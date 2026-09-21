# Toegang tot de KdG HPC-cluster

*[English version](en.md) · [terug naar de startpagina](../README.md)*

Je hebt een accountnaam en een eenmalig wachtwoord gekregen van het HPC-team.
Hieronder zet je in ongeveer twee minuten je toegang op.

| | |
|---|---|
| **Loginnode (SSH)** | `compute.kdg.be` |
| **Webportal** | Open OnDemand, via een tunnel (zie [stap 5](#5-de-grafische-omgeving)) |
| **Planner** | Slurm — `sbatch`, `srun`, `squeue` |

---

## 1. Verbind met het netwerk

De cluster is alleen bereikbaar vanaf het KdG-netwerk.

- **Op de campus:** verbind met het wifi-netwerk `KdG`.
- **Van thuis:** zet de **GlobalProtect VPN** aan —
  [instructies](https://studentkdg.sharepoint.com/sites/intranet-nl-ict/SitePages/GlobalProtect-(VPN).aspx)

Zonder een van beide werkt niets van wat hieronder staat.

---

## 2. Draai één commando

Open de terminal van je besturingssysteem en plak het commando voor jouw
platform. Gebruik daarvoor **Windows Terminal, PowerShell of Terminal.app**,
niet een terminalvenster binnen een andere toepassing — plakken werkt daar niet
altijd, en je hebt zo je wachtwoord nodig.

**Windows (PowerShell)**

```powershell
irm https://raw.githubusercontent.com/KdG-OCDI/hpc-public/main/tools/kdg-hpc-setup.ps1 | iex
```

**macOS of Linux (Terminal)**

```bash
curl -fsSL https://raw.githubusercontent.com/KdG-OCDI/hpc-public/main/tools/kdg-hpc-setup.sh | bash
```

Wil je eerst zien wat het script doet? Haal het dan eerst op en lees het:

```bash
curl -fsSL https://raw.githubusercontent.com/KdG-OCDI/hpc-public/main/tools/kdg-hpc-setup.sh -o kdg-hpc-setup.sh
less kdg-hpc-setup.sh && bash kdg-hpc-setup.sh
```

Het script vraagt je accountnaam, en daarna **eenmalig** je wachtwoord bij de
prompt van de server. Dat wachtwoord gaat rechtstreeks naar de cluster; het
script leest of bewaart het niet.

Opnieuw draaien is altijd veilig — het script past niets dubbel toe.

### Wat het script doet

| Stap | Actie |
|---|---|
| 1 | Controleert of de OpenSSH-client aanwezig is |
| 2 | Vraagt je accountnaam |
| 3 | Controleert of `compute.kdg.be` bereikbaar is — vangt "VPN vergeten" af |
| 4 | Maakt een `ed25519`-sleutelpaar aan in `~/.ssh/` als je er nog geen hebt |
| 5 | Zet je **publieke** sleutel op de loginnode |
| 6 | Voegt een `kdg-compute`-blok toe aan je lokale `~/.ssh/config` |
| 7 | Test of wachtwoordloos inloggen werkt |
| 8 | Biedt aan je wachtwoord te vervangen door een sterk, willekeurig exemplaar |

Je **private** sleutel verlaat je laptop nooit.

---

## 3. Verbinden

```bash
ssh kdg-compute
```

`kdg-compute` is de naam die het script in je `~/.ssh/config` heeft gezet — geen
adres op het internet. Heb je stap 2 niet gedraaid, gebruik dan je accountnaam
en het echte adres:

```bash
ssh jouw_accountnaam@compute.kdg.be
```

**In je editor:**

- **VS Code / Cursor** — installeer de extensie
  [Remote - SSH](https://marketplace.visualstudio.com/items?itemName=ms-vscode-remote.remote-ssh),
  dan `Ctrl+Shift+P` → *Remote-SSH: Connect to Host...* → `kdg-compute`
- **PyCharm** — *Settings → Tools → SSH Configurations* → `kdg-compute`

Vanaf daar open je mappen op de server en dien je jobs in met Slurm.

---

## 4. Je wachtwoord

Stap 8 van het script genereert een sterk wachtwoord en zet het op je klembord.
**Bewaar het in je wachtwoordbeheerder.** Na deze setup heb je het voor SSH niet
meer nodig, maar het is je noodingang als je ooit je sleutel kwijt bent.

Sla je stap 8 over, wijzig je wachtwoord dan later alsnog:

```bash
ssh kdg-compute passwd
```

---

## 5. De grafische omgeving

Voor Jupyter-notebooks in je browser. Dit heeft een werkend SSH-account nodig,
dus doe eerst stap 2.

De portal draait op een adres dat alleen binnen het clusternetwerk bestaat. Je
browser kan die naam niet vinden, ook niet met VPN. Daarom stuur je je
browserverkeer door een tunnel die de naam aan de clusterkant laat opzoeken.

### Stap 1 — open de tunnel

```bash
ssh -N -D 9090 kdg-compute
```

Dit commando blokkeert en geeft geen uitvoer. Dat hoort zo: laat het venster
open zolang je de portal gebruikt. Elk poortnummer boven 1024 mag in plaats van
9090.

### Stap 2 — stuur je browser door de tunnel

Gebruik hiervoor [FoxyProxy](https://addons.mozilla.org/nl/firefox/addon/foxyproxy-standard/),
beschikbaar voor Firefox, Chrome en Edge. Dat kan ook via de instellingen van
je besturingssysteem, maar dan gaat **al** je internetverkeer door de cluster —
inclusief je gewone browsen. FoxyProxy laat je het beperken tot alleen het
clusteradres.

Maak een proxy aan van het type **SOCKS5**, met host `localhost` en poort
`9090`:

![FoxyProxy-instellingen](../images/foxyproxy.png)

Voeg daarna een regel toe van het type *wildcard* met dit patroon, en kies
**Proxy by Patterns**:

```
://controller1.cluster:*
```

![FoxyProxy-patronen](../images/foxyproxy_patterns.png)

> **Belangrijk bij SOCKS5:** de naam `controller1.cluster` moet aan de
> clusterkant opgezocht worden, niet op je laptop. In Firefox is dat het
> aanvinkvakje *Proxy DNS when using SOCKS v5*; FoxyProxy zet dat zelf goed.
> Doe je het via je systeeminstellingen, dan werkt het vaak niet om precies
> deze reden.

### Stap 3 — open de portal

Ga naar [https://controller1.cluster:8080](https://controller1.cluster:8080) en
klik op **Azure SSO Login** om met je schoolaccount aan te melden.

![Aanmeldpagina](../images/login_page.png)

### Stap 4 — start een notebook

Klik op de startpagina op **Jupyter notebook** onder *Interactive Apps*.

- Vul je accountnaam in.
- Kies een partitie:
  - `defg` — de hele cluster, gedeeld. Kies het aantal nodes dat je nodig hebt,
    maximaal 8.
  - `single_node` — alleen `node001`, om te debuggen.
- Klik **Connect**. Je komt in je eigen map terecht.

Je start in Jupyter Classic; via *View → Lab* schakel je over naar JupyterLab.

E-mailmeldingen zijn nog niet ingesteld.

### Als je klaar bent

Sluit de tunnel met `Ctrl+C` en zet FoxyProxy weer uit.

> Dit hele hoofdstuk verdwijnt zodra de portal een adres krijgt dat over de VPN
> werkt. Dan typ je gewoon een adres in je browser, zonder tunnel en zonder
> extensie.

---

## 6. Geen toegang meer?

Nieuwe laptop of sleutel kwijt? Draai het setupscript gewoon opnieuw op je
nieuwe toestel — daarvoor heb je wel je wachtwoord nodig.

Ben je dat ook kwijt, neem dan contact op met het HPC-team. Je identiteit wordt
gecontroleerd via je KdG-schoolaccount.

---

## 7. Problemen oplossen

Draai `ssh -v kdg-compute` — die uitvoer laat zien welke sleutel is aangeboden
en wat de server ermee deed.

| Melding | Oorzaak en oplossing |
|---|---|
| `compute.kdg.be is niet bereikbaar` | VPN staat niet aan, of is nog aan het verbinden |
| `ssh.exe is niet gevonden` (Windows) | Draai `Add-WindowsCapability -Online -Name OpenSSH.Client~~~~0.0.1.0` in een PowerShell **als administrator** |
| `Permission denied` bij het wachtwoord | Accountnaam of eenmalig wachtwoord klopt niet — neem contact op |
| `Permission denied (publickey)` | Je sleutel staat niet op de server. Draai stap 2 opnieuw |
| `WARNING: UNPROTECTED PRIVATE KEY FILE` | Je private sleutel is te ruim leesbaar: `chmod 600 ~/.ssh/id_ed25519` |
| Sleutel wordt genegeerd, zonder melding | `sshd` weigert `~/.ssh` bij te ruime rechten: `chmod 700 ~/.ssh` |
| `Could not resolve hostname kdg-compute` | Je hebt stap 2 niet gedraaid — gebruik het volledige adres |
| De test in stap 7 faalt | Normaal als je een passphrase op je sleutel zette; test met `ssh kdg-compute` |
| Portal onbereikbaar, tunnel staat open | FoxyProxy staat uit, of de naam wordt lokaal opgezocht (zie stap 5) |

Lukt het niet? Open een issue met de **volledige uitvoer** van het script erbij —
die bevat geen geheimen.

---

## Meer

- [Handmatige SSH-installatie](../Setup%20SSH.md) — WSL, ssh-agent, meerdere
  sleutels, en wat het script onder water doet
