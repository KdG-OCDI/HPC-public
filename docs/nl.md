# Toegang tot de KdG HPC-cluster

*[English version](en.md) · [terug naar de startpagina](../README.md)*

Je hebt per mail een accountnaam en een wachtwoord gekregen van het HPC-team.
Hieronder zet je in ongeveer twee minuten je toegang op.

| | |
|---|---|
| **Loginnode (SSH)** | `compute.kdg.be` |
| **Je map op de cluster** | `/trinity/home/jouw_accountnaam`, zichtbaar op alle nodes |
| **Planner** | Slurm — `sbatch`, `srun`, `squeue` |
| **Webportal** | Open OnDemand, via een tunnel (zie [5.4](#54-een-jupyter-notebook-via-de-portal)) |

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

Wil je eerst zien wat het script doet? Haal het dan op en lees het:

```bash
curl -fsSL https://raw.githubusercontent.com/KdG-OCDI/hpc-public/main/tools/kdg-hpc-setup.sh -o kdg-hpc-setup.sh
less kdg-hpc-setup.sh && bash kdg-hpc-setup.sh
```

Het script vraagt je accountnaam, en daarna **eenmalig** het wachtwoord uit die
mail, bij de prompt van de server. Dat wachtwoord gaat rechtstreeks naar de
cluster; het script leest of bewaart het niet.

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

Je **private** sleutel verlaat je laptop nooit.

---

## 3. Test je verbinding

```bash
ssh kdg-compute
```

Je komt nu zonder wachtwoord op de loginnode terecht. Verlaten doe je met
`exit`.

`kdg-compute` is de naam die het script in je `~/.ssh/config` heeft gezet — geen
adres op het internet. Heb je stap 2 niet gedraaid, gebruik dan je accountnaam
en het echte adres:

```bash
ssh jouw_accountnaam@compute.kdg.be
```

---

## 4. Je wachtwoord

Je hebt het wachtwoord uit de mail nog één keer nodig gehad, in stap 2. Daarna
niet meer: inloggen gaat vanaf nu met je sleutel.

**Bewaar die mail toch**, of zet het wachtwoord in je wachtwoordbeheerder. Het
is je noodingang voor als je ooit je sleutel kwijt bent.

Wil je het vervangen door iets eigens, dan kan dat zodra je verbinding werkt:

```bash
ssh kdg-compute passwd
```

---

## 5. Werken op de cluster

Er zijn twee manieren, en de meeste mensen gebruiken de eerste.

### 5.1 Met VS Code, Cursor of PyCharm

Je bewerkt bestanden op de cluster alsof ze lokaal staan, met je eigen editor,
extensies en sneltoetsen. Je terminal draait op de cluster.

**VS Code of Cursor**

1. Installeer de extensie
   [Remote - SSH](https://marketplace.visualstudio.com/items?itemName=ms-vscode-remote.remote-ssh).
2. `Ctrl+Shift+P` → *Remote-SSH: Connect to Host...* → `kdg-compute`.
3. Er opent een nieuw venster. Linksonder staat **SSH: kdg-compute**.
4. *File → Open Folder* → je eigen map, bijvoorbeeld
   `/trinity/home/jouw_accountnaam`.
5. *Terminal → New Terminal* geeft je een shell op de loginnode.

De eerste keer installeert VS Code een klein hulpprogramma op de server; dat
duurt even en gebeurt daarna niet meer.

**PyCharm** — *Settings → Tools → SSH Configurations* → `kdg-compute`, en
koppel die daarna aan een *Remote Interpreter* of *Deployment*.

> Werk in je eigen map onder `/trinity/home/`. Die staat op gedeelde opslag en
> is dus zichtbaar op elke node waar je job terechtkomt. Bestanden die je op één
> node buiten die map zet, zijn elders niet te zien.

### 5.2 Python, pakketten en git

Er staat een handvol modules klaar, te bekijken met `module avail`:

| Module | |
|---|---|
| `python/3.12`, `python/3.9` | Python; 3.12 is de standaard |
| `cmake`, `gnu13`, `hwloc`, `pmix` | bouwgereedschap en MPI-onderdelen |
| `ood-vnc` | voor grafische sessies via de portal |

Laden doe je zo:

```bash
module load python/3.12
```

Voor de meeste projecten werk je echter prettiger met een eigen omgeving per
map. [uv](https://docs.astral.sh/uv/) regelt de Python-versie, de virtuele
omgeving en de pakketten in één, en heeft geen module nodig.

Kijk eerst of het al klaarstaat:

```bash
which uv
```

Zo niet, dan installeer je het eenmalig in je eigen map:

```bash
curl -LsSf https://astral.sh/uv/install.sh | sh
source ~/.bashrc
```

Een project opzetten:

```bash
cd /trinity/home/$USER
mkdir mijn-project && cd mijn-project
uv init
uv add numpy pandas
uv run python mijn_script.py
```

`git` staat klaar, dus je kunt gewoon een repository klonen en daarin werken.

> **Let op in een jobscript.** Een job erft je interactieve omgeving niet. Laad
> je modules daar opnieuw, en start je code via `uv run`, zodat de job dezelfde
> pakketten gebruikt als jij in je terminal.

### 5.3 Rekenwerk indienen met Slurm

Dit is het belangrijkste om te weten, en tegelijk wat het meest misgaat.

**De loginnode is niet om op te rekenen.** Daar bewerk je bestanden, installeer
je dingen en dien je werk in. Het echte rekenwerk gaat naar de compute nodes,
en Slurm verdeelt dat. Draai je een zwaar script rechtstreeks op de loginnode,
dan hinder je iedereen die op dat moment wil inloggen.

**Een job indienen.** Maak een bestand `job.sh`:

```bash
#!/bin/bash
#SBATCH --job-name=mijn-eerste-job
#SBATCH --partition=defg
#SBATCH --nodes=1
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=4
#SBATCH --time=01:00:00
#SBATCH --output=slurm-%j.out

hostname
cd /trinity/home/$USER/mijn-project
uv run python mijn_script.py
```

Indienen en volgen:

```bash
sbatch job.sh          # dient de job in, toont het jobnummer
squeue -u $USER        # toont je eigen jobs en hun status
scancel <jobnummer>    # stopt een job
```

De uitvoer komt in `slurm-<jobnummer>.out` te staan, in de map waar je
`sbatch` draaide.

**Partities.** Met `--partition` kies je waar je job draait:

| Partitie | Waarvoor |
|---|---|
| `defg` | De hele cluster, gedeeld. Maximaal 8 nodes |
| `single_node` | Alleen `node001`, om te debuggen |

**Interactief werken.** Wil je zelf commando's typen op een compute node in
plaats van een script in te dienen:

```bash
srun --partition=defg --cpus-per-task=4 --time=01:00:00 --pty bash
```

Je krijgt dan een shell op een compute node. Sluit af met `exit` zodra je klaar
bent — zolang je die shell openhoudt, blijft die capaciteit voor jou
gereserveerd.

**Wat er nog draait:**

```bash
sinfo                  # welke nodes er zijn en of ze vrij zijn
squeue                 # alle jobs in de wachtrij
```

> Welke software er klaarstaat en hoe je je omgeving opzet, verschilt per
> vakgebied. Vraag het aan het HPC-team via
> [compute@kdg.be](mailto:compute@kdg.be).

### 5.4 Een Jupyter-notebook via de portal

Handig als je in je browser wil werken. Dit heeft een werkend SSH-account
nodig, dus doe eerst stap 2.

De portal draait op een adres dat alleen binnen het clusternetwerk bestaat. Je
browser kan die naam niet vinden, ook niet met VPN. Daarom stuur je je
browserverkeer door een tunnel die de naam aan de clusterkant laat opzoeken.

**Stap 1 — open de tunnel**

```bash
ssh -N -D 9090 kdg-compute
```

Dit commando blokkeert en geeft geen uitvoer. Dat hoort zo: laat het venster
open zolang je de portal gebruikt. Elk poortnummer boven 1024 mag in plaats van
9090.

**Stap 2 — stuur je browser door de tunnel**

Gebruik hiervoor [FoxyProxy](https://addons.mozilla.org/nl/firefox/addon/foxyproxy-standard/),
beschikbaar voor Firefox, Chrome en Edge. Het kan ook via de instellingen van
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

**Stap 3 — open de portal**

Ga naar [https://controller1.cluster:8080](https://controller1.cluster:8080) en
klik op **Azure SSO Login** om met je schoolaccount aan te melden.

![Aanmeldpagina](../images/login_page.png)

**Stap 4 — start een notebook**

Klik op de startpagina op **Jupyter notebook** onder *Interactive Apps*.

- Vul je accountnaam in.
- Kies een partitie: `defg` voor gewoon werk, `single_node` om te debuggen.
- Kies het aantal nodes dat je nodig hebt, maximaal 8.
- Klik **Connect**. Je komt in je eigen map terecht.

Je start in Jupyter Classic; via *View → Lab* schakel je over naar JupyterLab.

E-mailmeldingen zijn nog niet ingesteld.

**Als je klaar bent** — sluit de tunnel met `Ctrl+C` en zet FoxyProxy weer uit.

> Het tunnel- en proxygedeelte verdwijnt zodra de portal een adres krijgt dat
> over de VPN werkt. Dan typ je gewoon een adres in je browser.

---

## 6. Geen toegang meer?

**Nieuwe laptop, of je oude nog steeds in gebruik.** Draai het setupscript op
het nieuwe toestel. Er komt een tweede sleutel bij; die van je oude laptop
blijft gewoon werken. Je hebt hiervoor het wachtwoord uit de mail nodig.

**Sleutel kwijt of laptop gestolen.** Draai het script op je nieuwe toestel, en
verwijder daarna de oude sleutel van de server — anders houdt wie die laptop
heeft toegang. Log in en open het bestand:

```bash
ssh kdg-compute
nano ~/.ssh/authorized_keys
```

Elke regel is één sleutel, met achteraan een naam als
`jouw_accountnaam@LAPTOP-OUD`. Verwijder de regel van het toestel dat je kwijt
bent, en bewaar met `Ctrl+O`, `Ctrl+X`.

**Wachtwoord ook kwijt.** Neem contact op met het HPC-team via
[compute@kdg.be](mailto:compute@kdg.be). Je identiteit wordt gecontroleerd via
je KdG-schoolaccount.

---

## 7. Problemen oplossen

Draai `ssh -v kdg-compute` — die uitvoer laat zien welke sleutel is aangeboden
en wat de server ermee deed.

| Melding | Oorzaak en oplossing |
|---|---|
| `compute.kdg.be is niet bereikbaar` | VPN staat niet aan, of is nog aan het verbinden |
| `ssh.exe is niet gevonden` (Windows) | Draai `Add-WindowsCapability -Online -Name OpenSSH.Client~~~~0.0.1.0` in een PowerShell **als administrator** |
| `Permission denied` bij het wachtwoord | Accountnaam of wachtwoord klopt niet — neem contact op |
| `Permission denied (publickey)` | Je sleutel staat niet op de server. Draai stap 2 opnieuw |
| `WARNING: UNPROTECTED PRIVATE KEY FILE` | Je private sleutel is te ruim leesbaar: `chmod 600 ~/.ssh/id_ed25519` |
| Sleutel wordt genegeerd, zonder melding | `sshd` weigert `~/.ssh` bij te ruime rechten: `chmod 700 ~/.ssh` |
| `Could not resolve hostname kdg-compute` | Je hebt stap 2 niet gedraaid — gebruik het volledige adres |
| De test in stap 7 faalt | Normaal als je een passphrase op je sleutel zette; test met `ssh kdg-compute` |
| Je job blijft in `PD` staan in `squeue` | De cluster is bezet, of je vraagt meer dan er is. `sinfo` toont wat vrij is |
| Portal onbereikbaar, tunnel staat open | FoxyProxy staat uit, of de naam wordt lokaal opgezocht (zie 5.4) |

Lukt het niet? Open een
[issue](https://github.com/KdG-OCDI/hpc-public/issues) of stuur een mail naar
[compute@kdg.be](mailto:compute@kdg.be), met de **volledige uitvoer** van het
script erbij — die bevat geen geheimen.

---

## Meer

- [Handmatige SSH-installatie](../Setup%20SSH.md) — WSL, ssh-agent, meerdere
  sleutels, en wat het script onder water doet
