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
    Vattnet före version 8:   .\brygga.ps1 -Bakat   (en gång, bryggan stoppad)
    Rätta brunnsdelen:        .\brygga.ps1 -BakatBrunn   (en gång, efter -Bakat)
    Spara lösenord (DPAPI):   .\brygga.ps1 -SparaLosen sql      (eller: moln)
    Skicka till Firebase:     .\brygga.ps1 -Skicka
    Prova ändringslogiken:    .\brygga.ps1 -Sjalvtest   (ingen databas behövs)
    Prova molnet:             .\brygga.ps1 -ProvaMoln   (ingen databas behövs)
    Avsteg, se README:        .\brygga.ps1 -Skicka -SqlUser GSS_Login -AvstegSkrivkonto

  Till molnet går bara det som ändrats sedan sist (med dödband), ett
  hjärtslag i minuten och en historikpunkt var femte minut. Datorn står på
  dygnet runt, och värdena står still det mesta av året. Historiken sparas
  hela säsongen (sedan version 4); förut rensades den efter 48 timmar.
  Sedan version 5 har den också varje hörd enhets luft- och våttemperatur.
  Sedan version 6 skickas brunnen varje enhet står vid.
  Sedan version 7 skickas flöde och tryck per enhet, och historiken har
  varje hörd enhets flöde och summan av dem (flodeSum).
  Sedan version 8 räknas vattnet per enhet sedan den kom till brunnen och
  för säsongen (snömängden = vatten x 2,2 räknas i appen).
  Version 9 kan fylla på räkneverken bakåt ur styrsystemets statistik
  (-Bakat, en gång). Version 10 rättar brunnsdelen av det (-BakatBrunn):
  journalfrågan i version 9 hittade inga inkopplingar, så alla kanoner
  räknades som vid sin brunn sedan 1 augusti.
  Version 11 räknar kanonernas vatten timme för timme ur statistiken och
  skickar det till /vattenTimme, så att appen kan räkna dammens uttag.
  Version 12 minns vattentemperaturen i pumphuset (TT01) från senast vattnet
  gick, och skickar den bredvid: pump/dep12/vattenTempDrift och -Tid. Den
  skickar också varje enhets snökvalitet och startgräns (och stoppgräns på
  SGC400), ur Sufags kolumnbeskrivningar.

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
  [switch]$Bakat,
  [switch]$BakatBrunn,
  [string]$Fran = "",
  [string]$SparaLosen = "",
  [switch]$Sjalvtest,
  [switch]$ProvaMoln,
  [switch]$AvstegSkrivkonto,
  [int]$Intervall = 20
)

$ErrorActionPreference = "Stop"
$here    = Split-Path -Parent $MyInvocation.MyCommand.Path
$outFile = Join-Path $here "brygga-live.json"
$logFile = Join-Path $here "brygga.log"
$cfgFile = Join-Path $here "brygga-config.json"
$stateFile = Join-Path $here "brygga-state.json"
$VERSION = "12"

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
#
# AVSTEG 16 november (Kristians beslut): leverantören har inte svarat om sa,
# och utan sa går läs-only-kontot inte att skapa. Tills det finns får bryggan
# gå med GSS_Login - men bara om det sägs uttryckligen med -AvstegSkrivkonto.
# Avsteget loggas vid varje start och följer med i hjärtslaget
# (meta/skrivkonto), så att det syns och inte blir kvar av glömska.
# Skyddet är då bara koden: Read-Sql släpper inte igenom annat än SELECT.
# sa är aldrig tillåtet i drift - det kontot kan göra allt på servern.
$writerAccount = ($SqlUser -match '^(GSS_Login|sa)$')
$avsteg = ($AvstegSkrivkonto -and $SqlUser -eq 'GSS_Login')
if ($AvstegSkrivkonto -and -not $avsteg) {
  Write-Host "-AvstegSkrivkonto gäller bara tillsammans med -SqlUser GSS_Login."
  exit 1
}
if ($writerAccount -and -not ($EnGang -or $Uttag -or $Bakat -or $BakatBrunn -or $avsteg)) {
  Write-Host ("Kontot " + $SqlUser + " kan skriva i styrsystemets databaser.")
  Write-Host "Det får bara användas för en enstaka läsning: lägg till -EnGang."
  Write-Host "För drift behövs läs-only-kontot (probe\skapa-lasonly-konto.sql),"
  Write-Host "eller det uttalade avsteget -AvstegSkrivkonto (se README)."
  exit 1
}
if ($writerAccount -and $Skicka -and -not $avsteg) {
  Write-Host "Med ett skrivande konto skickas inget till molnet. Ta bort -Skicka,"
  Write-Host "eller lägg till det uttalade avsteget -AvstegSkrivkonto (se README)."
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

# Lamporna på skärmen (ringar, kompressor, hydrant ...) ligger i SGC400 som
# bitmönster i teckenkolumner ("0001110000100011"). De skickas som en kort
# text med de bitar som är tända, "453:0,1,5;454:0,4" - bit 0 är tecknet
# längst till höger. Vilken bit som är vilken lampa är inte utrett; texten
# gör att det kan läsas ut över tid mot skärmbilder (version 7).
function Bits($row, [string[]]$cols) {
  $parts = @()
  foreach ($c in $cols) {
    $s = V $row $c
    if (-not $s -or $s -notmatch '^[01]+$') { continue }
    $on = @()
    for ($i = 0; $i -lt $s.Length; $i++) { if ($s[$s.Length - 1 - $i] -eq '1') { $on += $i } }
    if ($on.Count -gt 0) { $parts += ($c + ":" + ($on -join ",")) }
  }
  return ($parts -join ";")
}

# Det äldre kortet har en kolumn per lampa (25-81, heltal) i stället för
# bitar. Samma slags text: "25,37,42" för ettor, "65=3" för andra värden.
function Flags($row, [int[]]$cols) {
  $parts = @()
  foreach ($c in $cols) {
    $v = V $row ("" + $c)
    if ($null -eq $v -or -not (IsNum $v) -or $v -eq 0) { continue }
    if ($v -eq 1) { $parts += ("" + $c) } else { $parts += ("" + $c + "=" + $v) }
  }
  return ($parts -join ",")
}

# ------------------------------------------------------ bara ändringar
# Nuläget plattas ut till "sökväg -> värde" (enheter/SGC400-3/tw -> -4.1) och
# jämförs med det som senast SKICKADES - inte det som senast lästes. Annars
# kan ett värde krypa en tiondel i taget hur långt som helst utan att någon
# enskild ändring når över dödbandet.

# Larm och händelser skickas som en klump när något i dem ändras.
$BLOBS = @("larm", "handelser")
# "uppdaterad" ändras var 20:e sekund även när inget händer och skulle göra
# hela idén meningslös. I stället skickas den senaste tiden en gång i minuten
# med hjärtslaget (meta/gssTid). "ra" är bara till för torrläget.
$SKIP = @("uppdaterad", "ra")

function Flatten($node, [string]$prefix, [hashtable]$out) {
  foreach ($k in @($node.Keys)) {
    if ($SKIP -contains $k) { continue }
    $p = "$k"; if ($prefix -ne "") { $p = $prefix + "/" + $k }
    $v = $node[$k]
    if (($BLOBS -notcontains $p) -and ($v -is [System.Collections.IDictionary])) { Flatten $v $p $out }
    else { $out[$p] = $v }
  }
}

# Samma träd utan de överhoppade fälten, för den fullständiga sändningen.
function Strip($node) {
  $o = [ordered]@{}
  foreach ($k in @($node.Keys)) {
    if ($SKIP -contains $k) { continue }
    $v = $node[$k]
    if ($v -is [System.Collections.IDictionary]) { $o[$k] = Strip $v } else { $o[$k] = $v }
  }
  return $o
}

# Senaste "uppdaterad" i hela nuläget: visar att GSSystem självt lever.
function Newest($node) {
  $best = ""
  foreach ($k in @($node.Keys)) {
    $v = $node[$k]
    if ($k -eq "uppdaterad" -and $v) { if ("$v" -gt $best) { $best = "$v" } }
    elseif ($v -is [System.Collections.IDictionary]) { $b = Newest $v; if ($b -gt $best) { $best = $b } }
  }
  return $best
}

# Dödband per fält. Givarna flimrar en tiondel fram och tillbaka; utan
# dödband skulle varje flimmer bli en sändning.
function Band([string]$path) {
  $f = $path.Substring($path.LastIndexOf("/") + 1)
  if ($f -match '^(t|tw|vattenTemp|vattenTempDrift)$') { return 0.2 }
  if ($f -eq 'rh')                                  { return 2 }
  if ($f -match '^(tryck|tryckIn|tryckUt|tryckBor)$') { return 0.2 }
  if ($f -match '^(k125|k126|k408|flodeTeori|flode)$') { return 0.2 }
  if ($f -eq 'fart')                                { return 0.5 }
  # Räkneverken växer hela tiden kanonen går; utan dödband skulle de
  # skickas var 20:e sekund. Halv kubik vatten är några minuters körning.
  if ($f -eq 'vattenBrunn')                         { return 0.5 }
  if ($f -eq 'vattenSasong')                        { return 1 }
  if ($f -eq 'riktning')                            { return 15 }
  return 0
}

function IsNum($v) { return ($v -is [ValueType]) -and ($v -isnot [bool]) -and ($v -isnot [datetime]) }

function Sig($v) {
  if ($null -eq $v) { return "null" }
  if ($v -is [string]) { return $v }
  return (ConvertTo-Json -InputObject $v -Compress -Depth 6)
}

function IsDifferent([string]$path, $new, $old) {
  if ($null -eq $new -and $null -eq $old) { return $false }
  if ($null -eq $new -or $null -eq $old) { return $true }
  if ((IsNum $new) -and (IsNum $old)) {
    $band = Band $path
    $d = [math]::Abs([double]$new - [double]$old)
    if ($band -gt 0) { return ($d -ge ($band - 1e-9)) }
    return ($d -gt 1e-9)
  }
  return ((Sig $new) -cne (Sig $old))
}

# Ändringarna som en lista "sökväg -> nytt värde". Ett fält som försvunnit
# får värdet $null, vilket tar bort det i molnet.
function Get-Changes([hashtable]$now, [hashtable]$sent) {
  $ch = [ordered]@{}
  foreach ($k in ($now.Keys | Sort-Object)) {
    if (-not $sent.ContainsKey($k)) { $ch[$k] = $now[$k] }
    elseif (IsDifferent $k $now[$k] $sent[$k]) { $ch[$k] = $now[$k] }
  }
  foreach ($k in (@($sent.Keys) | Sort-Object)) {
    if (-not $now.ContainsKey($k)) { $ch[$k] = $null }
  }
  return $ch
}

# Historiknycklar: UTC på jämna fem minuter, så att natten då klockan ställs
# om inte ger två punkter med samma namn.
function SlotKey([datetime]$utc) { return $utc.ToString("yyyyMMddHHmm") }
function SlotOf([datetime]$utc) {
  return (New-Object datetime($utc.Year, $utc.Month, $utc.Day, $utc.Hour, ($utc.Minute - ($utc.Minute % 5)), 0, [DateTimeKind]::Utc))
}

# Punkten för graferna. Historiken sparas hela säsongen och städas inte bort
# (version 4, 22 november 2026). Förut rensades allt äldre än 48 h, men en
# punkt är ungefär 90 byte och en säsong blir runt 4 MB - långt under
# Firebases gratisnivå. Det som kostar är att LÄSA, så appen hämtar bara det
# senaste dygnet (288 punkter) när den öppnas.
# ------------------------------------------------- vatten per brunn och säsong
# Snömängden per kanon (version 8, 26 november 2026). Styrsystemet räknar
# snö som vatten x 2,2, utan hänsyn till väder - det gör appen också, men
# bryggan summerar bara VATTNET, så att faktorn kan bytas när snöytan mätts
# med pucken. Två räkneverk per enhet:
#   vattenBrunn  - sedan enheten kom till den brunn den står vid nu. Flyttas
#                  den till en annan brunn börjar det om på noll, så kurvan
#                  blir en sågtand: en tand per delsträcka. En flytt på tio
#                  meter vid samma brunn märks inte (Kristian, 26 november).
#   vattenSasong - sedan 1 augusti, oavsett brunn.
# Bryggan läser var 20:e sekund och lägger till flöde x tid. Bara när enheten
# hörts nyss (2 min) och förra läsningen är högst 2 min gammal - efter ett
# avbrott räknas inget för tiden emellan, hellre för lite än påhittat.
# Räkneverken sparas i brygga-state.json och överlever en omstart.
$script:acc = @{}

function SeasonOf([datetime]$t) {
  $y = $t.Year; if ($t.Month -lt 8) { $y-- }
  return ("" + $y + "/" + (($y + 1) % 100).ToString("00"))
}

function Add-Water($snap, [datetime]$now) {
  if (-not $snap["enheter"]) { return }
  $ref = Newest $snap
  if (-not $ref) { return }
  $fmt = "yyyy-MM-ddTHH:mm:ss"
  $refT = [datetime]::ParseExact($ref, $fmt, $null)
  $season = SeasonOf $now
  foreach ($k in @($snap["enheter"].Keys)) {
    $u = $snap["enheter"][$k]
    $a = $script:acc[$k]
    if ($null -eq $a) {
      # fran = när bryggan började räkna enheten. -Bakat fyller på med
      # styrsystemets statistik för tiden före, och bara före.
      $a = @{ brunn = $u["brunn"]; sedan = $now.ToString($fmt); fran = $now.ToString($fmt); brunnM3 = 0.0; sasong = $season; sasongM3 = 0.0; last = $null }
      $script:acc[$k] = $a
    }
    if ($null -ne $u["brunn"] -and $a["brunn"] -ne $u["brunn"]) {
      $a["brunn"] = $u["brunn"]; $a["sedan"] = $now.ToString($fmt); $a["brunnM3"] = 0.0
    }
    if ($a["sasong"] -ne $season) { $a["sasong"] = $season; $a["sasongM3"] = 0.0 }
    $fresh = $false
    if ($u["senastHord"]) {
      try { $fresh = ([math]::Abs(($refT - [datetime]::ParseExact("" + $u["senastHord"], $fmt, $null)).TotalSeconds) -le 120) } catch { }
    }
    if ($fresh) {
      if ($null -ne $a["last"] -and (IsNum $u["flode"]) -and $u["flode"] -gt 0) {
        $dt = ($now - [datetime]$a["last"]).TotalSeconds
        if ($dt -gt 0 -and $dt -le 120) {
          $m3 = [double]$u["flode"] * $dt / 3600
          $a["brunnM3"] = [double]$a["brunnM3"] + $m3
          $a["sasongM3"] = [double]$a["sasongM3"] + $m3
        }
      }
      $a["last"] = $now
    } else { $a["last"] = $null }
    $u["vattenBrunn"] = [math]::Round([double]$a["brunnM3"], 2)
    $u["vattenSasong"] = [math]::Round([double]$a["sasongM3"], 1)
    $u["brunnSedan"] = $a["sedan"]
  }
}

# Räkneverken till och från tillståndsfilen ("last" sparas inte: efter en
# omstart räknas första varvet inte, eftersom tiden emellan är okänd).
function Acc-ToState {
  $o = [ordered]@{}
  foreach ($k in ($script:acc.Keys | Sort-Object)) {
    $a = $script:acc[$k]
    $o[$k] = [ordered]@{ brunn = $a["brunn"]; sedan = $a["sedan"]; fran = $a["fran"]; brunnM3 = [math]::Round([double]$a["brunnM3"], 4); sasong = $a["sasong"]; sasongM3 = [math]::Round([double]$a["sasongM3"], 4) }
  }
  return $o
}
function Acc-FromState($obj) {
  $script:acc = @{}
  if ($null -eq $obj) { return }
  foreach ($p in $obj.PSObject.Properties) {
    $v = $p.Value
    # Version 8 sparade inte "fran". Den började räkna alla enheter samtidigt
    # och ingen hann byta brunn, så "sedan" är samma tid.
    $fr = "" + $v.fran; if (-not $fr) { $fr = "" + $v.sedan }
    $script:acc[$p.Name] = @{ brunn = $v.brunn; sedan = "" + $v.sedan; fran = $fr; brunnM3 = [double]$v.brunnM3; sasong = "" + $v.sasong; sasongM3 = [double]$v.sasongM3; last = $null }
  }
}

# ---------------------------------------------- räkna bakåt (-Bakat, version 9)
# Vattnet innan bryggan började räkna, ur styrsystemets egen statistik:
# stat_piste_canon_SGC400/SGC300 har varje kanons "Real water flow" var tionde
# minut (debit_eau_reel x 10), hela säsongen. Brunnen tas ur journalens
# "Appeared S ACCESS 300 ( adr = 8) to 5": adress 8 kopplades in vid brunn 5.
# Den rena räkningen ligger här, utan databas, så att självtestet kan prova den.

# Adressen i journalen till bryggans namn: SGC400 har adress = n + 2, det
# äldre kortet adress = n (bara 1 och 2).
function KeyOfAdr([int]$adr) {
  if ($adr -le 2) { return ("SGC300-" + $adr) }
  return ("SGC400-" + ($adr - 2))
}

# Händelserna (tid, text) till inkopplingar: adress, brunn, tid.
function Parse-Appeared($events) {
  $out = @()
  foreach ($ev in $events) {
    if ("" + $ev.text -match 'Appeared.*adr\s*=\s*(\d+)\s*\)\s*to\s+(\d+)') {
      $out += [pscustomobject]@{ key = (KeyOfAdr ([int]$matches[1])); brunn = [int]$matches[2]; tid = [datetime]$ev.tid }
    }
  }
  return ($out | Sort-Object tid)
}

# När kom enheten till brunnen den står vid nu? Den sammanhängande följden av
# inkopplingar vid samma brunn bakåt från "fore": den första av dem. En
# inkoppling vid samma brunn igen (efter strömavbrott) börjar inte om.
# Ingen inkoppling alls under säsongen: den har stått där sedan säsongens
# början. Senaste inkopplingen till en ANNAN brunn: okänt, $null.
function Arrival($appeared, [string]$key, $brunn, [datetime]$fore, [datetime]$seasonStart) {
  $mine = @($appeared | Where-Object { $_.key -eq $key -and $_.tid -lt $fore } | Sort-Object tid)
  if ($mine.Count -eq 0) { return $seasonStart }
  if ($mine[-1].brunn -ne $brunn) { return $null }
  $a = $mine[-1].tid
  for ($i = $mine.Count - 2; $i -ge 0; $i--) {
    if ($mine[$i].brunn -ne $brunn) { break }
    $a = $mine[$i].tid
  }
  return $a
}

# Raderna (key, tid, debit = m3/h x 10, nxt = nästa rads tid) till tillägg
# per enhet. En rad gäller fram till nästa, högst 15 minuter (längre glapp är
# ett avbrott i statistiken, och då räknas inget - hellre för lite). Saknas
# nästa rad (sista raden i en halvmånadsdatabas) räknas raden inte.
function Backfill-Compute($acc, $rows, $appeared, [datetime]$seasonStart) {
  $res = [ordered]@{}
  $fmt = "yyyy-MM-ddTHH:mm:ss"
  foreach ($k in ($acc.Keys | Sort-Object)) {
    $a = $acc[$k]
    $fran = [datetime]::ParseExact($a["fran"], $fmt, $null)
    $arr = Arrival $appeared $k $a["brunn"] $fran $seasonStart
    $sas = 0.0; $br = 0.0
    foreach ($r in $rows) {
      if ($r.key -ne $k -or $r.tid -ge $fran -or $r.tid -lt $seasonStart -or $null -eq $r.nxt) { continue }
      $end = $r.nxt; if ($end -gt $fran) { $end = $fran }
      $h = ($end - $r.tid).TotalHours
      if ($h -le 0 -or $h -gt 0.25) { continue }
      $m3 = [double]$r.debit / 10 * $h
      $sas += $m3
      if ($null -ne $arr -and $r.tid -ge $arr) { $br += $m3 }
    }
    $res[$k] = [pscustomobject]@{ sasong = $sas; brunn = $br; ankomst = $arr }
  }
  return $res
}

# Lampornas bitar sparas i historiken bara när de ändrats sedan förra
# punkten (fältet b, version 7): de ändras sällan, och en text på 40 tecken
# per enhet och punkt skulle annars göra säsongen ett par gånger större. Det
# som behövs för att para ihop bitar med skärmen är just ögonblicken då något
# tänds eller släcks. Efter en omstart skrivs alla en gång till.
$script:lastBits = @{}

# TT01 sitter på det strömmande vattnet i pumphuset. När pumparna står visar
# den vattnet som står still i röret, och det värms eller kyls av pumphuset.
# Version 12 minns därför senaste värdet medan vattnet gick (FT01 minst
# 2 m3/h; den visar 0,1 när allt står) och skickar det bredvid det mätta.
# Tiden har minutupplösning, så att den inte blir en ändring var 20:e
# sekund. Värdet sparas i brygga-state.json och överlever en omstart.
$script:driftTemp = $null
$script:driftTid = $null
function Mark-DriftTemp($snap, [datetime]$now) {
  if (-not $snap["pump"]) { return }
  $d = $snap["pump"]["dep12"]
  if (-not $d) { return }
  $q = $d["k125"]; $vt = $d["vattenTemp"]
  if ((IsNum $q) -and (IsNum $vt) -and ([double]$q -ge 2)) {
    $script:driftTemp = [double]$vt
    $script:driftTid = $now.ToString("yyyy-MM-ddTHH:mm")
  }
  if ($null -ne $script:driftTemp) {
    $d["vattenTempDrift"] = $script:driftTemp
    $d["vattenTempDriftTid"] = $script:driftTid
  }
}

function Build-HistPatch($snap, [datetime]$slot) {
  $p = [ordered]@{}
  $pt = [ordered]@{ ts = @{ ".sv" = "timestamp" } }
  if ($snap["vader"]) { $pt["t"] = $snap["vader"]["t"]; $pt["tw"] = $snap["vader"]["tw"] }
  if ($snap["pump"] -and $snap["pump"]["dep12"]) {
    $d = $snap["pump"]["dep12"]
    $pt["tryckUt"] = $d["tryckUt"]; $pt["k125"] = $d["k125"]; $pt["k126"] = $d["k126"]
  }
  # Varje enhets luft- och våttemperatur (version 5, 25 november), så att
  # appen kan visa kurvan när man trycker på en kanons värde. Bara enheter
  # som styrsystemet hört de senaste 15 minuterna (samma gräns som appens
  # "hörd"): en tyst enhets värden står still, och sparade var femte minut
  # skulle de se ut som mätningar. Saknas enheten blir det ett hål i kurvan.
  # Bara t, tw och flode - varje fält till gör säsongen större OCH varje
  # hämtning av en lång period dyrare. Runt 18 MB per säsong med nio enheter.
  # flodeSum (version 7) är de hörda enheternas beräknade flöde ihop, så att
  # det kan läggas bredvid FT01: 26 november var summan 43,9 m3/h och FT01
  # 19,8. Teoretiskt flöde summeras inte, det står kvar när kanonen står.
  $ref = Newest $snap
  if ($snap["enheter"] -and $ref) {
    $fmt = "yyyy-MM-ddTHH:mm:ss"
    $refT = [datetime]::ParseExact($ref, $fmt, $null)
    $e = [ordered]@{}
    $sum = 0.0; $nSum = 0
    $heard = @{}
    foreach ($k in @($snap["enheter"].Keys)) {
      $u = $snap["enheter"][$k]
      if (-not $u["senastHord"]) { continue }
      try { $h = [datetime]::ParseExact("" + $u["senastHord"], $fmt, $null) } catch { continue }
      if ([math]::Abs(($refT - $h).TotalMinutes) -gt 15) { continue }
      $heard[$k] = $true
      $x = [ordered]@{}
      foreach ($f in @("t", "tw", "flode")) { if ($null -ne $u[$f]) { $x[$f] = $u[$f] } }
      # Vattnet sedan enheten kom till brunnen (version 8) - sågtanden.
      if (IsNum $u["vattenBrunn"]) { $x["vb"] = [math]::Round([double]$u["vattenBrunn"], 1) }
      $b = $null
      if ($u.Contains("bitar")) { $b = $u["bitar"] } elseif ($u.Contains("flaggor")) { $b = $u["flaggor"] }
      if ($null -ne $b) {
        # "0" när allt är släckt: en tom text går inte att spara i Firebase.
        if ($b -eq "") { $b = "0" }
        if ($script:lastBits[$k] -ne $b) { $x["b"] = $b; $script:lastBits[$k] = $b }
      }
      if ($x.Count -gt 0) { $e[$k] = $x }
      if (IsNum $u["flode"]) { $sum += [double]$u["flode"]; $nSum++ }
    }
    if ($e.Count -gt 0) { $pt["e"] = $e }
    if ($nSum -gt 0) { $pt["flodeSum"] = [math]::Round($sum, 1) }
    # En enhet som tystnat glöms, så att dess bitar skrivs igen när den hörs.
    foreach ($k in @($script:lastBits.Keys)) { if (-not $heard.ContainsKey($k)) { $script:lastBits.Remove($k) } }
  }
  $p[(SlotKey $slot)] = $pt
  return $p
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
      # 125 är FT01, flödesmätaren i pumphuset (25 november). Den visar
      # ungefär 45 % av kanonernas summerade flöde (26 november) och skickas
      # orättad. 126 stod på 0,1 även när pumpen gick och är oklar.
      k125       = V $r "125"   # säker: FT01, m3/h, troligen fel skalad
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
      # Flöde och tryck (version 7). Alla tre stämde mot skärmen 26 november
      # för fem kanoner. Det finns ingen flödesgivare i kanonerna: "Theoretic
      # water flow" är flödet för de öppna ringarna vid börtrycket, och "Real
      # water flow" räknas ur det uppmätta trycket,
      #   flode = flodeTeori * roten ur (tryck / tryckBor),
      # vilket gick ihop på en tiondel för alla fem. Teoretiskt flöde står
      # kvar när kanonen är stoppad; det beräknade flödet blir 0 utan tryck,
      # och är därför det som ska summeras.
      flodeTeori  = V $r "411"  # säker: "Theoretic water flow", m3/h
      flode       = V $r "406"  # säker: "Real water flow", m3/h (beräknat)
      tryck       = V $r "403"  # säker: "Water pressure", bar, vid kanonen
      tryckBor    = V $r "417"  # säker: "Water pressure set point", bar
      k408        = V $r "408"  # troligen vattentemperaturen vid kanonen
      # Läget: 6 kör (alla fem som gick 26 november), 11 klar, 2 stoppad,
      # 1 fel.
      k415        = V $r "415"
      # Lamporna, som tända bitar (se Bits). Sufags namn (sonden 28 november):
      # 450-451 "Défaut 1-2", 452 "Alarme", 453-454 "Mot Etat 1-2", 455
      # "Option", 500-501 ingångar (ETOR), 502-503 utgångar (STOR), 709
      # "Options". Vad varje bit är står inte i databasen. 453 bit 11 och 12
      # följer flödet som två vattensteg (5,1 / 6,5 / 8,3 m3/h för kanon 8),
      # bit 0 och 1 är tända hela tiden kanonen går. Se docs\kolumnmappning.md.
      bitar       = Bits $r @("450", "451", "452", "453", "454", "455", "500", "501", "502", "503", "709")
      # Inställningarna (version 12, säkra ur Sufags beskrivningar 28
      # november): snökvalitet 1-10 (Dry-Wet), start- och stoppgräns i
      # våttemperatur. Ändras sällan, så de kostar nästan inga sändningar.
      kvalitet    = V $r "704"  # "Qualité de neige", 5 på alla 28 november
      startTemp   = V $r "702"  # "T de demarrage", -2,5
      stoppTemp   = V $r "703"  # "T arret", -2
      senastHord  = V $r "850"  # säker: senaste kontakt med kanonen
      # Brunnen enheten står vid ("Shelter" på skärmen Gun searching).
      # Säker: alla sju stämde mot skärmen 25 november (version 6).
      brunn       = V $r "707"
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
      # Flöde och tryck (version 7), mot skärmen 26 november: 4 = 14,5 bar
      # (skärmen 14,6), 5 och 10 = 5,8 båda. Det äldre kortet har inget
      # börtryck, och de två flödena skilde 4,7 mot 5,4 tidigare samma
      # morgon. Kanonen på adress 2, tyst sedan 2022, har 10 = 15,5 och
      # 5 = 0 utan tryck - som teoretiskt och beräknat flöde på SGC400.
      flodeTeori = V $r "10"    # trolig: "Theoretic water flow", m3/h
      flode      = V $r "5"     # trolig: "Real water flow", m3/h
      tryck      = V $r "4"     # säker: "Water pressure", bar
      # Lamporna (se Flags), en kolumn per lampa. Säkra ur Sufags
      # beskrivningar (sonden 28 november): 25 Auto, 26 General fault, 27
      # Pressostat, 28 Hydrant OK, 29 Gun started, 30 Power ON, 33-34
      # hydrant öppen/stängd, 35-39 "0-4 rings open", 42 Compressor ON, 43
      # Fan ON, 44 Ready to start, 66-81 felen. 26 november, gående: 25, 37,
      # 42, 43, 44 = 1 (Auto, 2 ringar, kompressor, fläkt, redo).
      flaggor    = Flags $r (@(25..81) + @(85, 86, 93, 96, 107))
      kvalitet   = V $r "16"    # säker: "Snow quality COM" (version 12)
      startTemp  = V $r "9"     # säker: "Start temperature COM" (version 12)
      senastHord = V $r "104"
      brunn      = V $r "108"   # säker: "Shelter", stämde 25 november
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

# ------------------------------------------ vattnet före version 8 (-Bakat)
# Engångskörning. Fyller på räkneverken i brygga-state.json med styrsystemets
# statistik för tiden innan bryggan började räkna. Bryggan måste vara
# stoppad (den skriver annars över filen var femte minut), och det görs bara
# en gång: filen får en stämpel "bakat" och en andra körning vägrar.
# Läser bara rader med flöde, inom säsongen, ur halvmånadsdatabaserna.

# Statistikraderna med flöde mellan $from och $to, över de halvmånads-
# databaser tiden spänner över. Anslutningen ska vara öppen. Används av
# -Bakat, -BakatBrunn och timvattnet.
function Stat-Rows([datetime]$from, [datetime]$to, $log) {
  $mois = @("janvier", "fevrier", "mars", "avril", "mai", "juin", "juillet", "aout", "septembre", "octobre", "novembre", "decembre")
  $rows = New-Object System.Collections.Generic.List[object]
  $dbs = @((Read-Sql "SELECT [name] FROM sys.databases WHERE [name] LIKE 'Live_stat_%SQL'").Rows | ForEach-Object { "" + $_["name"] })
  # Halvmånad för halvmånad: 1 = dag 1-15, 2 = resten.
  $d = $from
  while ($d -lt $to) {
    $half = $(if ($d.Day -le 15) { 1 } else { 2 })
    $db = "Live_stat_" + $mois[$d.Month - 1] + $half + "SQL"
    if ($dbs -contains $db) {
      foreach ($t in @(@{ tab = "stat_piste_canon_SGC400"; pre = "SGC400-" }, @{ tab = "stat_piste_canon_SGC300"; pre = "SGC300-" })) {
        # Raderna vägs med tiden till nästa rad för samma kanon (en rad var
        # tionde minut, visade -BakatBrunn 26 november). LEAD räknar fram den
        # i databasen, och bara raderna med flöde skickas hit.
        $q = "SELECT [num_canon],[date],[debit_eau_reel],[nxt] FROM (SELECT [num_canon],[date],[debit_eau_reel],LEAD([date]) OVER (PARTITION BY [num_canon] ORDER BY [date]) AS [nxt] FROM [" + $db + "].[dbo].[" + $t.tab + "] WITH (NOLOCK) WHERE [date] >= @from AND [date] < @to) AS x WHERE [debit_eau_reel] > 0"
        $dt = Read-Sql $q @{ from = $from; to = $to }
        foreach ($r in $dt.Rows) {
          $nx = $null; if (-not ($r["nxt"] -is [System.DBNull])) { $nx = [datetime]$r["nxt"] }
          $rows.Add([pscustomobject]@{ key = $t.pre + $r["num_canon"]; tid = [datetime]$r["date"]; debit = [double]$r["debit_eau_reel"]; nxt = $nx })
        }
        if ($log) { $log.Add(("{0} {1}: {2} rader med flöde" -f $db, $t.tab, $dt.Rows.Count)) }
      }
    }
    if ($half -eq 1) { $d = Get-Date -Year $d.Year -Month $d.Month -Day 16 -Hour 0 -Minute 0 -Second 0 } else { $d = (Get-Date -Year $d.Year -Month $d.Month -Day 1 -Hour 0 -Minute 0 -Second 0).AddMonths(1) }
  }
  return ,$rows
}

# ------------------------------------------- timvattnet (version 11, dammen)
# Allt vatten kanonerna tagit, timme för timme, till /vattenTimme i molnet:
# { "2026112603": 35.21, ... }, nyckeln är timmens början i UTC som
# historiken. Appen drar det från dammen sedan senaste måttbandsmätningen.
# Räknas ur styrsystemets statistik, inte ur bryggans egna läsningar: då
# går det att räkna om i efterhand, och en timme när bryggan inte gick kommer
# med ändå. Vid första starten räknas hela säsongen; sedan, var tionde
# minut, från den första timme som kan ha fått nya rader. En timme räknas
# klar först 25 minuter efter att den slutat - raderna kommer var tionde
# minut, och en rad gäller till nästa, så sista raden i timmen behöver nästa
# rad för att räknas. Marginalen tar en sen rad eller två.
function Hour-Totals($rows, [datetime]$from, [datetime]$to) {
  $h = @{}
  foreach ($r in $rows) {
    if ($null -eq $r.nxt) { continue }
    $a = $r.tid; $b = $r.nxt
    if (($b - $a).TotalHours -le 0 -or ($b - $a).TotalHours -gt 0.25) { continue }
    if ($a -lt $from) { $a = $from }
    if ($b -gt $to) { $b = $to }
    while ($a -lt $b) {
      $hs = New-Object datetime($a.Year, $a.Month, $a.Day, $a.Hour, 0, 0, $a.Kind)
      $he = $hs.AddHours(1); $e = $b; if ($he -lt $e) { $e = $he }
      $k = $hs.ToUniversalTime().ToString("yyyyMMddHH")
      $h[$k] = [double]$h[$k] + [double]$r.debit / 10 * ($e - $a).TotalHours
      $a = $e
    }
  }
  return $h
}

# Från vilken timme ska nästa runda räkna? Den första som inte är klar:
# timmen som slutade för mindre än 25 minuter sedan, eller den pågående.
function Hour-OpenFrom([datetime]$now) {
  $t = $now.AddMinutes(-25)
  return (New-Object datetime($t.Year, $t.Month, $t.Day, $t.Hour, 0, 0, $t.Kind))
}

# Statistikraderna och journalens inkopplingar, för -Bakat och -BakatBrunn.
function Bakat-Fetch([datetime]$seasonStart, [datetime]$until, $log) {
  $events = @()
  try {
    Open-Sql
    $rows = Stat-Rows $seasonStart $until $log
    # Version 9 frågade efter [message] LIKE 'Appeared%' och fick noll rader,
    # fast journalen hade "Appeared  S ACCESS 300 ( adr = 8)    to  5" samma
    # natt. Bryggan trimmar texterna innan de visas, så troligen börjar de med
    # blanksteg i databasen. Därför '%Appeared%', och texten tolkas sedan här.
    # Hur många rader journalen har och hur långt bakåt den går skrivs ut, så
    # att det syns om journalen själv är kortare än säsongen.
    $jn = Read-Sql "SELECT COUNT(*) AS [n], MIN([date]) AS [forst] FROM [Live_event_SQL].[dbo].[Journal] WITH (NOLOCK) WHERE [date] >= @from" @{ from = $seasonStart }
    if ($jn.Rows.Count -gt 0) {
      $fo = $jn.Rows[0]["forst"]; $fos = $(if ($fo -is [System.DBNull]) { "-" } else { ([datetime]$fo).ToString("yyyy-MM-dd HH:mm") })
      $log.Add(("Journal: {0} rader sedan {1}, den första {2}" -f $jn.Rows[0]["n"], $seasonStart.ToString("yyyy-MM-dd"), $fos))
    }
    $ev = Read-Sql "SELECT [date],[message] FROM [Live_event_SQL].[dbo].[Journal] WITH (NOLOCK) WHERE [date] >= @from AND [message] LIKE '%Appeared%'" @{ from = $seasonStart }
    $events = @($ev.Rows | ForEach-Object { [pscustomobject]@{ tid = [datetime]$_["date"]; text = ("" + $_["message"]).Trim() } })
    $log.Add(("Journal: {0} inkopplingar sedan {1}" -f $events.Count, $seasonStart.ToString("yyyy-MM-dd")))
  } finally { Close-Sql }
  return @{ rows = $rows; events = $events }
}

# Brunnsdelen rättad i efterhand (-BakatBrunn, version 10). Version 9 hittade
# inga inkopplingar och lade därför hela säsongen på brunnen, med "sedan"
# 1 augusti. Säsongen var rätt och rörs inte. För varje enhet som fortfarande
# står vid samma brunn (sedan är kvar på säsongens början) dras det felaktiga
# av: det som lades till var säsongens tillägg, rätt är tillägget sedan
# ankomsten. Statistiken före "till" ändras inte i efterhand, så samma rader
# ger samma säsongstillägg som då. En enhet som bytt brunn sedan dess har
# redan börjat om och lämnas.
function BakatBrunn-Adjust($acc, $res, [string]$seasonStartS) {
  $fmt = "yyyy-MM-ddTHH:mm:ss"
  $out = [ordered]@{}
  foreach ($k in $res.Keys) {
    $a = $acc[$k]; $r = $res[$k]
    if ($null -eq $a -or $a["sedan"] -ne $seasonStartS) { $out[$k] = "lämnad (ny brunn sedan -Bakat)"; continue }
    if ($null -ne $r.ankomst) {
      $a["brunnM3"] = [math]::Max(0.0, [double]$a["brunnM3"] - ($r.sasong - $r.brunn))
      $a["sedan"] = $r.ankomst.ToString($fmt)
      if ($r.ankomst -eq [datetime]::ParseExact($seasonStartS, $fmt, $null)) { $out[$k] = "oförändrad (ingen inkoppling i säsongen)" }
      else { $out[$k] = ("kom dit {0}, {1:N1} m3 vid brunnen före" -f $r.ankomst.ToString("yyyy-MM-dd HH:mm"), $r.brunn) }
    } else {
      $a["brunnM3"] = [math]::Max(0.0, [double]$a["brunnM3"] - $r.sasong)
      $a["sedan"] = $a["fran"]
      $out[$k] = "okänt när den kom (senast inkopplad vid en annan brunn) - räknas från " + $a["fran"]
    }
  }
  return $out
}

# Stämpeln "bakat" i brygga-state.json. Bryggan version 9 skrev bara
# lastSlot och vatten när den sparade var femte minut, så stämpeln försvann
# första gången bryggan gick efter -Bakat (26 november). Saknas den, byggs
# den upp ur rapporten bakat_<tid>.txt som ligger kvar i mappen: tiden ur
# namnet, raderna ur raderna "N rader med flöde", säsongens början ur tiden,
# och "till" som bryggans start (fran), som -Bakat själv räknade den.
function Bakat-Stamp($st, [string]$dir, $acc) {
  if ($st.bakat) { return $st.bakat }
  $rep = @(Get-ChildItem -Path $dir -Filter "bakat_*.txt" -ErrorAction SilentlyContinue | Sort-Object Name)
  if ($rep.Count -eq 0) { return $null }
  $fmt = "yyyy-MM-ddTHH:mm:ss"
  $f = $rep[0]
  $t = [datetime]::ParseExact(($f.BaseName -replace '^bakat_', ''), "yyyyMMdd-HHmmss", $null)
  $n = 0
  foreach ($l in (Get-Content $f.FullName -Encoding UTF8)) { if ($l -match ':\s*(\d+) rader med fl') { $n += [int]$matches[1] } }
  $y = $t.Year; if ($t.Month -lt 8) { $y-- }
  $ss = Get-Date -Year $y -Month 8 -Day 1 -Hour 0 -Minute 0 -Second 0
  $till = ($acc.Values | ForEach-Object { [datetime]::ParseExact($_["fran"], $fmt, $null) } | Measure-Object -Maximum).Maximum
  return [pscustomobject]@{ tid = $t.ToString($fmt); fran = $ss.ToString($fmt); till = $till.ToString($fmt); rader = $n; urRapport = $f.Name }
}

if ($BakatBrunn) {
  $created = $false
  $mx = New-Object System.Threading.Mutex($true, "snogrupp-brygga", [ref]$created)
  if (-not $created) {
    Write-Host "Bryggan går. Stoppa den först: .\installera-autostart.ps1 -TaBort, och sedan processen (se LAS-MIG-FORST.txt)."
    exit 1
  }
  if (-not (Test-Path $stateFile)) { Write-Host ("Hittar inte " + $stateFile); exit 1 }
  $st = Get-Content $stateFile -Raw | ConvertFrom-Json
  Acc-FromState $st.vatten
  $stamp = Bakat-Stamp $st $here $script:acc
  if (-not $stamp) { Write-Host "Bakåträkningen (-Bakat) är inte gjord. Kör den i stället."; exit 1 }
  if ($stamp.brunn) { Write-Host ("Brunnsdelen är redan rättad " + $stamp.brunn.tid + "."); exit 1 }
  if (@(Get-ChildItem -Path $here -Filter "bakatbrunn_*.txt" -ErrorAction SilentlyContinue).Count -gt 0) { Write-Host "Brunnsdelen är redan rättad (det finns en rapport bakatbrunn_...txt)."; exit 1 }
  $st | Add-Member -NotePropertyName bakat -NotePropertyValue $stamp -Force
  if ($stamp.urRapport) { Write-Host ("Stämpeln saknades i filen; tagen ur " + $stamp.urRapport + ": " + $stamp.rader + " rader, till " + $stamp.till + ".") }
  $fmt = "yyyy-MM-ddTHH:mm:ss"
  $now = Get-Date
  $seasonStart = [datetime]::ParseExact($st.bakat.fran, $fmt, $null)
  $until = [datetime]::ParseExact($st.bakat.till, $fmt, $null)
  $log = New-Object System.Collections.Generic.List[string]
  $f0 = Bakat-Fetch $seasonStart $until $log
  if ($f0.rows.Count -ne [int]$st.bakat.rader) {
    # Andra rader än vid -Bakat betyder att avdraget inte blir detsamma som
    # det som lades till. Hellre stanna än gissa.
    $log | ForEach-Object { Write-Host $_ }
    Write-Host ("Statistiken gav {0} rader nu men {1} vid -Bakat. Inget ändrat - skicka detta till Claude." -f $f0.rows.Count, $st.bakat.rader)
    exit 1
  }
  if ($f0.events.Count -eq 0) {
    $log | ForEach-Object { Write-Host $_ }
    Write-Host "Journalen gav inga inkopplingar nu heller. Inget ändrat - skicka detta till Claude."
    exit 1
  }
  # Ankomsten räknas mot "fran" som den var vid -Bakat, inte mot "sedan".
  $res = Backfill-Compute $script:acc $f0.rows (Parse-Appeared $f0.events) $seasonStart
  $out = BakatBrunn-Adjust $script:acc $res $st.bakat.fran
  # Hur tätt raderna kommer, och hur många som föll bort för att glappet till
  # nästa var över en kvart. Är det många, räknade -Bakat för lite.
  $log.Add("")
  $log.Add("enhet | rader med flöde | median till nästa (min) | bortfallna (glapp över 15 min)")
  foreach ($g in ($f0.rows | Where-Object { $null -ne $_.nxt } | Group-Object key | Sort-Object Name)) {
    $mins = @($g.Group | ForEach-Object { ($_.nxt - $_.tid).TotalMinutes } | Sort-Object)
    $med = $mins[[int][math]::Floor($mins.Count / 2)]
    $bort = @($mins | Where-Object { $_ -gt 15 }).Count
    $log.Add(("{0} | {1} | {2:N1} | {3}" -f $g.Name, $mins.Count, $med, $bort))
  }
  $log.Add("")
  $log.Add("enhet | brunn | vid brunnen nu (m3) | vad som hände")
  foreach ($k in $out.Keys) { $log.Add(("{0} | {1} | {2:N1} | {3}" -f $k, $script:acc[$k]["brunn"], [double]$script:acc[$k]["brunnM3"], $out[$k])) }
  $bk = [ordered]@{ tid = $st.bakat.tid; fran = $st.bakat.fran; till = $st.bakat.till; rader = $st.bakat.rader; brunn = [ordered]@{ tid = $now.ToString($fmt); inkopplingar = $f0.events.Count } }
  $o = [ordered]@{ lastSlot = $st.lastSlot; vatten = (Acc-ToState); bakat = $bk }
  Copy-Item $stateFile ($stateFile + ".fore-bakatbrunn") -Force
  (ConvertTo-Json -InputObject $o -Depth 5 -Compress) | Set-Content -Path $stateFile -Encoding ASCII
  $f = Join-Path $here ("bakatbrunn_" + $now.ToString("yyyyMMdd-HHmmss") + ".txt")
  $log | Set-Content -Path $f -Encoding UTF8
  $log | ForEach-Object { Write-Host $_ }
  Write-Host ""
  Write-Host ("Klart. Den gamla filen ligger kvar som " + (Split-Path -Leaf $stateFile) + ".fore-bakatbrunn.")
  Write-Host ("Rapporten ligger i " + $f + ". Starta bryggan igen med autostarten.")
  exit 0
}

if ($Bakat) {
  $created = $false
  $mx = New-Object System.Threading.Mutex($true, "snogrupp-brygga", [ref]$created)
  if (-not $created) {
    Write-Host "Bryggan går. Stoppa den först: .\installera-autostart.ps1 -TaBort"
    exit 1
  }
  if (-not (Test-Path $stateFile)) { Write-Host ("Hittar inte " + $stateFile + " - har bryggan version 8 gått?"); exit 1 }
  $st = Get-Content $stateFile -Raw | ConvertFrom-Json
  if ($st.bakat) { Write-Host ("Redan gjort " + $st.bakat.tid + ". Görs bara en gång, så att inget räknas dubbelt."); exit 1 }
  # Version 9 tappade stämpeln vid nästa sparning, så rapporten är det säkra
  # tecknet på att bakåträkningen redan är gjord.
  $rep = @(Get-ChildItem -Path $here -Filter "bakat_*.txt" -ErrorAction SilentlyContinue)
  if ($rep.Count -gt 0) { Write-Host ("Redan gjort (" + $rep[0].Name + "). Görs bara en gång, så att inget räknas dubbelt."); exit 1 }
  if (-not $st.vatten) { Write-Host "Inga räkneverk i tillståndsfilen - låt bryggan version 8 eller senare gå en stund först."; exit 1 }
  Acc-FromState $st.vatten
  $fmt = "yyyy-MM-ddTHH:mm:ss"
  $now = Get-Date
  $y = $now.Year; if ($now.Month -lt 8) { $y-- }
  $seasonStart = Get-Date -Year $y -Month 8 -Day 1 -Hour 0 -Minute 0 -Second 0
  $until = ($script:acc.Values | ForEach-Object { [datetime]::ParseExact($_["fran"], $fmt, $null) } | Measure-Object -Maximum).Maximum
  $log = New-Object System.Collections.Generic.List[string]
  $f0 = Bakat-Fetch $seasonStart $until $log
  $rows = $f0.rows; $events = $f0.events

  $res = Backfill-Compute $script:acc $rows (Parse-Appeared $events) $seasonStart
  $log.Add("")
  $log.Add("enhet | brunn | kom dit | vatten vid brunnen före | vatten i säsongen före (m3)")
  foreach ($k in $res.Keys) {
    $a = $script:acc[$k]; $r = $res[$k]
    $a["sasongM3"] = [double]$a["sasongM3"] + $r.sasong
    if ($null -ne $r.ankomst) {
      $a["brunnM3"] = [double]$a["brunnM3"] + $r.brunn
      if ($r.ankomst -lt [datetime]::ParseExact($a["sedan"], $fmt, $null)) { $a["sedan"] = $r.ankomst.ToString($fmt) }
      $ank = $r.ankomst.ToString("yyyy-MM-dd HH:mm")
    } else { $ank = "okänt (senast inkopplad vid en annan brunn) - inget tillagt" }
    $log.Add(("{0} | {1} | {2} | {3:N1} | {4:N1}" -f $k, $a["brunn"], $ank, $r.brunn, $r.sasong))
  }
  $o = [ordered]@{ lastSlot = $st.lastSlot; vatten = (Acc-ToState); bakat = [ordered]@{ tid = $now.ToString($fmt); fran = $seasonStart.ToString($fmt); till = $until.ToString($fmt); rader = $rows.Count } }
  Copy-Item $stateFile ($stateFile + ".fore-bakat") -Force
  (ConvertTo-Json -InputObject $o -Depth 5 -Compress) | Set-Content -Path $stateFile -Encoding ASCII
  $f = Join-Path $here ("bakat_" + $now.ToString("yyyyMMdd-HHmmss") + ".txt")
  $log | Set-Content -Path $f -Encoding UTF8
  $log | ForEach-Object { Write-Host $_ }
  Write-Host ""
  Write-Host ("Klart. Räkneverken är påfyllda; den gamla filen ligger kvar som " + (Split-Path -Leaf $stateFile) + ".fore-bakat.")
  Write-Host ("Rapporten ligger i " + $f + ". Starta bryggan igen med autostarten.")
  exit 0
}

# -------------------------------------------------------------- Firebase
# Databasen och reglerna finns sedan 15-16 november. Prova inloggning och
# rättigheter med -ProvaMoln innan bryggan får skicka på riktigt.
# Bryggan loggar in som ett eget konto (e-post + lösenord), inte med en
# servicekonto-nyckel - en sådan ger full makt över hela projektet.
$script:token = $null
$script:tokenAt = [datetime]::MinValue
$cfg = $null

function Send-Json([string]$method, [string]$url, [string]$json, [hashtable]$headers = @{}) {
  # Kroppen skickas som UTF-8-byte. Windows PowerShell 5.1 kodar annars en
  # textsträng som Latin-1, och å, ä, ö i larmtexter blir fel i molnet.
  $bytes = [System.Text.Encoding]::UTF8.GetBytes($json)
  return Invoke-RestMethod -Method $method -Uri $url -Body $bytes -Headers $headers -ContentType "application/json; charset=utf-8" -TimeoutSec 15
}

function Login-Headers {
  # Webbnyckeln är låst till vissa webbadresser i Google Cloud. Ett skript har
  # ingen adress, och inloggningen nekas då med "Requests from referer <empty>
  # are blocked" - upptäckt 16 november, innan bryggan hunnit ut till
  # styrdatorn. Därför skickas en av de tillåtna adresserna med, tagen ur
  # konfigurationen. Det är ingen säkerhetslucka: nyckeln är offentlig, och
  # skyddet är databasens regler och kontots lösenord.
  if ($cfg.referer) { return @{ Referer = [string]$cfg.referer } }
  return @{}
}

function Get-Token {
  # Inloggningen gäller en timme; förnya efter 50 minuter.
  if ($script:token -and ((Get-Date) - $script:tokenAt).TotalMinutes -lt 50) { return $script:token }
  $pw = Get-Secret "moln" "Lösenord för bryggans Firebase-konto"
  $body = @{ email = $cfg.email; password = (Plain $pw); returnSecureToken = $true } | ConvertTo-Json -Compress
  $r = Send-Json "Post" ("https://identitytoolkit.googleapis.com/v1/accounts:signInWithPassword?key=" + $cfg.apiKey) $body (Login-Headers)
  $script:token = $r.idToken
  $script:tokenAt = Get-Date
  return $script:token
}

function Send-Cloud([string]$method, [string]$path, $body) {
  $tok = Get-Token
  $json = ConvertTo-Json -InputObject $body -Depth 8 -Compress
  [void](Send-Json $method ($cfg.dbUrl.TrimEnd("/") + "/" + $path + ".json?auth=" + $tok) $json)
}

# ------------------------------------------------ vad ska skickas den här gången
# Tre sorters sändning:
#   full   - hela nuläget ersätts. Vid start och en gång i timmen, så att
#            molnet aldrig kan glida isär från verkligheten för gott.
#   patch  - bara fälten som ändrats, plus hjärtslaget.
#   none   - ingenting. Det vanliga, större delen av året.
# Minnet av vad som skickats uppdateras först när sändningen lyckats
# (Commit-Round). Går nätet ner försöker bryggan alltså igen nästa varv.
$script:sent      = $null
$script:lastFull  = [datetime]::MinValue
$script:lastMeta  = [datetime]::MinValue
$script:lastSqlOk = $null

function Plan-Round($snap, [bool]$sqlOk, [datetime]$now, [int]$ms) {
  # Hjärtslaget stämplas med molnets klocka, så att gammal data märks även om
  # styrdatorns klocka går fel eller hoppar natten till sommartid.
  $meta = [ordered]@{ ts = @{ ".sv" = "timestamp" }; sqlOk = $sqlOk; version = $VERSION; lasMs = $ms }
  if ($sqlOk) { $meta["gssTid"] = Newest $snap }
  # Syns i appen så länge bryggan går med det skrivande kontot.
  if ($avsteg) { $meta["skrivkonto"] = $true }
  $metaDue = (($now - $script:lastMeta).TotalSeconds -ge 60) -or ($script:lastSqlOk -ne $sqlOk)

  if (-not $sqlOk) {
    # Databasen svarar inte. Värdena i molnet får stå kvar - att ta bort dem
    # vore att påstå att kanonerna försvunnit. Bara hjärtslaget säger ifrån,
    # så att appen kan skilja "bryggan död" från "databasen svarar inte".
    if (-not $metaDue) { return @{ kind = "none" } }
    $b = [ordered]@{}
    foreach ($k in $meta.Keys) { $b["meta/" + $k] = $meta[$k] }
    return @{ kind = "patch"; body = $b; flat = $null; n = 0 }
  }

  $flat = @{}
  Flatten $snap "" $flat
  if ($null -eq $script:sent -or ($now - $script:lastFull).TotalHours -ge 1) {
    $body = Strip $snap
    $body["meta"] = $meta
    return @{ kind = "full"; body = $body; flat = $flat; n = $flat.Count }
  }
  $ch = Get-Changes $flat $script:sent
  $n = $ch.Count
  if ($n -eq 0 -and -not $metaDue) { return @{ kind = "none" } }
  foreach ($k in $meta.Keys) { $ch["meta/" + $k] = $meta[$k] }
  return @{ kind = "patch"; body = $ch; flat = $flat; n = $n }
}

function Commit-Round($plan, [bool]$sqlOk, [datetime]$now) {
  if ($plan.kind -eq "none") { return }
  $script:lastMeta = $now
  $script:lastSqlOk = $sqlOk
  if ($plan.kind -eq "full") { $script:sent = $plan.flat; $script:lastFull = $now; return }
  if ($null -eq $plan.flat) { return }
  # Bara de fält som faktiskt skickades får nytt jämförelsevärde. De övriga
  # behåller sitt, annars skulle dödbandet nollställas varje varv.
  foreach ($k in @($plan.body.Keys)) {
    if ($k -like "meta/*") { continue }
    if ($plan.flat.ContainsKey($k)) { $script:sent[$k] = $plan.flat[$k] } else { $script:sent.Remove($k) }
  }
}

# ------------------------------------------------------------ prova molnet
# Loggar in som bryggkontot och provar att reglerna ger precis det kontot ska
# ha: skriva under /live och /hist, ingenting annat. Behöver ingen databas och
# kan köras var som helst, så att fel i nyckel, lösenord eller regler syns
# hemma och inte först vid styrdatorn. Provvärdena tas bort igen.
function Try-Web([string]$method, [string]$url, [string]$json = "", [hashtable]$headers = @{}) {
  try {
    $p = @{ Method = $method; Uri = $url; TimeoutSec = 15; Headers = $headers; UseBasicParsing = $true }
    if ($json -ne "") {
      $p.Body = [System.Text.Encoding]::UTF8.GetBytes($json)
      $p.ContentType = "application/json; charset=utf-8"
    }
    $r = Invoke-WebRequest @p
    return @{ code = [int]$r.StatusCode; text = [string]$r.Content }
  } catch {
    $code = 0
    $text = $_.Exception.Message
    if ($_.Exception.Response) {
      $code = [int]$_.Exception.Response.StatusCode
      if ($_.ErrorDetails -and $_.ErrorDetails.Message) { $text = $_.ErrorDetails.Message }
      else {
        # Windows PowerShell 5.1 lämnar ofta bara "(400) Felaktig begäran".
        # Orsaken står i svarets kropp, som måste läsas för hand.
        try {
          $st = $_.Exception.Response.GetResponseStream()
          if ($st.CanSeek) { $st.Position = 0 }
          $t2 = (New-Object System.IO.StreamReader($st)).ReadToEnd()
          if ($t2) { $text = $t2 }
        } catch { }
      }
    }
    # Adressen innehåller inloggningsbeviset; det ska aldrig hamna på skärmen.
    $text = ($text -replace 'auth=[^\s"&]+', 'auth=<dolt>')
    return @{ code = $code; text = $text }
  }
}

if ($ProvaMoln) {
  if (-not (Test-Path $cfgFile)) {
    Write-Host ("Saknar " + $cfgFile + ". Kopiera brygga-config.exempel.json och fyll i.")
    exit 1
  }
  $cfg = Get-Content $cfgFile -Raw -Encoding UTF8 | ConvertFrom-Json
  [Net.ServicePointManager]::SecurityProtocol = 3072
  # På ett företagsnät kan utgående trafik gå via en proxy som vill ha
  # Windows-inloggningen. Styrdatorn har ingen proxy, så där gör raden inget.
  try { [System.Net.WebRequest]::DefaultWebProxy.Credentials = [System.Net.CredentialCache]::DefaultCredentials } catch { }

  $script:bad = 0
  function Report([string]$what, [bool]$ok, [string]$detail = "") {
    if ($ok) { Write-Host ("  OK    " + $what) }
    else {
      $script:bad++
      Write-Host ("  FEL   " + $what)
      if ($detail -ne "") { Write-Host ("        " + $detail) }
    }
  }

  Write-Host ("Provar molnet som " + $cfg.email)
  Write-Host ("Databas: " + $cfg.dbUrl)
  Write-Host ""

  $pw = Get-Secret "moln" "Lösenord för bryggans Firebase-konto"
  $body = @{ email = $cfg.email; password = (Plain $pw); returnSecureToken = $true } | ConvertTo-Json -Compress
  $r = Try-Web "Post" ("https://identitytoolkit.googleapis.com/v1/accounts:signInWithPassword?key=" + $cfg.apiKey) $body (Login-Headers)
  $body = $null

  if ($r.code -ne 200) {
    Write-Host "  FEL   Inloggningen"
    if ($r.code -eq 0) {
      Write-Host ("        Kom inte fram till Google: " + $r.text)
      Write-Host "        Troligen nätet (brandvägg eller proxy). Prova ett annat nät."
    } elseif ($r.text -match 'referer') {
      Write-Host "        Nyckeln är låst till vissa webbadresser. Lägg till raden"
      Write-Host '        "referer": "https://snoprognos.firebaseapp.com/" i brygga-config.json.'
    } elseif ($r.text -match 'INVALID_LOGIN_CREDENTIALS|INVALID_PASSWORD|EMAIL_NOT_FOUND') {
      Write-Host "        Fel lösenord eller fel adress för bryggkontot."
      if (Test-Path (SecretPath "moln")) { Write-Host "        Ett sparat lösenord användes - spara om med -SparaLosen moln." }
    } elseif ($r.text -match 'USER_DISABLED') {
      Write-Host "        Kontot är avstängt i Firebase-konsolen."
    } else {
      Write-Host ("        Svar " + $r.code + ": " + $r.text)
    }
    exit 1
  }
  $login = $r.text | ConvertFrom-Json
  $tok = $login.idToken
  Write-Host "  OK    Inloggningen"
  Write-Host ("        Kontots id: " + $login.localId + "  (ska vara det som står i reglerna)")

  $base = $cfg.dbUrl.TrimEnd("/")
  function U([string]$path) { return ($base + "/" + $path + ".json?auth=" + $tok) }
  $prov = '{"prov":true,"tid":{".sv":"timestamp"}}'

  foreach ($gren in @("live", "hist")) {
    $w = Try-Web "Put" (U ($gren + "/_prov")) $prov
    Report ("Får skriva under /" + $gren) ($w.code -eq 200) ("Svar " + $w.code + ": " + $w.text)
    if ($w.code -eq 200) {
      $d = Try-Web "Delete" (U ($gren + "/_prov"))
      Report ("Provvärdet under /" + $gren + " borttaget") ($d.code -eq 200) ("Svar " + $d.code + ": " + $d.text + " - ta bort _prov för hand i konsolen.")
    }
  }

  # Det här ska INTE gå. Ett bryggkonto som kan läsa medlemslistan eller
  # skriva utanför sina två grenar betyder att reglerna är fel.
  $g = Try-Web "Get" (U "members")
  Report "Får inte läsa medlemslistan" ($g.code -eq 401 -or $g.code -eq 403) ("Svar " + $g.code + " - bryggan kom åt /members.")

  $w = Try-Web "Put" (U "members/_prov") $prov
  Report "Får inte skriva i medlemslistan" ($w.code -eq 401 -or $w.code -eq 403) ("Svar " + $w.code + " - bryggan kunde skriva i /members.")
  if ($w.code -eq 200) { [void](Try-Web "Delete" (U "members/_prov")) }

  $w = Try-Web "Put" (U "annat/_prov") $prov
  Report "Får inte skriva utanför /live och /hist" ($w.code -eq 401 -or $w.code -eq 403) ("Svar " + $w.code + " - bryggan kunde skriva på annat ställe.")
  if ($w.code -eq 200) { [void](Try-Web "Delete" (U "annat/_prov")) }

  Write-Host ""
  if ($script:bad -eq 0) { Write-Host "Allt stämmer. Bryggan kan skicka, och bara dit den ska."; exit 0 }
  Write-Host ([string]$script:bad + " saker stämmer inte. Skicka inte riktiga värden förrän det är rättat.")
  exit 1
}

# ------------------------------------------------------------- självtest
# Provar ändringslogiken med påhittade värden, utan databas och utan nät.
if ($Sjalvtest) {
  $script:bad = 0
  function Check([string]$what, [bool]$ok) {
    if ($ok) { Write-Host ("  ok   " + $what) } else { Write-Host ("  FEL  " + $what); $script:bad++ }
  }
  function Fake([double]$tw, $larm) {
    return [ordered]@{
      pump = [ordered]@{ dep12 = [ordered]@{ tryckUt = 7.2; k125 = 0.1; k126 = 0.1; uppdaterad = "2026-11-15T18:43:27" } }
      enheter = [ordered]@{
        "SGC400-3" = [ordered]@{ nr = 3; typ = "S ACCESS 300"; tw = $tw; uppdaterad = "2026-11-15T18:43:24" }
        "SGC400-4" = [ordered]@{ nr = 4; typ = "TAURUS_2.0"; tw = 8.6; uppdaterad = "2026-11-15T18:42:42" }
      }
      vader = [ordered]@{ t = 2.9; rh = 82; tw = 1.8; uppdaterad = "2026-11-15T18:43:29" }
      larm = $larm
    }
  }
  $t = Get-Date "2026-11-15 19:00:00"

  $p = Plan-Round (Fake 7.1 @()) $true $t 40
  Check "första varvet skickar allt" ($p.kind -eq "full")
  Check "uppdaterad följer inte med" (-not ((ConvertTo-Json -InputObject $p.body -Depth 8) -match "uppdaterad"))
  Check "senaste tid från GSSystem i hjärtslaget" ($p.body["meta"]["gssTid"] -eq "2026-11-15T18:43:29")
  Commit-Round $p $true $t

  $t = $t.AddSeconds(20); $p = Plan-Round (Fake 7.1 @()) $true $t 40
  Check "oförändrat efter 20 s: inget skickas" ($p.kind -eq "none")

  $t = $t.AddSeconds(20); $p = Plan-Round (Fake 7.2 @()) $true $t 40
  Check "en tiondel: inom dödbandet, inget skickas" ($p.kind -eq "none")

  $t = $t.AddSeconds(20); $p = Plan-Round (Fake 7.3 @()) $true $t 40
  Check "två tiondelar från det SKICKADE värdet: skickas" ($p.kind -eq "patch" -and $p.n -eq 1 -and $p.body["enheter/SGC400-3/tw"] -eq 7.3)
  Commit-Round $p $true $t

  $t = $t.AddSeconds(20); $p = Plan-Round (Fake 7.3 @()) $true $t 40
  Check "direkt efter: inget skickas" ($p.kind -eq "none")

  $t = $t.AddSeconds(61); $p = Plan-Round (Fake 7.3 @()) $true $t 40
  Check "efter en minut: bara hjärtslaget" ($p.kind -eq "patch" -and $p.n -eq 0 -and $p.body.Contains("meta/ts"))
  Commit-Round $p $true $t

  $larm = @([ordered]@{ sedan = "15/11/2026 19:05:00"; text = "fault : hose frozen"; id = "x1" })
  $t = $t.AddSeconds(20); $p = Plan-Round (Fake 7.3 $larm) $true $t 40
  Check "nytt larm skickas som en klump" ($p.kind -eq "patch" -and $p.n -eq 1 -and $p.body.Contains("larm"))
  Commit-Round $p $true $t

  $s = Fake 7.3 $larm; $s["enheter"].Remove("SGC400-4")
  $t = $t.AddSeconds(20); $p = Plan-Round $s $true $t 40
  Check "en enhet som försvinner tas bort i molnet" ($p.kind -eq "patch" -and $p.n -eq 3 -and $p.body.Contains("enheter/SGC400-4/tw") -and $null -eq $p.body["enheter/SGC400-4/tw"])
  Commit-Round $p $true $t

  $t = $t.AddSeconds(20); $p = Plan-Round ([ordered]@{}) $false $t 40
  Check "databasen svarar inte: bara hjärtslag, inget tas bort" ($p.kind -eq "patch" -and $p.body.Count -eq 4 -and $p.body["meta/sqlOk"] -eq $false)
  Commit-Round $p $false $t

  $t = $t.AddSeconds(20); $p = Plan-Round ([ordered]@{}) $false $t 40
  Check "fortfarande nere 20 s senare: inget skickas" ($p.kind -eq "none")

  $t = $t.AddSeconds(20); $p = Plan-Round $s $true $t 40
  Check "databasen tillbaka: hjärtslaget säger det direkt" ($p.kind -eq "patch" -and $p.n -eq 0 -and $p.body["meta/sqlOk"] -eq $true)
  Commit-Round $p $true $t

  $t = $t.AddHours(1); $p = Plan-Round $s $true $t 40
  Check "efter en timme: allt skickas igen" ($p.kind -eq "full")

  $slot = SlotOf ([datetime]::SpecifyKind((Get-Date "2026-11-15 18:07:31"), [DateTimeKind]::Utc))
  Check "historiknyckeln ligger på jämna fem minuter" ((SlotKey $slot) -eq "202611151805")
  $h = Build-HistPatch (Fake 7.3 @()) $slot
  Check "en punkt, och inget gammalt tas bort" ($h.Count -eq 1 -and $h.Contains("202611151805"))
  $bort = @($h.Keys | Where-Object { $null -eq $h[$_] })
  Check "ingen nyckel sätts till tom (ingen städning)" ($bort.Count -eq 0)
  Check "punkten har våttemperatur och tryck" ($h["202611151805"]["tw"] -eq 1.8 -and $h["202611151805"]["tryckUt"] -eq 7.2)
  Check "utan senaste kontakt sparas ingen enhet" (-not $h["202611151805"].Contains("e"))

  # En enhet hörd nyss och en som varit tyst sedan förmiddagen.
  $s = Fake 7.3 @()
  $s["enheter"]["SGC400-3"]["senastHord"] = "2026-11-15T18:43:20"
  $s["enheter"]["SGC400-3"]["t"] = -1.2
  $s["enheter"]["SGC400-4"]["senastHord"] = "2026-11-15T11:02:00"
  $h = Build-HistPatch $s $slot
  $e = $h["202611151805"]["e"]
  Check "enhet hörd nyss: t och tw sparas" ($e -and $e["SGC400-3"]["tw"] -eq 7.3 -and $e["SGC400-3"]["t"] -eq -1.2)
  Check "enhet hörd nyss: inget mer än t och tw" ($e["SGC400-3"].Count -eq 2)
  Check "tyst enhet sparas inte (blir ett hål)" (-not $e.Contains("SGC400-4"))
  Check "utan flöde ingen summa" (-not $h["202611151805"].Contains("flodeSum"))

  # Flöde: två hörda kanoner summeras, den tysta och teoretiskt flöde inte.
  $s["enheter"]["SGC400-3"]["flode"] = 7.3
  $s["enheter"]["SGC400-3"]["flodeTeori"] = 7.3
  $s["enheter"]["SGC400-4"]["flode"] = 9.9
  $s["enheter"]["SGC300-1"] = [ordered]@{ typ = "S ACCESS 300"; tw = -4.3; flode = 5.8; flodeTeori = 5.8; senastHord = "2026-11-15T18:43:10"; uppdaterad = "2026-11-15T18:43:10" }
  $h = Build-HistPatch $s $slot
  $pt = $h["202611151805"]
  Check "hörd enhets flöde sparas" ($pt["e"]["SGC400-3"]["flode"] -eq 7.3 -and $pt["e"]["SGC300-1"]["flode"] -eq 5.8)
  Check "teoretiskt flöde sparas inte i historiken" (-not $pt["e"]["SGC400-3"].Contains("flodeTeori"))
  Check "summan är de hörda enheternas flöde" ($pt["flodeSum"] -eq 13.1)
  # Lamporna: bitmönster och flaggkolumner som de såg ut 26 november.
  $tb = New-Object System.Data.DataTable
  foreach ($c in @("453", "454", "455")) { [void]$tb.Columns.Add($c, [string]) }
  foreach ($c in @("25", "37", "65")) { [void]$tb.Columns.Add($c, [int]) }
  $row = $tb.NewRow(); $row["453"] = "0001110000100011"; $row["454"] = "0000000111010001"; $row["455"] = "0000000000000000"
  $row["25"] = 1; $row["37"] = 0; $row["65"] = 3
  Check "tända bitar räknas från höger" ((Bits $row @("453", "454", "455", "500")) -eq "453:0,1,5,10,11,12;454:0,4,6,7,8")
  Check "flaggor: ettor som nummer, annat med värde" ((Flags $row @(25, 37, 65, 99)) -eq "25,65=3")

  $script:lastBits = @{}
  $s["enheter"]["SGC400-3"]["bitar"] = "453:0,1;454:4"
  $s["enheter"]["SGC300-1"]["flaggor"] = ""
  $pt = (Build-HistPatch $s $slot)["202611151805"]
  Check "bitarna sparas första gången" ($pt["e"]["SGC400-3"]["b"] -eq "453:0,1;454:4" -and $pt["e"]["SGC300-1"]["b"] -eq "0")
  $pt = (Build-HistPatch $s $slot)["202611151805"]
  Check "oförändrade bitar sparas inte igen" (-not $pt["e"]["SGC400-3"].Contains("b") -and -not $pt["e"]["SGC300-1"].Contains("b"))
  $s["enheter"]["SGC400-3"]["bitar"] = "453:0,1,2;454:4"
  $pt = (Build-HistPatch $s $slot)["202611151805"]
  Check "en ring till: bitarna sparas" ($pt["e"]["SGC400-3"]["b"] -eq "453:0,1,2;454:4")
  $s["enheter"]["SGC300-1"]["senastHord"] = "2026-11-15T11:00:00"
  [void](Build-HistPatch $s $slot)
  $s["enheter"]["SGC300-1"]["senastHord"] = "2026-11-15T18:43:10"
  $pt = (Build-HistPatch $s $slot)["202611151805"]
  Check "tyst och hörd igen: bitarna skrivs igen" ($pt["e"]["SGC300-1"]["b"] -eq "0")

  # Vattnet per brunn och säsong.
  $script:acc = @{}
  function W([double]$q, [int]$brunn, [string]$hord, [datetime]$tid) {
    return [ordered]@{ vader = [ordered]@{ uppdaterad = $tid.ToString("yyyy-MM-ddTHH:mm:ss") }; enheter = [ordered]@{ "SGC400-1" = [ordered]@{ flode = $q; brunn = $brunn; senastHord = $hord } } }
  }
  $t = Get-Date "2026-11-26 09:00:00"
  $s = W 7.2 7 "2026-11-26T09:00:00" $t; Add-Water $s $t
  Check "första läsningen räknar inget" ($s["enheter"]["SGC400-1"]["vattenBrunn"] -eq 0)
  for ($i = 1; $i -le 180; $i++) { $t = $t.AddSeconds(20); $s = W 7.2 7 $t.ToString("yyyy-MM-ddTHH:mm:ss") $t; Add-Water $s $t }
  Check "en timme med 7,2 m3/h ger 7,2 m3" ([math]::Abs($s["enheter"]["SGC400-1"]["vattenBrunn"] - 7.2) -lt 0.01)
  $t = $t.AddMinutes(30); $s = W 7.2 7 $t.ToString("yyyy-MM-ddTHH:mm:ss") $t; Add-Water $s $t
  Check "efter ett avbrott räknas inte tiden emellan" ([math]::Abs($s["enheter"]["SGC400-1"]["vattenBrunn"] - 7.2) -lt 0.01)
  $t = $t.AddSeconds(20); $s = W 7.2 7 "2026-11-26T09:00:00" $t; Add-Water $s $t
  Check "tyst enhet räknas inte" ([math]::Abs($s["enheter"]["SGC400-1"]["vattenBrunn"] - 7.2) -lt 0.01)
  $t = $t.AddSeconds(20); $s = W 7.2 8 $t.ToString("yyyy-MM-ddTHH:mm:ss") $t; Add-Water $s $t
  Check "ny brunn: brunnens räkneverk börjar om, säsongens inte" ($s["enheter"]["SGC400-1"]["vattenBrunn"] -eq 0 -and $s["enheter"]["SGC400-1"]["vattenSasong"] -eq 7.2 -and $s["enheter"]["SGC400-1"]["brunnSedan"] -eq $t.ToString("yyyy-MM-ddTHH:mm:ss"))
  $saved = (Acc-ToState | ConvertTo-Json -Depth 5) | ConvertFrom-Json
  Acc-FromState $saved
  Check "räkneverken överlever en omstart" ($script:acc["SGC400-1"]["sasongM3"] -gt 7.19 -and $script:acc["SGC400-1"]["brunn"] -eq 8 -and $null -eq $script:acc["SGC400-1"]["last"])
  Check "säsongen börjar 1 augusti" ((SeasonOf (Get-Date "2026-07-31")) -eq "2025/26" -and (SeasonOf (Get-Date "2026-08-01")) -eq "2026/27")
  $t2 = Get-Date "2027-08-02 10:00:00"; $s = W 5 8 $t2.ToString("yyyy-MM-ddTHH:mm:ss") $t2; Add-Water $s $t2
  Check "ny säsong: säsongens räkneverk börjar om" ($s["enheter"]["SGC400-1"]["vattenSasong"] -eq 0)
  Check "räkneverken har dödband" ((Band "enheter/SGC400-1/vattenBrunn") -eq 0.5)
  $s = W 7 8 "2027-08-02T10:00:00" $t2; $s["enheter"]["SGC400-1"]["vattenBrunn"] = 12.34
  Check "historiken får vattnet vid brunnen" ((Build-HistPatch $s $slot)["202611151805"]["e"]["SGC400-1"]["vb"] -eq 12.3)

  # Räkna bakåt.
  $ss = Get-Date "2026-08-01 00:00:00"
  $ev = @(
    [pscustomobject]@{ tid = (Get-Date "2026-11-20 18:00"); text = "Appeared  S ACCESS 300 ( adr = 8)    to  4" },
    [pscustomobject]@{ tid = (Get-Date "2026-11-25 20:00"); text = "Appeared  S ACCESS 300 ( adr = 8)    to  5" },
    [pscustomobject]@{ tid = (Get-Date "2026-11-26 04:42"); text = "Appeared  S ACCESS 300 ( adr = 8)    to  5" },
    [pscustomobject]@{ tid = (Get-Date "2026-11-26 04:00"); text = "Appeared  S ACCESS 300 ( adr = 4)    to  9" },
    [pscustomobject]@{ tid = (Get-Date "2026-11-26 03:00"); text = "Disappeared S ACCESS 300 (adr = 4) from 10" })
  $ap = Parse-Appeared $ev
  Check "journalens inkopplingar läses, med rätt enhet" ($ap.Count -eq 4 -and ($ap | Where-Object { $_.key -eq "SGC400-6" }).Count -eq 3 -and ($ap | Where-Object { $_.key -eq "SGC400-2" }).brunn -eq 9)
  Check "adress 1 är det äldre kortet" ((KeyOfAdr 1) -eq "SGC300-1" -and (KeyOfAdr 3) -eq "SGC400-1")
  $fore = Get-Date "2026-11-26 09:53:31"
  Check "kom till brunnen: första i följden vid samma brunn" ((Arrival $ap "SGC400-6" 5 $fore $ss) -eq (Get-Date "2026-11-25 20:00"))
  Check "ingen inkoppling i säsongen: sedan säsongens början" ((Arrival $ap "SGC400-1" 7 $fore $ss) -eq $ss)
  Check "senast inkopplad vid en annan brunn: okänt" ($null -eq (Arrival $ap "SGC400-6" 7 $fore $ss))
  $acc2 = @{ "SGC400-6" = @{ brunn = 5; sedan = "2026-11-26T09:53:31"; fran = "2026-11-26T09:53:31"; brunnM3 = 1.0; sasongM3 = 1.0 } }
  $rows = @(
    # Vid brunn 4: 7 m3/h i 60 min (sex rader med tio minuters mellanrum).
    0..5 | ForEach-Object { [pscustomobject]@{ key = "SGC400-6"; tid = (Get-Date "2026-11-21 02:00").AddMinutes(10 * $_); debit = 70; nxt = (Get-Date "2026-11-21 02:00").AddMinutes(10 * $_ + 10) } }
    # Vid brunn 5: 6 m3/h i 30 min, rader var tredje minut.
    0..9 | ForEach-Object { [pscustomobject]@{ key = "SGC400-6"; tid = (Get-Date "2026-11-26 05:00").AddMinutes(3 * $_); debit = 60; nxt = (Get-Date "2026-11-26 05:00").AddMinutes(3 * $_ + 3) } }
    # Glapp på en timme i statistiken: räknas inte.
    [pscustomobject]@{ key = "SGC400-6"; tid = (Get-Date "2026-11-26 06:00"); debit = 60; nxt = (Get-Date "2026-11-26 07:00") }
    # Efter att bryggan började räkna: räknas inte (det gör bryggan själv).
    [pscustomobject]@{ key = "SGC400-6"; tid = (Get-Date "2026-11-26 09:50"); debit = 60; nxt = (Get-Date "2026-11-26 10:00") }
    # Sista raden i en databas, utan nästa: räknas inte.
    [pscustomobject]@{ key = "SGC400-6"; tid = (Get-Date "2026-11-15 23:58"); debit = 60; nxt = $null })
  $res = Backfill-Compute $acc2 $rows $ap $ss
  $r6 = $res["SGC400-6"]
  # Raden 09:50 gäller till bryggans start 09:53:31: 6 m3/h i 3,52 min.
  $sista = 6.0 * ((Get-Date "2026-11-26 09:53:31") - (Get-Date "2026-11-26 09:50")).TotalHours
  Check "säsongen: båda brunnarna, inte glappet eller tiden efter start" ([math]::Abs($r6.sasong - (7.0 + 3.0 + $sista)) -lt 0.001)
  Check "brunnen: bara sedan den kom dit" ([math]::Abs($r6.brunn - (3.0 + $sista)) -lt 0.001)

  # Rätta brunnsdelen (-BakatBrunn): så som version 9 lämnade det, utan
  # inkopplingar - hela säsongen på brunnen och sedan 1 augusti - plus 0,5 m3
  # som bryggan räknat efter bakåträkningen.
  $ssS = "2026-08-01T00:00:00"
  $fel = 1.0 + $r6.sasong + 0.5
  $acc3 = @{
    "SGC400-6" = @{ brunn = 5; sedan = $ssS; fran = "2026-11-26T09:53:31"; brunnM3 = $fel; sasongM3 = $fel }
    "SGC400-7" = @{ brunn = 7; sedan = $ssS; fran = "2026-11-26T09:53:31"; brunnM3 = $fel; sasongM3 = $fel }
    "SGC400-1" = @{ brunn = 3; sedan = "2026-11-26T14:00:00"; fran = "2026-11-26T14:00:00"; brunnM3 = 0.2; sasongM3 = $fel } }
  $res3 = [ordered]@{
    "SGC400-6" = $r6
    "SGC400-7" = [pscustomobject]@{ sasong = $r6.sasong; brunn = 0.0; ankomst = $null }
    "SGC400-1" = [pscustomobject]@{ sasong = 5.0; brunn = 5.0; ankomst = $ss } }
  $null = BakatBrunn-Adjust $acc3 $res3 $ssS
  Check "rättad brunn: bara tiden sedan ankomsten, plus det räknade efteråt" ([math]::Abs($acc3["SGC400-6"]["brunnM3"] - (1.0 + $r6.brunn + 0.5)) -lt 0.001 -and $acc3["SGC400-6"]["sedan"] -eq "2026-11-25T20:00:00")
  Check "rättad brunn: säsongen rörs inte" ($acc3["SGC400-6"]["sasongM3"] -eq $fel)
  Check "rättad brunn: okänd ankomst räknas från bryggans start" ([math]::Abs($acc3["SGC400-7"]["brunnM3"] - 1.5) -lt 0.001 -and $acc3["SGC400-7"]["sedan"] -eq "2026-11-26T09:53:31")
  Check "rättad brunn: enhet som bytt brunn sedan dess lämnas" ($acc3["SGC400-1"]["brunnM3"] -eq 0.2 -and $acc3["SGC400-1"]["sedan"] -eq "2026-11-26T14:00:00")
  # Stämpeln ur rapporten, när version 9 tappat den ur tillståndsfilen.
  $td = Join-Path ([IO.Path]::GetTempPath()) ("brygga-test-" + [guid]::NewGuid().ToString("N"))
  New-Item -ItemType Directory $td | Out-Null
  try {
    @("Live_stat_octobre2SQL stat_piste_canon_SGC400: 40 rader med flöde", "Live_stat_novembre2SQL stat_piste_canon_SGC400: 171 rader med flöde", "Live_stat_novembre2SQL stat_piste_canon_SGC300: 38 rader med flöde", "Journal: 0 inkopplingar sedan 2026-08-01") | Set-Content -Path (Join-Path $td "bakat_20261126-115303.txt") -Encoding UTF8
    $stp = Bakat-Stamp ([pscustomobject]@{ lastSlot = "x" }) $td $acc3
    Check "stämpeln byggs upp ur rapporten" ($stp.rader -eq 249 -and $stp.tid -eq "2026-11-26T11:53:03" -and $stp.fran -eq "2026-08-01T00:00:00" -and $stp.till -eq "2026-11-26T14:00:00")
    Check "finns stämpeln i filen används den" ((Bakat-Stamp ([pscustomobject]@{ bakat = [pscustomobject]@{ rader = 7 } }) $td $acc3).rader -eq 7)
  } finally { Remove-Item $td -Recurse -Force }
  # Timvattnet. Statistikens tider är lokal tid utan zon; nyckeln är UTC.
  $loc = { param($s) [datetime]::SpecifyKind((Get-Date $s), [DateTimeKind]::Unspecified) }
  $tr = @(
    # 6 m3/h i tio minuter över ett timskifte: 5 min i varje timme.
    [pscustomobject]@{ key = "SGC400-1"; tid = (& $loc "2026-11-26 03:55"); debit = 60; nxt = (& $loc "2026-11-26 04:05") }
    # Två kanoner i samma timme.
    [pscustomobject]@{ key = "SGC400-1"; tid = (& $loc "2026-11-26 04:05"); debit = 60; nxt = (& $loc "2026-11-26 04:15") }
    [pscustomobject]@{ key = "SGC400-2"; tid = (& $loc "2026-11-26 04:10"); debit = 30; nxt = (& $loc "2026-11-26 04:20") }
    # Glapp över en kvart och sista raden utan nästa: räknas inte.
    [pscustomobject]@{ key = "SGC400-1"; tid = (& $loc "2026-11-26 04:15"); debit = 60; nxt = (& $loc "2026-11-26 05:15") }
    [pscustomobject]@{ key = "SGC400-1"; tid = (& $loc "2026-11-26 05:15"); debit = 60; nxt = $null })
  $ht = Hour-Totals $tr (& $loc "2026-11-26 00:00") (& $loc "2026-11-26 06:00")
  $k3 = (& $loc "2026-11-26 03:00").ToUniversalTime().ToString("yyyyMMddHH")
  $k4 = (& $loc "2026-11-26 04:00").ToUniversalTime().ToString("yyyyMMddHH")
  Check "timvattnet: en rad över timskiftet delas" ([math]::Abs($ht[$k3] - 0.5) -lt 0.001)
  Check "timvattnet: timmen summerar alla kanoner, inte glapp eller sista raden" ([math]::Abs($ht[$k4] - (0.5 + 1.0 + 0.5)) -lt 0.001 -and $ht.Count -eq 2)
  Check "timvattnet: nyckeln är UTC som historiken" ($k4 -eq "2026112603")
  $ht2 = Hour-Totals $tr (& $loc "2026-11-26 04:00") (& $loc "2026-11-26 06:00")
  Check "timvattnet: klipps vid början" (-not $ht2.ContainsKey($k3) -and [math]::Abs($ht2[$k4] - 2.0) -lt 0.001)
  Check "timmen 03 är öppen till 04:25" ((Hour-OpenFrom (Get-Date "2026-11-26 04:24")) -eq (Get-Date "2026-11-26 03:00") -and (Hour-OpenFrom (Get-Date "2026-11-26 04:26")) -eq (Get-Date "2026-11-26 04:00"))
  Check "inkoppling med blanksteg först läses" ((Parse-Appeared @([pscustomobject]@{ tid = (Get-Date "2026-11-26 04:42"); text = ("   Appeared  S ACCESS 300 ( adr = 9)    to  1").Trim() })).key -eq "SGC400-7")

  Check "flöde och tryck har dödband" ((Band "enheter/SGC400-3/flode") -eq 0.2 -and (Band "enheter/SGC400-3/tryckBor") -eq 0.2)

  # Vattentemperaturen vid drift (version 12)
  $script:driftTemp = $null; $script:driftTid = $null
  $s0 = [ordered]@{ pump = [ordered]@{ dep12 = [ordered]@{ vattenTemp = 6.0; k125 = 0.1 } } }
  Mark-DriftTemp $s0 (Get-Date "2026-11-28 09:00:00")
  Check "drift: inget att visa innan vattnet gått" (-not $s0["pump"]["dep12"].Contains("vattenTempDrift"))
  $s1 = [ordered]@{ pump = [ordered]@{ dep12 = [ordered]@{ vattenTemp = 2.4; k125 = 30.5 } } }
  Mark-DriftTemp $s1 (Get-Date "2026-11-28 09:10:41")
  Check "drift: värdet medan vattnet går" ($s1["pump"]["dep12"]["vattenTempDrift"] -eq 2.4 -and $s1["pump"]["dep12"]["vattenTempDriftTid"] -eq "2026-11-28T09:10")
  $s2 = [ordered]@{ pump = [ordered]@{ dep12 = [ordered]@{ vattenTemp = 6.3; k125 = 0.1 } } }
  Mark-DriftTemp $s2 (Get-Date "2026-11-28 11:00:00")
  Check "drift: står pumparna ligger senaste driften kvar" ($s2["pump"]["dep12"]["vattenTempDrift"] -eq 2.4 -and $s2["pump"]["dep12"]["vattenTempDriftTid"] -eq "2026-11-28T09:10" -and $s2["pump"]["dep12"]["vattenTemp"] -eq 6.3)
  Check "drift: utan pumphuset händer inget" ($null -eq (Mark-DriftTemp ([ordered]@{}) (Get-Date)))
  Check "drift: samma dödband som vattentemperaturen" ((Band "pump/dep12/vattenTempDrift") -eq 0.2)

  if ($script:bad -eq 0) { Write-Host "Självtestet gick igenom."; exit 0 }
  Write-Host ("Självtestet hittade " + $script:bad + " fel."); exit 1
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
# Bara en brygga åt gången. Den schemalagda uppgiften försöker starta en ny
# var femte minut för att bryggan ska komma tillbaka om den dött; går den
# redan ska det nya försöket bara avsluta sig.
$mutex = $null
if (-not $EnGang) {
  $created = $false
  $mutex = New-Object System.Threading.Mutex($true, "snogrupp-brygga", [ref]$created)
  if (-not $created) { Write-Host "Bryggan går redan. Avslutar."; exit 0 }
}

$lastSlot = $null
if (Test-Path $stateFile) {
  try {
    $st = Get-Content $stateFile -Raw | ConvertFrom-Json
    $lastSlot = [datetime]::SpecifyKind([datetime]::ParseExact($st.lastSlot, "yyyyMMddHHmm", $null), [DateTimeKind]::Utc)
    Acc-FromState $st.vatten
    $script:bakatStamp = $st.bakat
    if ($st.timmeFran) { $script:timmeFran = [datetime]::ParseExact($st.timmeFran, "yyyy-MM-ddTHH:mm:ss", $null) }
    if ($null -ne $st.driftTemp) { $script:driftTemp = [double]$st.driftTemp; $script:driftTid = [string]$st.driftTid }
  } catch { $lastSlot = $null }
}
$script:timmeNasta = [datetime]::MinValue

# Timvattnet, se Hour-Totals. Fel här får aldrig stoppa resten av bryggan:
# nästa runda börjar från samma timme och tar igen det.
function Update-HourWater([datetime]$now) {
  if ($now -lt $script:timmeNasta) { return }
  $script:timmeNasta = $now.AddMinutes(10)
  $open = Hour-OpenFrom $now
  $from = $script:timmeFran
  if ($null -eq $from) {
    $y = $now.Year; if ($now.Month -lt 8) { $y-- }
    $from = Get-Date -Year $y -Month 8 -Day 1 -Hour 0 -Minute 0 -Second 0
  }
  if ($open -lt $from) { $from = $open }
  # Raderna en kvart före, så att en rad som börjar före timmen och gäller
  # in i den kommer med (Hour-Totals klipper vid $from).
  $rows = Stat-Rows ($from.AddMinutes(-15)) $now $null
  $h = Hour-Totals $rows $from $now
  $body = [ordered]@{}
  foreach ($k in ($h.Keys | Sort-Object)) { if ($h[$k] -ge 0.005) { $body[$k] = [math]::Round($h[$k], 2) } }
  if ($body.Count -gt 0) { Send-Cloud "Patch" "vattenTimme" $body }
  $first = ($null -eq $script:timmeFran)
  $script:timmeFran = $open
  Save-State
  if ($first) { Log ("Timvattnet: hela säsongen räknad, " + $body.Count + " timmar med vatten, sedan " + $from.ToString("yyyy-MM-dd")) }
}
# Räkneverken sparas var femte minut med historikpunkten, och bara när
# bryggan skickar - en -EnGang i torrläge bredvid den riktiga får inte
# skriva över dem. Stämpeln "bakat" följer med oförändrad; version 9 lät
# den falla bort, och då vet varken -Bakat eller -BakatBrunn vad som gjorts.
function Save-State {
  if (-not $Skicka) { return }
  $o = [ordered]@{ lastSlot = (SlotKey $lastSlot); vatten = (Acc-ToState) }
  if ($script:bakatStamp) { $o["bakat"] = $script:bakatStamp }
  if ($script:timmeFran) { $o["timmeFran"] = $script:timmeFran.ToString("yyyy-MM-ddTHH:mm:ss") }
  if ($null -ne $script:driftTemp) { $o["driftTemp"] = $script:driftTemp; $o["driftTid"] = $script:driftTid }
  (ConvertTo-Json -InputObject $o -Depth 5 -Compress) | Set-Content -Path $stateFile -Encoding ASCII
}

Log ("Bryggan startar (version " + $VERSION + ", konto " + $SqlUser + ", " + $(if ($Skicka) { "skickar till molnet" } else { "torrläge" }) + ")")
if ($avsteg) { Log "AVSTEG: går med GSS_Login, som kan skriva i styrsystemets databaser. Bryggan läser bara. Byt till snogrupp_ro så snart kontot finns." }
$fails = 0
while ($true) {
  $t0 = Get-Date
  $snap = [ordered]@{}
  try {
    if (-not $script:conn -or $script:conn.State -ne "Open") { Close-Sql; Open-Sql }
    $snap = Read-Snapshot
    $fails = 0
  } catch {
    $fails++
    Log ("SQL-fel: " + $_.Exception.Message)
    Close-Sql
    $snap = [ordered]@{}
  }
  $sqlOk = ($fails -eq 0)
  $now = Get-Date
  $ms = [int]($now - $t0).TotalMilliseconds
  if ($sqlOk) { try { Add-Water $snap $now } catch { Log ("Kunde inte räkna vattnet: " + $_.Exception.Message) } }
  if ($sqlOk) { try { Mark-DriftTemp $snap $now } catch { Log ("Vattentemperaturen vid drift: " + $_.Exception.Message) } }

  try {
    $plan = Plan-Round $snap $sqlOk $now $ms
    if ($Skicka) {
      if ($plan.kind -eq "full")  { Send-Cloud "Put"   "live" $plan.body }
      if ($plan.kind -eq "patch") { Send-Cloud "Patch" "live" $plan.body }
    } else {
      # Torrläge: hela nuläget i en fil, och i loggen vad som SKULLE ha
      # skickats - så att ändringslogiken går att se innan den släpps lös.
      $file = [ordered]@{}
      foreach ($k in $snap.Keys) { $file[$k] = $snap[$k] }
      $file["meta"] = [ordered]@{ lokalTid = $now.ToString("yyyy-MM-ddTHH:mm:ss"); sqlOk = $sqlOk; lasMs = $ms; version = $VERSION }
      (ConvertTo-Json -InputObject $file -Depth 8) | Set-Content -Path $outFile -Encoding UTF8
    }
    Commit-Round $plan $sqlOk $now
    $dry = ""; if (-not $Skicka) { $dry = " (torrläge, inget skickat)" }
    if ($plan.kind -eq "full") { Log ("Hela nuläget, " + $plan.n + " fält" + $dry) }
    if ($plan.kind -eq "patch" -and $plan.n -gt 0) {
      $names = @($plan.body.Keys | Where-Object { $_ -notlike "meta/*" })
      $show = ($names | Select-Object -First 6) -join ", "
      if ($names.Count -gt 6) { $show += " ..." }
      Log ("" + $plan.n + " ändring(ar)" + $dry + ": " + $show)
    }

    # Historikpunkten för graferna, på jämna fem minuter.
    if ($Skicka -and $sqlOk) {
      $slot = SlotOf ([datetime]::UtcNow)
      if ($null -eq $lastSlot -or $slot -gt $lastSlot) {
        Send-Cloud "Patch" "hist" (Build-HistPatch $snap $slot)
        $lastSlot = $slot
        Save-State
      }
      try { Update-HourWater $now } catch { Log ("Timvattnet: " + $_.Exception.Message) }
    }
    if ($EnGang) { Log ("Klart på " + $ms + " ms. Resultatet ligger i " + $outFile) }
  } catch {
    Log ("Kunde inte lämna ifrån mig datan: " + $_.Exception.Message)
    # Inloggningen kan ha gått ut; logga in på nytt nästa varv.
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
if ($mutex) { try { $mutex.ReleaseMutex() } catch { } }
if ($fails -gt 0) { exit 1 }
