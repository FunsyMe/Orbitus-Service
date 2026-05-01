@echo off

chcp 65001 >nul
title Orbitus Service Runner

REM Проверка PWSH
where pwsh >nul 2>&1
if errorlevel 1 (
    echo [?] Ошибка: PowerShell 7 не найден. Идет запуск обновления...
    start "" powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0utils\ps_update.ps1" & exit
)

REM Получение статуса Zapret
if "%~1"=="zapret_status" (
    "pwsh.exe" -NoProfile -Command "Start-Process -FilePath 'pwsh.exe' -ArgumentList '-NoProfile','-ExecutionPolicy','Bypass','-File','\"%~dp0utils\zapret_status.ps1\"','-kgyat' -WindowStyle Hidden -Verb RunAs"
    
    call :load_user_lists
    call :test_service zapret soft
    call :tcp_enable
    
    exit /b
)

REM Получение GameFilter
if "%~1"=="game_filter" (
    call :game_filter_status
    exit /b
)

REM Проверка прав
net session >nul 2>&1 || (
    echo Запрашиваем права администратора...
    powershell -NoProfile -ExecutionPolicy Bypass -Command "Start-Process -FilePath '%~s0' -Verb RunAs" & exit
)

REM Проверка извлечения
if not exist "%~dp0bin\" (
    echo [?] Ошибка: Необходимо распаковать архив. Нажмите любую клавишу для выхода...
    pause >nul & exit
)

REM Сбор персональных данных
"pwsh.exe" -NoProfile -Command "Start-Process -FilePath 'pwsh.exe' -ArgumentList '-NoProfile','-ExecutionPolicy','Bypass','-File','\"%~dp0utils\zapret_status.ps1\"' -WindowStyle Hidden -Verb RunAs"
cls

REM Проверка обновлений
set /p LOCAL_VERSION=<"%~dp0bin\orbitus_version.txt"
set "UpdateStatus="

REM Запуск функций иницилизации
call :load_user_lists
call :load_start_menu
call :check_updates

setlocal EnableDelayedExpansion

REM Меню
:menu
title Orbitus Service
cls

call :ipset_status
call :game_filter_status
call :check_updates_status
call :test_service zapret status

echo.
echo    ORBITUS SERVICE v%LOCAL_VERSION%
echo    --------------------------------
echo.
echo    [СЕРВИС]
echo       1. Установить сервис
echo       2. Удалить сервис
echo.
echo    [НАСТРОЙКИ]
echo        3. Сменить Game Filter        [%GameFilterStatus%]
echo        4. Сменить IPset Filter       [%IPsetStatus%]
echo        5. Авто-Проверка обновлений   [%CheckUpdatesStatus%]
echo.
echo    [ОБНОВЛЕНИЯ]
echo        6. Обновить файл IPset
echo        7. Обновить файл hosts
echo        8. Авто-Проверка обновлений
echo.
echo    [ИНСТРУМЕНТЫ]
echo        9. Диагностика zapret
echo        10. Авто-Поиск конфигурации
echo.
echo    --------------------------------
echo.

set "menu_choice="
set "menu_target="
set /p menu_choice=[?] Введите выбор [1-10]: 

if not defined menu_choice goto menu
if "%menu_choice%"=="1" set "menu_target=zapret_install"
if "%menu_choice%"=="2" set "menu_target=zapret_remove"
if "%menu_choice%"=="3" call :ipset_switch & goto menu
if "%menu_choice%"=="4" call :game_filter_switch & goto menu
if "%menu_choice%"=="5" call :check_updates_switch & goto menu
if "%menu_choice%"=="6" set "menu_target=ipset_update"
if "%menu_choice%"=="7" set "menu_target=hosts_update"
if "%menu_choice%"=="8" start "" "pwsh.exe" -NoLogo -NoProfile -ExecutionPolicy Bypass -File "%~dp0utils\zapret_update.ps1" & exit
if "%menu_choice%"=="9" set "menu_target=zapret_diagnostic"
if "%menu_choice%"=="10" set "menu_target=auto_config"
if not defined menu_target goto menu

cls
call :run_ps %menu_target%
goto menu

REM Запуск Pwsh
:run_ps
if "%~1"=="" exit /b
"pwsh.exe" -NoLogo -NoProfile -ExecutionPolicy Bypass -File "%~dp0utils\%~1.ps1"
exit /b

REM Включение TCP
:tcp_enable
netsh interface tcp show global | findstr /c:"timestamps" | findstr /c:"enabled" >nul || (
    netsh interface tcp set global timestamps=enabled >nul 2>&1
)
exit /b

REM Загрузка листов пользователя
:load_user_lists
set "listsPath=%~dp0lists\"

if not exist "%listsPath%ipset-exclude-user.txt" (
    type nul > "%listsPath%ipset-exclude-user.txt"
)
if not exist "%listsPath%list-general-user.txt" (
    type nul > "%listsPath%list-general-user.txt"
)
if not exist "%listsPath%list-exclude-user.txt" (
    type nul > "%listsPath%list-exclude-user.txt"
)
exit /b

REM Тестирование сервиса
:test_service
set "ServiceName=%~1"
set "ServiceStatus="
set "ZapretStatus="

chcp 437 >nul
for /f %%i in ('pwsh -NoProfile -Command "(Get-Service -Name '%ServiceName%').Status"') do set ServiceStatus=%%i
chcp 65001 >nul

if "%ServiceStatus%"=="Running" (
    if "%~2"=="soft" (
        echo [?] Ошибка: %ServiceName% уже запущен. Нажмите любую клавишу для выхода...
        pause >nul & exit
    ) else if "%~2"=="status" (
        set "ZapretStatus=работает"
    ) else (
        echo %ServiceName% работает & exit /b
    )
) else if "%ServiceStatus%"=="StopPending" (
    echo [?] Ошибка: %ServiceName% останавливается. Запустите диагностику для проверки конфликтов. Нажмите любую клавишу для выхода...
    pause >nul & exit
) else if "%ServiceStatus%"=="Stopped" (
    if "%~2"=="status" (
        set "ZapretStatus=не работает"
    )
)

exit /b

REM Статус IPset
:ipset_status
set "ipsetFile=%~dp0lists\ipset-all.txt"
set "lineCount=0"
for /f %%i in ('type "%ipsetFile%" 2^>nul ^| find /c /v ""') do set "lineCount=%%i"

if !lineCount!==0 (
    set "IPsetStatus=any"
) else (
    findstr /R "^203\.0\.113\.113/32$" "%ipsetFile%" >nul
    if !errorlevel!==0 (
        set "IPsetStatus=none"
    ) else (
        set "IPsetStatus=loaded"
    )
)
exit /b

REM Переключение IPset
:ipset_switch
set "listFile=%~dp0lists\ipset-all.txt"
set "backupFile=%listFile%.backup"

if "%IPsetStatus%"=="loaded" ( 
    if not exist "%backupFile%" (
        ren "%listFile%" "ipset-all.txt.backup"
    ) else (
        del /f /q "%backupFile%"
        ren "%listFile%" "ipset-all.txt.backup"
    )
    >"%listFile%" (
        echo 203.0.113.113/32
        echo 103.140.28.0/23
        echo 128.116.0.0/17
        echo 128.116.0.0/24
        echo 128.116.1.0/24
        echo 128.116.5.0/24
        echo 128.116.11.0/24
        echo 128.116.13.0/24
        echo 128.116.21.0/24
        echo 128.116.22.0/24
        echo 128.116.31.0/24
        echo 128.116.32.0/24
        echo 128.116.33.0/24
        echo 128.116.35.0/24
        echo 128.116.44.0/24
        echo 128.116.45.0/24
        echo 128.116.46.0/24
        echo 128.116.48.0/24
        echo 128.116.50.0/24
        echo 128.116.51.0/24
        echo 128.116.53.0/24
        echo 128.116.54.0/24
        echo 128.116.55.0/24
        echo 128.116.56.0/24
        echo 128.116.57.0/24
        echo 128.116.63.0/24
        echo 128.116.64.0/24
        echo 128.116.67.0/24
        echo 128.116.74.0/24
        echo 128.116.80.0/24
        echo 128.116.81.0/24
        echo 128.116.84.0/24
        echo 128.116.86.0/24
        echo 128.116.87.0/24
        echo 128.116.88.0/24
        echo 128.116.95.0/24
        echo 128.116.97.0/24
        echo 128.116.99.0/24
        echo 128.116.102.0/24
        echo 128.116.104.0/24
        echo 128.116.105.0/24
        echo 128.116.115.0/24
        echo 128.116.116.0/24
        echo 128.116.117.0/24
        echo 128.116.119.0/24
        echo 128.116.120.0/24
        echo 128.116.123.0/24
        echo 128.116.127.0/24
        echo 141.193.3.0/24
        echo 205.201.62.0/24
    )
) else if "%IPsetStatus%"=="none" (
    type nul > "%listFile%"
) else if "%IPsetStatus%"=="any" ( 
    if exist "%backupFile%" (
        del /f /q "%listFile%"
        ren "%backupFile%" "ipset-all.txt"
    ) else (
        echo [?] Ошибка: Не удалось обновить IPset. Нажмите любую клавишу для выхода...
        pause >nul
    ) 
)
exit /b

REM Статус GameFilter
:game_filter_status
if not exist "%~dp0bin\game_filter.enabled" (
    set "GameFilterStatus=отключен"
    set "GameFilter=12"
    set "GameFilterTCP=12"
    set "GameFilterUDP=12"
    exit /b
)
set "GameFilterMode="
set /p GameFilterMode=<"%~dp0bin\game_filter.enabled"

if /i "%GameFilterMode%"=="all" (
    set "GameFilterStatus=включен (TCP, UDP)"
    set "GameFilter=1024-65535"
    set "GameFilterTCP=1024-65535"
    set "GameFilterUDP=1024-65535"
) else if /i "%GameFilterMode%"=="tcp" (
    set "GameFilterStatus=включен (TCP)"
    set "GameFilter=1024-65535"
    set "GameFilterTCP=1024-65535"
    set "GameFilterUDP=12"
) else (
    set "GameFilterStatus=включен (UDP)"
    set "GameFilter=1024-65535"
    set "GameFilterTCP=12"
    set "GameFilterUDP=1024-65535"
)
exit /b

REM Переключение GameFilter
:game_filter_switch
if not exist "%~dp0bin\game_filter.enabled" (
    echo all>"%~dp0bin\game_filter.enabled"
    exit /b
)

set "GameFilterMode="
set /p GameFilterMode=<"%~dp0bin\game_filter.enabled"

if /i "%GameFilterMode%"=="all" (
    echo tcp>"%~dp0bin\game_filter.enabled"
) else if /i "%GameFilterMode%"=="tcp" (
    echo udp>"%~dp0bin\game_filter.enabled"
) else if /i "%GameFilterMode%"=="udp" (
    del /f /q "%~dp0bin\game_filter.enabled"
)
exit /b

REM Статус автоматической проверки обновлений
:check_updates_status
if exist "%~dp0bin\check_updates.enabled" (
    set "CheckUpdatesStatus=включена"
) else (
    set "CheckUpdatesStatus=отключена"
)
exit /b

REM Переключение автоматической проверки обновлений
:check_updates_switch
if not exist "%~dp0bin\check_updates.enabled" (
    type nul > "%~dp0bin\check_updates.enabled"
    call :check_updates
) else (
    del /f /q "%~dp0bin\check_updates.enabled"
    set "UpdateStatus="
)
exit /b

REM Проверка обновлений
:check_updates
if not exist "%~dp0bin\check_updates.enabled" (
    exit /b
)

cls
echo [?] Инфо: Идет получение информации о последних обновлениях...

set "GLOBAL_VERSION_URL=https://raw.githubusercontent.com/FunsyMe/Orbitus-Service/main/.service/orbitus_version.txt"
for /f "delims=" %%A in ('call "pwsh.exe" -NoProfile -Command "(Invoke-WebRequest -Uri \"%GLOBAL_VERSION_URL%\" -Headers @{\"Cache-Control\"=\"no-cache\"} -UseBasicParsing -TimeoutSec 5).Content.Trim()" 2^>nul') do set "GLOBAL_VERSION=%%A"

if "%GLOBAL_VERSION%"=="" (
    set "UpdateStatus=[ошибка]"
) else if not "%LOCAL_VERSION%"=="%GLOBAL_VERSION%" (
    set "UpdateStatus=[доступно обновление v%GLOBAL_VERSION%]"
)

cls
exit /b

REM Загрузка утилиты в меню Пуск
:load_start_menu
if exist "%APPDATA%\Microsoft\Windows\Start Menu\Programs\Orbitus Service.lnk" (
    exit /b
)

cls
echo [?] Инфо: Идет добавление утилиты в меню Пуск...

set "targetFile=%~f0"
set "shortcutFile=%APPDATA%\Microsoft\Windows\Start Menu\Programs\Orbitus Service.lnk"

"pwsh.exe" -Command ^
    $WshShell = New-Object -ComObject WScript.Shell; ^
    $Shortcut = $WshShell.CreateShortcut('%shortcutFile%'); ^
    $Shortcut.TargetPath = '%targetFile%'; ^
    $Shortcut.Save();

cls
exit /b