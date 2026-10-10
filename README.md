<div align="center">

<img src="docs/cover.png" width="240" alt="A cartoon hamster holding a red flag">

# Browser Download Location

**Right-click any folder and it becomes where your browser saves downloads.**
**右键任意文件夹，它就会成为浏览器保存下载的位置。**

![Platform](https://img.shields.io/badge/platform-Windows%2010%20%2F%2011-0078D4)
![PowerShell](https://img.shields.io/badge/PowerShell-5.1-5391FE)
![Browser](https://img.shields.io/badge/browser-Edge%20%7C%20Chrome-0A84FF)
![License](https://img.shields.io/badge/license-MIT-green)

</div>

---

## The problem · 要解决的问题

Changing the browser's download folder means opening the browser, digging through
settings, and pasting a path — every single time. This tool turns that into one
right-click: flag a folder, and downloads start landing there.

改变浏览器的下载目录，意味着打开浏览器、翻设置、粘贴路径 —— 每次都要来一遍。
本工具把它变成一次右键：标记一个文件夹，下载就开始落到那里。

The awkward part is not the settings page. It is that Chromium keeps the download
path **in memory** and rewrites its `Preferences` file on its own schedule.
Measured on the development machine: a value planted while Edge was running was
overwritten about **7 seconds later**. So the file can only be written while the
browser is genuinely not running — and "closed all the windows" is not the same
as "not running".

麻烦的地方不是设置页。而是 Chromium 把下载路径**放在内存里**，并按自己的时机重写
`Preferences` 文件。在开发机上实测：Edge 运行时写入的值，大约 **7 秒后**就被覆盖了。
所以这个文件只有在浏览器确实没在运行时才写得进去 —— 而「关掉了所有窗口」并不等于
「没在运行」。

Three other approaches were measured here and are dead ends:

另外三条路子都实测过，在这里都是死路：

| Route · 路径 | Why it fails · 为什么不行 |
| --- | --- |
| `edge://restart` | It does not close anything. · 它不会关闭任何东西。 |
| A browser extension · 浏览器扩展 | Chromium deliberately exposes no API that changes the default download folder. · Chromium 刻意不提供任何能更改默认下载目录的 API。 |
| `HKCU\SOFTWARE\Policies` written without admin · 非管理员写 HKCU 策略 | On the development account that key cannot even be **read**, let alone written. · 在开发账户上，那个键连**读**都不行，更别说写。 |

---

## What it does · 功能

- **One right-click** flags any folder as the download location.
  **一次右键**即可把任意文件夹标记为下载位置。
- **Drops a hidden marker** (a small flag icon) into the folder straight away, so
  you can see at a glance which folder is the current target.
  **立即放入一个隐藏标记**（小旗帜图标），一眼就能看出当前目标是哪个文件夹。
- **Closes the browser, writes the new path, reads it back to confirm, and
  reopens the browser** — automatically. There is nothing to verify afterwards.
  **自动关闭浏览器、写入新路径、读回来确认、再重新打开浏览器**。事后无需任何验证。
- **Never interrupts a download in progress** (it checks for `.crdownload` first).
  **绝不打断正在进行的下载**（会先检查 `.crdownload`）。
- **Cleans up after itself**: only one marker file ever exists, no matter how many
  times you re-flag. **自己收拾干净**：无论重新标记多少次，磁盘上始终只有一个标记文件。
- Works with **Edge, Chrome and Brave** (auto-detected), and needs **no
  administrator rights** for the default route.
  支持 **Edge、Chrome 和 Brave**（自动检测），默认路径**不需要管理员权限**。

---

## Quick start · 快速开始

1. Download or clone this repository anywhere.
   把本仓库下载或克隆到任意位置。
2. Double-click **`Setup.cmd`** and pick option **`1`** (install everything).
   双击 **`Setup.cmd`**，选 **`1`**（安装全部）。
3. Right-click any folder in Explorer and choose the menu entry.
   在资源管理器里右键任意文件夹，选择菜单项。
4. That is it. The folder is now the download location, and the browser reopens by
   itself. 完成。该文件夹现在就是下载位置，浏览器会自行重新打开。

> The folder must already exist. Chromium's policy documentation notes that a
> non-existent folder makes the browser prompt for a save location instead.
> 文件夹必须已存在。Chromium 的策略文档指出，目录不存在时浏览器会改为弹窗询问保存位置。

---

## The menu · 菜单

`Setup.cmd` is the front door. 双击 `Setup.cmd` 就是入口。

| # | Option · 选项 | Notes · 说明 |
| --- | --- | --- |
| 1 | Install everything · 安装全部 | Right-click menu + desktop shortcut · 右键菜单 + 桌面快捷方式 |
| 2 | Install the right-click menu only · 只安装右键菜单 | Writes `HKCU` only · 只写 `HKCU` |
| 3 | Remove the right-click menu · 移除右键菜单 | Leaves the other tools in place · 其它工具保持原位 |
| 4 | Show where downloads go now · 显示当前下载位置 | Also reports any pending change · 同时报告待处理的变更 |
| 5 | Flag a folder and wait · 标记目录并等待 | **Does not close the browser** · **不关闭浏览器** |
| 6 | Flag a folder and apply now · 标记目录并立即应用 | The normal way · 常规方式 |
| 7 | Flag a folder now by policy · 通过策略立即标记 | Instant, needs administrator · 即时生效，需要管理员 |
| 8 | Remove the download policy · 移除下载策略 | Unlocks the browser setting · 解锁浏览器里的设置 |
| 9 | Clear the flag and sweep markers · 清除标记并清理残留 | Also cancels a pending change · 同时取消待处理的变更 |
| 10 | How this works · 工作原理 | The long explanation · 详细说明 |

---

## Two routes · 两种通道

| | **File route** · 文件通道 | **Policy route** · 策略通道 |
| --- | --- | --- |
| How · 方式 | Rewrites the browser's own `Preferences` | Sets the Windows `DownloadDirectory` policy |
| Admin · 管理员 | Not needed · 不需要 | **Required** · **需要** |
| Browser must be closed · 需关闭浏览器 | **Yes** · **是** | No — takes effect within seconds · 不需要，几秒内生效 |
| Side effects · 副作用 | None · 无 | The download setting is greyed out / "managed by your organization" · 下载设置变灰 / 显示「由你的组织管理」 |
| Used by · 用于 | Options 5 and 6, and the right-click menu · 选项 5、6，以及右键菜单 | Option 7 · 选项 7 |

`-Mode auto` (the default) picks the policy route when the window is already
elevated, and the file route otherwise.
`-Mode auto`（默认）在本窗口已提权时走策略通道，否则走文件通道。

---

## How it works · 工作原理

Flagging a folder does four things, in order:
标记一个文件夹会按顺序做四件事：

1. **Drop the marker** into the folder, and remove it from every folder this tool
   has marked before. **放入标记**，并把它从本工具标记过的其它所有文件夹里移除。
2. **Ask the open windows to close** — an ordinary `WM_CLOSE`, so the session is
   saved. **请打开的窗口关闭** —— 一个普通的 `WM_CLOSE`，所以会话会被保存。
3. **Terminate whatever is still running.** This matters more than it sounds: see
   the Startup boost note below. **终止仍在运行的一切**。这比听起来更重要：见下面的
   启动加速说明。
4. **Write the new path, read it back, and reopen the browser.**
   **写入新路径、读回来、重新打开浏览器。**

### Startup boost is why "closing the browser" is not enough · 为什么「关掉浏览器」还不够

Edge's **Startup boost** keeps a windowless browser process alive after the last
window closes. Measured here: **0 windows open, 11 processes still running**. That
process holds the old download folder in memory, so it would silently overwrite
the new one later. Closing windows does nothing about it.
Edge 的**启动加速**会在最后一个窗口关闭后，继续保活一个无窗口进程。本机实测：
**0 个窗口打开，11 个进程仍存活**。那个进程内存里握着旧的下载目录，所以它稍后会
悄悄把新值覆盖回去。关窗口对它毫无作用。

So this tool waits **up to 5 seconds** for the windows to go (only while a window
is actually open), then terminates the survivors. A forced exit writes no
settings, so the stale value cannot come back.
所以本工具最多等 **5 秒**让窗口退出（且只在确实有窗口打开时才等），然后终止剩余的
进程。强杀不写任何设置，所以旧值回不来。

### Marker bookkeeping · 标记的记账

Every folder this tool has ever marked is recorded in `markers.txt`, and the
marker is removed from all of them except the current one. Looking only at the
folder that was last **applied** is not enough: while a change is queued that
folder never advances, so each further flag would leave another marker behind —
which is exactly how earlier versions produced a litter of `.ico` files.
本工具标记过的每个文件夹都记录在 `markers.txt` 里，除当前目录外，标记会从所有
目录中移除。只看最后一次**已应用**的目录是不够的：变更还在排队时，那个目录根本
不前进，于是每再标记一次就多遗留一个标记 —— 早期版本正是这样堆出一地 `.ico` 文件的。

---

## Command line · 命令行

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

| Parameter · 参数 | Meaning · 含义 |
| --- | --- |
| `-Target <path>` | Folder to flag (positional). · 要标记的目录（位置参数）。 |
| `-Show` | Report state. · 报告状态。 |
| `-Unflag` | Clear the flag and cancel. · 清除标志并取消。 |
| `-Cleanup` | Remove leftover marker files. · 清理残留的标记文件。 |
| `-Browser auto\|Edge\|Chrome\|Brave` | Which browser. · 哪个浏览器。 |
| `-Mode auto\|policy\|file` | How to apply it. · 以何种方式应用。 |
| `-WaitOnly` | Do not close the browser. · 不关闭浏览器。 |
| `-Elevate` | Relaunch through a UAC prompt. · 通过 UAC 提示重新启动。 |
| `-RemovePolicy` | Delete the policy this tool set. · 删除本工具设置的策略。 |
| `-NoPause` | Skip the 3-second closing countdown. · 跳过关闭前的 3 秒倒计时。 |

---

## Files · 文件

| File · 文件 | Purpose · 用途 |
| --- | --- |
| `Setup.cmd` | The menu. · 菜单入口。 |
| `Set-DownloadFlag.ps1` | Main entry point: flag / show / unflag / cleanup / policy. · 主入口。 |
| `BrowserDownload.Common.ps1` | Shared helpers, dot-sourced by the rest. · 共享辅助函数。 |
| `Apply-PendingFlag.ps1` | Background helper that waits for the browser to exit. · 后台辅助进程。 |
| `Install-ContextMenu.ps1` | Adds / removes the right-click menu (HKCU). · 添加 / 移除右键菜单。 |
| `Install-Shortcut.ps1` | Creates a desktop shortcut. · 创建桌面快捷方式。 |
| `OpenBrowserDownload.ps1` | Opens the current download folder in Explorer. · 打开当前下载目录。 |
| `flag.ico` | The icon copied into flagged folders. · 复制进已标记目录的图标。 |
| `docs/cover.png` | This README's artwork. · 本 README 的封面图。 |

The marker is placed as a **hidden** file named `浏览器下载位置.ico`
("browser download location"). `View > Show > Hidden items` reveals it.
标记以**隐藏**文件形式放入，名为 `浏览器下载位置.ico`。
「查看 > 显示 > 隐藏的项目」可以把它显示出来。

---

## Requirements · 环境要求

- **Windows 10 / 11** (uses the Windows registry and PowerShell).
  **Windows 10 / 11**（用到 Windows 注册表和 PowerShell）。
- **PowerShell 5.1** — built into Windows. No installation needed.
  **PowerShell 5.1** —— Windows 自带，无需安装。
- **Edge, Chrome or Brave.** · **Edge、Chrome 或 Brave。**
- Administrator rights are needed **only** for the policy route (options 7 and 8).
  **仅**策略通道（选项 7、8）需要管理员权限。

Tested on Windows 11 with Edge and Chrome, PowerShell 5.1.
已在 Windows 11 + Edge / Chrome + PowerShell 5.1 上测试。

---

## Troubleshooting · 常见问题

**The folder did not change.**
**目录没有变。**
Run option **4** — it reports the pending change and what is holding it up. If the
browser has Startup boost on, turn it off at `edge://settings/system`, or just use
option 6 (the default), which closes the browser for you.
运行选项 **4** —— 它会报告待处理的变更以及是什么在阻塞它。如果浏览器开着启动加速，
在 `edge://settings/system` 关掉它，或者直接用选项 6（默认），它会替你关闭浏览器。

**There are several `.ico` files lying around.**
**残留了好几个 `.ico` 文件。**
Run option **9**. It clears the flag and sweeps every folder this tool has ever
marked. · 运行选项 **9**。它会清除标记并清理本工具标记过的所有目录。

**"Your browser is managed by your organization".**
**「你的浏览器由你的组织管理」。**
That is the policy route (option 7). On a personal PC it only means a local policy
is set. Option **8** removes it. · 那是策略通道（选项 7）造成的。在个人电脑上，它仅
意味着设置了本地策略。选项 **8** 可以移除它。

**The download setting is greyed out.**
**下载设置变灰了。**
Same cause. Run option **8** to unlock it. · 同一个原因。运行选项 **8** 解锁。

**Downloads land in the wrong folder after a while.**
**过一会儿下载又落到别的目录了。**
The browser was still running when the change was written. Use option 6, or turn
off Startup boost. · 写入变更时浏览器仍在运行。请用选项 6，或者关闭启动加速。

---

## License · 许可证

[MIT](LICENSE) © 2026 pandipper
