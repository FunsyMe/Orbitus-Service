$host.UI.RawUI.WindowTitle = "Диагностика Zapret"

# Check Admin
$currentPrincipal = New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())

if (-not $currentPrincipal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Write-Host "[ОШИБКА] Запустите от имени администратора" -ForegroundColor Red
    Write-Host "Нажмите любую клавишу для выхода..."

    [void][System.Console]::ReadKey($true)
    exit
}

$ErrorActionPreference = 'SilentlyContinue'

# Test Service
function Test-Service {
    param (
        [string]$ServiceName
    )
    $service = Get-Service -Name $ServiceName -ErrorAction SilentlyContinue
    
    if ($service) {
        $status = $service.Status
        if ($status -eq "Running") {
            Write-Host "[ОК] $ServiceName работает" -ForegroundColor Green
        } elseif ($status -eq "StopPending") {
            Write-Host "$ServiceName находится в состоянии ожидания, что может быть вызвано конфликтом с другим zapret" -ForegroundColor Red
        } else {
            Write-Host "[ОШИБКА] $ServiceName не работает" -ForegroundColor Red
        }
    } else {
        Write-Host "[ОШИБКА] Сервис $ServiceName не работает" -ForegroundColor Red
    }
}

# Bast Filtering Engine
$filtering_engine = Get-Service -Name BFE -ErrorAction SilentlyContinue

if ($filtering_engine.Status -eq 'Running') {
    Write-Host "[ОК] Base Filtering Engine" -ForegroundColor Green
} else {
    Write-Host "[ОШИБКА] Base Filtering Engine не запущен" -ForegroundColor Green
}

# Proxy
$proxyState = 0
$proxyServer = ""

try {
    $proxyStateValue = Get-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Internet Settings" -Name "ProxyEnable" -ErrorAction Stop
    if ($proxyStateValue.ProxyEnable -eq 1) {
        $proxyState = 1
    }
} catch {
    Write-Host "[ОШИБКА] Ошибка чтения реестра: $($_.Exception.Message)" -ForegroundColor Red
}

if ($proxyState -eq 1) {
    try {
        $proxyServerValue = Get-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Internet Settings" -Name "ProxyServer" -ErrorAction Stop
        $proxyServer = $proxyServerValue.ProxyServer

        Write-Host "[ВНИМАНИЕ] Система Proxy включена: $proxyServer" -ForegroundColor Yellow
        Write-Host "[ВНИМАНИЕ] Убедитесь, что он действителен, или отключите его, если вы не используете Proxy" -ForegroundColor Yellow
    }
    catch {
        Write-Host "[ОШИБКА] Ошибка чтения реестра: $($_.Exception.Message)" -ForegroundColor Red
    }
} else {
    Write-Host "[ОК] Proxy" -ForegroundColor Green
}

# Netsh
$netshCommand = Get-Command netsh -ErrorAction SilentlyContinue

if (!$netshCommand) {
    Write-Host "[ОШИБКА] Команда Netsh не найдена, проверьте переменную PATH: $env:PATH" -ForegroundColor Red
    Write-Host "Нажмите любую клавишу для выхода..."

    [void][System.Console]::ReadKey($true)
    exit
}

# TCP
$tcp = netsh interface tcp show global > $null

if ($tcp -notmatch "(?i)timestamps.*enabled") {
    Write-Host "[ВНИМАНИЕ] TCP timestamps выключены. Запуск TCP timestamps" -ForegroundColor Yellow
    netsh interface tcp set global timestamps=enabled > $null

    if ($LASTEXITCODE -eq 0) {
        Write-Host "[ОК] TCP timestamps успешно запущены" -ForegroundColor Green
    } else {
        Write-Host "[ОШИБКА] Не удалось запустить TCP timestamps" -ForegroundColor Red
    }
} else {
    Write-Host "[ОК] TCP" -ForegroundColor Green
}

# AdguardSvc
$adguard = Get-Process -Name "AdguardSvc" -ErrorAction SilentlyContinue

if ($adguard) {
    Write-Host "[ОШИБКА] Найден процесс Adguard. Adguard может вызывать проблемы с Discord" -ForegroundColor Red
} else {
    Write-Host "[ОК] Adguard" -ForegroundColor Green
}

# Killer
$killer = Get-Service -Name "*Killer*" -ErrorAction SilentlyContinue

if ($killer) {
    Write-Host "[ОШИБКА] Найден процесс Killer. Killer вызывает проблемы с Zapret" -ForegroundColor Red
} else {
    Write-Host "[ОК] Killer" -ForegroundColor Green
}

# Intel Connectivity Network Service
$icns = Get-Service | Where-Object {
    (($_.Name -like "*Intel*" -and $_.Name -like "*Connectivity*" -and $_.Name -like "*Network*") -or
     ($_.DisplayName -like "*Intel*" -and $_.DisplayName -like "*Connectivity*" -and $_.DisplayName -like "*Network*"))
}

if ($icns) {
    Write-Host "[ОШИБКА] Найден процесс Intel Connectivity Network Service. Он вызывает проблемы с Zapret" -ForegroundColor Red
} else {
    Write-Host "[ОК] Intel Connectivity" -ForegroundColor Green
}

# Check Point
$checkPoint = Get-Service -Name "*TracSrvWrapper*" -ErrorAction SilentlyContinue
$epwd = Get-Service -Name "*EPWD*" -ErrorAction SilentlyContinue

if ($checkPoint -or $epwd) {
    Write-Host "[ОШИБКА] Найден процесс Check Point. Check Point вызывает проблемы с Zapret" -ForegroundColor Red
} else {
    Write-Host "[ОК] Check Point" -ForegroundColor Green
}

# SmartByte
$smartByte = Get-Service | Where-Object {
    ($_.Name -like "*SmartByte*") -or ($_.DisplayName -like "*SmartByte*")
}

if ($smartByte) {
    Write-Host "[ОШИБКА] Найден процесс SmartByte. SmartByte вызывает проблемы с Zapret" -ForegroundColor Red
} else {
    Write-Host "[ОК] SmartByte" -ForegroundColor Green
}

# WinDivert64
$HOME_PATH = Split-Path $PSScriptRoot -Parent
$BIN_PATH = Join-Path $HOME_PATH "bin"

if (!(Test-Path "$BIN_PATH\*.sys")) {
    Write-Host "[ОШИБКА] Файл WinDivert64.sys не найден" -ForegroundColor Red
} else {
    Write-Host "[ОК] WinDivert64.sys" -ForegroundColor Green
}

# VPN
$vpn = Get-Service | Where-Object {
    ($_.Name -like "*VPN*") -or ($_.DisplayName -like "*VPN*")
}

if ($vpn) {
    $serviceList = ($vpn | ForEach-Object { $_.Name }) -join ","
    Write-Host "[ВНИМАНИЕ] Найдены VPN: $serviceList. Нектороые VPN могут вызывать проблемы с Zapret" -ForegroundColor Yellow
} else {
    Write-Host "[ОК] VPN" -ForegroundColor Green
}

# DNS
try {
    $dohCount = Get-ChildItem -Recurse -Path 'HKLM:\System\CurrentControlSet\Services\Dnscache\InterfaceSpecificParameters\' |
                Get-ItemProperty |
                Where-Object { $_.DohFlags -gt 0 } |
                Measure-Object |
                Select-Object -ExpandProperty Count
} catch {
    $dohCount = 0
}

if ($dohCount -gt 0) {
    Write-Host "[ОК] DNS" -ForegroundColor Green
} else {
    Write-Host "[ВНИМАНИЕ] Убедитесь, что в браузере настроен Secure DNS с использованием нестандартного DNS-провайдера" -ForegroundColor Yellow
}

# Test Services
Write-Host
Test-Service -ServiceName "zapret"
Test-Service -ServiceName "WinDivert"

Write-Host
Write-Host "[ОК] Диагностика успешно пройдена" -ForegroundColor Green
Write-Host "Нажмите любую клавишу для выхода..."

[void][System.Console]::ReadKey($true)
exit