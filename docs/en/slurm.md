# Submitting work with Slurm

*[Nederlands](../nl/slurm.md) · [back to the procedure](README.md)*

Heavy work does not belong on the login node but in the queue. Slurm
distributes it across the compute nodes.

---

## Useful tooling

Two VS Code extensions make working with Slurm considerably more pleasant.
Neither is required — everything works with `sbatch` and `squeue` — but they
save a lot of going back and forth in the terminal.

Search for them by name in the *Extensions* panel:

| Extension | What it gives you |
|---|---|
| **SLURM Cluster Manager** | Your jobs in the sidebar, showing how much of your requested time is used up. Log files with one click, cancelling jobs without a command, and GPU usage per partition |
| **SLURM Monitor** | A view of the whole cluster: which nodes are free, and what a job actually uses against what it requested |

> **Install them in your Remote-SSH window**, not locally. They need the Slurm
> commands, and those live on the cluster — see
> [Working in your own editor](editor.md).

Both are third-party and are not maintained by the HPC team:
[SLURM Cluster Manager](https://github.com/dhimitriosduka1/sCode),
[SLURM Monitor](https://github.com/hforoughmand/slurm-monitor-top).

---

## Why

**The login node is not for computing.** There you edit files, install things
and submit work. There is only one of it, and everyone shares it. Run a heavy
script there and you get in the way of everyone trying to log in or work at
that moment.

The compute nodes are where the computing belongs. You do not connect to them
directly: you request capacity, and Slurm gives it to you once it is free.

---

## Submitting a job

We use the same `hello.py` from
[Python, packages and git](python.md#your-first-script). Alongside it, create a
file `job.sh` in your project directory:

```bash
#!/bin/bash
#SBATCH --job-name=hello-hpc
#SBATCH --partition=defq
#SBATCH --nodes=1
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=4
#SBATCH --time=00:05:00
#SBATCH --output=slurm-%j.out
#SBATCH --error=slurm-%j.err

cd /trinity/home/$USER/my-project
uv run python hello.py
```

The `#SBATCH` lines are not comments: they are your request. Below them are
ordinary shell commands that run on the node you are given.

Submit it:

```bash
sbatch job.sh
```

You get a job number back, for instance `Submitted batch job 4711`. The output
lands in `slurm-4711.out`, in the directory where you ran `sbatch`:

```bash
cat slurm-4711.out
```

```
Hello HPC, from node003
Python 3.12.3, NumPy 2.1.1
Cores on this machine: 128
Running as job 4711, with 4 cores assigned
```

Compare that with what the same script said on the login node. A different
machine, and four cores Slurm set aside for you — that is the difference
between working on the login node and working on the cluster.

### Looking at your output

Three ways, and the last is by far the most pleasant:

```bash
cat slurm-4711.out        # once the job has finished
tail -f slurm-4711.out    # follow it while it runs, stop with Ctrl+C
```

In the VS Code terminal the filename is clickable: **Ctrl+click**
`slurm-4711.out` to open it as a tab. Or just double-click it in the file
browser on the left.

But with **SLURM Cluster Manager** you click the job itself and the output is
right there, including while it is still running. You do not have to remember
the job number, or which directory you ran `sbatch` in — which is exactly what
you are looking for at that moment.

> Error messages land in `slurm-4711.err`, thanks to the `--error` line in the
> script. Leave that out and everything ends up jumbled in the same file —
> keeping them apart saves searching.

---

## Environment variables

`sbatch` copies your current environment variables into the job by default;
that is what `--export=ALL` does, and it is already the setting.

That sounds convenient, but it is a trap: it makes your job depend on the
terminal you submitted it from. Today it works because you just set something,
tomorrow it fails from a fresh terminal. A fault that sometimes works is harder
to find than one that always fails.

So state in your script what you need, instead of trusting that it comes along.

**A `.env` in your project.** It does not need to go anywhere: your project
directory is on shared storage, so every node already sees that file. You only
have to have it read:

```bash
cd /trinity/home/$USER/my-project
uv run --env-file .env python hello.py
```

Or load it in your code with `python-dotenv`, if you use that already.

**One variable for this one job.** Put it in the script, above your command:

```bash
export SEED=42
uv run python hello.py
```

Or pass it at submission:

```bash
sbatch --export=ALL,SEED=42 job.sh
```

**What does not come along:** anything your `.bashrc` only does for interactive
shells. A job does not run an interactive shell, so none of that happens.

---

## What you are asking for

| Option | Meaning |
|---|---|
| `--partition` | where your job runs, see below |
| `--nodes` | number of machines |
| `--ntasks` | number of processes |
| `--cpus-per-task` | cores per process |
| `--time` | maximum run time, `hh:mm:ss` |
| `--output` | file for the output; `%j` becomes the job number |
| `--error` | file for the error messages |

Ask for too little time and your job is killed when it runs out. Ask for far
too much and you end up further back in the queue. A generous but realistic
estimate works best.

### Partitions

| Partition | For |
|---|---|
| `defq` | The whole cluster, shared. This is the default, so you may leave `--partition` out |
| `compute` | All eight nodes as well |
| `node001` … `node008` | One specific node, for debugging |

`sinfo` shows which partitions exist and whether they are free. The one with a
`*` after it is the default.

---

## Following and stopping

```bash
squeue -u $USER        # your own jobs and their state
squeue                 # everything in the queue
sinfo                  # which nodes exist and whether they are free
scancel <jobnumber>    # stops a job
```

In `squeue`, `R` means your job is running and `PD` that it is waiting. If it
stays at `PD`, the cluster is busy or you are asking for more than exists —
`sinfo` shows what is free.

---

## Working interactively

To type commands on a compute node yourself instead of submitting a script:

```bash
srun --partition=defq --cpus-per-task=4 --time=01:00:00 --pty bash
```

You get a shell on a compute node as soon as there is room. Useful for trying
something before you submit it as a job.

**Leave with `exit` as soon as you are done.** While that shell is open, the
capacity stays reserved for you, even when you are doing nothing.

### When your time runs out

Your shell is closed and you are back on the login node. Slurm sends a
`SIGTERM` to everything in your session and a `SIGKILL` thirty seconds later.
There is no warning beforehand.

What is gone: whatever was in memory — a running script, a Python session, a
half-finished calculation. What stays: everything written to disk. Your files
in `/trinity/home` are safe.

How much time you have left:

```bash
squeue -u $USER -O JobID,TimeLeft,TimeLimit
```

You cannot extend it: you may only lower your own time limit. Raising it takes
an administrator.

> Which is why an interactive session is unsuited to long work — you are stuck
> with the time you guessed in advance. Ask for eight hours to be safe and you
> end up further back in the queue *and* hold that capacity for as long as your
> shell is open, lunch included. For real work, [submitting a
> job](#submitting-a-job) is better.

---

## The common mistake

Your job cannot find your packages, while the same script works fine in your
terminal.

Usually that is because the script relies on where you happened to be standing
or what you happened to have activated. Which is why the example above starts
with a `cd` into the project directory and runs through `uv run`, rather than
just `python hello.py`:

```bash
cd /trinity/home/$USER/my-project
uv run python hello.py
```

That way your job hangs off your project directory rather than your shell. See
[Python, packages and git](python.md) for setting that environment up.

---

## Next

- [Python, packages and git](python.md)
- [Working in your own editor](editor.md)
