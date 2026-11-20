pkgname=nerd-fonts-symbols
pkgver=3.5.1
pkgdesc="Symbols Nerd Font Mono (Symbole fuer kitty)"
license=OFL-1.1
url=https://www.nerdfonts.com/
sources=(https://raw.githubusercontent.com/ryanoasis/nerd-fonts/v3.5.1/patched-fonts/NerdFontsSymbolsOnly/SymbolsNerdFontMono-Regular.ttf)
sha256sums=()
depends=(fontconfig)

build() {
  :
}

package() {
  install -Dm644 SymbolsNerdFontMono-Regular.ttf "$pkgdir/usr/share/fonts/nerd-fonts/SymbolsNerdFontMono-Regular.ttf"
}

post_install() {
  fc-cache -s >/dev/null 2>&1 || true
}
