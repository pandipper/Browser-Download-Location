<#
.SYNOPSIS
    Background helper: writes the pending download folder once the browser exits.
    后台辅助脚本：浏览器退出后写入待应用的下载目录。

.DESCRIPTION
    Started by Set-DownloadFlag.ps1 when the browser is running. It does nothing
    but sleep until every process of the target browser has gone, then writes the
    new path into that browser's Preferences file, verifies the result by reading
    it back, and reopens the browser if it was open when the folder was flagged.
    当浏览器正在运行时，由 Set-DownloadFlag.ps1 启动。它只做一件事：一直休眠，
    直到目标浏览器的所有进程都消失，然后把新路径写入该浏览器的 Preferences
    文件，读回来验证结果，并在标记目录时浏览器原本开着的情况下把它重新打开。

    WHY THIS EXISTS
    为什么需要它

    The browser keeps download.default_directory in memory and rewrites the file
    on its own schedule, so a write only survives while no browser process
    exists. Demanding that the user force the browser closed is impractical --
    its background processes linger for hours -- so this helper waits for a
    natural exit instead.
    浏览器把 download.default_directory 保存在内存里，并按自己的节奏重写文件，
    所以写入只有在没有任何浏览器进程时才留得住。要求用户强制关闭浏览器并不现实
    -- 它的后台进程会逗留好几个小时 -- 因此这个辅助脚本改为等待自然退出。

    CANCELLING
    取消

    pending.txt is the single source of truth. Deleting it (which -Unflag does)
    is the cancel signal: this helper notices within a couple of seconds and
    stops without writing anything.
    pending.txt 是唯一的事实来源。删除它（-Unflag 就会这么做）就是取消信号：本
    辅助脚本会在几秒内察觉，然后什么都不写就停止。

    Only the latest intent matters. Every right-click rewrites pending.txt, and
    the helper re-reads it at the moment it applies, so the newest folder always
    wins no matter how many times you flagged in between.
    只有最新的意图有效。每次右键都会重写 pending.txt，而辅助脚本在应用的那一刻
    会重新读取它，所以无论期间你标记了多少次，最新的目录总是胜出。

.PARAMETER NoRelaunch
    Do not reopen the browser afterwards. Used when Set-DownloadFlag.ps1 applies
    the change itself because the browser was already closed.
    之后不重新打开浏览器。用于 Set-DownloadFlag.ps1 自己应用变更的情况，因为
    浏览器当时已经关闭。

.PARAMETER Relaunch
    Always reopen the browser afterwards, even though nothing was running when
    this helper started. Used when the caller closed the browser itself and
    wants it reopened once the new folder has been written.
    之后总是重新打开浏览器，即使本辅助脚本启动时没有任何进程在运行。用于调用方
    自己关闭了浏览器、并希望在写入新目录后重新打开它的情形。

.NOTES
    UTF-8 source with a BOM. The marker file name is assembled from character codes.
    带 BOM 的 UTF-8 源码。标记文件名由字符码拼装而成。
#>

param(
    [switch]$NoRelaunch,
    [switch]$Relaunch
)

$ErrorActionPreference = 'Stop'

$scriptRoot = $PSScriptRoot
if (-not $scriptRoot) { $scriptRoot = Split-Path -Parent $MyInvocation.MyCommand.Definition }

$commonPath = Join-Path -Path $scriptRoot -ChildPath 'BrowserDownload.Common.ps1'
if (-not (Test-Path -LiteralPath $commonPath)) { exit 1 }
. $commonPath

Initialize-BdState
$pendingFile = Get-BdStateFile -Name 'pending.txt'
$stateFile   = Get-BdStateFile -Name 'current.txt'

# --- single instance -------------------------------------------------------
# --- 单实例 ----------------------------------------------------------------
# Each right-click used to spawn another hidden helper that polled for up to 12
# hours, so they piled up. A named mutex keeps exactly one alive; a late arrival
# exits immediately because the running one re-reads pending.txt anyway.
# 以前每次右键都会再拉起一个隐藏的辅助进程，最多轮询 12 个小时，于是越堆越多。
# 用一个具名互斥体保证只有一个存活；迟到的那个会立即退出，因为正在运行的那个
# 反正会重新读取 pending.txt。
$mutex = New-Object System.Threading.Mutex($false, 'Local\BrowserDownloadApplier')
$owned = $false
try {
    $owned = $mutex.WaitOne(0)
} catch [System.Threading.AbandonedMutexException] {
    $owned = $true                      # previous holder died; we own it now
                                        # 上一个持有者已死；现在归我们持有
} catch {
    $owned = $false
}
if (-not $owned) {
    # Log lines are never translated. Get-BdLoggedTargets parses them with anchored
    # regexes such as 'target=(.+)$', so any extra text would be captured as part
    # of the folder path and -Cleanup would then chase folders that do not exist.
    # 日志内容一律不翻译。Get-BdLoggedTargets 用 'target=(.+)$' 这类带行尾锚点的
    # 正则解析日志，多出的任何文字都会被当成路径的一部分捕获，于是 -Cleanup 会去
    # 清理根本不存在的目录。
    Write-BdLog 'applier: another helper is already waiting; exiting'
    try { $mutex.Dispose() } catch { }
    exit 0
}

try {
    $info = Get-BdCurrentDownloadDir
    if (-not $info) {
        Write-BdLog 'applier: no browser profile found; exiting'
        exit 1
    }

    # --- wait for the target browser to be gone ----------------------------
    # --- 等待目标浏览器消失 ------------------------------------------------
    $already = Get-BdRunningCount -BrowserName $info.Browser
    if ($already -gt 0) {
        Write-BdLog ('applier: waiting for ' + $info.Browser + ' to exit (' + $already + ' processes)')
    } else {
        Write-BdLog ('applier: ' + $info.Browser + ' is already closed')
    }

    $autoApply = Read-BdStateLine -Name 'autoapply.txt'
    if (-not $autoApply) { $autoApply = 'on' }
    $autoApplyOn = ($autoApply -ine 'off')

    # How long a windowless browser process is left alone after the last window
    # closes. Startup boost keeps one alive indefinitely and it holds the OLD
    # folder in memory, so waiting for it to exit by itself means waiting
    # forever -- which is exactly why "I closed the browser" used to do nothing.
    # A windowless process cannot be holding unsaved work, and a forced exit
    # writes no settings, so terminating it is both safe and what stops it from
    # overwriting the new value later.
    # 最后一个窗口关闭后，无窗口的浏览器进程会被放任多久。启动加速会一直保活一个
    # 进程，而且它内存里握着旧目录，所以等它自己退出等于永远等下去 -- 这正是
    # 「我关了浏览器」过去毫无效果的原因。无窗口的进程不可能持有未保存的工作，
    # 而且强杀不写任何设置，因此终止它既安全，又能阻止它稍后覆盖新值。
    $graceSeconds    = 30
    $windowsClosedAt = $null
    $hadWindow       = $false
    $deadline        = (Get-Date).AddHours(24)

    # When the caller already closed the browser -- which is the normal route --
    # there is nothing to wait for, so the first pass only confirms it briefly.
    # The long poll is for the -WaitOnly case, where we really are waiting for a
    # natural exit. Sleeping a flat 2 s twice added ~4 s to every single run.
    # 当调用方已经关闭浏览器时 -- 这是常规路径 -- 就没什么可等的，所以第一轮只做
    # 一次简短确认。长轮询是给 -WaitOnly 情况用的，那时我们确实在等自然退出。
    # 固定睡两次 2 秒会给每次运行都加上约 4 秒。
    $tickMs = 400
    if ($already -gt 0) { $tickMs = 2000 }

    while ($true) {
        Start-Sleep -Milliseconds $tickMs
        $tickMs = 2000

        if (-not (Test-Path -LiteralPath $pendingFile)) {
            Write-BdLog 'applier: pending change was cancelled; exiting'
            exit 0
        }
        if ((Get-Date) -gt $deadline) {
            Write-BdLog 'applier: gave up after 24 hours; nothing was written'
            exit 1
        }

        $running = Get-BdRunningCount -BrowserName $info.Browser
        if ($running -eq 0) {
            # Confirm: a browser can respawn for a moment while it shuts down.
            # 确认一下：浏览器在关闭过程中可能短暂地重新拉起进程。
            Start-Sleep -Milliseconds 400
            if ((Get-BdRunningCount -BrowserName $info.Browser) -eq 0) { break }
            continue
        }

        $windows = Get-BdWindowCount -BrowserName $info.Browser
        if ($windows -gt 0) {
            $hadWindow = $true
            $windowsClosedAt = $null
            continue
        }

        # Windows are all shut but processes remain. Only touch them when the
        # user has not asked for a plain wait, and never while a download is
        # still being written.
        # 窗口全关了但进程还在。只有当用户没有要求「单纯等待」时才动它们，并且在
        # 下载仍在写入时绝不动。
        if (-not $autoApplyOn) { continue }

        if ($null -eq $windowsClosedAt) {
            $windowsClosedAt = Get-Date
            Write-BdLog ('applier: no window left, ' + $running + ' background process(es); ' + $graceSeconds + 's grace')
            continue
        }
        if (((Get-Date) - $windowsClosedAt).TotalSeconds -lt $graceSeconds) { continue }

        if (Test-BdDownloadInProgress -Folder $info.Dir) {
            Write-BdLog 'applier: a download is in progress; leaving the browser alone'
            $windowsClosedAt = Get-Date        # restart the countdown and keep waiting
                                               # 重新开始倒计时并继续等待
            continue
        }

        $procName = Get-BdBrowserProcessName -BrowserName $info.Browser
        Write-BdLog ('applier: closing ' + $running + ' windowless process(es)')
        foreach ($p in @(Get-Process -Name $procName -ErrorAction SilentlyContinue)) {
            try { Stop-Process -Id $p.Id -Force -ErrorAction Stop } catch { }
        }

        $stopAt = (Get-Date).AddSeconds(15)
        while (((Get-BdRunningCount -BrowserName $info.Browser) -gt 0) -and ((Get-Date) -lt $stopAt)) {
            Start-Sleep -Milliseconds 300
        }
        if ((Get-BdRunningCount -BrowserName $info.Browser) -eq 0) { break }
        $windowsClosedAt = $null
    }

    Write-BdLog ($info.Browser + ' is fully closed')

    # --- apply ------------------------------------------------------------
    # --- 应用 --------------------------------------------------------------
    $target = Read-BdStateLine -Name 'pending.txt'
    if (-not $target) {
        Write-BdLog 'applier: no pending target; exiting'
        exit 0
    }

    if (-not (Test-Path -LiteralPath $info.PrefsPath)) {
        Write-BdLog 'applier: profile not found; aborted'
        exit 1
    }

    $before = Get-BdDownloadDirFromPrefs -PrefsPath $info.PrefsPath
    Write-BdLog ('applier: current=' + $before + ' -> target=' + $target)

    try {
        $text = Read-BdText -Path $info.PrefsPath
        if (-not $text) { Write-BdLog 'applier: profile could not be read; aborted'; exit 1 }

        $updated = Set-BdDownloadDirInFile -Text $text -Dir $target
        if (-not $updated) {
            Write-BdLog 'applier: could not locate the download object; aborted'
            exit 1
        }

        # Validate before it touches the real file: it must parse.
        # 在动真正的文件之前先校验：它必须能解析。
        $null = ($updated | ConvertFrom-Json)

        Copy-Item -LiteralPath $info.PrefsPath -Destination ($info.PrefsPath + '.flagbak') -Force

        # No BOM: that is what Chromium itself writes, and a BOM would make the
        # whole profile fail to parse.
        # 不带 BOM：这正是 Chromium 自己写入的方式，带 BOM 会让整个配置文件解析失败。
        [System.IO.File]::WriteAllText($info.PrefsPath, $updated, (New-Object System.Text.UTF8Encoding($false)))
    } catch {
        Write-BdLog ('applier: write failed: ' + $_.Exception.Message)
        exit 1
    }

    # --- verify by reading it back from disk -------------------------------
    # --- 从磁盘读回来验证 --------------------------------------------------
    $after = Get-BdDownloadDirFromPrefs -PrefsPath $info.PrefsPath
    if ($after -ne $target) {
        Write-BdLog ('applier: verify failed, reads back as [' + $after + ']')
        if (Test-Path -LiteralPath ($info.PrefsPath + '.flagbak')) {
            try { Copy-Item -LiteralPath ($info.PrefsPath + '.flagbak') -Destination $info.PrefsPath -Force } catch { }
            Write-BdLog 'applier: rolled back to the backup'
        }
        exit 1
    }

    Write-BdLog ('applier: SUCCESS [' + $before + '] -> [' + $after + ']')

    # --- tidy up state -----------------------------------------------------
    # --- 整理状态 ----------------------------------------------------------
    foreach ($stale in (Remove-BdOtherMarkers -Keep $target)) {
        Write-BdLog ('applier: marker removed from ' + $stale)
    }
    Save-BdMarkers -Folders @($target)

    try { Remove-Item -LiteralPath $pendingFile -Force -ErrorAction SilentlyContinue } catch { }
    Write-BdText -Path $stateFile -Value $target

    # --- reopen ------------------------------------------------------------
    # --- 重新打开 ----------------------------------------------------------
    # Only when a window was actually open at some point. If the browser was
    # already down to background processes, reopening it would pop up a window
    # the user had deliberately closed.
    # 仅当此前确实开过窗口时才重新打开。如果浏览器当时已经只剩后台进程，重新打开
    # 会弹出一个用户本来特意关掉的窗口。
    if ($Relaunch -or ($hadWindow -and (-not $NoRelaunch))) {
        if (Start-BdBrowser -Name $info.Browser) {
            Write-BdLog ('applier: ' + $info.Browser + ' reopened')
        } else {
            Write-BdLog 'applier: reopen failed (executable not found)'
        }
    }

    exit 0
} finally {
    if ($owned) { try { $mutex.ReleaseMutex() } catch { } }
    try { $mutex.Dispose() } catch { }
}
