# Diensten draaien in containers

*[English](../en/containers.md) · [terug naar de procedure](README.md)*

Op de loginnode draait **Docker**. Daarmee zet je de diensten neer die naast je
rekenwerk staan en gewoon blijven draaien: een MLflow-server om experimenten
bij te houden, een Postgres-database, MinIO voor objectopslag, LakeFS voor
versiebeheer van je data.

---

## Voor je begint

**Docker draait alleen op de loginnode.** Niet op de compute nodes. Wat je hier
start, staat dus op de machine waarop je inlogt — zie
[hoe de cluster in elkaar zit](README.md#de-cluster-in-één-oogopslag).

**Je zit normaal al in de docker-groep.** Nieuwe accounts komen daar
automatisch in. Krijg je toch
`permission denied while trying to connect to the Docker daemon socket`, dan zit
je account er nog niet in — dat kan bij oudere accounts. Stuur een mail naar
[compute@kdg.be](mailto:compute@kdg.be).

**Containers zijn niet om in te rekenen.** Ze delen die ene loginnode met
iedereen. Een database of een trackingserver hoort daar thuis; het trainen van
een model niet — dat gaat via [Slurm](slurm.md).

---

## Met VS Code: de Containers-extensie

Zoek in het *Extensions*-paneel naar **Containers** (van Microsoft) en
installeer hem met de knop **Install in SSH: …** — dus in je
Remote-SSH-venster, niet lokaal. De extensie praat met de Docker-socket, en die
staat op de cluster. Installeer je hem lokaal, dan kijkt hij naar Docker op je
laptop en blijft de lijst leeg.

Daarna heb je in de zijbalk een overzicht van containers, images en volumes.
Rechtsklikken geeft je wat je anders intypt: **View Logs**, **Attach Shell**,
stoppen, herstarten, verwijderen.

Wil je er ook `Dockerfile`s mee schrijven, zet dan **Docker DX** (van Docker
zelf) ernaast. Die beheert niets, maar controleert je `Dockerfile` en
`compose.yaml` terwijl je typt.

---

## Een stack starten

Zet je `compose.yaml` in je projectmap, zoals de rest van je project:

```bash
cd /trinity/home/$USER/mijn-project
docker compose up -d
docker compose ps
docker compose logs -f mlflow
```

Stoppen doe je met `docker compose down`. Wil je ook de gegevens weg, dan
`docker compose down -v` — dat verwijdert de volumes, dus je databases zijn
dan echt leeg.

> **Kies je eigen poorten.** De loginnode is van iedereen, en er is maar één
> poort 5000. Draait er al iets, dan krijg je `address already in use`. Spreek
> met jezelf een reeks af — bijvoorbeeld `15000`, `15432`, `19000` — en houd
> die aan in al je projecten. `ss -tlnp` laat zien wat er al luistert.

---

## Erbij met je browser

De diensten luisteren op de loginnode, niet op je laptop. Je haalt ze naar je
toe met port forwarding, en dat kan VS Code voor je doen.

1. Panel onderaan → tabblad **Ports** (of `Ctrl+Shift+P` → *Ports: Focus on
   Ports View*)
2. **Forward a Port** → typ het poortnummer, bijvoorbeeld `5000`
3. Klik op het **wereldbolletje** in die regel

Vaak merkt VS Code zelf op dat er iets begint te luisteren en verschijnt de
regel vanzelf. Dat wereldbolletje opent de pagina **in VS Code zelf**, in een
tabblad naast je code — je hoeft niet naar je browser en de tunnel is al
geregeld. `Ctrl+Shift+P` → *Simple Browser: Show* doet hetzelfde voor een URL
die je zelf intypt.

Typische adressen, zodra je de poort hebt doorgestuurd:

| Dienst | Adres |
|---|---|
| MLflow | `http://localhost:5000` |
| MinIO-console | `http://localhost:9001` |
| LakeFS | `http://localhost:8000` |
| Postgres | geen webpagina — verbind met een databaseclient op `localhost:5432` |

> Draait je dienst op een **compute node** in plaats van op de loginnode, typ
> dan `node002:8888` in plaats van alleen het poortnummer. VS Code stuurt dan
> door naar die node, via de loginnode.

---

## Vanuit een job erbij

Een job op een compute node draait op een andere machine dan je containers.
Wil je bijvoorbeeld vanuit je training naar MLflow loggen, test dan eerst of je
job de loginnode kan bereiken:

```bash
srun --partition=defq --time=00:05:00 --pty bash
curl -s http://login01:5000/health
```

Werkt dat, dan kan je script erheen loggen met
`MLFLOW_TRACKING_URI=http://login01:5000`. Zet dat in je `.env` of in je
jobscript — zie [omgevingsvariabelen](slurm.md#omgevingsvariabelen).

---

## Op een compute node: Apptainer

Heb je een container nodig bij het rekenwerk zelf, dan is Docker daar geen
optie: er draait geen daemon op de nodes, en die zou ook als root draaien.
**Apptainer** (vroeger Singularity) doet hetzelfde werk als jouw gebruiker, met
jouw rechten en jouw home-map.

Een bestaand Docker-image omzetten en gebruiken:

```bash
apptainer build mijn-image.sif docker://python:3.12
apptainer exec --nv mijn-image.sif python mijn_script.py
```

`--nv` geeft de container toegang tot de GPU's van de node. Zo'n `.sif` is één
bestand in je projectmap, dus elke node ziet het meteen.

---

## Verder

- [Rekenwerk indienen met Slurm](slurm.md)
- [Werken in je eigen editor](editor.md)
- [Python, pakketten en git](python.md)
