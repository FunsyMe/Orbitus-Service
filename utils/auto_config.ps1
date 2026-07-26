$host.UI.RawUI.WindowTitle = "Автоматический поиск конфигураций"
$ProgressPreference = 'SilentlyContinue'

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
            Sort-Object { $name = $_.Name; if ($name -eq "general.bat") { $name = "general .bat" } [Regex]::Replace($name, '(\d+)', { $args[0].Value.PadLeft(8, '0') }) }

if (-not $batFiles) {
    Write-Host "[ОШИБКА] Не найдены general*.bat файлы" -ForegroundColor Red
    Exit-Script
}

# Check Winws
if (Get-Process -Name "winws" -ErrorAction SilentlyContinue) {
    Write-Host "[ОШИБКА] Остановите сервис zapret" -ForegroundColor Red
    Write-Host "Нажмите любую кнопку для выхода..."

    [void][System.Console]::ReadKey($true)
    exit
}

Write-Host "[ИНФО] Прохождение теста может занять время. Пожалуйста, подождите" -ForegroundColor Cyan
Write-Host "[ИНФО] Идет Авто-Поиск пре-конфига Zapret" -ForegroundColor Cyan
Write-Host ""

# Check Configs
for ($configNum = 1; $configNum -le $batFiles.Count; $configNum++) {
    $file = $batFiles[$configNum - 1]
    Clear-DnsClientCache

    Write-Host "Идет проверка конфига $($file.Name) " -ForegroundColor DarkCyan -NoNewline
    Write-Host "[$configNum/$($batFiles.Count)]" -ForegroundColor Yellow

    Stop-Zapret
    Write-Host " > Запуск конфига..." -ForegroundColor DarkGray

    $cleanupSw = [System.Diagnostics.Stopwatch]::StartNew()
    while ((Get-Process -Name "winws" -ErrorAction Ignore) -and ($cleanupSw.Elapsed.TotalSeconds -lt 3)) {
        Start-Sleep -Milliseconds 100
    }
    $cleanupSw.Stop()
    
    # Start Config
    $proc = Start-Process cmd.exe `
        -ArgumentList "/c `"$($file.FullName)`"" `
        -WorkingDirectory $rootDir `
        -WindowStyle Hidden `
        -PassThru

    $timeout = 10
    $sw = [System.Diagnostics.Stopwatch]::StartNew()
    $ready = $false

    while ($sw.Elapsed.TotalSeconds -lt $timeout) {
        if (Get-Process -Name "winws" -ErrorAction Ignore) {
            $ready = $true
            Start-Sleep -Milliseconds 500
            break
        }
        Start-Sleep -Milliseconds 100
    }
    $sw.Stop()

    if (-not $ready) {
        Write-Host " > Запуск конфига $($file.Name) " -ForegroundColor DarkGray -NoNewline
        Write-Host "не удался, " -ForegroundColor Red -NoNewline
        Write-Host "пропуск" -ForegroundColor DarkGray
        Write-Host ""
        continue
    }
    Write-Host " > Запуск теста..." -ForegroundColor DarkGray

    $configOutput = $targets | ForEach-Object -Parallel {
        $target = $_

        # Check DNS
        if (-not $target.Url) {
            try {
                $pingOk = Test-Connection -ComputerName $target.Ping -Count 1 -Quiet -TimeoutSeconds 4
                $ok = [int]($pingOk)
            } catch {
                $ok = 0
            }

            [PSCustomObject]@{ Name = $target.Name; HttpOk = $ok; Method = "Ping"; Target = $target.Ping; UsedDns = "отсутствует" }
            return
        }

        # Check Sites
        $usedDns = "системный"
        
        try {
            $handler = New-Object System.Net.Http.HttpClientHandler
            $handler.AllowAutoRedirect = $true

            $client = [System.Net.Http.HttpClient]::new($handler)
            $client.Timeout = [System.TimeSpan]::FromSeconds(4)
            $client.DefaultRequestHeaders.Add("User-Agent", "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36")

            $req = [System.Net.Http.HttpRequestMessage]::new([System.Net.Http.HttpMethod]::Get, $target.Url)
            $resp = $client.SendAsync($req, [System.Net.Http.HttpCompletionOption]::ResponseHeadersRead).GetAwaiter().GetResult()

            if ($resp.IsSuccessStatusCode) {
                $ok = 1
            } else {
                $ok = 0
            }
        } catch {
            $ok = 0
            $dohHeaders = @{ "accept" = "application/dns-json" }

            try {
                $dohUrlCF = "https://cloudflare-dns.com/dns-query?name=$($target.Ping)&type=A"
                $dnsResponseCF = Invoke-RestMethod -Uri $dohUrlCF -Headers $dohHeaders -ErrorAction Stop
                
                if ($dnsResponseCF.Status -eq 0 -and $dnsResponseCF.Answer) {
                    $resolvedIp = $dnsResponseCF.Answer[0].data
                    $tcpTest = Test-NetConnection -ComputerName $resolvedIp -Port 443 -WarningAction SilentlyContinue

                    if ($tcpTest.TcpTestSucceeded) {
                        $ok = 1
                        $usedDns = "1.1.1.1"
                    }
                }
            } catch { }

            if ($ok -eq 0) {
                try {
                    $dohUrlG = "https://dns.google/resolve?name=$($target.Ping)&type=A"
                    $dnsResponseG = Invoke-RestMethod -Uri $dohUrlG -Headers $dohHeaders -ErrorAction Stop
                    
                    if ($dnsResponseG.Status -eq 0 -and $dnsResponseG.Answer) {
                        $resolvedIp = $dnsResponseG.Answer[0].data
                        $tcpTest = Test-NetConnection -ComputerName $resolvedIp -Port 443 -WarningAction SilentlyContinue

                        if ($tcpTest.TcpTestSucceeded) {
                            $ok = 1
                            $usedDns = "8.8.8.8"
                        }
                    }
                } catch { }
            }
        } finally {
            if ($null -ne $client)  { $client.Dispose() }
            if ($null -ne $req)     { $req.Dispose() }
            if ($null -ne $handler) { $handler.Dispose() }
        }

        [PSCustomObject]@{ Name = $target.Name; HttpOk = $ok; Method = "HTTP-HEAD"; Target = $target.Url; UsedDns = $usedDns }
    } -ThrottleLimit 4

    # Stop Zapret
    Stop-Zapret
    if ($proc -and -not $proc.HasExited) {
        try {
            Stop-Process -Id $proc.Id -Force -ErrorAction SilentlyContinue
        } catch { }
    }

    # Get Results
    $httpResult = ($configOutput | Measure-Object -Property HttpOk -Sum).Sum
    Write-Host ""

    Write-Host ' > | ' -ForegroundColor DarkGray -NoNewline
    Write-Host ('ИМЯ'.PadRight(16)) -ForegroundColor DarkGray -NoNewline
    
    Write-Host ' | ' -ForegroundColor DarkGray -NoNewline
    Write-Host ('МЕТОД'.PadRight(11)) -ForegroundColor DarkGray -NoNewline
    
    Write-Host ' | ' -ForegroundColor DarkGray -NoNewline
    Write-Host ('DNS'.PadRight(15)) -ForegroundColor DarkGray -NoNewline
    Write-Host ' | ' -ForegroundColor DarkGray -NoNewline

    Write-Host ('СТАТУС'.PadRight(8)) -ForegroundColor DarkGray -NoNewline
    Write-Host ' |' -ForegroundColor DarkGray

    foreach ($result in $configOutput) {
        if ($result.HttpOk -eq 1) {
            $statusText  = "ОК"
            $statusColor = "Green"
        } else {
            $statusText  = "ОШИБКА"
            $statusColor = "Red"
        }

        if ($result.Method -eq "Ping") {
            $dnsText  = "отсутствует"
            $dnsColor = "Gray"
        } elseif ($result.UsedDns -eq "1.1.1.1" -or $result.UsedDns -eq "8.8.8.8") {
            $dnsText  = $result.UsedDns
            $dnsColor = "Yellow"
        } else {
            $dnsText  = "системный"
            $dnsColor = "DarkCyan"
        }

        Write-Host '   | ' -ForegroundColor DarkGray -NoNewline
        Write-Host ($result.Name.PadRight(16)) -ForegroundColor White -NoNewline

        Write-Host ' | ' -ForegroundColor DarkGray -NoNewline
        Write-Host ($result.Method.PadRight(11)) -ForegroundColor White -NoNewline
        
        Write-Host ' | ' -ForegroundColor DarkGray -NoNewline
        Write-Host ($dnsText.PadRight(15)) -ForegroundColor $dnsColor -NoNewline
        
        Write-Host ' | ' -ForegroundColor DarkGray -NoNewline
        Write-Host ($statusText.PadRight(8)) -ForegroundColor $statusColor -NoNewline

        Write-Host ' |' -ForegroundColor DarkGray
    }

    Write-Host ""
    if ($httpResult -eq $targets.Count) {
        Stop-Zapret

        Write-Host " > Кажется, Вам " -ForegroundColor DarkGray -NoNewline
        Write-Host "подходит " -ForegroundColor Green -NoNewline
        Write-Host "конфиг $($file.Name)" -ForegroundColor DarkGray

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