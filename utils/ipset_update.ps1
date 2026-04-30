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
$ipsetFile = "$rootDir\lists\ipset-all.txt"

# Download File
$ipsetUrl = "https://raw.githubusercontent.com/FunsyMe/Orbitus-Service/main/.service/list-ipset.txt"

try {
    $ipsetText = Invoke-WebRequest -Uri $ipsetUrl -ErrorAction Stop -UseBasicParsing | Select-Object -ExpandProperty Content
}
catch {
    Write-Host "[ОШИБКА] Не удалось скачать файл ipset-all" -ForegroundColor Red
    Write-Host "Нажмите любую клавишу для выхода..."

    [void][System.Console]::ReadKey($true)
    exit
}

# Write File
try {
    Clear-Content -Path $ipsetFile -ErrorAction SilentlyContinue
    Add-Content -Path $ipsetFile -Value $ipsetText -ErrorAction SilentlyContinue
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