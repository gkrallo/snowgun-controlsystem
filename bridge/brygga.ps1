<#
  BRYGGAN - läser nuläget ur styrsystemets databas och skickar det utåt.

  Version 0 (15 november 2026). Skriven efter sondrapporten samma dag.
  ALDRIG KÖRD mot den riktiga SQL-servern - första körningen ska vara
  torrläget nedan, med någon som tittar på.

  Vad den gör:   bara SELECT, var 20:e sekund, mot Live_Snowstar och
                 Live_event_SQL. Skriver resultatet till en fil (torrläge)
                 eller till Firebase (-Skicka).
  Vad den ALDRIG gör: skriver till SQL, öppnar en port, tar emot något
                 utifrån, startar eller stoppar något i anläggningen.

  Så här körs den:
    Torrläge, en läsning:     .\brygga.ps1 -EnGang
    Torrläge, tills Ctrl+C:   .\brygga.ps1
    Med alla råkolumner:      .\brygga.ps1 -EnGang -Ra
    Uttag per dygn (dammen):  .\brygga.ps1 -Uttag -Fran 2026-10-25
    Spara lösenord (DPAPI):   .\brygga.ps1 -SparaLosen sql      (eller: moln)
    Skicka till Firebase:     .\brygga.ps1 -Skicka

  Filen ska vara sparad som UTF-8 MED BOM (Windows PowerShell 5.1 läser den
  annars som ANSI och å, ä, ö blir fel) och får inte innehålla typografiska
  streck eller citattecken.
#>
param(
  [string]$Server  = "127.0.0.1\SQLEXPRESS,1433",
  # Förvalet är läs-only-kontot. GSS_Login kan skriva i styrsystemets
  # databaser och tillåts därför bara för en enstaka läsning (se längre ner).
  [string]$SqlUser = "snogrupp_ro",
  [switch]$EnGang,
  [switch]$Ra,
  [switch]$Skicka,
  [switch]$Uttag,
  [string]$Fran = "",
  [string]$SparaLosen = "",
  [int]$Intervall = 20
)

$ErrorActionPreference = "Stop"
$here    = Split-Path -Parent $MyInvocation.MyCommand.Path
$outFile = Join-Path $here "brygga-live.json"
$logFile = Join-Path $here "brygga.log"
$cfgFile = Join-Path $here "brygga-config.json"
$VERSION = "0"

function Log([string]$msg) {
  $line = (Get-Date -Format "yyyy-MM-dd HH:mm:ss") + "  " + $msg
  Write-Host $line
  try {
    # Loggen får inte växa obegränsat på en dator som står på hela vintern.
    if ((Test-Path $logFile) -and ((Get-Item $logFile).Length -gt 2MB)) {
      Move-Item $logFile ($logFile + ".1") -Force
    }
    Add-Content -Path $logFile -Value $line -Encoding UTF8
  } catch { }
}

# ---------------------------------------------------------------- lösenord
# Lösenorden sparas krypterade med Windows DPAPI: filen går bara att läsa av
# samma Windows-konto på samma dator. Aldrig i klartext, aldrig i git.
function SecretPath([string]$name) { Join-Path $here ("brygga-hemligt-" + $name + ".txt") }

function Get-Secret([string]$name, [string]$prompt) {
  $p = SecretPath $name
  if (Test-Path $p) { return (Get-Content $p | ConvertTo-SecureString) }
  return (Read-Host -AsSecureString $prompt)
}

function Plain([System.Security.SecureString]$s) {
  $b = [Runtime.InteropServices.Marshal]::SecureStringToBSTR($s)
  try { return [Runtime.InteropServices.Marshal]::PtrToStringBSTR($b) }
  finally { [Runtime.InteropServices.Marshal]::ZeroFreeBSTR($b) }
}

if ($SparaLosen -ne "") {
  if (@("sql", "moln") -notcontains $SparaLosen) { Write-Host "Ange sql eller moln."; exit 1 }
  $s = Read-Host -AsSecureString ("Lösenord för " + $SparaLosen)
  $s | ConvertFrom-SecureString | Set-Content -Path (SecretPath $SparaLosen) -Encoding ASCII
  Write-Host ("Sparat krypterat i " + (SecretPath $SparaLosen))
  exit 0
}

# ------------------------------------------------- spärr mot skrivande konto
# Överenskommet 15 november: GSS_Login får användas för att prova, men inte i
# något som går dygnet runt. Därför bara -EnGang eller -Uttag med det kontot.
$writerAccount = ($SqlUser -match '^(GSS_Login|sa)$')
if ($writerAccount -and -not ($EnGang -or $Uttag)) {
  Write-Host ("Kontot " + $SqlUser + " kan skriva i styrsystemets databaser.")
  Write-Host "Det får bara användas för en enstaka läsning: lägg till -EnGang."
  Write-Host "För drift behövs läs-only-kontot (probe\skapa-lasonly-konto.sql)."
  exit 1
}
if ($writerAccount -and $Skicka) {
  Write-Host "Med ett skrivande konto skickas inget till molnet. Ta bort -Skicka."
  exit 1
}

# --------------------------------------------------------------------- SQL
$script:conn = $null

function Open-Sql {
  $pw = Get-Secret "sql" ("SQL-lösenord för " + $SqlUser)
  $b = New-Object System.Data.SqlClient.SqlConnectionStringBuilder
  $b["Data Source"]      = $Server
  $b["Initial Catalog"]  = "Live_Snowstar"
  $b["User ID"]          = $SqlUser
  $b["Password"]         = (Plain $pw)
  $b["Connect Timeout"]  = 10
  $b["Application Name"] = "snogrupp-brygga"
  $c = New-Object System.Data.SqlClient.SqlConnection($b.ConnectionString)
  $c.Open()
  # Läs utan att ta lås, vänta högst tre sekunder på andras lås, och låt
  # styrsystemet vinna om två frågor någonsin skulle fastna i varandra.
  $cmd = $c.CreateCommand()
  $cmd.CommandText = "SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED; SET LOCK_TIMEOUT 3000; SET DEADLOCK_PRIORITY LOW;"
  [void]$cmd.ExecuteNonQuery()
  $script:conn = $c
}

function Close-Sql {
  if ($script:conn) { try { $script:conn.Close() } catch { } }
  $script:conn = $null
}

# All SQL går genom den här funktionen. Den vägrar allt som inte är en ren
# SELECT - ett extra skydd utöver läs-only-kontot, så att ett framtida
# misstag i koden inte kan bli en skrivning.
function Read-Sql([string]$sql, [hashtable]$params = @{}) {
  $t = $sql.Trim()
  if ($t -notmatch '^(?i)SELECT\s') { throw "Bara SELECT är tillåtet: $t" }
  if ($t -match '(?i)\b(INSERT|UPDATE|DELETE|MERGE|DROP|ALTER|CREATE|TRUNCATE|EXEC|EXECUTE|GRANT|DBCC|INTO)\b' -or $t.Contains(";")) {
    throw "Frågan innehåller något annat än läsning: $t"
  }
  $cmd = $script:conn.CreateCommand()
  $cmd.CommandText = $t
  $cmd.CommandTimeout = 10
  foreach ($k in $params.Keys) { [void]$cmd.Parameters.AddWithValue("@" + $k, $params[$k]) }
  $dt = New-Object System.Data.DataTable
  $da = New-Object System.Data.SqlClient.SqlDataAdapter($cmd)
  [void]$da.Fill($dt)
  return ,$dt
}

# ------------------------------------------------------------- hjälpare
# Ett värde ur en rad, städat för JSON: NULL blir $null, flyttal avrundas
# (databasen har "real", som annars blir 7.69999981), datum blir text.
function V($row, [string]$col) {
  if (-not $row.Table.Columns.Contains($col)) { return $null }
  $v = $row[$col]
  if ($v -is [System.DBNull]) { return $null }
  if ($v -is [single] -or $v -is [double]) { return [math]::Round([double]$v, 2) }
  if ($v -is [datetime]) { return $v.ToString("yyyy-MM-ddTHH:mm:ss") }
  if ($v -is [string]) { return $v.Trim() }
  return $v
}

# Hela raden, för att jämföra mot kontrollrumsskärmen (-Ra). Nollor och tomma
# fält hoppas över, annars drunknar de intressanta värdena.
function RawRow($row) {
  $o = [ordered]@{}
  foreach ($c in $row.Table.Columns) {
    $v = V $row $c.ColumnName
    if ($null -eq $v -or "$v" -eq "0" -or "$v" -eq "") { continue }
    $o["k" + $c.ColumnName] = $v
  }
  return $o
}

# ---------------------------------------------------------------- läsning
# KOLUMNERNA. "säker" = stämde mot skärmbilden 15 nov eller mot
# statistiktabellernas namn. "osäker" = gissning som måste kontrolleras när
# anläggningen går. Se docs\kolumnmappning.md.
function Read-Snapshot {
  $snap = [ordered]@{}

  # --- pumphuset: en rad per avgång (11 = lågtryck P1, 12 = högtryck P2)
  $pump = [ordered]@{}
  $dt = Read-Sql "SELECT * FROM [Water departure_Com] WITH (NOLOCK)"
  foreach ($r in $dt.Rows) {
    $p = [ordered]@{
      tryckIn    = V $r "121"   # bar, säker (PT01 0,1)
      vattenTemp = V $r "122"   # grader, säker (TT01 11,8)
      tryckUt    = V $r "123"   # bar, säker (PT02 7,2)
      # 125 och 126 var båda 0,1 med stillastående anläggning. Den ena är
      # uppmätt flöde (FT01), den andra oklar. Båda skickas tills vi vet.
      k125       = V $r "125"   # osäker
      k126       = V $r "126"   # osäker
      maxFlode   = V $r "128"   # m3/h, säker (70)
      uppdaterad = V $r "DateUpd"
    }
    if ($Ra) { $p["ra"] = RawRow $r }
    $pump["dep" + (V $r "0")] = $p
  }
  $snap["pump"] = $pump

  # --- ledningarna: tryck per ledning
  $lines = [ordered]@{}
  $dt = Read-Sql "SELECT * FROM [Line_Com] WITH (NOLOCK)"
  foreach ($r in $dt.Rows) {
    $l = [ordered]@{
      tryck      = V $r "60"    # bar, säker (PT03 7,7 och PT04 7,3)
      uppdaterad = V $r "DateUpd"
    }
    if ($Ra) { $l["ra"] = RawRow $r }
    $lines["L" + (V $r "0")] = $l
  }
  $snap["ledningar"] = $lines

  # --- kanoner och lansar på SGC400 (n 1,2,3,6,7 fläkt, n 4,5 lans)
  $units = [ordered]@{}
  $dt = Read-Sql "SELECT * FROM [SGC400_Com] WITH (NOLOCK)"
  foreach ($r in $dt.Rows) {
    $u = [ordered]@{
      nr          = V $r "3"
      typ         = V $r "801"  # säker: S ACCESS 300 eller TAURUS_2.0
      t           = V $r "400"  # säker
      rh          = V $r "401"  # säker
      tw          = V $r "402"  # säker (våttemperatur)
      flodeTeori  = V $r "411"  # säker: statistikens debit_eau_theorique / 10
      # Uppmätt flöde och driftläge är inte hittade än - anläggningen stod
      # still. Kör med -Ra när något går och jämför med skärmen.
      k408        = V $r "408"  # osäker (8-15, kan vara vattentemp eller tryck)
      k415        = V $r "415"  # osäker (2 eller 11, kan vara läge)
      senastHord  = V $r "850"  # säker: senaste kontakt med kanonen
      uppdaterad  = V $r "DateUpd"
    }
    if ($Ra) { $u["ra"] = RawRow $r }
    $units["SGC400-" + (V $r "3")] = $u
  }
  # --- fläktkanoner på SGC300 (n 2 har varit tyst sedan 2022)
  $dt = Read-Sql "SELECT * FROM [SGC300_Com] WITH (NOLOCK)"
  $i = 0
  foreach ($r in $dt.Rows) {
    $i++
    $u = [ordered]@{
      typ        = V $r "94"
      t          = V $r "2"     # säker
      rh         = V $r "3"     # säker
      tw         = V $r "7"     # säker
      senastHord = V $r "104"
      uppdaterad = V $r "DateUpd"
    }
    if ($Ra) { $u["ra"] = RawRow $r }
    # SGC300_Com har ingen egen nummerkolumn; kolumn 88 är 1 respektive 2.
    $n = V $r "88"; if ($null -eq $n) { $n = $i }
    $units["SGC300-" + $n] = $u
  }
  $snap["enheter"] = $units

  # --- väderstationen vid brunn 7 (givare 1). Kanonernas egna givare
  # (1001-1009) finns redan under enheter.
  $dt = Read-Sql "SELECT * FROM [TH_Com] WITH (NOLOCK) WHERE [10] = 1"
  foreach ($r in $dt.Rows) {
    $snap["vader"] = [ordered]@{
      t = V $r "4"; rh = V $r "5"; tw = V $r "6"; uppdaterad = V $r "DateUpd"
    }
  }
  # Vinden skickas med men ska inte användas i appen: stationens vindmätare
  # är inte tillförlitlig, vinden tas alltid från prognosen.
  $dt = Read-Sql "SELECT * FROM [Wind_Com] WITH (NOLOCK)"
  foreach ($r in $dt.Rows) {
    $snap["vindStation"] = [ordered]@{ fart = V $r "4"; riktning = V $r "5"; uppdaterad = V $r "DateUpd" }
  }

  # --- aktiva larm och de tio senaste händelserna
  $alarms = @()
  $dt = Read-Sql "SELECT [date],[machine],[nom],[message],[ID] FROM [Live_event_SQL].[dbo].[defaut_actif] WITH (NOLOCK) WHERE [def_actif] = 1"
  foreach ($r in $dt.Rows) {
    $alarms += [ordered]@{ sedan = V $r "date"; maskin = V $r "machine"; namn = V $r "nom"; text = V $r "message"; id = V $r "ID" }
  }
  $snap["larm"] = $alarms

  $events = @()
  $dt = Read-Sql "SELECT TOP 10 [date],[machine],[nom],[message] FROM [Live_event_SQL].[dbo].[Journal] WITH (NOLOCK) ORDER BY [date] DESC"
  foreach ($r in $dt.Rows) {
    $events += [ordered]@{ tid = V $r "date"; maskin = V $r "machine"; namn = V $r "nom"; text = V $r "message" }
  }
  $snap["handelser"] = $events

  return $snap
}

# ------------------------------------------------- uttag per dygn (dammen)
# Engångsfråga: hur mycket vatten har pumphuset tagit per dygn? Svarar på om
# provkörningarna förklarar skillnaden i docs\damm-matningar.md.
if ($Uttag) {
  $from = (Get-Date).AddDays(-30)
  if ($Fran -ne "") { $from = [datetime]::ParseExact($Fran, "yyyy-MM-dd", $null) }
  try {
    Open-Sql
    $dt = Read-Sql "SELECT [Num],[date_update],[Duree_fct],[Duree_defaut],[Volume_eau] FROM [Live_stat_SQL_rapport].[dbo].[Rapport_Depart_eau_24h] WITH (NOLOCK) WHERE [date_update] >= @from ORDER BY [date_update],[Num]" @{ from = $from }
    $out = New-Object System.Collections.Generic.List[string]
    $out.Add("Uttag per dygn fran " + $from.ToString("yyyy-MM-dd") + " (Rapport_Depart_eau_24h)")
    $out.Add("avgang | dygn som slutar | drifttid | feltid | volym")
    foreach ($r in $dt.Rows) {
      $out.Add(("{0} | {1} | {2} | {3} | {4}" -f (V $r "Num"), (V $r "date_update"), (V $r "Duree_fct"), (V $r "Duree_defaut"), (V $r "Volume_eau")))
    }
    $out.Add("")
    $dt = Read-Sql "SELECT * FROM [Live_stat_SQL].[dbo].[bilan_param_depart_eau] WITH (NOLOCK)"
    $out.Add("Sasongssummor (bilan_param_depart_eau):")
    foreach ($r in $dt.Rows) { $out.Add((RawRow $r | ConvertTo-Json -Compress)) }
    $f = Join-Path $here ("uttag_" + (Get-Date -Format "yyyyMMdd-HHmmss") + ".txt")
    $out | Set-Content -Path $f -Encoding UTF8
    $out | ForEach-Object { Write-Host $_ }
    Write-Host ""
    Write-Host ("Sparat i " + $f)
  } finally { Close-Sql }
  exit 0
}

# -------------------------------------------------------------- Firebase
# OPROVAT: databasen i Firebase finns inte än och reglerna är inte körda.
# Bryggan loggar in som ett eget konto (e-post + lösenord), inte med en
# servicekonto-nyckel - en sådan ger full makt över hela projektet.
$script:token = $null
$script:tokenAt = [datetime]::MinValue
$cfg = $null

function Send-Json([string]$method, [string]$url, [string]$json) {
  # Kroppen skickas som UTF-8-byte. Windows PowerShell 5.1 kodar annars en
  # textsträng som Latin-1, och å, ä, ö i larmtexter blir fel i molnet.
  $bytes = [System.Text.Encoding]::UTF8.GetBytes($json)
  return Invoke-RestMethod -Method $method -Uri $url -Body $bytes -ContentType "application/json; charset=utf-8" -TimeoutSec 15
}

function Get-Token {
  # Inloggningen gäller en timme; förnya efter 50 minuter.
  if ($script:token -and ((Get-Date) - $script:tokenAt).TotalMinutes -lt 50) { return $script:token }
  $pw = Get-Secret "moln" "Lösenord för bryggans Firebase-konto"
  $body = @{ email = $cfg.email; password = (Plain $pw); returnSecureToken = $true } | ConvertTo-Json -Compress
  $r = Send-Json "Post" ("https://identitytoolkit.googleapis.com/v1/accounts:signInWithPassword?key=" + $cfg.apiKey) $body
  $script:token = $r.idToken
  $script:tokenAt = Get-Date
  return $script:token
}

function Send-Live($snap) {
  $tok = Get-Token
  $json = $snap | ConvertTo-Json -Depth 8 -Compress
  [void](Send-Json "Put" ($cfg.dbUrl.TrimEnd("/") + "/live.json?auth=" + $tok) $json)
}

if ($Skicka) {
  if (-not (Test-Path $cfgFile)) {
    Write-Host ("Saknar " + $cfgFile + ". Kopiera brygga-config.exempel.json och fyll i.")
    exit 1
  }
  $cfg = Get-Content $cfgFile -Raw -Encoding UTF8 | ConvertFrom-Json
  # Styrdatorn är Windows 10; TLS 1.2 måste slås på uttryckligen i 5.1.
  [Net.ServicePointManager]::SecurityProtocol = 3072
}

# ------------------------------------------------------------------ slinga
Log ("Bryggan startar (version " + $VERSION + ", konto " + $SqlUser + ", " + $(if ($Skicka) { "skickar till molnet" } else { "torrläge" }) + ")")
$fails = 0
while ($true) {
  $t0 = Get-Date
  $snap = $null
  try {
    if (-not $script:conn -or $script:conn.State -ne "Open") { Close-Sql; Open-Sql }
    $snap = Read-Snapshot
    $fails = 0
  } catch {
    $fails++
    Log ("SQL-fel: " + $_.Exception.Message)
    Close-Sql
    # Databasen svarar inte: skicka ändå ett hjärtslag som säger det, så att
    # appen kan skilja "bryggan död" från "styrdatorn nås men SQL svarar inte".
    $snap = [ordered]@{}
  }
  $ms = [int]((Get-Date) - $t0).TotalMilliseconds
  # Hjärtslaget stämplas med molnets klocka, så att gammal data märks även om
  # styrdatorns klocka går fel eller hoppar natten till sommartid.
  $snap["meta"] = [ordered]@{
    ts      = @{ ".sv" = "timestamp" }
    lokalTid = (Get-Date).ToString("yyyy-MM-ddTHH:mm:ss")
    sqlOk   = ($fails -eq 0)
    lasMs   = $ms
    version = $VERSION
  }
  try {
    if ($Skicka) { Send-Live $snap }
    else { ($snap | ConvertTo-Json -Depth 8) | Set-Content -Path $outFile -Encoding UTF8 }
    if ($EnGang) { Log ("Klart på " + $ms + " ms. Resultatet ligger i " + $outFile) }
  } catch {
    Log ("Kunde inte lämna ifrån mig datan: " + $_.Exception.Message)
    $script:token = $null
  }
  if ($EnGang) { break }
  # Vid upprepade fel (till exempel minnesbrist i SQL Server som julafton
  # 2022) backar bryggan till en läsning i minuten, så att den inte gör ont
  # värre för styrsystemet.
  $wait = $Intervall
  if ($fails -ge 3) { $wait = 60 }
  Start-Sleep -Seconds $wait
}
Close-Sql
if ($fails -gt 0) { exit 1 }
