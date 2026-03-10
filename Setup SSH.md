# 🧑‍💻 SSH keys and VS Code Remote-SSH to access login node as `john`

This guide explains how you as user `john` can log in to the **login node (compute.kdg.be)** of your HPC cluster via SSH **without entering your password every time**.
We focus on both **WSL users** (Linux-like) and **Windows-native users** (PowerShell, Git Bash, VS Code).

You must always be connected to the school's **VPN** via GlobalProtect, unless you are on a campus as staff.
Students must always use the **VPN**.

### ⚠️ Note for Windows users:

Some commands, such as `ssh-copy-id`, do **not work well** from PowerShell/CMD.
Use WSL to perform the steps, and copy the result (e.g., the public key) manually to Windows if needed.

---

## 🧠 What are we doing and why?

SSH works with **public and private keys**:

* The **private key** stays on your local computer (secured with a passphrase)
* The **public key** goes on the login node (in `~/.ssh/authorized_keys`)
* SSH checks whether your private key matches the public key and grants you access **without a password**

To avoid entering your passphrase repeatedly, you use an **ssh-agent**, which temporarily "remembers" the key for you.

---

## 🔑 Step 1 – Generate an SSH key pair

> Only required if you don't have a key yet

### ✅ In WSL (recommended)

```bash
ssh-keygen -t ed25519 -f ~/.ssh/john_id_ed25519 -C "john access to login node"
```

### ✅ In Windows (PowerShell or Git Bash)

```powershell
ssh-keygen -t ed25519 -f "$env:USERPROFILE\.ssh\john_id_ed25519" -C "john access to login node"
```

Result:

* Private key: e.g. `~/.ssh/john_id_ed25519` or `C:\Users\<name>\.ssh\john_id_ed25519`
* Public key: `.pub` file with the same name

---

## 📤 Step 2 – Add public key to the login node (`compute.kdg.be`)

### ✅ Automatic (only possible in WSL)

```bash
ssh-copy-id -i ~/.ssh/john_id_ed25519.pub john@compute.kdg.be
```

### 🔧 Add manually (all platforms)

1. **Show your public key:**

   **In WSL:**

   ```bash
   cat ~/.ssh/john_id_ed25519.pub
   ```

   **In Windows:**

   ```powershell
   Get-Content $env:USERPROFILE\.ssh\john_id_ed25519.pub
   ```

2. **Log in to the login node:**

   ```bash
   ssh john@compute.kdg.be
   ```

3. **Add the key:**

   ```bash
   mkdir -p ~/.ssh
   chmod 700 ~/.ssh
   nano ~/.ssh/authorized_keys
   ```

   Paste the public key at the end. Save: `Ctrl+O`, exit: `Ctrl+X`.

   Then:

   ```bash
   chmod 600 ~/.ssh/authorized_keys
   ```

---

## ⚙️ Step 3 – Set up SSH configuration for convenience

In `~/.ssh/config` (WSL) or `C:\Users\<name>\.ssh\config` (Windows):

```ssh
Host login
  HostName compute.kdg.be
  User john
  IdentityFile ~/.ssh/john_id_ed25519  # WSL path or Windows path
  IdentitiesOnly yes
  ForwardAgent yes
```

Now use simply:

```bash
ssh login
```

---

## 🧠 Step 4 – Use `ssh-agent` so you only enter your passphrase once

### ✅ In WSL

```bash
eval "$(ssh-agent -s)"
ssh-add ~/.ssh/john_id_ed25519
```

> Add this to `~/.bashrc` or `~/.zshrc` for automatic use.

### ✅ In Windows (PowerShell)

```powershell
Start-Service ssh-agent
ssh-add $env:USERPROFILE\.ssh\john_id_ed25519
```

> Make sure you set the correct permissions:

```powershell
icacls "$env:USERPROFILE\.ssh\john_id_ed25519" /inheritance:r /grant:r "$env:USERNAME:F"
```

---

## 💻 Step 5 – Use with **VS Code Remote-SSH**

### 🔗 Install plugin:

👉 [Remote - SSH for Visual Studio Code](https://marketplace.visualstudio.com/items?itemName=ms-vscode-remote.remote-ssh)

### ✅ Configuration

1. Make sure your `~/.ssh/config` (or `C:\Users\<name>\.ssh\config`) contains the correct `Host login` entry (see above)
2. Open the Command Palette in VS Code:
   `Ctrl+Shift+P` → **Remote-SSH: Connect to Host...**
3. Choose `login`

---

## 🧪 Testing

```bash
ssh login
```

✅ Success = immediate access without password
🟡 Only passphrase if `ssh-agent` is not yet running

---

## 📌 Summary

| Step                 | WSL                                  | Windows-native                        |
| -------------------- | ------------------------------------ | ------------------------------------- |
| Create key           | `ssh-keygen`                         | `ssh-keygen`                          |
| Add public key       | `ssh-copy-id` or manually            | Manually                              |
| SSH config           | `~/.ssh/config`                      | `C:\Users\<name>\.ssh\config`        |
| Use ssh-agent        | `eval "$(ssh-agent -s)"` + `ssh-add` | `Start-Service ssh-agent` + `ssh-add` |
| Use in VS Code       | Remote-WSL or Remote-SSH plugin      | Remote-SSH plugin                     |

---

Let me know if you would like this as a `.md` file, PDF, or text file to add to your documentation — I'll prepare it for you right away.


# SSH configuration for the HPC cluster

**UPDATE: ⚠️ this is an earlier version of the step-by-step guide**

Here is a brief step-by-step guide to set everything up again. This assumes you have already generated an SSH key pair and have already added the public key to the `authorized_keys` of the controller.

---

### **Step 1: Generate SSH key pair**
You can do this by running the following commands:
```bash
ssh-keygen -t ed25519 -C "description of the key" "
```

On Windows you can do this with Git Bash or Windows Subsystem for Linux (WSL). It does not work with the standard Windows Command Prompt or PowerShell. You can then find the public key in `~/.ssh/id_ed25519.pub`. It is possible to copy this to your Windows SSH directory, so you can also use this key in Windows PowerShell.

Check if the key has been generated by running the following commands:
```bash
ls ~/.ssh
cat ~/.ssh/id_ed25519.pub
```

Optional: copy the key from your WSL environment to your Windows environment:

```bash
cp ~/.ssh/id_ed25519.pub /mnt/c/Users/your_username/.ssh/id_ed25519.pub
```

---

### **Step 2: Copy public key to the controller node**
1. **Use `ssh-copy-id` to add your public key to the `authorized_keys` on the controller node:**
   ```bash
   ssh-copy-id -i ~/.ssh/id_ed25519.pub root@datalab.kdg.be
   ```
2. **Test the connection to the controller:**
   ```bash
   ssh root@datalab.kdg.be
   ```
   You should now only need to enter your passphrase and have access.

---

### **Step 3: Copy public key to `node008` via the controller**
1. **Log in to the controller:**
   ```bash
   ssh root@datalab.kdg.be
   ```
2. **Copy your public key from the controller to `node008`:**
   ```bash
   ssh-copy-id -i ~/.ssh/id_ed25519.pub root@node008
   ```
3. **Test the connection from the controller to `node008`:**
   ```bash
   ssh root@node008
   ```
   You should now only need to enter your passphrase and have access.

---

### **Step 3: Configure `ProxyJump` on your local laptop**
1. **Open or create your SSH configuration file (`~/.ssh/config`) and add the following:**

   ```ssh
   Host controller
       HostName datalab.kdg.be
       User root
       IdentityFile ~/.ssh/id_ed25519
       DynamicForward 9090

   Host node008
       HostName node008
       User root
       ProxyJump controller
       IdentityFile ~/.ssh/id_ed25519
   ```

2. **Test the full connection via `ProxyJump`:**
   ```bash
   ssh -J root@datalab.kdg.be -i ~/.ssh/id_ed25519 root@node008
   ```
   You should now enter your passphrase twice: once for the controller and once for the compute node.

---

### **Summary of Intermediate Testing**
1. **To the controller (local → controller):**
   ```bash
   ssh root@datalab.kdg.be
   ```
   Expected: Enter passphrase once, access to the controller.

2. **To the compute node via the controller (controller → node008):**
   ```bash
   ssh root@node008
   ```
   Expected: Enter passphrase once, access to `node008`.
   Note: This was never necessary before, but this may have already been configured.

3. **Full connection via `ProxyJump` (local → controller → node008):**
   ```bash
   ssh -J root@datalab.kdg.be -i ~/.ssh/id_ed25519 root@node008
   ```
   Expected: Enter passphrase twice, access to `node008`.


Of course! Below you will find a clear, compact **summary in tutorial form**, following your existing documentation. I will build on your existing structure, with a focus on:

* Use as **user `john`**
* Key-based login via **login node (without ProxyJump)**
* Add to `ssh-agent` to avoid entering your passphrase every time
