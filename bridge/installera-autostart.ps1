<#
  Lägger upp (eller tar bort) den schemalagda uppgift som håller bryggan igång.

    Lägg upp:   .\installera-autostart.ps1
    Ta bort:    .\installera-autostart.ps1 -TaBort
    Visa läget: .\installera-autostart.ps1 -Visa

  Uppgiften startar bryggan när användaren loggar in, och försöker igen var
  femte minut. Går bryggan redan händer ingenting; har den dött kommer den
  alltså tillbaka inom fem minuter, och efter en omstart av datorn så snart
  någon är inloggad.

  Varför "vid inloggning" och inte "vid uppstart": lösenorden är krypterade
  med Windows DPAPI och går bara att läsa av det Windows-konto som sparade
  dem. Bryggan måste därför köras som samma användare. Styrdatorn loggar in
  av sig själv efter omstart (GSSystem startar på samma sätt), så i praktiken
  blir det samma sak.

  OPROVAT på styrdatorn. Ändrar inget i styrsystemet - bara en uppgift i
  Windows schemaläggare för den inloggade användaren.

  Filen ska vara sparad som UTF-8 MED BOM, utan typografiska tecken.
#>
param([switch]$TaBort, [switch]$Visa)

$ErrorActionPreference = "Stop"
$name = "Snogrupp-brygga"
$here = Split-Path -Parent $MyInvocation.MyCommand.Path
$script = Join-Path $here "brygga.ps1"

if ($Visa) {
  $t = Get-ScheduledTask -TaskName $name -ErrorAction SilentlyContinue
  if (-not $t) { Write-Host "Uppgiften finns inte."; exit 0 }
  $i = $t | Get-ScheduledTaskInfo
  Write-Host ("Läge: " + $t.State + "   Senast startad: " + $i.LastRunTime + "   Resultat: " + $i.LastTaskResult)
  $log = Join-Path $here "brygga.log"
  if (Test-Path $log) { Write-Host "Sista raderna i loggen:"; Get-Content $log -Tail 8 -Encoding UTF8 | ForEach-Object { Write-Host ("  " + $_) } }
  exit 0
}

if ($TaBort) {
  $t = Get-ScheduledTask -TaskName $name -ErrorAction SilentlyContinue
  if (-not $t) { Write-Host "Uppgiften finns inte."; exit 0 }
  Stop-ScheduledTask -TaskName $name -ErrorAction SilentlyContinue
  Unregister-ScheduledTask -TaskName $name -Confirm:$false
  Write-Host "Uppgiften är borttagen. En brygga som redan går stängs med Ctrl+C eller i Aktivitetshanteraren."
  exit 0
}

# Lägg inte upp något som inte kan fungera: utan sparade lösenord skulle
# bryggan stå och vänta på en fråga som ingen ser.
$missing = @()
foreach ($f in @("brygga.ps1", "brygga-config.json", "brygga-hemligt-sql.txt", "brygga-hemligt-moln.txt")) {
  if (-not (Test-Path (Join-Path $here $f))) { $missing += $f }
}
if ($missing.Count -gt 0) {
  Write-Host "Kan inte lägga upp autostarten än. Saknas i mappen:"
  $missing | ForEach-Object { Write-Host ("  " + $_) }
  Write-Host "Lösenorden sparas med:  .\brygga.ps1 -SparaLosen sql   och   -SparaLosen moln"
  exit 1
}

$user = [System.Security.Principal.WindowsIdentity]::GetCurrent().Name
$arg = '-NoProfile -NonInteractive -WindowStyle Hidden -ExecutionPolicy Bypass -File "' + $script + '" -Skicka'
$action = New-ScheduledTaskAction -Execute "powershell.exe" -Argument $arg -WorkingDirectory $here

$atLogon = New-ScheduledTaskTrigger -AtLogOn -User $user
# Var femte minut, för alltid. Äldre Windows kräver en uttalad längd.
$repeat = New-ScheduledTaskTrigger -Once -At (Get-Date).AddMinutes(1) -RepetitionInterval (New-TimeSpan -Minutes 5) -RepetitionDuration (New-TimeSpan -Days 3650)

# IgnoreNew: går bryggan redan startas ingen ny (inget fönster som blinkar
# på kontrollrumsskärmen). ExecutionTimeLimit noll: förvalet är tre dygn,
# och då skulle Windows stänga bryggan mitt i en köldknäpp.
$settings = New-ScheduledTaskSettingsSet -MultipleInstances IgnoreNew -ExecutionTimeLimit ([TimeSpan]::Zero) `
  -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries -StartWhenAvailable `
  -RestartCount 3 -RestartInterval (New-TimeSpan -Minutes 1)

# Interactive: körs som den inloggade användaren utan att något lösenord
# sparas i schemaläggaren. Limited: inga administratörsrättigheter.
$principal = New-ScheduledTaskPrincipal -UserId $user -LogonType Interactive -RunLevel Limited

$desc = "Läser nuläget ur GSSystems databas (bara läsning) och skickar ändringar till snögruppens app."
try {
  Register-ScheduledTask -TaskName $name -Action $action -Trigger @($atLogon, $repeat) -Settings $settings -Principal $principal -Description $desc -Force | Out-Null
} catch {
  # Ett konto utan administratörsrätt får ofta inte lägga upp "vid
  # inloggning". Då räcker femminutersförsöket: bryggan kommer igång inom
  # fem minuter efter inloggningen i stället för direkt.
  Write-Host ("Kunde inte lägga upp starten vid inloggning (" + $_.Exception.Message.Trim() + ").")
  Write-Host "Lägger upp bara femminutersförsöket i stället."
  Register-ScheduledTask -TaskName $name -Action $action -Trigger $repeat -Settings $settings -Principal $principal -Description $desc -Force | Out-Null
}

Start-ScheduledTask -TaskName $name
Start-Sleep -Seconds 5
$t = Get-ScheduledTask -TaskName $name
Write-Host ("Uppgiften '" + $name + "' är upplagd för " + $user + ". Läge just nu: " + $t.State)
Write-Host "Titta i brygga.log om en halv minut - där ska stå 'Hela nuläget, ... fält'."
Write-Host "Läget visas när som helst med:  .\installera-autostart.ps1 -Visa"
