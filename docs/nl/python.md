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
cd /trinity/home/$USER
mkdir mijn-project && cd mijn-project
uv init
uv add numpy pandas
uv run python mijn_script.py
```

`uv run` zorgt dat je script de pakketten uit dit project gebruikt, zonder dat
je een omgeving hoeft te activeren.

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

## In een jobscript

Een job erft je interactieve omgeving niet. Wat je in je terminal hebt geladen
of geactiveerd, is weg zodra Slurm je script op een andere node start.

Zet daarom in je jobscript expliciet wat je nodig hebt:

```bash
cd /trinity/home/$USER/mijn-project
uv run python mijn_script.py
```

Dit is de meest voorkomende oorzaak van "het werkt in mijn terminal maar niet
in mijn job".

---

## Verder

- [Rekenwerk indienen met Slurm](slurm.md)
- [Werken in je eigen editor](editor.md)
