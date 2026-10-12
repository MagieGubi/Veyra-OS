pkgname=perl
pkgver=5.42.0
pkgdesc="Perl"
license="GPL-1.0-or-later OR Artistic-1.0-Perl"
url=https://www.perl.org
sources=(https://www.cpan.org/src/5.0/perl-5.42.0.tar.xz)
sha256sums=()
depends=(glibc gdbm zlib bzip2 libxcrypt)

build() {
  cd "perl-$pkgver"
  export BUILD_ZLIB=False BUILD_BZIP2=0
  p=/usr/lib/perl5/5.42
  sh Configure -des -D prefix=/usr -D vendorprefix=/usr \
    -D privlib=$p/core_perl -D archlib=$p/core_perl -D sitelib=$p/site_perl -D sitearch=$p/site_perl \
    -D vendorlib=$p/vendor_perl -D vendorarch=$p/vendor_perl \
    -D man1dir=/usr/share/man/man1 -D man3dir=/usr/share/man/man3 \
    -D pager="/usr/bin/less -isR" -D useshrplib -D usethreads
  make
}

package() {
  cd "perl-$pkgver"
  make DESTDIR="$pkgdir" install
}
