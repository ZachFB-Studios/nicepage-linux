# nicepage-linux

Run the [Nicepage](https://nicepage.com) website builder natively on Linux, with no Wine at runtime.

Nicepage is only released for Windows and macOS, but it's an Electron app: the app itself is
JavaScript that runs the same on any platform. This script takes that JavaScript out of the
official Windows installer and runs it on the official Linux build of the same Electron version.

**This project contains no Nicepage code and downloads none itself.** You supply the Windows
installer from nicepage.com. Nicepage is proprietary software by Artisteer Limited, and your use
of it is covered by their license. This project isn't affiliated with or endorsed by Nicepage.

## Requirements

- Linux on x86_64 (arm64 should work but is untested)
- `wine` (only used once, while installing), `curl`, `7z` (p7zip), `strings` (binutils), `file`
- An internet connection: the installer downloads the app, and Nicepage's editor loads from their servers

Arch: `sudo pacman -S wine curl p7zip binutils file`
Debian/Ubuntu: `sudo apt install wine curl p7zip-full binutils file`

## Install

1. Download the Windows installer from [nicepage.com/download](https://nicepage.com/download)
   (`Nicepage-X.Y.Z.exe`). Any version works, including older ones your license covers.
2. Run:

```sh
./install.sh ~/Downloads/Nicepage-8.7.0.exe
```

Then start **Nicepage** from your app menu, or run `nicepage`.

What it does:

1. Creates a throwaway Wine prefix (cut off from your home folders, no Wine menu entries) and runs
   the installer silently in it.
2. Reads which Electron version that Nicepage was built on, downloads the same version for Linux
   from Electron's GitHub releases and checks its SHA-256.
3. Copies Nicepage's `resources/app.asar` into it, installs a launcher, an icon and a menu entry,
   and deletes the Wine prefix.

### Options

| Option | |
|---|---|
| `--dest DIR` | where to install (default `~/.local/share/nicepage-linux`) |
| `--projects DIR` | folder for your sites, set on first install (default: Nicepage's own, `~/Documents/Nicepage`) |
| `--no-integration` | skip `~/.local/bin/nicepage` and the menu entry |

A self-contained folder, with the sites inside it:

```sh
./install.sh --dest ~/Apps/Nicepage --projects ~/Apps/Nicepage/Projects Nicepage-8.7.0.exe
```

### Updating or switching versions

Run `install.sh` again with the other installer. Your settings and sites are kept, and the version it
replaces is moved to `DEST/previous` (one level, overwritten next time).

### Uninstall

```sh
rm -r ~/.local/share/nicepage-linux ~/.local/bin/nicepage ~/.local/share/applications/nicepage.desktop
```

Your sites stay in the projects folder. Nicepage also writes a log to `~/.config/Nicepage/`.

## Layout

```
DEST/
├── nicepage          launcher
├── nicepage.png      icon, taken from Nicepage.exe
├── electron/         Linux Electron + Nicepage's resources/app.asar
├── userdata/         Chromium profile + Nicepage settings (config.json)
└── previous/         the version replaced by the last update
```

## Known issues

- **Built-in updater:** it looks for a Linux release and logs a harmless 404. Update by
  rerunning the script.
- **SFTP publishing:** two optional native modules are Windows builds and don't load. The SSH library
  falls back to pure JavaScript, so SFTP should still work.
- **Chromium sandbox:** some distros block it (Ubuntu 24.04+ restricts unprivileged user namespaces).
  If Nicepage won't start, run `NICEPAGE_NO_SANDBOX=1 nicepage`, or set that variable in the menu
  entry's `Exec=` line.
- **Files on FUSE file systems (mergerfs etc.):** the Node.js inside Electron 29 reads files through
  io_uring, which returned scrambled data from mergerfs. The import then failed with
  "Invalid Nicepage Project File". The launcher sets `UV_USE_IO_URING=0` to prevent this. If you
  start `electron/electron` directly, set that variable yourself.

## License

The scripts in this repository are MIT licensed (see `LICENSE`). Nicepage itself is not covered by
that license.
