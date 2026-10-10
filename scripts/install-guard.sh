#!/usr/bin/env bash
# Install the gh-account-switcher push guard as a global git hook.
#   ./install-guard.sh            install (or update)
#   ./install-guard.sh --remove   uninstall
#
# Sets git's global core.hooksPath to ~/.config/gh-accounts/hooks. Every hook
# name there points at gh-accounts-hook, which runs the push check and then the
# repo's own .git/hooks/<name>, so per-repo hooks keep working.

set -euo pipefail
dir="${XDG_CONFIG_HOME:-$HOME/.config}/gh-accounts/hooks"
src="$(cd "$(dirname "$0")" && pwd)/gh-accounts-hook"

hook_names="applypatch-msg pre-applypatch post-applypatch pre-commit pre-merge-commit
prepare-commit-msg commit-msg post-commit pre-rebase post-checkout post-merge pre-push
post-rewrite push-to-checkout pre-auto-gc sendemail-validate"

current=$(git config --global --get core.hooksPath || true)

if [ "${1:-}" = --remove ]; then
    if [ "$current" = "$dir" ]; then
        git config --global --unset core.hooksPath
        echo "Removed the global hooks setting. Repos use their own .git/hooks again."
    else
        echo "The push guard isn't installed (core.hooksPath is '${current:-unset}')."
    fi
    rm -rf "$dir"
    exit 0
fi

if [ -n "$current" ] && [ "$current" != "$dir" ]; then
    echo "git already uses a global hooks folder: $current"
    echo "Not changing it. Copy $src into that folder as 'pre-push' instead (and chain any existing pre-push)."
    exit 1
fi

mkdir -p "$dir"
cp "$src" "$dir/gh-accounts-hook"
chmod +x "$dir/gh-accounts-hook"
for name in $hook_names; do
    ln -sf gh-accounts-hook "$dir/$name"
done
git config --global core.hooksPath "$dir"
echo "Push guard installed in $dir"
echo "Map orgs to accounts (optional): ${XDG_CONFIG_HOME:-$HOME/.config}/gh-accounts/owners"
echo "Undo with: $0 --remove"
