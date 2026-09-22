# Python, pakketten en git

*[English](../en/python.md) · [terug naar de procedure](README.md)*

Hoe je een project opzet met zijn eigen Python en zijn eigen pakketten.

---

## Een omgeving per project met uv

[uv](https://docs.astral.sh/uv/) regelt de Python-versie, de virtuele omgeving
en de pakketten in één. De omgeving hangt aan de map, niet aan je shell — dus
hij reist mee naar de compute node waar je job draait.

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
mkdir -p /trinity/home/$USER/projects
cd /trinity/home/$USER/projects
mkdir mijn-project && cd mijn-project
uv init
uv add numpy pandas
```

`uv` maakt in die map een `.venv` aan met je pakketten erin.

### Open die map nu in je editor

Dit is de stap die het verschil maakt, en die makkelijk overgeslagen wordt.

In **VS Code of Cursor**: *File → Open Folder* →
`/trinity/home/jouw_accountnaam/projects/mijn-project`. Dus de projectmap zelf, niet je
home.

Daarna kies je de omgeving die `uv` heeft aangemaakt: `Ctrl+Shift+P` →
*Python: Select Interpreter* → de `.venv` in je project.

Vanaf dat moment klopt alles bij elkaar: je terminal opent in de projectmap,
autocompletion en debuggen gebruiken dezelfde pakketten als je script, en een
notebook dat je in VS Code opent draait in dezelfde omgeving. Open je alleen je
home, dan zoekt VS Code een Python zonder je pakketten en lijkt elke `import`
te ontbreken.

In **PyCharm** open je het project op dezelfde manier, en wijs je de `.venv`
aan als interpreter.

### Je eerste script

Maak `hello.py` in je projectmap:

```python
import os
import platform
import socket

import numpy as np

print(f"Hallo HPC, vanaf {socket.gethostname()}")
print(f"Python {platform.python_version()}, NumPy {np.__version__}")
print(f"Cores op deze machine: {os.cpu_count()}")

job = os.environ.get("SLURM_JOB_ID")
if job:
    cores = os.environ.get("SLURM_CPUS_PER_TASK", "?")
    print(f"Dit draait als job {job}, met {cores} toegewezen cores")
else:
    print("Dit draait niet als job — je zit op de loginnode")
```

Draaien:

```bash
uv run python hello.py
```

`uv run` zorgt dat je script de pakketten uit dit project gebruikt, zonder dat
je een omgeving hoeft te activeren. Je zou zoiets moeten zien:

```
Hallo HPC, vanaf login01
Python 3.12.3, NumPy 2.1.1
Cores op deze machine: 64
Dit draait niet als job — je zit op de loginnode
```

Die laatste regel is het punt van dit voorbeeld.

> **Let op waar dit draait.** Je terminal staat op de loginnode, dus dit
> commando draait daar ook. Prima om te controleren of je script start of om
> iets kleins uit te proberen, maar niet voor echt rekenwerk: die ene machine
> is van iedereen. Zodra het meer dan een paar seconden duurt, dien je het in
> als [job](slurm.md) — en dan zegt datzelfde script iets anders.

Een andere Python-versie voor dit project:

```bash
uv python pin 3.11
```

---

## git

`git` staat klaar. Kloon je repository in je eigen map en werk daarin:

```bash
cd /trinity/home/$USER
git clone https://github.com/jouw-org/jouw-project.git
cd jouw-project
uv sync          # installeert wat in pyproject.toml of uv.lock staat
```

Voor een privérepository heb je een sleutel of een token nodig. De sleutel die
je gebruikt om op de cluster te komen is daar niet voor bedoeld — maak een
aparte aan op de cluster zelf, of gebruik een token.

---

## Verder

- [Rekenwerk indienen met Slurm](slurm.md)
- [Werken in je eigen editor](editor.md)
