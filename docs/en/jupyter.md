# A Jupyter notebook through the portal

*[Nederlands](../nl/jupyter.md) · [back to the procedure](README.md)*

The simplest way in: a notebook in your browser, with no terminal knowledge
required.

**You need first:** a working account
([step 2](README.md#2-run-one-command)) and an open tunnel to the portal
([step 5](README.md#5-reaching-the-web-portal)).

---

## Starting a notebook

On the portal's home page, click **Jupyter notebook** under *Interactive Apps*.

You fill in a form:

| Field | What to enter |
|---|---|
| **Account** | your account name |
| **Partition** | `defg` for ordinary work, `single_node` for debugging |
| **Number of nodes** | what you need, up to 8 |

Click **Connect**. Your request goes into Slurm's queue: the portal does not
start your notebook on the login node but on a compute node freed up for you.
On a busy cluster that can take a moment.

Once the session is running, a button appears to open it. You land in your own
directory, `/trinity/home/your_username`.

---

## Classic or Lab

You start in Jupyter Classic. *View → Lab* switches to JupyterLab, which adds a
file browser, tabs and a terminal.

---

## Where your files live

Everything under `/trinity/home/your_username` is on shared storage. You see
the same files when you log in over [SSH](editor.md), and a job on another node
sees them too.

Which means you can use a notebook to try something out, and then submit the
real work [as a job](slurm.md) against the same files.

---

## Installing packages

In a notebook, `!pip install` works within that session's environment. For an
environment that persists and that your jobs can use as well, set one up with
[uv](python.md) and start your notebook inside it.

---

## When you are done

End your session in the portal, under *My Interactive Sessions* → **Delete**.
While the session runs, that capacity stays reserved for you and nobody else
can use it.

Then close the tunnel with `Ctrl+C` and switch FoxyProxy off again.

---

## Next

- [Working in your own editor](editor.md) — VS Code, Cursor or PyCharm
- [Python, packages and git](python.md)
- [Submitting work with Slurm](slurm.md)
