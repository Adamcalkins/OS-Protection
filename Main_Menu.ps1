# ==============================================================================
# Plik: Main_Menu.ps1
# Glowny skrypt z dynamicznym ladowaniem modulow
# ==============================================================================

# Definicja sciezki do folderu z modulami
$ModulesPath = Join-Path -Path $PSScriptRoot -ChildPath "Modules"

$MenuOptions = @()
$optionIndex = 1

Write-Host "Ladowanie modulow..." -ForegroundColor Yellow

# Automatyczne ladowanie wszystkich skryptow z podkatalogu Modules
if (Test-Path $ModulesPath) {
    # Szukamy wszystkich plikow, ktore zaczynaja sie na 'OSO-' i koncza na '.ps1'
    $ModuleFiles = Get-ChildItem -Path $ModulesPath -Filter "OSO-*.ps1" -ErrorAction SilentlyContinue
    
    foreach ($file in $ModuleFiles) {
        try {
            # . $file.FullName wczytuje zawartosc skryptu do biezacej sesji (w tym funkcje)
            . $file.FullName 
            
            # Nazwa modulu jest pobierana z nazwy pliku (np. OSO-Enumerate -> Enumerate)
            $moduleName = $file.BaseName -replace "OSO-", ""
            
            # Wpis do menu
            $MenuOptions += [PSCustomObject]@{
                Index = $optionIndex
                Name  = "Wykonaj : $moduleName"
                File  = $file.FullName
                # Konstruujemy oczekiwana nazwe funkcji: Start-Enumerate
                FunctionToCall = "Start-$moduleName" 
            }
            $optionIndex++
            
            Write-Host " [+] Zaladowano: $($file.BaseName) jako Start-$moduleName" -ForegroundColor Green
        }
        catch {
            Write-Host " [-] Blad ladowania modulu $($file.Name): $($_.Exception.Message)" -ForegroundColor Red
        }
    }
} else {
    Write-Error "Nie znaleziono folderu 'Modules'. Skrypt nie moze dzialac."
    Read-Host "Nacisnij Enter, aby zamknac..."
    exit
}

function Show-MainMenu {
    # Funkcja wyswietla menu glowne na podstawie zaladowanych modulow
    param($Options)
    
    Write-Host "============================================" -ForegroundColor Cyan
    Write-Host "       SKRYPT DO ZARZADZANIA AUTOSTART" -ForegroundColor Cyan
    Write-Host "============================================" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "Wybierz opcje, ktora chcesz wykonac:" -ForegroundColor White
    Write-Host ""

    # Wyswietlanie dynamicznych opcji
    foreach ($opt in $Options) {
        Write-Host "$($opt.Index). $($opt.Name)" -ForegroundColor Yellow
    }

    # Opcja ZAMKNIJ
    Write-Host "$($optionIndex). ZAMKNIJ SKRYPT" -ForegroundColor Red
    Write-Host ""

    $choice = Read-Host "Wybor (1-$optionIndex)"
    return $choice
}

# Glowna petla aplikacji
$runMenu = $true 

while ($runMenu) {
    Clear-Host 
    $userChoice = Show-MainMenu -Options $MenuOptions

    if ($userChoice -eq "$optionIndex") {
        Write-Host "Zamykanie skryptu. Do widzenia!" -ForegroundColor Red
        $runMenu = $false
    }
    elseif ($userChoice -match "^[0-9]+$" -and $userChoice -le $MenuOptions.Count -and $userChoice -ge 1) {
        # Znaleziono pasujacy modul
        $SelectedOption = $MenuOptions | Where-Object {$_.Index -eq [int]$userChoice}
        
        Write-Host "`n-- ROZPOCZETO AKCJE: $($SelectedOption.Name) --`n" -ForegroundColor Yellow
        
        # Wywolanie funkcji za pomoca Invoke-Expression
        # Jest to konieczne, poniewaz nazwa funkcji jest przechowywana jako string
        $null = Invoke-Expression -Command "$($SelectedOption.FunctionToCall)"
        
        Write-Host "`n-- Zakonczono --`n" -ForegroundColor Yellow
        Read-Host "Nacisnij Enter, aby wrocic do Menu Glownego..." | Out-Null
    }
    else {
        Write-Host "Nieprawidlowy wybor. Sprobuj ponownie." -ForegroundColor Red
        Start-Sleep -Seconds 1
    }
}