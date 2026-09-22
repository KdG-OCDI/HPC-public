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
cd /trinity/home/$USER/my-project
uv add "ray==2.55.1"
```

That puts it in your `pyproject.toml`, so nobody has to remember it.

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
