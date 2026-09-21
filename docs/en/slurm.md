# Submitting work with Slurm

*[Nederlands](../nl/slurm.md) · [back to the procedure](README.md)*

Heavy work does not belong on the login node but in the queue. Slurm
distributes it across the compute nodes.

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

Create a file `job.sh` in your project directory:

```bash
#!/bin/bash
#SBATCH --job-name=my-first-job
#SBATCH --partition=defg
#SBATCH --nodes=1
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=4
#SBATCH --time=01:00:00
#SBATCH --output=slurm-%j.out

hostname
cd /trinity/home/$USER/my-project
uv run python my_script.py
```

The `#SBATCH` lines are not comments: they are your request. Below them are
ordinary shell commands that run on the node you are given.

Submit it:

```bash
sbatch job.sh
```

You get a job number back. The output lands in `slurm-<jobnumber>.out`, in the
directory where you ran `sbatch`.

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
your packages. A job does not inherit your interactive environment — see
[Python, packages and git](python.md).

---

## Next

- [Python, packages and git](python.md)
- [Working in your own editor](editor.md)
