$host.UI.RawUI.WindowTitle = "Обновить hosts"

# Check Admin
$currentPrincipal = New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())

if (-not $currentPrincipal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Write-Host "[ОШИБКА] Запустите от имени администратора" -ForegroundColor Red
    Write-Host "Нажмите любую кнопку для выхода..."

    [void][System.Console]::ReadKey($true)
    exit
}

# Dir Variables
$hostsDir = "$env:SystemRoot\System32\drivers\etc\"
$hostsFile = Join-Path $hostsDir "hosts"
$backupFile = Join-Path $hostsDir "hosts.backup"

# Download File
$hostsUrl = "https://raw.githubusercontent.com/FunsyMe/Ninja-Service/main/.service/list-hosts"
$hostText = Invoke-WebRequest -Uri $hostsUrl -UseBasicParsing | Select-Object -ExpandProperty Content

# Remove File
if (!(Test-Path $backupFile)) {
    Rename-Item $hostsFile "hosts.backup"
} else {
    Remove-Item $backupFile
    Rename-Item $hostsFile "hosts.backup"
}

# Write File
try {
    New-Item $hostsFile > $null
    Clear-Content -Path $hostsFile -ErrorAction SilentlyContinue
    Add-Content -Path $hostsFile -Value $hostText -ErrorAction SilentlyContinue
}
catch {
    Write-Host "[ОШИБКА] Файл host не может быть изменен" -ForegroundColor Red
    Write-Host "Нажмите любую кнопку для выхода..."

    [void][System.Console]::ReadKey($true)
    exit
}

Write-Host "[ОК] Файл host успешно изменен" -ForegroundColor Green
Write-Host "[ИНФО] Сделан бэк-ап файла hosts" -ForegroundColor Cyan
Write-Host "Нажмите любую кнопку для выхода..."

[void][System.Console]::ReadKey($true)
exit