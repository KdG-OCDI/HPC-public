# Rekenwerk indienen met Slurm

*[English](../en/slurm.md) · [terug naar de procedure](README.md)*

Zwaar werk hoort niet op de loginnode, maar in de wachtrij. Slurm verdeelt het
over de compute nodes.

---

## Handig gereedschap

Twee VS Code-extensies maken het werken met Slurm een stuk aangenamer. Nodig
zijn ze niet — alles kan met `sbatch` en `squeue` — maar ze besparen veel
heen-en-weer in de terminal.

Zoek ze op naam in het *Extensions*-paneel:

| Extensie | Wat je eraan hebt |
|---|---|
| **SLURM Cluster Manager** | Je jobs in de zijbalk, met hoeveel van je gevraagde tijd al op is. Logbestanden met één klik, jobs annuleren zonder commando, en het GPU-gebruik per partitie |
| **SLURM Monitor** | Een overzicht van de hele cluster: welke nodes vrij zijn, en wat een job werkelijk verbruikt tegenover wat hij aanvroeg |

> **Installeer ze in je Remote-SSH-venster**, niet lokaal. Ze hebben de
> Slurm-commando's nodig, en die staan op de cluster — zie
> [Werken in je eigen editor](editor.md).

Beide zijn gemaakt door derden en worden niet door het HPC-team onderhouden:
[SLURM Cluster Manager](https://github.com/dhimitriosduka1/sCode),
[SLURM Monitor](https://github.com/hforoughmand/slurm-monitor-top).

---

## Waarom

**De loginnode is niet om op te rekenen.** Daar bewerk je bestanden, installeer
je dingen en dien je werk in. Er is er maar één, en iedereen deelt hem. Draai
je er een zwaar script, dan hinder je iedereen die op dat moment wil inloggen
of werken.

De compute nodes zijn waar het rekenwerk hoort. Je komt er niet rechtstreeks
op: je vraagt capaciteit aan, en Slurm geeft je die zodra ze vrij is.

---

## Een job indienen

We gebruiken hier hetzelfde `hello.py` uit
[Python, pakketten en git](python.md#je-eerste-script). Maak daarnaast een
bestand `job.sh` in je projectmap:

```bash
#!/bin/bash
#SBATCH --job-name=hallo-hpc
#SBATCH --partition=defq
#SBATCH --nodes=1
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=4
#SBATCH --time=00:05:00
#SBATCH --output=slurm-%j.out
#SBATCH --error=slurm-%j.err

cd /trinity/home/$USER/projects/mijn-project
uv run python hello.py
```

De regels met `#SBATCH` zijn geen commentaar: dat zijn je aanvraag. Daaronder
staan gewone shell-commando's die op de toegewezen node draaien.

Indienen:

```bash
sbatch job.sh
```

Je krijgt een jobnummer terug, bijvoorbeeld `Submitted batch job 4711`. De
uitvoer komt in `slurm-4711.out`, in de map waar je `sbatch` draaide:

```bash
cat slurm-4711.out
```

```
Hallo HPC, vanaf node003
Python 3.12.3, NumPy 2.1.1
Cores op deze machine: 128
Dit draait als job 4711, met 4 toegewezen cores
```

Vergelijk dat met wat hetzelfde script op de loginnode zei. Een andere machine,
en vier cores die Slurm voor jou heeft vrijgemaakt — dat is het verschil tussen
werken op de loginnode en werken op de cluster.

### Je uitvoer bekijken

Drie manieren, en de laatste is veruit de prettigste:

```bash
cat slurm-4711.out        # als de job klaar is
tail -f slurm-4711.out    # meelezen terwijl hij draait, stoppen met Ctrl+C
```

In de VS Code-terminal is de bestandsnaam aanklikbaar: **Ctrl+klik** op
`slurm-4711.out` opent hem als tabblad. Of gewoon dubbelklikken in de
bestandsbrowser links.

Maar met **SLURM Cluster Manager** klik je op de job zelf en staat de uitvoer
er meteen, ook terwijl hij nog draait. Je hoeft het jobnummer niet te
onthouden en niet te weten in welke map je `sbatch` draaide — en dat is precies
waar je op dat moment naar zoekt.

> Foutmeldingen komen in `slurm-4711.err` terecht, door de `--error`-regel in
> het script. Laat je die weg, dan belandt alles door elkaar in hetzelfde
> bestand — apart houden scheelt zoeken.

---

## Omgevingsvariabelen

`sbatch` neemt standaard je huidige omgevingsvariabelen mee naar de job; dat is
wat `--export=ALL` doet, en dat staat al zo ingesteld.

Dat klinkt handig, maar het is een valkuil: je job gaat daardoor afhangen van
de terminal waaruit je hem indiende. Vandaag werkt hij omdat je net iets hebt
gezet, morgen faalt hij vanuit een verse terminal. Een fout die soms werkt is
lastiger te vinden dan een die altijd faalt.

Zet daarom in je script wat je nodig hebt, in plaats van erop te vertrouwen dat
het meekomt.

**Een `.env` in je project.** Die hoeft nergens heen: je projectmap staat op
gedeelde opslag, dus elke node ziet dat bestand al. Je moet hem alleen laten
inlezen:

```bash
cd /trinity/home/$USER/projects/mijn-project
uv run --env-file .env python hello.py
```

Of laad hem in je code met `python-dotenv`, als je dat al gebruikt.

**Eén variabele voor deze ene job.** Zet hem gewoon in het script, boven je
commando:

```bash
export SEED=42
uv run python hello.py
```

Of geef hem mee bij het indienen:

```bash
sbatch --export=ALL,SEED=42 job.sh
```

**Wat níét meekomt:** alles wat je `.bashrc` alleen voor interactieve shells
doet. Een job draait geen interactieve shell, dus wat daar staat gebeurt niet.

---

## Wat je aanvraagt

| Optie | Betekenis |
|---|---|
| `--partition` | waar je job draait, zie hieronder |
| `--nodes` | aantal machines |
| `--ntasks` | aantal processen |
| `--cpus-per-task` | cores per proces |
| `--time` | maximale looptijd, `uu:mm:ss` |
| `--output` | bestand voor de uitvoer; `%j` wordt het jobnummer |
| `--error` | bestand voor de foutmeldingen |

Vraag je te weinig tijd, dan wordt je job afgebroken zodra die op is. Vraag je
veel te veel, dan kom je verder achteraan in de wachtrij. Een ruime maar
realistische schatting werkt het best.

### Partities

| Partitie | Waarvoor |
|---|---|
| `defq` | De hele cluster, gedeeld. Dit is de standaard, dus je mag `--partition` ook weglaten |
| `compute` | Ook alle acht de nodes |
| `node001` … `node008` | Eén specifieke node, om te debuggen |

Welke partities er zijn en of ze vrij zijn, zie je met `sinfo`. De partitie met
een `*` erachter is de standaard.

---

## Volgen en stoppen

```bash
squeue -u $USER        # je eigen jobs en hun status
squeue                 # alles in de wachtrij
sinfo                  # welke nodes er zijn en of ze vrij zijn
scancel <jobnummer>    # stopt een job
```

In `squeue` betekent `R` dat je job draait en `PD` dat hij wacht. Blijft er
`PD` staan, dan is de cluster bezet of vraag je meer dan er beschikbaar is —
`sinfo` laat zien wat vrij is.

---

## Interactief werken

Wil je zelf commando's typen op een compute node in plaats van een script in te
dienen:

```bash
srun --partition=defq --cpus-per-task=4 --time=01:00:00 --pty bash
```

Je krijgt een shell op een compute node zodra er plaats is. Handig om iets uit
te proberen voordat je het als job indient.

**Sluit af met `exit` zodra je klaar bent.** Zolang die shell openstaat, blijft
de capaciteit voor jou gereserveerd, ook als je niets doet.

### Als je tijd op is

Je shell wordt afgesloten en je staat weer op de loginnode. Slurm stuurt eerst
een `SIGTERM` naar alles in je sessie en dertig seconden later een `SIGKILL`.
Je krijgt geen waarschuwing vooraf.

Wat er weg is: alles wat in het geheugen stond — een draaiend script, een
Python-sessie, een halve berekening. Wat blijft: alles wat naar schijf is
geschreven. Je bestanden in `/trinity/home` zijn veilig.

Hoeveel tijd je nog hebt:

```bash
squeue -u $USER -O JobID,TimeLeft,TimeLimit
```

Verlengen kan niet: je mag je eigen tijdslimiet alleen verlagen. Alleen een
beheerder kan hem verhogen.

> Daarom is een interactieve sessie ongeschikt voor werk dat lang duurt — je
> zit vast aan de tijd die je vooraf gokte. Vraag je voor de zekerheid acht uur
> aan, dan kom je verder achteraan in de wachtrij én houd je die capaciteit
> bezet zolang je shell openstaat, ook tijdens je lunch. Voor echt werk is
> [een job indienen](#een-job-indienen) beter.

---

## Veelgemaakte fout

Je job vindt je pakketten niet, terwijl hetzelfde script in je terminal wel
werkt.

Meestal komt dat doordat het script vertrouwt op waar je toevallig stond of
wat je toevallig had geactiveerd. Daarom begint het voorbeeld hierboven met een
`cd` naar de projectmap en draait het via `uv run`, in plaats van alleen
`python hello.py`:

```bash
cd /trinity/home/$USER/projects/mijn-project
uv run python hello.py
```

Zo hangt je job aan je projectmap en niet aan je shell. Zie
[Python, pakketten en git](python.md) voor het opzetten van die omgeving.

---

## Verder

- [Python, pakketten en git](python.md)
- [Werken in je eigen editor](editor.md)
