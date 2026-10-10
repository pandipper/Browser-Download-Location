# =============================================================================
#  Opens the browser's real download folder.
#  打开浏览器真实的下载目录。
# =============================================================================
#
#  Resolution order, most specific first:
#  解析顺序，最具体的排在最前面：
#
#    1. pending.txt -- the folder you flagged most recently. If a change is
#       still waiting for the browser to exit, this is the folder you meant,
#       so opening it is more useful than opening the old one.
#    1. pending.txt -- 你最近标记的目录。如果某个变更仍在等待浏览器退出，
#       那这就是你想要的目录，所以打开它比打开旧目录更有用。
#    2. current.txt -- the folder the change was last applied for.
#    2. current.txt -- 最后一次成功应用变更时的目录。
#    3. The browser profile itself, read live. This works even before the tool
#       has ever been used.
#    3. 浏览器配置本身，实时读取。即使这个工具从未被使用过也能用。
#    4. shell:Downloads.
#    4. shell:Downloads。
#
#  PERFORMANCE
#  性能
#  -----------
#  -----------
#  The naive approach (parse the whole ~700 KB Preferences with ConvertFrom-Json)
#  measured 120-470 ms, because it builds an object graph for thousands of
#  settings we never look at. We only need one string, so the shared helper
#  scans for the "download" object and regexes one value out of it: ~3.5 ms.
#  The remaining cost is PowerShell process startup, which cannot be avoided
#  from inside the script.
#  朴素做法（用 ConvertFrom-Json 解析整个约 700 KB 的 Preferences）实测要
#  120-470 毫秒，因为它会为成千上万个我们根本不看的设置构建对象图。我们只
#  需要一个字符串，所以共享辅助函数直接扫描 "download" 对象并用正则取出
#  一个值：约 3.5 毫秒。剩下的开销是 PowerShell 进程启动，这在脚本内部
#  无法避免。
#
#  ASCII-only source on purpose, so no code page can corrupt it.
#  源码刻意只用 ASCII，这样任何代码页都无法破坏它。

$ErrorActionPreference = 'Stop'

$scriptRoot = $PSScriptRoot
if (-not $scriptRoot) { $scriptRoot = Split-Path -Parent $MyInvocation.MyCommand.Definition }

$commonPath = Join-Path -Path $scriptRoot -ChildPath 'BrowserDownload.Common.ps1'

$target = $null

if (Test-Path -LiteralPath $commonPath) {
    . $commonPath

    # 1. A change that has not landed yet is still the folder the user meant.
    # 1. 尚未生效的变更，仍然是用户想要的那个目录。
    $target = Read-BdStateLine -Name 'pending.txt'

    # 2. The folder the last applied change went to.
    # 2. 上一次成功应用的变更所指向的目录。
    if (-not $target) { $target = Read-BdStateLine -Name 'current.txt' }

    # 3. Whatever the browser itself says right now.
    # 3. 浏览器此刻自己报告的目录。
    if (-not ($target -and (Test-Path -LiteralPath $target -PathType Container))) {
        $info = Get-BdCurrentDownloadDir
        if ($info -and $info.Dir -and (Test-Path -LiteralPath $info.Dir -PathType Container)) {
            $target = $info.Dir
        } else {
            $target = $null
        }
    }
}

# Browser folder missing (renamed or unmounted): walk up a few levels so the
# user still lands somewhere useful instead of nothing happening.
# 浏览器目录不存在（被改名或未挂载）：向上回溯几层，让用户至少落到一个
# 有用的地方，而不是什么都没发生。
if ($target -and -not (Test-Path -LiteralPath $target -PathType Container)) {
    $parent = Split-Path -Path $target -Parent
    for ($i = 0; $i -lt 3 -and $parent; $i++) {
        if (Test-Path -LiteralPath $parent -PathType Container) { $target = $parent; break }
        $parent = Split-Path -Path $parent -Parent
    }
}

if ($target -and (Test-Path -LiteralPath $target -PathType Container)) {
    Start-Process -FilePath 'explorer.exe' -ArgumentList ('"' + $target + '"')
} else {
    Start-Process -FilePath 'explorer.exe' -ArgumentList 'shell:Downloads'
}
