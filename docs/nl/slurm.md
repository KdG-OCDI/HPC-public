# Rekenwerk indienen met Slurm

*[English](../en/slurm.md) · [terug naar de procedure](README.md)*

Zwaar werk hoort niet op de loginnode, maar in de wachtrij. Slurm verdeelt het
over de compute nodes.

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

Maak een bestand `job.sh` in je projectmap:

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

De regels met `#SBATCH` zijn geen commentaar: dat zijn je aanvraag. Daaronder
staan gewone shell-commando's die op de toegewezen node draaien.

Indienen:

```bash
sbatch job.sh
```

Je krijgt een jobnummer terug. De uitvoer komt in `slurm-<jobnummer>.out`, in
de map waar je `sbatch` draaide.

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
pakketten niet. Een job erft je interactieve omgeving niet — zie
[Python, pakketten en git](python.md).

---

## Verder

- [Python, pakketten en git](python.md)
- [Werken in je eigen editor](editor.md)
