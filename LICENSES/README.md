# Lizenzen fremder Quellen

Veyra baut fremde Software aus ihren Originalquellen. Jede behält ihre Lizenz;
das Manifest jedes `.vpkg`-Pakets nennt sie im Feld `license`.

| Quelle | Lizenz | Verwendet für |
| --- | --- | --- |
| Linux | GPL-2.0-only (mit Syscall-Ausnahme) | Kernel, API-Header; künftige Veyra-Kernel-Patches stehen ebenfalls unter GPL-2.0-only |
| GNU binutils | GPL-3.0-or-later | Cross-Toolchain |
| GCC | GPL-3.0-or-later mit GCC Runtime Library Exception | Cross-Toolchain, libstdc++ |
| GNU C Library (glibc) | LGPL-2.1-or-later | Systembibliothek |
| GMP | LGPL-3.0-or-later oder GPL-2.0-or-later | GCC-Abhängigkeit (nur zum Bauen) |
| MPFR | LGPL-3.0-or-later | GCC-Abhängigkeit (nur zum Bauen) |
| MPC | LGPL-3.0-or-later | GCC-Abhängigkeit (nur zum Bauen) |
| Debian (Bootstrap-Container) | verschiedene | nur Build-Host, nichts davon im Veyra-System |

Methode und Bauschritte der Toolchain folgen dem Buch *Linux From Scratch* 12.4
(https://www.linuxfromscratch.org/), das unter einer Creative-Commons- bzw. MIT-Lizenz steht.
