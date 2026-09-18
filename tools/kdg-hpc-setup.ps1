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
Write-Ok ((ssh -V 2>&1) -join ' ')

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
icacls $KeyPath /inheritance:r /grant:r "*${sid}:(R,W)" 2>&1 | Out-Null
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

$out = ssh -n -o PreferredAuthentications=password,keyboard-interactive `
           -o PubkeyAuthentication=no `
           "$User@$ClusterHost" $remote 2>&1
if ($LASTEXITCODE -ne 0 -or ($out -notmatch 'SLEUTEL_GEPLAATST')) {
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
$test = ssh -n -o BatchMode=yes -o ConnectTimeout=15 $Alias "echo LOGIN_OK; hostname" 2>&1
if ($test -match 'LOGIN_OK') {
    Write-Ok "Verbinding werkt zonder wachtwoord"
    Write-Info ("Loginnode: " + (($test | Where-Object { $_ -notmatch 'LOGIN_OK' }) -join ''))
} else {
    Write-Warn2 "De automatische test slaagde niet."
    Write-Host ($test -join "`n") -ForegroundColor DarkGray
    Write-Warn2 "Als je sleutel een passphrase heeft, is dit normaal. Probeer handmatig: ssh $Alias"
}

Write-Host ""
# ------------------------------------------ 8. Initieel wachtwoord vervangen
Write-Step "Initieel wachtwoord vervangen (aanbevolen)"
Write-Info "Je sleutel werkt nu. Voor SSH heb je het wachtwoord niet meer nodig,"
Write-Info "maar het blijft je noodingang. Vervang het startwachtwoord dus door"
Write-Info "een sterk, uniek wachtwoord en bewaar dat in je passwordmanager."

function New-StrongPassword {
    param([int]$Length = 24)
    # Cryptografisch veilige generator met rejection sampling: bytes boven de
    # laatste volledige veelvoud van de alfabetlengte worden weggegooid, anders
    # zouden de eerste tekens van het alfabet vaker voorkomen (modulo-bias).
    $chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-_.!@#%+='
    $max   = [math]::Floor(256 / $chars.Length) * $chars.Length
    $rng   = [System.Security.Cryptography.RandomNumberGenerator]::Create()
    try {
        $byte = New-Object byte[] 1
        $sb   = New-Object System.Text.StringBuilder
        while ($sb.Length -lt $Length) {
            $rng.GetBytes($byte)
            if ($byte[0] -lt $max) { [void]$sb.Append($chars[$byte[0] % $chars.Length]) }
        }
        $sb.ToString()
    } finally { $rng.Dispose() }
}

$answer = Read-Host "    Nu een sterk wachtwoord genereren? [J/n]"
if ($answer -eq '' -or $answer -match '^[JjYy]') {
    $newPw = New-StrongPassword -Length 24
    $clipped = $false
    try { Set-Clipboard -Value $newPw -ErrorAction Stop; $clipped = $true } catch { }

    Write-Host ""
    Write-Host "    Nieuw wachtwoord: " -NoNewline -ForegroundColor White
    Write-Host $newPw -ForegroundColor White
    if ($clipped) { Write-Info "(ook naar je klembord gekopieerd)" }
    Write-Host ""
    Write-Warn2 "Bewaar dit NU in je passwordmanager. Het staat in je terminal-"
    Write-Warn2 "geschiedenis, dus sluit dit venster daarna."
    Write-Host ""
    Write-Info "De server vraagt zo eerst je HUIDIGE (initiele) wachtwoord,"
    Write-Info "daarna tweemaal het nieuwe. Plakken met rechtermuisknop werkt."
    Write-Host ""

    ssh -t $Alias passwd
    if ($LASTEXITCODE -eq 0) {
        Write-Ok "Wachtwoord gewijzigd"
    } else {
        Write-Warn2 "Wachtwoord wijzigen is niet gelukt. Je sleutel werkt nog steeds."
        Write-Warn2 "Probeer later opnieuw met: ssh $Alias passwd"
    }
    $newPw = $null
} else {
    Write-Info "Overgeslagen. Wijzig het later met: ssh $Alias passwd"
}

Write-Host "  Klaar." -ForegroundColor Green
Write-Host ""
Write-Host "  Terminal      : ssh $Alias"
Write-Host "  VS Code/Cursor: Remote-SSH: Connect to Host... > $Alias"
Write-Host "  PyCharm       : Settings > Tools > SSH Configurations > $Alias"
Write-Host ""
Write-Host "  Vergeet niet je initiele wachtwoord te wijzigen met 'passwd' op de server." -ForegroundColor Yellow
Write-Host ""
