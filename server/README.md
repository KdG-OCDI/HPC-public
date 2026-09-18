# Server-side: centrally managed SSH keys

This directory holds the login-node side of the onboarding automation. It is a
prerequisite for the planned self-service portal, but it is useful on its own.

## Why

Today every user's public key lives in `~/.ssh/authorized_keys`, inside a
directory the user fully controls. That has two practical downsides:

- A service that installs keys on a user's behalf has to write into home
  directories, and anything that can write there can also grant itself access.
- `sshd` silently ignores `~/.ssh` when its permissions are too permissive
  (`StrictModes`). This is a recurring source of "my key stopped working"
  tickets, and the cause is invisible to the user.

Adding a root-owned key directory fixes both. Existing keys keep working.

## 1. sshd configuration

In `/etc/ssh/sshd_config`:

```ssh-config
AuthorizedKeysFile /etc/ssh/authorized_keys.d/%u .ssh/authorized_keys
```

`sshd` tries each path in order, so **existing accounts are unaffected** —
anyone whose key is already in `~/.ssh/authorized_keys` keeps logging in
exactly as before, including accounts set up by `tools/kdg-hpc-setup.*`, which
still append there.

Two details worth knowing:

- This replaces the built-in default
  `.ssh/authorized_keys .ssh/authorized_keys2`. Dropping `authorized_keys2` is
  intentional; it has been deprecated for years and is unused here.
- Relative paths are resolved against the user's home directory; absolute paths
  are used as-is. `%u` expands to the username.

Apply it without locking yourself out:

```bash
sudo cp /etc/ssh/sshd_config /etc/ssh/sshd_config.bak
sudoedit /etc/ssh/sshd_config
sudo sshd -t && sudo systemctl reload sshd
```

`sshd -t` validates the config before the reload. **Keep your current SSH
session open** and confirm a new login works in a second terminal before
closing it. A reload does not drop existing sessions, so an open session is
your way back in if something is wrong.

## 2. Install the helper

`hpc-set-authorized-key` writes a validated public key to
`/etc/ssh/authorized_keys.d/<user>`. It runs as root and reads the key from
standard input.

```bash
sudo install -o root -g root -m 0755 hpc-set-authorized-key /usr/local/sbin/
sudo install -d -o root -g root -m 0755 /etc/ssh/authorized_keys.d
```

Usage:

```bash
# replace all keys for a user (default)
sudo hpc-set-authorized-key jan.janssens < id_ed25519.pub

# add one, leaving existing keys in place
sudo hpc-set-authorized-key --add jan.janssens < laptop2.pub

# revoke everything in the managed directory
sudo hpc-set-authorized-key --remove-all jan.janssens
```

What it refuses, and why it matters:

| Input | Result |
|---|---|
| `command="..." ssh-ed25519 AAAA...` | rejected — `authorized_keys` options can pin a forced command or relax restrictions, so only a bare key line is accepted |
| More than one line | rejected — one call installs one key |
| `ssh-dss`, unknown types | rejected — only ed25519, ecdsa, rsa and FIDO variants |
| RSA below 3072 bits | rejected |
| A system account (uid < 1000), or `root` | rejected — this holds even if the calling service is compromised |
| Anything `ssh-keygen -l` cannot parse | rejected |

Every call is written to the auth log via `logger`:

```bash
journalctl -t hpc-set-authorized-key
```

The previous file is kept as `<user>.bak` on each change.

## 3. Sudo rule for the self-service portal

When the portal is built, it should run as its own unprivileged user with a
single narrow sudo rule:

```sudoers
# /etc/sudoers.d/hpc-selfservice  (install with: visudo -f /etc/sudoers.d/hpc-selfservice)
hpcselfservice ALL=(root) NOPASSWD: /usr/local/sbin/hpc-set-authorized-key
```

The username argument is supplied by the portal and is therefore attacker-
controlled if the portal is ever compromised. That is why the helper does its
own validation rather than trusting its caller — the sudo rule restricts
*which binary* may run, not what it is asked to do.

## 4. Optional: migrate existing keys

Not required — the fallback in step 1 keeps existing keys working. Do this only
if you want every key centrally managed:

```bash
# Dry run first: show what would be migrated.
getent passwd | awk -F: '$3 >= 1000 {print $1 ":" $6}' | while IFS=: read -r u home; do
    [ -s "$home/.ssh/authorized_keys" ] && echo "$u ($home)"
done
```

Then migrate per user with `hpc-set-authorized-key < "$home/.ssh/authorized_keys"`,
one key at a time. Leave the original file in place until you have confirmed
the user can still log in.
