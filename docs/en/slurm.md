# Submitting work with Slurm

*[Nederlands](../nl/slurm.md) · [back to the procedure](README.md)*

Heavy work does not belong on the login node but in the queue. Slurm
distributes it across the compute nodes.

---

## Useful tooling

Two things that make working with Slurm considerably more pleasant. Neither is
required — everything works with `sbatch` and `squeue` — but they save a lot of
going back and forth in the terminal.

**[sCode](https://github.com/dhimitriosduka1/sCode)** brings Slurm into VS
Code. Your running and pending jobs appear in the sidebar, showing how much of
your requested time is used up; you open log files with one click, and cancel
or hold jobs without typing a command. It also shows GPU usage per partition
and per user.

Install it from the VS Code Marketplace. Note that the extension has to run on
a machine that knows Slurm, so install it **in your Remote-SSH window**, not
locally — see [Working in your own editor](editor.md).

**[slurm-monitor-top](https://github.com/hforoughmand/slurm-monitor-top)** is an
`htop` for the cluster: one terminal screen with every job, which nodes are
free, what a job actually uses against what it requested, and your job output
streaming live. It refreshes every three seconds.

```bash
uv tool install slurm-monitor-top
slurm-top
```

Both are third-party tools and are not maintained by the HPC team.

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
#SBATCH --partition=defg
#SBATCH --nodes=1
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=4
#SBATCH --time=00:05:00
#SBATCH --output=slurm-%j.out

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

Ask for too little time and your job is killed when it runs out. Ask for far
too much and you end up further back in the queue. A generous but realistic
estimate works best.

### Partitions

| Partition | For |
|---|---|
| `defg` | The whole cluster, shared. Up to 8 nodes |
| `single_node` | `node001` only, for debugging |

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
srun --partition=defg --cpus-per-task=4 --time=01:00:00 --pty bash
```

You get a shell on a compute node as soon as there is room. Useful for trying
something before you submit it as a job.

**Leave with `exit` as soon as you are done.** While that shell is open, the
capacity stays reserved for you, even when you are doing nothing.

---

## The common mistake

You build your environment in your terminal, submit a job, and it cannot find
your packages.

A job does not inherit your interactive environment. Whatever you loaded,
activated or added to your `PATH` in your terminal is gone the moment Slurm
starts your script on another node — that shell does not exist there.

So state what you need explicitly in the job script. That is why the example
above has a `cd` into the project directory and a `uv run`, rather than just
`python hello.py`:

```bash
cd /trinity/home/$USER/my-project
uv run python hello.py
```

See [Python, packages and git](python.md) for setting that environment up.

---

## Next

- [Python, packages and git](python.md)
- [Working in your own editor](editor.md)
