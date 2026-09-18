# Toegang tot de KdG HPC-cluster

Je hebt van ons een accountnaam en een eenmalig wachtwoord gekregen.
Met onderstaand commando zet je in ongeveer twee minuten je toegang op.

## Voor je begint

1. Verbind met de **KdG GlobalProtect VPN** (of zit op het KdG-netwerk).
2. Hou je accountnaam en eenmalig wachtwoord bij de hand.

## Setup

### macOS / Linux

Open **Terminal** en plak:

```bash
curl -fsSL https://raw.githubusercontent.com/KdG-OCDI/hpc-public/main/tools/kdg-hpc-setup.sh | bash
```

### Windows

Open **PowerShell** en plak:

```powershell
irm https://raw.githubusercontent.com/KdG-OCDI/hpc-public/main/tools/kdg-hpc-setup.ps1 | iex
```

Het script vraagt je accountnaam, en daarna **eenmalig** je wachtwoord bij de
SSH-prompt van de server. Dat wachtwoord gaat rechtstreeks naar de server;
het script leest of bewaart het niet.

Opnieuw draaien is altijd veilig — het script past niets dubbel toe.

## Wat het script doet

| Stap | Actie |
|---|---|
| 1 | Controleert of de OpenSSH-client aanwezig is |
| 2 | Vraagt je accountnaam |
| 3 | Controleert of `compute.kdg.be` bereikbaar is (VPN-check) |
| 4 | Maakt een `ed25519`-sleutelpaar aan in `~/.ssh/` als je er nog geen hebt |
| 5 | Zet je **publieke** sleutel in `~/.ssh/authorized_keys` op de loginnode |
| 6 | Voegt een `kdg-compute`-blok toe aan je lokale `~/.ssh/config` |
| 7 | Test of wachtwoordloos inloggen werkt |
| 8 | Biedt aan je initiële wachtwoord te vervangen door een sterk, willekeurig wachtwoord |

Je **private** sleutel verlaat je laptop nooit.

## Daarna

```bash
ssh kdg-compute
```

- **VS Code / Cursor** — extensie *Remote - SSH* → `Connect to Host...` → `kdg-compute`
- **PyCharm** — *Settings → Tools → SSH Configurations* → `kdg-compute`

### Je wachtwoord

Stap 8 genereert een sterk wachtwoord en zet het op je klembord. **Bewaar het in je
passwordmanager** — je hebt het na deze setup niet meer nodig voor SSH, maar het is
je noodingang als je ooit je sleutel kwijt bent.

Sla je stap 8 over, wijzig je initiële wachtwoord dan later zelf:

```bash
ssh kdg-compute passwd
```

## Geen toegang meer?

Nieuwe laptop, sleutel kwijt of wachtwoord vergeten? Draai het setupscript gewoon
opnieuw op je nieuwe toestel — je hebt daarvoor wel je wachtwoord nodig.

Ben je dat ook kwijt, neem dan contact op met het HPC-team. Je identiteit wordt
gecontroleerd via je KdG-schoolaccount.

## Problemen

| Melding | Oplossing |
|---|---|
| `compute.kdg.be is niet bereikbaar` | VPN niet actief, of nog aan het verbinden |
| `ssh.exe is niet gevonden` (Windows) | `Add-WindowsCapability -Online -Name OpenSSH.Client~~~~0.0.1.0` in een PowerShell **als administrator** |
| `Permission denied` bij het wachtwoord | Accountnaam of eenmalig wachtwoord klopt niet — neem contact op |
| De test in stap 7 faalt | Normaal als je een passphrase op je sleutel zette; test met `ssh kdg-compute` |

Lukt het niet? Stuur de volledige uitvoer van het script mee in je bericht.
