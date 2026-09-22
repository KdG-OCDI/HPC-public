# Verdeeld rekenen met Ray

*[English](../en/ray.md) · [terug naar de procedure](README.md)*

[Ray](https://docs.ray.io/) verdeelt Python-werk over meerdere machines. Op
deze cluster staat een Ray-cluster **permanent klaar**: je hoeft er niets voor
op te starten, je maakt er verbinding mee.

---

## Wat er klaarstaat

| | |
|---|---|
| Head | `login01` |
| Workers | alle acht compute nodes |
| Samen | **1024 CPU-kernen**, **16 GPU's**, 2,79 TiB geheugen |
| Versie | Ray **2.55.1** |
| Dashboard | `http://login01:8265` |

Dit is een andere opzet dan je in de meeste HPC-handleidingen leest. Daar start
je een Ray-cluster op *binnen* een Slurm-job, en verdwijnt hij weer als de job
klaar is. Hier draait hij gewoon, dus je code verbindt ermee en is meteen weg.

---

## Je project opzetten

Eén ding is streng: **je Ray-versie moet exact 2.55.1 zijn.** Client en cluster
praten een protocol dat tussen versies verandert; met 2.44 of 2.56 weigert de
verbinding. Daarom zet je hem vast in je project:

```bash
cd /trinity/home/$USER/projects/mijn-project
uv add "ray==2.55.1"
```

Zo staat het in je `pyproject.toml` en hoeft niemand het te onthouden.

---

## Verbinden

Eén regel, en die werkt overal hetzelfde:

```python
import ray
ray.init("ray://login01:10001")
```

Zowel vanuit een notebook in [VS Code](editor.md) als vanuit een
[notebook in de portal](jupyter.md), en ook vanuit een gewoon script. Je hoeft
niet te weten op welke machine je zelf zit — en dat is maar goed ook, want een
notebook uit de portal draait op een compute node en je VS Code-terminal op de
loginnode.

> Je komt in voorbeelden op het internet vaak `ray.init(address="auto")` tegen.
> Dat werkt hier niet: dat zoekt een Ray-sessie op de machine waar je zelf
> zit. Gebruik het adres hierboven.

---

### Vanaf je eigen laptop

Het kan ook zonder Remote-SSH, rechtstreeks vanuit een notebook of script op je
eigen machine. Je hebt dan twee dingen nodig: de **VPN** aan, en een **tunnel**
naar de cluster, want poort 10001 is van buitenaf niet bereikbaar. Hoe je zo'n
regel leest staat bij [containers](containers.md#zonder-vs-code-een-tunnel-met-ssh).

Laat dit venster openstaan zolang je werkt:

```bash
ssh -L 10001:login01:10001 -L 8265:login01:8265 kdg-compute
```

In je code gebruik je dan `localhost` in plaats van `login01`, en je stuurt je
projectmap mee — die staat immers op je laptop en niet op de cluster:

```python
ray.init("ray://localhost:10001", runtime_env={"working_dir": "."})
```

Zonder `working_dir` vindt je taak je eigen modules niet: de code die je
schrijft draait op een compute node, niet bij jou. Ray pakt die map in, stuurt
hem mee en pakt hem daar weer uit.

> Houd die map klein. Ray weigert een `working_dir` boven 100 MB, en je stuurt
> hem over de VPN. Datasets horen daar niet in — zet die op `/trinity/home` of
> in MinIO, en laat je taken ze daar lezen. `.gitignore` wordt gerespecteerd,
> dus een `.venv` gaat niet mee.

Ook hier geldt de versie-eis: `ray==2.55.1`, ook op Windows.

---

## Hallo Ray

Maak `hallo_ray.py` in je projectmap, of plak dit in een notebookcel:

```python
import ray
import socket
import time
from collections import Counter

ray.init("ray://login01:10001")

print(ray.cluster_resources())      # wat ziet Ray?

@ray.remote(resources={"compute_node": 1})
def waar_draai_ik():
    time.sleep(1)
    return socket.gethostname()

start = time.time()
resultaten = ray.get([waar_draai_ik.remote() for _ in range(50)])
print(f"50 taken van 1 seconde, klaar in {time.time() - start:.1f}s")

for machine, aantal in sorted(Counter(resultaten).items()):
    print(f"  {machine:16} {aantal} taken")
```

Draaien:

```bash
uv run python hallo_ray.py
```

Je ziet zoiets:

```
50 taken van 1 seconde, klaar in 8.8s
  node001.cluster  7 taken
  node002.cluster  7 taken
  node003.cluster  6 taken
  node004.cluster  7 taken
  node005.cluster  7 taken
  node006.cluster  2 taken
  node007.cluster  7 taken
  node008.cluster  7 taken
```

Vijftig keer een seconde wachten zou vijftig seconden duren. Het duurde er
negen, verdeeld over acht machines. Dat is het hele punt van Ray in één
uitvoer.

---

## Wat je aanvraagt

`@ray.remote` zonder meer vraagt één CPU-kern. Meer nodig:

```python
@ray.remote(num_cpus=4)              # vier kernen voor deze taak
@ray.remote(num_gpus=1)              # een van de zestien GPU's
@ray.remote(memory=8 * 1024**3)      # 8 GB geheugen
```

### Weg van de loginnode blijven

De loginnode hoort bij de cluster, dus zonder aanwijzing kan je werk ook daar
terechtkomen — op dezelfde machine waarop iedereen inlogt. Er staat een eigen
resource klaar om dat te voorkomen:

| Wat je vraagt | Wat het doet |
|---|---|
| `resources={"compute_node": 1}` | één taak tegelijk per node, mooi gespreid |
| `resources={"compute_node": 0.01}` | alleen "niet op de loginnode", Ray kiest zelf |

Elke compute node heeft één eenheid `compute_node`. Vraag je er een hele, dan
is dat meteen een slot: acht taken tegelijk, netjes verdeeld. Vraag je een
fractie, dan is het puur een richtingaanwijzer en pakt Ray waar er plaats is —
sneller, maar geconcentreerd op een paar machines.

---

## Een actor: iets dat blijft staan

Een `@ray.remote`-functie begint elke keer opnieuw. Soms wil je dat niet — je
wil iets één keer inladen en daarna hergebruiken. Dat is een **actor**: een
object dat op een node blijft leven, met zijn eigen geheugen.

```python
@ray.remote(resources={"compute_node": 1})
class Verzamelaar:
    def __init__(self):
        self.totaal = 0
        self.machine = socket.gethostname()

    def tel(self, getal):
        self.totaal += getal
        return self.totaal

    def stand(self):
        return self.machine, self.totaal

teller = Verzamelaar.remote()
for i in range(5):
    teller.tel.remote(i)

print(ray.get(teller.stand.remote()))
```

```
('node004.cluster', 10)
```

Vijf aanroepen, en de optelling bleef bestaan tussen die aanroepen door — op
één bepaalde machine. Let op het verschil met een functie: `Verzamelaar.remote()`
maakt het object aan, en daarna roep je methodes aan met `.remote()`.

Waar dit werkelijk voor dient is niet tellen maar **iets zwaars één keer
klaarzetten**: een model in het geheugen laden, een databaseverbinding openen,
een grote tabel inlezen. Honderd taken die elk hetzelfde model inladen kosten
honderd keer die laadtijd; één actor laadt het één keer en beantwoordt honderd
vragen.

---

## Pakketten meesturen

Je taken draaien op machines waar jouw `uv`-omgeving niet geldt. Heeft je code
een pakket nodig, dan geef je dat mee — Ray installeert het op de nodes waar de
taak terechtkomt:

```python
@ray.remote(runtime_env={"pip": ["cowsay==6.1"]})
def iets_met_cowsay():
    import cowsay
    return "gelukt"
```

Of in één keer voor alles wat je daarna start:

```python
ray.init("ray://login01:10001", runtime_env={"pip": ["pandas==2.2.3"]})
```

En bij een ingediende job:

```bash
ray job submit --address http://login01:8265 --working-dir . \
  --runtime-env-json '{"pip": ["pandas==2.2.3"]}' -- python mijn_script.py
```

> De eerste taak met een nieuwe omgeving duurt langer, want dan wordt er
> geïnstalleerd. Ray bewaart die omgeving daarna, dus alleen de eerste keer
> betaal je. Zet er versies bij (`==2.2.3`): zonder versienummer krijg je op de
> ene node iets anders dan op de andere zodra er een nieuwe uitgave verschijnt.

Voor bestanden werkt het net zo: `--working-dir .` bij `ray job submit` stuurt
je projectmap mee. Binnen deze cluster heb je dat meestal niet nodig, want
`/trinity/home` staat op elke node — dat scheelt kopiëren.

---

## Het dashboard

`http://login01:8265` toont wat er draait, per node en per taak. Je komt er via
port forwarding in VS Code: **Ports** → **Forward a Port** → `login01:8265`,
en dan het wereldbolletje. Zie [containers](containers.md#erbij-met-je-browser)
voor die werkwijze.

---

## Als het geen demo meer is

Voor werk dat lang duurt is een verbinding vanuit een notebook kwetsbaar: valt
je laptop uit, dan is je berekening weg. Dien het dan in als Ray-job:

```bash
ray job submit --address http://login01:8265 --working-dir . -- python hallo_ray.py
```

Je code draait dan op de cluster zelf, met een job-id, logs die je later kan
opvragen, en zonder dat jouw machine verbonden hoeft te blijven.

---

## Er is meer dan taken en actors

Dit zijn de twee bouwstenen waar de rest op staat. Daarboven heeft Ray
bibliotheken voor werk dat je anders zelf zou schrijven:

| | Waarvoor |
|---|---|
| **[Ray Data](https://docs.ray.io/en/latest/data/data.html)** | grote datasets inlezen en bewerken, verdeeld over de nodes |
| **[Ray Train](https://docs.ray.io/en/latest/train/train.html)** | een model trainen over meerdere GPU's, met PyTorch of TensorFlow |
| **[Ray Tune](https://docs.ray.io/en/latest/tune/index.html)** | hyperparameters zoeken: honderden varianten tegelijk |
| **[Ray Serve](https://docs.ray.io/en/latest/serve/index.html)** | een getraind model als API aanbieden |

Ze gebruiken dezelfde cluster en dezelfde verbinding als hierboven. Ray Tune
op zestien GPU's is waarschijnlijk het punt waarop deze cluster zich voor jou
terugbetaalt — dat is werk dat op één machine dagen kost.

---

## Waarom Ray en niet Slurm

Ze doen allebei werk verdelen, maar op een ander niveau:

| | |
|---|---|
| **[Slurm](slurm.md)** | verdeelt *machines* over gebruikers. Je vraagt cores en tijd, je wacht, je krijgt ze |
| **Ray** | verdeelt *taken* over machines. Geen wachtrij, je code praat rechtstreeks met de cluster |

Voor een berekening die uren duurt: Slurm. Voor duizenden kleine taken, of iets
dat je interactief wil opbouwen: Ray.

> **Ze weten niet van elkaar.** Ray houdt de kernen van de compute nodes bezet
> buiten Slurm om, en Slurm kan diezelfde kernen nog eens uitdelen aan een job.
> Zolang het rustig is merk je daar niets van. Draait je Slurm-job trager dan
> verwacht terwijl `sinfo` zegt dat alles vrij is, dan is dit de verklaring.

---

## Verder

- [Rekenwerk indienen met Slurm](slurm.md)
- [Python, pakketten en git](python.md)
- [Werken in je eigen editor](editor.md)
