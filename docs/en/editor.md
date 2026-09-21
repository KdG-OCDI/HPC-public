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

**Notebooks work here too.** Open a `.ipynb` in VS Code and pick your
[uv environment](python.md) as the kernel. That gives you a notebook with no
tunnel and no portal.

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

Files you put outside it on one node — in `/tmp`, say — cannot be seen
elsewhere. A job running on another node will not find them.

---

## Next

- [Python, packages and git](python.md) — setting up your environment
- [Submitting work with Slurm](slurm.md) — when your script gets heavier
- [A notebook in your browser](jupyter.md) — through the portal
