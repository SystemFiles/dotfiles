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

```sh
sh -c "$(curl -fsLS get.chezmoi.io)" -- init --apply SystemFiles
```

## Install location

```sh
~/.local/share/chezmoi
```
