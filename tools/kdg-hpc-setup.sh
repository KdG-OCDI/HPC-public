#!/usr/bin/env bash
# KdG HPC - SSH setup (macOS / Linux)
#
# Zet in een keer je SSH-toegang tot de KdG HPC-cluster op:
#   - controleert de VPN-verbinding
#   - maakt een ed25519-sleutel aan (als je er nog geen hebt)
#   - plaatst je publieke sleutel op de loginnode (eenmalig wachtwoord)
#   - schrijft een blok in ~/.ssh/config voor VS Code / Cursor / PyCharm
#   - verifieert dat wachtwoordloos inloggen werkt
#
# Het script is idempotent: opnieuw draaien is veilig.
#
# Gebruik:  ./kdg-hpc-setup.sh [accountnaam]

set -euo pipefail

CLUSTER_HOST="${KDG_HPC_HOST:-compute.kdg.be}"
ALIAS="${KDG_HPC_ALIAS:-kdg-compute}"
KEY_PATH="${KDG_HPC_KEY:-$HOME/.ssh/id_ed25519}"
USERNAME="${1:-}"

if [ -t 1 ] && [ -z "${NO_COLOR:-}" ]; then
  C_HDR=$'\033[1m'; C_STEP=$'\033[36m'; C_OK=$'\033[32m'
  C_DIM=$'\033[90m'; C_WARN=$'\033[33m'; C_ERR=$'\033[31m'; C_OFF=$'\033[0m'
else
  C_HDR=""; C_STEP=""; C_OK=""; C_DIM=""; C_WARN=""; C_ERR=""; C_OFF=""
fi

STEP=0
step() { STEP=$((STEP+1)); printf '\n%s[%d] %s%s\n' "$C_STEP" "$STEP" "$*" "$C_OFF"; }
ok()   { printf '    %sOK%s  %s\n' "$C_OK" "$C_OFF" "$*"; }
info() { printf '    %s..  %s%s\n' "$C_DIM" "$*" "$C_OFF"; }
warn() { printf '    %s!   %s%s\n' "$C_WARN" "$*" "$C_OFF"; }
die()  { printf '\n%sFOUT: %s%s\n\n' "$C_ERR" "$*" "$C_OFF" >&2; exit 1; }

printf '\n  %sKdG HPC - SSH setup%s\n' "$C_HDR" "$C_OFF"
printf '  %s===================%s\n' "$C_HDR" "$C_OFF"

# ------------------------------------------------------------ 1. OpenSSH
step "OpenSSH-client controleren"
for exe in ssh ssh-keygen; do
  command -v "$exe" >/dev/null 2>&1 || die "$exe is niet gevonden. Installeer OpenSSH."
done
ok "$(ssh -V 2>&1)"

# ----------------------------------------------------------- 2. Username
step "Accountnaam"
if [ -z "$USERNAME" ]; then
  printf '    Je KdG HPC-accountnaam: '
  # Lees van de terminal, niet van stdin: bij `curl ... | bash` is stdin het
  # script zelf, en dan zou read de scripttekst opslurpen.
  if [ -r /dev/tty ]; then read -r USERNAME < /dev/tty; else read -r USERNAME; fi
fi
case "$USERNAME" in
  ''|*[!A-Za-z0-9._-]*) die "Ongeldige accountnaam: '$USERNAME'" ;;
esac
ok "Account: $USERNAME"

# ------------------------------------------------------ 3. Bereikbaarheid
step "Verbinding met $CLUSTER_HOST controleren (VPN)"
reachable=1
if command -v nc >/dev/null 2>&1; then
  nc -z -G 5 "$CLUSTER_HOST" 22 >/dev/null 2>&1 || nc -z -w 5 "$CLUSTER_HOST" 22 >/dev/null 2>&1 || reachable=0
else
  # Bash-only fallback zonder netcat
  (exec 3<>"/dev/tcp/$CLUSTER_HOST/22") >/dev/null 2>&1 || reachable=0
fi
[ "$reachable" -eq 1 ] || die "$CLUSTER_HOST is niet bereikbaar op poort 22.

Verbind eerst met de KdG GlobalProtect VPN (of gebruik het KdG-netwerk)
en start dit script daarna opnieuw."
ok "$CLUSTER_HOST bereikbaar"

# ------------------------------------------------------------ 4. Sleutel
step "SSH-sleutel"
mkdir -p "$(dirname "$KEY_PATH")"
chmod 700 "$(dirname "$KEY_PATH")"

if [ -f "$KEY_PATH" ]; then
  ok "Bestaande sleutel gevonden: $KEY_PATH"
else
  info "Er wordt een nieuw ed25519-sleutelpaar aangemaakt."
  info "Je mag bij de passphrase-vraag gewoon Enter drukken (geen passphrase),"
  info "of een passphrase kiezen voor extra beveiliging."
  echo
  ssh-keygen -t ed25519 -f "$KEY_PATH" -C "$USERNAME@$(hostname -s 2>/dev/null || hostname)"
  [ -f "$KEY_PATH" ] || die "ssh-keygen is mislukt."
  ok "Sleutel aangemaakt"
fi
chmod 600 "$KEY_PATH"
chmod 644 "$KEY_PATH.pub"

PUB="$(tr -d '\r\n' < "$KEY_PATH.pub")"
case "$PUB" in
  ssh-ed25519\ *|ssh-rsa\ *|ecdsa-*\ *) : ;;
  *) die "De publieke sleutel ziet er niet geldig uit: $KEY_PATH.pub" ;;
esac
case "$PUB" in *\'*) die "Publieke sleutel bevat een ongeldig teken (')." ;; esac

# -------------------------------------------------- 5. Sleutel uploaden
step "Publieke sleutel naar de loginnode kopieren"
info "Hierna vraagt de server EENMALIG je wachtwoord."
info "Je typt het rechtstreeks in bij de SSH-prompt; dit script ziet het niet."
echo

REMOTE_CMD="umask 077; mkdir -p ~/.ssh; touch ~/.ssh/authorized_keys; chmod 700 ~/.ssh; chmod 600 ~/.ssh/authorized_keys; grep -qxF '$PUB' ~/.ssh/authorized_keys || echo '$PUB' >> ~/.ssh/authorized_keys; echo SLEUTEL_GEPLAATST"

if out=$(ssh -n -o PreferredAuthentications=password,keyboard-interactive \
             -o PubkeyAuthentication=no \
             "$USERNAME@$CLUSTER_HOST" "$REMOTE_CMD" 2>&1) \
   && printf '%s' "$out" | grep -q SLEUTEL_GEPLAATST; then
  ok "Publieke sleutel staat in ~/.ssh/authorized_keys op de server"
else
  printf '%s%s%s\n' "$C_DIM" "$out" "$C_OFF"
  die "Kopieren van de sleutel is mislukt. Klopt je accountnaam en wachtwoord?"
fi

# ----------------------------------------------------------- 6. ssh config
step "~/.ssh/config bijwerken"
CFG="$HOME/.ssh/config"
BEGIN="# >>> $ALIAS (KdG HPC) >>>"
END="# <<< $ALIAS (KdG HPC) <<<"

USE_KEYCHAIN=""
[ "$(uname -s)" = "Darwin" ] && USE_KEYCHAIN="    UseKeychain yes"

if [ -f "$CFG" ] && grep -qF "$BEGIN" "$CFG"; then
  cp "$CFG" "$CFG.bak"
  awk -v b="$BEGIN" -v e="$END" '
    index($0,b){skip=1} !skip{print} index($0,e){skip=0}
  ' "$CFG.bak" > "$CFG"
  info "Bestaand blok vervangen (back-up: config.bak)"
fi

{
  [ -s "$CFG" ] && echo
  echo "$BEGIN"
  echo "Host $ALIAS"
  echo "    HostName $CLUSTER_HOST"
  echo "    User $USERNAME"
  echo "    IdentityFile $KEY_PATH"
  echo "    IdentitiesOnly yes"
  echo "    AddKeysToAgent yes"
  [ -n "$USE_KEYCHAIN" ] && echo "$USE_KEYCHAIN"
  echo "    ServerAliveInterval 60"
  echo "$END"
} >> "$CFG"
chmod 600 "$CFG"
ok "Host '$ALIAS' toegevoegd aan $CFG"

# ------------------------------------------------------------ 7. Verifieren
step "Wachtwoordloos inloggen testen"
if test_out=$(ssh -n -o BatchMode=yes -o ConnectTimeout=15 "$ALIAS" 'echo LOGIN_OK; hostname' 2>&1) \
   && printf '%s' "$test_out" | grep -q LOGIN_OK; then
  ok "Verbinding werkt zonder wachtwoord"
  info "Loginnode: $(printf '%s' "$test_out" | grep -v LOGIN_OK | tr -d '\n')"
else
  warn "De automatische test slaagde niet."
  printf '%s%s%s\n' "$C_DIM" "$test_out" "$C_OFF"
  warn "Als je sleutel een passphrase heeft, is dit normaal. Probeer handmatig: ssh $ALIAS"
fi

# ------------------------------------------- 8. Initieel wachtwoord vervangen
step "Initieel wachtwoord vervangen (aanbevolen)"
info "Je sleutel werkt nu. Voor SSH heb je het wachtwoord niet meer nodig,"
info "maar het blijft je noodingang. Vervang het startwachtwoord dus door"
info "een sterk, uniek wachtwoord en bewaar dat in je passwordmanager."
printf '    Nu een sterk wachtwoord genereren? [J/n] '
if [ -r /dev/tty ]; then read -r answer < /dev/tty; else read -r answer; fi

case "${answer:-j}" in
  [JjYy]*|'')
    # CSPRNG. pipefail staat uit in de subshell: head sluit de pipe vroeg af,
    # waardoor tr een SIGPIPE krijgt en de pipeline anders zou "falen".
    NEWPW="$(set +o pipefail; LC_ALL=C tr -dc 'A-Za-z0-9_.!@#%+=-' < /dev/urandom | head -c 24)"
    [ "${#NEWPW}" -eq 24 ] || die "Kon geen wachtwoord genereren."

    clipped=""
    if   command -v pbcopy  >/dev/null 2>&1; then printf '%s' "$NEWPW" | pbcopy  && clipped=1
    elif command -v wl-copy >/dev/null 2>&1; then printf '%s' "$NEWPW" | wl-copy && clipped=1
    elif command -v xclip   >/dev/null 2>&1; then printf '%s' "$NEWPW" | xclip -selection clipboard && clipped=1
    fi

    echo
    printf '    %sNieuw wachtwoord:%s %s\n' "$C_HDR" "$C_OFF" "$NEWPW"
    [ -n "$clipped" ] && info "(ook naar je klembord gekopieerd)"
    echo
    warn "Bewaar dit NU in je passwordmanager. Het staat in je terminal-"
    warn "geschiedenis, dus sluit dit venster daarna."
    echo
    info "De server vraagt zo eerst je HUIDIGE (initiele) wachtwoord,"
    info "daarna tweemaal het nieuwe. Plakken werkt; typen mag ook."
    echo

    # stdin expliciet van de terminal: bij `curl ... | bash` is stdin de download.
    rc=0
    if [ -r /dev/tty ]; then
      ssh -t "$ALIAS" passwd < /dev/tty || rc=$?
    else
      ssh -t "$ALIAS" passwd || rc=$?
    fi

    if [ "$rc" -eq 0 ]; then
      ok "Wachtwoord gewijzigd"
    else
      warn "Wachtwoord wijzigen is niet gelukt. Je sleutel werkt nog steeds."
      warn "Probeer later opnieuw met: ssh $ALIAS passwd"
    fi
    unset NEWPW
    ;;
  *)
    info "Overgeslagen. Wijzig het later met: ssh $ALIAS passwd"
    ;;
esac

printf '
  %sKlaar.%s

' "$C_OK" "$C_OFF"
echo "  Terminal      : ssh $ALIAS"
echo "  VS Code/Cursor: Remote-SSH: Connect to Host... > $ALIAS"
echo "  PyCharm       : Settings > Tools > SSH Configurations > $ALIAS"
printf '\n  %sVergeet niet je initiele wachtwoord te wijzigen met '"'"'passwd'"'"' op de server.%s\n\n' "$C_WARN" "$C_OFF"
