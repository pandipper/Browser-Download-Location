# =============================================================================
#  Browser download folder -- shared helpers
#  浏览器下载目录 -- 共享辅助函数
# =============================================================================
#  Loaded by Set-DownloadFlag.ps1, Apply-PendingFlag.ps1 and
#  OpenBrowserDownload.ps1 through:
#  被 Set-DownloadFlag.ps1、Apply-PendingFlag.ps1 和 OpenBrowserDownload.ps1
#  通过下面这行加载：
#
#      . (Join-Path -Path $PSScriptRoot -ChildPath 'BrowserDownload.Common.ps1')
#
#  ENCODING: this file is UTF-8 WITH a BOM. PowerShell 5.1 only decodes UTF-8
#  correctly when it sees a BOM; without one it falls back to the ANSI code page
#  and every Chinese character below would turn to mojibake.
#  编码：本文件是「带 BOM 的 UTF-8」。PowerShell 5.1 只有在看到 BOM 时才会
#  按 UTF-8 解码，否则会退回 ANSI 代码页，下面所有中文都会变成乱码。
#
#  Strict mode is on deliberately. An earlier revision shipped with an undefined
#  $stateFile, which made -Show, -Unflag and every Set run abort with a
#  "cannot bind argument to parameter LiteralPath because it is null" error.
#  Strict mode turns that class of mistake into an immediate, obvious failure.
#  这里故意开启了严格模式。早期版本曾带着一个未定义的 $stateFile 发布，
#  导致 -Show、-Unflag 以及每次 Set 都以「无法将参数绑定到参数 LiteralPath，
#  因为该参数是空值」中止。严格模式让这类错误立刻、明显地暴露出来。
# =============================================================================

Set-StrictMode -Version 2.0

# ------------------------------------------------------------------ state
# ------------------------------------------------------------------ 状态

$script:BdStateDirName = 'BrowserDownloadFlag'
$script:BdLegacyStateDirName = 'EdgeDownloadFlag'

function Get-BdStateDir {
    # Returns the state folder and makes sure it exists.
    # 返回状态目录，并确保它存在。
    $d = Join-Path -Path $env:APPDATA -ChildPath $script:BdStateDirName
    if (-not (Test-Path -LiteralPath $d)) {
        New-Item -Path $d -ItemType Directory -Force | Out-Null
    }
    return $d
}

function Get-BdStateFile {
    param([string]$Name)
    return (Join-Path -Path (Get-BdStateDir) -ChildPath $Name)
}

function Initialize-BdState {
    # Carry a flag over from the folder the tool used when it was Edge-only.
    # 从本工具还只支持 Edge 时使用的目录里，把标记迁移过来。
    $current = Get-BdStateFile -Name 'current.txt'
    if (Test-Path -LiteralPath $current) { return }

    $legacy = Join-Path -Path $env:APPDATA -ChildPath ($script:BdLegacyStateDirName + '\current.txt')
    if (-not (Test-Path -LiteralPath $legacy)) { return }

    $v = Read-BdText -Path $legacy
    if ($v -and $v.Trim()) {
        Write-BdText -Path $current -Value $v.Trim()
        Write-BdLog 'carried the flag over from the previous state folder'
    }
}

# ------------------------------------------------------------------ text I/O
# ------------------------------------------------------------------ 文本读写

function Read-BdText {
    # Explicit UTF-8, and a leading BOM is dropped if one is present.
    # Get-Content -Raw only decodes UTF-8 when it finds a BOM, which is exactly
    # the kind of implicit behaviour a tool should not rely on for its own files.
    # 显式按 UTF-8 读取，若开头有 BOM 则去掉。
    # Get-Content -Raw 只有在发现 BOM 时才按 UTF-8 解码，而工具不应该对自己
    # 的文件依赖这种隐式行为。
    param([string]$Path)

    if (-not $Path) { return $null }
    if (-not (Test-Path -LiteralPath $Path)) { return $null }

    try {
        $t = [System.IO.File]::ReadAllText($Path, [System.Text.Encoding]::UTF8)
    } catch {
        return $null
    }
    if ($t.Length -gt 0 -and [int][char]$t[0] -eq 0xFEFF) { $t = $t.Substring(1) }
    return $t
}

function Write-BdText {
    # UTF-8 without a BOM -- the same way Chromium writes its own files.
    # 不带 BOM 的 UTF-8 -- 与 Chromium 写自己文件的方式一致。
    param([string]$Path, [string]$Value)

    $dir = Split-Path -Path $Path -Parent
    if ($dir -and -not (Test-Path -LiteralPath $dir)) {
        New-Item -Path $dir -ItemType Directory -Force | Out-Null
    }
    [System.IO.File]::WriteAllText($Path, [string]$Value, (New-Object System.Text.UTF8Encoding($false)))
}

function Read-BdStateLine {
    # One trimmed line of state, or $null. Never throws.
    # 读取状态文件里去空白后的一行，没有则返回 $null。从不抛异常。
    param([string]$Name)

    $t = Read-BdText -Path (Get-BdStateFile -Name $Name)
    if (-not $t) { return $null }
    $t = $t.Trim()
    if ($t) { return $t }
    return $null
}

function Write-BdLog {
    # NOTE: log lines are deliberately NOT translated. Get-BdLoggedTargets parses
    # them with anchored regexes such as 'target=(.+)$', so any extra text on the
    # line would be captured as part of the folder path and -Cleanup would then
    # chase folders that do not exist.
    # 注意：日志内容刻意不做翻译。Get-BdLoggedTargets 用 'target=(.+)$' 这类
    # 带行尾锚点的正则解析日志，行里多出任何文字都会被当成路径的一部分捕获，
    # 于是 -Cleanup 会去清理根本不存在的目录。
    param([string]$Message)
    try {
        $log = Get-BdStateFile -Name 'flag.log'
        Add-Content -LiteralPath $log -Value ((Get-Date -Format 'yyyy-MM-dd HH:mm:ss') + ' ' + $Message) -Encoding UTF8
    } catch { }
}

# ------------------------------------------------------------------ output
# ------------------------------------------------------------------ 输出

function Write-BdOk    { param([string]$m) Write-Host ('[OK]   ' + $m) -ForegroundColor Green }
function Write-BdInfo  { param([string]$m) Write-Host ('[info] ' + $m) -ForegroundColor Gray }
function Write-BdWarn  { param([string]$m) Write-Host ('[WARN] ' + $m) -ForegroundColor Yellow }
function Write-BdErr   { param([string]$m) Write-Host ('[FAIL] ' + $m) -ForegroundColor Red }

function Pause-BdIfInteractive {
    # Count down three seconds and let the window close itself.
    # 倒计时三秒，然后让窗口自行关闭。
    #
    # It used to wait for the Enter key. That is one keystroke too many for a
    # tool that is meant to be fire-and-forget from the right-click menu, and
    # the window then sat there until it was noticed.
    # 以前是等回车键。对一个从右键菜单「点完就走」的工具来说，这多了一次
    # 按键，而且窗口会一直杵在那里直到被人注意到。
    param([switch]$NoPause)

    if ($NoPause) { return }
    try {
        for ($i = 3; $i -ge 1; $i--) {
            Write-Host ("`r  Closing in $i s ...   $i 秒后自动关闭 ...  ") -NoNewline -ForegroundColor DarkGray
            Start-Sleep -Seconds 1
        }
        Write-Host ''
    } catch { }
}

# ------------------------------------------------------------------ JSON

function Get-BdJsonSection {
    # The substring of the JSON object whose key is $Key, or $null.
    # 取出键为 $Key 的那个 JSON 对象的子串，找不到则返回 $null。
    #
    # The key is matched as "key" followed by a colon and an opening brace, so a
    # *value* that happens to read "download", or a key such as "downloads",
    # cannot be mistaken for the object. Braces inside quoted strings are
    # skipped, and nested objects are handled.
    # 匹配的是「"key" 后跟冒号和左花括号」，因此一个恰好叫 "download" 的
    # *值*，或 "downloads" 这样的键，都不会被误认成该对象。引号内的花括号
    # 会被跳过，嵌套对象也能正确处理。
    param([string]$Text, [string]$Key)

    if (-not $Text) { return $null }

    $m = [regex]::Match($Text, '"' + [regex]::Escape($Key) + '"\s*:\s*\{')
    if (-not $m.Success) { return $null }
    $start = $m.Index + $m.Length - 1        # sitting on the '{'
                                             # 正好停在 '{' 上

    $depth = 0; $inStr = $false; $esc = $false
    for ($i = $start; $i -lt $Text.Length; $i++) {
        $c = $Text[$i]
        if ($inStr) {
            if ($esc)           { $esc = $false; continue }
            elseif ($c -eq '\') { $esc = $true; continue }
            elseif ($c -eq '"') { $inStr = $false; continue }
            continue
        }
        if ($c -eq '"')     { $inStr = $true; continue }
        elseif ($c -eq '{') { $depth++ }
        elseif ($c -eq '}') {
            $depth--
            if ($depth -eq 0) { return $Text.Substring($start, $i - $start + 1) }
        }
    }
    return $null
}

function Get-BdJsonString {
    # A string value for $Key inside a JSON object substring.
    # 在 JSON 对象子串里取出 $Key 对应的字符串值。
    param([string]$Section, [string]$Key)

    if (-not $Section) { return $null }
    $m = [regex]::Match($Section, '"' + [regex]::Escape($Key) + '"\s*:\s*"((?:[^"\\]|\\.)*)"')
    if (-not $m.Success) { return $null }
    return ($m.Groups[1].Value -replace '\\\\', '\' -replace '\\"', '"')
}

function ConvertTo-BdJsonEscaped {
    param([string]$Value)
    # Backslash first, then quote -- otherwise the backslashes added for the
    # quotes would be escaped a second time.
    # 先处理反斜杠，再处理引号 -- 否则为引号添加的反斜杠会被二次转义。
    $v = $Value -replace '\\', '\\'
    $v = $v -replace '"', '\"'
    return $v
}

function Set-BdDownloadDirInFile {
    # Rewrites default_directory inside the "download" object only, and returns
    # the new document, or $null when the object is not there.
    # 只重写 "download" 对象里的 default_directory，返回新文档；该对象不存在
    # 时返回 $null。
    #
    # Scoping matters: these profiles also carry a "savefile" object with its own
    # default_directory pointing somewhere else entirely, so a document-wide
    # replace would silently point downloads at the wrong folder.
    # 限定范围很重要：这些配置里还有一个 "savefile" 对象，它自己的
    # default_directory 指向完全不同的地方，所以全文档替换会悄悄把下载目录
    # 指错。
    param([string]$Text, [string]$Dir)

    $obj = Get-BdJsonSection -Text $Text -Key 'download'
    if (-not $obj) { return $null }

    $replacement = '"default_directory":"' + (ConvertTo-BdJsonEscaped $Dir) + '"'
    $rx = [regex]'"default_directory"\s*:\s*"(?:[^"\\]|\\.)*"'

    # Splice by hand rather than Regex.Replace: a replacement string has its own
    # $-substitution rules, and a path must be inserted literally.
    # 手工拼接而不用 Regex.Replace：替换串有自己的 $ 替换规则，而路径必须
    # 原样插入。
    $m = $rx.Match($obj)
    if ($m.Success) {
        $newObj = $obj.Substring(0, $m.Index) + $replacement + $obj.Substring($m.Index + $m.Length)
    } else {
        $newObj = '{' + $replacement + ',' + $obj.Substring(1)
    }

    $idx = $Text.IndexOf($obj)
    if ($idx -lt 0) { return $null }
    return $Text.Substring(0, $idx) + $newObj + $Text.Substring($idx + $obj.Length)
}

# ------------------------------------------------------------------ browsers
# ------------------------------------------------------------------ 浏览器

function Get-BdBrowsers {
    # Chromium-family browsers that actually have a profile on this machine,
    # ordered by likelihood of being the one in use.
    # 本机确实存在配置目录的 Chromium 系浏览器，按「正在被使用的可能性」排序。
    $defs = @(
        @{ Name = 'Edge';   Process = 'msedge'; Rel = 'Microsoft\Edge\User Data' },
        @{ Name = 'Chrome'; Process = 'chrome'; Rel = 'Google\Chrome\User Data' },
        @{ Name = 'Brave';  Process = 'brave';  Rel = 'BraveSoftware\Brave-Browser\User Data' }
    )

    $found = New-Object System.Collections.Generic.List[object]
    foreach ($d in $defs) {
        $root = Join-Path -Path $env:LOCALAPPDATA -ChildPath $d.Rel
        if (Test-Path -LiteralPath $root) {
            $found.Add([pscustomobject]@{ Name = $d.Name; Process = $d.Process; Root = $root })
        }
    }
    return $found
}

function Get-BdDefaultProfilePrefs {
    # Preferences paths to try, most likely first. Probing Default directly
    # avoids enumerating the profile directory on the common path.
    # 待尝试的 Preferences 路径，最可能的排在前面。直接探测 Default 可以
    # 避免在常见路径上枚举整个配置目录。
    param([string]$Root)

    $list = New-Object System.Collections.Generic.List[string]

    $p = Join-Path -Path $Root -ChildPath 'Default\Preferences'
    if (Test-Path -LiteralPath $p) {
        $list.Add($p)
        return $list
    }

    foreach ($d in @(Get-ChildItem -LiteralPath $Root -Directory -ErrorAction SilentlyContinue |
                     Where-Object { $_.Name -like 'Profile *' } | Sort-Object -Property Name)) {
        $q = Join-Path -Path $d.FullName -ChildPath 'Preferences'
        if (Test-Path -LiteralPath $q) { $list.Add($q) }
    }
    return $list
}

function Get-BdDownloadDirFromPrefs {
    param([string]$PrefsPath)

    $text = Read-BdText -Path $PrefsPath
    if (-not $text) { return $null }

    $dl = Get-BdJsonSection -Text $text -Key 'download'
    if (-not $dl) { return $null }

    # Deliberately no savefile fallback: savefile carries a different
    # default_directory on this machine, and borrowing it would point downloads
    # at the wrong folder without any obvious sign.
    # 刻意不回退到 savefile：本机上 savefile 带的是另一个 default_directory，
    # 借用它会把下载目录指错，而且没有任何明显迹象。
    return (Get-BdJsonString -Section $dl -Key 'default_directory')
}

function Get-BdCurrentDownloadDir {
    # -> [pscustomobject] @{ Browser; PrefsPath; Dir } for the first profile
    #    that has a download folder, or $null.
    # -> 第一个存在下载目录的配置所对应的
    #    [pscustomobject] @{ Browser; PrefsPath; Dir }；都没有则返回 $null。
    param([string]$BrowserName)

    foreach ($b in Get-BdBrowsers) {
        if ($BrowserName -and ($b.Name -ine $BrowserName)) { continue }
        foreach ($prefs in Get-BdDefaultProfilePrefs -Root $b.Root) {
            $dir = Get-BdDownloadDirFromPrefs -PrefsPath $prefs
            if ($dir) {
                return [pscustomobject]@{ Browser = $b.Name; PrefsPath = $prefs; Dir = $dir }
            }
        }
    }
    return $null
}

function Get-BdRunningCount {
    # 当前正在运行的浏览器进程总数。
    param([string]$BrowserName)

    $total = 0
    foreach ($b in Get-BdBrowsers) {
        if ($BrowserName -and ($b.Name -ine $BrowserName)) { continue }
        $total += @(Get-Process -Name $b.Process -ErrorAction SilentlyContinue).Count
    }
    return $total
}

function Get-BdApplierProcesses {
    # 正在等待的后台 helper 进程。
    try {
        return @(Get-CimInstance Win32_Process -Filter "Name='powershell.exe'" -ErrorAction SilentlyContinue |
                 Where-Object { $_.CommandLine -and ($_.CommandLine -like '*Apply-PendingFlag.ps1*') })
    } catch {
        return @()
    }
}

function Get-BdBrowserProcessName {
    # 浏览器对应的进程名，例如 Edge -> msedge。
    param([string]$BrowserName)
    foreach ($b in Get-BdBrowsers) {
        if ($b.Name -ieq $BrowserName) { return $b.Process }
    }
    return $null
}

function Get-BdBrowserProcesses {
    # Detailed view of what is running: which processes own a visible window,
    # which one is the browser process, and which was started by Startup boost.
    # 运行中进程的详细信息：哪些拥有可见窗口、哪一个是浏览器主进程、哪些是
    # 由「启动加速」拉起来的。
    #
    # Slower than Get-BdRunningCount -- one CIM query per process -- so it is used
    # by -Show only, never inside the waiting loop.
    # 比 Get-BdRunningCount 慢 -- 每个进程一次 CIM 查询 -- 所以只给 -Show 用，
    # 绝不放进等待循环里。
    param([string]$BrowserName)

    $result = New-Object System.Collections.Generic.List[object]
    $names = New-Object System.Collections.Generic.List[string]
    foreach ($b in Get-BdBrowsers) {
        if ($BrowserName -and ($b.Name -ine $BrowserName)) { continue }
        $names.Add($b.Process)
    }
    if ($names.Count -eq 0) { return $result }

    foreach ($p in @(Get-Process -Name $names.ToArray() -ErrorAction SilentlyContinue)) {
        $cmd = ''
        try {
            $c = Get-CimInstance Win32_Process -Filter ('ProcessId=' + $p.Id) -ErrorAction SilentlyContinue
            if ($c -and $c.CommandLine) { $cmd = $c.CommandLine }
        } catch { }

        $result.Add([pscustomobject]@{
            Id           = $p.Id
            HasWindow    = ($p.MainWindowHandle -ne 0)
            IsBrowser    = (($cmd -ne '') -and ($cmd -notlike '*--type=*'))
            StartupBoost = ($cmd -like '*--no-startup-window*')
        })
    }
    return $result
}

function Stop-BdBrowserSafely {
    # Closes the browser in two stages and returns $true once nothing is left.
    # 分两个阶段关闭浏览器，全部退出后返回 $true。
    #
    #   1. If -- and only if -- a process owns a visible window, ask it to close.
    #      That is an ordinary WM_CLOSE, so the browser saves its session and
    #      shuts down cleanly. A windowless browser is skipped entirely: there is
    #      nothing to save, so waiting would be dead time. See the note below.
    #   1. 当且仅当有进程拥有可见窗口时，请它关闭。这是一个普通的 WM_CLOSE，
    #      浏览器会保存会话并干净退出。完全没有窗口时直接跳过：没有东西需要
    #      保存，等待纯属浪费时间。详见下面的说明。
    #   2. Terminate whatever is still running.
    #   2. 终止仍然存活的一切。
    #
    # Without -Force only windowless survivors are terminated. Those are the
    # Startup boost process (launched at sign-in with --no-startup-window); a
    # windowless process cannot be holding unsaved work, so terminating it is
    # safe, and because a forced exit writes no settings, the old value in its
    # memory can no longer overwrite what we are about to plant. If a window is
    # still open after the grace period the function refuses and returns
    # $false, so a browser that ignores the close request is never killed out
    # from under the user.
    # 不带 -Force 时只终止没有窗口的残留进程。那些是「启动加速」进程（登录时
    # 以 --no-startup-window 拉起）。没有窗口的进程不可能持有未保存的工作，
    # 终止它是安全的；而且强杀不写任何设置，它内存里的旧值也无法再覆盖我们
    # 即将写入的新值。若宽限期结束后仍有窗口开着，本函数拒绝执行并返回
    # $false，因此不会在用户眼皮底下把无视关闭请求的浏览器杀掉。
    #
    # With -Force everything left is terminated, window or no window. That is
    # the default route for flagging a folder: the point of the tool is that one
    # right-click really does change the download folder, and a browser that
    # refuses to close would otherwise stall it for hours. A forced exit writes
    # no settings, so the stale value cannot come back either way.
    # 带 -Force 时，剩下的一切都会被终止，不管有没有窗口。这是标记目录时的
    # 默认路径：这个工具的意义就是「一次右键真的能改掉下载目录」，而一个
    # 拒绝关闭的浏览器会让它卡上好几个小时。强杀不写设置，所以无论哪种方式
    # 旧值都回不来。
    param([string]$BrowserName, [int]$GraceSeconds = 20, [switch]$Force)

    $procName = Get-BdBrowserProcessName -BrowserName $BrowserName
    if (-not $procName) { return $false }

    $windowed = @(Get-Process -Name $procName -ErrorAction SilentlyContinue |
                  Where-Object { $_.MainWindowHandle -ne 0 })

    # Wait ONLY when there is a window to close.
    # 只有在确实有窗口要关时才等待。
    #
    # A window is the only thing that can be holding unsaved work, so it is the
    # only reason to give the browser time. When every process is windowless --
    # the Startup boost case, measured on this machine at 0 windows and 11 to 22
    # processes -- there is nothing to save and nothing to ask: WM_CLOSE has no
    # window to reach, and those processes never exit on their own. Waiting for
    # them was pure dead time, and it was the single largest cost in the whole
    # tool: measured 10.5 s of every run spent waiting, then killed instantly.
    # 窗口是唯一可能持有未保存工作的东西，所以它也是唯一值得给浏览器时间的
    # 理由。当所有进程都没有窗口时 -- 即「启动加速」的情况，本机实测为
    # 0 个窗口、11 到 22 个进程 -- 既没有东西要保存，也没有对象可通知：
    # WM_CLOSE 找不到窗口，而那些进程永远不会自己退出。等它们纯属浪费，
    # 而且是整个工具里最大的一笔开销：实测每次运行白等 10.5 秒，然后一秒
    # 之内强杀。
    if ($windowed.Count -gt 0) {
        foreach ($p in $windowed) {
            try { [void]$p.CloseMainWindow() } catch { }
        }

        # Wait for the WINDOW to disappear, not for every process to exit.
        # 等的是「窗口消失」，而不是「所有进程退出」。
        #
        # The window is what holds the session, and it is saved as the window
        # goes. The remaining windowless processes are terminated below anyway,
        # so waiting for them here bought nothing and cost seconds: measured
        # 6 s per run when waiting on the process count, against ~1 s on the
        # window count.
        # 窗口才是会话的载体，窗口关掉会话就存好了。剩下的无窗口进程下面反正
        # 会被终止，在这里等它们毫无收益却要花掉好几秒：实测等进程数每次 6 秒，
        # 等窗口数只要约 1 秒。
        $deadline = (Get-Date).AddSeconds($GraceSeconds)
        while (((Get-BdWindowCount -BrowserName $BrowserName) -gt 0) -and ((Get-Date) -lt $deadline)) {
            Start-Sleep -Milliseconds 150
        }
        # Give the session a moment to finish being written before stopping it.
        # 给它一点时间把会话写完，再结束进程。
        if ((Get-BdWindowCount -BrowserName $BrowserName) -eq 0) {
            Start-Sleep -Milliseconds 400
        }
    }

    $left = @(Get-Process -Name $procName -ErrorAction SilentlyContinue)
    if ($left.Count -eq 0) { return $true }

    if (-not $Force) {
        $stillWindowed = @($left | Where-Object { $_.MainWindowHandle -ne 0 })
        if ($stillWindowed.Count -gt 0) { return $false }
    }

    foreach ($p in $left) {
        try { Stop-Process -Id $p.Id -Force -ErrorAction Stop } catch { }
    }

    $deadline = (Get-Date).AddSeconds(10)
    while (((Get-BdRunningCount -BrowserName $BrowserName) -gt 0) -and ((Get-Date) -lt $deadline)) {
        Start-Sleep -Milliseconds 150
    }

    return ((Get-BdRunningCount -BrowserName $BrowserName) -eq 0)
}

function Start-BdBrowser {
    # 重新打开浏览器。成功返回 $true，找不到可执行文件返回 $false。
    param([string]$Name)

    $rel = ''
    switch ($Name) {
        'Edge'   { $rel = 'Microsoft\Edge\Application\msedge.exe' }
        'Chrome' { $rel = 'Google\Chrome\Application\chrome.exe' }
        'Brave'  { $rel = 'BraveSoftware\Brave-Browser\Application\brave.exe' }
        default  { return $false }
    }

    $bases = @(
        [Environment]::GetEnvironmentVariable('ProgramFiles(x86)'),
        [Environment]::GetEnvironmentVariable('ProgramFiles'),
        $env:LOCALAPPDATA
    )

    $exe = $null
    foreach ($base in $bases) {
        if (-not $base) { continue }
        $cand = Join-Path -Path $base -ChildPath $rel
        if (Test-Path -LiteralPath $cand) { $exe = $cand; break }
    }
    if (-not $exe) { return $false }

    try {
        Start-Process -FilePath $exe | Out-Null
        return $true
    } catch {
        return $false
    }
}

# ------------------------------------------------------------------ policy
# ------------------------------------------------------------------ 策略

function Test-BdIsElevated {
    # 当前窗口是否已提权（管理员）。
    try {
        $id = [Security.Principal.WindowsIdentity]::GetCurrent()
        $pr = New-Object Security.Principal.WindowsPrincipal($id)
        return $pr.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
    } catch {
        return $false
    }
}

function Get-BdPolicyRegistryPath {
    # Registry roots for the DownloadDirectory policy.
    # DownloadDirectory 策略对应的注册表根路径。
    #
    # Edge and Chrome are documented with this exact layout:
    # Edge 与 Chrome 的官方文档就是这个结构：
    #   value name : DownloadDirectory            值名
    #   value type : REG_SZ                       类型
    #   mandatory  : SOFTWARE\Policies\Microsoft\Edge            强制
    #   recommended: SOFTWARE\Policies\Microsoft\Edge\Recommended 推荐
    #
    # Brave does publish a policy root of its own, but does not document
    # DownloadDirectory, so it is deliberately left on the file route rather
    # than guessed at.
    # Brave 确实有自己的策略根路径，但并未文档化 DownloadDirectory，所以刻意
    # 让它走文件通道，而不是去猜。
    param([string]$BrowserName)

    switch ($BrowserName) {
        'Edge'   { return 'HKLM:\SOFTWARE\Policies\Microsoft\Edge' }
        'Chrome' { return 'HKLM:\SOFTWARE\Policies\Google\Chrome' }
        default  { return $null }
    }
}

function Get-BdPolicyDirectory {
    # The folder the browser is currently being forced to use by policy, or
    # $null when no policy is set. Read-only, so it works unelevated.
    # 浏览器当前被策略强制使用的目录；没有设置策略时返回 $null。只读操作，
    # 因此未提权也能用。
    param([string]$BrowserName)

    $root = Get-BdPolicyRegistryPath -BrowserName $BrowserName
    if (-not $root) { return $null }

    try {
        $v = Get-ItemProperty -Path $root -Name 'DownloadDirectory' -ErrorAction Stop
        $dir = [string]$v.DownloadDirectory
        if ($dir) { return $dir }
        return $null
    } catch {
        return $null
    }
}

function Set-BdPolicyDirectory {
    # Writes the mandatory policy. Needs an elevated process; returns $false
    # rather than throwing so the caller can fall back to the file route.
    # 写入强制策略。需要已提权的进程；失败时返回 $false 而不抛异常，以便调用
    # 方回退到文件通道。
    #
    # Mandatory, not recommended, on purpose: a recommended policy only supplies
    # a default, and an existing user value in Preferences wins over it. Since
    # this tool has already written that value, a recommended policy would be
    # silently ignored.
    # 故意用「强制」而不是「推荐」：推荐策略只提供一个默认值，而 Preferences
    # 里已有的用户值会覆盖它。由于本工具恰好写过那个值，推荐策略会被静默忽略。
    param([string]$BrowserName, [string]$Dir)

    $root = Get-BdPolicyRegistryPath -BrowserName $BrowserName
    if (-not $root) { return $false }

    try {
        if (-not (Test-Path -Path $root)) {
            New-Item -Path $root -Force -ErrorAction Stop | Out-Null
        }
        New-ItemProperty -Path $root -Name 'DownloadDirectory' -Value $Dir `
            -PropertyType String -Force -ErrorAction Stop | Out-Null
        return $true
    } catch {
        Write-BdLog ('policy write failed: ' + $_.Exception.Message)
        return $false
    }
}

function Remove-BdPolicyDirectory {
    # Removes only the value this tool writes, and leaves the key itself alone so
    # any unrelated policy already on the machine survives. Returns $true when no
    # policy value is left behind.
    # 只删除本工具写入的那个值，保留键本身，这样机器上其它无关策略不会受
    # 影响。确认没有残留策略值时返回 $true。
    param([string]$BrowserName)

    $root = Get-BdPolicyRegistryPath -BrowserName $BrowserName
    if (-not $root) { return $true }
    if (-not (Test-Path -Path $root)) { return $true }

    try {
        $existing = Get-ItemProperty -Path $root -Name 'DownloadDirectory' -ErrorAction SilentlyContinue
        if ($null -eq $existing) { return $true }
        Remove-ItemProperty -Path $root -Name 'DownloadDirectory' -Force -ErrorAction Stop
        return $true
    } catch {
        Write-BdLog ('policy remove failed: ' + $_.Exception.Message)
        return $false
    }
}

function Get-BdWindowCount {
    # How many browser processes currently own a visible top-level window.
    # Cheap: no CIM query, so it is safe to call from the waiting loop.
    # 当前拥有可见顶层窗口的浏览器进程数。开销很小：不做 CIM 查询，因此可以
    # 安全地在等待循环里调用。
    param([string]$BrowserName)

    $procName = Get-BdBrowserProcessName -BrowserName $BrowserName
    if (-not $procName) { return 0 }
    try {
        return @(Get-Process -Name $procName -ErrorAction SilentlyContinue |
                 Where-Object { $_.MainWindowHandle -ne 0 }).Count
    } catch {
        return 0
    }
}

function Test-BdDownloadInProgress {
    # A half-written download sits in the download folder as *.crdownload.
    # Nothing may terminate the browser while one is there.
    # 未写完的下载会以下载目录里的 *.crdownload 形式存在。只要有它在，就不
    # 能终止浏览器。
    param([string]$Folder)

    if (-not $Folder) { return $false }
    if (-not (Test-Path -LiteralPath $Folder -PathType Container)) { return $false }
    try {
        return (@(Get-ChildItem -LiteralPath $Folder -Filter '*.crdownload' -Force -ErrorAction SilentlyContinue).Count -gt 0)
    } catch {
        return $false
    }
}

# ------------------------------------------------------------------ marker
# ------------------------------------------------------------------ 标记文件

function Get-BdMarkers {
    # Every folder this tool has put a marker in.
    # 本工具放过标记文件的每一个目录。
    #
    # This list is what stops markers from piling up. Tracking only the folder
    # that was last *applied* is not enough: while a change is still queued the
    # applied folder never advances, so each new flag used to leave the previous
    # marker behind for good.
    # 这份清单正是防止标记堆积的关键。只跟踪最后一次「成功应用」的目录是不够
    # 的：变更还在排队时，已应用目录根本不会前进，于是每标记一次就把上一个
    # 标记永久遗留下来了。
    $path = Get-BdStateFile -Name 'markers.txt'
    $list = New-Object System.Collections.Generic.List[string]
    $text = Read-BdText -Path $path
    if (-not $text) { return $list }

    foreach ($line in ($text -split "`r?`n")) {
        $t = $line.Trim()
        if ($t -and -not ($list -contains $t)) { $list.Add($t) }
    }
    return $list
}

function Save-BdMarkers {
    # 写入标记目录清单；清单为空时直接删除该文件。
    param([string[]]$Folders)

    $path = Get-BdStateFile -Name 'markers.txt'
    $clean = New-Object System.Collections.Generic.List[string]
    foreach ($f in $Folders) {
        $t = ''
        if ($f) { $t = $f.Trim() }
        if ($t -and -not ($clean -contains $t)) { $clean.Add($t) }
    }
    if ($clean.Count -eq 0) {
        try { Remove-Item -LiteralPath $path -Force -ErrorAction SilentlyContinue } catch { }
        return
    }
    Write-BdText -Path $path -Value (($clean.ToArray()) -join "`r`n")
}

function Get-BdLoggedTargets {
    # Every folder named in the log. Only used by -Cleanup, to reach markers
    # that were orphaned before markers.txt existed.
    # 日志里出现过的每一个目录。只给 -Cleanup 用，用来够到 markers.txt 出现
    # 之前就已孤儿化的标记。
    $path = Get-BdStateFile -Name 'flag.log'
    $text = Read-BdText -Path $path
    $list = New-Object System.Collections.Generic.List[string]
    if (-not $text) { return $list }

    foreach ($rx in @('target=(.+)$', 'policy set: (.+)$', 'SUCCESS \[.*\] -> \[(.+)\]$')) {
        foreach ($m in [regex]::Matches($text, $rx, [System.Text.RegularExpressions.RegexOptions]::Multiline)) {
            $t = $m.Groups[1].Value.Trim()
            if ($t -and -not ($list -contains $t)) { $list.Add($t) }
        }
    }
    return $list
}

function Remove-BdOtherMarkers {
    # Takes the marker out of every recorded folder except $Keep, and returns
    # the folders it cleaned.
    # 从所有已登记目录里移除标记文件，$Keep 除外；返回被清理的目录清单。
    param([string]$Keep)

    $cleaned = New-Object System.Collections.Generic.List[string]
    foreach ($f in Get-BdMarkers) {
        if (-not $f) { continue }
        if ($f -ieq $Keep) { continue }
        if (Remove-BdMarker -Folder $f) { $cleaned.Add($f) }
    }
    return $cleaned
}

function Get-BdMarkerName {
    # "browser-download-location.ico" -- the marker file name.
    # 「浏览器下载位置.ico」-- 标记文件的文件名。
    #
    # Kept as codepoints on purpose, and NOT turned into a literal. This name is
    # baked into markers that already exist on disk, so it must stay
    # byte-for-byte identical; building it from character codes makes that
    # guaranteed regardless of how this file is saved or transferred.
    # 故意保留码点写法，不改成字面量。这个名字已经固化在磁盘上现有的标记文件
    # 里，必须逐字节完全一致；用字符码拼装可以保证这一点，无论本文件如何保存
    # 或传输。
    #   6D4F liu  89C8 lan  5668 qi  4E0B xia  8F7D zai  4F4D wei  7F6E zhi
    $leaf = -join ([char]0x6D4F, [char]0x89C8, [char]0x5668,
                   [char]0x4E0B, [char]0x8F7D, [char]0x4F4D, [char]0x7F6E)
    return ($leaf + '.ico')
}

function Set-BdMarker {
    # Copies the flag icon in and hides it. Returns $true when a marker is in
    # place afterwards.
    # 把标记图标复制进去并隐藏。完成时该目录里有标记则返回 $true。
    param([string]$Folder, [string]$IconSource)

    if (-not (Test-Path -LiteralPath $Folder)) { return $false }
    $m = Join-Path -Path $Folder -ChildPath (Get-BdMarkerName)

    if (-not (Test-Path -LiteralPath $m)) {
        if (-not (Test-Path -LiteralPath $IconSource)) { return $false }
        try { Copy-Item -LiteralPath $IconSource -Destination $m -Force -ErrorAction Stop }
        catch { return $false }
    }

    # Hidden, so it does not clutter the folder or get swept up by Ctrl+A.
    # 设为隐藏，既不弄乱目录，也不会被 Ctrl+A 全选带走。
    try {
        $it = Get-Item -LiteralPath $m -Force
        $it.Attributes = $it.Attributes -bor [System.IO.FileAttributes]::Hidden
    } catch { }
    return $true
}

function Remove-BdMarker {
    # 删除标记文件。成功删除返回 $true，本来就不存在返回 $false。
    param([string]$Folder)

    if (-not $Folder) { return $false }
    $m = Join-Path -Path $Folder -ChildPath (Get-BdMarkerName)
    if (-not (Test-Path -LiteralPath $m)) { return $false }

    try { (Get-Item -LiteralPath $m -Force).Attributes = 'Normal' } catch { }
    try { Remove-Item -LiteralPath $m -Force -ErrorAction Stop; return $true }
    catch { return $false }
}
