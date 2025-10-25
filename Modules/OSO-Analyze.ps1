# ==============================================================================
# File: OSO-Analyze.ps1
# Funkcja: Start-Analyze (Analiza podpisow cyfrowych nowych wpisow)
# ==============================================================================

function Start-Analyze {
    
    Write-Host "============================================" -ForegroundColor Cyan
    Write-Host "     ANALIZA I WALIDACJA AUTOSTARTU       " -ForegroundColor Cyan
    Write-Host "============================================" -ForegroundColor Cyan

    $WhitelistPath = Join-Path -Path $PSScriptRoot -ChildPath "Whitelist_Base.csv"
    
    # Lista wlasciwosci, ktorych uzywamy do porownania i analizy
    $PropertiesToCompare = "Lokalizacja", "Sciezka", "Nazwa", "Wartosc", "Typ"
    
    # 1. Ladowanie Bialej Listy
    if (-not (Test-Path $WhitelistPath)) {
        Write-Error "Brak pliku Whitelist_Base.csv. Najpierw uruchom opcje 'Utworz Biala Liste (Whitelist)'."
        return
    }

    Write-Host "[1/3] Ladowanie bialej listy i skanowanie..." -ForegroundColor Yellow
    
    # Wczytanie Whitelist (CSV)
    $Whitelist = Import-Csv -Path $WhitelistPath -Delimiter "," -Encoding UTF8 -ErrorAction Stop | 
                 Select-Object -Property $PropertiesToCompare
    
    # Skanowanie Aktualne (wywolanie OSO-Enumerate)
    $CurrentAutostart = Start-Enumerate -Silent -ErrorAction Stop | 
                        Select-Object -Property $PropertiesToCompare
    $CurrentAutostartCount = ($CurrentAutostart | Measure-Object).Count
    
    if ($CurrentAutostartCount -eq 0) {
        Write-Host "Nie znaleziono zadnych aktualnych wpisow autostartu." -ForegroundColor Red
        return
    }
    
    # 2. Porownanie i Identyfikacja Nowych Wpisow
    Write-Host "`n[2/3] Identyfikacja nowych/nieznanych wpisow..." -ForegroundColor Yellow

    # Porownanie na ujednoliconych wlasciwosciach
    $NewEntriesComparison = Compare-Object -ReferenceObject $Whitelist `
                                 -DifferenceObject $CurrentAutostart `
                                 -Property Lokalizacja, Nazwa, Wartosc `
                                 -PassThru
    
    # Filtrowanie tylko nowych wpisow ('=>' oznacza element tylko w DifferenceObject)
    $NewEntries = @($NewEntriesComparison | Where-Object { $_.SideIndicator -eq '=>' })
    
    $NewEntriesCount = $NewEntries.Count
    
    Write-Host "   Znaleziono $NewEntriesCount nowych wpisow wymagajacych analizy." -ForegroundColor Green
    
    if ($NewEntriesCount -eq 0) {
        Write-Host "`nBrak nowych wpisow autostartu. System jest zgodny ze wzorcem." -ForegroundColor Cyan
        return
    }

    # 3. Analiza Podpisu Cyfrowego
    Write-Host "`n[3/3] Analiza podpisow cyfrowych..." -ForegroundColor Yellow
    $AnalysisResults = @()

    foreach ($entry in $NewEntries) {
        # Proba wyodrebnienia czystej sciezki do pliku wykonywalnego
if ($entry.Lokalizacja -like "Folder Startup") {
            # Dla plików w folderze Startup używamy wartości z entry.Wartosc, która zawiera pełną ścieżkę
            $path = $entry.Wartosc

        } else {
            # Dla rejestru - wyodrebnij sciezke z wartosci
            if ($entry.Wartosc -match '(?<path>".*?"|\S+)') {
                $path = $matches.path -replace '"',''
            } else {
                $path = $entry.Wartosc
            }
        }
        
        $signature = $null
        try {
            # Tylko sprawdzamy, jesli sciezka wyglada jak plik wykonywalny i istnieje
            if ($path -match "\.(exe|dll|com|sys)$" -and (Test-Path $path -ErrorAction SilentlyContinue)) {
                $signature = Get-AuthenticodeSignature -FilePath $path -ErrorAction SilentlyContinue
            }
        }
        catch {
            # Ignorujemy bledy Get-AuthenticodeSignature (np. brak dostepu)
        }
        
        $status = "Brak Podpisu / Nieznany typ"
        $publisher = "N/A"

        if ($signature) {
            if ($signature.Status -eq 'Valid') {
                $status = "Wazny"
                $publisher = if ($signature.SignerCertificate.Subject) { 
                    $signature.SignerCertificate.Subject -replace 'CN=', '' 
                } else { 
                    "N/A" 
                }
            }
            elseif ($signature.Status -eq 'NotSigned') {
                $status = "Brak Podpisu"
            }
            else {
                $status = "Nieprawidlowy ($($signature.Status))"
                $publisher = if ($signature.SignerCertificate.Subject) { 
                    $signature.SignerCertificate.Subject -replace 'CN=', '' 
                } else { 
                    "N/A" 
                }
            }
        }

        $result = [PSCustomObject]@{
            Lokalizacja     = $entry.Lokalizacja
            Sciezka         = $entry.Sciezka
            Nazwa           = $entry.Nazwa
            SciezkaProgramu = $path
            StatusPodpisu   = $status
            Wydawca         = $publisher
        }
        
        $AnalysisResults += $result
        Write-Host "   [NOWY] $($entry.Nazwa) | Status: $status" -ForegroundColor Gray
    }

    Write-Host "`n============================================" -ForegroundColor Cyan
    Write-Host "     WYNIKI ANALIZY NOWYCH WPISOW      " -ForegroundColor Cyan
    Write-Host "============================================" -ForegroundColor Cyan

    # Wyswietlenie wynikow bez niszczenia obiektow
    $AnalysisResults | Format-Table -Property Lokalizacja, Nazwa, StatusPodpisu, Wydawca -AutoSize | Out-Host
    
    # ZWROCENIE WYNIKOW ANALIZY DLA KOLEJNYCH MODULOW
    return $AnalysisResults
}