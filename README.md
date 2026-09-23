# ros2-fzf-bash

Fuzzy-find your way around ROS 2 from **bash**. Pick topics, nodes, services, actions, parameters, interfaces, packages and launch files with [fzf](https://github.com/junegunn/fzf), with live previews, and every command you run is saved to your shell history.

This is the bash sibling of [oh-my-zsh-ros2-plugin](https://github.com/farzadsw/oh-my-zsh-ros2-plugin).

## Install

```bash
curl -fsSL https://raw.githubusercontent.com/farzadsw/ros2-fzf-bash/main/install.sh | bash
```

Then open a new terminal and run `r2help`.

The installer is safe to run again (that's also how you update). It:

| Step | Details |
|---|---|
| **fzf** | Uses your fzf if it's ≥ 0.38; otherwise installs the latest into `~/.fzf` (no sudo), falling back to `apt`. |
| **bat** *(optional)* | Installs `bat` via `apt` for syntax-colored previews. Not required: without it previews are plain text. Skip with `ROS2_FZF_NO_BAT=1`. |
| **ROS 2** | Checks that it's installed and sourced. It does **not** install ROS 2. |
| **Files** | Clones this repo to `~/.local/share/ros2-fzf-bash` (override with `ROS2_FZF_DIR`). |
| **~/.bashrc** | Adds one marked `# >>> ros2-fzf-bash >>>` block that sources the functions. |

Dependencies: `bash`, `git`, `curl`, `fzf` ≥ 0.38, a sourced ROS 2 install (tested on Jazzy, Ubuntu 24.04), and optionally `bat`.

**Uninstall:** `bash ~/.local/share/ros2-fzf-bash/uninstall.sh`

**Manual install:** clone anywhere and add `source /path/to/ros2-fzf.bash` to `~/.bashrc` after your ROS 2 `setup.bash`.

## Commands

Run any command without arguments to open the picker. Pass a name to skip it (`rtecho /tf`); extra arguments are passed through (`rtecho --once`, `rbag -o mybag`).

| Area | Command | What it does | Preview |
|---|---|---|---|
| Topics | `rtlist` | Browse topics (Tab: multi-select), print names | `topic info -v` |
| | `rtecho` | `ros2 topic echo` | a live sample message |
| | `rthz` / `rtbw` / `rtdelay` | `ros2 topic hz` / `bw` / `delay` | `topic info -v` |
| | `rtinfo` | `ros2 topic info -v` | `topic info -v` |
| | `rtpub` | Prefills `ros2 topic pub --once <topic> <type> "<msg template>"` for editing | message prototype |
| Nodes | `rnlist`, `rninfo` | Browse nodes / `ros2 node info` | `node info` |
| Services | `rslist`, `rscall` | Browse / prefill `ros2 service call` with the request template | service definition |
| Actions | `ralist`, `rasend` | Browse / prefill `ros2 action send_goal --feedback` with the goal template | action definition |
| Params | `rplist` | Pick a node, list its parameters | |
| | `rpget` | Pick node → parameter, get its value | value + description |
| | `rpset` | Pick node → parameter, prefill `ros2 param set` with the current value | value + description |
| Interfaces | `rishow` | `ros2 interface show` for any msg/srv/action | definition |
| Packages | `rpkg` | `cd` into a package's share directory | `package.xml` |
| | `rrun` | Pick `package executable`, `ros2 run` it | package description |
| | `rlaunch` | Pick a launch file from any package, `ros2 launch` it | the launch file |
| Bags | `rbag` | Pick topics (Tab: multi-select), `ros2 bag record` them | `topic info -v` |
| Help | `r2help` | List all commands | |

`rtpub`, `rscall`, `rasend` and `rpset` don't run blindly: they put the full command on an editable line (readline) so you can fill in values first, and press Enter to run it.

Tab completion: `rtecho <Tab>` completes topic names and `rninfo <Tab>` completes node names.

## Settings

Set these in `~/.bashrc` before the ros2-fzf-bash block:

| Variable | Default | Meaning |
|---|---|---|
| `ROS2_FZF_OPTS` | *(empty)* | Extra fzf options, e.g. `--height=90%` |
| `ROS2_FZF_PREVIEW_TIMEOUT` | `3` | Seconds before a preview command is stopped |
| `ROS2_FZF_NO_BAT` | *(unset)* | Set to disable bat colors in previews |
