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
cd /trinity/home/$USER/projects/mijn-project
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

### Zonder VS Code: een tunnel met ssh

Werk je niet in VS Code, dan doe je hetzelfde met één commando. Laat dat
venster openstaan zolang je de dienst gebruikt:

```bash
ssh -L 5000:login01:5000 kdg-compute
```

De vorm van `-L` is:

```
ssh -L <poort bij jou>:<host vanaf de cluster>:<poort daar> kdg-compute
        └─ kies je zelf      └─ wordt pas aan de overkant opgezocht
```

Drie dingen die het meestal ophelderen:

- **Alleen het eerste getal kies je zelf.** Dat is de poort op je eigen
  machine; in je browser of je code gebruik je altijd `localhost:<dat getal>`.
- **De naam in het midden wordt op de cluster opgezocht**, niet bij jou.
  Daarom kan je daar `node002` schrijven terwijl je laptop die machine niet
  eens kent — login01 legt de rest van de weg af.
- Je ziet vaak `localhost` in het midden staan. Dat werkt altijd — vanaf
  login01 is `localhost` gewoon login01 — en `login01` schrijven leest
  duidelijker, want dan staat er letterlijk waar je uitkomt. Met één
  uitzondering: een dienst die alleen op de machine zelf luistert, zoals de
  Ray Client, bereik je uitsluitend via `localhost`. Twijfel je, neem dan
  `localhost`.

| Commando | Wat je krijgt |
|---|---|
| `-L 5000:login01:5000` | `localhost:5000` bij jou is MLflow op de loginnode |
| `-L 15000:login01:5000` | idem, maar op poort 15000 — handig als 5000 bij jou bezet is |
| `-L 8888:node002:8888` | `localhost:8888` bij jou is poort 8888 op **node002** |

Die laatste is de interessante: zo bereik je een server die je zelf in een job
op een compute node hebt gestart, bijvoorbeeld een vLLM-server.

Meerdere poorten in één keer kan ook, gewoon door `-L` te herhalen:

```bash
ssh -L 5000:login01:5000 -L 9001:login01:9001 -L 8265:login01:8265 kdg-compute
```


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

## Op een compute node: nog niet

Heb je een container nodig bij het rekenwerk zelf, dan is Docker daar geen
optie: er draait geen daemon op de compute nodes, en die zou ook als root
draaien. Het gebruikelijke antwoord op een cluster is **Apptainer** (vroeger
Singularity) of **Podman** — die draaien als jouw gebruiker, met jouw rechten.

**Op deze cluster staat geen van beide klaar.** Alleen `node008` heeft Podman.
Heb je containers nodig in een job, stuur dan een mail naar
[compute@kdg.be](mailto:compute@kdg.be) met wat je wil draaien — dat helpt
bepalen welke van de twee het wordt.

Ondertussen: voor Python-werk heb je meestal geen container nodig. Een
omgeving met [uv](python.md) staat op gedeelde opslag en is daardoor op elke
node hetzelfde — dat is precies wat een container je hier zou opleveren.

---

## Verder

- [Rekenwerk indienen met Slurm](slurm.md)
- [Werken in je eigen editor](editor.md)
- [Python, pakketten en git](python.md)
