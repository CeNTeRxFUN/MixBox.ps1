<#
    ===========================================================================
    MixBox CheatHunter - ULTIMATE SS-EDITION v4.0 (Recoded from SS-Tools)
    Powered by CeNTeR_FUN | Forensic Module Enabled
    ===========================================================================
#>

$ErrorActionPreference = "SilentlyContinue"
$Global:Results = @()
Clear-Host

Write-Host "--- MixBox CheatHunter [FORENSIC MODE ACTIVE] ---" -ForegroundColor Cyan

if (!([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltinRole]::Administrator)) {
    Write-Host "!!! ТРЕБУЮТСЯ ПРАВА АДМИНИСТРАТОРА !!!" -ForegroundColor Red; return
}

# --- БАЗА СИГНАТУР (Расширенная) ---
$CheatDB = @("Vape", "Akrien", "Celestial", "Expensive", "Wild", "Nurik", "Doomsday", "Phasma", "Drip", "MicoHit", "MixBox", "AutoClicker", "Reach", "Velocity", "Hitbox", "Meteor", "Impact", "LiquidBounce", "Aristois", "Wurst", "Killaura", "AimAssist", "SelfDestruct", "Destruct", "String", "JNI", "Native", "Mapped")
$ToolsDB = @("xxstrings", "ProcessHacker", "SystemInformer", "Everything", "LnkParse", "Wipe", "Cleaner")

function Add-Entry ($Level, $Module, $Target, $Detail) {
    $Global:Results += [PSCustomObject]@{Level = $Level; Module = $Module; Target = $Target; Detail = $Detail}
}

# --- МОДУЛЬ 1: ИСТОРИЯ ЗАПУСКОВ (BAM/BAM STATE) ---
# Логика из BamParserCLI.ps1
Write-Host "[1/7] Анализ Background Activity Moderator (История запуска)..." -ForegroundColor Gray
$bamPaths = @("HKLM:\SYSTEM\CurrentControlSet\Services\bam\UserSettings\", "HKLM:\SYSTEM\CurrentControlSet\Services\bam\state\UserSettings\")
foreach ($path in $bamPaths) {
    if (Test-Path $path) {
        Get-ChildItem $path | ForEach-Object {
            $vals = Get-ItemProperty $_.PSPath
            foreach ($p in $vals.PSObject.Properties) {
                if ($p.Value -is [byte[]]) {
                    $fileName = $p.Name
                    foreach ($c in $CheatDB) {
                        if ($fileName -match $c) { Add-Entry "CRITICAL" "BAM" $fileName "Запуск чита подтвержден в истории" }
                    }
                    if (!(Test-Path $fileName) -and ($fileName -like "*:*")) {
                        Add-Entry "SUSPICIOUS" "BAM" $fileName "Файл запускался, но сейчас УДАЛЕН (чистка следов?)"
                    }
                }
            }
        }
    }
}

# --- МОДУЛЬ 2: СТРОКИ ПАМЯТИ (DPS/PCA) ---
# Логика из ServiceCheck.ps1
Write-Host "[2/7] Глубокий анализ памяти системных служб..." -ForegroundColor Gray
$tempXX = "$env:TEMP\xxstrings.exe"
if (!(Test-Path $tempXX)) { 
    Invoke-WebRequest -Uri "https://github.com/ZaikoARG/xxstrings/releases/download/1.0.0/xxstrings64.exe" -OutFile $tempXX 
}

$targetPIDs = Get-Process -Name "DPS", "PcaSvc" | Select-Object -ExpandProperty Id
foreach ($pid in $targetPIDs) {
    $strings = (& $tempXX -p $pid | Out-String)
    foreach ($c in $CheatDB) {
        if ($strings -match $c) { Add-Entry "CRITICAL" "Memory" "PID $pid" "Найдена сигнатура '$c' в системной памяти" }
    }
}
Remove-Item $tempXX -Force

# --- МОДУЛЬ 3: СЕТЕВАЯ ФОРЕНЗИКА (DNS) ---
Write-Host "[3/7] Анализ DNS-кэша на запросы к сайтам читов..." -ForegroundColor Gray
$dns = Get-DnsClientCache
$domains = @("vape.gg", "doomsdayclient", "akrien", "expensive.wtf", "liquidbounce", "impactclient")
foreach ($d in $dns) {
    foreach ($dom in $domains) {
        if ($d.Name -match $dom) { Add-Entry "SUSPICIOUS" "DNS" $d.Name "Зафиксировано посещение сайта чита" }
    }
}

# --- МОДУЛЬ 4: ZONE IDENTIFIER (ADS) ---
# Логика из DoomsdayFinder.ps1
Write-Host "[4/7] Проверка метаданных загруженных файлов..." -ForegroundColor Gray
$scanPaths = @("$env:USERPROFILE\Downloads", "$env:USERPROFILE\Desktop")
foreach ($sp in $scanPaths) {
    $files = Get-ChildItem -Path $sp -Include *.exe, *.jar -Recurse -File
    foreach ($f in $files) {
        $zone = Get-Content -Path $f.FullName -Stream "Zone.Identifier" -ErrorAction SilentlyContinue
        if ($zone -match "doomsdayclient" -or $zone -match "vape" -or $zone -match "cheat") {
            Add-Entry "CRITICAL" "ZoneID" $f.FullName "Файл скачан с ресурса с читами"
        }
    }
}

# --- МОДУЛЬ 5: USB & DRIVE HISTORY ---
Write-Host "[5/7] Проверка истории подключенных устройств..." -ForegroundColor Gray
$usbKeys = Get-ChildItem "HKLM:\SYSTEM\CurrentControlSet\Enum\USBSTOR"
foreach ($key in $usbKeys) {
    $friendly = (Get-ItemProperty "$($key.PSPath)\*" -ErrorAction SilentlyContinue).FriendlyName
    if ($friendly) {
        foreach ($c in $CheatDB) {
            if ($friendly -match $c) { Add-Entry "CRITICAL" "USB" $friendly "Подключалась флешка с названием чита" }
        }
    }
}

# --- МОДУЛЬ 6: ПРОВЕРКА ЦИФРОВЫХ ПОДПИСЕЙ ---
Write-Host "[6/7] Проверка подписей подозрительных процессов..." -ForegroundColor Gray
$procs = Get-Process | Where-Object {$_.Path -like "*Temp*" -or $_.Path -like "*Downloads*"}
foreach ($pr in $procs) {
    $sig = Get-AuthenticodeSignature $pr.Path
    if ($sig.Status -ne "Valid") {
        Add-Entry "WARNING" "Signature" $pr.Path "Запущен файл без цифровой подписи в Temp"
    }
}

# --- МОДУЛЬ 7: PREFETCH ---
Write-Host "[7/7] Анализ службы ускорения запуска (Prefetch)..." -ForegroundColor Gray
$pf = Get-ChildItem "C:\Windows\Prefetch" -Filter "*.pf"
foreach ($f in $pf) {
    foreach ($c in $CheatDB) {
        if ($f.Name -match $c) { Add-Entry "CRITICAL" "Prefetch" $f.Name "Обнаружен запуск (даже если файл удален)" }
    }
}

# --- ФИНАЛЬНЫЙ ОТЧЕТ ---
Write-Host "`n=== РЕЗУЛЬТАТЫ ПРОВЕРКИ ===" -ForegroundColor Cyan

if ($Global:Results.Count -eq 0) {
    Write-Host "Система чиста. Подозрительных следов не найдено." -ForegroundColor Green
} else {
    $Global:Results | Sort-Object Level | ForEach-Object {
        $color = "White"
        if ($_.Level -eq "CRITICAL") { $color = "Red" }
        elseif ($_.Level -eq "SUSPICIOUS") { $color = "Yellow" }
        
        Write-Host "[$($_.Level)]" -ForegroundColor $color -NoNewline
        Write-Host " | $($_.Module) | " -NoNewline
        Write-Host "$($_.Target)" -ForegroundColor Cyan
        Write-Host "      └─ $($_.Detail)" -ForegroundColor Gray
    }
}

Write-Host "`nНажмите любую клавишу, чтобы закрыть отчет..."
[void]$Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
