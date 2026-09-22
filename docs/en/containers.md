# Running services in containers

*[Nederlands](../nl/containers.md) · [back to the procedure](README.md)*

The login node runs **Docker**. It is where you put the services that sit
alongside your computing and simply keep running: an MLflow server to track
experiments, a Postgres database, MinIO for object storage, LakeFS for
versioning your data.

---

## Before you start

**Docker runs on the login node only.** Not on the compute nodes. What you
start here lives on the machine you log in to — see
[how the cluster fits together](README.md#the-cluster-at-a-glance).

**You are normally in the docker group already.** New accounts are put in it
automatically. If you still get
`permission denied while trying to connect to the Docker daemon socket`, your
account is not in it — which can happen with older accounts. Send a mail to
[compute@kdg.be](mailto:compute@kdg.be).

**Containers are not for computing.** They share that one login node with
everyone. A database or a tracking server belongs there; training a model does
not — that goes through [Slurm](slurm.md).

---

## In VS Code: the Containers extension

Search the *Extensions* panel for **Containers** (from Microsoft) and install it
with the **Install in SSH: …** button — in your Remote-SSH window, not locally.
The extension talks to the Docker socket, and that socket is on the cluster.
Install it locally and it looks at Docker on your laptop, leaving the list
empty.

You then get containers, images and volumes in the sidebar. Right-click gives
you what you would otherwise type: **View Logs**, **Attach Shell**, stop,
restart, remove.

If you also write `Dockerfile`s, put **Docker DX** (from Docker itself) next to
it. It manages nothing, but checks your `Dockerfile` and `compose.yaml` as you
type.

---

## Starting a stack

Keep your `compose.yaml` in your project directory, like the rest of your
project:

```bash
cd /trinity/home/$USER/projects/my-project
docker compose up -d
docker compose ps
docker compose logs -f mlflow
```

Stop it with `docker compose down`. To drop the data as well, `docker compose
down -v` — that removes the volumes, so your databases really are empty
afterwards.

> **Pick your own ports.** The login node belongs to everyone, and there is
> only one port 5000. If something is already there you get `address already in
> use`. Agree a range with yourself — say `15000`, `15432`, `19000` — and stick
> to it across your projects. `ss -tlnp` shows what is already listening.

---

## Reaching them with your browser

The services listen on the login node, not on your laptop. You bring them to
you with port forwarding, and VS Code can do that for you.

1. Bottom panel → **Ports** tab (or `Ctrl+Shift+P` → *Ports: Focus on Ports
   View*)
2. **Forward a Port** → type the port number, for instance `5000`
3. Click the **globe icon** on that row

Often VS Code notices something has started listening and the row appears by
itself. That globe opens the page **inside VS Code**, in a tab next to your
code — no switching to your browser, and the tunnel is already handled.
`Ctrl+Shift+P` → *Simple Browser: Show* does the same for a URL you type
yourself.

Typical addresses, once the port is forwarded:

| Service | Address |
|---|---|
| MLflow | `http://localhost:5000` |
| MinIO console | `http://localhost:9001` |
| LakeFS | `http://localhost:8000` |
| Postgres | no web page — connect a database client to `localhost:5432` |

> If your service runs on a **compute node** rather than the login node, type
> `node002:8888` instead of just the port number. VS Code then forwards to that
> node, by way of the login node.

### Without VS Code: a tunnel with ssh

If you do not work in VS Code, one command does the same. Leave that window
open while you use the service:

```bash
ssh -L 5000:login01:5000 kdg-compute
```

The shape of `-L` is:

```
ssh -L <port on your machine>:<host as seen from the cluster>:<port there> kdg-compute
        └─ you choose this one        └─ looked up on the other side
```

Three things that usually clear it up:

- **Only the first number is yours to choose.** It is the port on your own
  machine; in your browser or your code you always use `localhost:<that
  number>`.
- **The name in the middle is resolved on the cluster**, not with you. That is
  why you can write `node002` there even though your laptop has never heard of
  that machine — login01 covers the rest of the distance.
- You will often see `localhost` in the middle. That always works — from
  login01, `localhost` is login01 — and writing `login01` reads more clearly,
  because it says where you end up. With one exception: a service listening on
  the machine itself only, such as the Ray Client, is reachable through
  `localhost` and nothing else. When in doubt, use `localhost`.

| Command | What you get |
|---|---|
| `-L 5000:login01:5000` | `localhost:5000` here is MLflow on the login node |
| `-L 15000:login01:5000` | the same, on port 15000 — useful when your 5000 is taken |
| `-L 8888:node002:8888` | `localhost:8888` here is port 8888 on **node002** |

That last one is the interesting one: it reaches a server you started yourself
in a job on a compute node, a vLLM server for instance.

Several ports at once works too, by repeating `-L`:

```bash
ssh -L 5000:login01:5000 -L 9001:login01:9001 -L 8265:login01:8265 kdg-compute
```


---

## Reaching them from a job

A job on a compute node runs on a different machine than your containers. If
you want to log to MLflow from your training run, first check that your job can
reach the login node:

```bash
srun --partition=defq --time=00:05:00 --pty bash
curl -s http://login01:5000/health
```

If that works, your script can log there with
`MLFLOW_TRACKING_URI=http://login01:5000`. Put it in your `.env` or in your job
script — see [environment variables](slurm.md#environment-variables).

---

## On a compute node: not yet

If you need a container for the computing itself, Docker is not an option
there: no daemon runs on the compute nodes, and it would run as root. The
usual answer on a cluster is **Apptainer** (formerly Singularity) or
**Podman** — both run as your own user, with your permissions.

**Neither is available on this cluster.** Only `node008` has Podman. If you
need containers inside a job, mail [compute@kdg.be](mailto:compute@kdg.be)
with what you want to run — that helps decide which of the two it becomes.

In the meantime: Python work rarely needs a container. An environment built
with [uv](python.md) lives on shared storage and is therefore identical on
every node — which is exactly what a container would buy you here.

---

## Next

- [Submitting work with Slurm](slurm.md)
- [Working in your own editor](editor.md)
- [Python, packages and git](python.md)
