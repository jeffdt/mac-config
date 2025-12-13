# Mac Config

My dotfiles managed using a bare git repository. This approach allows tracking config files in their natural locations without cluttering the home directory with a full git repo.

## Setup on a New Machine

### 1. Clone the bare repository
```bash
git clone --bare git@github.com:jeffdt/mac-config.git $HOME/.dotfiles
```

### 2. Create the config alias
Add this to your shell config (temporarily or permanently):
```bash
alias config='/usr/bin/git --git-dir=$HOME/.dotfiles/ --work-tree=$HOME'
```

### 3. Checkout the config files
```bash
config checkout
```

If you get errors about existing files, back them up or remove them first:
```bash
mkdir -p ~/.config-backup
config checkout 2>&1 | grep -E "\s+\." | awk {'print $1'} | xargs -I{} mv {} ~/.config-backup/{}
config checkout
```

### 4. Hide untracked files
```bash
config config --local status.showUntrackedFiles no
```

### 5. Set up shell config
Add this line to your `~/.zshrc`:
```bash
source ~/shell/common.zsh
```

Optionally create `~/shell/local.zsh` for machine-specific config (it's auto-sourced if it exists).

### 6. Reload your shell
```bash
source ~/.zshrc
```

## Shell Config Structure

```
~/shell/
├── common.zsh          # Entry point (tracked)
├── common/             # Portable configs (tracked)
│   ├── aliases.zsh     # Git, brew, venv, editor aliases
│   ├── functions.zsh   # b64, kdo, git helpers
│   └── fzf.zsh         # fzf setup
├── local.zsh           # Machine-specific entry (NOT tracked)
└── local/              # Machine-specific files (NOT tracked)
```

- **common.zsh** and **common/** are tracked and portable across machines
- **local.zsh** and **local/** are NOT tracked - create them for machine-specific config
- `common.zsh` auto-sources `local.zsh` if it exists

## Daily Usage

Once set up, use the `config` command just like `git`:

```bash
config status              # Check status
config add <file>          # Track a new file
config commit -m "msg"     # Commit changes
config push                # Push to GitHub
config pull                # Pull updates
```

## Currently Tracked Files

- `~/shell/common.zsh` - Shell config entry point
- `~/shell/common/*` - Portable shell aliases, functions, fzf config
- `~/.config/git/ignore` - Global git ignore patterns
- `~/.config/zed/settings.json` - Zed editor settings
- `~/README.md` - This file

## Notes

- The `.dotfiles` directory contains the git metadata (bare repo)
- Your actual config files stay in their normal locations
- Only explicitly added files are tracked
- No `.gitignore` needed - untracked files are hidden by default
- `.zshrc` is NOT tracked (each machine has its own)
