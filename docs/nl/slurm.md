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
#SBATCH --partition=defg
#SBATCH --nodes=1
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=4
#SBATCH --time=00:05:00
#SBATCH --output=slurm-%j.out

cd /trinity/home/$USER/mijn-project
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

Vraag je te weinig tijd, dan wordt je job afgebroken zodra die op is. Vraag je
veel te veel, dan kom je verder achteraan in de wachtrij. Een ruime maar
realistische schatting werkt het best.

### Partities

| Partitie | Waarvoor |
|---|---|
| `defg` | De hele cluster, gedeeld. Maximaal 8 nodes |
| `single_node` | Alleen `node001`, om te debuggen |

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
srun --partition=defg --cpus-per-task=4 --time=01:00:00 --pty bash
```

Je krijgt een shell op een compute node zodra er plaats is. Handig om iets uit
te proberen voordat je het als job indient.

**Sluit af met `exit` zodra je klaar bent.** Zolang die shell openstaat, blijft
de capaciteit voor jou gereserveerd, ook als je niets doet.

---

## Veelgemaakte fout

Je bouwt je omgeving op in je terminal, dient een job in, en die vindt je
pakketten niet.

Een job erft je interactieve omgeving niet. Wat je in je terminal hebt geladen,
geactiveerd of aan je `PATH` hebt toegevoegd, is weg zodra Slurm je script op
een andere node start — die shell bestaat daar niet.

Zet daarom in je jobscript expliciet wat je nodig hebt. Daarom staat er in het
voorbeeld hierboven ook een `cd` naar de projectmap en een `uv run`, en niet
alleen `python hello.py`:

```bash
cd /trinity/home/$USER/mijn-project
uv run python hello.py
```

Zie [Python, pakketten en git](python.md) voor het opzetten van die omgeving.

---

## Verder

- [Python, pakketten en git](python.md)
- [Werken in je eigen editor](editor.md)
