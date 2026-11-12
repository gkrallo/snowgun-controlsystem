@echo off
rem Dubbelklicka pa den har filen for att kora sonden. Den gor samma sak som
rem att skriva kommandot i PowerShell, men fonstret stannar kvar efterat och
rem Windows sparr mot nedladdade skript (ExecutionPolicy) kringgas bara for
rem den har korningen. Ingen svensk bokstav i filen med flit: kommandofonstret
rem laser den med en annan teckentabell an PowerShell.

echo Kor sonden (bara lasning, inget andras) ...
echo.
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0db-sond.ps1" %*

rem Forsta forsoket gors med Windows-inloggningen. Den nar ofta inte
rem databaserna - da provar vi direkt med styrsystemets eget konto, sa att
rem det inte behovs en korning till for hand.
if errorlevel 1 if "%~1"=="" (
  echo.
  echo ------------------------------------------------------------
  echo  Windows-inloggningen racker inte. Provar med styrsystemets
  echo  konto GSS_Login - skriv losenordet nar det fragas efter.
  echo ------------------------------------------------------------
  echo.
  powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0db-sond.ps1" -User GSS_Login
)

echo.
echo Rapportfilen ligger bredvid den har filen (db-sond-rapport_...txt).
echo Tar du med den senaste hem ar du klar.
echo.
pause
