# dotfiles
My personal dotfiles, managed with [`chezmoi`](https://github.com/twpayne/chezmoi).

## Installation

### Install Dotfiles

```sh
sh -c "$(curl -fsLS get.chezmoi.io)" -- init --apply git@github.com:SystemFiles/dotfiles.git
```

### Install Software (MacOS)

After dotfiles installation (which includes a `~/.Brewfile`), we can install software.

```sh
brew bundle --global
```

## Troubleshooting

### Switch Existing Install from HTTPS to SSH

If you've already initialized chezmoi with HTTPS and want to switch to SSH:

```sh
cd ~/.local/share/chezmoi
git remote set-url origin git@github.com:SystemFiles/dotfiles.git
```
