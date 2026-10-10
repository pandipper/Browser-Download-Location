# Creates the desktop shortcut for opening the browser download folder.
# 创建用于打开浏览器下载目录的桌面快捷方式。
# ASCII-only source: the Chinese shortcut name is built from char codes so the
# file survives any code page. Kept at an ASCII path for the same reason.
# 源码只用 ASCII：中文快捷方式名由字符码拼装，因此文件能扛住任何代码页。
# 出于同样原因，文件也放在 ASCII 路径下。
#
# Uses WScript.Shell COM, which is the supported way to author a .lnk and
# produces a file Explorer always accepts (a hand-built PIDL is not reliable).
# 使用 WScript.Shell COM，这是创建 .lnk 的受支持方式，产出的文件资源管理器
# 总能接受（手工拼装 PIDL 并不可靠）。
#
# Order matters: create the new shortcut FIRST, verify it, and only then remove
# the stale one. Deleting up front would leave the desktop empty if anything
# below throws.
# 顺序很重要：先创建新快捷方式，验证它，然后才移除旧的。如果一上来就删除，
# 下面任何一步抛异常都会让桌面变空。

$ErrorActionPreference = 'Stop'

# The shortcut name built below reads "打开浏览器下载文件夹".
# 下面拼装出的快捷方式名是「打开浏览器下载文件夹」。
$name = -join ([char]0x6253, [char]0x5F00, [char]0x6D4F, [char]0x89C8, [char]0x5668,
               [char]0x4E0B, [char]0x8F7D, [char]0x6587, [char]0x4EF6, [char]0x5939)

$script = Join-Path $PSScriptRoot 'OpenBrowserDownload.ps1'
if (-not (Test-Path -LiteralPath $script)) {
    Write-Host "ERROR: OpenBrowserDownload.ps1 not found next to this file. 错误：本文件旁边找不到 OpenBrowserDownload.ps1。" -ForegroundColor Red
    Write-Host "Expected: $script. 应为：$script。" -ForegroundColor Yellow
    exit 1
}

$desktop = [Environment]::GetFolderPath('Desktop')
$lnk = Join-Path $desktop ($name + '.lnk')

# Build into a staging shortcut first, so a failure never leaves the desktop
# empty. Explorer refuses to overwrite a .lnk whose Properties window is open.
# 先构建到一个暂存快捷方式，这样失败时绝不会让桌面变空。资源管理器会拒绝
# 覆盖属性窗口正开着的 .lnk。
#
# The staging name MUST still end in .lnk -- WScript.Shell.CreateShortcut
# rejects anything else with "The shortcut path must end with .lnk or .url".
# It lives in TEMP so it cannot collide with a locked desktop shortcut.
# 暂存文件名仍然必须以 .lnk 结尾 -- 否则 WScript.Shell.CreateShortcut 会报
# 「The shortcut path must end with .lnk or .url」。它放在 TEMP 里，因此不会
# 与锁定的桌面快捷方式冲突。
$staged = Join-Path -Path $env:TEMP -ChildPath 'BrowserDownloadShortcut.lnk'

if (Test-Path -LiteralPath $staged) {
    try { Remove-Item -LiteralPath $staged -Force } catch { }
}

$psExe = Join-Path -Path $env:SystemRoot -ChildPath 'System32\WindowsPowerShell\v1.0\powershell.exe'
$iconDll = Join-Path -Path $env:SystemRoot -ChildPath 'System32\imageres.dll'

# NOTE: every Join-Path result must be wrapped in parentheses before it is
# concatenated -- otherwise PowerShell binds "+ ,3" as extra positional
# parameters and throws "cannot find a positional parameter for +".
# 注意：每个 Join-Path 结果在被拼接前都必须用括号包起来 -- 否则 PowerShell
# 会把 "+ ,3" 绑定成额外的位置参数，并抛出「cannot find a positional
# parameter for +」。
$sh = New-Object -ComObject WScript.Shell
$s = $sh.CreateShortcut($staged)
$s.TargetPath = $psExe
$s.Arguments = '-NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File "' + $script + '"'
$s.WorkingDirectory = 'C:\'
$s.IconLocation = $iconDll + ',3'
$s.Description = 'Open browser download folder. 打开浏览器下载文件夹。'
$s.Save()

if (-not (Test-Path -LiteralPath $staged)) {
    Write-Host "ERROR: shortcut was not created. 错误：快捷方式未能创建。" -ForegroundColor Red
    exit 1
}

# Verify the staged file is non-trivial before promoting it.
# 在提升为正式文件之前，先验证暂存文件不是空的。
$len = (Get-Item -LiteralPath $staged).Length
if ($len -lt 200) {
    Write-Host "ERROR: staged shortcut looks truncated ($len bytes). 错误：暂存快捷方式看起来被截断了（$len 字节）。" -ForegroundColor Red
    exit 1
}

# Promote: copy the validated staging file onto the desktop, then drop the temp.
# Copy-Item -Force overwrites in place, so no explicit delete is needed (and a
# locked target surfaces here as a clear error rather than a partial state).
# 提升：把已验证的暂存文件复制到桌面，然后删掉临时文件。Copy-Item -Force
# 是就地覆盖，所以无需显式删除（而且目标被锁时这里会报出清晰错误，而不是
# 留下半成品状态）。
Copy-Item -LiteralPath $staged -Destination $lnk -Force
Remove-Item -LiteralPath $staged -Force -ErrorAction SilentlyContinue

if (Test-Path -LiteralPath $lnk) {
    $finalLen = (Get-Item -LiteralPath $lnk).Length
    Write-Host "OK: $lnk. 成功：$lnk。" -ForegroundColor Green
    Write-Host "Size: $finalLen bytes. 大小：$finalLen 字节。"
    if ($finalLen -lt 200) {
        Write-Host "WARNING: the shortcut on the desktop looks truncated. 警告：桌面上的快捷方式看起来被截断了。" -ForegroundColor Yellow
    }
    exit 0
} else {
    Write-Host "FAILED to place shortcut on the desktop. 无法把快捷方式放到桌面。" -ForegroundColor Red
    exit 1
}
