$host.UI.RawUI.WindowTitle = "Сменить активный фейк"

# Check Admin
$currentPrincipal = New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())

if (-not $currentPrincipal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Write-Host "[ОШИБКА] Запустите от имени администратора" -ForegroundColor Red
    Write-Host "Нажмите любую кнопку для выхода..."

    [void][System.Console]::ReadKey($true)
    exit
}

# Dir Variables
$rootDir = Split-Path $PSScriptRoot -Parent
$binDir = Join-Path $rootDir "bin"
$doubleFakeDir = Join-Path $binDir "double_fake.txt"

# Check Winws
if (Get-Process -Name "winws" -ErrorAction SilentlyContinue) {
    Write-Host "[ОШИБКА] Остановите сервис zapret" -ForegroundColor Red
    Write-Host "Нажмите любую кнопку для выхода..."

    [void][System.Console]::ReadKey($true)
    exit
}

# Get Fake
$activeFakeFile = Get-ChildItem $binDir -Filter "active*.bin"
$unactiveFakesFiles = Get-ChildItem $binDir -Filter "quic_initial*.bin"

$activeFakeFileHash = (Get-FileHash $activeFakeFile.FullName).Hash

for ($i = 0; $i -lt $unactiveFakesFiles.Count; $i++) {
    if ((Get-FileHash $unactiveFakesFiles[$i].FullName).Hash -eq $activeFakeFileHash) {
        $file = $unactiveFakesFiles[$i]
        $activeFake = [PSCustomObject]@{
            Name = $file.Name
            Path = $file.FullName
            Hash = Get-FileHash $file.FullName | Select-Object -ExpandProperty Hash
        }
    }
}

# Get Double Fake
$activeDoubleFakeName = Get-Content $doubleFakeDir -Raw
$unactiveDoubleFakesFiles = Get-ChildItem $binDir -Include "quic_initial*.bin", "stun.bin" -Recurse

# Fake User Input
Write-Host "[ИНФО] Активный фейк $($activeFake.Name)" -ForegroundColor Cyan
Write-Host "[ВВОД] Введите номер фейка (цифра)" -ForegroundColor Cyan
Write-Host

for ($i = 0; $i -lt $unactiveFakesFiles.Count; $i++) {
    Write-Host "$($i + 1). $($unactiveFakesFiles[$i].Name)"
}

Write-Host
Write-Host "[ВВОД] Ваш выбор [1-$i]: " -ForegroundColor Cyan -NoNewline
$fakeFile = (Read-Host) -as [int]

if ($null -eq $fakeFile -or
    $fakeFile -gt $unactiveFakesFiles.Count -or
    $fakeFile -le 0) 
{
    Clear-Host
    Write-Host "[ОШИБКА] Неверный выбор" -ForegroundColor Red
    Write-Host "Нажмите любую клавишу для выхода..."

    [void][System.Console]::ReadKey($true)
    exit
}

# Double Fake User Input
Clear-Host
Write-Host "[ИНФО] Активный дабл-фейк $activeDoubleFakeName" -ForegroundColor Cyan
Write-Host "[ВВОД] Введите номер фейка (цифра)" -ForegroundColor Cyan
Write-Host

Write-Host "0. none"
for ($i = 0; $i -lt $unactiveDoubleFakesFiles.Count; $i++) {
    Write-Host "$($i + 1). $($unactiveDoubleFakesFiles[$i].Name)"
}

Write-Host
Write-Host "[ВВОД] Ваш выбор [0-$i]: " -ForegroundColor Cyan -NoNewline
$doubleFakeFile = (Read-Host) -as [int]

if ($null -eq $doubleFakeFile -or
    $doubleFakeFile -gt $unactiveDoubleFakesFiles.Count -or
    $doubleFakeFile -lt 0) 
{
    Clear-Host
    Write-Host "[ОШИБКА] Неверный выбор" -ForegroundColor Red
    Write-Host "Нажмите любую клавишу для выхода..."

    [void][System.Console]::ReadKey($true)
    exit
}

Set-Location $binDir

try {
    Copy-Item $unactiveFakesFiles[$fakeFile - 1] "active_discord_udp.bin" -Force
}
catch {
    Clear-Host
    Write-Host "[ОШИБКА] Не удалось сменить фейк" -ForegroundColor Red
    Write-Host "Нажмите любую клавишу для выхода..."

    [void][System.Console]::ReadKey($true)
    exit
}

Clear-Host
Write-Host "[ОК] Фейк успешно сменен на $($unactiveFakesFiles[$fakeFile - 1].Name)" -ForegroundColor Green

if ($doubleFakeFile -ne 0) {
    try {
        Set-Content -Path $doubleFakeDir -Value "$($unactiveDoubleFakesFiles[$doubleFakeFile - 1].Name)" -NoNewline
        Write-Host "[ОК] Дабл-фейк успешно сменен на $($unactiveFakesFiles[$fakeFile - 1].Name)" -ForegroundColor Green
    }
    catch {
        Clear-Host
        Write-Host "[ОШИБКА] Не удалось сменить дабл-фейк" -ForegroundColor Red
        Write-Host "Нажмите любую клавишу для выхода..."

        [void][System.Console]::ReadKey($true)
        exit
    }
} else {
    Set-Content -Path $doubleFakeDir -Value "none" -NoNewline
    Write-Host "[ОК] Дабл-фейк успешно удален" -ForegroundColor Green
}

Write-Host "Нажмите любую клавишу для выхода..."

[void][System.Console]::ReadKey($true)
exit