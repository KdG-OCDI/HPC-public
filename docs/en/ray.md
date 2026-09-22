# Distributed computing with Ray

*[Nederlands](../nl/ray.md) · [back to the procedure](README.md)*

[Ray](https://docs.ray.io/) spreads Python work across several machines. On
this cluster a Ray cluster is **permanently up**: you do not start anything,
you connect to it.

---

## What is running

| | |
|---|---|
| Head | `login01` |
| Workers | all eight compute nodes |
| Together | **1024 CPU cores**, **16 GPUs**, 2.79 TiB memory |
| Version | Ray **2.55.1** |
| Dashboard | `http://login01:8265` |

This is a different setup from the one most HPC guides describe. There you
start a Ray cluster *inside* a Slurm job and it disappears when the job ends.
Here it simply runs, so your code connects and gets going.

---

## Setting up your project

One thing is strict: **your Ray version must be exactly 2.55.1.** Client and
cluster speak a protocol that changes between versions; 2.44 or 2.56 will be
refused. So pin it in your project:

```bash
cd /trinity/home/$USER/projects/my-project
uv add "ray[client]==2.55.1"
```

Mind the **`[client]`**. Without it you get the minimal Ray, and you only find
out when you try to connect:

```
ValueError: Ray Client requires pip package `ray[client]`.
```

Working in a notebook needs two more:

```bash
uv add ipykernel ipywidgets
```

`ipykernel` turns your environment into a kernel VS Code can select;
`ipywidgets` is what Ray uses to show the progress of your tasks. If something
still asks for `pip`, `uv add pip` settles it.

It all ends up in your `pyproject.toml`, so anyone who clones your project gets
the same versions without having to know about them.

---

## Connecting

One line, the same everywhere:

```python
import ray
ray.init("ray://login01:10001")
```

From a notebook in [VS Code](editor.md), from a [notebook in the
portal](jupyter.md), and from an ordinary script. You do not need to know which
machine you are on — which is just as well, because a portal notebook runs on a
compute node while your VS Code terminal is on the login node.

> Examples on the internet often use `ray.init(address="auto")`. That does not
> work here: it looks for a Ray session on the machine you are on. Use the
> address above.

---

### From your own laptop

This also works without Remote-SSH, straight from a notebook or script on your
own machine. You need two things: the **VPN** on, and a **tunnel** to the
cluster, because port 10001 is not reachable from outside. How to read such a
line is explained under [containers](containers.md#without-vs-code-a-tunnel-with-ssh).

Leave this window open while you work:

```bash
ssh -L 10001:login01:10001 -L 8265:login01:8265 kdg-compute
```

In your code you then use `localhost` instead of `login01`, and you send your
project directory along — it is on your laptop, after all, not on the cluster:

```python
ray.init("ray://localhost:10001", runtime_env={"working_dir": "."})
```

Without `working_dir` your task cannot find your own modules: the code you
write runs on a compute node, not with you. Ray packs that directory up, sends
it along and unpacks it there.

> Keep that directory small. Ray refuses a `working_dir` over 100 MB, and you
> are sending it over the VPN. Datasets do not belong in it — put those on
> `/trinity/home` or in MinIO and let your tasks read them there. `.gitignore`
> is respected, so a `.venv` does not travel.

The version requirement holds here too: `ray[client]==2.55.1`, on Windows as well.

---

## Hello Ray

Create `hello_ray.py` in your project directory, or paste this into a notebook
cell:

```python
import ray
import socket
import time
from collections import Counter

ray.init("ray://login01:10001")

print(ray.cluster_resources())      # what does Ray see?

@ray.remote(resources={"compute_node": 1})
def where_am_i():
    time.sleep(1)
    return socket.gethostname()

start = time.time()
results = ray.get([where_am_i.remote() for _ in range(50)])
print(f"50 one-second tasks, finished in {time.time() - start:.1f}s")

for machine, count in sorted(Counter(results).items()):
    print(f"  {machine:16} {count} tasks")
```

Run it:

```bash
uv run python hello_ray.py
```

You should see something like:

```
50 one-second tasks, finished in 8.8s
  node001.cluster  7 tasks
  node002.cluster  7 tasks
  node003.cluster  6 tasks
  node004.cluster  7 tasks
  node005.cluster  7 tasks
  node006.cluster  2 tasks
  node007.cluster  7 tasks
  node008.cluster  7 tasks
```

Waiting one second fifty times should take fifty seconds. It took nine, spread
across eight machines. That is the whole point of Ray in one piece of output.

---

## What you ask for

A bare `@ray.remote` asks for one CPU core. If you need more:

```python
@ray.remote(num_cpus=4)              # four cores for this task
@ray.remote(num_gpus=1)              # one of the sixteen GPUs
@ray.remote(memory=8 * 1024**3)      # 8 GB of memory
```

### Staying off the login node

The login node is part of the cluster, so without a hint your work can land
there too — on the machine everyone logs in to. A custom resource exists to
prevent that:

| What you ask | What it does |
|---|---|
| `resources={"compute_node": 1}` | one task at a time per node, evenly spread |
| `resources={"compute_node": 0.01}` | only "not on the login node", Ray picks |

Each compute node has one unit of `compute_node`. Asking for a whole one makes
it a lock: eight tasks at a time, neatly distributed. Asking for a fraction
makes it a signpost, and Ray packs work wherever there is room — faster, but
concentrated on a few machines.

---

## An actor: something that stays

A `@ray.remote` function starts fresh every time. Sometimes that is not what
you want — you want to load something once and reuse it. That is an **actor**:
an object that stays alive on a node, with its own memory.

```python
@ray.remote(resources={"compute_node": 1})
class Collector:
    def __init__(self):
        self.total = 0
        self.machine = socket.gethostname()

    def add(self, number):
        self.total += number
        return self.total

    def state(self):
        return self.machine, self.total

counter = Collector.remote()
for i in range(5):
    counter.add.remote(i)

print(ray.get(counter.state.remote()))
```

```
('node004.cluster', 10)
```

Five calls, and the running total survived between them — on one particular
machine. Note the difference from a function: `Collector.remote()` creates the
object, and after that you call methods with `.remote()`.

What this is really for is not counting but **setting something heavy up
once**: loading a model into memory, opening a database connection, reading a
large table. A hundred tasks that each load the same model pay that loading
time a hundred times; one actor loads it once and answers a hundred questions.

---

## Sending packages along

Your tasks run on machines where your `uv` environment does not apply. If your
code needs a package, send it along — Ray installs it on the nodes where the
task lands:

```python
@ray.remote(runtime_env={"pip": ["cowsay==6.1"]})
def something_with_cowsay():
    import cowsay
    return "worked"
```

Or once, for everything you start afterwards:

```python
ray.init("ray://login01:10001", runtime_env={"pip": ["pandas==2.2.3"]})
```

And for a submitted job:

```bash
ray job submit --address http://login01:8265 --working-dir . \
  --runtime-env-json '{"pip": ["pandas==2.2.3"]}' -- python my_script.py
```

> The first task with a new environment takes longer, because that is when the
> installing happens. Ray keeps that environment afterwards, so you pay only
> once. Pin versions (`==2.2.3`): without one, a new release can give you
> something different on one node than on another.

Files work the same way: `--working-dir .` sends your project directory along
with `ray job submit`. Inside this cluster you rarely need it, because
`/trinity/home` is on every node — which saves the copying.

---

## The dashboard

`http://login01:8265` shows what is running, per node and per task. Reach it
through port forwarding in VS Code: **Ports** → **Forward a Port** →
`login01:8265`, then the globe icon. See
[containers](containers.md#reaching-them-with-your-browser) for that workflow.

---

## When it is no longer a demo

For work that takes a long time, a connection from a notebook is fragile: if
your laptop drops, your computation goes with it. Submit it as a Ray job
instead:

```bash
ray job submit --address http://login01:8265 --working-dir . -- python hello_ray.py
```

Your code then runs on the cluster itself, with a job id, logs you can fetch
later, and no need for your machine to stay connected.

---

## There is more than tasks and actors

Those two are the building blocks everything else rests on. Above them, Ray has
libraries for work you would otherwise write yourself:

| | For | Also install |
|---|---|---|
| **[Ray Data](https://docs.ray.io/en/latest/data/data.html)** | reading and transforming large datasets, spread across the nodes | `ray[data]` |
| **[Ray Train](https://docs.ray.io/en/latest/train/train.html)** | training a model across several GPUs, with PyTorch or TensorFlow | `ray[train]` |
| **[Ray Tune](https://docs.ray.io/en/latest/tune/index.html)** | hyperparameter search: hundreds of variants at once | `ray[tune]` |
| **[Ray Serve](https://docs.ray.io/en/latest/serve/index.html)** | serving a trained model as an API | `ray[serve]` |

Each of those is a separate extra at install time; `ray[client]` on its own
gives you tasks and actors and nothing more. You can combine them in one go,
and the version has to stay the same everywhere:

```bash
uv add "ray[client,data,train]==2.55.1"
```

They use the same cluster and the same connection as above. Ray Tune on sixteen
GPUs is probably the point where this cluster pays for itself — that is work
which takes days on a single machine.

---

## Why Ray and not Slurm

Both distribute work, but at a different level:

| | |
|---|---|
| **[Slurm](slurm.md)** | distributes *machines* among users. You ask for cores and time, you wait, you get them |
| **Ray** | distributes *tasks* among machines. No queue; your code talks to the cluster directly |

For one computation that runs for hours: Slurm. For thousands of small tasks,
or something you want to build up interactively: Ray.

> **They do not know about each other.** Ray holds the cores of the compute
> nodes outside Slurm's accounting, and Slurm can hand those same cores to a
> job. While things are quiet you will not notice. If a Slurm job runs slower
> than expected while `sinfo` says everything is free, this is why.

---

## Next

- [Submitting work with Slurm](slurm.md)
- [Python, packages and git](python.md)
- [Working in your own editor](editor.md)
