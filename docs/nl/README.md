# Toegang tot de KdG HPC-cluster

*[English version](../en/README.md) · [terug naar de startpagina](../../README.md)*

## De cluster in één oogopslag

Vier soorten machines en één gedeelde map. Wie dit plaatje eenmaal ziet,
begrijpt de rest van deze pagina een stuk sneller.

<p align="center">
  <img src="../../images/cluster-nl.svg" alt="Schema van de cluster: je laptop verbindt via ssh met login01, die werk indient op node001 tot node008; controller1 plant en beheert alles; /trinity/home is dezelfde gedeelde schijf op alle machines" width="100%">
</p>

| Machine | Wat het voor jou betekent |
|---|---|
| **login01** | De enige machine waarop je inlogt. Bestanden bewerken, pakketten installeren, git, werk indienen — maar niet rekenen: er is er één en iedereen deelt hem. Rocky Linux 9, met één NVIDIA A10 (23 GB) om op te testen |
| **node001 … node008** | Waar je rekenwerk draait. Je logt er niet rechtstreeks op in; je dient werk in en Slurm wijst een node toe zodra er plaats is. Rocky Linux 9, met twee NVIDIA L40-GPU's (46 GB) per node |
| **controller1** | De machinekamer: de planner, het gebruikersbeheer, de webportal en de gedeelde schijf. Je hebt er geen login, en hebt die ook niet nodig |
| **/trinity/home/…** | Jouw map, op de loginnode én op elke node dezelfde. Wat je hier opslaat ziet je job ook — kopiëren hoeft niet. Alleen `/trinity` is gedeeld: `/tmp`, `/etc` en de rest van het systeem heeft elke machine voor zich |

---

Je hebt per mail een accountnaam en een wachtwoord gekregen van het HPC-team.
Hieronder zet je in ongeveer twee minuten je toegang op.

| | |
|---|---|
| **Loginnode (SSH)** | `compute.kdg.be` |
| **Je map op de cluster** | `/trinity/home/jouw_accountnaam`, zichtbaar op alle nodes |
| **Planner** | Slurm — `sbatch`, `srun`, `squeue` |
| **Webportal** | Open OnDemand, via een tunnel (zie [stap 5](#5-toegang-tot-de-webportal)) |

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

## 5. Toegang tot de webportal

Alleen nodig als je de portal wil gebruiken, bijvoorbeeld voor een
[Jupyter-notebook in je browser](jupyter.md). Werk je liever in je eigen
editor, dan kun je dit hoofdstuk overslaan.

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
beschikbaar voor Firefox, Chrome en Edge. Het kan ook via de instellingen van
je besturingssysteem, maar dan gaat **al** je internetverkeer door de cluster —
inclusief je gewone browsen. FoxyProxy laat je het beperken tot alleen het
clusteradres.

Maak een proxy aan van het type **SOCKS5**, met host `localhost` en poort
`9090`:

![FoxyProxy-instellingen](../../images/foxyproxy.png)

Voeg daarna een regel toe van het type *wildcard* met dit patroon, en kies
**Proxy by Patterns**:

```
://controller1.cluster:*
```

![FoxyProxy-patronen](../../images/foxyproxy_patterns.png)

> **Belangrijk bij SOCKS5:** de naam `controller1.cluster` moet aan de
> clusterkant opgezocht worden, niet op je laptop. In Firefox is dat het
> aanvinkvakje *Proxy DNS when using SOCKS v5*; FoxyProxy zet dat zelf goed.
> Doe je het via je systeeminstellingen, dan werkt het vaak niet om precies
> deze reden.

### Stap 3 — open de portal

Ga naar [https://controller1.cluster:8080](https://controller1.cluster:8080) en
klik op **Azure SSO Login** om met je schoolaccount aan te melden.

![Aanmeldpagina](../../images/login_page.png)

Je bent nu binnen. Wat je er kunt doen staat in
[Een Jupyter-notebook via de portal](jupyter.md).

### Als je klaar bent

Sluit de tunnel met `Ctrl+C` en zet FoxyProxy weer uit.

> Dit hele hoofdstuk verdwijnt zodra de portal een adres krijgt dat over de VPN
> werkt. Dan typ je gewoon een adres in je browser, zonder tunnel en zonder
> extensie.

---

## 6. Werken met de cluster

Zes manieren, van eenvoudig naar geavanceerder. Elke pagina staat op zichzelf;
begin bij wat je nodig hebt.

| | Waarvoor | Wat je nodig hebt |
|---|---|---|
| **[Jupyter-notebook via de portal](jupyter.md)** | Uitproberen en verkennen in je browser | Een browser en de tunnel uit stap 5 |
| **[Werken in je eigen editor](editor.md)** | Dagelijks werk, met je eigen extensies en sneltoetsen | VS Code, Cursor of PyCharm |
| **[Python, pakketten en git](python.md)** | Een omgeving per project opzetten | De terminal |
| **[Rekenwerk indienen met Slurm](slurm.md)** | Werk dat te zwaar is voor de loginnode | Begrip van een wachtrij |
| **[Verdeeld rekenen met Ray](ray.md)** | Werk over meerdere machines tegelijk | Een project met `ray==2.55.1` |
| **[Diensten draaien in containers](containers.md)** | MLflow, Postgres, MinIO, LakeFS — naast je rekenwerk | Docker op de loginnode |

Weet je niet waar te beginnen: [je eigen editor](editor.md) is wat de meeste
mensen hier dagelijks gebruiken.

---

## 7. Geen toegang meer?

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

## 8. Problemen oplossen

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
| Portal onbereikbaar, tunnel staat open | FoxyProxy staat uit, of de naam wordt lokaal opgezocht (zie stap 5) |

Lukt het niet? Open een
[issue](https://github.com/KdG-OCDI/hpc-public/issues) of stuur een mail naar
[compute@kdg.be](mailto:compute@kdg.be), met de **volledige uitvoer** van het
script erbij — die bevat geen geheimen.

---

## Meer

- [Handmatige SSH-installatie](../../Setup%20SSH.md) — WSL, ssh-agent, meerdere
  sleutels, en wat het script onder water doet
