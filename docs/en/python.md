# Python, packages and git

*[Nederlands](../nl/python.md) · [back to the procedure](README.md)*

How to set up a project with its own Python and its own packages.

---

## A per-project environment with uv

[uv](https://docs.astral.sh/uv/) handles the Python version, the virtual
environment and the packages in one. The environment belongs to the directory
rather than to your shell — so it travels to whichever compute node runs your
job.

Check whether it is already there:

```bash
which uv
```

If not, install it once, in your own directory:

```bash
curl -LsSf https://astral.sh/uv/install.sh | sh
source ~/.bashrc
```

Setting up a project:

```bash
mkdir -p /trinity/home/$USER/projects
cd /trinity/home/$USER/projects
mkdir my-project && cd my-project
uv init
uv add numpy pandas
```

`uv` creates a `.venv` in that directory with your packages in it.

### Now open that folder in your editor

This is the step that makes the difference, and the one most easily skipped.

In **VS Code or Cursor**: *File → Open Folder* →
`/trinity/home/your_username/projects/my-project`. The project directory itself, not
your home.

Then pick the environment `uv` created: `Ctrl+Shift+P` →
*Python: Select Interpreter* → the `.venv` inside your project.

From that point everything lines up: your terminal opens in the project
directory, autocompletion and debugging use the same packages as your script,
and a notebook you open in VS Code runs in the same environment. Open only your
home and VS Code finds a Python without your packages, making every `import`
look broken.

In **PyCharm**, open the project the same way and point the interpreter at the
`.venv`.

### Your first script

Create `hello.py` in your project directory:

```python
import os
import platform
import socket

import numpy as np

print(f"Hello HPC, from {socket.gethostname()}")
print(f"Python {platform.python_version()}, NumPy {np.__version__}")
print(f"Cores on this machine: {os.cpu_count()}")

job = os.environ.get("SLURM_JOB_ID")
if job:
    cores = os.environ.get("SLURM_CPUS_PER_TASK", "?")
    print(f"Running as job {job}, with {cores} cores assigned")
else:
    print("Not running as a job — you are on the login node")
```

Run it:

```bash
uv run python hello.py
```

`uv run` makes sure your script uses this project's packages, without you
having to activate an environment. You should see something like:

```
Hello HPC, from login01
Python 3.12.3, NumPy 2.1.1
Cores on this machine: 64
Not running as a job — you are on the login node
```

That last line is the point of this example.

> **Mind where this runs.** Your terminal is on the login node, so this command
> runs there too. Fine for checking that your script starts, or trying
> something small, but not for real computing: that one machine belongs to
> everyone. As soon as it takes more than a few seconds, submit it as a
> [job](slurm.md) — where the same script says something different.

A different Python version for this project:

```bash
uv python pin 3.11
```

---

## git

`git` is available. Clone your repository into your own directory and work
there:

```bash
cd /trinity/home/$USER
git clone https://github.com/your-org/your-project.git
cd your-project
uv sync          # installs what pyproject.toml or uv.lock specifies
```

A private repository needs a key or a token. The key you use to reach the
cluster is not meant for that — create a separate one on the cluster itself, or
use a token.

---

## Next

- [Submitting work with Slurm](slurm.md)
- [Working in your own editor](editor.md)
