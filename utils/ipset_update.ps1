$host.UI.RawUI.WindowTitle = "Обновление файла IPset"

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

# Download File
$hostsFile = "$rootDir\lists\ipset-all.txt"
$hostsUrl = "https://raw.githubusercontent.com/FunsyMe/Ninja-Service/main/.service/list-ipset"
$hostText = Invoke-WebRequest -Uri $hostsUrl -UseBasicParsing | Select-Object -ExpandProperty Content

# Write File
try {
    Clear-Content -Path $hostsFile -ErrorAction SilentlyContinue
    Add-Content -Path $hostsFile -Value $hostText -ErrorAction SilentlyContinue
}
catch {
    Write-Host "[ОШИБКА] Файл ipset-all не может быть изменен" -ForegroundColor Red
    Write-Host "Нажмите любую клавишу для выхода..."

    [void][System.Console]::ReadKey($true)
    exit
}

Write-Host "[ОК] Файл ipset-all успешно изменен" -ForegroundColor Green
Write-Host "Нажмите любую клавишу для выхода..."

[void][System.Console]::ReadKey($true)
exit