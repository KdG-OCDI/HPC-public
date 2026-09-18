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

Cluster accounts do not live in `/etc/passwd`. They live in the OpenLDAP
directory on the controller (`dc=local`), which every node reads through SSSD,
so they are created there — not with `useradd` on the login node, which would
produce an account that exists on one node only.

TrinityX ships `obol` for exactly this. It knows the existing structure,
allocates UID and GID numbers and keeps its own bookkeeping in `cn=uid` and
`cn=gid`. Write your own LDIF alongside it and the two allocators will
eventually hand out the same number — two accounts sharing a UID can read and
write each other's files, because the filesystem only ever sees the number.

`hpc-create-account` therefore calls `obol` for the account itself and adds
only what obol does not do: name validation, installing an SSH key, recording
the school account for SSO, and a variant where no password is created at all.

### Install

```bash
sudo install -o root -g root -m 0755 hpc-create-account /usr/local/sbin/
```

### Usage

Always look first — `--dry-run` prints the exact `obol` command and runs
nothing:

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

### Always pass `--upn`

The SSO login maps a school account to a cluster account by searching LDAP for
`(mail=<address>)`. An account without `mail` is invisible to that search, and
the mapping script then concludes the person is new and creates a second
account beside the existing one. `--upn` fills that field.

`--oid` records the Entra object ID next to it in
`/var/lib/hpc-accounts/registry.tsv`. It is the only identifier that never
changes — names and addresses do, on a name change, when duplicates get a `.1`
suffix, and when a student becomes staff and moves from `@student.kdg.be` to
`@kdg.be`.

A `@kdg.be` address (not `@student.kdg.be`) also adds the account to `staff`,
matching what the SSO mapping script does, so accounts created by hand and
accounts created by a first SSO login come out the same.

### Removing an account

```bash
obol user delete <username>
```

Check afterwards whether the home directory is gone. Files keep their UID
number, and obol reissues numbers once they are free, so an orphaned home
eventually becomes readable by whoever gets that number next. Either delete it
or `chown` it to root when archiving.

### Not needed here

`AccountingStorageEnforce` is `none`, so no Slurm association is required to
submit jobs. If that ever changes, account creation will also need
`sacctmgr create user`.

### Direct LDAP write access is no longer required

An earlier version of this script wrote LDIF itself, which needed an ACL rule
granting local root write access to the directory. `obol` authenticates with
its own credentials from `/etc/obol.conf`, so that rule is not needed any more.

If it was added and you want it gone:

```bash
printf 'dn: olcDatabase={1}mdb,cn=config\nchangetype: modify\ndelete: olcAccess\nolcAccess: {0}\n' | ldapmodify -Y EXTERNAL -H ldapi:///
```

Check what index the rule actually has first — deleting `{0}` removes whatever
sits in that position:

```bash
ldapsearch -LLL -Y EXTERNAL -H ldapi:/// -b cn=config '(olcSuffix=dc=local)' olcAccess
```

Keeping it is defensible too: it lets local root inspect and repair the
directory without the `cn=Manager` password. It grants nothing to anyone but
root on the controller.
