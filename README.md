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

### 5. Reload your shell
```bash
source ~/.zshrc
```

## Daily Usage

Once set up, use the `config` command just like `git`:

### Check status
```bash
config status
```

### Add new config files
```bash
config add ~/.vimrc
config add ~/.config/starship.toml
```

### Commit and push changes
```bash
config commit -m "Update zsh config"
config push
```

### Pull updates
```bash
config pull
```

## Currently Tracked Files

- `~/.zshrc` - Zsh shell configuration
- `~/.config/git/ignore` - Global git ignore patterns
- `~/.config/zed/settings.json` - Zed editor settings

## Adding More Files

To track additional config files:
```bash
config add <path-to-file>
config commit -m "Add <description>"
config push
```

## Notes

- The `.dotfiles` directory contains the git metadata (bare repo)
- Your actual config files stay in their normal locations
- Only explicitly added files are tracked
- No `.gitignore` needed - untracked files are hidden by default
