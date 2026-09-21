# Access to the KdG HPC cluster

*[Nederlandse versie](nl.md) · [back to the start page](../README.md)*

You have been given an account name and a one-time password by the HPC team.
The steps below set up your access in about two minutes.

| | |
|---|---|
| **Login node (SSH)** | `compute.kdg.be` |
| **Web portal** | Open OnDemand, through a tunnel (see [step 5](#5-the-graphical-environment)) |
| **Scheduler** | Slurm — `sbatch`, `srun`, `squeue` |

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

The script asks for your account name, and then **once** for your password at
the server's own prompt. That password goes straight to the cluster; the script
never reads or stores it.

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
| 8 | Offers to replace your password with a strong random one |

Your **private** key never leaves your laptop.

---

## 3. Connecting

```bash
ssh kdg-compute
```

`kdg-compute` is the name the script wrote into your `~/.ssh/config` — not an
address on the internet. If you have not run step 2, use your account name and
the real address:

```bash
ssh your_username@compute.kdg.be
```

**From your editor:**

- **VS Code / Cursor** — install the
  [Remote - SSH](https://marketplace.visualstudio.com/items?itemName=ms-vscode-remote.remote-ssh)
  extension, then `Ctrl+Shift+P` → *Remote-SSH: Connect to Host...* →
  `kdg-compute`
- **PyCharm** — *Settings → Tools → SSH Configurations* → `kdg-compute`

From there you open folders on the server and submit jobs with Slurm.

---

## 4. Your password

Step 8 of the script generates a strong password and puts it on your clipboard.
**Save it in your password manager.** You will not need it for SSH after this
setup, but it is your way back in if you ever lose your key.

If you skipped step 8, change your password later:

```bash
ssh kdg-compute passwd
```

---

## 5. The graphical environment

For Jupyter notebooks in your browser. This needs a working SSH account, so do
step 2 first.

The portal runs on an address that only exists inside the cluster network. Your
browser cannot resolve that name, not even on the VPN. So you send your browser
traffic through a tunnel that resolves the name on the cluster side.

### Step 1 — open the tunnel

```bash
ssh -N -D 9090 kdg-compute
```

This command blocks and prints nothing. That is expected: leave the window open
while you use the portal. Any port number above 1024 works instead of 9090.

### Step 2 — send your browser through the tunnel

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

### Step 3 — open the portal

Go to [https://controller1.cluster:8080](https://controller1.cluster:8080) and
click **Azure SSO Login** to sign in with your school account.

![Login page](../images/login_page.png)

### Step 4 — start a notebook

On the home page, click **Jupyter notebook** under *Interactive Apps*.

- Fill in your account name.
- Choose a partition:
  - `defg` — the whole cluster, shared. Select the number of nodes you need,
    up to 8.
  - `single_node` — `node001` only, for debugging.
- Click **Connect**. You land in your own directory.

You start in Jupyter Classic; switch to JupyterLab via *View → Lab*.

Email notifications are not configured yet.

### When you are done

Close the tunnel with `Ctrl+C` and switch FoxyProxy off again.

> This whole chapter goes away once the portal gets an address that works over
> the VPN. You will simply type an address in your browser, with no tunnel and
> no extension.

---

## 6. Lost access?

New laptop, or lost your key? Just run the setup script again on the new
machine — you will need your password for that.

Lost your password as well: contact the HPC team. Your identity is verified
through your KdG school account.

---

## 7. Troubleshooting

Run `ssh -v kdg-compute` — that output shows which key was offered and what the
server did with it.

| Message | Cause and fix |
|---|---|
| `compute.kdg.be is niet bereikbaar` | The VPN is off, or still connecting |
| `ssh.exe is niet gevonden` (Windows) | Run `Add-WindowsCapability -Online -Name OpenSSH.Client~~~~0.0.1.0` in PowerShell **as administrator** |
| `Permission denied` at the password prompt | Wrong account name or one-time password — get in touch |
| `Permission denied (publickey)` | Your key is not on the server. Run step 2 again |
| `WARNING: UNPROTECTED PRIVATE KEY FILE` | Your private key is readable by others: `chmod 600 ~/.ssh/id_ed25519` |
| Key ignored, no message at all | `sshd` refuses `~/.ssh` when its permissions are too broad: `chmod 700 ~/.ssh` |
| `Could not resolve hostname kdg-compute` | You have not run step 2 — use the full address |
| The test in step 7 fails | Normal if you set a passphrase on your key; test with `ssh kdg-compute` |
| Portal unreachable while the tunnel is open | FoxyProxy is off, or the name is being resolved locally (see step 5) |

Still stuck? Open an issue and include the **full output** of the script — it
contains no secrets.

---

## More

- [Manual SSH setup](../Setup%20SSH.md) — WSL, ssh-agent, several keys, and what
  the script does under the hood
