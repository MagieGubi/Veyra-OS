/*
 * veyra-live-init: Startprogramm der Veyra-Live-ISO (laeuft als /init in der Initramfs,
 * die fest im Live-Kernel steckt).
 *
 * 1. /dev, /proc, /sys einhaengen
 * 2. das Startmedium suchen: ein Blockgeraet mit ISO-9660-Dateisystem, auf dem
 *    /veyra/root.sfs liegt (CD-Laufwerk der VM oder USB-Stick), bis zu 30 s warten
 * 3. root.sfs (SquashFS) ueber ein Loop-Geraet nur lesend einhaengen
 * 4. darueber ein beschreibbares Overlay im Arbeitsspeicher (tmpfs)
 * 5. ins neue Root wechseln und systemd starten
 *
 * Bewusst ohne Shell und ohne Hilfsprogramme, statisch gegen die Veyra-glibc gelinkt.
 */
#define _GNU_SOURCE
#include <dirent.h>
#include <errno.h>
#include <fcntl.h>
#include <linux/loop.h>
#include <stdarg.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/ioctl.h>
#include <sys/mount.h>
#include <sys/stat.h>
#include <sys/sysmacros.h>
#include <time.h>
#include <unistd.h>

#define MEDIUM "/live/medium"
#define SFS_DIR "/live/sfs"
#define RW "/live/rw"
#define NEWROOT "/newroot"
#define SFS_FILE MEDIUM "/veyra/root.sfs"

static void msg(const char *fmt, ...)
{
	va_list ap;
	FILE *con = fopen("/dev/kmsg", "w");
	if (!con)
		con = stderr;
	fputs("veyra-live: ", con);
	va_start(ap, fmt);
	vfprintf(con, fmt, ap);
	va_end(ap);
	fputc('\n', con);
	if (con != stderr)
		fclose(con);
}

static void fatal(const char *what)
{
	msg("FEHLER: %s (%s). Start abgebrochen.", what, strerror(errno));
	for (;;)
		pause();
}

static void must_mount(const char *src, const char *dst, const char *type,
		       unsigned long flags, const char *data)
{
	mkdir(dst, 0755);
	if (mount(src, dst, type, flags, data) != 0) {
		char buf[256];
		snprintf(buf, sizeof(buf), "mount %s auf %s", type, dst);
		fatal(buf);
	}
}

/* Prueft ein Blockgeraet: ISO 9660 einhaengbar und /veyra/root.sfs vorhanden? */
static int try_medium(const char *name)
{
	char dev[300];
	struct stat st;

	snprintf(dev, sizeof(dev), "/dev/%s", name);
	if (stat(dev, &st) != 0 || !S_ISBLK(st.st_mode))
		return 0;
	if (mount(dev, MEDIUM, "iso9660", MS_RDONLY, NULL) != 0)
		return 0;
	if (access(SFS_FILE, R_OK) == 0) {
		msg("Startmedium gefunden: %s", dev);
		return 1;
	}
	umount(MEDIUM);
	return 0;
}

static int find_medium(void)
{
	for (int tries = 0; tries < 60; tries++) {
		DIR *d = opendir("/sys/class/block");
		struct dirent *e;

		if (!d)
			fatal("/sys/class/block nicht lesbar");
		while ((e = readdir(d))) {
			if (e->d_name[0] == '.' || !strncmp(e->d_name, "loop", 4) ||
			    !strncmp(e->d_name, "ram", 3))
				continue;
			if (try_medium(e->d_name)) {
				closedir(d);
				return 1;
			}
		}
		closedir(d);
		if (tries == 0)
			msg("warte auf das Startmedium (CD oder USB-Stick) ...");
		struct timespec ts = { 0, 500 * 1000 * 1000 };
		nanosleep(&ts, NULL);
	}
	return 0;
}

static void attach_loop(const char *file, char *loopdev, size_t len)
{
	int ctl = open("/dev/loop-control", O_RDWR | O_CLOEXEC);
	if (ctl < 0)
		fatal("/dev/loop-control");
	int n = ioctl(ctl, LOOP_CTL_GET_FREE);
	if (n < 0)
		fatal("kein freies Loop-Geraet");
	close(ctl);
	snprintf(loopdev, len, "/dev/loop%d", n);

	int ffd = open(file, O_RDONLY | O_CLOEXEC);
	if (ffd < 0)
		fatal(file);
	int lfd = open(loopdev, O_RDONLY | O_CLOEXEC);
	if (lfd < 0)
		fatal(loopdev);

	struct loop_config cfg;
	memset(&cfg, 0, sizeof(cfg));
	cfg.fd = (unsigned int)ffd;
	cfg.info.lo_flags = LO_FLAGS_READ_ONLY | LO_FLAGS_AUTOCLEAR;
	memcpy(cfg.info.lo_file_name, "root.sfs", sizeof("root.sfs"));
	if (ioctl(lfd, LOOP_CONFIGURE, &cfg) != 0)
		fatal("LOOP_CONFIGURE");
	close(ffd);
	close(lfd);
}

int main(void)
{
	char loopdev[32];

	mkdir("/dev", 0755);
	mkdir("/proc", 0755);
	mkdir("/sys", 0755);
	must_mount("devtmpfs", "/dev", "devtmpfs", MS_NOSUID, "mode=0755");
	must_mount("proc", "/proc", "proc", MS_NOSUID | MS_NOEXEC | MS_NODEV, NULL);
	must_mount("sysfs", "/sys", "sysfs", MS_NOSUID | MS_NOEXEC | MS_NODEV, NULL);
	mkdir("/live", 0755);
	mkdir(MEDIUM, 0755);
	msg("Veyra Live startet");

	if (!find_medium()) {
		errno = ENODEV;
		fatal("kein Startmedium mit /veyra/root.sfs gefunden");
	}

	attach_loop(SFS_FILE, loopdev, sizeof(loopdev));
	must_mount(loopdev, SFS_DIR, "squashfs", MS_RDONLY, NULL);

	/* Beschreibbare Schicht im Arbeitsspeicher. */
	must_mount("veyra-rw", RW, "tmpfs", 0, "mode=0755");
	mkdir(RW "/upper", 0755);
	mkdir(RW "/work", 0755);
	must_mount("overlay", NEWROOT, "overlay", 0,
		   "lowerdir=" SFS_DIR ",upperdir=" RW "/upper,workdir=" RW "/work");

	/* Medium, SquashFS und RW-Schicht im neuen System sichtbar lassen. */
	static const char *const keep[][2] = {
		{ MEDIUM, NEWROOT "/run/veyra-live/medium" },
		{ SFS_DIR, NEWROOT "/run/veyra-live/sfs" },
		{ RW, NEWROOT "/run/veyra-live/rw" },
	};
	mkdir(NEWROOT "/run", 0755);
	must_mount("tmpfs", NEWROOT "/run", "tmpfs", MS_NOSUID | MS_NODEV, "mode=0755");
	mkdir(NEWROOT "/run/veyra-live", 0755);
	for (size_t i = 0; i < sizeof(keep) / sizeof(keep[0]); i++) {
		mkdir(keep[i][1], 0755);
		if (mount(keep[i][0], keep[i][1], NULL, MS_MOVE, NULL) != 0)
			fatal(keep[i][0]);
	}
	static const char *const api[] = { "/dev", "/proc", "/sys" };
	for (size_t i = 0; i < 3; i++) {
		char dst[64];
		snprintf(dst, sizeof(dst), NEWROOT "%s", api[i]);
		mkdir(dst, 0755);
		if (mount(api[i], dst, NULL, MS_MOVE, NULL) != 0)
			fatal(api[i]);
	}

	/* switch_root: neues Root an "/" schieben und hineinwechseln. Die Initramfs
	 * selbst ist nur ein paar hundert KiB gross und bleibt einfach liegen. */
	if (chdir(NEWROOT) != 0)
		fatal("chdir " NEWROOT);
	if (mount(".", "/", NULL, MS_MOVE, NULL) != 0)
		fatal("mount --move " NEWROOT " /");
	if (chroot(".") != 0 || chdir("/") != 0)
		fatal("chroot");

	msg("starte systemd");
	char *const argv[] = { "/usr/lib/systemd/systemd", NULL };
	execv(argv[0], argv);
	fatal("systemd nicht startbar");
	return 1;
}
