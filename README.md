# gh-account-switcher

Switch between your GitHub accounts (for example **personal** and **work**) on one machine with a single command. Each switch changes both:

- **who your commits say**: `git user.name` / `user.email`
- **which account pushes**: gh's active account, which git uses through `gh auth git-credential`

```
$ git_work
✔ Now committing as "Your Name" <you@company.com> and pushing as your-work-login.
```

The usual way to switch is to change `user.name`/`user.email`, but that only changes the label on commits. Pushes and `gh repo create` still go to whichever account `gh` has active. This fixes that.

It's a [Claude](https://claude.ai) skill, so Claude can set it up and troubleshoot it for you, but the scripts work fine on their own.

> **For one person with several accounts.** If several *people* share one Linux login (a lab PC, a shared server), use separate Linux users, or a per-repo switcher that asks each person for their own token, instead. See *Pick the right skill first* in [SKILL.md](SKILL.md).

## Requirements

- **gh 2.40 or newer**, with each account logged in once (`gh auth login`). Ubuntu 22.04's apt package is gh 2.4, which only holds one account; [SKILL.md](SKILL.md#2-upgrade-gh-if-needed) has the upgrade steps.
- bash or zsh on Linux or macOS. It was tested on Ubuntu 22.04 in bash and zsh; macOS should work but is untested.

## Install as a Claude Code skill

```bash
git clone https://github.com/RoKenobi/gh-account-switcher.git ~/.claude/skills/gh-account-switcher
```

Then ask Claude something like *"set up switching between my personal and work GitHub accounts"*.

## Use without Claude

```bash
gh auth login                # once per account
gh auth setup-git            # git asks gh for GitHub logins

cp scripts/gh-accounts.sh ~/.gh-accounts.sh
cat >> ~/.bashrc <<'EOF'
source ~/.gh-accounts.sh
git_personal() { gh_use your-personal-login "Your Name" you@example.com; }
git_work()     { gh_use your-work-login     "Your Name" you@company.com; }
EOF
source ~/.bashrc
```

If you already have `git_personal`/`git_work` **aliases**, delete those lines first; bash can't define a function with the same name as an existing alias.

| Command | What it does |
|---|---|
| `git_personal` / `git_work` | Switch commit identity and push account together |
| `gh_who` | Show who you'll commit as, which account pushes, and all logged-in accounts |
| `gh_use <login> "<Name>" <email>` | The function the shortcuts call |

**Switch before you commit:** the author is recorded when the commit is made, not when it's pushed.

## Optional extras

- **Push guard** (`scripts/install-guard.sh`): blocks a `git push` when the active account doesn't match the repo's owner, while keeping each repo's own hooks working. Off unless you install it.
- **Prompt indicator** (`gh_prompt`): puts `[login]` at the start of your shell prompt.

Details, caveats and a troubleshooting table are in [SKILL.md](SKILL.md).
