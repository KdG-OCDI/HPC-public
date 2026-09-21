# Een Jupyter-notebook via de portal

*[English](../en/jupyter.md) · [terug naar de procedure](README.md)*

De eenvoudigste manier om te beginnen: een notebook in je browser, zonder dat
je iets van de terminal hoeft te weten.

**Vooraf nodig:** een werkend account ([stap 2](README.md#2-draai-één-commando))
en een open tunnel naar de portal ([stap 5](README.md#5-toegang-tot-de-webportal)).

---

## Een notebook starten

Klik op de startpagina van de portal op **Jupyter notebook**, onder
*Interactive Apps*.

Je vult een formulier in:

| Veld | Wat je invult |
|---|---|
| **Account** | je accountnaam |
| **Partition** | `defq` voor gewoon werk, of `node001` om te debuggen |
| **Number of nodes** | wat je nodig hebt, maximaal 8 |

Klik op **Connect**. Je aanvraag komt in de wachtrij van Slurm terecht: de
portal start je notebook niet op de loginnode, maar op een compute node die
voor jou vrijgemaakt wordt. Bij een drukke cluster kan dat even duren.

Zodra de sessie draait verschijnt er een knop om hem te openen. Je komt in je
eigen map terecht, `/trinity/home/jouw_accountnaam`.

---

## Classic of Lab

Je start in Jupyter Classic. Via *View → Lab* schakel je over naar JupyterLab,
met bestandsbrowser, tabbladen en een terminal erbij.

---

## Waar je bestanden staan

Alles onder `/trinity/home/jouw_accountnaam` staat op gedeelde opslag. Je ziet
dezelfde bestanden terug als je via [SSH](editor.md) inlogt, en een job op een
andere node ziet ze ook.

Dat betekent ook dat je een notebook kunt gebruiken om iets uit te proberen, en
het echte rekenwerk daarna [als job](slurm.md) kunt indienen op dezelfde
bestanden.

---

## Pakketten installeren

In een notebook werkt `!pip install` binnen de omgeving van die sessie. Wil je
een omgeving die blijft bestaan en die je jobs ook kunnen gebruiken, zet die
dan op met [uv](python.md) en start je notebook daarin.

---

## Als je klaar bent

Sluit je sessie af via de portal, onder *My Interactive Sessions* → **Delete**.
Zolang de sessie draait, blijft die capaciteit voor jou gereserveerd en kan
niemand anders die gebruiken.

Vergeet daarna de tunnel niet te sluiten met `Ctrl+C`, en zet FoxyProxy weer
uit.

---

## Verder

- [Werken in je eigen editor](editor.md) — VS Code, Cursor of PyCharm
- [Python, pakketten en git](python.md)
- [Rekenwerk indienen met Slurm](slurm.md)
