# ============================================================================
#  Snögruppen - läs-only-sond mot styrdatorn och styrsystemets databaser
#  ----------------------------------------------------------------------------
#  Körs EN gång på styrdatorn för att kartlägga allt bryggan behöver veta.
#
#  Vad den gör:
#    * tittar på datorn (minne, processer, nät, klocka) och på GSSystems loggar.
#    * ansluter till SQL Server och LÄSER (SELECT) - skriver aldrig något till
#      databasen, skapar inget konto, ändrar inga inställningar.
#    * går igenom ALLA GSSystems databaser. Granskningen av programfilerna
#      visade att de är fyra (Live_Snowstar, Live_stat_SQL, Live_event_SQL,
#      Live_Language) - den första versionen av sonden såg bara en.
#    * alla läsningar använder WITH (NOLOCK) så styrprogrammet aldrig kan låsas.
#    * radantal hämtas ur systemtabeller (ögonblickligt), inte via COUNT(*).
#    * stora tabeller sorteras bara om de har ett index på datum - annars visas
#      tre rader osorterat, så att ingen stor tabell skannas.
#    * sparar allt i en textfil bredvid skriptet (db-sond-rapport_DATUM.txt).
#
#  Vad den INTE gör:
#    * skickar ingen data någonstans. Den provar bara om datorn NÅR molnet
#      (en tom förfrågan). Rapporten stannar på datorn tills DU tar med den.
#    * visar inga rader ur tabeller som kan innehålla lösenord eller
#      telefonnummer (smtp, sms, användare) - bara deras kolumner.
#
#  Krav: ingenting att installera. Windows PowerShell (2.0 eller senare) och
#  .NET:s inbyggda SqlClient räcker.
# ============================================================================

param(
  # Lämna tom: skriptet provar de adresser GSSystem själv använder, i tur och
  # ordning. Ange bara om du vet att instansen heter något annat.
  [string]$Server = "",
  # Lämna tom för att prova Windows-inloggning. Ange -User för SQL-inloggning
  # (då frågas lösenordet - det skrivs aldrig ut och sparas inte).
  [string]$User   = "",
  # Mapp där GSSystem ligger. Lämna tom så letar skriptet själv.
  [string]$GsLog  = ""
)

$ErrorActionPreference = "Stop"
$started = Get-Date
$stamp   = Get-Date -Format "yyyyMMdd-HHmmss"

# $PSScriptRoot finns först i PowerShell 3. Styrdatorn kan vara äldre.
$here = $PSScriptRoot
if (-not $here) { $here = Split-Path -Parent $MyInvocation.MyCommand.Path }
if (-not $here) { $here = (Get-Location).Path }
$report = Join-Path $here "db-sond-rapport_$stamp.txt"
$lines  = New-Object System.Collections.Generic.List[string]

function Log([string]$s = "") { $lines.Add($s); Write-Host $s }
function Head([string]$s) { Log ""; Log $s; Log ("-" * [Math]::Min(76, $s.Length)) }
function Save-Report { $lines | Out-File -FilePath $report -Encoding utf8 }

Log "============================================================"
Log " Läs-only-sond mot styrdatorn (version 2)"
Log " Tid:    $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')"
Log " Dator:  $env:COMPUTERNAME   Användare: $env:USERNAME"
Log "============================================================"

# =================== 0. Miljö på datorn =====================================
# Körs före databasen, så vi får svaret även om DB-anslutningen misslyckas.
# Avgör vilket språk bryggan skrivs i, hur lätt den måste vara och om datorn
# alls når molnet.
Head "0. MILJÖ PÅ DATORN (avgör hur bryggan byggs)"
Log ("   PowerShell: " + $PSVersionTable.PSVersion.ToString())

# Get-CimInstance finns först i PowerShell 3 - Get-WmiObject fungerar överallt.
try {
  $os = Get-WmiObject Win32_OperatingSystem
  Log ("   OS: " + $os.Caption + " " + $os.OSArchitecture + " (version " + $os.Version + ")")
  $totMb  = [Math]::Round($os.TotalVisibleMemorySize / 1024)
  $freeMb = [Math]::Round($os.FreePhysicalMemory / 1024)
  Log ("   Arbetsminne: $totMb MB totalt, $freeMb MB ledigt just nu")
  $boot = $os.ConvertToDateTime($os.LastBootUpTime)
  Log ("   Senaste omstart: " + $boot.ToString('yyyy-MM-dd HH:mm') +
       " (" + [Math]::Round(((Get-Date) - $boot).TotalDays, 1) + " dygn sedan)")
} catch { Log "   OS/minne: kunde inte läsas ($($_.Exception.Message))" }
try {
  $cpu = Get-WmiObject Win32_Processor | Select-Object -First 1
  Log ("   Processor: " + $cpu.Name.Trim() + " (" + $cpu.NumberOfLogicalProcessors + " trådar)")
} catch {}
try {
  $d = Get-WmiObject Win32_LogicalDisk -Filter "DeviceID='C:'"
  Log ("   Disk C: " + [Math]::Round($d.FreeSpace / 1GB, 1) + " GB ledigt av " +
       [Math]::Round($d.Size / 1GB, 1) + " GB")
} catch {}

# Klocka och tidszon. Mätvärdena får tidsstämplar - då måste vi veta om
# datorns klocka går rätt och hur den hanterar sommartid (watchdog-raderna i
# GSSystems logg faller alla kl 03:00 natten då klockan ställs fram).
try {
  $tz = [System.TimeZone]::CurrentTimeZone
  Log ("   Tidszon: " + $tz.StandardName + ", UTC" + $tz.GetUtcOffset((Get-Date)).ToString() +
       ", sommartid just nu: " + $tz.IsDaylightSavingTime((Get-Date)))
} catch {}

# .NET-version (avgör bl.a. om TLS 1.2 finns, som molnet kräver)
try {
  $rel = (Get-ItemProperty "HKLM:\SOFTWARE\Microsoft\NET Framework Setup\NDP\v4\Full" -ErrorAction Stop).Release
  Log "   .NET Framework 4.x, Release-nummer: $rel (378389 = 4.5, 461808 = 4.7.2, 528040 = 4.8)"
} catch { Log "   .NET Framework 4.x: hittades inte i registret" }

# Python och Node? (inte nödvändigt - bryggan kan skrivas i PowerShell)
foreach ($prog in @("python","py","node")) {
  try {
    $v = & $prog --version 2>&1
    if ($v) { Log ("   $prog : " + ($v | Select-Object -First 1)) } else { Log "   $prog : finns inte" }
  } catch { Log "   $prog : finns inte" }
}

# ODBC-drivrutiner för SQL Server (behövs bara om bryggan blir Python)
try {
  $odbc = Get-ItemProperty "HKLM:\SOFTWARE\ODBC\ODBCINST.INI\ODBC Drivers" -ErrorAction Stop
  $sqlDrivers = $odbc.PSObject.Properties |
    Where-Object { $_.Name -match "SQL Server" } | ForEach-Object { $_.Name }
  if ($sqlDrivers) { Log ("   ODBC SQL-drivrutiner: " + ($sqlDrivers -join "; ")) }
  else { Log "   ODBC SQL-drivrutiner: inga SQL Server-drivrutiner hittades" }
} catch { Log "   ODBC-drivrutiner: kunde inte läsas" }

# Vilka av styrsystemets program går, och hur mycket minne tar de?
# Bryggan ska väga lätt bredvid dem.
Log "   Processer (styrsystemet och SQL Server):"
try {
  $procs = Get-Process | Where-Object { $_.ProcessName -match '^(GSS|Server\d|SMScontrol|sqlservr|Statistiques|recup_stat|Gestion_base)' } |
    Sort-Object ProcessName
  if (-not $procs) { Log "      (inga hittades - går GSSystem just nu?)" }
  foreach ($p in $procs) {
    $st = ""; try { $st = "  startad " + $p.StartTime.ToString('yyyy-MM-dd HH:mm') } catch {}
    Log ("      " + $p.ProcessName.PadRight(22) + [Math]::Round($p.WorkingSet64 / 1MB).ToString().PadLeft(6) + " MB" + $st)
  }
} catch { Log "      kunde inte läsas ($($_.Exception.Message))" }

# SQL Servers tjänster. SQL Browser avgör om instansnamnet går att slå upp.
try {
  Get-Service | Where-Object { $_.Name -match '^(MSSQL|SQLBrowser|SQLAgent|SQLWriter)' } | ForEach-Object {
    Log ("   Tjänst " + $_.Name + ": " + $_.Status)
  }
} catch {}

# Når datorn molnet UTÅT? (bryggan skickar bara ut, aldrig in)
# Först ren TCP mot de adresser Firebase använder, sedan en riktig HTTPS-
# förfrågan: gamla Windows saknar ofta TLS 1.2 som förval, och då räcker det
# inte att porten är öppen.
foreach ($hostName in @("firestore.googleapis.com","identitytoolkit.googleapis.com","securetoken.googleapis.com")) {
  try {
    $c = New-Object System.Net.Sockets.TcpClient
    $iar = $c.BeginConnect($hostName, 443, $null, $null)
    $ok = $iar.AsyncWaitHandle.WaitOne(4000, $false)
    if ($ok -and $c.Connected) { Log "   Utgående 443 -> $hostName : OK" }
    else { Log "   Utgående 443 -> $hostName : NÅDDE INTE (kolla brandvägg/proxy)" }
    $c.Close()
  } catch { Log "   Utgående 443 -> $hostName : fel ($($_.Exception.Message))" }
}
try {
  # 3072 = TLS 1.2. Skrivet som tal eftersom namnet saknas i gamla .NET.
  try { [System.Net.ServicePointManager]::SecurityProtocol = 3072 } catch { Log "   TLS 1.2 går inte att slå på i den här .NET-versionen" }
  $uri = New-Object System.Uri "https://www.gstatic.com/generate_204"
  $px = [System.Net.WebRequest]::GetSystemWebProxy().GetProxy($uri)
  if ($px -and $px.AbsoluteUri -ne $uri.AbsoluteUri) { Log ("   Proxy används för utgående trafik: " + $px.Host + ":" + $px.Port) }
  else { Log "   Proxy: ingen (direkt ut)" }
  $req = [System.Net.WebRequest]::Create($uri)
  $req.Timeout = 8000
  $resp = $req.GetResponse()
  Log ("   HTTPS med TLS 1.2 -> www.gstatic.com : OK (svar " + [int]$resp.StatusCode + ")")
  # Molnets klocka mot datorns: en klocka som går fel ger fel tidsstämplar.
  $srvDate = $resp.Headers["Date"]
  if ($srvDate) {
    $skew = ((Get-Date).ToUniversalTime() - [DateTime]::Parse($srvDate).ToUniversalTime()).TotalSeconds
    Log ("   Datorns klocka mot molnets: " + [Math]::Round($skew) + " s skillnad")
  }
  $resp.Close()
} catch { Log "   HTTPS med TLS 1.2 -> www.gstatic.com : MISSLYCKADES ($($_.Exception.Message))" }

# =================== 0b. Styrsystemets loggar ===============================
# Granskningen av programfilerna visade minnesfel i SQL Server (en kväll,
# 24 december 2022), watchdog-rader varje vår och en del andra fel. Här ser vi
# vad som hänt sedan dess. Bara läsning av filer, inget ändras.
Head "0b. STYRSYSTEMETS LOGGAR"

$logRoots = @()
if ($GsLog -ne "") {
  if (Test-Path $GsLog) { $logRoots += $GsLog }
  else { Log "   Angiven -GsLog finns inte: $GsLog" }
} else {
  $cand = @("C:\GSSystem","D:\GSSystem","C:\Sufag","C:\MND")
  if ($env:ProgramFiles) { $cand += (Join-Path $env:ProgramFiles "GSSystem") }
  $pf86 = ${env:ProgramFiles(x86)}
  if ($pf86) { $cand += (Join-Path $pf86 "GSSystem") }
  foreach ($root in $cand) { if (Test-Path $root) { $logRoots += $root } }
}
# SQL Servers egen ERRORLOG ligger i instansens Log-mapp.
$sqlLogRoots = @()
foreach ($b in @($env:ProgramFiles, ${env:ProgramFiles(x86)})) {
  if (-not $b) { continue }
  $ms = Join-Path $b "Microsoft SQL Server"
  if (Test-Path $ms) {
    Get-ChildItem -Path $ms -ErrorAction SilentlyContinue | Where-Object { $_.PSIsContainer -and $_.Name -like "MSSQL*" } | ForEach-Object {
      $lp = Join-Path $_.FullName "MSSQL\Log"
      if (Test-Path $lp) { $sqlLogRoots += $lp }
    }
  }
}

# Mönster vi räknar. SQL Server och GSSystem loggar på FRANSKA på den här
# datorn. Franska mönster skrivs utan accenter, så matchningen inte beror på
# hur loggfilen är teckenkodad.
$groups = @(
  @("minnesfel",        @("insufficient system memory","out of memory","insuffisante","not enough storage","cannot allocate")),
  @("timeout",          @("timeout expired","timeout period")),
  @("watchdog/krasch",  @("watchdog","ne fonctionne plus","crashed")),
  @("overflow (VB6)",   @("passement de capacit")),
  @("SQL-fel vid lagring", @("erreur enregistrement")),
  @("behörighet",       @("permission refus","access denied","acces refus")),
  @("dongel",           @("dongle"))
)

function Scan-LogFile($f, [bool]$tail) {
  $sizeKb = [Math]::Round($f.Length / 1KB)
  $shown = (Split-Path -Leaf $f.DirectoryName) + "\" + $f.Name
  Log ("   " + $shown + "  (" + $sizeKb + " kB, ändrad " + $f.LastWriteTime.ToString('yyyy-MM-dd HH:mm') + ")")
  if ($f.Length -eq 0) { Log "      (tom)"; return }
  if ($f.Length -gt 20MB) { Log "      (för stor för att läsas här - hoppar över)"; return }
  foreach ($g in $groups) {
    try {
      # -Encoding default = datorns ANSI-teckentabell, som GSSystem skriver i.
      # Utan den läses é som skräptecken. Filer med BOM (SQL Servers
      # ERRORLOG är UTF-16) känns igen ändå.
      $found = @(Select-String -Path $f.FullName -Pattern $g[1] -SimpleMatch -Encoding default -ErrorAction SilentlyContinue)
      if ($found.Count -gt 0) {
        $last = $found[$found.Count - 1].Line.Trim()
        if ($last.Length -gt 150) { $last = $last.Substring(0, 147) + "..." }
        Log ("      " + $g[0] + ": " + $found.Count + " rader. Senaste: " + $last)
      }
    } catch {}
  }
  if ($tail) {
    try {
      $all = @(Get-Content -Path $f.FullName -ErrorAction Stop)
      Log ("      Sista raderna (av " + $all.Count + "):")
      $from = [Math]::Max(0, $all.Count - 12)
      for ($i = $from; $i -lt $all.Count; $i++) {
        $t = $all[$i].Trim(); if ($t -eq "") { continue }
        if ($t.Length -gt 170) { $t = $t.Substring(0, 167) + "..." }
        Log ("        " + $t)
      }
    } catch { Log "      (kunde inte läsa filen: $($_.Exception.Message))" }
  }
}

if ($logRoots.Count -eq 0) {
  Log "   Hittade ingen GSSystem-mapp automatiskt."
  Log "   Kör igen med sökväg till mappen, t.ex.:  .\db-sond.ps1 -GsLog `"C:\GSSystem`""
  Log "   (hitta mappen: högerklicka GSSystem-ikonen -> Öppna filplats)."
} else {
  foreach ($root in $logRoots) {
    Log "   GSSystems mapp: $root"
    try {
      # .log i BdD, .rap och GSSystem*.tmp i concept - det är där GSSystem skriver.
      $files = Get-ChildItem -Path $root -Recurse -ErrorAction SilentlyContinue |
        Where-Object { -not $_.PSIsContainer -and ($_.Extension -match '^\.(log|rap)$' -or $_.Name -match '^GSSystem.*\.tmp$') } |
        Sort-Object FullName
      if (-not $files) { Log "      (inga loggfiler hittades här)" }
      foreach ($f in $files) { Scan-LogFile $f $true }
    } catch { Log "      (kunde inte läsa mappen: $($_.Exception.Message))" }
  }
}
foreach ($root in $sqlLogRoots) {
  Log "   SQL Servers loggmapp: $root"
  try {
    $files = Get-ChildItem -Path $root -ErrorAction SilentlyContinue |
      Where-Object { -not $_.PSIsContainer -and $_.Name -like "ERRORLOG*" } | Sort-Object Name
    foreach ($f in $files) { Scan-LogFile $f $false }
  } catch { Log "      (kunde inte läsa mappen: $($_.Exception.Message))" }
}
if ($sqlLogRoots.Count -eq 0) { Log "   SQL Servers loggmapp hittades inte under Program Files." }

# Spara det vi har hittills - om något går snett längre ner finns det ändå.
Save-Report

# =================== 1. Anslutning ==========================================
Head "1. ANSLUTNING TILL SQL SERVER"

$pw = ""
if ($User -ne "") {
  $sec  = Read-Host "Lösenord för SQL-inloggningen '$User'" -AsSecureString
  $bstr = [Runtime.InteropServices.Marshal]::SecureStringToBSTR($sec)
  $pw   = [Runtime.InteropServices.Marshal]::PtrToStringAuto($bstr)
  [Runtime.InteropServices.Marshal]::ZeroFreeBSTR($bstr)
  $authNote = "SQL-inloggning som '$User'"
} else {
  $authNote = "Windows-inloggning ($env:USERNAME)"
}

# GSSystem använder olika skrivsätt i olika program (SQL.ini, exe.config).
# Vilket som fungerar beror på om SQL Browser går och om TCP är påslaget, så
# vi provar dem i tur och ordning. Ingen databas anges: vi hamnar i
# inloggningens förvalda och byter sedan till var och en.
if ($Server -ne "") { $servers = @($Server) }
else { $servers = @("127.0.0.1\SQLEXPRESS,1433", "localhost\SQLEXPRESS", ".\SQLEXPRESS", "127.0.0.1,1433") }

$conn = $null
foreach ($srv in $servers) {
  $b = New-Object System.Data.SqlClient.SqlConnectionStringBuilder
  $b["Data Source"] = $srv
  $b["Connect Timeout"] = 6
  $b["Application Name"] = "snogrupp-sond"
  if ($User -ne "") { $b["User ID"] = $User; $b["Password"] = $pw } else { $b["Integrated Security"] = $true }
  $try = New-Object System.Data.SqlClient.SqlConnection $b.ConnectionString
  try {
    $try.Open()
    $conn = $try
    Log "   ANSLUTNING OK mot $srv ($authNote)."
    break
  } catch {
    $ex = $_.Exception; while ($ex.InnerException) { $ex = $ex.InnerException }
    $msg = ($ex.Message -replace "[\r\n]+", " ")
    if ($msg.Length -gt 160) { $msg = $msg.Substring(0, 157) + "..." }
    Log "   $srv : $msg"
    # 18456 = servern svarade men godtog inte inloggningen. Då hjälper det
    # inte att prova fler adresser - det är kontot som är fel.
    if ($ex -is [System.Data.SqlClient.SqlException] -and $ex.Number -eq 18456) {
      Log "   Servern svarar, men inloggningen godtogs inte."
      break
    }
  }
}
$pw = ""

if (-not $conn) {
  Log ""
  Log "ANSLUTNING MISSLYCKADES ($authNote)."
  if ($User -eq "") {
    Log "Tips: kör med styrsystemets SQL-inloggning i stället:"
    Log "   powershell -ExecutionPolicy Bypass -File .\db-sond.ps1 -User GSS_Login"
    Log "(du får då skriva lösenordet - det står i SECRETS.md hemma)."
  }
  Save-Report
  Write-Host ""
  Write-Host "Rapport (miljö och loggar finns med, databasen saknas) sparad: $report"
  exit 1
}

# ---- hjälpfunktioner för läsning --------------------------------------------
function Invoke-Read([string]$sql) {
  $cmd = $conn.CreateCommand()
  $cmd.CommandText = $sql
  $cmd.CommandTimeout = 15
  $da = New-Object System.Data.SqlClient.SqlDataAdapter $cmd
  $dt = New-Object System.Data.DataTable
  [void]$da.Fill($dt)
  # Kommat hindrar PowerShell från att veckla ut tabellen till lösa rader.
  return ,$dt
}

# Kolumner och tabeller som kan bära lösenord, telefonnummer eller licenser.
# Rapporten lämnar datorn, så sådant ska inte följa med.
$secretCol   = '(?i)pass|pwd|mdp|motdepasse|secret|token'
$secretTable = '(?i)smtp|mail|sms|user|utilisat|login|pass|mdp|licen|dongle|hasp|operateur|operator'

function Show-Rows($dt, [int]$max) {
  $i = 0
  foreach ($r in $dt.Rows) {
    $i++; if ($i -gt $max) { break }
    $parts = New-Object System.Collections.Generic.List[string]
    foreach ($c in $dt.Columns) {
      $v = $r[$c]
      if ($v -is [System.DBNull]) { continue }
      if ($v -is [byte[]]) { $s = "<bin " + $v.Length + " byte>" }
      elseif ($v -is [datetime]) { $s = $v.ToString("yyyy-MM-dd HH:mm:ss") }
      else { $s = "$v" }
      $s = ($s -replace "[\r\n]+", " ").Trim()
      if ($s -eq "") { continue }
      if ($c.ColumnName -match $secretCol) { $s = "<dolt>" }
      if ($s.Length -gt 60) { $s = $s.Substring(0, 57) + "..." }
      $parts.Add($c.ColumnName + "=" + $s)
    }
    Log ("      #" + $i + ": " + ($parts.ToArray() -join " | "))
  }
}
function Show-Table($dt) {
  if ($dt.Rows.Count -eq 0) { Log "   (inga rader)"; return }
  $cols = @($dt.Columns | ForEach-Object { $_.ColumnName })
  Log ("   " + ($cols -join " | "))
  foreach ($r in $dt.Rows) {
    $vals = foreach ($c in $cols) {
      $v = ("" + $r[$c]) -replace "[\r\n]+", " "
      if ($v.Length -gt 70) { $v = $v.Substring(0, 67) + "..." }
      $v
    }
    Log ("   " + ($vals -join " | "))
  }
}
function Q([string]$name) { return "[" + $name.Replace("]", "]]") + "]" }

# =================== 2. Server, version och minne ============================
Head "2. SERVER, VERSION OCH MINNE"
try {
  $dt = Invoke-Read "SELECT @@VERSION AS v, @@LANGUAGE AS sprak, SERVERPROPERTY('Collation') AS kollation, SERVERPROPERTY('Edition') AS utgava, GETDATE() AS servertid, SUSER_SNAME() AS inloggad_som, DB_NAME() AS forvald_db"
  foreach ($r in $dt.Rows) {
    Log ("   " + (("" + $r["v"]) -replace "\s+", " "))
    Log ("   Utgåva: " + $r["utgava"] + "   Språk: " + $r["sprak"] + "   Kollation: " + $r["kollation"])
    Log ("   Serverns klocka: " + ([datetime]$r["servertid"]).ToString('yyyy-MM-dd HH:mm:ss') + "   Inloggad som: " + $r["inloggad_som"] + "   Förvald databas: " + $r["forvald_db"])
  }
} catch { Log "   FEL: $($_.Exception.Message)" }
# Minnestaket. SQL Express har ett eget tak på buffertminnet (1 GB i äldre
# versioner) - det var det som tog slut julen 2022.
try {
  $dt = Invoke-Read "SELECT name, CAST(value_in_use AS bigint) AS varde FROM sys.configurations WHERE name LIKE '%server memory%' ORDER BY name"
  foreach ($r in $dt.Rows) { Log ("   " + $r["name"] + ": " + $r["varde"]) }
} catch { Log "   Minnesinställningar: kunde inte läsas ($($_.Exception.Message))" }
try {
  $dt = Invoke-Read "SELECT physical_memory_in_use_kb/1024 AS anvant_MB, memory_utilization_percentage AS andel_procent, process_physical_memory_low AS lagt_fysiskt, process_virtual_memory_low AS lagt_virtuellt FROM sys.dm_os_process_memory"
  Log "   SQL Servers minne just nu:"; Show-Table $dt
} catch { Log "   SQL Servers minne just nu: kräver VIEW SERVER STATE (går inte med det här kontot)" }
try {
  $dt = Invoke-Read "SELECT sqlserver_start_time FROM sys.dm_os_sys_info"
  foreach ($r in $dt.Rows) { Log ("   SQL Server startad: " + ([datetime]$r[0]).ToString('yyyy-MM-dd HH:mm')) }
} catch {}

# =================== 3. Nätverk (TCP/IP och port) ============================
# Bryggan körs på samma dator, så det här är mest för att veta läget.
Head "3. NÄTVERKSPROTOKOLL"
try {
  $dt = Invoke-Read @"
SELECT registry_key, value_name, value_data
FROM sys.dm_server_registry
WHERE registry_key LIKE '%SuperSocketNetLib%Tcp%'
  AND value_name IN ('Enabled','TcpPort','TcpDynamicPorts')
ORDER BY registry_key, value_name
"@
  Show-Table $dt
} catch { Log "   Kunde inte läsa (kräver VIEW SERVER STATE eller nyare SQL Server)" }
try {
  $dt = Invoke-Read "SELECT program_name AS program, COUNT(*) AS anslutningar FROM sys.dm_exec_sessions WHERE is_user_process = 1 GROUP BY program_name ORDER BY COUNT(*) DESC"
  Log "   Program som är anslutna just nu:"; Show-Table $dt
} catch { Log "   Anslutna program: kräver VIEW SERVER STATE" }

# =================== 4. Inloggningar och roller =============================
# För att planera ett eget läs-only-konto i stället för GSS_Login.
Head "4. INLOGGNINGAR OCH MINA RÄTTIGHETER"
try {
  $dt = Invoke-Read "SELECT name, type_desc, is_disabled FROM sys.server_principals WHERE type IN ('S','U','G') AND name NOT LIKE '##%' ORDER BY type_desc, name"
  Show-Table $dt
} catch { Log "   FEL: $($_.Exception.Message)" }
try {
  $dt = Invoke-Read "SELECT IS_SRVROLEMEMBER('sysadmin') AS ar_sysadmin, IS_SRVROLEMEMBER('securityadmin') AS far_skapa_konton"
  Show-Table $dt
} catch { Log "   FEL: $($_.Exception.Message)" }

# =================== 5. Databaserna ==========================================
Head "5. DATABASER PÅ SERVERN"
$dbNames = @()
try {
  $dt = Invoke-Read "SELECT name, database_id, state_desc, recovery_model_desc, create_date FROM sys.databases ORDER BY database_id"
  Show-Table $dt
  foreach ($r in $dt.Rows) { if ([int]$r["database_id"] -gt 4 -and ("" + $r["state_desc"]) -eq "ONLINE") { $dbNames += ("" + $r["name"]) } }
} catch { Log "   FEL: $($_.Exception.Message)" }
try {
  $dt = Invoke-Read "SELECT DB_NAME(database_id) AS db, type_desc, CAST(size AS bigint)*8/1024 AS storlek_MB, physical_name FROM sys.master_files WHERE database_id > 4 ORDER BY database_id, file_id"
  Log "   Filer:"; Show-Table $dt
} catch { Log "   Filstorlekar: kunde inte läsas med det här kontot" }
if ($dbNames.Count -eq 0) { $dbNames = @("Live_Snowstar","Live_stat_SQL","Live_event_SQL","Live_Language") }

# =================== 6. Varje databas: tabeller, kolumner, smakprov ==========
# Radantal ur sys.partitions. Smakprov: små tabeller visas hela (det är där
# nuläget och apparatlistorna finns), stora bara med de tre senaste raderna.
foreach ($db in $dbNames) {
  Head "6. DATABAS $db"
  try { $conn.ChangeDatabase($db) }
  catch { Log "   Kommer inte åt databasen: $($_.Exception.Message)"; continue }

  try {
    $dt = Invoke-Read "SELECT IS_MEMBER('db_datareader') AS datareader, IS_MEMBER('db_datawriter') AS datawriter, IS_MEMBER('db_owner') AS db_owner"
    Log "   Mina roller här:"; Show-Table $dt
  } catch {}

  # --- tabeller och radantal ---
  $tables = $null
  try {
    $tables = Invoke-Read @"
SELECT s.name AS sch, t.name AS tabell, SUM(p.rows) AS rader
FROM sys.tables t
JOIN sys.schemas s    ON t.schema_id = s.schema_id
JOIN sys.partitions p ON p.object_id = t.object_id AND p.index_id IN (0,1)
GROUP BY s.name, t.name
ORDER BY t.name
"@
  } catch { Log "   Tabellistan: FEL: $($_.Exception.Message)"; continue }
  Log ("   " + $tables.Rows.Count + " tabeller.")

  # --- kolumner, alla tabeller i en fråga ---
  $colsOf = @{}
  try {
    $dt = Invoke-Read @"
SELECT t.name AS tabell, c.name AS kol, ty.name AS typ
FROM sys.tables t
JOIN sys.columns c ON c.object_id = t.object_id
JOIN sys.types ty  ON c.user_type_id = ty.user_type_id
ORDER BY t.name, c.column_id
"@
    foreach ($r in $dt.Rows) {
      $tn = "" + $r["tabell"]
      if (-not $colsOf.ContainsKey($tn)) { $colsOf[$tn] = New-Object System.Collections.Generic.List[string] }
      $colsOf[$tn].Add(("" + $r["kol"]) + ":" + ("" + $r["typ"]))
    }
  } catch { Log "   Kolumner: FEL: $($_.Exception.Message)" }

  # --- index: vilken kolumn leder varje index? Avgör om sortering är billig ---
  $leadCols = @{}
  try {
    $dt = Invoke-Read @"
SELECT t.name AS tabell, c.name AS kol
FROM sys.indexes i
JOIN sys.tables t         ON t.object_id = i.object_id
JOIN sys.index_columns ic ON ic.object_id = i.object_id AND ic.index_id = i.index_id AND ic.key_ordinal = 1
JOIN sys.columns c        ON c.object_id = ic.object_id AND c.column_id = ic.column_id
WHERE i.index_id > 0
"@
    foreach ($r in $dt.Rows) {
      $tn = "" + $r["tabell"]
      if (-not $leadCols.ContainsKey($tn)) { $leadCols[$tn] = @() }
      $leadCols[$tn] += ("" + $r["kol"]).ToLower()
    }
  } catch {}

  # I språkdatabasen ligger texterna som förklarar de numrerade kolumnerna -
  # där vill vi ha mer än ett smakprov.
  $allLimit = 100
  if ($db -match '(?i)language') { $allLimit = 3000 }

  foreach ($t in $tables.Rows) {
    $tn = "" + $t["tabell"]; $sch = "" + $t["sch"]; $n = [long]$t["rader"]
    $cl = @(); if ($colsOf.ContainsKey($tn)) { $cl = $colsOf[$tn].ToArray() }
    Log ""
    Log ("   [" + $tn + "]  " + $n + " rader, " + $cl.Count + " kolumner")
    if ($cl.Count -gt 0) {
      # radbryt kolumnlistan så filen går att läsa
      $line = "      kol: "
      foreach ($c in $cl) {
        if (($line.Length + $c.Length) -gt 118) { Log $line; $line = "           " }
        $line += $c + "  "
      }
      Log $line.TrimEnd()
    }
    if ($n -eq 0) { continue }
    if ($tn -match $secretTable) { Log "      (rader visas inte - tabellen kan innehålla lösenord eller telefonnummer)"; continue }

    $names = @($cl | ForEach-Object { ($_ -split ":")[0] })
    $dateCol = $null
    foreach ($cand in @("DateUpd","date","dateRap","Date_Heure","datetime")) {
      foreach ($nm in $names) { if ($nm -ieq $cand) { $dateCol = $nm; break } }
      if ($dateCol) { break }
    }
    $top = 3; if ($n -le $allLimit) { $top = [int]$n }
    $order = ""; $note = ""
    if ($dateCol) {
      $indexed = $leadCols.ContainsKey($tn) -and ($leadCols[$tn] -contains $dateCol.ToLower())
      # Sortera bara när det är billigt: liten tabell eller index på datumet.
      if ($n -le 300000 -or $indexed) { $order = " ORDER BY " + (Q $dateCol) + " DESC"; $note = " (senaste först)" }
      else { $note = " (osorterat - stor tabell utan datumindex, raderna kan vara gamla)" }
    }
    try {
      $dt = Invoke-Read ("SELECT TOP " + $top + " * FROM " + (Q $sch) + "." + (Q $tn) + " WITH (NOLOCK)" + $order)
      Log ("      " + $dt.Rows.Count + " rader visas" + $note + ":")
      Show-Rows $dt $top
    } catch { Log "      (hoppar över: $($_.Exception.Message))" }
  }
  Save-Report
}

$conn.Close()

$secs = [Math]::Round(((Get-Date) - $started).TotalSeconds)
Log ""
Log "============================================================"
Log " KLART på $secs s. Inget skrevs till databasen."
Log " Ta med den här filen tillbaka:"
Log "   $report"
Log "============================================================"

Save-Report
Write-Host ""
Write-Host "Rapport sparad: $report"
Write-Host "Det är den filen du tar med hem (lägg på Drive igen eller på ett USB-minne)."
exit 0
