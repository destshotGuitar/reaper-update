# Update REAPER

**English** · [Русский](README.ru.md)

A REAPER action that updates REAPER itself in one click: it checks
[reaper.fm](https://www.reaper.fm/download.php) for a newer version, quits REAPER
(asking to save your projects), downloads and installs the update, and starts
REAPER again.

Works on **Windows**, **macOS** and **Linux**.

## Install

### With ReaPack (recommended)

1. Extensions → ReaPack → Import repositories…
2. Paste this URL and press OK:
   ```
   https://github.com/destshotGuitar/reaper-update/raw/main/index.xml
   ```
3. Extensions → ReaPack → Browse packages, find **Update REAPER**, right-click → Install, then Apply.

ReaPack will also deliver new versions of the script.

### Manually

1. Copy the `Various` folder contents into REAPER's resource path → `Scripts`
   (Options → Show REAPER resource path in explorer/finder). Keep
   `Update REAPER.lua` and the `reaper-update` folder next to each other.
2. Actions → Show action list → New action → Load ReaScript… → pick `Update REAPER.lua`.

## Use

Run **Script: Update REAPER.lua** from the action list. To keep it handy:

- **Actions menu:** in the action list choose New action → New custom action…,
  name it "Update REAPER", add *Script: Update REAPER.lua* to it and tick
  **Show in actions menu**.
- **Toolbar:** right-click a toolbar → Customize toolbar → Add.

If an update is available you'll see what version is installed and what's new.
Press **Yes** — REAPER quits, and a few seconds after it closes the update is
installed and REAPER starts again. You'll get notifications along the way and a
message if something goes wrong.

An administrator password is requested only when REAPER lives in a folder your
user can't write to (`C:\Program Files`, `/opt`, sometimes `/Applications`).

## How it works

`Update REAPER.lua` asks a small helper next to it for the latest version:
`update.ps1` (PowerShell) on Windows, `update.sh` (bash) on macOS and Linux.
The helper reads the download page, picks the file for your system and, after
you confirm, waits for REAPER to quit and installs the update:

| System | Download | Installs by | Asks for password with |
|---|---|---|---|
| Windows x64 / x86 / ARM64EC | `reaperNNN_x64-install.exe`, `reaperNNN-install.exe`, `…_win11_arm64ec…-install.exe` | official installer, silent (`/S /D=<REAPER folder>`) | UAC |
| macOS (Intel and Apple Silicon) | `reaperNNN_universal.dmg` | replacing `REAPER.app` with the one from the disk image | macOS admin prompt |
| Linux x86_64 / aarch64 / armv7l / i686 | `reaperNNN_linux_<arch>.tar.xz` | copying the new files over the REAPER folder (what `install-reaper.sh` does) | `pkexec` (polkit) |

REAPER is installed into the same place it runs from (`reaper.GetExePath()`),
so custom and portable install locations work. Your settings, plug-ins and
scripts live in the resource path and are not touched.

Details:

- **Proxy.** Programs started from REAPER don't inherit the proxy from your
  desktop settings. The helper picks it up itself: Windows uses the system proxy,
  on macOS it's read from `scutil --proxy`, on Linux from GNOME (`gsettings`) or
  KDE (`kioslaverc`). `https_proxy` in the environment takes priority.
- **Linux launcher.** After the update REAPER is started through its menu
  launcher (`cockos-reaper.desktop`) if that launcher runs this REAPER — so
  options like `pw-jack -p 128 /opt/REAPER/reaper` are kept. Otherwise the
  binary is started directly.
- **Stalled downloads** are aborted (less than 10 KB/s for 30 s) with an error
  message, so REAPER doesn't stay closed for long.
- If REAPER isn't closed within 5 minutes (for example you pressed Cancel in the
  save dialog), the update is cancelled.

Logs:

- Windows: `%TEMP%\reaper-update.log`
- macOS: `~/Library/Logs/reaper-update.log`
- Linux: `~/.cache/reaper-update.log`

## Tested

| | Version check | Full update |
|---|---|---|
| Linux x86_64 (Fedora, GNOME) | ✅ | ✅ |
| Windows | ✅ | not yet |
| macOS | ✅ | not yet |

Reports from Windows and macOS users are very welcome — please open an issue
with your log file.

## Requirements

- REAPER 6 or newer.
- Windows: Windows PowerShell 5.1 (built into Windows 10 and 11).
- macOS: nothing extra.
- Linux: `bash`, `curl`, `tar`, `xz`; `pkexec` if REAPER is in a system
  folder; `notify-send` and `zenity` or `kdialog` for messages (optional).

## License

[MIT](LICENSE)
