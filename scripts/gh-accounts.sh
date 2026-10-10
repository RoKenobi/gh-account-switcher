# gh-accounts.sh: switch between several GitHub accounts as ONE person on ONE
# machine. Each switch changes both the commit identity (git user.name/email)
# and the account that pushes (gh's active account, used by git through
# `gh auth git-credential`).
#
# Source from ~/.bashrc or ~/.zshrc:   source ~/.gh-accounts.sh
#
#   gh_use <gh-login> "<Name>" <email>   switch everything to that account
#   gh_who                               show who commits and who pushes
#   gh_prompt                            "[login] " for your shell prompt
#
# Define one shortcut per account at the bottom of this file.
# Needs gh >= 2.40 (multi-account support) with each account logged in once.

_gh_accounts_host="${GH_ACCOUNTS_HOST:-github.com}"
# Last known active login, so the prompt doesn't have to ask gh (~0.4 s) every time.
_gh_accounts_state="${XDG_STATE_HOME:-$HOME/.local/state}/gh-accounts/active"

# Logins gh currently holds for the host, one per line, active one marked with "*".
_gh_accounts_list() {
    gh auth status --hostname "$_gh_accounts_host" 2>&1 | awk '
        /Logged in to .* account / { for (i = 1; i <= NF; i++) if ($i == "account") login = $(i + 1) }
        /Active account: true/      { if (login) print "*" login; login = "" }
        /Active account: false/     { if (login) print " " login; login = "" }'
}

_gh_accounts_save() {
    mkdir -p "${_gh_accounts_state%/*}" && printf '%s\n' "$1" >"$_gh_accounts_state"
}

# Prints "[login] " from the saved state. Instant; refreshed by gh_use, gh_who and every push.
gh_prompt() {
    local active
    [ -r "$_gh_accounts_state" ] && read -r active <"$_gh_accounts_state" && [ -n "$active" ] \
        && printf '[%s] ' "$active"
}

gh_use() {
    local login="$1" name="$2" email="$3"
    if [ -z "$login" ] || [ -z "$name" ] || [ -z "$email" ]; then
        echo "Usage: gh_use <gh-login> \"<Name>\" <email>"
        return 1
    fi
    if ! gh auth switch --help >/dev/null 2>&1; then
        echo "✘ Your gh ($(gh --version 2>/dev/null | head -1)) can't hold several accounts."
        echo "  Upgrade to gh 2.40+ from https://cli.github.com, then 'gh auth login' once per account."
        return 1
    fi
    if ! _gh_accounts_list | grep -qx "[* ]$login"; then
        echo "✘ $login is not logged in to gh. Run: gh auth login   (and pick $login)"
        echo "  Logged in now: $(_gh_accounts_list | tr -d '* ' | paste -sd' ' -)"
        return 1
    fi

    # Push account first: if this fails, the commit identity is left unchanged,
    # so you never end up committing as one account and pushing as another.
    local out
    if ! out=$(gh auth switch --hostname "$_gh_accounts_host" --user "$login" 2>&1); then
        echo "$out"
        return 1
    fi
    _gh_accounts_save "$login"
    git config --global user.name "$name"
    git config --global user.email "$email"
    echo "✔ Now committing as \"$name\" <$email> and pushing as $login."

    if git rev-parse --is-inside-work-tree >/dev/null 2>&1 && git config --local user.name >/dev/null; then
        echo "⚠ This repo has its own user.name ($(git config --local user.name)), which wins over the switch."
        echo "  Remove it with: git config --local --unset user.name; git config --local --unset user.email"
    fi
}

gh_who() {
    echo "Commits will say : $(git config user.name) <$(git config user.email)>"
    if git rev-parse --is-inside-work-tree >/dev/null 2>&1 && git config --local user.name >/dev/null; then
        echo "                   (set by this repo, not the global switch)"
    fi
    local list active
    list=$(_gh_accounts_list)
    active=$(printf '%s\n' "$list" | sed -n 's/^\*//p')
    [ -n "$active" ] && _gh_accounts_save "$active"
    echo "Pushes will use  : $active"
    echo "All gh accounts  : $(printf '%s\n' "$list" | tr -d '* ' | paste -sd' ' -)"
    if [ "$(git config --global --get core.hooksPath)" = "${XDG_CONFIG_HOME:-$HOME/.config}/gh-accounts/hooks" ]; then
        echo "Push guard       : on"
    fi
    if ! git config --get-all "credential.https://$_gh_accounts_host.helper" 2>/dev/null | grep -q 'gh auth git-credential'; then
        echo "⚠ git isn't using gh for $_gh_accounts_host logins, so pushes may ignore the switch. Run: gh auth setup-git"
    fi
}

# --- Your accounts: one shortcut per account. Edit these. ---
# git_personal() { gh_use your-personal-login "Your Name"     you@example.com; }
# git_work()     { gh_use your-work-login     "Your Name"     you@company.com; }
