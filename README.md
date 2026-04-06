# dotfiles
My personal dotfiles, managed with [`chezmoi`](https://github.com/twpayne/chezmoi).

## Installation

### Pre-Installation Steps

There are a few things (mostly software installs) that cannot easily be captured as part of this project.

For general software, use the [`software-tasks`](https://github.com/SystemFiles/software) project

```bash
bash <(curl -sSLf https://raw.githubusercontent.com/SystemFiles/software/master/install)
```

```bash
task basics:install
```

### Install Dotfiles

#### Using HTTPS (no SSH key required)

```sh
sh -c "$(curl -fsLS get.chezmoi.io)" -- init --apply SystemFiles
```

#### Using SSH (requires SSH key configured with GitHub)

```sh
sh -c "$(curl -fsLS get.chezmoi.io)" -- init --apply git@github.com:SystemFiles/dotfiles.git
```

### Switch Existing Install from HTTPS to SSH

If you've already initialized chezmoi with HTTPS and want to switch to SSH:

```sh
cd ~/.local/share/chezmoi
git remote set-url origin git@github.com:SystemFiles/dotfiles.git
```

## Install location

```sh
~/.local/share/chezmoi
```
