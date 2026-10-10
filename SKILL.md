---
name: gh-account-switcher
description: Set up one-command switching between several GitHub accounts (for example personal and work) for ONE person on their own Linux or macOS machine. Each switch changes both the commit author (git user.name/email) and the account that pushes (gh's active account). Use this skill whenever the user has more than one GitHub account, wants to push or create repos as a different account, says pushes or new repos land on the wrong account, has git_personal / git_work style aliases that only change user.name/email, hits "unknown shorthand flag 'u'" from `gh auth switch`, finds that `gh auth login` logged out their other account, or asks how to switch accounts before pushing, even if they never say "switcher". For several PEOPLE sharing one Linux login, use git-profile-switcher instead.
---

# GitHub Account Switcher (one person, several accounts)

Lets one person move between GitHub accounts with a single command, such as `git_personal` or `git_work`. The command changes **who the commits say** and **which account pushes**, together.

## Pick the right skill first

| Situation | Use |
|---|---|
| One person, own machine, two or more GitHub accounts | **this skill** |
| Several people share one Linux login (lab PC, robot, shared server) and must not use each other's tokens | **git-profile-switcher**: per-repo identity, token asked per person, nothing global |

This skill makes **global** changes: one switch affects every repo and every terminal for that user. That's what a single person wants, and exactly what a shared login must avoid.

## How it works

There are two separate settings, and most "wrong account" problems come from changing only one of them:

1. **Commit identity**: `git config --global user.name / user.email`. This is only a label written into each commit. **It does not decide which account pushes.**
2. **Push account**: when git needs a GitHub login, it asks its credential helper. With `gh auth setup-git`, that helper is `gh auth git-credential`, which hands over the token of **gh's active account**.

gh 2.40 and later can hold several accounts per host and switch the active one with `gh auth switch -u <login>`. The bundled `scripts/gh-accounts.sh` provides `gh_use`, which does both steps: it switches the push account first and only then the identity. If the switch fails, the identity is left unchanged, so the user never commits as one account while pushing as another.

## Setup

Walk the user through these steps in order, checking each one. Steps that need `sudo` must be run by the user. Give them the commands in **short lines**: when a long `... | sudo tee file > /dev/null` line wraps while pasting, the shell sees a stray `>` and the file is never written.

### 1. Check the gh version

```bash
gh --version
gh auth switch --help >/dev/null 2>&1 && echo "multi-account OK" || echo "too old"
```

Version 2.40 or newer is needed. **Ubuntu 22.04's apt package is gh 2.4.0** (2022). It holds one account per host, and each `gh auth login` replaces the previous account.

### 2. Upgrade gh if needed

Debian/Ubuntu, from GitHub's official repo:

```bash
sudo mkdir -p -m 755 /etc/apt/keyrings
URL=https://cli.github.com/packages/githubcli-archive-keyring.gpg
KEY=/etc/apt/keyrings/githubcli-archive-keyring.gpg
wget -qO- "$URL" | sudo tee "$KEY" >/dev/null
ARCH=$(dpkg --print-architecture)
echo "deb [arch=$ARCH signed-by=$KEY] https://cli.github.com/packages stable main" | sudo tee /etc/apt/sources.list.d/github-cli.list
sudo apt update
sudo apt install gh
gh --version
```

macOS: `brew install gh` (or `brew upgrade gh`). Fedora: `sudo dnf install gh`. Other systems: https://github.com/cli/cli#installation

After upgrading from 2.4, check `gh auth status`. **The login from the old version may not carry over**, so expect to log in again in step 3.

### 3. Log in once per account and route git through gh

```bash
gh auth login        # repeat once per account; pick a different account in the browser each time
gh auth setup-git    # makes git ask gh for GitHub logins
gh auth status       # should list EVERY account; exactly one shows "Active account: true"
```

If an account is missing from `gh auth status`, run `gh auth login` again for that account. Logging in adds an account; it doesn't remove the others.

### 4. Install the switcher

Copy `scripts/gh-accounts.sh` to `~/.gh-accounts.sh` and fill in the shortcuts at the bottom with the user's real logins, names and emails:

```bash
git_personal() { gh_use my-personal-login "My Name" me@example.com; }
git_work()     { gh_use my-work-login     "My Name" me@company.com; }
```

Then load it from the shell config:

```bash
echo 'source ~/.gh-accounts.sh' >> ~/.bashrc     # or ~/.zshrc
source ~/.bashrc
```

If the user already has aliases with the same names (a common pattern is `alias git_work='git config --global user.email ... && git config --global user.name ...'`), **delete those alias lines** from the shell config rather than leaving them next to the functions. If an alias with that name exists when the function is defined, bash reports `syntax error near unexpected token '('`: the function is never created and the old alias keeps running. In a shell that's already open, run `unalias git_personal git_work` before re-sourcing. Show the user the lines before you change their shell config.

When testing the shortcuts yourself, don't use `bash -i`/`bash -ic`: that loads the user's real shell config and can actually switch their account. Use `bash --norc --noprofile -c 'source ~/.gh-accounts.sh; gh_who'`, or `gh_who`, which only reads.

For privacy, GitHub's noreply address works as the email: `<id>+<login>@users.noreply.github.com`. It's shown under GitHub → Settings → Emails.

### 5. Verify

```bash
git_work && gh_who
git_personal && gh_who
```

`gh_who` prints who commits will say, which account pushes, every account gh holds, and whether the push guard is on. It also warns if git isn't using gh for logins.

### 6. Recommended: the push guard

The switch is global and easy to forget. If both accounts can access a repo, a push from the wrong one goes through silently. The guard stops that **before anything is sent**:

```bash
bash ~/.claude/skills/gh-account-switcher/scripts/install-guard.sh    # or wherever the skill's scripts/ folder is
```

On every `git push` to an HTTPS GitHub remote, it reads the repo owner from the URL (`github.com/<owner>/...`) and compares it with gh's active account:

- **The owner is one of the user's logged-in accounts** → that account must be active, or the push is blocked with a message naming the account to switch to.
- **The owner is an org or someone else** → it's checked against `~/.config/gh-accounts/owners` if that file lists it; otherwise the push goes ahead with a one-line note (`pushing to <owner> as <login>`).

Add a line per org to the owners file, so work repos are guarded too:

```
# ~/.config/gh-accounts/owners   ("<owner> <gh-login>" per line)
my-company        my-work-login
my-company-labs   my-work-login
```

How it's installed, which matters if something looks off: git 2.34+ (Ubuntu 22.04) has no way to add a global hook alongside per-repo hooks, so the installer sets the global `core.hooksPath` to `~/.config/gh-accounts/hooks`. Every common hook name in that folder points to one script, `gh-accounts-hook`. It runs the push check and then **hands over to the repo's own `.git/hooks/<name>`**, so pre-commit checks and other per-repo hooks keep working. Limits:

- Repos that set their **own** `core.hooksPath` (Husky, some frameworks) use their own folder, and the guard doesn't run there.
- If the user already has a global `core.hooksPath`, the installer stops instead of replacing it. Merge by hand: copy `gh-accounts-hook` into their folder as `pre-push`, and chain any existing `pre-push`.
- SSH remotes aren't checked, since they use SSH keys, not gh.
- Skip it for one push: `GH_ACCOUNTS_GUARD=off git push` (or `git push --no-verify`, which also skips the repo's own pre-push).
- Remove it: `install-guard.sh --remove`.

### 7. Recommended: show the active account in the prompt

```bash
# bash (~/.bashrc, after "source ~/.gh-accounts.sh" and after any PS1 setup)
PS1='$(gh_prompt)'"$PS1"
# zsh (~/.zshrc)
setopt PROMPT_SUBST; PROMPT='$(gh_prompt)'"$PROMPT"
```

The prompt becomes `[my-work-login] user@host:~/repo$`. `gh_prompt` reads a small saved file (`~/.local/state/gh-accounts/active`) instead of asking gh, which takes about 0.4 s, so the prompt stays instant. `gh_use`, `gh_who` and every guarded push update that file. If the user switches with plain `gh auth switch`, the prompt is out of date until the next one of those runs.

## Daily use

```bash
git_work                 # switch BEFORE committing
git add . && git commit -m "..."
git push                 # goes out as the work account
gh_who                   # check any time
```

Points to explain to the user:

- **Switch before committing, not just before pushing.** The author is written into the commit when it's made. If the user commits and then switches, the push uses the new account but the commit still shows the old name. If the commit hasn't been pushed yet, fix it with `git commit --amend --reset-author --no-edit` after switching.
- **The switch is global.** It applies to all repos and all open terminals at once, including any push already running in another window.
- **A repo's own setting wins.** If a repo has `user.name` set locally, that beats the global switch for the commit label. The push account still follows gh. `gh_use` warns about this when run inside such a repo.
- `gh repo create` and other `gh` commands also act as the active account. Check `gh_who` before creating repos.

## Troubleshooting

| Symptom | Cause | Fix |
|---|---|---|
| `unknown shorthand flag: 'u' in -u` | gh is older than 2.40 | Step 2 |
| `gh auth status` lists only one account after upgrading | The old gh's login didn't carry over, or each login replaced the last (old gh) | `gh auth login` for the missing account |
| Commits show the right name but pushes and new repos land on the other account | Only `user.name/email` changed; gh's active account didn't | Use `gh_use`/the shortcuts, which switch both |
| Push uses an unexpected account, or asks for a password | git isn't using gh for logins (a `store`/`libsecret` helper, `~/.git-credentials`, or a username baked into the remote URL) | `gh auth setup-git`; check `git config --show-origin --get-all credential.https://github.com.helper` and `git remote -v` |
| `sudo tee ...: No such file`, or `syntax error near unexpected token 'newline'` while upgrading | A long pasted line wrapped at `>` | Use the short-line commands in step 2 |
| `✘ gh-accounts: this repo belongs to your account X ... Nothing was pushed.` | The push guard saw the wrong active account | Run the shortcut for X and push again. If pushing as the other account is intended: `GH_ACCOUNTS_GUARD=off git push` |
| A repo's own pre-commit/pre-push hook stopped running | Usually a global `core.hooksPath` set by something other than this guard (this guard passes through to `.git/hooks`) | `git config --global --get core.hooksPath`; if it isn't `~/.config/gh-accounts/hooks`, that tool replaced it |
| Prompt shows the wrong account | Switched with plain `gh auth switch`, so the saved state is old | Run `gh_who` (refreshes it), or switch with the shortcuts |
| `syntax error near unexpected token '('` when sourcing `~/.gh-accounts.sh` | An old alias has the same name as a shortcut function | Delete the alias line from the shell config, `unalias <name>`, then `source` again |
| `✘ <login> is not logged in to gh` | Typo in the shortcut, or that account isn't logged in | Compare with `gh auth status`; fix the login name or `gh auth login` |
| SSH remote (`git@github.com:...`) ignores the switch | SSH uses keys from `~/.ssh`, not gh | Use HTTPS remotes (`git remote set-url origin https://github.com/owner/repo.git`) or a separate SSH host alias per account |

## Things to avoid

- Don't print, read or copy tokens (`gh auth token`, `gh auth status -t`, `git credential fill`) to diagnose problems. `gh auth status` and the git config settings show everything needed.
- Don't set up `credential.helper store` to "remember" a second account. It saves the token in plain text in `~/.git-credentials`, and gh's multi-account support makes it unnecessary.
- Don't run `gh auth logout` to switch accounts. That deletes the login; `gh auth switch` (via the shortcuts) is the switch.
