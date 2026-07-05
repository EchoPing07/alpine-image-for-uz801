@echo off
@title 一键刷入Alpine Linux - UZ801
color 0A
mode con cols=100 lines=35

echo.
echo  ===========================================================================
echo               UZ801 一键刷入 Alpine Linux 系统 (Windows版)
echo  ===========================================================================
echo.
echo  功能说明: 超低系统占用 / 支持CPU超频 / 去除蜂窝网络模块释放内存
echo.
echo  ===========================================================================
echo.

echo 【警告】以下操作可能会破坏您的设备，使其无法启动！
echo         请确保已备份原始固件，风险自负！
echo.

set /p confirm=是否继续？(y/n):
if /i not "%confirm%"=="y" (
    echo 已取消操作。
    pause
    exit /b 0
)

echo.
echo ---------------------------------------------------------------
echo  【阶段 1/3】刷写aboot并重启
echo ---------------------------------------------------------------
echo.

echo 正在检测设备...
adb devices >nul 2>&1
adb devices 2>nul | findstr /r "device$" >nul
if %errorlevel% equ 0 (
    echo 【成功】已检测到ADB设备，正在重启进入Fastboot模式...
    adb reboot bootloader
    timeout /NOBREAK 5 >nul
) else (
    echo 【提示】未检测到ADB设备，请确保设备已处于Fastboot模式。
)

:wait_fb1
fastboot devices 2>nul | findstr /v "^$" >nul
if %errorlevel% equ 0 goto fb1_ok
timeout /NOBREAK 2 >nul
goto wait_fb1

:fb1_ok
echo 【成功】已检测到Fastboot设备！
echo.
echo 擦除boot分区...
fastboot erase boot
echo 刷写aboot...
fastboot flash aboot "%~dp0aboot.mbn"
echo 重启设备...
fastboot reboot
echo.
echo 请等待设备重新进入Fastboot模式...
echo （如果设备正常启动了，请手动重新进入Fastboot模式）
echo.
timeout /NOBREAK 5 >nul

:wait_fb2
fastboot devices 2>nul | findstr /v "^$" >nul
if %errorlevel% equ 0 goto fb2_ok
timeout /NOBREAK 2 >nul
goto wait_fb2

:fb2_ok
echo 【成功】已检测到Fastboot设备！
echo.

echo ---------------------------------------------------------------
echo  【阶段 2/3】刷写所有分区
echo ---------------------------------------------------------------
echo.
echo 刷写分区表...
fastboot flash partition "%~dp0gpt_both0.bin"
echo.
echo 刷写引导加载程序...
fastboot flash hyp "%~dp0hyp.mbn"
fastboot flash rpm "%~dp0rpm.mbn"
fastboot flash sbl1 "%~dp0sbl1.mbn"
fastboot flash tz "%~dp0tz.mbn"
echo.
echo 刷写基带及配置分区...
fastboot flash fsc "%~dp0fsc.bin"
fastboot flash fsg "%~dp0fsg.bin"
fastboot -S 200m flash modem "%~dp0modem.bin"
fastboot flash modemst1 "%~dp0modemst1.bin"
fastboot flash modemst2 "%~dp0modemst2.bin"
fastboot -S 200m flash persist "%~dp0persist.bin"
fastboot flash sec "%~dp0sec.bin"
echo.
echo 刷写aboot...
fastboot flash aboot "%~dp0aboot.mbn"
echo.
echo 擦除boot和rootfs分区...
fastboot erase boot
fastboot erase rootfs
echo.
echo 重启设备...
fastboot reboot
echo.
echo 请等待设备重新进入Fastboot模式...
echo （如果设备正常启动了，请手动重新进入Fastboot模式）
echo.
timeout /NOBREAK 5 >nul

:wait_fb3
fastboot devices 2>nul | findstr /v "^$" >nul
if %errorlevel% equ 0 goto fb3_ok
timeout /NOBREAK 2 >nul
goto wait_fb3

:fb3_ok
echo 【成功】已检测到Fastboot设备！
echo.

echo ---------------------------------------------------------------
echo  【阶段 3/3】刷写boot和根文件系统
echo ---------------------------------------------------------------
echo.
echo 刷写boot内核镜像...
fastboot flash boot "%~dp0boot.bin"
echo.
echo 刷写Alpine根文件系统（约97MB，请耐心等待）...
fastboot -S 200m flash rootfs "%~dp0alpine_rootfs.bin"
echo.
echo 重启设备...
fastboot reboot

echo.
echo  ===========================================================================
echo.
echo                       *** 刷机完成！ ***
echo.
echo  设备正在重启，启动成功后即可连接：
echo    SSH连接: ssh root@192.168.5.1 （默认密码: uz801）
echo    连接WiFi: SSH登录后执行 nmtui 命令
echo.
echo  ===========================================================================
echo.
pause
exit /b 0
