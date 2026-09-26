#!/usr/bin/env bash
# Install the standalone executable without changing shell startup files.
set -euo pipefail

if [[ ${1:-} == --help || $# -gt 1 ]]; then
  echo 'Usage: ./install.sh [bin-directory]'
  echo 'Default: ~/.local/bin. Requires Bash, Herdr, jq, and fzf >= 0.74.0.'
  exit 0
fi

source_dir=$(CDPATH= cd "$(dirname "$0")" && pwd -P)
bin_dir=${1:-"$HOME/.local/bin"}
"$source_dir/bopeep" --check
mkdir -p "$bin_dir"
install -m 755 "$source_dir/bopeep" "$bin_dir/bopeep"
printf 'Installed %s/bopeep\n' "$bin_dir"
case ":$PATH:" in
  *":$bin_dir:"*) echo 'Run bopeep in a terminal to open your dashboard.' ;;
  *) printf 'Add %s to PATH, or run %s/bopeep directly.\n' "$bin_dir" "$bin_dir" ;;
esac
