#Requires -Version 5.1
<#
.SYNOPSIS
    Zet in een keer je SSH-toegang tot de KdG HPC-cluster op (Windows).
.DESCRIPTION
    - Controleert de OpenSSH-client en de VPN-verbinding
    - Maakt een ed25519-sleutelpaar aan (als je er nog geen hebt)
    - Plaatst je publieke sleutel op de loginnode (eenmalig wachtwoord nodig)
    - Schrijft een net blok in ~/.ssh/config voor VS Code / Cursor / PyCharm
    - Verifieert dat wachtwoordloos inloggen werkt
    Het script is idempotent: opnieuw draaien is veilig.
.EXAMPLE
    .\kdg-hpc-setup.ps1
.EXAMPLE
    .\kdg-hpc-setup.ps1 -User jan.janssens
#>
[CmdletBinding()]
param(
    [string]$User,
    [string]$ClusterHost = 'compute.kdg.be',
    [string]$Alias       = 'kdg-compute',
    [string]$KeyPath     = "$env:USERPROFILE\.ssh\id_ed25519"
)

$ErrorActionPreference = 'Stop'
# Zonder dit tekent Test-NetConnection een voortgangsbalk over de rest van het
# scherm heen -- inclusief de wachtwoordprompt van ssh, die een paar stappen
# later verschijnt. De gebruiker ziet dan "password: ttempting TCP connect".
$ProgressPreference = 'SilentlyContinue'
$script:Step = 0

# Windows PowerShell 5.1 maakt van elke regel die een extern commando naar
# stderr schrijft een FOUT zodra $ErrorActionPreference op Stop staat -- ook
# als het commando gewoon slaagt. `ssh -V` schrijft zijn versie naar stderr,
# dus daar liep het meteen op vast. PowerShell 7 doet dat niet, vandaar dat
# het bij de ene wel werkt en bij de andere niet.
function Invoke-Native {
    param([Parameter(Mandatory)][scriptblock]$Command)
    $prev = $ErrorActionPreference
    $ErrorActionPreference = "Continue"
    try { & $Command 2>&1 | ForEach-Object { "$_" } }
    finally { $ErrorActionPreference = $prev }
}

function Write-Step  { $script:Step++; Write-Host ""; Write-Host "[$script:Step] $args" -ForegroundColor Cyan }
function Write-Ok    { Write-Host "    OK  $args" -ForegroundColor Green }
function Write-Info  { Write-Host "    ..  $args" -ForegroundColor DarkGray }
function Write-Warn2 { Write-Host "    !   $args" -ForegroundColor Yellow }
function Die         { Write-Host ""; Write-Host "FOUT: $args" -ForegroundColor Red; Write-Host ""; exit 1 }

Write-Host ""
Write-Host "  KdG HPC - SSH setup" -ForegroundColor White
Write-Host "  ===================" -ForegroundColor White

# ---------------------------------------------------------------- 1. OpenSSH
Write-Step "OpenSSH-client controleren"
foreach ($exe in 'ssh.exe','ssh-keygen.exe') {
    if (-not (Get-Command $exe -ErrorAction SilentlyContinue)) {
        Die @"
$exe is niet gevonden.

Installeer de OpenSSH-client (eenmalig, vereist beheerdersrechten):
    Add-WindowsCapability -Online -Name OpenSSH.Client~~~~0.0.1.0

Of via Windows Instellingen > Systeem > Optionele onderdelen > Onderdeel toevoegen > OpenSSH Client.
"@
    }
}
Write-Ok ((Invoke-Native { ssh -V }) -join " ")

# ------------------------------------------------------------- 2. Username
Write-Step "Accountnaam"
if (-not $User) {
    $User = (Read-Host "    Je KdG HPC-accountnaam").Trim()
}
if ($User -notmatch '^[A-Za-z0-9._-]+$') { Die "Ongeldige accountnaam: '$User'" }
Write-Ok "Account: $User"

# ------------------------------------------------------- 3. Bereikbaarheid
Write-Step "Verbinding met $ClusterHost controleren (VPN)"
$reach = Test-NetConnection -ComputerName $ClusterHost -Port 22 -InformationLevel Quiet -WarningAction SilentlyContinue
if (-not $reach) {
    Die @"
$ClusterHost is niet bereikbaar op poort 22.

Verbind eerst met de KdG GlobalProtect VPN (of gebruik het KdG-netwerk)
en start dit script daarna opnieuw.
"@
}
Write-Ok "$ClusterHost bereikbaar"

# ------------------------------------------------------------- 4. Sleutel
Write-Step "SSH-sleutel"
$sshDir = Split-Path $KeyPath -Parent
if (-not (Test-Path $sshDir)) { New-Item -ItemType Directory -Path $sshDir -Force | Out-Null }

if (Test-Path $KeyPath) {
    Write-Ok "Bestaande sleutel gevonden: $KeyPath"
} else {
    Write-Info "Er wordt een nieuw ed25519-sleutelpaar aangemaakt."
    Write-Info "Je mag bij de passphrase-vraag gewoon Enter drukken (geen passphrase),"
    Write-Info "of een passphrase kiezen voor extra beveiliging."
    Write-Host ""
    ssh-keygen -t ed25519 -f $KeyPath -C "$User@$env:COMPUTERNAME"
    if ($LASTEXITCODE -ne 0 -or -not (Test-Path $KeyPath)) { Die "ssh-keygen is mislukt." }
    Write-Ok "Sleutel aangemaakt"
}

# Rechten op de prive-sleutel dichttimmeren; OpenSSH weigert een te ruim leesbare sleutel.
$sid = ([Security.Principal.WindowsIdentity]::GetCurrent()).User.Value
Invoke-Native { icacls $KeyPath /inheritance:r /grant:r "*${sid}:(R,W)" } | Out-Null
Write-Ok "Bestandsrechten op de prive-sleutel gecorrigeerd"

$pub = (Get-Content -Raw "$KeyPath.pub").Trim()
if ($pub -notmatch '^(ssh-ed25519|ssh-rsa|ecdsa-[a-z0-9-]+) [A-Za-z0-9+/=]+( [^\r\n'']*)?$') {
    Die "De publieke sleutel ziet er niet geldig uit: $KeyPath.pub"
}

# --------------------------------------------------------- 5. Sleutel uploaden
Write-Step "Publieke sleutel naar de loginnode kopieren"
Write-Info "Hierna vraagt de server EENMALIG je wachtwoord."
Write-Info "Je typt het rechtstreeks in bij de SSH-prompt; dit script ziet het niet."
Write-Host ""

$remote = "umask 077; mkdir -p ~/.ssh; touch ~/.ssh/authorized_keys; chmod 700 ~/.ssh; chmod 600 ~/.ssh/authorized_keys; grep -qxF '$pub' ~/.ssh/authorized_keys || echo '$pub' >> ~/.ssh/authorized_keys; echo SLEUTEL_GEPLAATST"

$out = Invoke-Native {
    ssh -n -o PreferredAuthentications=password,keyboard-interactive `
        -o PubkeyAuthentication=no `
        "$User@$ClusterHost" $remote
}
# Let op: $out is een array regels, en -match/-notmatch filtert een array in
# plaats van een ja/nee te geven. Bij een mislukte eerste wachtwoordpoging
# blijven er regels over die de melding niet bevatten, en dan zou een niet-lege
# lijst hier als "waar" gelden -- fout gemeld terwijl de sleutel er wel staat.
# Eerst samenvoegen tot een tekstblok maakt de vergelijking een echte test.
$outText = ($out | Out-String)
if ($outText -notmatch 'SLEUTEL_GEPLAATST') {
    Write-Host ($out -join "`n") -ForegroundColor DarkGray
    Die "Kopieren van de sleutel is mislukt. Klopt je accountnaam en wachtwoord?"
}
Write-Ok "Publieke sleutel staat in ~/.ssh/authorized_keys op de server"

# ------------------------------------------------------------ 6. ssh config
Write-Step "~/.ssh/config bijwerken"
$cfgPath = Join-Path $sshDir 'config'
$begin = "# >>> $Alias (KdG HPC) >>>"
$end   = "# <<< $Alias (KdG HPC) <<<"
$keyForCfg = $KeyPath -replace '\','/'

$block = @"
$begin
Host $Alias
    HostName $ClusterHost
    User $User
    IdentityFile $keyForCfg
    IdentitiesOnly yes
    AddKeysToAgent yes
    ServerAliveInterval 60
$end
"@

if (Test-Path $cfgPath) {
    $existing = Get-Content -Raw $cfgPath
    if ($existing -match [regex]::Escape($begin)) {
        Copy-Item $cfgPath "$cfgPath.bak" -Force
        $pattern = '(?ms)' + [regex]::Escape($begin) + '.*?' + [regex]::Escape($end) + '\r?\n?'
        $existing = [regex]::Replace($existing, $pattern, '')
        Write-Info "Bestaand blok vervangen (back-up: config.bak)"
    }
    $new = $existing.TrimEnd() + "`r`n`r`n" + $block
} else {
    $new = $block
}
Set-Content -Path $cfgPath -Value $new -Encoding ASCII
Write-Ok "Host '$Alias' toegevoegd aan $cfgPath"

# -------------------------------------------------------------- 7. Verifieren
Write-Step "Wachtwoordloos inloggen testen"
$test = Invoke-Native { ssh -n -o BatchMode=yes -o ConnectTimeout=15 $Alias "echo LOGIN_OK; hostname" }
$testText = ($test | Out-String)
if ($testText -match 'LOGIN_OK') {
    Write-Ok "Verbinding werkt zonder wachtwoord"
    Write-Info ("Loginnode: " + (($test | Where-Object { $_ -notmatch 'LOGIN_OK' }) -join ''))
} else {
    Write-Warn2 "De automatische test slaagde niet."
    Write-Host ($test -join "`n") -ForegroundColor DarkGray
    Write-Warn2 "Als je sleutel een passphrase heeft, is dit normaal. Probeer handmatig: ssh $Alias"
}

Write-Host ""
Write-Host "  Klaar." -ForegroundColor Green
Write-Host ""
Write-Host "  Terminal      : ssh $Alias"
Write-Host "  VS Code/Cursor: Remote-SSH: Connect to Host... > $Alias"
Write-Host "  PyCharm       : Settings > Tools > SSH Configurations > $Alias"
Write-Host ""
Write-Host ""
Write-Host "  Bewaar de mail met je wachtwoord: die heb je nodig als je ooit je" -ForegroundColor DarkGray
Write-Host "  sleutel kwijt bent. Om in te loggen heb je hem niet meer nodig." -ForegroundColor DarkGray
Write-Host ""
