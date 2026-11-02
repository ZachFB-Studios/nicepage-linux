# nicepage-linux

Native electron app on linux for the [Nicepage](https://nicepage.com) website builder. Import your Winblows projects and start making websites.

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
2. Get this repo and run the script with your installer:

```sh
git clone https://github.com/ZachFB-Studios/nicepage-linux
cd nicepage-linux
./install.sh ~/Downloads/Nicepage-8.7.0.exe
```

It takes a few minutes and opens no windows. When it's done, **Nicepage** is in your app menu, and
`nicepage` starts it from a terminal.

What it does:

1. Creates a throwaway Wine prefix (cut off from your home folders, no Wine menu entries) and runs
   the installer silently in it.
2. Reads which Electron version that Nicepage was built on, downloads the same version for Linux
   from Electron's GitHub releases and checks its SHA-256.
3. Copies Nicepage's app files into it, installs a launcher, an icon and a menu entry, and deletes
   the Wine prefix.

### Options

| Option | |
|---|---|
| `--dest DIR` | where to install (default `~/.local/share/nicepage-linux`) |
| `--projects DIR` | folder for your sites, set on first install (you can also change it later in Preferences) |
| `--no-integration` | skip `~/.local/bin/nicepage` and the menu entry |

To keep everything in one folder, with your sites inside it:

```sh
./install.sh --dest ~/Apps/Nicepage --projects ~/Apps/Nicepage/Projects Nicepage-8.7.0.exe
```

## First start

1. **Start Nicepage** from your app menu (or run `nicepage`).
2. **Sign in.** Nicepage opens its sign-in or sign-up page in your web browser, and the app picks it
   up once you're signed in.
3. **Choose your folders.** Open the main menu and, under **Application**, choose **Preferences...**:
   - **Project Folder:** where Nicepage keeps your sites. It holds one `Site_…` folder per site
     and is managed by Nicepage, so don't drop zips or other files in it.
   - **Backup Folder:** where Nicepage saves site backups: before a newer Nicepage version updates
     a site, and when you delete one (as `…-DELETED.zip`).
   - **Export Folder:** where exported projects, HTML, WordPress and Joomla exports are saved.

   A tidy setup is one folder with three subfolders, such as `~/Nicepage/Projects`,
   `~/Nicepage/Backups` and `~/Nicepage/Exports`. Point each setting at its subfolder.
4. **Bring your sites over** from Windows or macOS:
   - On the old computer, open **Export / Import**, choose **Export Project**, and copy the zip over.
     A project zip has a `site.json` file at the top level.
   - On Linux, open **Export / Import** and choose **Import**.

   HTML, WordPress and Joomla exports are for publishing. Nicepage can't import them back as
   projects, and it reports them as "Invalid Nicepage Project File".

## Shortcuts

The installer adds:

- **A menu entry:** `~/.local/share/applications/nicepage.desktop`. Pin it to your dock or panel
  like any other app.
- **A terminal command:** `nicepage` (a link in `~/.local/bin`).

Both run `DEST/nicepage`, the launcher. Always start Nicepage through it: it points Nicepage at
its settings folder, runs it as a native Wayland app where available, and works around a
file-reading bug in the Node.js version this Electron uses. Running `DEST/electron/electron`
directly skips all of that.

### Making your own shortcut

If you used `--no-integration`, or want the shortcut somewhere else, create
`~/.local/share/applications/nicepage.desktop` with your install folder in place of `DEST`
(the default is `~/.local/share/nicepage-linux`; use the full path, `~` doesn't work here):

```ini
[Desktop Entry]
Type=Application
Name=Nicepage
Comment=Website builder
Exec=DEST/nicepage %U
Icon=DEST/nicepage.png
Terminal=false
Categories=Development;WebDevelopment;Graphics;
StartupWMClass=Nicepage
```

Or give this prompt to your own AI coding agent (Claude Code, opencode, etc.) and let it set the
shortcut up for your desktop:

```text
I installed Nicepage with nicepage-linux (https://github.com/ZachFB-Studios/nicepage-linux).
Find the install folder: it contains the launcher script "nicepage", "nicepage.png" and an
"electron" folder. The default is ~/.local/share/nicepage-linux. Then create a desktop entry at
~/.local/share/applications/nicepage.desktop with Name=Nicepage, Exec=<full path to that
nicepage launcher> %U, Icon=<full path to nicepage.png>, StartupWMClass=Nicepage,
Terminal=false and Categories=Development;WebDevelopment;Graphics;. Use absolute paths. Exec must
point to the "nicepage" launcher, never to electron/electron. Run update-desktop-database
~/.local/share/applications if it's installed. Then tell me how to pin it to my dock or panel on
my desktop environment. Don't change anything else without asking me.
```

## Updating or switching versions

Run `install.sh` again with the other installer (use the same `--dest` if you changed it). Your
settings, sites and folders are kept, and the version it replaces is moved to `DEST/previous`
(one level, overwritten next time).

## Uninstall

```sh
rm -r ~/.local/share/nicepage-linux ~/.local/bin/nicepage ~/.local/share/applications/nicepage.desktop
```

Your sites, backups and exports stay where you put them. Nicepage also writes a log to
`~/.config/Nicepage/`.

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
- **Nicepage won't start:** some distros block Chromium's sandbox (Ubuntu 24.04+ restricts
  unprivileged user namespaces). Run `NICEPAGE_NO_SANDBOX=1 nicepage`. If that works, change the
  menu entry's `Exec=` line to `env NICEPAGE_NO_SANDBOX=1 DEST/nicepage %U`.

## License

The scripts in this repository are MIT licensed (see `LICENSE`). Nicepage itself is not covered by
that license.
