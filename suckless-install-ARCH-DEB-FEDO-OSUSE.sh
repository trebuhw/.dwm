#!/usr/bin/env bash
# =============================================================================
#  Suckless Universal Installer v2.0
#  Instaluje: dwm, st, dmenu, slstatus
#  Obsługuje: Debian/Ubuntu, Fedora/RHEL, Arch Linux, openSUSE
#  Katalog instalacji: ~/.config/suckless
#  Binaria:            ~/.local/bin  (fallback: /usr/local/bin jako root)
# =============================================================================

set -euo pipefail
IFS=$'\n\t'

# ── Wersja i ścieżki ──────────────────────────────────────────────────────────
SCRIPT_VERSION="2.0"
SUCKLESS_DIR="${HOME}/.config/suckless"
LOCAL_PREFIX="${HOME}/.local"

# ── Kolory (wyłączone jeśli brak terminala) ───────────────────────────────────
if [ -t 1 ]; then
    RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
    BLUE='\033[0;34m'; CYAN='\033[0;36m'; BOLD='\033[1m'; NC='\033[0m'
else
    RED=''; GREEN=''; YELLOW=''; BLUE=''; CYAN=''; BOLD=''; NC=''
fi

# ── Pomocnicze funkcje ────────────────────────────────────────────────────────
info()    { echo -e "${BLUE}[INFO]${NC}  $*"; }
success() { echo -e "${GREEN}[ OK ]${NC}  $*"; }
warn()    { echo -e "${YELLOW}[WARN]${NC}  $*"; }
error()   { echo -e "${RED}[ERR ]${NC}  $*" >&2; exit 1; }
step()    { echo -e "\n${BOLD}${CYAN}══ $* ${NC}"; }
die()     { echo -e "${RED}[FATAL]${NC} $*" >&2; exit 1; }

# ── Obsługa sygnałów ──────────────────────────────────────────────────────────
cleanup() {
    local code=$?
    if [ $code -ne 0 ]; then
        echo -e "\n${RED}Skrypt zakończony błędem (kod: $code).${NC}"
        echo -e "Sprawdź logi powyżej. Możesz uruchomić skrypt ponownie – obsługuje wznowienie."
    fi
}
trap cleanup EXIT

# ── Wymagania wstępne ─────────────────────────────────────────────────────────
check_requirements() {
    local missing=()
    for cmd in git make gcc; do
        command -v "$cmd" &>/dev/null || missing+=("$cmd")
    done
    [ ${#missing[@]} -gt 0 ] && info "Brakujące narzędzia (zostaną zainstalowane): ${missing[*]}"
    return 0
}

# ── Wykrycie dystrybucji ──────────────────────────────────────────────────────
detect_distro() {
    [ -f /etc/os-release ] || die "Nie można wykryć dystrybucji – brak /etc/os-release."

    # shellcheck source=/dev/null
    . /etc/os-release

    local id="${ID,,}"
    local id_like="${ID_LIKE,,:-}"

    case "$id" in
        arch|manjaro|endeavouros|artix|garuda|cachyos)
            DISTRO="arch" ;;
        debian|ubuntu|linuxmint|pop|kali|raspbian|elementary|zorin|neon)
            DISTRO="debian" ;;
        fedora|rhel|centos|almalinux|rocky|nobara)
            DISTRO="fedora" ;;
        opensuse*|suse|sles)
            DISTRO="opensuse" ;;
        *)
            if   [[ "$id_like" == *"arch"*   ]]; then DISTRO="arch"
            elif [[ "$id_like" == *"debian"* || "$id_like" == *"ubuntu"* ]]; then DISTRO="debian"
            elif [[ "$id_like" == *"fedora"* || "$id_like" == *"rhel"*   ]]; then DISTRO="fedora"
            elif [[ "$id_like" == *"suse"*   ]]; then DISTRO="opensuse"
            else die "Nieobsługiwana dystrybucja: $id (ID_LIKE=$id_like)"
            fi ;;
    esac

    PRETTY="${PRETTY_NAME:-$id}"
    info "Dystrybucja : ${BOLD}${PRETTY}${NC}  →  profil: ${BOLD}${DISTRO}${NC}"
}

# ── Sprawdzenie/konfiguracja sudo ─────────────────────────────────────────────
check_sudo() {
    if [ "$EUID" -eq 0 ]; then
        SUDO=""
        warn "Uruchomiono jako root. Binaria trafią do /usr/local/bin."
        LOCAL_PREFIX="/usr/local"
    elif command -v sudo &>/dev/null; then
        SUDO="sudo"
        sudo -v || die "sudo niedostępne lub odrzucono hasło."
        info "Uprawnienia sudo potwierdzone."
    else
        die "Brak sudo i nie jesteś rootem. Zainstaluj sudo lub uruchom jako root."
    fi
}

# ── Instalacja zależności ─────────────────────────────────────────────────────
install_deps() {
    step "Instalacja zależności systemowych ($DISTRO)"

    case "$DISTRO" in

        arch)
            local pkgs=(
                base-devel git
                xorg-server xorg-xinit xorg-xrandr xorg-xsetroot
                xorg-xev xorg-xprop xorg-xdpyinfo xorg-xauth
                libx11 libxft libxinerama freetype2 fontconfig
                feh xdg-user-dirs
                ttf-dejavu ttf-liberation noto-fonts
            )
            $SUDO pacman -Syu --needed --noconfirm "${pkgs[@]}"
            ;;

        debian)
            $SUDO apt-get update -qq
            local pkgs=(
                build-essential git pkg-config
                xorg x11-xserver-utils xinit xauth
                libx11-dev libxft-dev libxinerama-dev
                libfreetype6-dev libfontconfig1-dev
                feh xdg-user-dirs
                fonts-dejavu fonts-liberation
            )
            $SUDO apt-get install -y "${pkgs[@]}"
            ;;

        fedora)
            $SUDO dnf upgrade -y --refresh
            local pkgs=(
                gcc make git pkgconf-pkg-config
                xorg-x11-server-Xorg xorg-x11-xinit
                xorg-x11-utils xorg-x11-server-utils xorg-x11-xauth
                libX11-devel libXft-devel libXinerama-devel
                freetype-devel fontconfig-devel
                feh xdg-user-dirs
                dejavu-fonts-all liberation-fonts
            )
            $SUDO dnf install -y "${pkgs[@]}"
            ;;

        opensuse)
            $SUDO zypper --non-interactive refresh
            local pkgs=(
                gcc make git pkg-config
                patterns-devel-base-devel_basis
                xorg-x11-server xorg-x11-xinit xorg-x11-server-extra
                xorg-x11-utils xauth
                libX11-devel libXft-devel libXinerama-devel
                freetype2-devel fontconfig-devel
                feh xdg-user-dirs
                dejavu-fonts liberation-fonts
            )
            $SUDO zypper install -y --no-recommends "${pkgs[@]}"
            ;;
    esac

    success "Zależności zainstalowane."
}

# ── Konfiguracja xdg-user-dirs ────────────────────────────────────────────────
setup_xdg() {
    step "Konfiguracja xdg-user-dirs"
    if command -v xdg-user-dirs-update &>/dev/null; then
        xdg-user-dirs-update
        success "Katalogi użytkownika XDG zaktualizowane."
    else
        warn "xdg-user-dirs-update niedostępne – pomijam."
    fi
}

# ── Upewnienie się, że ~/.local/bin jest w PATH ───────────────────────────────
ensure_local_bin_in_path() {
    local bin_dir="${LOCAL_PREFIX}/bin"
    mkdir -p "$bin_dir"

    for rc in "${HOME}/.bashrc" "${HOME}/.zshrc"; do
        [ -f "$rc" ] || continue
        if ! grep -q "$bin_dir" "$rc" 2>/dev/null; then
            printf '\n# Dodane przez suckless-install.sh\nexport PATH="%s:$PATH"\n' \
                "$bin_dir" >> "$rc"
            info "Dodano ${bin_dir} do PATH w $rc"
        fi
    done

    export PATH="${bin_dir}:${PATH}"
}

# ── Klonowanie i kompilacja projektu suckless ─────────────────────────────────
build_suckless() {
    local name="$1"
    local url="$2"
    local dest="$3"

    step "Klonowanie i kompilacja: ${BOLD}${name}${NC}"

    # Klonuj lub aktualizuj
    if [ -d "${dest}/.git" ]; then
        warn "${name} już istnieje – próba aktualizacji (git pull)."
        git -C "$dest" pull --ff-only 2>/dev/null \
            || warn "git pull nie powiódł się (lokalne zmiany?) – pomijam aktualizację."
    else
        info "Klonowanie ${url}"
        git clone --depth=1 "$url" "$dest" \
            || die "Nie można sklonować ${name}. Sprawdź połączenie z internetem."
    fi

    # Backup config.h jeśli istnieje
    if [ -f "${dest}/config.h" ]; then
        local bak="${dest}/config.h.bak.$(date +%Y%m%d_%H%M%S)"
        cp "${dest}/config.h" "$bak"
        info "Backup config.h → $(basename "$bak")"
    fi

    # Skopiuj config.def.h → config.h jeśli brak własnego
    if [ ! -f "${dest}/config.h" ] && [ -f "${dest}/config.def.h" ]; then
        cp "${dest}/config.def.h" "${dest}/config.h"
        info "Skopiowano config.def.h → config.h"
    fi

    # Kompilacja
    info "Kompiluję ${name} (PREFIX=${LOCAL_PREFIX})…"
    make -C "$dest" clean 2>/dev/null || true

    make -C "$dest" PREFIX="${LOCAL_PREFIX}" \
        || die "Kompilacja ${name} nie powiodła się. Sprawdź błędy powyżej."

    # Instalacja
    if ! make -C "$dest" PREFIX="${LOCAL_PREFIX}" install 2>/dev/null; then
        warn "Instalacja bez sudo nie powiodła się – próba z ${SUDO:-root}…"
        ${SUDO:+$SUDO} make -C "$dest" PREFIX="${LOCAL_PREFIX}" install \
            || die "Instalacja ${name} nie powiodła się nawet z sudo."
    fi

    success "${name} zainstalowany."
}

# ── Tworzenie ~/.xinitrc ──────────────────────────────────────────────────────
create_xinitrc() {
    step "Tworzenie ~/.xinitrc"

    local xinitrc="${HOME}/.xinitrc"

    if [ -f "$xinitrc" ]; then
        local bak="${xinitrc}.bak.$(date +%Y%m%d_%H%M%S)"
        cp "$xinitrc" "$bak"
        warn "Istniejący .xinitrc zbackupowany → $(basename "$bak")"
    fi

    cat > "$xinitrc" << 'XINITEOF'
#!/bin/sh
# ~/.xinitrc – wygenerowany przez suckless-install.sh v2.0
# Edytuj według własnych potrzeb.

# ── Środowisko ─────────────────────────────────────────────────────────────
export PATH="$HOME/.local/bin:$PATH"
export XDG_SESSION_TYPE=x11

# ── Kompozytor ────────────────────────────────────────────────────────────
# picom --experimental-backends -b &

# ── Blokada ekranu ─────────────────────────────────────────────────────────
# xset s 300 300 &
# xss-lock -- slock &

# ── Schowek ───────────────────────────────────────────────────────────────
# parcellite &

# ── Tapeta ────────────────────────────────────────────────────────────────
# feh --randomize --bg-fill ~/Pictures/Wallpapers/ &
# feh --bg-scale ~/Pictures/wallpaper.jpg &

# ── Układ klawiatury ──────────────────────────────────────────────────────
setxkbmap pl &

# ── Akceleracja myszy ─────────────────────────────────────────────────────
# xset m 0 0 &

# ── Zasobnik systemowy / sieć ─────────────────────────────────────────────
# nm-applet &

# ── Pasek stanu slstatus ──────────────────────────────────────────────────
if command -v slstatus >/dev/null 2>&1; then
    slstatus &
fi

# ── Uruchom DWM ───────────────────────────────────────────────────────────
exec dwm
XINITEOF

    chmod +x "$xinitrc"
    success "Plik ~/.xinitrc zapisany."
}

# ── Wpis .desktop dla menedżerów logowania ────────────────────────────────────
create_desktop_entry() {
    step "Wpis .desktop dla DWM"

    # Wpis systemowy (widoczny w GDM/LightDM/SDDM)
    local xsessions="/usr/share/xsessions"
    if [ -d "$xsessions" ]; then
        ${SUDO:+$SUDO} tee "${xsessions}/dwm.desktop" > /dev/null << 'DESKTOPEOF'
[Desktop Entry]
Name=dwm
Comment=Dynamic Window Manager (suckless)
Exec=/bin/sh -c "exec dwm"
TryExec=dwm
Type=XSession
DESKTOPEOF
        success "Wpis ${xsessions}/dwm.desktop zapisany."
    fi

    # Lokalny wpis (fallback)
    local apps_dir="${HOME}/.local/share/applications"
    mkdir -p "$apps_dir"
    cat > "${apps_dir}/dwm.desktop" << 'DESKTOPEOF'
[Desktop Entry]
Name=dwm
Comment=Dynamic Window Manager (suckless)
Exec=startx
Type=Application
Categories=System;
DESKTOPEOF
    success "Lokalny wpis .desktop zapisany."
}

# ── Podsumowanie ──────────────────────────────────────────────────────────────
print_summary() {
    local bin_dir="${LOCAL_PREFIX}/bin"

    echo
    echo -e "${BOLD}${GREEN}╔═══════════════════════════════════════════════════════════╗${NC}"
    echo -e "${BOLD}${GREEN}║          Instalacja suckless zakończona!  ✓               ║${NC}"
    echo -e "${BOLD}${GREEN}╚═══════════════════════════════════════════════════════════╝${NC}"
    echo
    echo -e "  Dystrybucja  : ${CYAN}${PRETTY}${NC}"
    echo -e "  Źródła       : ${CYAN}${SUCKLESS_DIR}/${NC}"
    echo -e "  Binaria      : ${CYAN}${bin_dir}${NC}"
    echo -e "  Konfiguracja : ${CYAN}~/.xinitrc${NC}"
    echo
    echo -e "  ${BOLD}Zainstalowane projekty:${NC}"
    for proj in dwm st dmenu slstatus; do
        if command -v "$proj" &>/dev/null || [ -x "${bin_dir}/${proj}" ]; then
            echo -e "  ${GREEN}✓${NC}  $proj"
        else
            echo -e "  ${YELLOW}?${NC}  $proj  (nie znaleziono w PATH – sprawdź ${bin_dir})"
        fi
    done
    echo
    echo -e "  ${BOLD}Jak uruchomić DWM:${NC}"
    echo -e "  • TTY          →  wpisz ${YELLOW}startx${NC}"
    echo -e "  • Display Mgr  →  wybierz sesję ${YELLOW}dwm${NC}"
    echo
    echo -e "  ${BOLD}Domyślne skróty DWM:${NC}"
    echo -e "  ${YELLOW}Mod+Shift+Enter${NC}   terminal (st)"
    echo -e "  ${YELLOW}Mod+p${NC}             dmenu (launcher)"
    echo -e "  ${YELLOW}Mod+b${NC}             pokaż/ukryj pasek"
    echo -e "  ${YELLOW}Mod+Shift+c${NC}       zamknij okno"
    echo -e "  ${YELLOW}Mod+Shift+q${NC}       wyjdź z DWM"
    echo -e "  (Mod = Alt domyślnie; zmień na Super → config.h: modkey)"
    echo
    echo -e "  ${BOLD}Personalizacja (workflow):${NC}"
    echo -e "  1. Edytuj ${CYAN}${SUCKLESS_DIR}/<projekt>/config.h${NC}"
    echo -e "  2. ${YELLOW}cd ${SUCKLESS_DIR}/<projekt>${NC}"
    echo -e "  3. ${YELLOW}make clean install PREFIX=${LOCAL_PREFIX}${NC}"
    echo -e "  4. Zrestartuj DWM: ${YELLOW}Mod+Shift+q${NC} → ${YELLOW}startx${NC}"
    echo
}

# ── Pomoc ─────────────────────────────────────────────────────────────────────
usage() {
    cat << EOF
Użycie: $(basename "$0") [opcje]

Opcje:
  -d, --dir DIR      Katalog docelowy suckless    (domyślnie: ~/.config/suckless)
  -p, --prefix DIR   Prefix instalacji binarek    (domyślnie: ~/.local)
  --no-xinitrc       Nie twórz/nadpisuj ~/.xinitrc
  --only PROJEKT     Zainstaluj tylko jeden projekt: dwm | st | dmenu | slstatus
  -h, --help         Wyświetl tę pomoc

Przykłady:
  $(basename "$0")
  $(basename "$0") --only dwm
  $(basename "$0") --dir ~/src/suckless --prefix /usr/local
EOF
    exit 0
}

# ── MAIN ──────────────────────────────────────────────────────────────────────
main() {
    local no_xinitrc=false
    local only=""

    while [[ $# -gt 0 ]]; do
        case "$1" in
            -d|--dir)     SUCKLESS_DIR="$2"; shift 2 ;;
            -p|--prefix)  LOCAL_PREFIX="$2"; shift 2 ;;
            --no-xinitrc) no_xinitrc=true; shift ;;
            --only)       only="$2"; shift 2 ;;
            -h|--help)    usage ;;
            *) warn "Nieznany argument: $1"; shift ;;
        esac
    done

    echo -e "\n${BOLD}${CYAN}╔═══════════════════════════════════════════════════════════╗${NC}"
    echo -e   "${BOLD}${CYAN}║       Suckless Universal Installer v${SCRIPT_VERSION}                   ║${NC}"
    echo -e   "${BOLD}${CYAN}║   dwm  ·  st  ·  dmenu  ·  slstatus                      ║${NC}"
    echo -e   "${BOLD}${CYAN}╚═══════════════════════════════════════════════════════════╝${NC}\n"

    detect_distro
    check_sudo
    check_requirements
    install_deps
    setup_xdg
    ensure_local_bin_in_path

    mkdir -p "$SUCKLESS_DIR"
    info "Katalog suckless : ${SUCKLESS_DIR}"
    info "Prefix binarek   : ${LOCAL_PREFIX}"

    # Mapa projektów: nazwa → URL
    declare -A PROJECTS=(
        [dwm]="https://git.suckless.org/dwm"
        [st]="https://git.suckless.org/st"
        [dmenu]="https://git.suckless.org/dmenu"
        [slstatus]="https://git.suckless.org/slstatus"
    )

    local order=(dwm st dmenu slstatus)

    if [ -n "$only" ]; then
        [ -n "${PROJECTS[$only]:-}" ] \
            || die "Nieznany projekt: '$only'. Dostępne: ${!PROJECTS[*]}"
        order=("$only")
    fi

    for proj in "${order[@]}"; do
        build_suckless "$proj" "${PROJECTS[$proj]}" "${SUCKLESS_DIR}/${proj}"
    done

    $no_xinitrc || create_xinitrc
    create_desktop_entry
    print_summary
}

main "$@"
