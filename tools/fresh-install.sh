#!/usr/bin/env bash
# Build a throwaway NoetherVim install from scratch, under its own
# NVIM_APPNAME, leaving your real config untouched.
#
# Two things you may want to test, and one flag between them:
#
#   --local   the install loads the distribution from a checkout on disk, so
#             your uncommitted work is what runs. Edits take effect on the
#             next restart with no :Lazy update in between.
#   (none)    the install clones NoetherVim from GitHub, which is exactly
#             what a new user gets. The right test for the bootstrap path.
#
# Both wipe the four XDG directories for the appname first, so every run
# starts from nothing. tools/install.sh cannot serve here: it backs existing
# directories up rather than removing them, so repeated runs pile up
# .bak.<timestamp> copies of state that was meant to be discarded.
#
# Usage:
#   tools/fresh-install.sh                    # NVIM_APPNAME=tmpnvim, clone of main
#   tools/fresh-install.sh --local            # ... loading this checkout instead
#   tools/fresh-install.sh --local ~/src/NoetherVim
#   tools/fresh-install.sh scratch            # ... under a different appname
#   tools/fresh-install.sh --keep-state       # keep shada, undo history, sessions
#   tools/fresh-install.sh nvim --force       # required to touch the real config
set -euo pipefail

repo="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
template="$repo/init.lua.example"

appname=""
dev_path=""
keep_state=0
force=0

while [ $# -gt 0 ]; do
	case "$1" in
		--local|--dev)
			# Optional argument: bare --local means this checkout.
			if [ $# -ge 2 ] && [ "${2#-}" = "$2" ] && [ -d "$2" ]; then
				dev_path="$(cd "$2" && pwd)"
				shift
			else
				dev_path="$repo"
			fi
			;;
		--keep-state) keep_state=1 ;;
		--force)      force=1 ;;
		-h|--help)    sed -n '2,25p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//'; exit 0 ;;
		-*)           echo "unknown flag: $1" >&2; exit 2 ;;
		*)
			if [ -n "$appname" ]; then
				echo "appname given twice: $appname, $1" >&2
				exit 2
			fi
			appname="$1"
			;;
	esac
	shift
done

appname="${appname:-tmpnvim}"

# The whole point of this script is deletion without confirmation, which is
# fine for a scratch appname and not fine for the config someone actually
# uses. `nvim` is the only name that is somebody's real editor by default.
if [ "$appname" = "nvim" ] && [ "$force" -ne 1 ]; then
	cat >&2 <<-EOF
		Refusing to wipe NVIM_APPNAME=nvim, which is the default config.
		Pass --force if that is genuinely what you want, or name a scratch
		config instead:

		  tools/fresh-install.sh tmpnvim
	EOF
	exit 1
fi

config_dir="${XDG_CONFIG_HOME:-$HOME/.config}/$appname"
data_dir="${XDG_DATA_HOME:-$HOME/.local/share}/$appname"
state_dir="${XDG_STATE_HOME:-$HOME/.local/state}/$appname"
cache_dir="${XDG_CACHE_HOME:-$HOME/.cache}/$appname"

[ -f "$template" ] || { echo "missing template: $template" >&2; exit 1; }

targets=("$config_dir" "$data_dir" "$cache_dir")
if [ "$keep_state" -eq 1 ]; then
	echo "Keeping $state_dir (shada, undo history, sessions)."
else
	targets+=("$state_dir")
fi

echo "Wiping NVIM_APPNAME=$appname:"
for dir in "${targets[@]}"; do
	if [ -d "$dir" ]; then
		echo "  rm -rf $dir"
		rm -rf "$dir"
	else
		echo "  (absent) $dir"
	fi
done

mkdir -p "$config_dir"

if [ -z "$dev_path" ]; then
	cp "$template" "$config_dir/init.lua"
	echo "Wrote $config_dir/init.lua (clones NoetherVim from GitHub on first launch)."
else
	# Two edits, both anchored on lines that have been stable since the
	# template existed. Anchors are verified before rewriting so a template
	# reshuffle fails here rather than producing a config that silently
	# tests the GitHub clone instead of the local checkout.
	for anchor in 'local noethervimpath = ' '"Chiarandini/NoetherVim",'; do
		grep -qF "$anchor" "$template" || {
			echo "init.lua.example no longer contains: $anchor" >&2
			echo "tools/fresh-install.sh needs updating." >&2
			exit 1
		}
	done

	awk -v dev="$dev_path" '
		# Point the runtimepath prepend at the working tree. The clone block
		# below it is then skipped, because the directory already exists.
		/^local noethervimpath = / {
			print "local noethervimpath = \"" dev "\""
			next
		}
		# Give the lazy spec an explicit dir so lazy.nvim manages the local
		# checkout in place instead of cloning its own copy.
		/"Chiarandini\/NoetherVim",/ {
			print
			match($0, /^[ \t]*/)
			print substr($0, 1, RLENGTH) "dir = \"" dev "\","
			next
		}
		{ print }
	' "$template" > "$config_dir/init.lua"

	echo "Wrote $config_dir/init.lua (loads NoetherVim from $dev_path)."
fi

echo
echo "Launch with:"
echo "  NVIM_APPNAME=$appname nvim"
echo
echo "Worth an alias if you do this often:"
echo "  alias $appname='NVIM_APPNAME=$appname nvim'"
echo
echo "Plugins install on first launch."
