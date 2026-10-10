<div align="center">

<img src="docs/cover.png" width="240" alt="A cartoon hamster holding a red flag">

# Browser Download Location

**Right-click any folder and it becomes where your browser saves downloads.**

**English** · [简体中文](README.md)

![Platform](https://img.shields.io/badge/platform-Windows%2010%20%2F%2011-0078D4)
![PowerShell](https://img.shields.io/badge/PowerShell-5.1-5391FE)
![Browser](https://img.shields.io/badge/browser-Edge%20%7C%20Chrome-0A84FF)
![License](https://img.shields.io/badge/license-MIT-green)

</div>

---

## The problem

Changing the browser's download folder means opening the browser, digging through
settings, and pasting a path — every single time. This tool turns that into one
right-click: flag a folder, and downloads start landing there.

The awkward part is not the settings page. It is that Chromium keeps the download
path **in memory** and rewrites its `Preferences` file on its own schedule.
Measured on the development machine: a value planted while Edge was running was
overwritten about **7 seconds later**. So the file can only be written while the
browser is genuinely not running — and "closed all the windows" is not the same
as "not running".

Three other approaches were measured and are dead ends:

| Route | Why it fails |
| --- | --- |
| `edge://restart` | It does not close anything. |
| A browser extension | Chromium deliberately exposes no API that changes the default download folder. |
| `HKCU\SOFTWARE\Policies` written without admin | On the development account that key cannot even be **read**, let alone written. |

---

## What it does

- **One right-click** flags any folder as the download location.
- **Drops a hidden marker** (a small flag icon) into the folder straight away, so
  you can see at a glance which folder is the current target.
- **Closes the browser, writes the new path, reads it back to confirm, and
  reopens the browser** — automatically. Nothing to verify afterwards.
- **Never interrupts a download in progress** (it checks for `.crdownload` first).
- **Cleans up after itself**: only one marker file ever exists, no matter how many
  times you re-flag.
- Works with **Edge, Chrome and Brave** (auto-detected), and needs **no
  administrator rights** for the default route.

---

## Quick start

1. Download or clone this repository anywhere.
2. Double-click **`Setup.cmd`** and pick option **`1`** (install everything).
3. Right-click any folder in Explorer and choose **"设为浏览器下载位置"**
   (*Set as browser download location*).
4. That is it. The folder is now the download location, and the browser reopens by
   itself.

<div align="center">
<img src="docs/folder-view.png" width="300" alt="The marker file and the right-click menu entry">
<br>
<sub>Top: the hidden marker <code>浏览器下载位置.ico</code> dropped into the folder　·　Bottom: the right-click menu entry</sub>
</div>

> The folder must already exist. Chromium's policy documentation notes that a
> non-existent folder makes the browser prompt for a save location instead.

---

## The menu

`Setup.cmd` is the front door.

| # | Option | Notes |
| --- | --- | --- |
| 1 | Install everything | Right-click menu + desktop shortcut |
| 2 | Install the right-click menu only | Writes `HKCU` only |
| 3 | Remove the right-click menu | Leaves the other tools in place |
| 4 | Show where downloads go now | Also reports any pending change |
| 5 | Flag a folder and wait | **Does not close the browser** |
| 6 | Flag a folder and apply now | The normal way |
| 7 | Flag a folder now by policy | Instant, needs administrator |
| 8 | Remove the download policy | Unlocks the browser setting |
| 9 | Clear the flag and sweep markers | Also cancels a pending change |
| 10 | How this works | The long explanation |

---

## Two routes

| | **File route** | **Policy route** |
| --- | --- | --- |
| How | Rewrites the browser's own `Preferences` | Sets the Windows `DownloadDirectory` policy |
| Admin | Not needed | **Required** |
| Browser must be closed | **Yes** | No — takes effect within seconds |
| Side effects | None | The download setting is greyed out / "managed by your organization" |
| Used by | Options 5 and 6, and the right-click menu | Option 7 |

`-Mode auto` (the default) picks the policy route when the window is already
elevated, and the file route otherwise.

---

## How it works

Flagging a folder does four things, in order:

1. **Drop the marker** into the folder, and remove it from every folder this tool
   has marked before.
2. **Ask the open windows to close** — an ordinary `WM_CLOSE`, so the session is
   saved.
3. **Terminate whatever is still running.** This matters more than it sounds: see
   the Startup boost note below.
4. **Write the new path, read it back, and reopen the browser.**

### Startup boost is why "closing the browser" is not enough

Edge's **Startup boost** keeps a windowless browser process alive after the last
window closes. Measured here: **0 windows open, 11 processes still running**. That
process holds the old download folder in memory, so it would silently overwrite
the new one later. Closing windows does nothing about it.

So this tool waits **up to 5 seconds** for the windows to go (only while a window
is actually open), then terminates the survivors. A forced exit writes no
settings, so the stale value cannot come back.

### Marker bookkeeping

Every folder this tool has ever marked is recorded in `markers.txt`, and the
marker is removed from all of them except the current one. Looking only at the
folder that was last **applied** is not enough: while a change is queued that
folder never advances, so each further flag would leave another marker behind —
which is exactly how earlier versions produced a litter of `.ico` files.

---

## Command line

```powershell
# Flag a folder (closes the browser and applies it)
.\Set-DownloadFlag.ps1 'D:\Downloads\Browser'

# Report the current location, the flag and any pending change
.\Set-DownloadFlag.ps1 -Show

# Flag without closing the browser
.\Set-DownloadFlag.ps1 -WaitOnly 'D:\Downloads\Browser'

# Force the policy route (needs an elevated window)
.\Set-DownloadFlag.ps1 -Mode policy 'D:\Downloads\Browser'

# Remove the marker, clear the flag, cancel any pending change
.\Set-DownloadFlag.ps1 -Unflag

# Sweep up marker files left behind by earlier versions
.\Set-DownloadFlag.ps1 -Cleanup

# Remove the download policy and unlock the browser setting
.\Set-DownloadFlag.ps1 -RemovePolicy
```

| Parameter | Meaning |
| --- | --- |
| `-Target <path>` | Folder to flag (positional). |
| `-Show` | Report state. |
| `-Unflag` | Clear the flag and cancel. |
| `-Cleanup` | Remove leftover marker files. |
| `-Browser auto\|Edge\|Chrome\|Brave` | Which browser. |
| `-Mode auto\|policy\|file` | How to apply it. |
| `-WaitOnly` | Do not close the browser. |
| `-Elevate` | Relaunch through a UAC prompt. |
| `-RemovePolicy` | Delete the policy this tool set. |
| `-NoPause` | Skip the 3-second closing countdown. |

---

## Files

| File | Purpose |
| --- | --- |
| `Setup.cmd` | The menu. |
| `Set-DownloadFlag.ps1` | Main entry point: flag / show / unflag / cleanup / policy. |
| `BrowserDownload.Common.ps1` | Shared helpers, dot-sourced by the rest. |
| `Apply-PendingFlag.ps1` | Background helper that waits for the browser to exit. |
| `Install-ContextMenu.ps1` | Adds / removes the right-click menu (HKCU). |
| `Install-Shortcut.ps1` | Creates a desktop shortcut. |
| `OpenBrowserDownload.ps1` | Opens the current download folder in Explorer. |
| `flag.ico` | The icon copied into flagged folders. |
| `docs/cover.png` | This README's artwork. |
| `docs/folder-view.png` | The marker file and the right-click menu entry. |

The marker is placed as a **hidden** file named `浏览器下载位置.ico`
("browser download location"). `View > Show > Hidden items` reveals it.

---

## Requirements

- **Windows 10 / 11** (uses the Windows registry and PowerShell).
- **PowerShell 5.1** — built into Windows. No installation needed.
- **Edge, Chrome or Brave.**
- Administrator rights are needed **only** for the policy route (options 7 and 8).

Tested on Windows 11 with Edge and Chrome, PowerShell 5.1.

---

## Troubleshooting

**The folder did not change.**
Run option **4** — it reports the pending change and what is holding it up. If the
browser has Startup boost on, turn it off at `edge://settings/system`, or just use
option 6 (the default), which closes the browser for you.

**There are several `.ico` files lying around.**
Run option **9**. It clears the flag and sweeps every folder this tool has ever
marked.

**"Your browser is managed by your organization".**
That is the policy route (option 7). On a personal PC it only means a local policy
is set. Option **8** removes it.

**The download setting is greyed out.**
Same cause. Run option **8** to unlock it.

**Downloads land in the wrong folder after a while.**
The browser was still running when the change was written. Use option 6, or turn
off Startup boost.

---

## License

[MIT](LICENSE) © 2026 pandipper
