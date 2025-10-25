# ==============================================================================
# Plik: OSO-Enumerate.ps1
# Funkcja: Start-Enumerate (Czysty Silnik Skanujacy dla innych modulow)
# Funkcja zbiera dane autostartu i ZWRACA je jako tablice obiektow.
# ==============================================================================

function Start-Enumerate {

    # Parametr kontroluje, czy wyswietlac szczegoly skanowania w konsoli.
    param(
        [Parameter(Mandatory=$false)]
        [switch]$Silent = $false
    )

    if (-not $Silent) {
        Write-Host "============================================" -ForegroundColor Cyan
        Write-Host "  SKRYPT ENUMERACJI AUTOSTARTU WINDOWS" -ForegroundColor Cyan
        Write-Host "============================================" -ForegroundColor Cyan
        Write-Host ""
    }

    # Sprawdz uprawnienia administratora
    $isAdmin = ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
    if (-not $isAdmin) {
        Write-Warning "Dla pelnego dostepu zalecane sa uprawnienia administratora."
    }

    # Tablica do przechowywania wszystkich wynikow
    $allAutostart = @()
    
    # --- [1/3] REJESTR WINDOWS ---
    if (-not $Silent) { Write-Host "[1/3] Skanowanie rejestru Windows..." -ForegroundColor Yellow }

    # Sciezki rejestru do sprawdzenia
    $registryPaths = @(
        "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Run",
        "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\RunOnce",
        "HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Run",
        "HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\RunOnce",
        "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Run",
        "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\RunOnce",
        "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\Explorer\Run",
        "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\Explorer\Run"
    )

    $registryCount = 0

    foreach ($path in $registryPaths) {
        if (Test-Path $path) {
            if (-not $Silent) { Write-Host " Sprawdzanie: $path" -ForegroundColor Gray }
            
            try {
                $items = Get-ItemProperty -Path $path -ErrorAction SilentlyContinue
                
                if ($items) {
                    $properties = $items.PSObject.Properties | Where-Object { $_.Name -notlike "PS*" }
                    
                    foreach ($prop in $properties) {
                        $objekt = New-Object PSObject
                        $objekt | Add-Member -MemberType NoteProperty -Name "Lokalizacja" -Value "Rejestr"
                        $objekt | Add-Member -MemberType NoteProperty -Name "Sciezka" -Value $path
                        $objekt | Add-Member -MemberType NoteProperty -Name "Nazwa" -Value $prop.Name
                        $objekt | Add-Member -MemberType NoteProperty -Name "Wartosc" -Value $prop.Value
                        $objekt | Add-Member -MemberType NoteProperty -Name "Typ" -Value "Registry Key"
                        
                        $allAutostart += $objekt
                        $registryCount++
                    }
                }
            }
            catch {
                if (-not $Silent) { Write-Host " Blad dostepu do: $path" -ForegroundColor Red }
            }
        }
    }
    
    if (-not $Silent) {
        Write-Host " Znaleziono $registryCount wpisow w rejestrze" -ForegroundColor Green
        Write-Host ""
    }

    # --- [2/3] FOLDER STARTUP ---
    if (-not $Silent) { Write-Host "[2/3] Skanowanie folderow Startup..." -ForegroundColor Yellow }

    # Sciezki do folderow Startup
    $startupFolders = @(
        "$env:APPDATA\Microsoft\Windows\Start Menu\Programs\Startup",
        "$env:ProgramData\Microsoft\Windows\Start Menu\Programs\Startup"
    )

    $startupCount = 0

    foreach ($folder in $startupFolders) {
        if (Test-Path $folder) {
            if (-not $Silent) { Write-Host " Sprawdzanie: $folder" -ForegroundColor Gray }
            
            $items = Get-ChildItem -Path $folder -File -ErrorAction SilentlyContinue
            
            foreach ($item in $items) {
                $target = $item.FullName
                
                if ($item.Extension -eq ".lnk") {
                    try {
                        $shell = New-Object -ComObject WScript.Shell
                        $shortcut = $shell.CreateShortcut($item.FullName)
                        $target = $shortcut.TargetPath
                        [System.Runtime.InteropServices.Marshal]::ReleaseComObject($shell) | Out-Null
                    }
                    catch {
                        $target = $item.FullName
                    }
                }
                
                $objekt = New-Object PSObject
                $objekt | Add-Member -MemberType NoteProperty -Name "Lokalizacja" -Value "Folder Startup"
                $objekt | Add-Member -MemberType NoteProperty -Name "Sciezka" -Value $folder
                $objekt | Add-Member -MemberType NoteProperty -Name "Nazwa" -Value $item.Name
                $objekt | Add-Member -MemberType NoteProperty -Name "Wartosc" -Value $target
                $objekt | Add-Member -MemberType NoteProperty -Name "Typ" -Value $item.Extension
                
                $allAutostart += $objekt
                $startupCount++
            }
        }
    }

    if (-not $Silent) {
        Write-Host " Znaleziono $startupCount elementow w folderach Startup" -ForegroundColor Green
        Write-Host ""
    }

    # --- [3/3] HARMONOGRAM ZADAN ---
    if (-not $Silent) { Write-Host "[3/3] Skanowanie Harmonogramu Zadan..." -ForegroundColor Yellow }
    $taskCount = 0
    
    try {
        $scheduledTasks = Get-ScheduledTask -ErrorAction SilentlyContinue
        
        if ($scheduledTasks) {
            foreach ($task in $scheduledTasks) {
                if ($task.State -eq "Disabled" -or $task.Settings.Enabled -eq $false) {
                    continue
                }
                
                $hasAutoTrigger = $false
                $triggerType = "Inne"
                
                foreach ($trigger in $task.Triggers) {
                    $className = $trigger.CimClass.CimClassName
                    
                    if ($className -eq "MSFT_TaskLogonTrigger") {
                        $hasAutoTrigger = $true; $triggerType = "Przy logowaniu" ; break
                    }
                    elseif ($className -eq "MSFT_TaskBootTrigger") {
                        $hasAutoTrigger = $true; $triggerType = "Przy starcie systemu" ; break
                    }
                    elseif ($className -eq "MSFT_TaskRegistrationTrigger") {
                        $hasAutoTrigger = $true; $triggerType = "Przy rejestracji" ; break
                    }
                }
                
                if ($hasAutoTrigger) {
                    $action = $task.Actions | Select-Object -First 1
                    $program = "N/A"
                    $arguments = ""
                    
                    if ($action) {
                        if ($action.Execute) { $program = $action.Execute }
                        if ($action.Arguments) { $arguments = $action.Arguments }
                    }
                    
                    $objekt = New-Object PSObject
                    $objekt | Add-Member -MemberType NoteProperty -Name "Lokalizacja" -Value "Harmonogram Zadan"
                    $objekt | Add-Member -MemberType NoteProperty -Name "Sciezka" -Value $task.TaskPath
                    $objekt | Add-Member -MemberType NoteProperty -Name "Nazwa" -Value $task.TaskName
                    $objekt | Add-Member -MemberType NoteProperty -Name "Wartosc" -Value "$program $arguments"
                    $objekt | Add-Member -MemberType NoteProperty -Name "Typ" -Value $triggerType
                    
                    $allAutostart += $objekt
                    $taskCount++
                }
            }
            
            if (-not $Silent) { Write-Host " Znaleziono $taskCount zadan uruchamianych automatycznie" -ForegroundColor Green }
        }
    }
    catch {
        if (-not $Silent) { Write-Host " Blad podczas skanowania Harmonogramu Zadan" -ForegroundColor Red }
    }

    if (-not $Silent) { Write-Host "" }

    # ZWROC ZGROMADZONE DANE (TEN WIERSZ JEST KRYTYCZNY DLA MODULOWOSCI)
    return $allAutostart 
}