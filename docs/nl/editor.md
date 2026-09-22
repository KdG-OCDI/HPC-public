# Werken in je eigen editor

*[English](../en/editor.md) · [terug naar de procedure](README.md)*

Je bewerkt bestanden op de cluster alsof ze lokaal staan, met je eigen editor,
extensies en sneltoetsen. Je terminal draait op de cluster. Dit is hoe de
meeste mensen hier werken.

**Vooraf nodig:** een werkend account
([stap 2](README.md#2-draai-één-commando)). Geen tunnel, geen portal.

---

## VS Code of Cursor

1. Installeer de extensie
   [Remote - SSH](https://marketplace.visualstudio.com/items?itemName=ms-vscode-remote.remote-ssh).
2. `Ctrl+Shift+P` → *Remote-SSH: Connect to Host...* → `kdg-compute`.
3. Er opent een nieuw venster. Linksonder staat **SSH: kdg-compute**.
4. *File → Open Folder* → je eigen map, bijvoorbeeld
   `/trinity/home/jouw_accountnaam`.
5. *Terminal → New Terminal* geeft je een shell op de loginnode.

De eerste keer installeert VS Code een klein hulpprogramma op de server. Dat
duurt even en gebeurt daarna niet meer.

> `kdg-compute` is de naam die het setupscript in je `~/.ssh/config` heeft
> gezet. Zie je hem niet in de lijst, dan heb je stap 2 nog niet gedraaid.

### Goed om te weten

**Je extensies draaien op de server.** Python, Jupyter, linters: die installeert
VS Code opnieuw aan de clusterkant. Dat is precies wat je wil — ze zien dezelfde
bestanden en dezelfde Python als je code.

**Je terminal staat op de loginnode.** Dat is de plek om bestanden te bewerken
en werk in te dienen, niet om te rekenen. Zie [Slurm](slurm.md).

**Je kan hier ook notebooks draaien.** Open een `.ipynb` in VS Code en kies je
[uv-omgeving](python.md) als kernel. Je werkt dan in een notebook zonder dat je
de portal en de tunnel uit stap 5 nodig hebt.

Let wel op waar zo'n notebook draait: op de loginnode, net als je terminal.
Prima dus om iets uit te proberen of een grafiek te maken, maar zodra een cel
langer dan een paar seconden rekent, hoort dat werk in een [job](slurm.md) of
op de [Ray-cluster](ray.md).

---

## PyCharm

1. *Settings → Tools → SSH Configurations* → voeg `kdg-compute` toe.
2. Koppel die aan een **Remote Interpreter** (*Settings → Project → Python
   Interpreter → Add → SSH Interpreter*), of aan **Deployment** als je liever
   bestanden synchroniseert.

PyCharm Professional heeft dit ingebouwd; de Community-editie niet.

---

## Waar je je bestanden zet

Werk in je eigen map onder `/trinity/home/`. Die staat op gedeelde opslag en is
dus zichtbaar op elke node waar je job terechtkomt.

**Geef elk project zijn eigen map**, en zet die samen onder één `projects`-map:

```
/trinity/home/jouw_accountnaam/
└── projects/
    ├── scriptie/          ← eigen .venv, eigen pyproject.toml
    ├── beeldherkenning/   ← eigen .venv
    └── oefeningen/
```

Dat is geen ordelijkheid om de ordelijkheid: [uv](python.md) maakt per
projectmap een eigen `.venv` met eigen pakketversies. Gooi je alles in je home,
dan krijg je één omgeving waarin het ene project het andere ondermijnt zodra
twee pakketten een verschillende versie nodig hebben. En in VS Code open je
telkens die ene projectmap, niet je home — anders vindt de editor je omgeving
niet.

Bestanden die je daarbuiten op één node neerzet — in `/tmp` bijvoorbeeld — zijn
elders niet te zien. Een job die op een andere node draait vindt ze dan niet.

---

## Verder

- [Python, pakketten en git](python.md) — je omgeving opzetten
- [Rekenwerk indienen met Slurm](slurm.md) — als je script zwaarder wordt
- [Een notebook in je browser](jupyter.md) — via de portal
