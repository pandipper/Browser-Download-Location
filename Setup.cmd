@echo off
REM Setup and status for the browser download-folder flag.
REM 浏览器下载目录标记工具的安装与状态。
REM Saved as GBK/cp936 with CRLF (the Chinese Windows console code page), and it
REM must stay that way.
REM 以 GBK/cp936 加 CRLF 保存（中文 Windows 控制台的代码页），并且必须保持这种编码。

setlocal
set "DIR=%~dp0"

echo.
echo ============================================
echo   Browser download folder - flag tools  浏览器下载目录 - 标记工具
echo ============================================
echo.
echo  [1] Install everything (menu + desktop shortcut) 安装全部（菜单 + 桌面快捷方式）
echo  [2] Install the right-click menu only 只安装右键菜单
echo  [3] Remove the right-click menu 移除右键菜单
echo  [4] Show where downloads are going now 显示当前下载保存到哪里
echo  [5] Flag a folder and wait (does not close the browser) 标记目录并等待（不关闭浏览器）
echo  [6] Flag a folder and apply now (closes the browser) 标记目录并立即应用（会关闭浏览器）
echo  [7] Flag a folder now by policy (instant, needs administrator) 通过策略立即标记目录（即时生效，需要管理员）
echo  [8] Remove the download policy (unlocks the browser setting) 移除下载策略（解锁浏览器里的设置）
echo  [9] Clear the flag and sweep up any leftover marker files 清除标记并清理任何残留的标记文件
echo [10] How this works 工作原理
echo  [0] Exit 退出
echo.

set /p CHOICE=Choose an option:

if "%CHOICE%"=="1" goto all
if "%CHOICE%"=="2" goto menu
if "%CHOICE%"=="3" goto remove
if "%CHOICE%"=="4" goto show
if "%CHOICE%"=="5" goto setnow
if "%CHOICE%"=="6" goto setapply
if "%CHOICE%"=="7" goto setpolicy
if "%CHOICE%"=="8" goto rmpolicy
if "%CHOICE%"=="9" goto unflag
if "%CHOICE%"=="10" goto howto
goto done

:all
echo.
if not exist "%DIR%Install-ContextMenu.ps1" (
  echo ERROR: Install-ContextMenu.ps1 is missing from %DIR% 错误：%DIR% 中缺少 Install-ContextMenu.ps1
  goto end
)
if not exist "%DIR%BrowserDownload.Common.ps1" (
  echo ERROR: BrowserDownload.Common.ps1 is missing from %DIR% 错误：%DIR% 中缺少 BrowserDownload.Common.ps1
  echo The other scripts cannot run without it. 没有它，其它脚本都无法运行。
  goto end
)
echo Installing right-click menu... 正在安装右键菜单...
powershell -NoProfile -ExecutionPolicy Bypass -File "%DIR%Install-ContextMenu.ps1"
echo.
echo Creating desktop shortcut... 正在创建桌面快捷方式...
if exist "%DIR%Install-Shortcut.ps1" (
  powershell -NoProfile -ExecutionPolicy Bypass -File "%DIR%Install-Shortcut.ps1"
) else (
  echo WARNING: Install-Shortcut.ps1 is missing; skipping. 警告：缺少 Install-Shortcut.ps1；已跳过。
)
echo.
echo Done. Right-click any folder to flag it as the download location. 完成。右键任意目录即可将其标记为下载位置。
goto end

:menu
if exist "%DIR%Install-ContextMenu.ps1" (
  powershell -NoProfile -ExecutionPolicy Bypass -File "%DIR%Install-ContextMenu.ps1"
) else (
  echo ERROR: Install-ContextMenu.ps1 is missing from %DIR% 错误：%DIR% 中缺少 Install-ContextMenu.ps1
)
goto end

:remove
if exist "%DIR%Install-ContextMenu.ps1" (
  powershell -NoProfile -ExecutionPolicy Bypass -File "%DIR%Install-ContextMenu.ps1" -Remove
) else (
  echo Nothing to remove - installer not present. 没有可移除的内容 - 安装器不存在。
)
goto end

:show
powershell -NoProfile -ExecutionPolicy Bypass -File "%DIR%Set-DownloadFlag.ps1" -Show -NoPause
goto end

:setnow
echo.
echo The marker is placed and the intent is recorded straight away, but the
echo browser is left alone. The change is written the next time the browser
echo exits on its own - which may be a long time if you keep it open.
echo 标记会立即放置、意图会立即记录，但浏览器不会被碰。变更会在浏览器下次自行退出
echo 时写入 - 如果你一直开着它，可能要等很久。
echo.
set /p TARGETPATH=Paste the full folder path to flag:
echo.
powershell -NoProfile -ExecutionPolicy Bypass -File "%DIR%Set-DownloadFlag.ps1" -NoPause -WaitOnly "%TARGETPATH%"
goto end

:setapply
echo.
echo This is the normal way to flag a folder. Open windows get an ordinary
echo close request first, so the session is saved. Anything still running
echo after that - the Startup boost process keeps no window - is terminated,
echo because it holds the old folder in memory. The browser is reopened.
echo 这是标记目录的常规方式。开着的窗口会先收到一个普通的关闭请求，因此会话会被
echo 保存。之后仍在运行的一切 - 启动加速进程不保留窗口 - 都会被终止，因为它
echo 内存里握着旧目录。随后浏览器会被重新打开。
echo.
set /p TARGETPATH=Paste the full folder path to flag:
echo.
powershell -NoProfile -ExecutionPolicy Bypass -File "%DIR%Set-DownloadFlag.ps1" -NoPause "%TARGETPATH%"
goto end

:setpolicy
echo.
echo This applies the folder through the Windows policy the browser reads.
echo It takes effect within seconds, and the browser never has to be closed.
echo 这会通过浏览器读取的 Windows 策略来应用该目录。它会在几秒内生效，而且浏览器
echo 完全不必关闭。
echo.
echo Administrator rights are needed, so a UAC prompt will appear and the
echo result shows up in a separate elevated window.
echo 需要管理员权限，因此会出现一个 UAC 提示，结果显示在一个单独的高权限窗口中。
echo.
echo Note: while the policy is set, the download location is locked in the
echo browser settings page. Option 8 unlocks it again.
echo 注意：策略设置期间，下载位置会被锁定在浏览器的设置页面里。选项 8 可以重新解锁它。
echo.
set /p TARGETPATH=Paste the full folder path to flag:
echo.
powershell -NoProfile -ExecutionPolicy Bypass -File "%DIR%Set-DownloadFlag.ps1" -NoPause -Elevate "%TARGETPATH%"
goto end

:rmpolicy
echo.
echo This removes the download policy and unlocks the setting in the browser.
echo Administrator rights are needed, so a UAC prompt will appear.
echo 这会移除下载策略并解锁浏览器里的该项设置。需要管理员权限，因此会出现一个 UAC 提示。
echo.
powershell -NoProfile -ExecutionPolicy Bypass -File "%DIR%Set-DownloadFlag.ps1" -NoPause -Elevate -RemovePolicy
goto end

:unflag
powershell -NoProfile -ExecutionPolicy Bypass -File "%DIR%Set-DownloadFlag.ps1" -Unflag -NoPause
echo.
echo Sweeping up any marker files left behind by earlier runs... 正在清理早先运行遗留下来的标记文件...
powershell -NoProfile -ExecutionPolicy Bypass -File "%DIR%Set-DownloadFlag.ps1" -Cleanup -NoPause
goto end

:howto
echo.
echo HOW IT WORKS 工作原理
echo.
echo The browser keeps the download folder inside a settings file that it
echo rewrites from memory while it runs. Measured on this machine: a value
echo planted while Edge was running was overwritten about 7 seconds later.
echo So that file can only be written while the browser is fully closed.
echo 浏览器把下载目录保存在一个设置文件里，它在运行时会从内存重写该文件。在本机
echo 实测：Edge 运行时写入的一个值大约 7 秒后就被覆盖了。所以该文件只有在浏览器
echo 完全关闭时才能写入。
echo.
echo Three other routes were tried here and do not work:
echo 这里试过另外三条路，都行不通：
echo.
echo   - The DownloadDirectory registry policy. It would apply instantly, but
echo     this account cannot even read HKCU\SOFTWARE\Policies, let alone write
echo     it, so that route needs an administrator and is not used.
echo   - edge://restart. It does not close anything.
echo   - A browser extension. Chromium deliberately exposes no API that can
echo     change the default download folder.
echo   - DownloadDirectory 注册表策略。它本可以立即生效，但这个账户连
echo     HKCU\SOFTWARE\Policies 都读不了，更别提写入，所以这条路径需要管理员，
echo     故不使用。
echo   - edge://restart。它不会关闭任何东西。
echo   - 浏览器扩展。Chromium 刻意不提供任何能更改默认下载目录的 API。
echo.
echo So this tool does not fight the browser. Flagging a folder drops a hidden
echo marker into it straight away, then closes the browser, writes the new
echo path, reads it back to confirm, and reopens the browser. One right-click
echo is all it takes - there is nothing to verify afterwards.
echo 所以本工具不与浏览器对抗。标记一个目录会立即在其中放入一个隐藏标记，然后关闭
echo 浏览器、写入新路径、读回来确认，再重新打开浏览器。一次右键就够了 - 之后无需
echo 再做任何验证。
echo.
echo TWO ROUTES 两种路径
echo.
echo Option 7 uses the Windows policy the browser already supports
echo (DownloadDirectory). The browser picks it up within seconds and nothing
echo has to be closed at all. The price: the download location becomes locked
echo in the browser settings page, and the browser may say it is "managed by
echo your organization" - on a personal PC that only means a local policy is
echo set. Option 8 removes it again.
echo 选项 7 使用浏览器本就支持的 Windows 策略（DownloadDirectory）。浏览器会在
echo 几秒内拾取它，完全不必关闭任何东西。代价是：下载位置会被锁定在浏览器设置页面
echo 里，浏览器可能会说它「由你的组织管理」- 在个人电脑上这仅意味着设置了本地
echo 策略。选项 8 可以把它移除。
echo.
echo Options 5 and 6 use the file route instead: the browser's own settings
echo file is rewritten. Nothing gets locked and no policy is involved, but the
echo write only survives while the browser is fully closed - which is why
echo option 6 closes it for you and option 5 waits.
echo 选项 5 和 6 则改用文件路径：重写浏览器自己的设置文件。不会锁定任何东西，也不
echo 涉及任何策略，但写入只有在浏览器完全关闭时才留得住 - 这就是为什么选项 6 替你
echo 关闭它，而选项 5 会等待。
echo.
echo CLOSING THE BROWSER 关闭浏览器
echo.
echo Closing every window is not enough on its own: Edge's Startup boost keeps
echo a windowless browser process running. That process holds the old folder in
echo memory, so it would overwrite the new one later. Measured on this machine:
echo 0 windows open, 11 processes still alive.
echo 仅仅关闭所有窗口还不够：Edge 的启动加速会保活一个无窗口的浏览器进程。该进程
echo 内存里握着旧目录，所以它稍后会覆盖新值。在本机实测：0 个窗口打开，11 个进程
echo 仍存活。
echo.
echo So flagging asks every window to close first - an ordinary close request,
echo so the session is saved - waits up to 5 seconds for them to go, then
echo terminates whatever is still running. A forced exit writes no settings, so
echo the stale value cannot come back. It never closes the browser while a
echo download is still being written (a .crdownload file in the download folder).
echo 因此标记时会先请每个窗口关闭 - 一个普通的关闭请求，所以会话会被保存 - 最多
echo 等 5 秒让它们退出，然后终止仍在运行的一切。强杀不写任何设置，所以旧值回不来。
echo 下载仍在写入时（下载目录里有 .crdownload 文件），它绝不会关闭浏览器。
echo.
echo Option 5 (or -WaitOnly) skips all of that: nothing is interrupted, but the
echo change waits until the browser exits on its own. Turn Startup boost off at
echo edge://settings/system if you want closing the windows to really exit it.
echo 选项 5（或 -WaitOnly）会跳过这一切：不打断任何东西，但变更会一直等到浏览器
echo 自行退出。如果你希望关闭窗口就能真正退出浏览器，请在 edge://settings/system
echo 里关闭启动加速。
echo.
echo MARKER FILES 标记文件
echo.
echo Every folder this tool marks is recorded, and the marker is removed from
echo all the others each time you flag a new folder. Earlier versions only
echo cleaned the last folder that had been APPLIED, so while a change sat in the
echo queue every further flag left another marker behind. Option 9 sweeps up any
echo that are still lying around.
echo 本工具标记过的每个目录都会被记录，每次标记新目录时，标记都会从其它所有目录中
echo 移除。早期版本只清理最后一个「已应用」的目录，所以当某个变更还在队列里时，
echo 每再标记一次就会多遗留一个标记。选项 9 会清理所有仍然残留的标记。
echo.
echo Option 5 is the only case where a change can sit unapplied: it lands the
echo next time the browser fully exits, so if the browser stays open for days,
echo so does the change. Option 4 reports a pending change and what is holding
echo it up. Options 6 and 7 change the folder there and then.
echo 选项 5 是唯一一种变更可能迟迟不应用的情况：它会在浏览器下次完全退出时落地，
echo 所以如果浏览器开着好几天，变更也会拖上好几天。选项 4 会报告待处理的变更以及
echo 是什么在阻塞它。选项 6 和 7 会当场更改目录。
echo.
echo Cancelling: option 9 clears the flag and stops any waiting helper, so a
echo change you no longer want will not land later.
echo 取消：选项 9 会清除标记并停止任何正在等待的辅助进程，所以一个你不再想要的
echo 变更不会在之后落地。
echo.
powershell -NoProfile -ExecutionPolicy Bypass -File "%DIR%Set-DownloadFlag.ps1" -Show -NoPause
goto end

:done
echo Nothing to do. 无事可做。

:end
echo.
pause
