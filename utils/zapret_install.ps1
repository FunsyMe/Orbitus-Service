$host.UI.RawUI.WindowTitle = "Запуск и добавление Zapret в автозапуск"

# Check Admin
$currentPrincipal = New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())

if (-not $currentPrincipal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Write-Host "[ОШИБКА] Запустите от имени администратора" -ForegroundColor Red
    Write-Host "Нажмите любую клавишу для выхода..."

    [void][System.Console]::ReadKey($true)
    exit
}

# Dir Variables
$rootDir = Split-Path $PSScriptRoot -Parent
$preConfigsDir = Join-Path $rootDir "pre-configs"
$binDir = Join-Path $rootDir "bin"
$listsDir = Join-Path $rootDir "lists"

$gameFilterFile = Join-Path $binDir "game_filter.enabled"
$winwsService = Join-Path $binDir "winws.exe"
$proxy = Join-Path $binDir "proxy.exe"

# Tatget Configs
$batFiles = Get-ChildItem $preConfigsDir -Filter "*.bat" |
            Sort-Object Name
Set-Location $preConfigsDir

if (-not $batFiles) {
    Write-Host "[ОШИБКА] Ненайдены general*.bat файлы" -ForegroundColor Red
    Write-Host "Нажмите любую клавишу для выхода..."

    [void][System.Console]::ReadKey($true)
    exit
}

# Game Filter Status
if (Test-Path $gameFilterFile) {
    $gameFilterData = Get-Content $gameFilterFile | Select-Object -First 1

    if ($gameFilterData -eq "all") {
        $gameFilter = "1024-65535"
        $gameFilterTcp = "1024-65535"
        $gameFilterUdp = "1024-65535"
    } elseif ($gameFilterData -eq "tcp") {
        $gameFilter = "1024-65535"
        $gameFilterTcp = "1024-65535"
        $gameFilterUdp = "12"
    } else {
        $gameFilter = "1024-65535"
        $gameFilterTcp = "12"
        $gameFilterUdp = "1024-65535"
    }
} else {
    $gameFilter = "12"
    $gameFilterTcp = "12"
    $gameFilterUdp = "12"
}

# User Input
Write-Host "[ВВОД] Введите номер конфига (цифра)" -ForegroundColor Cyan
Write-Host ""

for ($i = 0; $i -lt $batFiles.Count; $i++) {
    Write-Host "$($i + 1). $($batFiles[$i].Name)"
}

Write-Host ""
Write-Host "[ВВОД] Ваш выбор [1-$i]: " -ForegroundColor Cyan -NoNewline
$batNumber = (Read-Host) -as [int]

# Check Input
if ($null -eq $batNumber -or
    $batNumber -gt $batFiles.Count -or
    $batNumber -eq 0) 
{
    Write-Host
    Write-Host "[ОШИБКА] Неверный выбор" -ForegroundColor Red
    Write-Host "Нажмите любую клавишу для выхода..."

    [void][System.Console]::ReadKey($true)
    exit
}
Clear-Host
Write-Host "[ИНФО] Добавление Zapret в Авто-Запуск может занять некоторое время. Пожалуйста, подождите" -ForegroundColor Cyan
Write-Host "[ИНФО] Добавляемый конфиг: $($batFiles[$batNumber - 1])" -ForegroundColor Cyan
Write-Host

# Parse Arguments
$selectedFile = $batFiles[$batNumber - 1].FullName
$fileName = $batFiles[$batNumber - 1].BaseName
$lines = Get-Content $selectedFile -Raw

$winwsPattern = 'winws.exe'
$pos = $lines.IndexOf($winwsPattern, [System.StringComparison]::OrdinalIgnoreCase)
$rawArgs = ""

if ($pos -ge 0) {
    $start = $pos + $winwsPattern.Length
    $rawArgs = $lines.Substring($start)
} else {
    Write-Host "[ОШИБКА] В выбранном .bat не найден запуск winws.exe" -ForegroundColor Red
    Write-Host "Нажмите любую клавишу для выхода..."

    [void][System.Console]::ReadKey($true)
    exit
}

# Delete Bin
$rawArgs = $rawArgs.Substring(2)
$rawArgs = $rawArgs.Replace('exit /b 0', '')
$rawArgs = $rawArgs.Replace('start "" /high "%BIN%proxy.exe"', '')

$rawArgs = $rawArgs.Replace('^', '')
$rawArgs = $rawArgs.Replace('=', ' ')

$rawArgs = $rawArgs.Replace('sni ', 'sni=')
$rawArgs = $rawArgs -replace '\r?\n', ''

# Replace Variables
$rawArgs = $rawArgs.Replace('%GameFilter%', $gameFilter)
$rawArgs = $rawArgs.Replace('%GameFilterTCP%', $gameFilterTcp)
$rawArgs = $rawArgs.Replace('%GameFilterUDP%', $gameFilterUdp)

$rawArgs = $rawArgs.Replace('%BIN%', "$binDir\")
$rawArgs = $rawArgs.Replace('%LISTS%',"$listsDir\")

$finalArgs = $rawArgs.Trim()

# Set Timestamps
if (-not (Get-NetTCPSetting -SettingName Internet).Timestamps) {
    Set-NetTCPSetting -SettingName Internet -Timestamps Enabled | Out-Null
}

# Remove Zapret
try {
    Stop-Service -Name 'zapret' -Force -ErrorAction SilentlyContinue
    Remove-Service -Name 'zapret' -ErrorAction SilentlyContinue

    Write-Host "[ОК] Сервис zapret успешно удален" -ForegroundColor Green
} catch {
    Write-Host "[ОШИБКА] Не удалось удалить сервис Zapret" -ForegroundColor Red
}

# Remove Winws
try {
    Stop-Process -Name 'winws' -Force -ErrorAction SilentlyContinue
} catch {}

# WinDivert
try {
    Stop-Service -Name 'WinDivert' -Force -ErrorAction SilentlyContinue
    Remove-Service -Name 'WinDivert' -ErrorAction SilentlyContinue
} catch {}

# WinDivert14
try {
    Stop-Service -Name 'WinDivert14' -Force -ErrorAction SilentlyContinue
    Remove-Service -Name 'WinDivert14' -ErrorAction SilentlyContinue
} catch {}

# Create Service
$winwsDir = "`"$winwsService`" $finalArgs"
try {
    New-Service `
        -Name zapret `
        -BinaryPathName $winwsDir `
        -DisplayName 'zapret' `
        -StartupType Automatic | Out-Null

    Write-Host "[ОК] Сервис zapret успешно создан" -ForegroundColor Green
} catch {
    Write-Host "[ОШИБКА] Не удалось создать сервис Zapret" -ForegroundColor Red
}

# Create Proxy
Stop-Process -Name "proxy" -Force -ErrorAction SilentlyContinue

$action = New-ScheduledTaskAction -Execute $proxy -WorkingDirectory $binDir
$trigger = New-ScheduledTaskTrigger -AtLogOn
$settings = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries

Register-ScheduledTask -TaskName "Proxy Telegram" `
    -Action $action `
    -Trigger $trigger `
    -Settings $settings `
    -Force | Out-Null

# Edit Service
try {
    Set-Service -Name 'zapret' -Description 'Ninja Service'
    Write-Host "[ОК] Конфигурация сервиса успешно обновлена" -ForegroundColor Green
} catch {
    Write-Host "[ОШИБКА] Не удалось обновить конфигурацию сервиса" -ForegroundColor Red
}

# Start Service
try {
    Start-Service -Name zapret -ErrorAction Stop
    Write-Host "[ОК] Сервис успешно запущен" -ForegroundColor Green
} catch {
    Write-Host "[ОШИБКА] Не удалось запустить сервис" -ForegroundColor Red
}

# Start Proxy
try {
    Start-Process -FilePath $proxy -WorkingDirectory $binDir
    Write-Host "[ОК] Proxy успешно запущен" -ForegroundColor Green
} catch {
    Write-Host "[ОШИБКА] Не удалось запустить Proxy" -ForegroundColor Red
}

# Edit Regedit
try {
    New-ItemProperty -Path 'HKLM:\System\CurrentControlSet\Services\zapret' -Name 'zapret-discord-youtube' -Value $fileName -PropertyType String -Force | Out-Null
    Write-Host "[ОК] Regedit успешно обновлен" -ForegroundColor Green
} catch {
    Write-Host "[ОШИБКА] Не удалось обновить Regedit" -ForegroundColor Red
}

# Add to WinLogon
$fileDir = Join-Path $PSScriptRoot "zapret_status.ps1"
$action = New-ScheduledTaskAction -Execute "pwsh.exe" `
    -Argument "-NoProfile -WindowStyle Hidden -ExecutionPolicy Bypass -File `"$fileDir`" -kgyat"
$trigger = New-ScheduledTaskTrigger -AtLogOn
$trigger.Delay = "PT30S"

$settings = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries
$principal = New-ScheduledTaskPrincipal -UserId "SYSTEM" -LogonType ServiceAccount -RunLevel Highest

Register-ScheduledTask -TaskName "Zapret Status" `
    -Action $action `
    -Trigger $trigger `
    -Settings $settings `
    -Principal $principal `
    -Force | Out-Null

$psi = New-Object System.Diagnostics.ProcessStartInfo
$psi.FileName = "pwsh.exe"
$psi.Arguments = "-NoProfile -WindowStyle Hidden -ExecutionPolicy Bypass -File `"$fileDir`" -kgyat"
$psi.CreateNoWindow = $true
$psi.UseShellExecute = $false
[System.Diagnostics.Process]::Start($psi) | Out-Null

Write-Host ""
Write-Host "[ОК] Сервис успешно установлен в Авто-Запуск" -ForegroundColor Green
Write-Host "Нажмите любую клавишу для выхода..."

[void][System.Console]::ReadKey($true)
exit