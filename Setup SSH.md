# SSH access by hand

**Most people do not need this page.** The setup script in
[docs/en/README.md](docs/en/README.md#2-run-one-command) does everything
below in about two minutes, and it is idempotent, so running it again is safe.

Read on if you want to understand what it does, if you prefer to do it
yourself, if you work from WSL or manage several keys, or if something went
wrong and you want to check each step separately.

Everything here assumes you are on the KdG network or connected to the
**GlobalProtect VPN**.

---

## How key-based login works

You create a pair of files that belong together:

- The **private key** stays on your own machine and never leaves it. Anyone who
  has it can log in as you, so it is protected by file permissions and,
  optionally, a passphrase.
- The **public key** goes on the login node, in `~/.ssh/authorized_keys`.
  It is not secret.

At login, the server challenges your client to prove it holds the private key.
Nothing secret crosses the network, which is why this is both safer and more
convenient than a password.

To avoid typing your passphrase every time, an **ssh-agent** holds the unlocked
key in memory for the rest of your session.

---

## Step 1 — Generate a key pair

Only if you do not have one yet. Check first:

```bash
ls ~/.ssh/id_ed25519.pub
```

If that file does not exist:

```bash
ssh-keygen -t ed25519 -C "your.name@kdg.be"
```

Press Enter to accept the default location. A passphrase is optional; with an
agent (step 4) you only type it once per session.

This works the same in macOS Terminal, Linux, WSL, Git Bash and **PowerShell** —
Windows 10 and 11 ship with OpenSSH. Older versions of this guide said
otherwise; that has not been true for years.

You now have two files:

| File | What it is |
|---|---|
| `~/.ssh/id_ed25519` | private key — never share or copy it off your machine |
| `~/.ssh/id_ed25519.pub` | public key — this is the one you upload |

On Windows these live in `C:\Users\<you>\.ssh\`.

---

## Step 2 — Put your public key on the login node

This is the only step that needs your password, and only once.

### macOS, Linux, WSL, Git Bash

```bash
ssh-copy-id your_username@compute.kdg.be
```

### Windows PowerShell

`ssh-copy-id` does not exist here. Do not pipe the file into `ssh`: PowerShell
re-encodes piped text, which corrupts the key on arrival. Read it into a
variable instead:

```powershell
$pub = (Get-Content -Raw "$env:USERPROFILE\.ssh\id_ed25519.pub").Trim()
ssh your_username@compute.kdg.be "umask 077; mkdir -p ~/.ssh; touch ~/.ssh/authorized_keys; grep -qxF '$pub' ~/.ssh/authorized_keys || echo '$pub' >> ~/.ssh/authorized_keys"
```

The `grep -qxF ... ||` part is what makes this safe to repeat: without it, a
second attempt appends a duplicate entry.

### Manually, on any platform

Show your public key, copy the whole line, then log in with your password and
paste it as a new line in `~/.ssh/authorized_keys`:

```bash
cat ~/.ssh/id_ed25519.pub                 # or: Get-Content on Windows
ssh your_username@compute.kdg.be
mkdir -p ~/.ssh && chmod 700 ~/.ssh
nano ~/.ssh/authorized_keys               # paste, then Ctrl+O, Ctrl+X
chmod 600 ~/.ssh/authorized_keys
```

---

## Step 3 — Give the connection a name

Add this to `~/.ssh/config` (`C:\Users\<you>\.ssh\config` on Windows):

```ssh-config
Host kdg-compute
    HostName compute.kdg.be
    User your_username
    IdentityFile ~/.ssh/id_ed25519
    IdentitiesOnly yes
    AddKeysToAgent yes
    ServerAliveInterval 60
```

On macOS, add `UseKeychain yes` to store the passphrase in the keychain.

`IdentitiesOnly yes` matters more than it looks: without it, your client offers
every key it knows about, and a server that allows only a few attempts may
refuse you before it reaches the right one.

You can now use `ssh kdg-compute` everywhere instead of the full address.

---

## Step 4 — Use an ssh-agent

Only needed if your key has a passphrase.

**macOS** — handled automatically by the `UseKeychain` line above.

**Linux and WSL:**

```bash
eval "$(ssh-agent -s)"
ssh-add ~/.ssh/id_ed25519
```

Add those lines to `~/.bashrc` or `~/.zshrc` to make it permanent.

**Windows PowerShell,** once, as administrator:

```powershell
Set-Service ssh-agent -StartupType Automatic
Start-Service ssh-agent
```

Then, as yourself:

```powershell
ssh-add $env:USERPROFILE\.ssh\id_ed25519
```

---

## Step 5 — Test, and connect from your editor

```bash
ssh kdg-compute
```

You should land on the login node without typing a password. If you are asked
for a passphrase, your agent is not running — the key itself is fine.

- **VS Code / Cursor** — install
  [Remote - SSH](https://marketplace.visualstudio.com/items?itemName=ms-vscode-remote.remote-ssh),
  then `Ctrl+Shift+P` → *Remote-SSH: Connect to Host...* → `kdg-compute`
- **PyCharm** — *Settings → Tools → SSH Configurations* → `kdg-compute`

From there you open folders on the server and submit jobs with Slurm
(`sbatch`, `srun`, `squeue`).

---

## Several machines, several keys

Generate a separate key on every machine you work from, and add each public key
to the login node. Never copy a private key between machines: a key you cannot
trace to one laptop is a key you cannot revoke when that laptop is lost.

Give each one a name so you can tell them apart later:

```bash
ssh-keygen -t ed25519 -f ~/.ssh/id_ed25519_laptop -C "your.name@kdg.be laptop"
```

Then point `IdentityFile` at the right one in your `~/.ssh/config`.

---

## When it does not work

Run `ssh -v kdg-compute` — the verbose output shows which key was offered and
what the server did with it.

| Symptom | Cause |
|---|---|
| `Permission denied (publickey)` | The public key is not on the server, or it is in the wrong file. Repeat step 2. |
| `WARNING: UNPROTECTED PRIVATE KEY FILE` | Your private key is readable by others. `chmod 600 ~/.ssh/id_ed25519`, or on Windows: `icacls "$env:USERPROFILE\.ssh\id_ed25519" /inheritance:r /grant:r "$($env:USERNAME):(R,W)"` |
| Key ignored without any message | `sshd` refuses `~/.ssh` when its permissions are too broad. `chmod 700 ~/.ssh` and `chmod 600 ~/.ssh/authorized_keys`. |
| Still asked for a passphrase | The agent is not running. See step 4. |
| `Too many authentication failures` | Your client offered too many keys. Add `IdentitiesOnly yes`. |
| Connection times out | VPN is not connected. |

Keys can also be installed centrally in `/etc/ssh/authorized_keys.d/<user>`,
which only administrators can write. If your own key works but a colleague's
does not, that is worth asking the HPC team about.

---

## Reaching a compute node directly

Normal work does not need this: you submit jobs from the login node with Slurm
and it places them on the nodes for you. For debugging a running job, you can
hop through the login node:

```ssh-config
Host node0*
    HostName %h
    User your_username
    ProxyJump kdg-compute
    IdentityFile ~/.ssh/id_ed25519
```

Then `ssh node001` connects through `compute.kdg.be` in one step. This works
only for nodes where you already have a running job.
