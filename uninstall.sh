#!/usr/bin/env bash
# Remove ros2-fzf-bash: the ~/.bashrc block and the install directory.
# fzf and bat are left installed (other tools may use them).
set -euo pipefail

DIR=${ROS2_FZF_DIR:-$HOME/.local/share/ros2-fzf-bash}
RC=${ROS2_FZF_RC:-$HOME/.bashrc}
MARK_BEGIN='# >>> ros2-fzf-bash >>>'
MARK_END='# <<< ros2-fzf-bash <<<'

if [ -f "$RC" ] && grep -qF "$MARK_BEGIN" "$RC"; then
    tmp=$(mktemp)
    sed "/^$MARK_BEGIN\$/,/^$MARK_END\$/d" "$RC" >"$tmp" && cat "$tmp" >"$RC"
    rm -f "$tmp"
    echo "Removed the ros2-fzf-bash block from $RC"
fi

if [ -d "$DIR" ]; then
    rm -rf "$DIR"
    echo "Removed $DIR"
fi

echo "Done. Open a new terminal to finish. (fzf in ~/.fzf and bat were left installed.)"
