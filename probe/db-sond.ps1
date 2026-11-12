# ============================================================================
#  Snögruppen - läs-only-sond mot styrsystemets databas (Live_Snowstar)
#  ----------------------------------------------------------------------------
#  Körs EN gång på styrdatorn för att kartlägga databasen inför bryggan.
#
#  Vad den gör:
#    * ansluter till SQL Server och LÄSER (SELECT) - skriver aldrig något till
#      databasen, skapar inget konto, ändrar inga inställningar.
#    * alla läsningar använder WITH (NOLOCK) så styrprogrammet aldrig kan låsas.
#    * radantal hämtas ur systemtabeller (ögonblickligt), inte via COUNT(*) som
#      skulle skanna de stora statistiktabellerna.
#    * sparar allt i en textfil bredvid skriptet (db-sond-rapport_DATUM.txt).
#
#  Vad den INTE gör:
#    * inget nätverk ut - inget skickas någonstans. Rapporten stannar på datorn
#      tills DU tar med den.
#    * inga tunga frågor, inga JOIN:ar, bara TOP 5 ur de små nulägestabellerna.
#
#  Krav: ingenting att installera. Windows PowerShell 5.1 (finns på alla
#  Windows) och .NET:s inbyggda SqlClient räcker.
# ============================================================================

param(
  # Standard är den instans GSSystem använder. Ändra bara om du vet att den
  # heter något annat.
  [string]$Server   = "127.0.0.1\SQLEXPRESS",
  [string]$Database = "Live_Snowstar",
  # Lämna User tom för att prova Windows-inloggning (om du är inloggad som en
  # användare med åtkomst). Ange -User för SQL-inloggning (då frågas lösenord).
  [string]$User     = ""
)

$ErrorActionPreference = "Stop"
$stamp  = Get-Date -Format "yyyyMMdd-HHmmss"
$report = Join-Path $PSScriptRoot "db-sond-rapport_$stamp.txt"
$lines  = New-Object System.Collections.Generic.List[string]

function Log([string]$s="") { $lines.Add($s); Write-Host $s }

Log "============================================================"
Log " Läs-only-sond mot styrsystemets databas"
Log " Tid:    $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')"
Log " Server: $Server   Databas: $Database"
Log " Dator:  $env:COMPUTERNAME   Användare: $env:USERNAME"
Log "============================================================"
Log ""

# =================== 0. Miljö på datorn (för bryggan) =======================
# Körs före databasen, så vi får svaret även om DB-anslutningen misslyckas.
# Avgör vilket språk bryggan skrivs i och om datorn alls når molnet.
Log "0. MILJÖ PÅ DATORN (avgör hur bryggan byggs)"
Log "--------------------------------------------"
Log ("   PowerShell: " + $PSVersionTable.PSVersion.ToString())
Log ("   OS: " + (Get-CimInstance Win32_OperatingSystem -ErrorAction SilentlyContinue).Caption)

# Python och Node? (inte nödvändigt, men avgör bryggans språk)
foreach ($prog in @("python","py","node")) {
  try {
    $v = & $prog --version 2>&1
    if ($LASTEXITCODE -eq 0 -or $v) { Log ("   $prog : " + ($v | Select-Object -First 1)) }
    else { Log "   $prog : finns inte" }
  } catch { Log "   $prog : finns inte" }
}

# ODBC-drivrutiner för SQL Server (behövs om bryggan blir Python med pyodbc)
try {
  $odbc = Get-ItemProperty "HKLM:\SOFTWARE\ODBC\ODBCINST.INI\ODBC Drivers" -ErrorAction Stop
  $sqlDrivers = $odbc.PSObject.Properties |
    Where-Object { $_.Name -match "SQL Server" } | ForEach-Object { $_.Name }
  if ($sqlDrivers) { Log ("   ODBC SQL-drivrutiner: " + ($sqlDrivers -join "; ")) }
  else { Log "   ODBC SQL-drivrutiner: inga SQL Server-drivrutiner hittades" }
} catch { Log "   ODBC-drivrutiner: kunde inte läsas ($($_.Exception.Message))" }

# Når datorn molnet UTÅT på 443? (bryggan skickar bara ut, aldrig in)
foreach ($hostName in @("firestore.googleapis.com","www.googleapis.com")) {
  try {
    $c = New-Object System.Net.Sockets.TcpClient
    $iar = $c.BeginConnect($hostName,443,$null,$null)
    $ok = $iar.AsyncWaitHandle.WaitOne(4000,$false)
    if ($ok -and $c.Connected) { Log "   Utgående 443 -> $hostName : OK" }
    else { Log "   Utgående 443 -> $hostName : NÅDDE INTE (kolla brandvägg/proxy)" }
    $c.Close()
  } catch { Log "   Utgående 443 -> $hostName : fel ($($_.Exception.Message))" }
}
Log ""

# ---- bygg anslutningssträng (SQL- eller Windows-inloggning) ----------------
if ($User -ne "") {
  $sec = Read-Host "Lösenord för SQL-inloggningen '$User'" -AsSecureString
  $bstr = [Runtime.InteropServices.Marshal]::SecureStringToBSTR($sec)
  $pw   = [Runtime.InteropServices.Marshal]::PtrToStringAuto($bstr)
  [Runtime.InteropServices.Marshal]::ZeroFreeBSTR($bstr)
  $connStr = "Server=$Server;Database=$Database;User Id=$User;Password=$pw;" +
             "Encrypt=False;TrustServerCertificate=True;Connect Timeout=6;" +
             "Application Name=snogrupp-sond"
  $authNote = "SQL-inloggning som '$User'"
} else {
  $connStr = "Server=$Server;Database=$Database;Integrated Security=SSPI;" +
             "Encrypt=False;TrustServerCertificate=True;Connect Timeout=6;" +
             "Application Name=snogrupp-sond"
  $authNote = "Windows-inloggning ($env:USERNAME)"
}

# ---- hjälpfunktion: kör en SELECT och returnera en DataTable -----------------
function Invoke-Read([System.Data.SqlClient.SqlConnection]$conn, [string]$sql) {
  $cmd = $conn.CreateCommand()
  $cmd.CommandText = $sql
  $cmd.CommandTimeout = 15
  $da = New-Object System.Data.SqlClient.SqlDataAdapter $cmd
  $dt = New-Object System.Data.DataTable
  [void]$da.Fill($dt)
  return $dt
}

function Show-Table([System.Data.DataTable]$dt, [int]$maxCol = 4000) {
  if ($dt.Rows.Count -eq 0) { Log "   (inga rader)"; return }
  $cols = $dt.Columns | ForEach-Object { $_.ColumnName }
  Log ("   " + ($cols -join " | "))
  foreach ($r in $dt.Rows) {
    $vals = foreach ($c in $cols) {
      $v = "$($r[$c])"
      if ($v.Length -gt 60) { $v = $v.Substring(0,57) + "..." }
      $v
    }
    Log ("   " + ($vals -join " | "))
  }
}

$conn = New-Object System.Data.SqlClient.SqlConnection $connStr
try {
  $conn.Open()
  Log "ANSLUTNING OK ($authNote)."
  Log ""
} catch {
  Log "ANSLUTNING MISSLYCKADES ($authNote):"
  Log "   $($_.Exception.Message)"
  Log ""
  if ($User -eq "") {
    Log "Tips: kör med SQL-inloggning i stället, t.ex.:"
    Log "   .\db-sond.ps1 -User GSS_Login"
    Log "(du far da skriva losenordet - det hamtas ur styrsystemets installningar)."
  }
  $lines | Out-File -FilePath $report -Encoding utf8
  Write-Host ""
  Write-Host "Rapport (med felet) sparad: $report"
  exit 1
}

# =================== 1. Version och grunduppgifter ===========================
Log "1. SERVER OCH VERSION"
Log "---------------------"
try {
  $dt = Invoke-Read $conn "SELECT @@VERSION AS v, SERVERPROPERTY('InstanceDefaultDataPath') AS datapath, DB_NAME() AS db"
  foreach ($r in $dt.Rows) {
    Log ("   " + ($r["v"] -replace "`r?`n"," "))
    Log ("   Datafiler: " + $r["datapath"])
    Log ("   Ansluten databas: " + $r["db"])
  }
} catch { Log "   FEL: $($_.Exception.Message)" }
Log ""

# =================== 2. Nätverk (TCP/IP och port) ============================
# Avgörande för bryggan: lyssnar servern på TCP och i så fall på vilken port?
Log "2. NÄTVERKSPROTOKOLL (för bryggan senare)"
Log "-----------------------------------------"
try {
  $dt = Invoke-Read $conn @"
SELECT registry_key, value_name, value_data
FROM sys.dm_server_registry
WHERE registry_key LIKE '%SuperSocketNetLib%Tcp%'
  AND value_name IN ('Enabled','TcpPort','TcpDynamicPorts')
ORDER BY registry_key, value_name
"@
  Show-Table $dt
} catch { Log "   Kunde inte läsa (kräver VIEW SERVER STATE): $($_.Exception.Message)" }
Log ""

# =================== 3. Inloggningar och roller =============================
# För att planera ett eget läs-only-konto (db_datareader) i stället för det
# hårdkodade GSS_Login.
Log "3. INLOGGNINGAR OCH MINA RÄTTIGHETER"
Log "------------------------------------"
try {
  $dt = Invoke-Read $conn @"
SELECT name, type_desc, is_disabled
FROM sys.server_principals
WHERE type IN ('S','U','G') AND name NOT LIKE '##%'
ORDER BY type_desc, name
"@
  Show-Table $dt
} catch { Log "   FEL: $($_.Exception.Message)" }
try {
  $dt = Invoke-Read $conn @"
SELECT SUSER_SNAME() AS inloggad_som,
       IS_SRVROLEMEMBER('sysadmin') AS ar_sysadmin,
       IS_MEMBER('db_datareader') AS kan_lasa_allt,
       IS_MEMBER('db_owner') AS ar_db_owner
"@
  Show-Table $dt
} catch { Log "   FEL: $($_.Exception.Message)" }
Log ""

# =================== 4. Alla tabeller med radantal ==========================
# Radantal ur sys.partitions - ögonblickligt, skannar ingenting.
Log "4. TABELLER OCH RADANTAL (störst först)"
Log "--------------------------------------"
try {
  $dt = Invoke-Read $conn @"
SELECT s.name AS sch, t.name AS tabell, SUM(p.rows) AS rader
FROM sys.tables t
JOIN sys.schemas s   ON t.schema_id = s.schema_id
JOIN sys.partitions p ON p.object_id = t.object_id AND p.index_id IN (0,1)
GROUP BY s.name, t.name
ORDER BY SUM(p.rows) DESC, t.name
"@
  Show-Table $dt
} catch { Log "   FEL: $($_.Exception.Message)" }
Log ""

# =================== 5. Kolumner för nyckeltabellerna =======================
# De tabeller granskningen pekade ut. De numrerade kolumnerna i SGC*_Main är
# det vi behöver mappa mot kontrollrumsskärmen.
$nyckel = @("stat_piste_canon_y","alarms_techno","TH_Main","Wind_Main","SGC300_Main","SGC400_Main")
Log "5. KOLUMNER I NYCKELTABELLERNA"
Log "------------------------------"
foreach ($tbl in $nyckel) {
  Log "  [$tbl]"
  try {
    $dt = Invoke-Read $conn @"
SELECT c.column_id AS nr, c.name AS kolumn, ty.name AS typ,
       c.max_length AS bredd, c.is_nullable AS kan_vara_null
FROM sys.columns c
JOIN sys.types ty ON c.user_type_id = ty.user_type_id
WHERE c.object_id = OBJECT_ID('$tbl')
ORDER BY c.column_id
"@
    if ($dt.Rows.Count -eq 0) { Log "   (tabellen finns inte eller saknar åtkomst)" }
    else { Show-Table $dt }
  } catch { Log "   FEL: $($_.Exception.Message)" }
  Log ""
}

# =================== 6. Smakprov ur nulägestabellerna =======================
# TOP 5 WITH (NOLOCK) ur de små, aktuella tabellerna. Hjälper att se hur ett
# "nu-värde" ser ut, och att mappa de numrerade kolumnerna mot skärmen.
Log "6. SMAKPROV - TOP 5 RADER (WITH NOLOCK)"
Log "--------------------------------------"
foreach ($tbl in $nyckel) {
  Log "  [$tbl]"
  try {
    $dt = Invoke-Read $conn "SELECT TOP 5 * FROM [$tbl] WITH (NOLOCK)"
    Show-Table $dt
  } catch { Log "   (hoppar över: $($_.Exception.Message))" }
  Log ""
}

$conn.Close()

Log "============================================================"
Log " KLART. Inget skrevs till databasen."
Log " Ta med den här filen tillbaka:"
Log "   $report"
Log "============================================================"

$lines | Out-File -FilePath $report -Encoding utf8
Write-Host ""
Write-Host "Rapport sparad: $report"
Write-Host "Det är den filen du tar med hem (lägg på Drive igen eller på ett USB-minne)."
exit 0
