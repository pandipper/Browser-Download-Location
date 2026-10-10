<#
.SYNOPSIS
    Installs (or removes) the "set as browser download folder" right-click menu.
    安装（或移除）「设为浏览器下载位置」右键菜单。

.DESCRIPTION
    Adds a context-menu entry that runs Set-DownloadFlag.ps1 on the folder the
    user right-clicked. Registered in both places so it works either way:
    添加一个右键菜单项，对用户右键点击的目录运行 Set-DownloadFlag.ps1。
    在两个位置都注册，因此两种方式都能用：

      HKCU\Software\Classes\Directory\shell\...            (folder icon)  文件夹图标
      HKCU\Software\Classes\Directory\Background\shell\... (empty area)   空白区域

    HKCU only -- no administrator rights needed, nothing written to HKLM.
    仅写 HKCU -- 不需要管理员权限，不向 HKLM 写入任何内容。

    Removing the menu removes the registry keys ONLY. An earlier version
    deleted this script as well, which made the tool impossible to reinstall
    without rewriting it from scratch. Nothing here deletes a file.
    移除菜单只删除注册表键。早期版本还会删掉本脚本，导致不从头重写就无法
    重新安装这个工具。这里不会删除任何文件。

.PARAMETER Remove
    Delete the registry entries. This script and the other tools are left in
    place so the menu can be installed again at any time.
    删除注册表项。本脚本及其它工具都保持原位，因此随时可以重新安装菜单。

.EXAMPLE
    .\Install-ContextMenu.ps1
    .\Install-ContextMenu.ps1 -Remove

.NOTES
    ASCII-only source. The menu label is assembled from codepoints so no code
    page can mangle it.
    源码只用 ASCII。菜单标签由码点拼装，因此任何代码页都无法破坏它。
#>
[CmdletBinding()]
param(
    [switch]$Remove
)

$ErrorActionPreference = 'Stop'

# Registry key name. ASCII so the key path never depends on a code page.
# 注册表键名。用 ASCII，因此键路径永远不依赖代码页。
$keyName = 'SetDownloadFlag'

# Menu label from codepoints: "设为浏览器下载位置"
# 菜单标签由码点拼装："设为浏览器下载位置"
#   8BBE 设  4E3A 为  6D4F 浏  89C8 览  5668 器  4E0B 下  8F7D 载  4F4D 位  7F6E 置
$menuText = -join ([char]0x8BBE, [char]0x4E3A, [char]0x6D4F, [char]0x89C8, [char]0x5668,
                   [char]0x4E0B, [char]0x8F7D, [char]0x4F4D, [char]0x7F6E)

$scriptRoot = $PSScriptRoot
if (-not $scriptRoot) { $scriptRoot = Split-Path -Parent $MyInvocation.MyCommand.Definition }

$flagScript = Join-Path -Path $scriptRoot -ChildPath 'Set-DownloadFlag.ps1'
$iconPath = Join-Path -Path $scriptRoot -ChildPath 'flag.ico'

$hcuClasses = 'HKCU:\Software\Classes'
$targets = @(
    (Join-Path -Path $hcuClasses -ChildPath "Directory\shell\$keyName"),
    (Join-Path -Path $hcuClasses -ChildPath "Directory\Background\shell\$keyName")
)

function Remove-MenuKeys {
    foreach ($k in $targets) {
        if (Test-Path -LiteralPath $k) {
            Remove-Item -LiteralPath $k -Recurse -Force
            Write-Host "removed: $k. 已移除：$k。" -ForegroundColor Yellow
        }
    }
}

if ($Remove) {
    Write-Host ''
    Remove-MenuKeys
    Write-Host ''
    Write-Host 'Right-click menu removed. The other tools were left in place. 右键菜单已移除，其它工具保持原位。' -ForegroundColor Green
    Write-Host 'Run this script without -Remove to install it again. 不带 -Remove 再运行一次本脚本即可重新安装。' -ForegroundColor DarkGray
    exit 0
}

if (-not (Test-Path -LiteralPath $flagScript)) {
    Write-Host "ERROR: Set-DownloadFlag.ps1 not found next to this script. 错误：本脚本旁边找不到 Set-DownloadFlag.ps1。" -ForegroundColor Red
    Write-Host "Expected: $flagScript. 应为：$flagScript。" -ForegroundColor Yellow
    exit 1
}

# The flag script dot-sources the shared helpers; registering the menu without
# them would install an entry that fails the moment it is clicked.
# 标记脚本会点源加载共享辅助函数；若没有它们就注册菜单，会安装一个一点击
# 就失败的菜单项。
$commonScript = Join-Path -Path $scriptRoot -ChildPath 'BrowserDownload.Common.ps1'
if (-not (Test-Path -LiteralPath $commonScript)) {
    Write-Host "ERROR: BrowserDownload.Common.ps1 not found next to this script. 错误：本脚本旁边找不到 BrowserDownload.Common.ps1。" -ForegroundColor Red
    Write-Host "Expected: $commonScript. 应为：$commonScript。" -ForegroundColor Yellow
    exit 1
}

# "%V" is the folder that was right-clicked: required for Directory\Background,
# and correct for Directory\shell too.
# "%V" 是被右键点击的目录：Directory\Background 需要它，对 Directory\shell
# 也同样正确。
#
# No -WindowStyle Hidden on purpose -- it swallows every message, so a failed
# run looked like nothing happened. The script also pauses before exiting.
# 故意不加 -WindowStyle Hidden -- 它会吞掉所有消息，于是运行失败看起来像
# 什么都没发生。脚本退出前也会暂停。
$psExe = Join-Path -Path $env:SystemRoot -ChildPath 'System32\WindowsPowerShell\v1.0\powershell.exe'
$cmd = '"' + $psExe + '" -NoProfile -ExecutionPolicy Bypass -File "' + $flagScript + '" "%V"'

# Prefer the flag icon; fall back to a stock one if flag.ico is missing.
# 优先用标记图标；若 flag.ico 缺失则回退到系统自带图标。
if (Test-Path -LiteralPath $iconPath) {
    $iconValue = $iconPath + ',0'
} else {
    $iconValue = 'imageres.dll,1024'
    Write-Host 'flag.ico not found; using a stock icon instead. 未找到 flag.ico，改用系统自带图标。' -ForegroundColor Yellow
}

foreach ($k in $targets) {
    # Rebuild from scratch so a stale key (e.g. a leftover "shift" subkey that
    # made the entry appear only on Shift+right-click) cannot survive.
    # 从头重建，这样陈旧的键（例如一个残留的 "shift" 子键，会让菜单项只在
    # Shift+右键时出现）就无法存活。
    if (Test-Path -LiteralPath $k) { Remove-Item -LiteralPath $k -Recurse -Force }
    New-Item -Path $k -Force | Out-Null
    New-ItemProperty -Path $k -Name '(default)' -Value $menuText -PropertyType String -Force | Out-Null
    New-ItemProperty -Path $k -Name 'Icon'     -Value $iconValue -PropertyType String -Force | Out-Null
    New-ItemProperty -Path $k -Name 'Position' -Value 'top'           -PropertyType String -Force | Out-Null

    $sub = Join-Path -Path $k -ChildPath 'command'
    New-Item -Path $sub -Force | Out-Null
    New-ItemProperty -Path $sub -Name '(default)' -Value $cmd -PropertyType String -Force | Out-Null
    Write-Host "registered: $k. 已注册：$k。" -ForegroundColor Green
}

Write-Host ''
Write-Host 'Done. 完成。' -ForegroundColor Green
Write-Host 'Right-click any folder and look for "' -NoNewline
Write-Host $menuText -ForegroundColor White -NoNewline
Write-Host '". 右键点击任意文件夹，就能看到该菜单项。' -ForegroundColor Green
Write-Host 'The browser is never closed or restarted. 浏览器不会被关闭或重启。' -ForegroundColor DarkGray
exit 0
