@echo off
chcp 65001 >nul
setlocal enabledelayedexpansion

rem Check for --debug flag
set "debug_mode=false"
for %%i in (%*) do (
    if "%%i"=="--debug" set "debug_mode=true"
)

if "%~1"=="" (
    echo Usage: %~nx0 "notification content" [title] [method] [--debug]
    echo.
    echo Parameters:
    echo   notification content  - Required, the notification content to display
    echo   title                 - Optional, notification title ^(default: "Notification"^)
    echo   method                - Optional, notification method ^(toast/balloon/messagebox/console/all^)
    echo                          default: all ^(try all methods^)
    echo   --debug               - Optional, show detailed output information
    echo.
    echo Examples:
    echo   %~nx0 "This is a test notification"
    echo   %~nx0 "This is a test notification" "Custom Title"
    echo   %~nx0 "This is a test notification" "Title" "toast"
    echo   %~nx0 "This is a test notification" "Title" "all" --debug
    echo.
    pause
    exit /b 1
)

rem Parse arguments (filter out --debug)
set "args_count=0"
set "message="
set "title="
set "method="
for %%i in (%*) do (
    if not "%%i"=="--debug" (
        set /a args_count+=1
        if !args_count! equ 1 set "message=%%~i"
        if !args_count! equ 2 set "title=%%~i"
        if !args_count! equ 3 set "method=%%~i"
    )
)

if "%title%"=="" (
    set "title=Notification"
)

if "%method%"=="" (
    set "method=all"
)

if "%debug_mode%"=="true" (
    echo Sending notification...
    echo Content: %message%
    echo Title: %title%
    echo Method: %method%
    echo.
)

if "%debug_mode%"=="true" (
    powershell.exe -ExecutionPolicy Bypass -File "%~dp0send-notification.ps1" -Message "%message%" -Title "%title%" -Method "%method%" -DebugMode
) else (
    powershell.exe -ExecutionPolicy Bypass -File "%~dp0send-notification.ps1" -Message "%message%" -Title "%title%" -Method "%method%"
)

if "%debug_mode%"=="true" (
    if %errorlevel% equ 0 (
        echo.
        echo Notification processing completed!
    ) else (
        echo.
        echo Notification sending failed!
        pause
    )
) else (
    if %errorlevel% neq 0 (
        echo Notification sending failed!
        pause
    )
)