$host.UI.RawUI.WindowTitle = "Остановка и удаление Zapret из автозапуска"

# Check Admin
$currentPrincipal = New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())

if (-not $currentPrincipal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Write-Host "[ОШИБКА] Запустите от имени администратора" -ForegroundColor Red
    Write-Host "Нажмите любую клавишу для выхода..."

    [void][System.Console]::ReadKey($true)
    exit
}

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

# Win Logon
Unregister-ScheduledTask -TaskName "Zapret Status" -Confirm:$false -ErrorAction SilentlyContinue | Out-Null

Write-Host ""
Write-Host "[ОК] Zapret остановлен и удален с Авто-Запуска" -ForegroundColor Green
Write-Host "Нажмите любую клавишу для выхода..."

[void][System.Console]::ReadKey($true)
exit