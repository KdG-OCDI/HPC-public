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

---

## 5. Creating accounts

Cluster accounts do not live in `/etc/passwd`; they live in the OpenLDAP
directory on the controller (`dc=local`), which every node consults through
SSSD. So accounts are created there, not with `useradd` on the login node — a
local account would exist on one node only, invisible to the compute nodes and
showing up as a bare UID number on NFS.

### Write access

Reads over the Unix socket work out of the box, but writes do not: local root
authenticates as `gidNumber=0+uidNumber=0,cn=peercred,cn=external,cn=auth`,
which the existing ACLs only grant read. Rather than storing the `cn=Manager`
password in a file, grant that identity write access once:

```bash
slapcat -n0 -l /root/slapd-config-$(date +%F).ldif

cat <<'EOF' | ldapmodify -Y EXTERNAL -H ldapi:///
dn: olcDatabase={1}mdb,cn=config
changetype: modify
add: olcAccess
olcAccess: {0}to * by dn.exact="gidNumber=0+uidNumber=0,cn=peercred,cn=external,cn=auth" manage by * break
EOF
```

`by * break` is what keeps this safe: every other identity falls through to the
existing rules unchanged, including `by self write` on `userPassword` — without
it, users could no longer change their own password.

Credentials then live nowhere. The kernel vouches for the caller through the
socket, so there is no secret to leak, rotate or accidentally commit.

To undo:

```bash
printf 'dn: olcDatabase={1}mdb,cn=config\nchangetype: modify\ndelete: olcAccess\nolcAccess: {0}\n' | ldapmodify -Y EXTERNAL -H ldapi:///
```

### Install

```bash
sudo install -o root -g root -m 0755 hpc-create-account /usr/local/sbin/
```

### Usage

Always look first:

```bash
hpc-create-account --dry-run --name "Jan Janssens" --upn jan.janssens@kdg.be jan.janssens
```

Then create, with a one-time password:

```bash
hpc-create-account --name "Jan Janssens" --upn jan.janssens@kdg.be --oid <entra-object-id> jan.janssens
```

Or, if the user sent their public key from their school account, with no
password at all:

```bash
hpc-create-account --name "Jan Janssens" --upn jan.janssens@kdg.be --oid <entra-object-id> --key jan.pub jan.janssens
```

The second form is preferable: a password that does not exist cannot be
intercepted, reused or forgotten.

### What it does

Creates a personal group (`cn=<user>,ou=Group,dc=local`, `groupOfMembers` +
`posixGroup`) and the account (`uid=<user>,ou=People,dc=local`, matching the
object classes of the existing accounts), creates the home directory from
`/etc/skel`, optionally sets a random 24-character password via `ldappasswd`,
optionally installs an SSH key, and records the account in
`/var/lib/hpc-accounts/registry.tsv`.

If any step after the LDAP write fails, it removes what it created. A half
account is worse than none.

### Two things to know

**UID allocation ignores `cn=uid,dc=local`.** That counter says the next free
UID is 1050 while 1063 is already in use, so trusting it would hand out a UID
that already belongs to someone — and two accounts sharing a UID silently share
each other's files. The script scans for the highest number actually in use and
verifies the result against `getent` before using it. It does bump the counters
afterwards, so they stop drifting further.

**Record the Entra object ID with `--oid`.** It is the only identifier that
never changes. Names and email addresses do: on a name change, when duplicates
get a `.1` suffix, and when a student becomes staff and moves from
`@student.kdg.be` to `@kdg.be`. Matching on anything else will eventually match
the wrong person, and the planned self-service portal depends on it.

### Not needed here

`AccountingStorageEnforce` is `none`, so no Slurm association is required to
submit jobs. If that ever changes, account creation will also need
`sacctmgr create user`.
