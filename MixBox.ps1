<#
    MixBox CheatHunter - Professional Integrity Tool
    Version: 2.5
    Система глубокого анализа следов стороннего ПО.
#>

$ErrorActionPreference = "SilentlyContinue"
$Report = @()
Clear-Host

Write-Host "--- MixBox CheatHunter: Запуск масштабного анализа системы ---" -ForegroundColor Cyan

# Проверка привилегий
if (!([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltinRole]::Administrator)) {
    Write-Host "[!] КРИТИЧЕСКАЯ ОШИБКА: Требуются права Администратора." -ForegroundColor Red
    return
}

# --- БАЗА ДАННЫХ ---
$CheatNames = @("Vape", "Akrien", "Celestial", "Expensive", "Wild", "Nurik", "Doomsday", "Phasma", "Drip", "MicoHit", "MixBox", "AutoClicker", "Reach", "Velocity", "HitBox", "Meteor", "Impact", "LiquidBounce")
$ToolsList = @("xxstrings", "ProcessHacker", "SystemInformer", "Everything", "FileZilla", "AnyDesk")
$xxstringsURL = "https://github.com/ZaikoARG/xxstrings/releases/download/1.0.0/xxstrings64.exe"
$tempPath = "$env:TEMP\sb_engine.exe"

function Add-Log ($Status, $Source, $Item, $Info) {
    $script:Report += [PSCustomObject]@{
        Status   = $Status
        Source   = $Source
        Item     = $Item
        Info     = $Info
    }
}

# --- 1. АНАЛИЗ РЕЕСТРА (BAM/Execution History) ---
Write-Host "[1/6] Поиск следов в Background Activity Moderator..." -ForegroundColor Gray
$bamKeys = @("HKLM:\SYSTEM\CurrentControlSet\Services\bam\UserSettings\", "HKLM:\SYSTEM\CurrentControlSet\Services\bam\state\UserSettings\")
foreach ($key in $bamKeys) {
    if (Test-Path $key) {
        Get-ChildItem $key | ForEach-Object {
            $props = Get-ItemProperty $_.PSPath
            foreach ($p in $props.PSObject.Properties) {
                if ($p.Value -is [byte[]]) {
                    $name = $p.Name
                    foreach ($c in $CheatNames) {
                        if ($name -like "*$c*") { Add-Log "CRITICAL" "Registry (BAM)" $name "Зафиксирован запуск чита" }
                    }
                }
            }
        }
    }
}

# --- 2. АНАЛИЗ ПАМЯТИ (Service Strings) ---
Write-Host "[2/6] Анализ строк в системной памяти (DPS/PCA)..." -ForegroundColor Gray
if (!(Test-Path $tempPath)) { Invoke-WebRequest -Uri $xxstringsURL -OutFile $tempPath }
$targetProcesses = Get-Process -Name "DPS", "PcaSvc", "DiagTrack" -ErrorAction SilentlyContinue
foreach ($proc in $targetProcesses) {
    $out = (& $tempPath -p $proc.Id | Out-String)
    foreach ($c in $CheatNames) {
        if ($out -match $c) { Add-Log "CRITICAL" "Memory (Service)" "$($proc.Name) (PID: $($proc.Id))" "В памяти найдена строка: $c" }
    }
}
Remove-Item $tempPath -Force

# --- 3. АНАЛИЗ ФАЙЛОВ И ADS (Zone.Identifier) ---
Write-Host "[3/6] Проверка метаданных файлов и истории загрузок..." -ForegroundColor Gray
$paths = @("$env:USERPROFILE\Downloads", "$env:USERPROFILE\Desktop", "$env:APPDATA\Roaming")
foreach ($p in $paths) {
    $files = Get-ChildItem -Path $p -Include *.exe, *.jar, *.zip, *.rar -Recurse -File
    foreach ($f in $files) {
        $zone = Get-Content -Path $f.FullName -Stream "Zone.Identifier"
        if ($zone -match "doomsdayclient" -or $zone -match "vape.gg" -or $zone -match "cheat") {
            Add-Log "CRITICAL" "File ADS" $f.FullName "Источник файла подтвержден как сайт с читами"
        }
        foreach ($c in $CheatNames) {
            if ($f.Name -match $c) { Add-Log "SUSPICIOUS" "FileSystem" $f.FullName "Подозрительное имя файла" }
        }
    }
}

# --- 4. АНАЛИЗ DNS КЭША ---
Write-Host "[4/6] Проверка истории посещенных доменов..." -ForegroundColor Gray
$dnsCache = Get-DnsClientCache
$cheatDomains = @("vape.gg", "doomsdayclient", "akrien", "expensive.wtf", "liquidbounce", "impactclient")
foreach ($domain in $cheatDomains) {
    if ($dnsCache.Name -match $domain) { Add-Log "WARNING" "DNS Cache" $domain "Зафиксировано обращение к сайту чита" }
}

# --- 5. АНАЛИЗ PREFETCH ---
Write-Host "[5/6] Анализ службы Prefetch..." -ForegroundColor Gray
$prefetchFiles = Get-ChildItem -Path "C:\Windows\Prefetch" -Filter "*.pf"
foreach ($pf in $prefetchFiles) {
    foreach ($c in $CheatNames) {
        if ($pf.Name -match $c) { Add-Log "CRITICAL" "Prefetch" $pf.Name "Обнаружен запуск программы с названием чита" }
    }
}

# --- 6. ИТОГОВЫЙ ВЕРДИКТ ---
Write-Host "`n--- АНАЛИЗ ЗАВЕРШЕН. ВЕРДИКТ СИСТЕМЫ ---`n" -ForegroundColor Cyan

if ($Report.Count -eq 0) {
    Write-Host "РЕЗУЛЬТАТ: ЧИСТО. Подозрительных активностей не обнаружено." -ForegroundColor Green
} else {
    $Sorted = $Report | Sort-Object @{Expression={ if($_.Status -eq "CRITICAL"){1}elseif($_.Status -eq "SUSPICIOUS"){2}else{3} }}
    
    foreach ($r in $Sorted) {
        $color = "White"
        if ($r.Status -eq "CRITICAL") { $color = "Red" }
        elseif ($r.Status -eq "SUSPICIOUS") { $color = "Yellow" }
        
        Write-Host "[$($r.Status)]" -ForegroundColor $color -NoNewline
        Write-Host " | $($r.Source) | $($r.Item)" -ForegroundColor White
        Write-Host "      └─ Инфо: $($r.Info)" -ForegroundColor Gray
    }
    
    $crit = ($Report | Where-Object { $_.Status -eq "CRITICAL" }).Count
    Write-Host "`nОбнаружено критических улик: $crit" -ForegroundColor Red
}

Write-Host "`nНажмите любую клавишу для выхода..."
[void]$Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
