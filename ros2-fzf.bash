# ros2-fzf-bash: fzf-powered helpers for the ROS 2 CLI.
# https://github.com/farzadsw/ros2-fzf-bash
#
# Source this file from ~/.bashrc (install.sh does it for you).
# Run `r2help` for the list of commands.

# Only for interactive bash shells.
[[ $- == *i* ]] || return 0
[ -n "${BASH_VERSION:-}" ] || return 0

# ---------------------------------------------------------------------------
# Settings
# ---------------------------------------------------------------------------

# Seconds a preview command may run before it is killed.
: "${ROS2_FZF_PREVIEW_TIMEOUT:=3}"
# Extra options passed to every fzf call, e.g. ROS2_FZF_OPTS='--height=80%'.
: "${ROS2_FZF_OPTS:=}"

# Syntax highlighter for previews: bat (Debian/Ubuntu ship it as batcat).
# Falls back to plain cat when bat is missing or ROS2_FZF_NO_BAT is set.
_r2f_hl() {
    local lang=${1:-yaml} bat=
    if [ -z "${ROS2_FZF_NO_BAT:-}" ]; then
        if command -v bat >/dev/null 2>&1; then bat=bat
        elif command -v batcat >/dev/null 2>&1; then bat=batcat
        fi
    fi
    if [ -n "$bat" ]; then
        printf '%s --color=always --style=plain --paging=never -l %s' "$bat" "$lang"
    else
        printf 'cat'
    fi
}

# ---------------------------------------------------------------------------
# Core helpers
# ---------------------------------------------------------------------------

_r2f_check() {
    local missing=
    command -v fzf >/dev/null 2>&1 || missing+=" fzf"
    command -v ros2 >/dev/null 2>&1 || missing+=" ros2"
    if [ -n "$missing" ]; then
        echo "ros2-fzf: missing:$missing" >&2
        [[ $missing == *ros2* ]] && echo "ros2-fzf: source your ROS 2 setup, e.g. 'source /opt/ros/<distro>/setup.bash'" >&2
        [[ $missing == *fzf* ]] && echo "ros2-fzf: re-run install.sh or install fzf (https://github.com/junegunn/fzf)" >&2
        return 1
    fi
}

# Build a preview command that cannot hang and is highlighted.
# _r2f_preview <shell command using fzf placeholders> [bat language]
_r2f_preview() {
    printf 'timeout %s %s 2>&1 | %s' "$ROS2_FZF_PREVIEW_TIMEOUT" "$1" "$(_r2f_hl "${2:-yaml}")"
}

# Fuzzy-pick from stdin.
# _r2f_pick <prompt> <preview command> [extra fzf options...]
_r2f_pick() {
    local prompt=$1 preview=$2
    shift 2
    # shellcheck disable=SC2086  # ROS2_FZF_OPTS is intentionally word-split
    SHELL=bash fzf --height=60% --reverse --border=rounded \
        --prompt="$prompt > " \
        --preview="$preview" --preview-window='right,60%,wrap' \
        $ROS2_FZF_OPTS "$@"
}

# Print, record in history, and run a command.
_r2f_run() {
    local cmd
    cmd=$(printf '%q ' "$@")
    cmd=${cmd% }
    history -s "$cmd"
    printf '\033[2mRunning: %s\033[0m\n' "$cmd" >&2
    "$@"
}

# Let the user edit a prefilled command line, then record and run it.
_r2f_edit_run() {
    local line
    printf '\033[2mEdit the command, then press Enter (Ctrl-C to cancel):\033[0m\n' >&2
    IFS= read -r -e -i "$1" -p '$ ' line || return 130
    [ -n "$line" ] || return 0
    history -s "$line"
    eval "$line"
}

# Single-line YAML prototype of an interface, ready to paste into a command.
_r2f_proto() {
    ros2 interface proto --no-quotes "$1" 2>/dev/null | python3 -c '
import sys, yaml
d = yaml.safe_load(sys.stdin.read())
print("{}" if d is None else yaml.safe_dump(d, default_flow_style=True, width=1 << 30).strip())
' 2>/dev/null || echo '{}'
}

# Pick a ROS entity. Prints the selected "name [type]" line(s).
# _r2f_select <topic|node|service|action> <prompt> [preview] [extra fzf options...]
_r2f_select() {
    local kind=$1 prompt=$2 preview=${3:-}
    shift 3 2>/dev/null || shift $#
    _r2f_check || return 1
    local list_opt=-t
    [ "$kind" = node ] && list_opt=
    if [ -z "$preview" ]; then
        case $kind in
            topic)  preview=$(_r2f_preview 'ros2 topic info -v {1}') ;;
            node)   preview=$(_r2f_preview 'ros2 node info {1}') ;;
            service|action)
                    preview=$(_r2f_preview 'ros2 interface show $(echo {2} | tr -d "[]")') ;;
        esac
    fi
    # shellcheck disable=SC2086
    ros2 "$kind" list $list_opt | _r2f_pick "$prompt" "$preview" "$@"
}

_r2f_name() { printf '%s\n' "${1%% *}"; }
_r2f_type() { local t=${1#*[}; printf '%s\n' "${t%]*}"; }

# Generic "pick an entity, then run `ros2 <kind> <verb> <name> [args]`".
# A first argument that does not start with '-' is used as the name (no fzf).
_r2f_do() {
    local kind=$1 verb=$2 preview=${3:-}
    shift 3
    local name sel
    if [ $# -gt 0 ] && [[ $1 != -* ]]; then
        name=$1
        shift
    else
        sel=$(_r2f_select "$kind" "$kind $verb" "$preview") || return
        name=$(_r2f_name "$sel")
    fi
    [ -n "$name" ] || return 1
    _r2f_run ros2 "$kind" "$verb" "$name" "$@"
}

# ---------------------------------------------------------------------------
# Topics
# ---------------------------------------------------------------------------

rtlist()  { local s; s=$(_r2f_select topic 'topics' '' --multi) && awk '{print $1}' <<<"$s"; }
rtecho()  { _r2f_do topic echo "$(_r2f_preview 'ros2 topic echo --once {1}')" "$@"; }
rthz()    { _r2f_do topic hz '' "$@"; }
rtbw()    { _r2f_do topic bw '' "$@"; }
rtdelay() { _r2f_do topic delay '' "$@"; }
rtinfo()  { _r2f_do topic info '' "$@" -v; }

# Publish: pick a topic, then edit a prefilled `ros2 topic pub` command.
rtpub() {
    local sel name type
    sel=$(_r2f_select topic 'topic pub' "$(_r2f_preview 'ros2 interface proto $(echo {2} | tr -d "[]")')") || return
    name=$(_r2f_name "$sel")
    type=$(_r2f_type "$sel")
    _r2f_edit_run "ros2 topic pub --once $name $type \"$(_r2f_proto "$type")\""
}

# ---------------------------------------------------------------------------
# Nodes
# ---------------------------------------------------------------------------

rnlist() { local s; s=$(_r2f_select node 'nodes' '' --multi) && printf '%s\n' "$s"; }
rninfo() { _r2f_do node info '' "$@"; }

# ---------------------------------------------------------------------------
# Services
# ---------------------------------------------------------------------------

rslist() { local s; s=$(_r2f_select service 'services' '' --multi) && awk '{print $1}' <<<"$s"; }

rscall() {
    local sel name type
    sel=$(_r2f_select service 'service call') || return
    name=$(_r2f_name "$sel")
    type=$(_r2f_type "$sel")
    _r2f_edit_run "ros2 service call $name $type \"$(_r2f_proto "$type")\""
}

# ---------------------------------------------------------------------------
# Actions
# ---------------------------------------------------------------------------

ralist() { local s; s=$(_r2f_select action 'actions' '' --multi) && awk '{print $1}' <<<"$s"; }

rasend() {
    local sel name type
    sel=$(_r2f_select action 'action send_goal') || return
    name=$(_r2f_name "$sel")
    type=$(_r2f_type "$sel")
    _r2f_edit_run "ros2 action send_goal --feedback $name $type \"$(_r2f_proto "$type")\""
}

# ---------------------------------------------------------------------------
# Parameters
# ---------------------------------------------------------------------------

# _r2f_param_pick [node] -> prints "node<TAB>param"
_r2f_param_pick() {
    local node=${1:-} param qnode
    if [ -z "$node" ]; then
        node=$(_r2f_select node 'param node') || return
    fi
    _r2f_check || return 1
    qnode=$(printf '%q' "$node")
    param=$(ros2 param list "$node" | awk 'NF {print $1}' |
        _r2f_pick "param ($node)" \
            "$(_r2f_preview "ros2 param get $qnode {1}"); echo; $(_r2f_preview "ros2 param describe $qnode {1}")") || return
    printf '%s\t%s\n' "$node" "$param"
}

# rplist [node]: browse the parameters of a node.
rplist() {
    local node=${1:-}
    [ -n "$node" ] || { node=$(_r2f_select node 'param node') || return; }
    _r2f_run ros2 param list "$node"
}

# rpget [node [param]]
rpget() {
    if [ $# -ge 2 ]; then _r2f_run ros2 param get "$1" "$2"; return; fi
    local sel
    sel=$(_r2f_param_pick "${1:-}") || return
    _r2f_run ros2 param get "${sel%%$'\t'*}" "${sel#*$'\t'}"
}

# rpset [node [param [value]]]
rpset() {
    if [ $# -ge 3 ]; then _r2f_run ros2 param set "$@"; return; fi
    local sel node param value
    if [ $# -eq 2 ]; then
        node=$1 param=$2
    else
        sel=$(_r2f_param_pick "${1:-}") || return
        node=${sel%%$'\t'*} param=${sel#*$'\t'}
    fi
    # Prefill with the current value ("Integer value is: 5" -> "5").
    value=$(ros2 param get "$node" "$param" 2>/dev/null | sed -n '1s/^[^:]*: //p')
    _r2f_edit_run "ros2 param set $node $param $value"
}

# ---------------------------------------------------------------------------
# Interfaces
# ---------------------------------------------------------------------------

rishow() {
    local name=${1:-}
    if [ -z "$name" ]; then
        _r2f_check || return 1
        name=$(ros2 interface list | awk '/^ /{print $1}' |
            _r2f_pick 'interface' "$(_r2f_preview 'ros2 interface show {1}')") || return
    fi
    _r2f_run ros2 interface show "$name"
}

# ---------------------------------------------------------------------------
# Packages, run, launch
# ---------------------------------------------------------------------------

# Every "<prefix>/share/<pkg>/package.xml" on AMENT_PREFIX_PATH, as "pkg<TAB>dir".
_r2f_pkg_dirs() {
    local IFS=: prefix f
    for prefix in $AMENT_PREFIX_PATH; do
        for f in "$prefix"/share/*/package.xml; do
            [ -e "$f" ] || continue
            f=${f%/package.xml}
            printf '%s\t%s\n' "${f##*/}" "$f"
        done
    done | sort -u -t$'\t' -k1,1
}

# rpkg [pkg]: cd into a package's share directory.
rpkg() {
    _r2f_check || return 1
    local dir
    if [ -n "${1:-}" ]; then
        dir=$(ros2 pkg prefix --share "$1") || return
    else
        dir=$(_r2f_pkg_dirs | _r2f_pick 'package' \
            "$(_r2f_hl xml) {2}/package.xml" --delimiter=$'\t' --with-nth=1) || return
        dir=${dir#*$'\t'}
    fi
    _r2f_run cd "$dir"
}

# rrun [pkg exe] [args...]
rrun() {
    if [ $# -ge 2 ] && [[ $1 != -* ]]; then _r2f_run ros2 run "$@"; return; fi
    _r2f_check || return 1
    local sel
    sel=$(ros2 pkg executables | _r2f_pick 'run' \
        "$(_r2f_preview 'ros2 pkg xml -t description {1}')") || return
    _r2f_run ros2 run "${sel%% *}" "${sel#* }" "$@"
}

# rlaunch [pkg file] [args...]
rlaunch() {
    if [ $# -ge 2 ] && [[ $1 != -* ]] && [[ $2 != *:=* ]]; then _r2f_run ros2 launch "$@"; return; fi
    _r2f_check || return 1
    local sel pkg file
    sel=$(_r2f_pkg_dirs | while IFS=$'\t' read -r pkg dir; do
            [ -d "$dir/launch" ] || continue
            find -L "$dir/launch" -maxdepth 2 -type f -name '*launch*' \
                \( -name '*.py' -o -name '*.xml' -o -name '*.yaml' -o -name '*.yml' \) \
                -printf "$pkg %f\t%p\n" 2>/dev/null
        done | _r2f_pick 'launch' "$(_r2f_hl python) {2}" \
            --delimiter=$'\t' --with-nth=1) || return
    sel=${sel%%$'\t'*}
    pkg=${sel%% *} file=${sel#* }
    _r2f_run ros2 launch "$pkg" "$file" "$@"
}

# ---------------------------------------------------------------------------
# Bags
# ---------------------------------------------------------------------------

# rbag [record options...]: pick topics (Tab to multi-select) and record them.
rbag() {
    local sel topics
    sel=$(_r2f_select topic 'bag record (Tab: multi-select)' '' --multi) || return
    mapfile -t topics < <(awk '{print $1}' <<<"$sel")
    [ ${#topics[@]} -gt 0 ] || return 1
    _r2f_run ros2 bag record "$@" "${topics[@]}"
}

# ---------------------------------------------------------------------------
# Help & completion
# ---------------------------------------------------------------------------

r2help() {
    cat <<'EOF'
ros2-fzf-bash commands (run without arguments to pick with fzf)

 Topics      rtlist  rtecho  rthz  rtbw  rtdelay  rtinfo  rtpub
 Nodes       rnlist  rninfo
 Services    rslist  rscall
 Actions     ralist  rasend
 Params      rplist  rpget  rpset
 Interfaces  rishow
 Packages    rpkg (cd)  rrun  rlaunch
 Bags        rbag (Tab to select multiple topics)

 Pass a name to skip the picker, e.g. `rtecho /tf`; extra args are
 passed through, e.g. `rtecho --once`, `rbag -o mybag`.
 Settings: ROS2_FZF_OPTS, ROS2_FZF_PREVIEW_TIMEOUT, ROS2_FZF_NO_BAT
EOF
}

_r2f_complete() {
    local kind=$1 cur=${COMP_WORDS[COMP_CWORD]}
    [ "$COMP_CWORD" -eq 1 ] || return 0
    command -v ros2 >/dev/null 2>&1 || return 0
    mapfile -t COMPREPLY < <(compgen -W "$(ros2 "$kind" list 2>/dev/null)" -- "$cur")
}
_r2f_complete_topic()   { _r2f_complete topic; }
_r2f_complete_node()    { _r2f_complete node; }
complete -F _r2f_complete_topic rtecho rthz rtbw rtdelay rtinfo
complete -F _r2f_complete_node rninfo rplist rpget rpset
