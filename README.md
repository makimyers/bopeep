# Bopeep

Little Bo-Peep has lost her sheep. This helps you find them.

Bopeep is a live terminal dashboard for [Herdr](https://herdr.dev). It shows which agents need attention, lets you read their terminal output, and lets you reply without hunting through tabs.

```text
🐑 3 in the flock   ● 1 blocked   ◐ 1 working   ○ 1 idle

▶ ● blocked  codex    storefront    Waiting for approval
  ◐ working  claude   api           Adding password reset
  ○ idle     opencode docs          Ready for the next task

reply ▸ type a reply for the highlighted agent
```

The real dashboard shows the selected agent's terminal beside the list. In a narrow terminal, the preview moves below it.

## Why this exists?

Running multiple coding agents means context-switching through tabs to figure out which one is stuck, which one finished, and which one needs an answer. Bopeep gives you:

- **Blocked agents first**, then done, working, unknown, and idle
- **A live preview** of the selected agent's terminal before you reply
- **A list that refreshes every two seconds** but holds your selection steady; while you type a message it pauses refreshing the list so nothing jumps around, but the preview keeps updating
- **No build step or background service.** One Bash executable plus Herdr, fzf, and jq

## Install

### Requirements

| Requirement | Version | Where to get it |
| --- | --- | --- |
| Bash | 3.2+ | Comes with macOS and most Linux distros |
| Herdr | Tested with 0.9.1 | [Herdr install docs](https://herdr.dev/docs/install/) |
| fzf | **0.74.0 or newer** | [fzf install page](https://junegunn.github.io/fzf/installation/) |
| jq | 1.6+ | [jq download](https://jqlang.org/download/) |

The fzf version matters because Bopeep uses timer events and the `wait` action to keep your selection from jumping around when the list refreshes. That requires [fzf 0.74.0](https://junegunn.github.io/fzf/releases/0.74.0/). If your distro ships an older fzf, check with `fzf --version`.

With Homebrew:

```sh
brew install herdr fzf jq
```

Otherwise grab jq from your package manager and follow the Herdr and fzf links above.

### Install Bopeep

```sh
git clone https://github.com/makimyers/bopeep.git
cd bopeep
bash install.sh
```

Prefer a ZIP? Hit **Code → Download ZIP** on GitHub, extract it, cd into the folder containing `install.sh`, and run:

```sh
bash install.sh
```

The installer checks your dependencies and copies `bopeep` to `~/.local/bin`. It does not use sudo, download anything extra, or touch your shell config.

If you get "command not found" later, make sure `~/.local/bin` is on your PATH:

```sh
export PATH="$HOME/.local/bin:$PATH"
```

Add that to your `.bashrc` / `.zshrc` if you want it permanent. Alternatively just run `~/.local/bin/bopeep`.

Want a different install location? Pass one as an argument:

```sh
bash install.sh /path/to/somewhere-else
```

## First run

1. Start `herdr`, launch your coding agents in its tabs or panes
2. Open another Herdr tab (or just a regular terminal) for the dashboard
3. Run `bopeep`

You can also try it from this repo without installing: `./bopeep`.

## Controls

**Typing sends a message to the selected agent. It does not search.** Pick your target first, check its preview, then hit Enter.

| Key | What happens |
| --- | --- |
| Up / Down arrows | Select an agent |
| Type a message + Enter | Send that message to the selected agent |
| Enter with nothing typed | Jump into the agent's Herdr pane; attach from another terminal |
| Type key names + Ctrl+K | Send raw keys, e.g. `1 enter`, `esc`, `ctrl+c` |
| Ctrl+U | Clear your message input |
| Esc / Ctrl+C | Close Bopeep; agents keep running |

When you've jumped into an agent from outside Herdr, press **Ctrl+B then Q** to detach and get back. When jumping from inside a Herdr tab, just switch back to your Bopeep tab.

If an agent is sitting on a permission or question dialog, Herdr may reject normal text input. Read the preview and deliberately send the keys that answer the dialog. Bopeep will never auto-approve anything for you.

## What shows up in the flock?

Bopeep lists whatever `herdr agent list` returns for your connected session. It uses Herdr's reported status plus the agent's working directory and terminal title.

- Empty shell tabs and closed agents do not appear
- One Herdr session at a time; inside Herdr it inherits that pane's session, outside it defaults to the default session unless you set `HERDR_SESSION`
- Herdr owns persistence, not Bopeep. If you reboot, configure [Herdr's native session restore](https://herdr.dev/docs/session-state/) for recovery
- Status is whatever Herdr reports. Sometimes a dialog gets reported as idle; the preview still shows what's actually going on

Outside of Herdr:

```sh
HERDR_SESSION=my-session bopeep
```

No network endpoint, no telemetry. Bopeep calls your local Herdr CLI and that's it. Your agents keep their own providers, permissions, and whatever they normally do over the wire.

## Troubleshooting

| Problem | Fix |
| --- | --- |
| `bopeep: command not found` | Run `~/.local/bin/bopeep` directly or add that dir to PATH |
| Missing dependency or fzf too old | `bopeep --check` tells you what's wrong; install/update it |
| `herdr unreachable` | `herdr status`; start Herdr in another terminal if the server stopped |
| Flock is empty / agent missing | Run `herdr agent list` yourself and confirm the agent is actually running in that session |
| Reply gets rejected | Check the preview. The agent may have exited, changed state, or be waiting on a dialog |

If Herdr is down, Bopeep keeps retrying quietly. Your personal `FZF_DEFAULT_OPTS` are ignored so they can't interfere with the keybindings here.

## Update / uninstall

Pull the latest source and rerun `bash install.sh`. To remove:

```sh
rm "$HOME/.local/bin/bopeep"
```

That's all it touches. Herdr, your agents, and their conversations are untouched.

## Development

```sh
bash -n bopeep install.sh test.sh
bash test.sh
```

The tests use a fake Herdr and fzf. They cover sorting, message routing, key sending, empty selections, malformed responses, terminal title sanitization, cursor preservation, temp-file cleanup, version checks, and installing into paths with spaces. Nothing hits real agents. GitHub Actions runs them on both Linux and macOS.

This stays intentionally a single Bash script. Keep changes small. For bug reports: include your OS plus output from `bopeep --version`, `herdr --version`, `fzf --version`, and `jq --version`. Scrub private conversation content before sharing any terminal output.
