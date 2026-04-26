$host.UI.RawUI.WindowTitle = "Обновить PowerShell"

# Check Admin
$currentPrincipal = New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())

if (-not $currentPrincipal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Write-Host "[ОШИБКА] Запустите от имени администратора" -ForegroundColor Red
    Write-Host "Нажмите любую кнопку для выхода..."

    [void][System.Console]::ReadKey($true)
    exit
}

# User Input
Write-Host "[ВВОД] Вы желаете установить PowerShell? (Y/N): " -ForegroundColor Cyan -NoNewline
$continue = Read-Host
                    
if ($continue.ToLower() -ne "y") {
    exit
}

# Download PowerShell
Write-Host "[ИНФО] Идет установка PowerShell" -ForegroundColor Cyan
Write-Host ""

winget.exe install --id Microsoft.PowerShell --source winget
if ($LASTEXITCODE -eq 0) {
    Write-Host ""
    Write-Host "[ОК] PowerShell успешно обновлен" -ForegroundColor Green
    Write-Host "[ИНФО] После выхода, перезапустите Ninja Service" -ForegroundColor Cyan
    Write-Host "Нажмите любую кнопку для выхода..."
    
    [void][System.Console]::ReadKey($true)
    exit
} else {
    Write-Host ""
    Write-Host "[ОШИБКА] Не удалось обновить PowerShell" -ForegroundColor Red
    Write-Host "[ИНФО] После выхода, перезапустите Ninja Service" -ForegroundColor Cyan
    Write-Host "Нажмите любую кнопку для выхода..."

    [void][System.Console]::ReadKey($true)
    exit
}