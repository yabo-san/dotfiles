#!/usr/bin/env sh
# bootstrap.sh — Linux/Mac/devcontainer bootstrap for yabo-san/dotfiles
# =============================================================================
# POSIX counterpart to bootstrap.ps1 (Windows). Installs chezmoi and applies
# this repo in one step. Used by DevPod's --dotfiles integration:
#   devpod context set-options -o DOTFILES_URL=https://github.com/yabo-san/dotfiles
# Also works standalone on any fresh Linux/Mac box:
#   sh -c "$(curl -fsLS https://raw.githubusercontent.com/yabo-san/dotfiles/main/bootstrap.sh)"
# Re-runnable. chezmoi's own templates handle the OS branching from here
# (darwin vs linux vs windows) — this script just gets chezmoi itself running.
# =============================================================================
set -eu
sh -c "$(curl -fsLS get.chezmoi.io)" -- init --apply --force yabo-san/dotfiles
