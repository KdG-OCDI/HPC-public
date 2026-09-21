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
cd /trinity/home/$USER
mkdir my-project && cd my-project
uv init
uv add numpy pandas
```

`uv` creates a `.venv` in that directory with your packages in it.

### Now open that folder in your editor

This is the step that makes the difference, and the one most easily skipped.

In **VS Code or Cursor**: *File → Open Folder* →
`/trinity/home/your_username/my-project`. The project directory itself, not
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

### Running your code

```bash
uv run python my_script.py
```

`uv run` makes sure your script uses this project's packages, without you
having to activate an environment.

> **Mind where this runs.** Your terminal is on the login node, so this command
> runs there too. Fine for checking that your script starts, or trying
> something small, but not for real computing: that one machine belongs to
> everyone. As soon as it takes more than a few seconds, submit it as a
> [job](slurm.md).

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

## In a job script

A job does not inherit your interactive environment. Whatever you loaded or
activated in your terminal is gone the moment Slurm starts your script on
another node.

So state what you need explicitly in the job script:

```bash
cd /trinity/home/$USER/my-project
uv run python my_script.py
```

This is the most common cause of "it works in my terminal but not in my job".

---

## Next

- [Submitting work with Slurm](slurm.md)
- [Working in your own editor](editor.md)
