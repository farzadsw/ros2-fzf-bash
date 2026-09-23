#!/usr/bin/env bash
# ros2-fzf-bash installer.
#
#   curl -fsSL https://raw.githubusercontent.com/farzadsw/ros2-fzf-bash/main/install.sh | bash
#
# Environment:
#   ROS2_FZF_DIR     install location     (default ~/.local/share/ros2-fzf-bash)
#   ROS2_FZF_REPO    git URL to clone     (default the GitHub repo)
#   ROS2_FZF_NO_BAT  set to skip installing bat (optional syntax highlighting)
#   ROS2_FZF_RC      shell rc file to edit (default ~/.bashrc)
# Safe to run again: it updates in place and never duplicates the ~/.bashrc block.
set -euo pipefail

REPO=${ROS2_FZF_REPO:-https://github.com/farzadsw/ros2-fzf-bash.git}
DIR=${ROS2_FZF_DIR:-$HOME/.local/share/ros2-fzf-bash}
RC=${ROS2_FZF_RC:-$HOME/.bashrc}
FZF_MIN=0.38
MARK_BEGIN='# >>> ros2-fzf-bash >>>'
MARK_END='# <<< ros2-fzf-bash <<<'

info() { printf '\033[1;34m==>\033[0m %s\n' "$*"; }
warn() { printf '\033[1;33m==>\033[0m %s\n' "$*" >&2; }
die()  { printf '\033[1;31m==>\033[0m %s\n' "$*" >&2; exit 1; }
have() { command -v "$1" >/dev/null 2>&1; }

# Run as root: directly if we are root, with sudo if available.
as_root() {
    if [ "$(id -u)" -eq 0 ]; then "$@"
    elif have sudo; then sudo "$@"
    else return 1
    fi
}

apt_install() {
    have apt-get || return 1
    as_root env DEBIAN_FRONTEND=noninteractive apt-get install -y -qq "$@" >/dev/null ||
        { as_root apt-get update -qq >/dev/null && as_root env DEBIAN_FRONTEND=noninteractive apt-get install -y -qq "$@" >/dev/null; }
}

# version_ge A B: true when version A >= B
version_ge() { [ "$(printf '%s\n%s\n' "$2" "$1" | sort -V | head -n1)" = "$2" ]; }

fzf_version() { "$1" --version 2>/dev/null | awk '{print $1}'; }

# ---------------------------------------------------------------------------
# 1. git (needed to fetch fzf and this repo)
# ---------------------------------------------------------------------------
if ! have git; then
    info "Installing git"
    apt_install git || die "git is required; please install it and re-run."
fi

# ---------------------------------------------------------------------------
# 2. fzf >= $FZF_MIN
# ---------------------------------------------------------------------------
FZF_FROM_GIT=0
fzf_bin=
if [ -x "$HOME/.fzf/bin/fzf" ]; then fzf_bin=$HOME/.fzf/bin/fzf; FZF_FROM_GIT=1
elif have fzf; then fzf_bin=$(command -v fzf)
fi

if [ -n "$fzf_bin" ] && version_ge "$(fzf_version "$fzf_bin")" "$FZF_MIN"; then
    info "fzf $(fzf_version "$fzf_bin") found at $fzf_bin"
else
    [ -n "$fzf_bin" ] && warn "fzf $(fzf_version "$fzf_bin") is older than $FZF_MIN, installing a newer one"
    info "Installing fzf into ~/.fzf (no sudo needed)"
    if { [ -d "$HOME/.fzf/.git" ] && git -C "$HOME/.fzf" pull -q --ff-only; } ||
       { [ ! -e "$HOME/.fzf" ] && git clone -q --depth 1 https://github.com/junegunn/fzf.git "$HOME/.fzf"; }; then
        "$HOME/.fzf/install" --bin >/dev/null 2>&1
        FZF_FROM_GIT=1
    else
        warn "Could not install fzf from GitHub, trying apt"
        apt_install fzf || die "Could not install fzf. Install it manually: https://github.com/junegunn/fzf"
    fi
fi

# ---------------------------------------------------------------------------
# 3. bat (optional: syntax-highlighted previews)
# ---------------------------------------------------------------------------
if have bat || have batcat; then
    info "bat found (colored previews enabled)"
elif [ -n "${ROS2_FZF_NO_BAT:-}" ]; then
    info "Skipping bat (ROS2_FZF_NO_BAT set); previews will be plain text"
else
    info "Installing bat for colored previews (optional, may ask for your sudo password)"
    apt_install bat || warn "Could not install bat; previews will be plain text. That's fine."
fi

# ---------------------------------------------------------------------------
# 4. ROS 2 check (never installed by this script)
# ---------------------------------------------------------------------------
if have ros2; then
    info "ros2 found${ROS_DISTRO:+ (ROS_DISTRO=$ROS_DISTRO)}"
elif compgen -G '/opt/ros/*/setup.bash' >/dev/null; then
    if ! grep -qs '/opt/ros/.*/setup.bash' "$RC"; then
        warn "ROS 2 is installed but not sourced in $RC. Add e.g.:"
        warn "  source $(ls -d /opt/ros/*/setup.bash | tail -n1)"
    fi
else
    warn "ROS 2 not found. The commands will work once ROS 2 is installed and sourced."
fi

# ---------------------------------------------------------------------------
# 5. Fetch / update ros2-fzf-bash
# ---------------------------------------------------------------------------
if [ -d "$DIR/.git" ]; then
    info "Updating $DIR"
    git -C "$DIR" pull -q --ff-only || warn "Could not update $DIR; keeping the current version"
elif [ -e "$DIR" ]; then
    die "$DIR exists but is not a git checkout; remove it or set ROS2_FZF_DIR"
else
    info "Installing into $DIR"
    mkdir -p "$(dirname "$DIR")"
    git clone -q --depth 1 "$REPO" "$DIR"
fi
[ -f "$DIR/ros2-fzf.bash" ] || die "$DIR/ros2-fzf.bash is missing"

# ---------------------------------------------------------------------------
# 6. Hook into ~/.bashrc (replace any previous block)
# ---------------------------------------------------------------------------
touch "$RC"
if grep -qF "$MARK_BEGIN" "$RC"; then
    tmp=$(mktemp)
    sed "/^$MARK_BEGIN\$/,/^$MARK_END\$/d" "$RC" >"$tmp" && cat "$tmp" >"$RC"
    rm -f "$tmp"
    action=Updated
else
    action=Added
fi
{
    echo "$MARK_BEGIN"
    if [ "$FZF_FROM_GIT" -eq 1 ]; then
        # shellcheck disable=SC2016  # expanded when .bashrc runs
        echo '[[ ":$PATH:" == *":$HOME/.fzf/bin:"* ]] || PATH="$HOME/.fzf/bin:$PATH"'
    fi
    echo "[ -f \"$DIR/ros2-fzf.bash\" ] && source \"$DIR/ros2-fzf.bash\""
    echo "$MARK_END"
} >>"$RC"
info "$action the ros2-fzf-bash block in $RC"

cat <<EOF

  ros2-fzf-bash is installed. Open a new terminal (or run: source $RC)
  and type 'r2help' to list the commands, e.g.:

    rtecho   pick a topic and echo it       rninfo   pick a node and show info
    rthz     pick a topic and measure Hz    rscall   pick a service and call it
    rlaunch  pick a launch file             rbag     pick topics and record a bag

  Uninstall: bash $DIR/uninstall.sh
EOF
