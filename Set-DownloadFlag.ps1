<#
.SYNOPSIS
    Flag a folder as the browser download location, from the right-click menu.
    从右键菜单把一个目录标记为浏览器下载位置。

.DESCRIPTION
    Right-click a folder, choose the menu entry, and that folder becomes where
    downloads land. The marker appears in it straight away.
    右键点击一个目录，选择菜单项，该目录就会成为下载的落点。标记会立刻出现在
    其中。

    The browser is closed if it is running, the new location is written, and the
    browser is reopened. One right-click is all it takes; nothing has to be
    verified or confirmed afterwards.
    若浏览器正在运行就关闭它，写入新位置，然后重新打开浏览器。只需一次右键，
    事后无需再做任何验证或确认。

    WHY THE BROWSER HAS TO CLOSE
    为什么必须关闭浏览器

    The browser keeps download.default_directory in memory and rewrites its
    Preferences file on its own schedule. Measured on this machine: a value
    written while Edge was running was gone again 7 seconds later. So the write
    only sticks while no browser process exists.
    浏览器把 download.default_directory 保存在内存里，并按自己的时机重写
    Preferences 文件。本机实测：Edge 运行时写入的值 7 秒后就又没了。所以只有
    在没有任何浏览器进程存在时，写入才能留存。

    Three other routes were tried and measured, all dead ends here:
    另外三条路子都试过并实测过，在这里都是死路：

      1. The DownloadDirectory registry policy would apply instantly, but this
         account cannot even read HKCU\SOFTWARE\Policies, let alone write it, so
         it needs an administrator.
      1. DownloadDirectory 注册表策略本可以立即生效，但本账户连读取
         HKCU\SOFTWARE\Policies 都做不到，更别说写入，因此需要管理员权限。
      2. edge://restart does not close anything.
      2. edge://restart 不会关闭任何东西。
      3. A browser extension: Chromium deliberately exposes no API that changes
         the default download folder.
      3. 浏览器扩展：Chromium 刻意不提供任何可以更改默认下载目录的 API。

    Closing the windows is not enough by itself: Edge's Startup boost keeps a
    windowless process alive (measured here: 0 windows, 11 processes) and that
    process holds the old folder in memory. So an open window is asked to close
    first -- an ordinary WM_CLOSE, so the session is saved -- and whatever is
    still running after that is terminated. A forced exit writes no settings, so
    the stale value cannot come back either.
    仅关闭窗口本身还不够：Edge 的「启动加速」会维持一个无窗口进程存活（本机
    实测：0 个窗口、11 个进程），而那个进程把旧目录留在内存里。所以先请打开
    的窗口关闭 -- 一个普通的 WM_CLOSE，会话因此得以保存 -- 之后再终止仍然
    存活的一切。强杀不写任何设置，所以旧值也回不来。

    -WaitOnly keeps the old, patient behaviour instead: record the intent, drop
    the marker, and let a background helper write the setting the next time the
    browser exits on its own. Nothing is interrupted, but the change can wait a
    long time -- which is exactly the case that used to look like a failure.
    -WaitOnly 则保留旧的、耐心的行为：记录意图，放下标记，让后台 helper 在
    浏览器下次自行退出时写入设置。什么都不会被打断，但变更可能要等很久 --
    而这恰恰就是过去看起来像失败的那种情况。

.PARAMETER Target
    Folder to flag.
    要标记的目录。

.PARAMETER Show
    Report the browser's current download folder, the flagged folder, and any
    pending change.
    报告浏览器当前的下载目录、已标记的目录，以及任何待处理的变更。

.PARAMETER Unflag
    Remove the marker, clear the flag and cancel any pending change.
    移除标记、清除标志，并取消任何待处理的变更。

.PARAMETER Browser
    Which browser to configure: auto (default), Edge, Chrome or Brave.
    要配置哪个浏览器：auto（默认）、Edge、Chrome 或 Brave。

.PARAMETER ApplyNow
    Accepted for compatibility, and no longer needed: closing the browser and
    applying the change is what flagging a folder does by default now.
    为兼容性而接受，但已不再需要：关闭浏览器并应用变更如今就是标记目录的默认
    行为。

.PARAMETER WaitOnly
    Do not close the browser. Record the intent, drop the marker, and let a
    background helper write the setting the next time the browser exits on its
    own. Nothing is interrupted, but the change can sit unapplied for as long as
    the browser stays open.
    不关闭浏览器。记录意图，放下标记，让后台 helper 在浏览器下次自行退出时
    写入设置。什么都不会被打断，但只要浏览器一直开着，变更就可能一直不被
    应用。

.PARAMETER Mode
    How the folder gets applied.
    目录以何种方式被应用。

      auto   - the policy route when this window is elevated, otherwise the
               deferred Preferences write (default)
      policy - force the policy route; needs an elevated window
      file   - force the deferred Preferences write
      auto   - 本窗口已提权时走策略通道，否则走延迟的 Preferences 写入（默认）
      policy - 强制走策略通道；需要已提权的窗口
      file   - 强制走延迟的 Preferences 写入

    The policy route sets the mandatory DownloadDirectory policy. The browser
    picks it up within seconds, with no restart and no need to close anything.
    The trade-off is that the download location becomes locked in the browser's
    settings page while the policy is set; -RemovePolicy unlocks it.
    策略通道设置强制的 DownloadDirectory 策略。浏览器会在几秒内采用它，无需
    重启，也无需关闭任何东西。代价是：策略生效期间，下载位置会在浏览器的设置
    页面里被锁定；-RemovePolicy 可以解锁。

    The file route leaves the settings page alone, but can only be written while
    the browser is fully closed, so it may wait a long time.
    文件通道不碰设置页面，但只能在浏览器完全关闭时写入，因此可能要等很久。

.PARAMETER RemovePolicy
    Delete the DownloadDirectory policy this tool set and unlock the download
    location in the browser settings page. Needs an elevated window. The flag
    and the marker are left alone.
    删除本工具设置的 DownloadDirectory 策略，并解锁浏览器设置页面里的下载
    位置。需要已提权的窗口。标志和标记保持不变。

.PARAMETER NoPause
    Skip the 3-second countdown before the window closes. Set by Setup.cmd so its
    menu does not stall.
    跳过窗口关闭前的 3 秒倒计时。由 Setup.cmd 设置，以免它的菜单卡住。

.EXAMPLE
    .\Set-DownloadFlag.ps1 -Show

.EXAMPLE
    .\Set-DownloadFlag.ps1 -Target 'D:\Downloads\Browser'
#>

[CmdletBinding(DefaultParameterSetName = 'Set')]
param(
    [Parameter(Mandatory = $true, Position = 0, ParameterSetName = 'Set')]
    [string]$Target,

    [Parameter(Mandatory = $true, ParameterSetName = 'Show')]
    [switch]$Show,

    [Parameter(Mandatory = $true, ParameterSetName = 'Unflag')]
    [switch]$Unflag,

    [Parameter(Mandatory = $true, ParameterSetName = 'RemovePolicy')]
    [switch]$RemovePolicy,

    # Sweep up every marker this tool has ever planted, including ones orphaned
    # by earlier revisions.
    # 清扫本工具曾经放过的每一个标记，包括被早期版本遗留成孤儿的那些。
    [Parameter(Mandatory = $true, ParameterSetName = 'Cleanup')]
    [switch]$Cleanup,

    [ValidateSet('auto', 'Edge', 'Chrome', 'Brave')]
    [string]$Browser = 'auto',

    # How the folder is applied.
    # 目录以何种方式被应用。
    #   auto   - policy when this window is elevated, otherwise the file route
    #   policy - force the policy route (needs an elevated window)
    #   file   - force the deferred Preferences write
    #   auto   - 本窗口已提权时走策略，否则走文件通道
    #   policy - 强制走策略通道（需要已提权的窗口）
    #   file   - 强制走延迟的 Preferences 写入
    [ValidateSet('auto', 'policy', 'file')]
    [string]$Mode = 'auto',

    # Kept for compatibility. Closing the browser and applying the change is
    # what a plain flag does now, so this switch changes nothing any more.
    # 为兼容性而保留。关闭浏览器并应用变更如今就是普通标记的默认行为，所以这个
    # 开关不再改变任何东西。
    [switch]$ApplyNow,

    # Opt out of closing the browser: record the intent, drop the marker, and
    # let the background helper apply it when the browser exits on its own.
    # 选择不关闭浏览器：记录意图，放下标记，让后台 helper 在浏览器自行退出时
    # 应用它。
    [switch]$WaitOnly,

    # Relaunch this script through a UAC prompt when it is not already
    # elevated. Used by Setup.cmd so the policy route is one click away.
    # 当尚未提权时，通过 UAC 提示重新启动本脚本。由 Setup.cmd 使用，让策略通道
    # 只需一次点击。
    [switch]$Elevate,

    [switch]$NoPause
)

# ASCII-only source. Every Chinese string in this tool is assembled from
# character codes at run time, so a BOM-less file cannot be mis-decoded by
# PowerShell 5.1 and no code page can mangle a menu label.
# 纯 ASCII 源码。本工具里每个中文字符串都在运行时由字符码拼装而成，因此一个
# 不带 BOM 的文件不会被 PowerShell 5.1 误解码，也没有任何代码页能把菜单标签
# 弄乱。

$ErrorActionPreference = 'Stop'
$logFileEarly = Join-Path -Path $env:APPDATA -ChildPath 'BrowserDownloadFlag\flag.log'

trap {
    $msg = $_.Exception.Message
    $where = ''
    if ($_.InvocationInfo) { $where = ' (at line ' + $_.InvocationInfo.ScriptLineNumber + ')' }
    Write-Host ''
    Write-Host ('FAILED: 失败：' + $msg + $where) -ForegroundColor Red
    Write-Host 'Nothing was changed, or only partly changed. 没有做任何更改，或者只更改了一部分。' -ForegroundColor Yellow
    Write-Host ('Log: 日志：' + $logFileEarly) -ForegroundColor DarkGray

    # Record the failure. A crash used to leave no trace in the log at all,
    # which made "it worked a few times and then stopped" impossible to
    # diagnose afterwards. Written directly, because the shared helpers may not
    # have been loaded yet when this runs.
    # 记录这次失败。以前崩溃时日志里完全不留痕迹，导致「用了几次然后就不行了」
    # 之后根本无法诊断。这里直接写入，因为运行到这里时共享辅助函数可能还没被
    # 加载。
    try {
        $logDir = Split-Path -Path $logFileEarly -Parent
        if (-not (Test-Path -LiteralPath $logDir)) { New-Item -Path $logDir -ItemType Directory -Force | Out-Null }
        Add-Content -LiteralPath $logFileEarly -Encoding UTF8 -Value (
            (Get-Date -Format 'yyyy-MM-dd HH:mm:ss') + ' FAILED: ' + $msg + $where)
    } catch { }

    if (-not $NoPause) { for ($i = 3; $i -ge 1; $i--) { Write-Host ("`r  Closing in $i s ...   $i 秒后自动关闭 ...  ") -NoNewline -ForegroundColor DarkGray; Start-Sleep -Seconds 1 }; Write-Host '' }
    break
}

$scriptRoot = $PSScriptRoot
if (-not $scriptRoot) { $scriptRoot = Split-Path -Parent $MyInvocation.MyCommand.Definition }

$commonPath = Join-Path -Path $scriptRoot -ChildPath 'BrowserDownload.Common.ps1'
if (-not (Test-Path -LiteralPath $commonPath)) {
    Write-Host ('FAILED: BrowserDownload.Common.ps1 is missing. 失败：缺少 BrowserDownload.Common.ps1。位置：' + $scriptRoot) -ForegroundColor Red
    Write-Host 'Reinstall the tool: the other scripts cannot run without it. 请重新安装本工具：没有它其它脚本无法运行。' -ForegroundColor Yellow
    if (-not $NoPause) { for ($i = 3; $i -ge 1; $i--) { Write-Host ("`r  Closing in $i s ...   $i 秒后自动关闭 ...  ") -NoNewline -ForegroundColor DarkGray; Start-Sleep -Seconds 1 }; Write-Host '' }
    exit 4
}
. $commonPath

# --- optional self-elevation ------------------------------------------------
# --- 可选的自提权 ----------------------------------------------------------
# The policy route needs an elevated process. Relaunching through a UAC prompt
# from here is more reliable than trying to quote a folder path through cmd's
# escaping rules, and it keeps the elevated window's output readable.
# 策略通道需要已提权的进程。从这里通过 UAC 提示重新启动，比试图用 cmd 的转义
# 规则去引住一个目录路径更可靠，而且能让提权后窗口的输出保持可读。
if ($Elevate -and (-not (Test-BdIsElevated))) {
    $self = $PSCommandPath
    if (-not $self) { $self = Join-Path -Path $scriptRoot -ChildPath 'Set-DownloadFlag.ps1' }

    $argList = @('-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', ('"' + $self + '"'))
    if ($PSCmdlet.ParameterSetName -eq 'RemovePolicy') {
        $argList += '-RemovePolicy'
    } elseif ($PSCmdlet.ParameterSetName -eq 'Set') {
        $argList += @('-Target', ('"' + $Target + '"'), '-Mode', $Mode)
    } else {
        $argList += '-Show'
    }
    if ($Browser -and ($Browser -ine 'auto')) { $argList += @('-Browser', $Browser) }

    Write-Host ''
    Write-BdInfo 'This needs administrator rights. A UAC prompt will open. 这需要管理员权限。将弹出 UAC 提示。'
    try {
        Start-Process -FilePath 'powershell.exe' -Verb RunAs -ArgumentList $argList -ErrorAction Stop
    } catch {
        Write-BdErr ('Could not elevate: 无法提权：' + $_.Exception.Message)
        Write-Host '  Open PowerShell with Run as administrator and run it there. 请以管理员身份打开 PowerShell，并在那里运行。' -ForegroundColor Yellow
        Pause-BdIfInteractive -NoPause:$NoPause
        exit 9
    }
    exit 0
}

$applierScript = Join-Path -Path $scriptRoot -ChildPath 'Apply-PendingFlag.ps1'
$iconSource    = Join-Path -Path $scriptRoot -ChildPath 'flag.ico'

Initialize-BdState
$stateFile   = Get-BdStateFile -Name 'current.txt'     # folder currently flagged. 当前已标记的目录。
$pendingFile = Get-BdStateFile -Name 'pending.txt'     # folder waiting to be applied. 等待被应用的目录。
$modeFile    = Get-BdStateFile -Name 'mode.txt'        # 'policy' or 'file'. 'policy' 或 'file'。

# ------------------------------------------------------------------ show
# ------------------------------------------------------------------ 显示

if ($Show) {
    Write-Host ''

    $info = Get-BdCurrentDownloadDir
    Write-BdInfo 'The browser download location right now: 浏览器当前的下载位置：'
    if ($info) {
        Write-Host ('  ' + $info.Dir) -ForegroundColor White
        Write-Host ('  (' + $info.Browser + ')') -ForegroundColor DarkGray
    } else {
        Write-BdWarn 'could not be read. 无法读取。'
    }

    if ($info) {
        $policy     = Get-BdPolicyDirectory -BrowserName $info.Browser
        $policyRoot = Get-BdPolicyRegistryPath -BrowserName $info.Browser

        Write-Host ''
        if ($policy) {
            Write-BdInfo 'Forced by policy: 被策略强制为：'
            Write-Host ('  ' + $policy) -ForegroundColor White
            Write-Host ('  ' + $policyRoot + '\DownloadDirectory') -ForegroundColor DarkGray
            Write-Host '  The location is locked in the browser settings page while this policy is' -ForegroundColor Gray
            Write-Host '  set. -RemovePolicy unlocks it.' -ForegroundColor Gray
            Write-Host '  只要该策略生效，这个位置就在浏览器设置页面里被锁定。-RemovePolicy 可解锁。' -ForegroundColor Gray
        } elseif ($policyRoot) {
            Write-BdInfo 'No download policy is set. 没有设置下载策略。'
        } else {
            Write-BdInfo ($info.Browser + ' has no policy route in this tool; the file route is used. 在本工具里没有策略通道；将使用文件通道。')
        }

        if ($policyRoot) {
            if (Test-BdIsElevated) {
                Write-Host '  This window is elevated, so -Mode auto uses the policy route: 本窗口已提权，所以 -Mode auto 走策略通道：' -ForegroundColor DarkGray
                Write-Host '  it applies instantly and never needs the browser closed. 它立即生效，且从不需要关闭浏览器。' -ForegroundColor DarkGray
            } else {
                Write-Host '  This window is not elevated, so -Mode auto uses the file route, which' -ForegroundColor DarkGray
                Write-Host '  waits for the browser to exit. Run once as administrator to get the' -ForegroundColor DarkGray
                Write-Host '  instant policy route instead.' -ForegroundColor DarkGray
                Write-Host '  本窗口未提权，所以 -Mode auto 走文件通道，它会等待浏览器退出。以管理员身份运行一次，即可改用即时生效的策略通道。' -ForegroundColor DarkGray
            }
        }
    }

    $flag = Read-BdStateLine -Name 'current.txt'
    if ($flag) {
        Write-Host ''
        Write-BdInfo 'Last folder you flagged: 你上次标记的目录：'
        Write-Host ('  ' + $flag) -ForegroundColor White
        if (Test-Path -LiteralPath $flag) {
            if (Test-Path -LiteralPath (Join-Path -Path $flag -ChildPath (Get-BdMarkerName))) {
                Write-BdOk 'marker present. 标记存在。'
            } else {
                Write-BdWarn 'marker is missing (flag the folder again to restore it). 标记缺失（重新标记该目录即可恢复）。'
            }
        } else {
            Write-BdWarn 'that folder no longer exists. 该目录已不存在。'
        }
    }

    $pending = Read-BdStateLine -Name 'pending.txt'
    if ($pending) {
        $running = Get-BdRunningCount
        $appliers = @(Get-BdApplierProcesses).Count
        Write-Host ''
        Write-BdWarn 'A change is waiting to be applied: 有一个变更正等待应用：'
        Write-Host ('  ' + $pending) -ForegroundColor Yellow
        Write-Host ''
        if ($info -and ($info.Dir.TrimEnd('\') -ieq $pending.TrimEnd('\'))) {
            Write-BdOk 'already applied -- the browser is using it. 已应用 -- 浏览器正在使用它。'
        } elseif ($appliers -gt 0) {
            $procs    = Get-BdBrowserProcesses -BrowserName $info.Browser
            $windowed = @($procs | Where-Object { $_.HasWindow })
            $boost    = @($procs | Where-Object { $_.StartupBoost })

            if (($procs.Count -gt 0) -and ($windowed.Count -eq 0)) {
                # Every window is shut, yet processes remain. This is the case
                # that makes the tool look broken: nothing will ever be applied
                # until those processes go, and closing windows does not do it.
                # 所有窗口都关了，进程却还在。正是这种情况让本工具看起来坏掉了：
                # 在这些进程消失之前什么都不会被应用，而关闭窗口并不能让它们消失。
                Write-BdWarn ('All browser windows are closed, but ' + $procs.Count + ' background process(es) are still alive. 所有浏览器窗口都已关闭，但仍有 ' + $procs.Count + ' 个后台进程存活。')
                Write-Host ''
                if ($boost.Count -gt 0) {
                    Write-BdInfo 'Startup boost is holding a windowless browser process open. 「启动加速」正维持着一个无窗口的浏览器进程。'
                    Write-Host '  That process keeps the old folder in memory, so the change cannot be' -ForegroundColor Gray
                    Write-Host '  written until it is gone. Two ways out:' -ForegroundColor Gray
                    Write-Host '    - turn off Startup boost at edge://settings/system, or' -ForegroundColor Gray
                    Write-Host '    - flag the folder again without -WaitOnly: that closes the browser' -ForegroundColor Gray
                    Write-Host '      and applies the change straight away.' -ForegroundColor Gray
                    Write-Host '  该进程把旧目录留在内存里，所以在它消失之前无法写入变更。两条出路：' -ForegroundColor Gray
                    Write-Host '    - 在 edge://settings/system 关闭「启动加速」，或者' -ForegroundColor Gray
                    Write-Host '    - 不加 -WaitOnly 重新标记该目录：那会关闭浏览器并立即应用变更。' -ForegroundColor Gray
                } else {
                    Write-BdInfo 'No window is open, so the change will land as soon as the remaining background processes stop.'
                    Write-Host '  没有窗口开着，所以剩余的这些后台进程一停止，变更就会落地。' -ForegroundColor Gray
                    Write-Host '  A helper is waiting. 有 helper 在等待。' -ForegroundColor Gray
                }
            } else {
                Write-BdInfo ('The browser is running (' + $running + ' processes), so the change is held back until it has fully exited.')
                Write-Host ('  浏览器正在运行（' + $running + ' 个进程），所以变更会被推迟到它完全退出。') -ForegroundColor Gray
                Write-Host '  A helper is waiting and needs nothing from you: close the browser whenever' -ForegroundColor Gray
                Write-Host '  you normally would and the change lands then.' -ForegroundColor Gray
                Write-Host '  有 helper 在等待，不需要你做任何事：照常关闭浏览器，变更届时落地。' -ForegroundColor Gray
            }
        } else {
            Write-BdWarn 'No helper is running, so nothing will apply it automatically. 没有 helper 在运行，所以不会自动应用任何东西。'
            Write-Host '  Flag the folder again to restart the helper, or close the browser and' -ForegroundColor Gray
            Write-Host '  flag it again to apply the change immediately.' -ForegroundColor Gray
            Write-Host '  重新标记该目录以重启 helper，或者关闭浏览器后再重新标记一次，以立即应用变更。' -ForegroundColor Gray
        }
    } else {
        Write-Host ''
        Write-BdOk 'Nothing pending. 没有待处理的变更。'
    }

    Write-Host ''
    Write-Host 'The marker is hidden -- View > Show > Hidden items reveals it. 标记是隐藏的 -- 「查看 > 显示 > 隐藏的项目」可将其显示出来。' -ForegroundColor DarkGray
    Pause-BdIfInteractive -NoPause:$NoPause
    exit 0
}

# ------------------------------------------------------------------ unflag
# ------------------------------------------------------------------ 取消标记

if ($Unflag) {
    Write-Host ''

    # The marker can sit in any folder this tool has ever marked, so the list of
    # marked folders is the primary source, not just the applied and pending ones.
    # 标记可能落在本工具曾经标记过的任意目录里，所以已标记目录清单才是主要
    # 来源，而不只是已应用和待处理的那两个。
    $folders = New-Object System.Collections.Generic.List[string]
    foreach ($v in (Get-BdMarkers)) {
        if ($v -and -not ($folders -contains $v)) { $folders.Add($v) }
    }
    foreach ($name in @('current.txt', 'pending.txt')) {
        $v = Read-BdStateLine -Name $name
        if ($v -and -not ($folders -contains $v)) { $folders.Add($v) }
    }

    $hadPending = Test-Path -LiteralPath $pendingFile

    if ($folders.Count -eq 0) {
        Write-BdWarn 'No folder is flagged. 没有目录被标记。'
    }
    foreach ($f in $folders) {
        if (-not (Test-Path -LiteralPath $f)) {
            Write-BdWarn ('The flagged folder no longer exists: 已标记的目录不再存在：' + $f)
            continue
        }
        if (Remove-BdMarker -Folder $f) {
            Write-BdOk ('Marker removed from: 已从以下目录移除标记：' + $f)
        } else {
            Write-BdWarn ('No marker was found in: 在以下目录未找到标记：' + $f)
        }
    }
    if ($folders.Count -gt 0) { Write-BdOk 'Flag cleared. 标志已清除。' }
    Save-BdMarkers -Folders @()

    # Deleting pending.txt is also the cancel signal: a waiting helper notices it
    # is gone within a couple of seconds and stops, so nothing gets applied
    # behind your back later.
    # 删除 pending.txt 同时也是取消信号：等待中的 helper 会在几秒内发现它没了
    # 并停止，所以之后不会有东西在背后被应用。
    foreach ($p in @($stateFile, $pendingFile)) {
        if (Test-Path -LiteralPath $p) {
            try { Remove-Item -LiteralPath $p -Force -ErrorAction SilentlyContinue } catch { }
        }
    }
    if ($hadPending) { Write-BdInfo 'Any waiting change was cancelled. 任何等待中的变更都已取消。' }

    # A policy this tool set has to go too. Otherwise the flag would look
    # cleared while the browser stayed pinned to that folder by policy.
    # 本工具设置过的策略也必须一并移除。否则标志看起来已清除，浏览器却仍被策略
    # 钉在那个目录上。
    $browserFilter = $null
    if ($Browser -and ($Browser -ine 'auto')) { $browserFilter = $Browser }
    $info = Get-BdCurrentDownloadDir -BrowserName $browserFilter
    if ($info -and (Get-BdPolicyDirectory -BrowserName $info.Browser)) {
        if (Remove-BdPolicyDirectory -BrowserName $info.Browser) {
            Write-BdOk 'Download policy removed. 下载策略已移除。'
        } else {
            Write-BdWarn 'A download policy is still set and could not be removed. 下载策略仍处于设置状态，且无法移除。'
            Write-Host '  It needs an elevated window. Run: Set-DownloadFlag.ps1 -RemovePolicy 它需要已提权的窗口。请运行：Set-DownloadFlag.ps1 -RemovePolicy' -ForegroundColor Yellow
        }
    }
    if (Test-Path -LiteralPath $modeFile) {
        try { Remove-Item -LiteralPath $modeFile -Force -ErrorAction SilentlyContinue } catch { }
    }

    Write-Host ''
    Write-BdInfo 'The browser download location itself was not changed. 浏览器下载位置本身没有被更改。'
    # Log lines stay English-only: Get-BdLoggedTargets parses them with anchored
    # regexes, so any extra text would be captured as part of the folder path.
    # 日志内容保持纯英文：Get-BdLoggedTargets 用带行尾锚点的正则解析它们，多出
    # 的任何文字都会被当成路径的一部分捕获。
    Write-BdLog 'unflag requested'
    Pause-BdIfInteractive -NoPause:$NoPause
    exit 0
}

# ------------------------------------------------------------------ cleanup
# ------------------------------------------------------------------ 清理

if ($Cleanup) {
    Write-Host ''

    # The marker belongs in exactly one folder: the one currently flagged. That
    # is the pending folder if a change is still queued, otherwise the applied
    # one. Everything else is a leftover.
    # 标记只应存在于一个目录里：当前被标记的那个。若变更仍在排队，那就是待处理
    # 目录，否则就是已应用目录。其余的一切都是遗留。
    $keep = Read-BdStateLine -Name 'pending.txt'
    if (-not $keep) { $keep = Read-BdStateLine -Name 'current.txt' }

    # markers.txt is the normal source. current.txt and pending.txt cover a flag
    # set before markers.txt existed, and the log covers markers orphaned by the
    # old logic, which only ever cleaned the last applied folder.
    # markers.txt 是常规来源。current.txt 和 pending.txt 覆盖的是 markers.txt
    # 出现之前设置的标记，而日志覆盖的是被旧逻辑遗留成孤儿的标记，旧逻辑只会
    # 清理最后一次应用的目录。
    $folders = New-Object System.Collections.Generic.List[string]
    foreach ($f in (Get-BdMarkers)) {
        if ($f -and -not ($folders -contains $f)) { $folders.Add($f) }
    }
    foreach ($name in @('current.txt', 'pending.txt')) {
        $f = Read-BdStateLine -Name $name
        if ($f -and -not ($folders -contains $f)) { $folders.Add($f) }
    }
    foreach ($f in (Get-BdLoggedTargets)) {
        if ($f -and -not ($folders -contains $f)) { $folders.Add($f) }
    }

    if ($folders.Count -eq 0) {
        Write-BdWarn 'No folders are recorded, so there is nothing to clean. 没有记录任何目录，因此没有可清理的东西。'
        Pause-BdIfInteractive -NoPause:$NoPause
        exit 0
    }

    if ($keep) {
        Write-BdInfo ('The flag is on: 标志已开启：' + $keep)
        Write-BdInfo ('Checking ' + $folders.Count + ' folder(s) for leftover markers... 正在检查 ' + $folders.Count + ' 个目录是否有遗留标记...')
    } else {
        Write-BdInfo ('Checking ' + $folders.Count + ' folder(s) for leftover markers... 正在检查 ' + $folders.Count + ' 个目录是否有遗留标记...')
    }

    $removed = 0
    foreach ($f in $folders) {
        if ($keep -and ($f -ieq $keep)) { continue }
        if (-not (Test-Path -LiteralPath $f)) { continue }
        if (Remove-BdMarker -Folder $f) {
            Write-BdOk ('Marker removed from: 已从以下目录移除标记：' + $f)
            $removed++
        }
    }

    if ($keep) { Save-BdMarkers -Folders @($keep) } else { Save-BdMarkers -Folders @() }

    Write-Host ''
    if ($removed -gt 0) {
        Write-BdOk ('Removed ' + [string]$removed + ' leftover marker(s). 已移除 ' + [string]$removed + ' 个遗留标记。')
    } else {
        Write-BdInfo 'No leftover markers were found. 未发现遗留标记。'
    }
    Write-BdLog ('cleanup: removed ' + $removed + ' marker(s)')
    Pause-BdIfInteractive -NoPause:$NoPause
    exit 0
}

# ------------------------------------------------------------------ remove policy
# ------------------------------------------------------------------ 移除策略

if ($RemovePolicy) {
    Write-Host ''

    $browserFilter = $null
    if ($Browser -and ($Browser -ine 'auto')) { $browserFilter = $Browser }

    $info = Get-BdCurrentDownloadDir -BrowserName $browserFilter
    if (-not $info) {
        Write-BdErr 'No browser profile was found. 没有找到浏览器配置目录。'
        Pause-BdIfInteractive -NoPause:$NoPause
        exit 1
    }

    $policyRoot = Get-BdPolicyRegistryPath -BrowserName $info.Browser
    if (-not $policyRoot) {
        Write-BdWarn ($info.Browser + ' has no policy route in this tool; nothing to remove. 在本工具里没有策略通道；无需移除。')
        Pause-BdIfInteractive -NoPause:$NoPause
        exit 0
    }

    $before = Get-BdPolicyDirectory -BrowserName $info.Browser
    if (-not $before) {
        Write-BdInfo 'No download policy is set. Nothing to do. 没有设置下载策略。无需处理。'
        Pause-BdIfInteractive -NoPause:$NoPause
        exit 0
    }

    Write-BdInfo ('Removing the policy (it is currently forcing ' + $before + ')... 正在移除策略（它当前正强制指向 ' + $before + '）...')
    if (-not (Remove-BdPolicyDirectory -BrowserName $info.Browser)) {
        Write-BdErr 'Could not remove the policy -- it needs an elevated window. 无法移除策略 -- 它需要已提权的窗口。'
        Write-Host '  Right-click PowerShell, choose Run as administrator, then try again. 右键点击 PowerShell，选择「以管理员身份运行」，然后重试。' -ForegroundColor Yellow
        Write-BdLog 'removepolicy: denied'
        Pause-BdIfInteractive -NoPause:$NoPause
        exit 7
    }

    Write-BdOk 'Policy removed. 策略已移除。'
    Write-Host ''
    Write-BdWarn 'The browser falls back to the folder stored in its own settings. 浏览器会回退到它自己设置里存储的目录。'
    Write-Host ('  That is: 即：' + $info.Dir) -ForegroundColor Gray
    Write-Host '  To keep the folder the policy was forcing, pin it the normal way: 若要保留策略原本强制的目录，请用常规方式钉住它：' -ForegroundColor Gray
    Write-Host ('    Set-DownloadFlag.ps1 -Target "' + $before + '" -Mode file') -ForegroundColor Gray

    if (Test-Path -LiteralPath $modeFile) {
        try { Remove-Item -LiteralPath $modeFile -Force -ErrorAction SilentlyContinue } catch { }
    }
    Write-BdLog 'policy removed'
    Pause-BdIfInteractive -NoPause:$NoPause
    exit 0
}

# ------------------------------------------------------------------ set
# ------------------------------------------------------------------ 设置

Write-Host ''
Write-BdLog ('run started; target=' + $Target)

$Target = $Target.Trim()
if (-not (Test-Path -LiteralPath $Target -PathType Container)) {
    Write-BdErr ('Not a folder: 不是目录：' + $Target)
    Write-Host '  Pick an existing local folder. 请选择一个已存在的本地目录。' -ForegroundColor Gray
    Write-BdLog 'rejected: not a folder'
    Pause-BdIfInteractive -NoPause:$NoPause
    exit 1
}

$Target = (Resolve-Path -LiteralPath $Target).Path
Write-BdInfo ('Flag folder: 标记目录：' + $Target)

# Refuse a path that is itself a link. The browser would store the link, not the
# real folder, and the link's target could be changed out from under it later.
# 拒绝本身就是一个链接的路径。浏览器会存下链接而不是真实目录，而链接的目标
# 之后可能在它脚下被改掉。
try {
    $it = Get-Item -LiteralPath $Target -Force -ErrorAction Stop
    if (($it.Attributes -band [System.IO.FileAttributes]::ReparsePoint) -ne 0) {
        Write-BdErr 'That folder is a link, not a real folder. 该目录是一个链接，不是真实目录。'
        Write-Host '  Downloads can only be pointed at a real folder. 下载只能指向真实目录。' -ForegroundColor Yellow
        Write-BdLog 'rejected: target is a reparse point'
        Pause-BdIfInteractive -NoPause:$NoPause
        exit 1
    }
} catch { }

$browserFilter = $null
if ($Browser -and ($Browser -ine 'auto')) { $browserFilter = $Browser }

$info = Get-BdCurrentDownloadDir -BrowserName $browserFilter
if (-not $info) {
    Write-BdErr 'No browser profile was found to configure. 没有找到可配置的浏览器配置目录。'
    Write-Host '  Looked for Edge, Chrome and Brave under your local app data. 已在你的本地应用数据下查找 Edge、Chrome 和 Brave。' -ForegroundColor Gray
    Write-BdLog 'rejected: no browser profile found'
    Pause-BdIfInteractive -NoPause:$NoPause
    exit 1
}

$current = $info.Dir
Write-BdInfo ('The browser currently downloads into: 浏览器当前下载到：' + $current)
Write-BdInfo ('Browser: 浏览器：' + $info.Browser)

# --- already there? --------------------------------------------------------
# --- 已经指向那里？ --------------------------------------------------------
if ($current.TrimEnd('\') -ieq $Target.TrimEnd('\')) {
    Write-Host ''
    Write-BdOk 'The browser already downloads into that folder. 浏览器已经下载到该目录。'
    foreach ($stale in (Remove-BdOtherMarkers -Keep $Target)) {
        Write-BdInfo ('Marker removed from the previous folder: 已从上一个目录移除标记：' + $stale)
    }
    if (Set-BdMarker -Folder $Target -IconSource $iconSource) {
        Write-BdOk ('Marker placed in: 已在以下目录放置标记：' + $Target)
    } else {
        Write-BdWarn 'Marker could not be written (is flag.ico next to the script?). 标记无法写入（flag.ico 是否在脚本旁边？）。'
    }
    Save-BdMarkers -Folders @($Target)
    Write-BdText -Path $stateFile -Value $Target
    try { Remove-Item -LiteralPath $pendingFile -Force -ErrorAction SilentlyContinue } catch { }
    Write-BdLog ('already set: ' + $Target)
    Pause-BdIfInteractive -NoPause:$NoPause
    exit 0
}

# --- pick the route --------------------------------------------------------
# --- 选择通道 --------------------------------------------------------------
# The policy route is instant and needs no browser restart, but it locks the
# download location in the browser UI. The file route leaves the UI alone, but
# can only be written while the browser is fully closed. auto prefers the
# policy route when this window is elevated, and falls back to the file route
# otherwise -- which is the only thing that works on a locked-down machine.
# 策略通道即时生效且无需重启浏览器，但它会把下载位置锁在浏览器界面里。文件
# 通道不碰界面，但只能在浏览器完全关闭时写入。本窗口已提权时 auto 优先用策略
# 通道，否则回退到文件通道 -- 而这是在受管控的机器上唯一可行的办法。
$elevated   = Test-BdIsElevated
$policyRoot = Get-BdPolicyRegistryPath -BrowserName $info.Browser
$route      = 'file'

if ($Mode -eq 'policy') {
    if (-not $policyRoot) {
        Write-BdErr ($info.Browser + ' has no policy route in this tool. 在本工具里没有策略通道。')
        Write-Host '  Use -Mode file for the deferred Preferences write. 请用 -Mode file 走延迟的 Preferences 写入。' -ForegroundColor Yellow
        Pause-BdIfInteractive -NoPause:$NoPause
        exit 8
    }
    if (-not $elevated) {
        Write-BdErr 'The policy route needs an elevated window. 策略通道需要已提权的窗口。'
        Write-Host '  Right-click PowerShell, choose Run as administrator, then try again.' -ForegroundColor Yellow
        Write-Host '  Or drop -Mode policy to use the file route instead.' -ForegroundColor Yellow
        Write-Host '  右键点击 PowerShell，选择「以管理员身份运行」，然后重试；或者去掉 -Mode policy，改用文件通道。' -ForegroundColor Yellow
        Pause-BdIfInteractive -NoPause:$NoPause
        exit 7
    }
    $route = 'policy'
} elseif (($Mode -eq 'auto') -and $elevated -and $policyRoot) {
    $route = 'policy'
}

# --- move the marker first, so the folder is visibly flagged right away ----
# --- 先移动标记，这样目录立刻就能看出已被标记 ------------------------------
# This runs before anything that can fail, so a later problem still leaves the
# user able to see which folder they picked.
# 这一步在任何可能失败的操作之前运行，所以之后即使出问题，用户仍能看出自己
# 选的是哪个目录。
#
# Every folder this tool has ever marked is tracked in markers.txt, and the
# marker is taken out of all of them except this one. Looking only at the folder
# that was last APPLIED is not enough: while a change is queued that folder never
# advances, so each further flag used to leave the previous marker behind for
# good. That is what produced the leftover .ico files.
# 本工具曾经标记过的每一个目录都记录在 markers.txt 里，标记会从除本目录之外
# 的所有目录里移除。只看最后一次「成功应用」的目录是不够的：变更还在排队时
# 那个目录根本不前进，于是每再标记一次就把上一个标记永久遗留下来了。这正是
# 产生遗留 .ico 文件的原因。
foreach ($stale in (Remove-BdOtherMarkers -Keep $Target)) {
    Write-BdInfo ('Marker removed from the previous folder: 已从上一个目录移除标记：' + $stale)
}
if (Set-BdMarker -Folder $Target -IconSource $iconSource) {
    Write-BdOk ('Marker placed in: 已在以下目录放置标记：' + $Target)
} else {
    Write-BdWarn 'Marker could not be written (is flag.ico next to the script?). 标记无法写入（flag.ico 是否在脚本旁边？）。'
}
Save-BdMarkers -Folders @($Target)

# --- policy route: instant, nothing to wait for ----------------------------
# --- 策略通道：即时生效，无需等待 ------------------------------------------
if ($route -eq 'policy') {
    Write-Host ''
    Write-BdInfo 'Applying by policy... 正在通过策略应用...'

    if (-not (Set-BdPolicyDirectory -BrowserName $info.Browser -Dir $Target)) {
        Write-BdWarn 'The policy could not be written; using the file route instead. 策略无法写入；改用文件通道。'
        $route = 'file'
    } else {
        Write-BdOk ('Policy set: 策略已设置：' + $Target)
        Write-Host '  The browser applies this within a few seconds and does not have to be' -ForegroundColor Gray
        Write-Host '  closed. While the policy is set, the download location is locked in the' -ForegroundColor Gray
        Write-Host '  browser settings page.' -ForegroundColor Gray
        Write-Host '  浏览器会在几秒内应用它，无需关闭。策略生效期间，下载位置在浏览器设置页面里被锁定。' -ForegroundColor Gray

        Write-BdText -Path $stateFile -Value $Target
        Write-BdText -Path $modeFile  -Value 'policy'
        try { Remove-Item -LiteralPath $pendingFile -Force -ErrorAction SilentlyContinue } catch { }
        Write-BdLog ('policy set: ' + $Target)

        Write-Host ''
        Write-Host 'Check it with: 这样检查：' -ForegroundColor Green
        Write-Host '  edge://policy               -- DownloadDirectory should be listed    -- 应列出 DownloadDirectory' -ForegroundColor Gray
        Write-Host '  edge://settings/downloads   -- it will show the folder, greyed out    -- 它会显示该目录，且为灰色不可改' -ForegroundColor Gray
        Pause-BdIfInteractive -NoPause:$NoPause
        exit 0
    }
}

# --- file route: record the intent -----------------------------------------
# --- 文件通道：记录意图 ----------------------------------------------------
Write-BdText -Path $pendingFile -Value $Target
Write-BdText -Path $modeFile  -Value 'file'

# Remembered so the background helper knows whether it may terminate a leftover
# windowless browser process once every window is closed.
# 记住它，好让后台 helper 知道在所有窗口关闭后，它是否可以终止一个遗留的
# 无窗口浏览器进程。
$autoApply = 'on'
if ($WaitOnly) { $autoApply = 'off' }
Write-BdText -Path (Get-BdStateFile -Name 'autoapply.txt') -Value $autoApply

# --- queue the write -------------------------------------------------------
# --- 排队写入 --------------------------------------------------------------
$running  = Get-BdRunningCount
$appliers = @(Get-BdApplierProcesses).Count
$weClosed = $false

if ((-not $WaitOnly) -and ($running -gt 0)) {
    Write-Host ''
    Write-BdInfo ('Closing ' + $info.Browser + ' so the change can be written now... 正在关闭 ' + $info.Browser + ' 以便现在写入变更...')
    Write-Host '  Open windows get an ordinary close request first, so the session is saved.' -ForegroundColor Gray
    Write-Host '  Whatever is still running after that is terminated.' -ForegroundColor Gray
    Write-Host '  先给打开的窗口发送普通的关闭请求，所以会话得以保存。之后仍然存活的一切都会被终止。' -ForegroundColor Gray

    if (Test-BdDownloadInProgress -Folder $info.Dir) {
        Write-Host ''
        Write-BdWarn 'A download is in progress in the current folder. 当前目录里有一个下载正在进行。'
        Write-Host '  Closing the browser now will interrupt it. 现在关闭浏览器会打断它。' -ForegroundColor Yellow
    }

    # Take over from any helper that is already waiting. It holds the
    # single-instance lock, so leaving it alive would make this call hand back
    # "done" without having written anything, while the old helper applied the
    # change a moment later. pending.txt is untouched, so nothing is lost.
    # 接管任何已经在等待的 helper。它持有单实例锁，所以若让它继续活着，本次调用
    # 会在什么都没写的情况下返回「完成」，而旧 helper 稍后才应用变更。
    # pending.txt 不受影响，所以不会丢失任何东西。
    foreach ($a in Get-BdApplierProcesses) {
        try { Stop-Process -Id $a.ProcessId -Force -ErrorAction Stop } catch { }
    }

    # GraceSeconds only applies when a window is actually open -- it is the time
    # allowed for a clean, session-saving exit. With no window (Startup boost
    # only) nothing is waited for at all, which is the common case.
    # GraceSeconds 只在确实有窗口打开时才起作用 -- 它是允许一次干净、能保存
    # 会话的退出所用的时间。没有窗口时（只有「启动加速」）完全不等待，而这正是
    # 常见情况。
    if (-not (Stop-BdBrowserSafely -BrowserName $info.Browser -Force -GraceSeconds 5)) {
        Write-Host ''
        Write-BdErr 'The browser could not be closed, so nothing was changed. 浏览器无法关闭，所以没有任何更改。'
        Write-Host '  Close it by hand, then flag the folder again. 请手动关闭它，然后重新标记该目录。' -ForegroundColor Yellow
        Write-BdLog 'close: browser survived a forced close'
        Pause-BdIfInteractive -NoPause:$NoPause
        exit 7
    }

    $weClosed = $true
    $running  = 0
    Write-BdOk 'The browser is fully closed. 浏览器已完全关闭。'
}

if ($running -eq 0) {
    # Nothing to wait for -- apply it now, in this window, so any problem is
    # visible immediately rather than silently logged in the background.
    # 没什么可等的 -- 就在本窗口里立即应用，这样任何问题都能立刻看见，而不是
    # 在后台被悄悄记进日志。
    Write-Host ''
    Write-BdInfo 'Applying now... 正在应用...'
    Write-BdLog 'applying immediately'
    if (-not (Test-Path -LiteralPath $applierScript)) {
        Write-BdErr ('Missing helper: 缺少 helper：' + $applierScript)
        Pause-BdIfInteractive -NoPause:$NoPause
        exit 4
    }

    # Reopen only what we closed ourselves. If the browser was already shut, the
    # user meant it to stay shut.
    # 只重新打开我们自己关掉的东西。如果浏览器本来就是关着的，说明用户希望它
    # 保持关闭。
    $applierArgs = @{}
    if ($weClosed) { $applierArgs['Relaunch'] = $true } else { $applierArgs['NoRelaunch'] = $true }

    & $applierScript @applierArgs
    if ($LASTEXITCODE -ne 0) {
        Write-Host ''
        Write-BdErr 'Could not write the new location. See the log for the reason. 无法写入新位置。原因见日志。'
        Pause-BdIfInteractive -NoPause:$NoPause
        exit 6
    }
    Write-BdOk ('The browser now downloads into: 浏览器现在下载到：' + $Target)
} elseif ($appliers -gt 0) {
    Write-Host ''
    Write-BdInfo 'A helper is already waiting; it will pick up this folder. 已经有一个 helper 在等待；它会接手这个目录。'
    Write-BdLog ('queued behind a running helper; running=' + $running)
} else {
    Write-Host ''
    Write-BdWarn ('The browser is running (' + $running + ' processes).')
    Write-Host ('  浏览器正在运行（' + $running + ' 个进程）。') -ForegroundColor Gray
    Write-Host ''
    Write-Host '  It rewrites its own settings while it runs, so the change is saved and' -ForegroundColor Gray
    Write-Host '  applied the moment it has fully exited.' -ForegroundColor Gray
    Write-Host '  它在运行时重写自己的设置，所以变更会被保存，并在它完全退出的那一刻应用。' -ForegroundColor Gray
    Write-Host '  You do not need to do anything -- close the browser whenever you normally' -ForegroundColor Gray
    Write-Host '  would, and the change lands then.' -ForegroundColor Gray
    Write-Host '  你不需要做任何事 -- 照常关闭浏览器，变更届时落地。' -ForegroundColor Gray
    Write-Host ''

    if (-not (Test-Path -LiteralPath $applierScript)) {
        Write-BdErr ('Missing helper: 缺少 helper：' + $applierScript)
        Write-Host '  Close the browser and flag the folder again. 请关闭浏览器，然后重新标记该目录。' -ForegroundColor Yellow
        Write-BdLog 'applier script missing'
        Pause-BdIfInteractive -NoPause:$NoPause
        exit 4
    }

    try {
        $psExe = Join-Path -Path $env:SystemRoot -ChildPath 'System32\WindowsPowerShell\v1.0\powershell.exe'
        Start-Process -FilePath $psExe -WindowStyle Hidden -ArgumentList @(
            '-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', ('"' + $applierScript + '"')
        ) | Out-Null

        Start-Sleep -Milliseconds 400
        if (@(Get-BdApplierProcesses).Count -eq 0) {
            Write-BdWarn 'The helper did not stay running. helper 没有保持运行。'
            Write-Host '  The change is recorded but nothing will apply it automatically. 变更已被记录，但不会自动应用。' -ForegroundColor Yellow
            Write-Host '  Close the browser, then flag the folder again. 请关闭浏览器，然后重新标记该目录。' -ForegroundColor Yellow
            Write-BdLog 'applier launch did not stick'
            Pause-BdIfInteractive -NoPause:$NoPause
            exit 5
        }

        Write-BdOk 'A helper is now waiting in the background for the browser to exit. 现在有一个 helper 正在后台等待浏览器退出。'
        Write-BdLog ('queued; applier launched; running=' + $running)
    } catch {
        Write-BdWarn ('Could not start the helper: 无法启动 helper：' + $_.Exception.Message)
        Write-Host '  The change is recorded but nothing will apply it automatically. 变更已被记录，但不会自动应用。' -ForegroundColor Yellow
        Write-Host '  Close the browser, then flag the folder again. 请关闭浏览器，然后重新标记该目录。' -ForegroundColor Yellow
        Write-BdLog ('applier launch failed: ' + $_.Exception.Message)
        Pause-BdIfInteractive -NoPause:$NoPause
        exit 5
    }
}

Write-Host ''
Pause-BdIfInteractive -NoPause:$NoPause
exit 0
