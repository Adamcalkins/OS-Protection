# ==============================================================================
# Plik: OSO-Report.ps1
# Funkcja: Start-Report (Generuje pełny raport dla uzytkownika)
# ==============================================================================

function Start-Report {

  # 1. Wywolaj czysty silnik enumeracji
  Write-Host "Wykonywanie skanowania autostartu..." -ForegroundColor Yellow
  $allAutostart = Start-Enumerate # Wywolanie funkcji Start-Enumerate bez parametru -Silent
    
  if (-not $allAutostart) {
      Write-Host "Nie znaleziono zadnych wpisow autostartu do raportowania." -ForegroundColor Red
      return
  }

  # 2. Raportowanie i Podsumowanie
  Write-Host ""
  Write-Host "============================================" -ForegroundColor Cyan
  Write-Host "  PODSUMOWANIE" -ForegroundColor Cyan
  Write-Host "============================================" -ForegroundColor Cyan
  Write-Host ""

  Write-Host "Lacznie znaleziono: $($allAutostart.Count) wpisow autostartu" -ForegroundColor White
  Write-Host ""

  $grouped = $allAutostart | Group-Object -Property Lokalizacja
  Write-Host "Rozklad wedlug typu:" -ForegroundColor Yellow
  foreach ($group in $grouped) {
      Write-Host " $($group.Name): $($group.Count) wpisow" -ForegroundColor Gray
  }

  Write-Host ""
  Write-Host "============================================" -ForegroundColor Cyan
  Write-Host " SZCZEGOLOWA LISTA" -ForegroundColor Cyan
  Write-Host "============================================" -ForegroundColor Cyan
  Write-Host ""

  $allAutostart | Format-Table -Property Lokalizacja, Nazwa, Wartosc -AutoSize

  # 3. Zapis do pliku CSV (Raport)
  $reportPath = "$env:USERPROFILE\Desktop\Autostart_Raport_$(Get-Date -Format 'yyyyMMdd_HHmmss').csv"
  $allAutostart | Export-Csv -Path $reportPath -NoTypeInformation -Encoding UTF8 -Delimiter ","

  Write-Host ""
  Write-Host "Raport zapisano w: $reportPath" -ForegroundColor Green

  $open = Read-Host "`nCzy chcesz otworzyc plik CSV z raportem? (T/N)"
  if ($open -eq "T" -or $open -eq "t") {
      Start-Process $reportPath
  }

  Write-Host ""
  Write-Host "Skanowanie zakonczone." -ForegroundColor Cyan
}