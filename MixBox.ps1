<#
    ===========================================================================
    MixBox CheatHunter - ULTIMATE SS-EDITION v4.0
    Created by: CeNTeR_FUN
    Forensic System: Active | UI: Advanced
    ===========================================================================
#>

$ErrorActionPreference = "SilentlyContinue"
$Global:Results = @()
Clear-Host

# Цветовая палитра
$C_Main = "Cyan"
$C_Warn = "Yellow"
$C_Crit = "Red"
$C_Info = "Gray"

# --- ASCII LOGO ---
Write-Host @"
  __  __ _      ____             _____ _                _   _    _             _            
 |  \/  (_)    |  _ \           / ____| |              | | | |  | |           | |           
 | \  / |___  _| |_) | _____  _| |    | |__   ___  __ _| |_| |__| |_   _ _ __ | |_ ___ _ __ 
 | |\/| | \ \/ /  _ < / _ \ \/ / |    | '_ \ / _ \/ _` | __|  __  | | | | '_ \| __/ _ \ '__|
 | |  | | |>  <| |_) | (_) >  <| |____| | | |  __/ (_| | |_| |  | | |_| | | | | ||  __/ |   
 |_|  |_|_/_/\_\____/ \___/_/\_\\_____|_| |_|\___|\__,_|\__|_|  |_|\__,_|_| |_|\__\___|_|   
                                                                                            
                   >> ULTIMATE FORENSIC ENGINE v4.0 | SS-TOOLS RECODE <<
"@ -ForegroundColor $C_Main

Write-Host "`n[!] Инициализация модулей сканирования..." -ForegroundColor $C_Info

# Проверка прав
if (!([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltinRole]::Administrator)) {
    Write-Host " [!] ОШИБКА: Запуск от имени администратора обязателен." -ForegroundColor $C_Crit
    exit
}

# База данных ключевых слов
$CheatDB = @("Vape", "Akrien", "Celestial", "Expensive", "Wild", "Nurik", "Doomsday", "Phasma", "Drip", "MicoHit", "MixBox", "Meteor", "Impact", "LiquidBounce", "Aristois", "Wurst", "Killaura", "AimAssist", "SelfDestruct", "Destruct", "JNI", "Native", "Mapped")

function Add-Entry ($Level, $Module, $Target, $Detail) {
    if ($Level -eq "CRITICAL") { [console]::beep(500, 300) }
    $Global:Results += [PSCustomObject]@{
        'Уровень' = $Level
        'Модуль'  = $Module
        'Объект'  = $Target
        'Детали'  = $Detail
    }
}

# --- МОДУЛЬ 1: BAM (Background Activity Moderator) ---
Write-Host " [`] Сканирование BAM State (Registry Forensics)..." -ForegroundColor $C_Main -NoNewline
$bamKeys = @("HKLM:\SYSTEM\CurrentControlSet\Services\bam\UserSettings\", "HKLM:\SYSTEM\CurrentControlSet\Services\bam\state\UserSettings\")
foreach ($key in $bamKeys) {
    if (Test-Path $key) {
        Get-ChildItem $key | ForEach-Object {
            $vals = Get-ItemProperty $_.PSPath
            foreach ($p in $vals.PSObject.Properties) {
                if ($p.Value -is [byte[]]) {
                    $fn = $p.Name
                    foreach ($c in $CheatDB) { if ($fn -match $c) { Add-Entry "CRITICAL" "BAM" $fn "Найден в истории запусков" } }
                    if (!(Test-Path $fn) -and ($fn -like "*:*")) { Add-Entry "SUSPICIOUS" "BAM" $fn "Файл запускался, но был УДАЛЕН" }
                }
            }
        }
    }
}
Write-Host " [OK]" -ForegroundColor Green

# --- МОДУЛЬ 2: MEMORY STRINGS (DPS/PCA) ---
Write-Host " [`] Анализ строк в системной памяти (DPS/PCA)..." -ForegroundColor $C_Main -NoNewline
$tempXX = "$env:TEMP\xxstrings.exe"
if (!(Test-Path $tempXX)) { (New-Object System.Net.WebClient).DownloadFile("https://github.com/ZaikoARG/xxstrings/releases/download/1.0.0/xxstrings64.exe", $tempXX) }
$pids = Get-Process -Name "DPS", "PcaSvc" | Select-Object -ExpandProperty Id
foreach ($pid in $pids) {
    $out = (& $tempXX -p $pid | Out-String)
    foreach ($c in $CheatDB) { if ($out -match $c) { Add-Entry "CRITICAL" "Memory" "PID:$pid" "Сигнатура '$c' обнаружена в ОЗУ" } }
}
Write-Host " [OK]" -ForegroundColor Green

# --- МОДУЛЬ 3: DNS & NETWORK ---
Write-Host " [`] Проверка DNS Cache (Network Trace)..." -ForegroundColor $C_Main -NoNewline
Get-DnsClientCache | ForEach-Object {
    $name = $_.Name
    foreach ($c in $CheatDB) { if ($name -match $c) { Add-Entry "SUSPICIOUS" "DNS" $name "Обращение к серверу чита" } }
}
Write-Host " [OK]" -ForegroundColor Green

# --- МОДУЛЬ 4: FILE SYSTEM (ZONE.ID / PREFETCH) ---
Write-Host " [`] Эвристика файлов (Prefetch & ADS)..." -ForegroundColor $C_Main -NoNewline
# Prefetch
Get-ChildItem "C:\Windows\Prefetch" -Filter "*.pf" | ForEach-Object {
    foreach ($c in $CheatDB) { if ($_.Name -match $c) { Add-Entry "CRITICAL" "Prefetch" $_.Name "След запуска удаленного чита" } }
}
# ADS Zone Identifier
Get-ChildItem -Path "$env:USERPROFILE\Downloads", "$env:USERPROFILE\Desktop" -Include *.exe, *.jar -File | ForEach-Object {
    $zone = Get-Content -Path $_.FullName -Stream "Zone.Identifier" -ErrorAction SilentlyContinue
    if ($zone -match "doomsday" -or $zone -match "vape" -or $zone -match "cheat") {
        Add-Entry "CRITICAL" "ZoneID" $_.FullName "Файл скачан с сайта читов"
    }
}
Write-Host " [OK]" -ForegroundColor Green

# --- МОДУЛЬ 5: USB HISTORY ---
Write-Host " [`] История внешних накопителей (USBSTOR)..." -ForegroundColor $C_Main -NoNewline
$usbPath = "HKLM:\SYSTEM\CurrentControlSet\Enum\USBSTOR"
if (Test-Path $usbPath) {
    Get-ChildItem $usbPath | ForEach-Object {
        $friendly = (Get-ItemProperty "$($_.PSPath)\*" -ErrorAction SilentlyContinue).FriendlyName
        foreach ($c in $CheatDB) { if ($friendly -match $c) { Add-Entry "CRITICAL" "USB" $friendly "Найдена флешка с софтом" } }
    }
}
Write-Host " [OK]" -ForegroundColor Green

# --- ФИНАЛЬНЫЙ ВЕРДИКТ ---
Write-Host "`n" + ("=" * 80) -ForegroundColor $C_Main
Write-Host "                            ОТЧЕТ О ПРОВЕРКЕ" -ForegroundColor White
Write-Host ("=" * 80) -ForegroundColor $C_Main

if ($Global:Results.Count -eq 0) {
    Write-Host "`n [SUCCESS] Система полностью чиста. Следов вмешательства не обнаружено." -ForegroundColor Green
} else {
    $Global:Results | Sort-Object Уровень | Format-Table -AutoSize | Out-String | ForEach-Object {
        foreach ($line in ($_ -split "`r`n")) {
            if ($line -match "CRITICAL") { Write-Host $line -ForegroundColor $C_Crit }
            elseif ($line -match "SUSPICIOUS") { Write-Host $line -ForegroundColor $C_Warn }
            else { Write-Host $line -ForegroundColor $C_Info }
        }
    }
    
    $c_count = ($Global:Results | Where-Object { $_.Уровень -eq "CRITICAL" }).Count
    Write-Host "`n [!] ИТОГО: Найдено критических угроз: $c_count" -ForegroundColor $C_Crit
}

Write-Host "`n" + ("=" * 80) -ForegroundColor $C_Main
Write-Host " Нажмите любую клавишу для выхода..." -ForegroundColor $C_Info
[void]$Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
