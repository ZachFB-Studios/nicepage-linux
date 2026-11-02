#!/usr/bin/env bash
# nicepage-linux: run Nicepage's own app code on the official Linux build of Electron.
#
# Nicepage ships for Windows and macOS only, but the app itself is JavaScript (resources/app.asar).
# This script runs the Windows installer you downloaded once, in a throwaway Wine prefix, takes the
# app files out of it, downloads the matching Linux Electron from GitHub and installs a launcher.
# Nothing from Nicepage is bundled with or downloaded by this project except through that installer.
set -euo pipefail

DEST="${XDG_DATA_HOME:-$HOME/.local/share}/nicepage-linux"
BIN_DIR="$HOME/.local/bin"
APPS_DIR="${XDG_DATA_HOME:-$HOME/.local/share}/applications"
PROJECTS=""
INTEGRATE=1
INSTALLER=""

usage() {
	cat <<EOF
Usage: $(basename "$0") [options] Nicepage-X.Y.Z.exe

Installs Nicepage from its Windows installer to run natively on Linux.

Options:
  --dest DIR        install directory (default: $DEST)
  --projects DIR    folder Nicepage keeps its sites in (default: Nicepage's own, ~/Documents/Nicepage)
  --no-integration  don't add ~/.local/bin/nicepage or a menu entry
  -h, --help        show this help

Running it again with another installer replaces the app and keeps your settings and sites;
the version it replaces is kept in DIR/previous.
EOF
}

die() { printf '\033[31merror:\033[0m %s\n' "$*" >&2; exit 1; }
log() { printf '\033[1;34m::\033[0m %s\n' "$*"; }

while (($#)); do
	case "$1" in
		--dest) DEST="${2:?--dest needs a directory}"; shift 2 ;;
		--projects) PROJECTS="${2:?--projects needs a directory}"; shift 2 ;;
		--no-integration) INTEGRATE=0; shift ;;
		-h|--help) usage; exit 0 ;;
		-*) die "unknown option: $1 (see --help)" ;;
		*) [[ -z "$INSTALLER" ]] || die "only one installer can be given"; INSTALLER="$1"; shift ;;
	esac
done

[[ -n "$INSTALLER" ]] || { usage; exit 1; }
[[ -f "$INSTALLER" ]] || die "installer not found: $INSTALLER"
INSTALLER="$(realpath "$INSTALLER")"
DEST="$(realpath -m "$DEST")"
[[ -z "$PROJECTS" ]] || PROJECTS="$(realpath -m "$PROJECTS")"

for cmd in wine wineboot wineserver curl 7z strings sha256sum file; do
	command -v "$cmd" >/dev/null || die "missing '$cmd' (needed: wine, curl, 7z/p7zip, binutils, coreutils, file)"
done

case "$(uname -m)" in
	x86_64) ARCH=x64 ;;
	aarch64) ARCH=arm64 ;;
	*) die "unsupported architecture: $(uname -m)" ;;
esac

WORK="$(mktemp -d -t nicepage-linux.XXXXXX)"
export WINEPREFIX="$WORK/prefix" WINEARCH=win64 WINEDEBUG=-all
cleanup() {
	wineserver -k 2>/dev/null || true
	rm -rf "$WORK"
}
trap cleanup EXIT

# --- 1. Run the Windows installer in a throwaway prefix --------------------------------------------
log "Creating a temporary Wine prefix"
# winemenubuilder off: no Wine menu entries or file associations from the installer
WINEDLLOVERRIDES="winemenubuilder.exe=d;mscoree,mshtml=" wineboot -i >/dev/null 2>&1
wine reg add 'HKCU\Software\Wine\DllOverrides' /v winemenubuilder.exe /d '' /f >/dev/null 2>&1
# Wine links these to your real home folders; make them plain folders so nothing leaks out
WUSER="$WINEPREFIX/drive_c/users/$USER"
for d in Desktop Documents Downloads Music Pictures Videos; do
	if [[ -L "$WUSER/$d" ]]; then rm "$WUSER/$d"; mkdir "$WUSER/$d"; fi
done

log "Running $(basename "$INSTALLER") silently (it downloads the app, ~200 MB)"
wine "$INSTALLER" /S >"$WORK/installer.log" 2>&1 || true

WINAPP="$WUSER/AppData/Local/Programs/Nicepage"
for _ in $(seq 120); do
	[[ -f "$WINAPP/resources/app.asar" && -f "$WINAPP/Nicepage.exe" ]] && break
	sleep 1
done
if [[ ! -f "$WINAPP/resources/app.asar" ]]; then
	tail -n 20 "$WORK/installer.log" >&2
	die "the installer didn't install Nicepage (Wine output above). Is this a Nicepage installer, and are you online?"
fi
wineserver -k 2>/dev/null || true   # stop anything the installer started

ELECTRON="$(strings "$WINAPP/Nicepage.exe" | grep -m1 -oE 'Electron/[0-9]+\.[0-9]+\.[0-9]+' | cut -d/ -f2 || true)"
[[ -n "$ELECTRON" ]] || die "couldn't find the Electron version in Nicepage.exe"
NPVER="$(grep -a -o '"DisplayVersion"="[^"]*"' "$WINEPREFIX/user.reg" | head -1 | cut -d'"' -f4 || true)"
log "Nicepage ${NPVER:-(unknown version)} uses Electron $ELECTRON"

# --- 2. Get the matching Linux Electron ------------------------------------------------------------
ZIP="electron-v$ELECTRON-linux-$ARCH.zip"
BASE="https://github.com/electron/electron/releases/download/v$ELECTRON"
log "Downloading $ZIP"
curl -fL --progress-bar -o "$WORK/$ZIP" "$BASE/$ZIP"
curl -fsSL -o "$WORK/SHASUMS256.txt" "$BASE/SHASUMS256.txt"
(cd "$WORK" && grep " \*$ZIP\$" SHASUMS256.txt | sed 's/ \*/  /' | sha256sum -c --quiet) \
	|| die "checksum mismatch for $ZIP"

# --- 3. Assemble ---------------------------------------------------------------------------------
NEW="$WORK/electron"
7z x -y -o"$NEW" "$WORK/$ZIP" >/dev/null
rm -f "$NEW/resources/default_app.asar"
cp -a "$WINAPP/resources/app.asar" "$WINAPP/resources/app.asar.unpacked" "$WINAPP/resources/app-update.yml" "$NEW/resources/"
cp -a "$WINAPP/nicepage.id" "$WINAPP/inst_source.dat" "$NEW/" 2>/dev/null || true
printf '%s\n' "${NPVER:-unknown}" >"$NEW/nicepage-version"

# Icon: the largest PNG among Nicepage.exe's icon resources
7z x -y -o"$WORK/rsrc" "$WINAPP/Nicepage.exe" '.rsrc/*/ICON/*' >/dev/null 2>&1 || true
ICON_SRC="$(find "$WORK/rsrc" -type f -printf '%s %p\n' 2>/dev/null | sort -rn | while read -r _ f; do
	file -b "$f" | grep -q '^PNG' && { echo "$f"; break; }; done || true)"

mkdir -p "$DEST"
if [[ -d "$DEST/electron" ]]; then
	rm -rf "$DEST/previous"
	mv "$DEST/electron" "$DEST/previous"
	log "Kept the old version in $DEST/previous"
fi
mv "$NEW" "$DEST/electron"
[[ -n "$ICON_SRC" ]] && cp "$ICON_SRC" "$DEST/nicepage.png"

mkdir -p "$DEST/userdata"
if [[ -n "$PROJECTS" ]]; then
	mkdir -p "$PROJECTS"
	if [[ -f "$DEST/userdata/config.json" ]]; then
		log "Settings already exist; change the projects folder in Nicepage's settings instead"
	else
		cat >"$DEST/userdata/config.json" <<EOF
{
	"runtimeSettings": {
		"projectsFolder": "$PROJECTS",
		"lastSaveFolder": "$PROJECTS",
		"backupAskOption": null,
		"backupFolder": null,
		"lastUrl": null
	}
}
EOF
	fi
fi

cat >"$DEST/nicepage" <<'EOF'
#!/usr/bin/env bash
# Nicepage on native Linux Electron (installed by nicepage-linux).
here="$(cd "$(dirname "$(readlink -f "$0")")" && pwd)"
# Electron's Node (20.x in Electron 29) reads files through io_uring, which returns scrambled data on
# some FUSE file systems (mergerfs): valid projects then fail to import. Node later disabled it too.
export UV_USE_IO_URING=0
flags=(--user-data-dir="$here/userdata" --ozone-platform-hint=auto --enable-wayland-ime)
# For systems that block Chromium's sandbox (e.g. Ubuntu 24.04+ AppArmor userns restrictions)
[[ "${NICEPAGE_NO_SANDBOX:-}" == 1 ]] && flags+=(--no-sandbox)
exec "$here/electron/electron" "${flags[@]}" "$@"
EOF
chmod +x "$DEST/nicepage"

# --- 4. Desktop integration ----------------------------------------------------------------------
if ((INTEGRATE)); then
	mkdir -p "$BIN_DIR" "$APPS_DIR"
	ln -sfn "$DEST/nicepage" "$BIN_DIR/nicepage"
	cat >"$APPS_DIR/nicepage.desktop" <<EOF
[Desktop Entry]
Type=Application
Name=Nicepage
Comment=Website builder
Exec=$DEST/nicepage %U
Icon=$DEST/nicepage.png
Terminal=false
Categories=Development;WebDevelopment;Graphics;
StartupWMClass=Nicepage
EOF
	command -v update-desktop-database >/dev/null && update-desktop-database "$APPS_DIR" 2>/dev/null || true
fi

log "Installed Nicepage ${NPVER:-} to $DEST"
((INTEGRATE)) && log "Start it from your app menu or run: nicepage"
((INTEGRATE)) || log "Start it with: $DEST/nicepage"
log "First start: sign in, then set your folders in Application > Preferences... (README: First start)"
