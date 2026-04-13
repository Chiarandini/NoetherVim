#!/usr/bin/env bash
# NoetherVim installer
# Usage:
#   bash <(curl -fsSL https://raw.githubusercontent.com/Chiarandini/NoetherVim/main/tools/install.sh)
#   bash <(curl -fsSL ...) noethervim   # side-by-side install via NVIM_APPNAME
set -euo pipefail

APPNAME="${1:-nvim}"
CONFIG_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/$APPNAME"
DATA_DIR="${XDG_DATA_HOME:-$HOME/.local/share}/$APPNAME"
STATE_DIR="${XDG_STATE_HOME:-$HOME/.local/state}/$APPNAME"
CACHE_DIR="${XDG_CACHE_HOME:-$HOME/.cache}/$APPNAME"

REPO_URL="https://raw.githubusercontent.com/Chiarandini/NoetherVim/main/init.lua.example"

# ── Backup existing directories ──────────────────────────────────────────────

backup() {
	local dir="$1"
	if [ -d "$dir" ]; then
		local backup="${dir}.bak.$(date +%s)"
		echo "  Backing up $dir -> $backup"
		mv "$dir" "$backup"
	fi
}

if [ -d "$CONFIG_DIR" ] || [ -d "$DATA_DIR" ]; then
	echo "Existing Neovim files detected for NVIM_APPNAME=$APPNAME."
	echo "Backing up:"
	backup "$CONFIG_DIR"
	backup "$DATA_DIR"
	backup "$STATE_DIR"
	backup "$CACHE_DIR"
	echo ""
fi

# ── Install ──────────────────────────────────────────────────────────────────

mkdir -p "$CONFIG_DIR"
echo "Downloading init.lua.example..."
curl -fLo "$CONFIG_DIR/init.lua" "$REPO_URL"

echo ""
echo "NoetherVim installed to $CONFIG_DIR/init.lua"
echo ""

if [ "$APPNAME" = "nvim" ]; then
	echo "Launch with:"
	echo "  nvim"
else
	echo "Launch with:"
	echo "  NVIM_APPNAME=$APPNAME nvim"
	echo ""
	echo "Or add to your shell profile:"
	echo "  alias nv='NVIM_APPNAME=$APPNAME nvim'"
fi

echo ""
echo "On first launch, all plugins will install automatically."
