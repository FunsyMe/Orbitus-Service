$host.UI.RawUI.WindowTitle = "Автоматический поиск конфигураций"

# Stop Zapret
function Stop-Zapret {
    Stop-Process -Name winws -Force -ErrorAction Ignore
}

# Exit Script
function Exit-Script {
    param ([int]$ExitCode = 0)
    Write-Host "Нажмите любую клавишу для выхода..."
    [void][System.Console]::ReadKey($true)
    
    exit $ExitCode
}

# Dir Variables
$rootDir = Split-Path $PSScriptRoot -Parent
$preConfigsDir = Join-Path $rootDir "pre-configs"

# Check Admin
$currentPrincipal = New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())

if (-not $currentPrincipal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Write-Host "[ОШИБКА] Запустите от имени администратора" -ForegroundColor Red
    Exit-Script
}

# Target Sites
$targets = @(
    @{ Name = "Discord"; Url = "https://discord.com"; Ping = "discord.com" }
    @{ Name = "YouTube"; Url = "https://www.youtube.com"; Ping = "youtube.com" }
    @{ Name = "Google";  Url = "https://www.google.com";  Ping = "google.com" }
    @{ Name = "Cloudflare DNS"; Url = $null; Ping = "1.1.1.1" }
)

# Target Configs
$batFiles = Get-ChildItem $preConfigsDir -Filter "*.bat" |
            Sort-Object Name

if (-not $batFiles) {
    Write-Host "[ОШИБКА] Не найдены general*.bat файлы" -ForegroundColor Red
    Exit-Script
}

Write-Host "[ИНФО] Все активные Zapret будут остановлены" -ForegroundColor Cyan
Write-Host "[ИНФО] Прохождение теста может занять время. Пожалуйста, подождите" -ForegroundColor Cyan
Write-Host "[ИНФО] Идет Авто-Поиск пре-конфига Zapret" -ForegroundColor Cyan
Write-Host ""

# Check Configs
for ($configNum = 1; $configNum -le $batFiles.Count; $configNum++) {
    $file = $batFiles[$configNum - 1]

    Write-Host "Идет проверка конфига $($file.Name) " -ForegroundColor DarkCyan -NoNewline
    Write-Host "[$configNum/$($batFiles.Count)]" -ForegroundColor Yellow

    Stop-Zapret
    Write-Host " > Запуск конфига..." -ForegroundColor DarkGray

    # Start Config
    $proc = Start-Process cmd.exe `
        -ArgumentList "/c `"$($file.FullName)`"" `
        -WorkingDirectory $rootDir `
        -WindowStyle Hidden `
        -PassThru
    Start-Sleep -Milliseconds 800

    Write-Host " > Запуск теста..." -ForegroundColor DarkGray

    $configOutput = $targets | ForEach-Object -Parallel {
        $t = $_

        # Check DNS
        if (-not $t.Url) {
            try {
                $pingOk = Test-Connection -ComputerName $t.Ping -Count 1 -Quiet -TimeoutSeconds 4
                $ok = [int]($pingOk)
            } catch {
                $ok = 0
            }

            [PSCustomObject]@{ Name = $t.Name; HttpOk = $ok; Method = "Ping"; Target = $t.Ping }
            return
        }

        # Check Sites
        try {
            $handler = New-Object System.Net.Http.HttpClientHandler
            $handler.AllowAutoRedirect = $true

            $client = [System.Net.Http.HttpClient]::new($handler)
            $client.Timeout = [System.TimeSpan]::FromSeconds(4)

            $req = [System.Net.Http.HttpRequestMessage]::new([System.Net.Http.HttpMethod]::Head, $t.Url)
            $resp = $client.SendAsync($req).GetAwaiter().GetResult()

            $ok = if ($resp.IsSuccessStatusCode) { 1 } else { 0 }
        } catch {
            $ok = 0
        } finally {
            if ($null -ne $client)  { $client.Dispose() }
            if ($null -ne $req)     { $req.Dispose() }
            if ($null -ne $handler) { $handler.Dispose() }
        }

        [PSCustomObject]@{ Name = $t.Name; HttpOk = $ok; Method = "HTTP-HEAD"; Target = $t.Url }
    } -ThrottleLimit 64

    # Stop Zapret
    Stop-Zapret
    if ($proc -and -not $proc.HasExited) {
        try {
            Stop-Process -Id $proc.Id -Force -ErrorAction SilentlyContinue
        } catch { }
    }

    # Get Reults
    $httpResult = ($configOutput | Measure-Object -Property HttpOk -Sum).Sum
    
    if ($httpResult -eq $targets.Count) {
        Stop-Zapret

        Write-Host " > Кажется, Вам " -ForegroundColor DarkGray -NoNewline
        Write-Host "подходит " -ForegroundColor Green -NoNewline
        Write-Host "конфиг $($file.Name)" -ForegroundColor DarkGray
        Write-Host ""

        if ($configNum -ne $batFiles.Count) {
            do {
                Write-Host "[ВВОД] Вы желаете продолжить тест? (Y/N): " -ForegroundColor Cyan -NoNewline
                $continue = Read-Host
            } until ($continue -match '^[YyNn]$')


            if ($continue -match '^[Nn]$') {
                exit $configNum
            }
        }
    } elseif ($httpResult -ge ($targets.Count - 1)) {
        Write-Host " > Кажется, Вам " -ForegroundColor DarkGray -NoNewline
        Write-Host "частично подходит " -ForegroundColor Yellow -NoNewline
        Write-Host "конфиг $($file.Name)" -ForegroundColor DarkGray
        Write-Host ""
    } else {
        Write-Host " > Кажется, Вам " -ForegroundColor DarkGray -NoNewline
        Write-Host "не подходит " -ForegroundColor Red -NoNewline
        Write-Host "конфиг $($file.Name)" -ForegroundColor DarkGray
        Write-Host ""
    }
}

Write-Host "[ОК] Авто-Поиск пре-конфига успешно пройден" -ForegroundColor Green
Exit-Script -ExitCode -2