# Access to the KdG HPC cluster

*[Nederlandse versie](nl.md) · [back to the start page](../README.md)*

The HPC team has mailed you an account name and a password. The steps below set
up your access in about two minutes.

| | |
|---|---|
| **Login node (SSH)** | `compute.kdg.be` |
| **Your directory** | `/trinity/home/your_username`, visible on every node |
| **Scheduler** | Slurm — `sbatch`, `srun`, `squeue` |
| **Web portal** | Open OnDemand, through a tunnel (see [5.4](#54-a-jupyter-notebook-through-the-portal)) |

---

## 1. Connect to the network

The cluster is only reachable from the KdG network.

- **On campus:** connect to the `KdG` WiFi network.
- **From home:** turn on the **GlobalProtect VPN** —
  [instructions (NL)](https://studentkdg.sharepoint.com/sites/intranet-nl-ict/SitePages/GlobalProtect-(VPN).aspx)

Nothing below works without one of the two.

---

## 2. Run one command

Open your operating system's terminal and paste the command for your platform.
Use **Windows Terminal, PowerShell or Terminal.app** — not a terminal window
inside another application, where pasting does not always work and you will
need it for your password.

**Windows (PowerShell)**

```powershell
irm https://raw.githubusercontent.com/KdG-OCDI/hpc-public/main/tools/kdg-hpc-setup.ps1 | iex
```

**macOS or Linux (Terminal)**

```bash
curl -fsSL https://raw.githubusercontent.com/KdG-OCDI/hpc-public/main/tools/kdg-hpc-setup.sh | bash
```

Prefer to read the script first? Download it, then run it:

```bash
curl -fsSL https://raw.githubusercontent.com/KdG-OCDI/hpc-public/main/tools/kdg-hpc-setup.sh -o kdg-hpc-setup.sh
less kdg-hpc-setup.sh && bash kdg-hpc-setup.sh
```

The script asks for your account name, and then **once** for the password from
that mail, at the server's own prompt. That password goes straight to the
cluster; the script never reads or stores it.

Running it again is always safe — it applies nothing twice.

### What the script does

| Step | Action |
|---|---|
| 1 | Checks that the OpenSSH client is present |
| 2 | Asks for your account name |
| 3 | Checks that `compute.kdg.be` is reachable — catches "forgot the VPN" |
| 4 | Creates an `ed25519` key pair in `~/.ssh/` if you do not have one |
| 5 | Installs your **public** key on the login node |
| 6 | Adds a `kdg-compute` block to your local `~/.ssh/config` |
| 7 | Verifies that password-less login works |

Your **private** key never leaves your laptop.

---

## 3. Test your connection

```bash
ssh kdg-compute
```

You land on the login node without a password. Leave again with `exit`.

`kdg-compute` is the name the script wrote into your `~/.ssh/config` — not an
address on the internet. If you have not run step 2, use your account name and
the real address:

```bash
ssh your_username@compute.kdg.be
```

---

## 4. Your password

You needed the password from the mail once, in step 2. Not any more: from here
on you log in with your key.

**Keep that mail anyway**, or move the password to your password manager. It is
your way back in if you ever lose your key.

To replace it with one of your own, once your connection works:

```bash
ssh kdg-compute passwd
```

---

## 5. Working on the cluster

There are two ways, and most people use the first.

### 5.1 With VS Code, Cursor or PyCharm

You edit files on the cluster as if they were local, with your own editor,
extensions and shortcuts. Your terminal runs on the cluster.

**VS Code or Cursor**

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

**PyCharm** — *Settings → Tools → SSH Configurations* → `kdg-compute`, then
attach it to a *Remote Interpreter* or *Deployment*.

> Work in your own directory under `/trinity/home/`. It lives on shared storage
> and is therefore visible on whichever node your job lands. Files you put
> outside it on one node cannot be seen elsewhere.

### 5.2 Python, packages and git

A handful of modules is available, listed by `module avail`:

| Module | |
|---|---|
| `python/3.12`, `python/3.9` | Python; 3.12 is the default |
| `cmake`, `gnu13`, `hwloc`, `pmix` | build tooling and MPI components |
| `ood-vnc` | for graphical sessions through the portal |

Load one like this:

```bash
module load python/3.12
```

For most projects, though, a per-directory environment is more comfortable.
[uv](https://docs.astral.sh/uv/) handles the Python version, the virtual
environment and the packages in one, and needs no module.

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
uv run python my_script.py
```

`git` is available, so you can clone a repository and work inside it.

> **Watch out in a job script.** A job does not inherit your interactive
> environment. Load your modules again there, and start your code through
> `uv run`, so the job uses the same packages you do in your terminal.

### 5.3 Submitting work with Slurm

This is the most important thing to know, and the thing that most often goes
wrong.

**The login node is not for computing.** There you edit files, install things
and submit work. The actual computing goes to the compute nodes, and Slurm
distributes it. Run a heavy script directly on the login node and you get in
the way of everyone trying to log in at that moment.

**Submitting a job.** Create a file `job.sh`:

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

Submit and follow it:

```bash
sbatch job.sh          # submits the job, prints the job number
squeue -u $USER        # shows your own jobs and their state
scancel <jobnumber>    # stops a job
```

The output ends up in `slurm-<jobnumber>.out`, in the directory where you ran
`sbatch`.

**Partitions.** `--partition` decides where your job runs:

| Partition | For |
|---|---|
| `defg` | The whole cluster, shared. Up to 8 nodes |
| `single_node` | `node001` only, for debugging |

**Working interactively.** To type commands on a compute node yourself instead
of submitting a script:

```bash
srun --partition=defg --cpus-per-task=4 --time=01:00:00 --pty bash
```

That gives you a shell on a compute node. Leave with `exit` as soon as you are
done — while that shell is open, the capacity stays reserved for you.

**What is running:**

```bash
sinfo                  # which nodes exist and whether they are free
squeue                 # every job in the queue
```

> Which software is available and how to set up your environment differs per
> field. Ask the HPC team at [compute@kdg.be](mailto:compute@kdg.be).

### 5.4 A Jupyter notebook through the portal

Useful if you prefer to work in your browser. This needs a working SSH account,
so do step 2 first.

The portal runs on an address that only exists inside the cluster network. Your
browser cannot resolve that name, not even on the VPN. So you send your browser
traffic through a tunnel that resolves the name on the cluster side.

**Step 1 — open the tunnel**

```bash
ssh -N -D 9090 kdg-compute
```

This command blocks and prints nothing. That is expected: leave the window open
while you use the portal. Any port number above 1024 works instead of 9090.

**Step 2 — send your browser through the tunnel**

Use [FoxyProxy](https://addons.mozilla.org/firefox/addon/foxyproxy-standard/),
available for Firefox, Chrome and Edge. You can also do this in your operating
system's settings, but then **all** your internet traffic goes through the
cluster, including ordinary browsing. FoxyProxy lets you limit it to the
cluster address.

Create a proxy of type **SOCKS5**, host `localhost`, port `9090`:

![FoxyProxy settings](../images/foxyproxy.png)

Then add a rule of type *wildcard* with this pattern, and select
**Proxy by Patterns**:

```
://controller1.cluster:*
```

![FoxyProxy patterns](../images/foxyproxy_patterns.png)

> **Important with SOCKS5:** the name `controller1.cluster` has to be resolved
> on the cluster side, not on your laptop. In Firefox that is the
> *Proxy DNS when using SOCKS v5* checkbox; FoxyProxy sets it correctly by
> itself. Doing this through your system settings often fails for exactly this
> reason.

**Step 3 — open the portal**

Go to [https://controller1.cluster:8080](https://controller1.cluster:8080) and
click **Azure SSO Login** to sign in with your school account.

![Login page](../images/login_page.png)

**Step 4 — start a notebook**

On the home page, click **Jupyter notebook** under *Interactive Apps*.

- Fill in your account name.
- Choose a partition: `defg` for ordinary work, `single_node` for debugging.
- Choose the number of nodes you need, up to 8.
- Click **Connect**. You land in your own directory.

You start in Jupyter Classic; switch to JupyterLab via *View → Lab*.

Email notifications are not configured yet.

**When you are done** — close the tunnel with `Ctrl+C` and switch FoxyProxy
off again.

> The tunnel and proxy go away once the portal gets an address that works over
> the VPN. You will simply type an address in your browser.

---

## 6. Lost access?

**New laptop, old one still in use.** Run the setup script on the new machine.
A second key is added; the one from your old laptop keeps working. You need the
password from the mail for this.

**Key lost or laptop stolen.** Run the script on your new machine, then remove
the old key from the server — otherwise whoever has that laptop keeps access.
Log in and open the file:

```bash
ssh kdg-compute
nano ~/.ssh/authorized_keys
```

Each line is one key, ending in a name such as `your_username@OLD-LAPTOP`.
Delete the line for the machine you lost, then save with `Ctrl+O`, `Ctrl+X`.

**Password lost too.** Contact the HPC team at
[compute@kdg.be](mailto:compute@kdg.be). Your identity is verified through your
KdG school account.

---

## 7. Troubleshooting

Run `ssh -v kdg-compute` — that output shows which key was offered and what the
server did with it.

| Message | Cause and fix |
|---|---|
| `compute.kdg.be is niet bereikbaar` | The VPN is off, or still connecting |
| `ssh.exe is niet gevonden` (Windows) | Run `Add-WindowsCapability -Online -Name OpenSSH.Client~~~~0.0.1.0` in PowerShell **as administrator** |
| `Permission denied` at the password prompt | Wrong account name or password — get in touch |
| `Permission denied (publickey)` | Your key is not on the server. Run step 2 again |
| `WARNING: UNPROTECTED PRIVATE KEY FILE` | Your private key is readable by others: `chmod 600 ~/.ssh/id_ed25519` |
| Key ignored, no message at all | `sshd` refuses `~/.ssh` when its permissions are too broad: `chmod 700 ~/.ssh` |
| `Could not resolve hostname kdg-compute` | You have not run step 2 — use the full address |
| The test in step 7 fails | Normal if you set a passphrase on your key; test with `ssh kdg-compute` |
| Your job sits at `PD` in `squeue` | The cluster is busy, or you asked for more than exists. `sinfo` shows what is free |
| Portal unreachable while the tunnel is open | FoxyProxy is off, or the name is being resolved locally (see 5.4) |

Still stuck? Open an
[issue](https://github.com/KdG-OCDI/hpc-public/issues) or mail
[compute@kdg.be](mailto:compute@kdg.be), with the **full output** of the script
— it contains no secrets.

---

## More

- [Manual SSH setup](../Setup%20SSH.md) — WSL, ssh-agent, several keys, and what
  the script does under the hood
