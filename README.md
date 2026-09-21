# KdG HPC Cluster

Documentation for the KdG HPC cluster.

| | |
|---|---|
| **Login node (SSH)** | `compute.kdg.be` |
| **Cluster GUI** | `https://controller1.cluster:8080` (TrinityX, via SOCKS tunnel) |
| **Admin node** | `datalab.kdg.be` |
| **Scheduler** | Slurm (`sbatch`, `srun`, `squeue`) |

---

## 1. Network access

The cluster is only reachable from the KdG network.

- **On campus:** connect to the `KdG` WiFi SSID.
  *Researchers: the cluster is not reachable on the `NxT-Research` SSID.*
- **Remote:** connect with the **GlobalProtect VPN** —
  [instructions (NL)](https://studentkdg.sharepoint.com/sites/intranet-nl-ict/SitePages/GlobalProtect-(VPN).aspx)

Nothing below works without one of these two.

---

## 2. First-time setup — run one command

You received an account name and a one-time password from the HPC team.
With the VPN active, run the command for your platform. It takes about two minutes.

**Windows (PowerShell)**

```powershell
irm https://raw.githubusercontent.com/KdG-OCDI/hpc-public/main/tools/kdg-hpc-setup.ps1 | iex
```

**macOS / Linux (Terminal)**

```bash
curl -fsSL https://raw.githubusercontent.com/KdG-OCDI/hpc-public/main/tools/kdg-hpc-setup.sh | bash
```

Prefer to inspect the script before running it? Download it first:

```bash
curl -fsSL https://raw.githubusercontent.com/KdG-OCDI/hpc-public/main/tools/kdg-hpc-setup.sh -o kdg-hpc-setup.sh
less kdg-hpc-setup.sh && bash kdg-hpc-setup.sh
```

The script creates an `ed25519` key pair if you don't have one, installs your
**public** key on the login node, writes a `kdg-compute` entry in your local
`~/.ssh/config`, and verifies that password-less login works. Your **private**
key never leaves your machine, and the script never reads or stores your
password — you type it once at the login node's own SSH prompt.

Running it again is safe; it is idempotent.

Full walkthrough and troubleshooting: **[ONBOARDING.md](ONBOARDING.md)**
Manual steps, WSL, ssh-agent and multiple keys: **[Setup SSH.md](Setup%20SSH.md)**

### Connect

```bash
ssh kdg-compute
```

- **VS Code / Cursor** — install *Remote - SSH*, then `Connect to Host...` → `kdg-compute`
- **PyCharm** — *Settings → Tools → SSH Configurations* → `kdg-compute`

The script offers to replace your initial password with a strong random one and
puts it on your clipboard — **save it in your password manager**. You will not
need it for SSH after this setup, but it is your way back in if you ever lose
your key.

### Lost access?

New laptop or lost key: just run the setup command again on the new machine.
You will need your password for that step.

Lost your password as well: contact the HPC team. Your identity is verified
through your KdG school account.

> Password authentication on the login node will be disabled in the future.
> Make sure your public key is installed before then — the script above does this for you.

---

## 3. Cluster GUI access (TrinityX)

The GUI is not exposed outside the cluster network, so you reach it through a
SOCKS v5 tunnel over the login node. **This requires a working SSH account**
(see section 2).

1. Open the tunnel — it blocks; leave the terminal open:

   ```bash
   ssh -N -D 9090 kdg-compute
   ```

   Any port above 1024 works instead of 9090.

   `kdg-compute` is the alias the setup script wrote into your `~/.ssh/config`,
   not a hostname. Without it, use your account and the real address:

   ```bash
   ssh -N -D 9090 your_username@compute.kdg.be
   ```

2. Point your browser at the SOCKS proxy `localhost:9090`.
   Use the [FoxyProxy](https://addons.mozilla.org/en-US/firefox/addon/foxyproxy-standard/)
   extension rather than your system proxy settings (see below).

3. Go to [https://controller1.cluster:8080](https://controller1.cluster:8080)
   and click **Azure SSO Login** to sign in with your school account.

   ![TrinityX login page](images/login_page.png)

4. When you're done, close the tunnel with `Ctrl+C` and disable the proxy.

### FoxyProxy (recommended)

The controller node has internet access, so a system-wide proxy means you are
browsing the internet *through the cluster*. FoxyProxy lets you route only
cluster traffic through the tunnel. Add a wildcard include rule:

```
://controller1.cluster:*
```

Then select **Proxy by Patterns**.

![FoxyProxy settings](images/foxyproxy.png)
![FoxyProxy patterns](images/foxyproxy_patterns.png)

---

## 4. Starting a notebook

From the GUI home page, click **Jupyter notebook** under *Interactive Apps*.

- Fill in your user account.
- Choose a partition:
  - `defg` — the whole cluster, shared. Select the number of nodes you need (max 8).
  - `single_node` — `node001` only, for debugging.
- Click **Connect**. You land in your home directory.

You start in Jupyter Classic; switch to JupyterLab via *View → Lab*.

Email notifications are not configured yet.

---

## 5. Monitoring and alerts

The **HPC** team in KdG MS Teams receives alerts from the cluster's Grafana
dashboard. Email alerts are not configured yet.

---

## 6. Admin access

```bash
ssh <username>@datalab.kdg.be
```

---

## Repository layout

| Path | Contents |
|---|---|
| `README.md` | This file — start here |
| `ONBOARDING.md` | Step-by-step first-time setup and troubleshooting |
| `Setup SSH.md` | Manual SSH setup, WSL, ssh-agent, advanced configurations |
| `tools/kdg-hpc-setup.ps1` | Automated setup script — Windows |
| `tools/kdg-hpc-setup.sh` | Automated setup script — macOS / Linux |
| `server/` | Login-node configuration: centrally managed SSH keys |
| `images/` | Screenshots used in this documentation |

## Support

Problems with the setup script? Open an issue and include the **full output**
of the script (it contains no secrets).
