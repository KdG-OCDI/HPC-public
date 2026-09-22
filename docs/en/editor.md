# Working in your own editor

*[Nederlands](../nl/editor.md) · [back to the procedure](README.md)*

You edit files on the cluster as if they were local, with your own editor,
extensions and shortcuts. Your terminal runs on the cluster. This is how most
people here work.

**You need first:** a working account ([step 2](README.md#2-run-one-command)).
No tunnel, no portal.

---

## VS Code or Cursor

1. Install the
   [Remote - SSH](https://marketplace.visualstudio.com/items?itemName=ms-vscode-remote.remote-ssh)
   extension.
2. `Ctrl+Shift+P` → *Remote-SSH: Connect to Host...* → `kdg-compute`.
3. A new window opens. The bottom left says **SSH: kdg-compute**.
4. *File → Open Folder* → your own directory, for example
   `/trinity/home/your_username`.
5. *Terminal → New Terminal* gives you a shell on the login node.

The first time, VS Code installs a small helper on the server. That takes a
moment and does not happen again.

> `kdg-compute` is the name the setup script wrote into your `~/.ssh/config`.
> If it is not in the list, you have not run step 2 yet.

### Worth knowing

**Your extensions run on the server.** Python, Jupyter, linters: VS Code
installs them again on the cluster side. That is what you want — they see the
same files and the same Python as your code.

**Your terminal is on the login node.** That is the place to edit files and
submit work, not to compute. See [Slurm](slurm.md).

**You can run notebooks here too.** Open a `.ipynb` in VS Code and pick your
[uv environment](python.md) as the kernel. You then work in a notebook without
needing the portal and the tunnel from step 5.

Do mind where such a notebook runs: on the login node, like your terminal. Fine
for trying something out or drawing a chart, but as soon as a cell computes for
more than a few seconds, that work belongs in a [job](slurm.md) or on the [Ray
cluster](ray.md).

---

## PyCharm

1. *Settings → Tools → SSH Configurations* → add `kdg-compute`.
2. Attach it to a **Remote Interpreter** (*Settings → Project → Python
   Interpreter → Add → SSH Interpreter*), or to **Deployment** if you prefer to
   synchronise files.

PyCharm Professional has this built in; the Community edition does not.

---

## Where to put your files

Work in your own directory under `/trinity/home/`. It lives on shared storage
and is therefore visible on whichever node your job lands.

**Give every project its own directory**, and keep them together under one
`projects` directory:

```
/trinity/home/your_username/
└── projects/
    ├── thesis/            ← its own .venv, its own pyproject.toml
    ├── image-recognition/ ← its own .venv
    └── exercises/
```

This is not tidiness for its own sake: [uv](python.md) creates a `.venv` per
project directory, with its own package versions. Throw everything into your
home and you get one environment in which one project undermines the next as
soon as two packages need different versions. And in VS Code you open that one
project directory, not your home — otherwise the editor cannot find your
environment.

Files you put outside it on one node — in `/tmp`, say — cannot be seen
elsewhere. A job running on another node will not find them.

---

## Next

- [Python, packages and git](python.md) — setting up your environment
- [Submitting work with Slurm](slurm.md) — when your script gets heavier
- [A notebook in your browser](jupyter.md) — through the portal
