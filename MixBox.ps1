<#
    ===========================================================================
    MixBox CheatHunter - ULTIMATE FORENSIC ENGINE v3.0
    Developer: CeNTeR_FUN (Powered by Bin & Steve)
    Description: Глубочайший форензик-анализ (USB, LNK, BAM, UserAssist, Memory, ADS)
    ===========================================================================
#>

$ErrorActionPreference = "SilentlyContinue"
Clear-Host
$Global:Report = @()

Write-Host "=======================================================" -ForegroundColor Cyan
Write-Host "   MixBox CheatHunter: УЛЬТИМАТИВНЫЙ АНАЛИЗ СИСТЕМЫ    " -ForegroundColor Red
Write-Host "=======================================================" -ForegroundColor Cyan

# Проверка на Бога (Админа)
if (!([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltinRole]::Administrator)) {
    Write-Host "[!] ДОСТУП ЗАПРЕЩЕН. Запустите от имени Администратора." -ForegroundColor Red; return
}

# --- 1. ОГРОМНАЯ БАЗА СИГНАТУР И ПАТТЕРНОВ ---
$Cheats = @("Vape","Akrien","Celestial","Expensive","Wild","Nurik","Doomsday","Phasma","Drip","MicoHit","MixBox","Meteor","Impact","LiquidBounce","Wurst","Aristois","Inertia","BleachHack","Matix","Husk","Flux","KAMI","Sigma","Icarus","Rise","Tenacity","Novoline","Astolfo","Moon","Exhibition","FDP","Bypass","Reach","HitBox","Velocity","Killaura","AimAssist","Clicker","Macro","Swag","Jigsaw","Deadcode","Nodus","CheatEngine","ProcessHacker","SystemInformer","Injector","Loader","JNI","Destruct","SelfDestruct")
$Suspicious = @("Cleaner","Wiper","Hider","Vanish","String","Spoofer","HWID","Temp","Hidden","Ghost")
$Extensions = @("*.exe", "*.jar", "*.dll", "*.bat", "*.cmd", "*.vbs", "*.zip", "*.rar", "*.7z", "*.sys")

function Log-Threat ($Level, $Module, $Target, $Desc) {
    $script:Report += [PSCustomObject]@{ Level = $Level; Module = $Module; Target = $Target; Desc = $Desc }
}

# Функция дешифровки ROT13 (Windows шифрует UserAssist)
function Decode-ROT13([string]$Text) {
    $arr = $Text.ToCharArray()
    for ($i=0; $i -lt $arr.Length; $i++) {
        $c = [int]$arr[$i]
        if (($c -ge 97 -and $c -le 109) -or ($c -ge 65 -and $c -le 77)) { $arr[$i] = [char]($c + 13) }
        elseif (($c -ge 110 -and $c -le 122) -or ($c -ge 78 -and $c -le 90)) { $arr[$i] = [char]($c - 13) }
    }
    return -join $arr
}

# --- МОДУЛЬ 1: ИСТОРИЯ USB ФЛЕШЕК ---
Write-Host "[*] Модуль 1/7: Извлечение истории USB-устройств..." -ForegroundColor Yellow
$usbPath = "HKLM:\SYSTEM\CurrentControlSet\Enum\USBSTOR"
if (Test-Path $usbPath) {
    Get-ChildItem $usbPath | ForEach-Object {
        $deviceName = $_.PSChildName
        Get-ChildItem $_.PSPath | ForEach-Object {
            $friendlyName = (Get-ItemProperty $_.PSPath -Name FriendlyName -ErrorAction SilentlyContinue).FriendlyName
            if ($friendlyName) {
                foreach ($c in $Cheats) {
                    if ($friendlyName -match $c) { Log-Threat "CRITICAL" "USB History" $friendlyName "Найдена флешка с названием чита" }
                }
                foreach ($s in $Suspicious) {
                    if ($friendlyName -match $s) { Log-Threat "SUSPICIOUS" "USB History" $friendlyName "Подозрительное название флешки" }
                }
            }
        }
    }
}

# --- МОДУЛЬ 2: USERASSIST (Расшифровка скрытых запусков) ---
Write-Host "[*] Модуль 2/7: Дешифровка логов UserAssist (ROT13)..." -ForegroundColor Yellow
$uaPaths = @("HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\UserAssist\*\Count")
foreach ($ua in $uaPaths) {
    Get-ItemProperty $ua -ErrorAction SilentlyContinue | Get-Member -MemberType NoteProperty | ForEach-Object {
        $decoded = Decode-ROT13 $_.Name
        foreach ($c in $Cheats) {
            if ($decoded -match $c) { Log-Threat "CRITICAL" "UserAssist" $decoded "Скрытый запуск программы-чита" }
        }
    }
}

# --- МОДУЛЬ 3: RECENT FILES (LNK) ---
Write-Host "[*] Модуль 3/7: Анализ ярлыков (Recent LNK)..." -ForegroundColor Yellow
$recentPath = "$env:APPDATA\Microsoft\Windows\Recent"
$wshShell = New-Object -ComObject WScript.Shell
Get-ChildItem -Path $recentPath -Filter *.lnk | ForEach-Object {
    $lnk = $wshShell.CreateShortcut($_.FullName)
    $target = $lnk.TargetPath
    foreach ($c in $Cheats) {
        if ($target -match $c -or $_.Name -match $c) { Log-Threat "CRITICAL" "Recent LNK" $target "Был запущен файл чита (возможно, удален)" }
    }
}

# --- МОДУЛЬ 4: PREFETCH И BAM ---
Write-Host "[*] Модуль 4/7: Сканирование Prefetch и BAM..." -ForegroundColor Yellow
$pfFiles = Get-ChildItem "C:\Windows\Prefetch" -Filter "*.pf"
foreach ($pf in $pfFiles) {
    foreach ($c in $Cheats) { if ($pf.Name -match $c) { Log-Threat "CRITICAL" "Prefetch" $pf.Name "След запуска" } }
}
$bamKeys = @("HKLM:\SYSTEM\CurrentControlSet\Services\bam\UserSettings\", "HKLM:\SYSTEM\CurrentControlSet\Services\bam\state\UserSettings\")
foreach ($key in $bamKeys) {
    if (Test-Path $key) {
        Get-ChildItem $key | ForEach-Object {
            $props = Get-ItemProperty $_.PSPath
            foreach ($p in $props.PSObject.Properties) {
                if ($p.Value -is [byte[]]) {
                    foreach ($c in $Cheats) { if ($p.Name -match $c) { Log-Threat "CRITICAL" "BAM" $p.Name "Остаточный след в реестре" } }
                }
            }
        }
    }
}

# --- МОДУЛЬ 5: ГЛУБОКОЕ СКАНИРОВАНИЕ ФАЙЛОВ И ADS ---
Write-Host "[*] Модуль 5/7: Эвристическое сканирование файловой системы..." -ForegroundColor Yellow
$scanDirs = @("$env:USERPROFILE\Downloads", "$env:USERPROFILE\Desktop", "$env:APPDATA", "$env:LOCALAPPDATA\Temp", "C:\Windows\Temp")
foreach ($dir in $scanDirs) {
    if (Test-Path $dir) {
        $files = Get-ChildItem -Path $dir -Include $Extensions -Recurse -File -ErrorAction SilentlyContinue
        foreach ($f in $files) {
            # Проверка имени
            foreach ($c in $Cheats) { if ($f.Name -match $c) { Log-Threat "CRITICAL" "File System" $f.FullName "Найден файл чита" } }
            foreach ($s in $Suspicious) { if ($f.Name -match $s) { Log-Threat "SUSPICIOUS" "File System" $f.FullName "Подозрительный файл (Клинер/Инжектор?)" } }
            
            # Проверка ADS (Zone.Identifier)
            $zone = Get-Content -Path $f.FullName -Stream "Zone.Identifier" -ErrorAction SilentlyContinue
            if ($zone) {
                foreach ($c in $Cheats) {
                    if ($zone -match $c) { Log-Threat "CRITICAL" "File ADS" $f.FullName "Файл загружен с сайта: $c" }
                }
            }
        }
    }
}

# --- МОДУЛЬ 6: СЕТЕВОЙ АНАЛИЗ (DNS) ---
Write-Host "[*] Модуль 6/7: Анализ сетевого кэша..." -ForegroundColor Yellow
$dns = Get-DnsClientCache
foreach ($d in $dns) {
    foreach ($c in $Cheats) {
        if ($d.Name -match $c) { Log-Threat "WARNING" "DNS Cache" $d.Name "Сетевой запрос к подозрительному домену" }
    }
}

# --- МОДУЛЬ 7: MEMORY DUMP СКАНИРОВАНИЕ ---
Write-Host "[*] Модуль 7/7: Сканирование памяти системных процессов..." -ForegroundColor Yellow
$xxstringsURL = "https://github.com/ZaikoARG/xxstrings/releases/download/1.0.0/xxstrings64.exe"
$tempXX = "$env:TEMP\sys_scanner.exe"
if (!(Test-Path $tempXX)) { Invoke-WebRequest -Uri $xxstringsURL -OutFile $tempXX }

$procs = Get-Process -Name "DPS", "PcaSvc", "lsass", "explorer", "javaw" -ErrorAction SilentlyContinue
foreach ($p in $procs) {
    $out = (& $tempXX -p $p.Id | Out-String)
    foreach ($c in $Cheats) {
        if ($out -match $c) { Log-Threat "CRITICAL" "Memory Inject" "PID: $($p.Id) ($($p.Name))" "В памяти найдена сигнатура: $c" }
    }
}
Remove-Item $tempXX -Force

# --- ГЕНЕРАЦИЯ ОТЧЕТА ---
Write-Host "`n=======================================================" -ForegroundColor Cyan
Write-Host "                   ВЕРДИКТ СИСТЕМЫ                     " -ForegroundColor Red
Write-Host "=======================================================" -ForegroundColor Cyan

if ($Report.Count -eq 0) {
    Write-Host "`n[+] ИДЕАЛЬНО ЧИСТО. Никаких следов модификаций, лоадеров или флешек." -ForegroundColor Green
} else {
    $Sorted = $Report | Sort-Object @{Expression={ if($_.Level -eq "CRITICAL"){1}elseif($_.Level -eq "SUSPICIOUS"){2}else{3} }}
    
    foreach ($r in $Sorted) {
        $col = if ($r.Level -eq "CRITICAL") { "Red" } elseif ($r.Level -eq "SUSPICIOUS") { "Yellow" } else { "DarkYellow" }
        Write-Host "[$($r.Level)]" -ForegroundColor $col -NoNewline
        Write-Host " [ $($r.Module) ] " -ForegroundColor Magenta -NoNewline
        Write-Host "$($r.Target)" -ForegroundColor White
        Write-Host "      └─ $($r.Desc)" -ForegroundColor Gray
    }
    
    $critCount = ($Report | Where-Object { $_.Level -eq "CRITICAL" }).Count
    Write-Host "`n[!!!] НАЙДЕНО КРИТИЧЕСКИХ СОВПАДЕНИЙ: $critCount" -ForegroundColor Red
}

Write-Host "`n[*] Анализ завершен. Нажмите любую клавишу..." -ForegroundColor Gray
[void]$Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
