# ==============================================================================
# Plik: OSO-Whitelist.ps1
# Funkcja dla glownego menu: Start-Whitelist
# Generuje plik CSV, ktory bedzie uzywany jako "biala lista" wzorcowych wpisow.
# ==============================================================================

function Start-Whitelist {

    Write-Host "============================================" -ForegroundColor Cyan
    Write-Host "  NARZEDZIE TWORZENIA BIALEJ LISTY (WHITELIST) " -ForegroundColor Cyan
    Write-Host "============================================" -ForegroundColor Cyan

    # Sprawdzamy, czy funkcja Start-Enumerate jest zaladowana (jest w innym module)
    if (-not (Get-Command -Name Start-Enumerate -ErrorAction SilentlyContinue)) {
        Write-Error "Blad krytyczny: Funkcja Start-Enumerate nie jest zaladowana. Upewnij sie, ze plik OSO-Enumerate.ps1 jest w katalogu Modules i zawiera funkcje Start-Enumerate, ktora zwraca dane."
        return
    }

    $WhitelistPath = Join-Path -Path $PSScriptRoot -ChildPath "Whitelist_Base.csv"
    
    Write-Host "[1/2] Wykonywanie pelnej enumeracji autostartu (Stan Biezacy)..." -ForegroundColor Yellow
    
    # Wywolanie funkcji z OSO-Enumerate.ps1. 
    # Zakladamy, ze funkcja Start-Enumerate zostala zmodyfikowana, aby ZWRACAC dane.
    try {
        $SnapshotData = Start-Enumerate
    }
    catch {
        Write-Error "Blad podczas wykonywania enumeracji: $($_.Exception.Message)"
        return
    }

    
    if ($SnapshotData.Count -gt 0) {
        
        Write-Host "`n[2/2] Zapisywanie $($SnapshotData.Count) wpisow do pliku Whitelist_Base.csv..." -ForegroundColor Yellow
        
        # Zapisujemy kluczowe kolumny do bazy, pomijajac PSObject i inne wlasciwosci
        $SnapshotData | Select-Object Lokalizacja, Sciezka, Nazwa, Wartosc, Typ | Export-Csv -Path $WhitelistPath -NoTypeInformation -Encoding UTF8
        
        Write-Host ""
        Write-Host "Sukces! Wzorcowa biala lista zapisana." -ForegroundColor Green
        Write-Host "Plik: $WhitelistPath" -ForegroundColor White
        Write-Host ""
        Write-Host "--- WAZNE: Plik Whitelist_Base.csv jest Twoja baza. Sprawdz jego zawartosc i upewnij sie, ze system jest czysty przed jego uzyciem do porownan! ---" -ForegroundColor Red
        
        $open = Read-Host "`nCzy chcesz otworzyc plik CSV z biala lista? (T/N)"
        if ($open -eq "T" -or $open -eq "t") {
            Start-Process $WhitelistPath
        }

    } else {
        Write-Host "Nie znaleziono zadnych wpisow autostartu. Nie utworzono bazy." -ForegroundColor Red
    }
}