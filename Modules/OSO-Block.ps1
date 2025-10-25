# ==============================================================================
# File: OSO-Block.ps1
# Funkcja: Start-Block - Format zapisu kwarantanny: CSV
# ==============================================================================

# Definicje ścieżek
$ScriptBaseDir = Split-Path -Path $MyInvocation.MyCommand.Path -Parent
# Nowa nazwa pliku kwarantanny
$QuarantineFile = Join-Path -Path $ScriptBaseDir -ChildPath "quarantine.csv" 
$QuarantineDir = Join-Path -Path $ScriptBaseDir -ChildPath "Quarantine_Files"


# ==============================================================================
# Funkcje pomocnicze dla kwarantanny (CSV)
# ==============================================================================
function Get-QuarantineData {
    if (Test-Path $QuarantineFile) {
        try {
            # Odczyt z CSV i konwersja na obiekty
            return (Import-Csv -Path $QuarantineFile -ErrorAction Stop)
        } catch {
            Write-Error "Blad odczytu pliku kwarantanny CSV. Zwracam pusta liste."
            return @()
        }
    }
    return @()
}

function Save-QuarantineData ($data) {
    if (-not $data) { $data = @() } 
    # Eksport do CSV
    $data | Export-Csv -Path $QuarantineFile -NoTypeInformation -Force
}


# ==============================================================================
# FUNKCJA BLOKOWANIA
# ==============================================================================
function Start-Block {
    
    Write-Host "============================================" -ForegroundColor Cyan
    Write-Host "     AUTOMATYCZNE BLOKOWANIE PODEJRZANYCH    " -ForegroundColor Cyan
    Write-Host "============================================" -ForegroundColor Cyan

    Write-Host "[1/3] Pobieranie listy podejrzanych wpisow (wywola analyze i notify)..." -ForegroundColor Yellow
    
    if (-not (Get-Command Start-Notify -ErrorAction SilentlyContinue)) {
        Write-Error "Blad: Funkcja Start-Notify (Modul OSO-Notify.ps1) nie jest dostepna."
        return @()
    }

    $SuspiciousEntries = Start-Notify 
    
    if (-not $SuspiciousEntries -or ($SuspiciousEntries | Measure-Object).Count -eq 0) {
        Write-Host "`nBrak nowych PODEJRZANYCH wpisow do zablokowania. Koniec." -ForegroundColor Green
        return
    }

    [array]$QuarantineData = Get-QuarantineData 
    $BlockedCount = 0

    Write-Host "`n[2/3] Rozpoczynanie blokowania $($SuspiciousEntries.Count) wpisow..." -ForegroundColor Yellow
    
    # Utworzenie folderu Kwarantanny, jesli nie istnieje
    if (-not (Test-Path $QuarantineDir)) {
        New-Item -Path $QuarantineDir -ItemType Directory -Force | Out-Null
        Write-Host "   Utworzono folder kwarantanny: $QuarantineDir" -ForegroundColor DarkGray
    }

    foreach ($entry in $SuspiciousEntries) {
        $entry | Add-Member -MemberType NoteProperty -Name 'BlockID' -Value ([guid]::NewGuid().Guid) -Force 

        $Location = $entry.Lokalizacja
        $Name = $entry.Nazwa
        
        Write-Host "   -> Blokowanie: $Name w $Location" -ForegroundColor White
        
        # Usuwanie/Przenoszenie wpisu z lokalizacji
		if ($Location -like "*Rejestr*") {
			# PRZYPADEK 1: Lokalizacja to Rejestr
			try {
				# Dane z obiektu sa podzielone na klucz (Lokalizacja) i nazwe wartosci (Nazwa).
				# Odtwarzamy sciezke do klucza (bez prefiksu "Registry: ").
				$Key = $entry.Sciezka
				$ValueName = $entry.Nazwa # Pobieramy nazwe wartosci z pola 'Nazwa'

				# DEBUG:
				Write-Host " 			[DEBUG] Usuwany Klucz: '$Key', Nazwa Wartosci: '$ValueName'" -ForegroundColor DarkGray

				# Uzywamy $Key i $ValueName bez prob Substring
				Remove-ItemProperty -Path $Key -Name $ValueName -Force -ErrorAction Stop

				Write-Host " 			[OK] Zablokowano w Rejestrze (klucz usuniety)." -ForegroundColor Green
				$BlockedCount++
			}
			catch {
				Write-Host " 			[BLAD] Nie mozna usunac z Rejestru: $($_.Exception.Message)" -ForegroundColor Red
			}
        }
        else {
            # PRZYPADEK 2: Lokalizacja to Katalog (Startup Folder) - PRZENOSZENIE DO KWARANTANNY
            try {
                # Uzywamy gotowej pelnej sciezki z OSO-Analyze
                $FilePath = $entry.SciezkaProgramu
                
                if (Test-Path $FilePath) {
                    $DestinationPath = Join-Path -Path $QuarantineDir -ChildPath $Name
                    
                    Move-Item -Path $FilePath -Destination $DestinationPath -Force -ErrorAction Stop
                    
                    $entry | Add-Member -MemberType NoteProperty -Name 'QuarantinePath' -Value $DestinationPath -Force
                    
                    Write-Host "      [OK] Zablokowano przez PRZENIESIENIE pliku do Kwarantanny." -ForegroundColor Green
                    $BlockedCount++
                } else {
                    Write-Host "      [UWAGA] Plik '$FilePath' nie zostal odnaleziony." -ForegroundColor Yellow
                    $BlockedCount++ 
                }
            }
            catch {
                Write-Host "      [BLAD] Nie mozna przeniesc pliku: $($_.Exception.Message)" -ForegroundColor Red
            }
        }
        
        # Zapisanie obiektu do bazy kwarantanny
        $QuarantineData += $entry
    }
    
    # Zapisanie zaktualizowanej kwarantanny do CSV
    Save-QuarantineData $QuarantineData
    
    Write-Host "`n[3/3] Podsumowanie:" -ForegroundColor Yellow
    Write-Host "   Zablokowano $BlockedCount nowych, podejrzanych wpisow. Zapisano do CSV." -ForegroundColor Green
}