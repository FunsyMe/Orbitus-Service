$host.UI.RawUI.WindowTitle = "Обновление приложения Ninja Service"

# Dir Variables
$rootDir = Split-Path $PSScriptRoot -Parent
$ninjaService = Join-Path $rootDir "ninja_service.bat"
$versionFile = Join-Path $rootDir "bin\ninja_version.txt"

# Archive Variables
$zipDir = "$env:TEMP\Ninja.Service.zip"
$extractDir = "$env:TEMP\Ninja.Service"

# Check Admin
$currentPrincipal = New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())

if (-not $currentPrincipal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Write-Host "[ОШИБКА] Запустите от имени администратора" -ForegroundColor Red
    Write-Host "Нажмите любую клавишу для выхода..."
    [void][System.Console]::ReadKey($true)

    Start-Process $ninjaService
    exit
}

# Get Release
Write-Host "[ИНФО] Идет поиск обновлений Ninja Service" -ForegroundColor Cyan

$release = Invoke-WebRequest `
    -Uri "https://raw.githubusercontent.com/FunsyMe/Ninja-Service/main/.service/ninja_version.txt" `
    -Headers @{ "Cache-Control"="no-cache" } `
    -UseBasicParsing -TimeoutSec 5
$newVersion = $release.Content.Trim()

# Compare Verison
$currentVersion = Get-Content $versionFile | Select-Object -First 1

if ($newVersion -eq $currentVersion) {
    Write-Host
    Write-Host "[ИНФО] Новых обновлений не найдено" -ForegroundColor Cyan
    Write-Host "Нажмите любую клавишу для выхода..."
    [void][System.Console]::ReadKey($true)
    
    Start-Process $ninjaService
    exit
}
Write-Host "[ИНФО] Найдено новое обновление Ninja Serivce v$newVersion" -ForegroundColor Cyan

# User Input
do {
    Write-Host "[ВВОД] Вы желаете обновить Ninja Service (Y/N): " -ForegroundColor Cyan -NoNewline
    $continue = Read-Host
} until ($continue -match '^[YyNn]$')

if ($continue -match '^[Nn]$') {
    Start-Process $ninjaService
    exit
}
Clear-Host

# Zapret
try {
    Stop-Service -Name 'zapret' -Force -ErrorAction SilentlyContinue
    Remove-Service -Name 'zapret' -ErrorAction SilentlyContinue

    Write-Host "[ОК] Сервис zapret успешно удален" -ForegroundColor Green
} catch {
    Write-Host "[ОШИБКА] Не удалось удалить сервис Zapret" -ForegroundColor Red
}

# Winws
try {
    Stop-Process -Name 'winws' -Force -ErrorAction SilentlyContinue
    Write-Host "[ОК] Сервис winws успешно удален" -ForegroundColor Green
} catch {
    Write-Host "[ОШИБКА] Не удалось удалить сервис winws" -ForegroundColor Red
}

# WinDivert
try {
    Stop-Service -Name 'WinDivert' -Force -ErrorAction SilentlyContinue
    Remove-Service -Name 'WinDivert' -ErrorAction SilentlyContinue

    Write-Host "[ОК] Сервис WinDivert успешно удален" -ForegroundColor Green
} catch {}

# WinDivert14
try {
    Stop-Service -Name 'WinDivert14' -Force -ErrorAction SilentlyContinue
    Remove-Service -Name 'WinDivert14' -ErrorAction SilentlyContinue

    Write-Host "[ОК] Сервис WinDivert14 успешно удален" -ForegroundColor Green
} catch {
    Write-Host "[ОШИБКА] Не удалось удалить сервис WinDivert14" -ForegroundColor Red
}

# Download Archive
try {
    Invoke-WebRequest -Uri "https://github.com/FunsyMe/Ninja-Service/releases/latest/download/Ninja.Service.zip" -OutFile $zipDir
    Write-Host "[ОК] Ninja Service успешно скачался" -ForegroundColor Green
}
catch {
    Write-Host "[ОШИБКА] Не удалось скачать Ninja Service" -ForegroundColor Red
    Write-Host "Нажмите любую клавишу для выхода..."
    [void][System.Console]::ReadKey($true)
    
    Start-Process $ninjaService -NoNewWindow
    exit
}

# Unarchive
$ProgressPreference = 'SilentlyContinue'
if (Test-Path $extractDir) {
    Remove-Item $extractDir -Recurse -Force | Out-Null
}
Expand-Archive -Path $zipDir -DestinationPath $extractDir | Out-Null
$ProgressPreference = 'Continue'

# Clear Folder
if (Test-Path $rootDir) {
    Get-ChildItem -Path $rootDir -Force |
        Where-Object { $_.Name -ne "zapret_update.ps1" } |
        Remove-Item -Recurse -Force | Out-Null
} else {
    New-Item -ItemType Directory -Path $rootDir | Out-Null
}

# Copy Files
Copy-Item -Path "$extractDir\*" -Destination $rootDir -Recurse -Force | Out-Null
Write-Host

Write-Host "[ОК] Ninja Service успешно обновлен" -ForegroundColor Green
Write-Host "Нажмите любую клавишу для выхода..."

[void][System.Console]::ReadKey($true)
Start-Process $ninjaService
exit