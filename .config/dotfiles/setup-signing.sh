#!/usr/bin/env bash
# Sign Git commits and tags with an SSH key on this machine. The settings go in
# ~/.gitconfig.local, which is not tracked. Safe to re-run.
#
#   ~/.config/dotfiles/setup-signing.sh [path/to/key.pub]
#
# Without an argument the first of id_ed25519, id_ecdsa and id_rsa in ~/.ssh is
# used.

set -euo pipefail

die() {
  echo "error: $*" >&2
  exit 1
}

public_key=${1:-}
if [[ -z $public_key ]]; then
  for candidate in "$HOME"/.ssh/id_ed25519.pub "$HOME"/.ssh/id_ecdsa.pub "$HOME"/.ssh/id_rsa.pub; do
    if [[ -f $candidate ]]; then
      public_key=$candidate
      break
    fi
  done
fi
[[ -n $public_key ]] || die "no SSH key found in ~/.ssh; create one with: ssh-keygen -t ed25519"
[[ -f $public_key ]] || die "$public_key does not exist"

email=$(git config user.email || true)
[[ -n $email ]] || die "set your Git email first: git config --file ~/.gitconfig.local user.email you@example.com"

# Git signs with ssh-keygen. Given the private key it works without ssh-agent;
# given only the public key, the private key must be loaded in ssh-agent.
signing_key=${public_key%.pub}
[[ -f $signing_key ]] || signing_key=$public_key

local_config="$HOME/.gitconfig.local"
git config --file "$local_config" user.signingKey "$signing_key"
git config --file "$local_config" commit.gpgSign true
git config --file "$local_config" tag.gpgSign true

# Lets `git log --show-signature` verify your own signatures on this machine.
# It contains your email, so it is listed in the dotfiles' ignore list.
signers="$HOME/.config/git/allowed_signers"
mkdir -p "$(dirname "$signers")"
entry="$email namespaces=\"git\" $(cut -d' ' -f1,2 "$public_key")"
grep -qxF -- "$entry" "$signers" 2>/dev/null || printf '%s\n' "$entry" >>"$signers"

echo "Commits and tags on this machine are now signed with $signing_key."
echo
echo "For GitHub to show them as Verified, add this public key as a *signing* key"
echo "(Settings > SSH and GPG keys > New SSH key > Key type: Signing Key):"
echo
cat "$public_key"
