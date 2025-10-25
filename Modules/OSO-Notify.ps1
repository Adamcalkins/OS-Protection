# ==============================================================================
# File: OSO-Notify.ps1
# Funkcja: Start-Notify
# ==============================================================================

function Start-Notify {
    
    # ----------------------------------------------------
    # Konfiguracja Event Log
    # ----------------------------------------------------
    $EventSource = "OSO-SecurityMonitor"
    $LogName = "Application"
    
    # Definicja Event ID dla klasyfikacji
    $ID_ValidEntry = 4100    # Nowy wpis, podpis OK (Information)
    $ID_SuspiciousEntry = 4200 # Nowy wpis, brak/nieprawidlowy podpis (Warning)
    
    # ----------------------------------------------------
    # Rejestracja Event Source
    # ----------------------------------------------------
    # Sprawdzamy, czy zrodlo juz istnieje, i rejestrujemy je, jesli nie.
    if (-not ([System.Diagnostics.EventLog]::SourceExists($EventSource))) {
        Write-Host "Inicjalizacja Event Source '$EventSource'. Wymaga uprawnien administratora." -ForegroundColor Yellow
        try {
            New-EventLog -LogName $LogName -Source $EventSource -ErrorAction Stop
        }
        catch {
             Write-Host "Blad rejestracji zrodla zdarzen! ($_.Exception.Message). Kontynuowanie, ale Event Log moze nie dzialac." -ForegroundColor Red
        }
    }


    Write-Host "============================================" -ForegroundColor Cyan
    Write-Host "     LOGOWANIE NOWYCH WPISOW DO EVENT VIEWER " -ForegroundColor Cyan
    Write-Host "============================================" -ForegroundColor Cyan

    # 1. Wywolanie analizy
    Write-Host "[1/3] Wykonywanie analizy autostartu..." -ForegroundColor Yellow
    
    if (-not (Get-Command Start-Analyze -ErrorAction SilentlyContinue)) {
        Write-Error "Blad krytyczny: Funkcja Start-Analyze nie jest dostepna. Sprawdz OSO-Analyze.ps1"
        return @()
    }
    
    try {
        $AnalysisResults = Start-Analyze -ErrorAction Stop
    }
    catch {
        Write-Error "Blad podczas wykonywania Start-Analyze: $($_.Exception.Message)"
        return @()
    }
    
    # Sprawdzenie, czy sa jakiekolwiek wyniki
    if (-not $AnalysisResults -or ($AnalysisResults | Measure-Object).Count -eq 0) {
        Write-Host "`nBrak nowych wpisow do analizy. Koniec powiadamiania." -ForegroundColor Green
        return @()
    }

    # 2. Logowanie do Event Viewer
    $SuspiciousEntries = @() 
    $TotalLogged = 0
    
    Write-Host "`n[2/3] Klasyfikacja i zapis zdarzen do Podgladu Zdarzen..." -ForegroundColor Yellow

    foreach ($entry in $AnalysisResults) {
        $CurrentID = 0
        $CurrentType = ""
        $LogVerb = ""
        $isSuspicious = $true

        # KLASYFIKACJA NA PODSTAWIE STATUSU PODPISU
        switch -Wildcard ($entry.StatusPodpisu) {
            "Wazny" { 
                $CurrentID = $ID_ValidEntry
                $CurrentType = "Information"
                $LogVerb = "INFO"
            }
            "Brak Podpisu" { 
                $CurrentID = $ID_SuspiciousEntry
                $CurrentType = "Warning" 
                $LogVerb = "OSTRZEŻENIE"
                $isSuspicious = $true
            }
            "*Nieprawidlowy*" { 
                $CurrentID = $ID_SuspiciousEntry
                $CurrentType = "Warning" 
                $LogVerb = "OSTRZEŻENIE"
                $isSuspicious = $true
            }
            default { 
                $CurrentID = $ID_SuspiciousEntry
                $CurrentType = "Warning"
                $LogVerb = "UWAGA"
                $isSuspicious = $true
            }
        }
        
        # Dodajemy do listy podejrzanych, jesli jest to ostrzezenie
        if ($isSuspicious) { $SuspiciousEntries += $entry }

        # Tworzenie czytelnej wiadomosci logu
        $Message = @"
[$LogVerb - ID:$CurrentID] Nowy wpis autostartu.
    Lokalizacja: $($entry.Lokalizacja)
    Nazwa Wpisu: $($entry.Nazwa)
    Sciezka: $($entry.SciezkaProgramu)
    Status Podpisu: $($entry.StatusPodpisu)
    Wydawca: $($entry.Wydawca)
"@
        
        try {
            # Zapis zdarzenia do Event Logu
            Write-EventLog -LogName $LogName `
                           -Source $EventSource `
                           -EntryType $CurrentType `
                           -EventId $CurrentID `
                           -Message $Message `
                           -ErrorAction Stop
            $TotalLogged++
            Write-Host "   [EventLog] Log [$LogVerb] ID:$CurrentID dla: $($entry.Nazwa)" -ForegroundColor Gray
        }
        catch {
            Write-Host "   [EventLog] Blad zapisu: $($_.Exception.Message)" -ForegroundColor Red
        }
    }

    # 3. Podsumowanie

    Write-Host "`n[3/3] Podsumowanie..." -ForegroundColor Yellow
    Write-Host "   Zapisano $TotalLogged zdarzen w Event Viewer." -ForegroundColor Green
   
    # Zwraca liste PODEJRZANYCH wpisow
    return $SuspiciousEntries
}