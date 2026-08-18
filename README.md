# claudelocal

Launcher scripts that run [Claude Code](https://docs.anthropic.com/en/docs/claude-code) (Anthropic's CLI coding agent) against a **local model hosted on Ollama or LM Studio** — on `localhost` or any reachable machine on your network.

Both Ollama and LM Studio expose an Anthropic-compatible Messages API, so Claude Code can talk to them directly. These scripts set all the required environment variables for you and then launch `claude`, forwarding any extra arguments. Your normal Anthropic-backed `claude` setup is untouched — the variables only apply to the launched session.

Based on the official integration guides:

- Ollama: <https://docs.ollama.com/integrations/claude-code>
- LM Studio: <https://lmstudio.ai/docs/integrations/claude-code>

## Files

| File | Purpose |
|---|---|
| `claudelocal.cmd` | Windows launcher (works from PowerShell and cmd) |
| `claudelocal` | Bash launcher for macOS, Linux, and Git Bash on Windows |
| `claudelocal.conf.example` | Configuration template — copy to `claudelocal.conf` and edit |

## Prerequisites

1. **Claude Code CLI** installed and working:

   ```sh
   npm install -g @anthropic-ai/claude-code
   claude --version
   ```

2. **A local model server**, either:

   - **Ollama** — <https://ollama.com>. Pull a coding-capable model and make sure the server is running (it listens on port `11434` by default):

     ```sh
     ollama pull qwen2.5-coder:7b
     ollama serve   # usually already running as a service/app
     ```

   - **LM Studio** — <https://lmstudio.ai>. Download a model, load it, and start the local server (port `1234` by default):

     ```sh
     lms server start
     ```

     or use the **Developer / Local Server** tab in the app.

## Configuration

Settings come from three sources, in order of precedence:

**command-line flag** → **`claudelocal.conf`** (next to the script) → **built-in default**

### Config file

Copy the example and edit it:

```sh
cp claudelocal.conf.example claudelocal.conf
```

```ini
# claudelocal.conf
BACKEND=ollama           # ollama | lmstudio
HOST=localhost           # hostname or IP of the model server
PORT=                    # blank = 11434 (Ollama) / 1234 (LM Studio)
MODEL=                   # blank = auto-detect from the server
CONTEXT_TOKENS=65536     # context window Claude Code should assume
AUTO_COMPACT_TOKENS=     # blank = auto-calculated (75% of CONTEXT_TOKENS)
AUTH_TOKEN=              # only needed for LM Studio "Require Authentication"
```

> **If you put a real LM Studio token in `claudelocal.conf`, don't commit it to source control.** The provided `.gitignore` already excludes it.

### Command-line flags

```
claudelocal [options] [--] [claude args...]

  -m, --model NAME      Model name (default: auto-detect the server's first model)
  -b, --backend NAME    ollama | lmstudio
  -H, --host HOST       Hostname or IP (may include http://)
  -p, --port PORT       Server port
  -x, --context N       Context window in tokens (auto-compact = 75% of this)
  -k, --token TOKEN     Auth token (LM Studio "Require Authentication")
  -c, --config FILE     Alternate config file
  -h, --help            Show help
```

Anything the script doesn't recognize is passed straight through to `claude` (use `--` first if you want to be explicit). One deliberate collision is handled for you: `-p` followed by a **number** sets the port, while `-p` followed by anything else (or nothing) is passed to `claude` as its own `-p`/`--print` flag.

```powershell
claudelocal                                    # config-file defaults
claudelocal -b lmstudio                        # talk to LM Studio instead
claudelocal -m qwen2.5-coder:14b               # one-off model override
claudelocal -H 192.168.1.50                    # server on another machine
claudelocal -b lmstudio -H 192.168.1.50 -p 1234 -m "qwen3-coder-30b"
claudelocal -x 262144                          # 256K context (compact at 196608)
claudelocal -- --verbose                       # pass --verbose to claude
```

> On Windows (`claudelocal.cmd`), `-c`/`--config` must be the **first** option when used. The bash script accepts it anywhere.

### Model auto-detection

If `MODEL` is unset (config and flag), the script queries `http://<host>:<port>/v1/models` and uses the **first model the server reports**. For LM Studio that's the currently loaded model; for Ollama it's the first entry in `ollama list`. Set `MODEL` explicitly if you run multiple models.

## Setup — Windows

1. Copy `claudelocal.cmd` (and optionally `claudelocal.conf.example`) to a folder, e.g. `C:\claudelocal`.
2. Create `claudelocal.conf` next to it (optional — defaults work for a localhost Ollama).
3. Add the folder to your user `PATH` (PowerShell):

   ```powershell
   [Environment]::SetEnvironmentVariable(
     'Path',
     [Environment]::GetEnvironmentVariable('Path','User') + ';C:\claudelocal',
     'User')
   ```

4. Open a **new** terminal and run:

   ```powershell
   claudelocal
   ```

Git Bash users on Windows can use the bash `claudelocal` script from the same folder instead — both read the same `claudelocal.conf`.

## Setup — macOS / Linux

1. Copy the `claudelocal` script (no extension) to a directory on your `PATH`, e.g. `~/.local/bin` or `/usr/local/bin`:

   ```sh
   mkdir -p ~/.local/bin
   cp claudelocal ~/.local/bin/
   chmod +x ~/.local/bin/claudelocal
   ```

2. Copy `claudelocal.conf.example` to `claudelocal.conf` in the same directory and edit it (optional).

3. If `~/.local/bin` isn't already on your `PATH`, add it in your shell profile:

   ```sh
   export PATH="$HOME/.local/bin:$PATH"
   ```

4. Run:

   ```sh
   claudelocal
   ```

## Running the server on another machine

Point `HOST` at the remote machine and make sure the server listens on the network:

- **Ollama** binds to localhost by default. To expose it on the LAN, start it with:

  ```sh
  OLLAMA_HOST=0.0.0.0 ollama serve
  ```

  (on Windows, set the `OLLAMA_HOST` environment variable to `0.0.0.0` and restart Ollama).

- **LM Studio**: enable **"Serve on local network"** in the server settings, then start the server.

Then:

```powershell
claudelocal -H 192.168.1.50
```

> Exposing a model server on your network gives anyone who can reach it access to the model. Keep it to trusted networks, or use LM Studio's "Require Authentication" with `-k`.

## Verifying it works

Inside the launched Claude Code session, run:

```
/status
```

The Base URL should show your server, e.g. `http://localhost:11434`. If it shows an Anthropic URL, the environment variables didn't take effect — make sure you launched via `claudelocal`, not `claude`.

You can also sanity-check the server directly:

```sh
curl http://localhost:11434/v1/models    # Ollama
curl http://localhost:1234/v1/models     # LM Studio
```

## What the scripts configure

| Variable | Value | Why |
|---|---|---|
| `ANTHROPIC_BASE_URL` | `http://<host>:<port>` | The server's Anthropic-compatible endpoint (no `/v1` suffix — Claude Code appends paths itself) |
| `ANTHROPIC_AUTH_TOKEN` | placeholder (`ollama`/`lmstudio`) or `-k` value | Claude Code requires a non-empty token; local servers don't validate it (unless LM Studio auth is enabled) |
| `ANTHROPIC_API_KEY` | unset | Prevents a stray cloud key from taking precedence |
| `ANTHROPIC_MODEL` | configured/auto-detected model | The model every request uses |
| `ANTHROPIC_DEFAULT_FABLE_MODEL`, `ANTHROPIC_DEFAULT_OPUS_MODEL`, `ANTHROPIC_DEFAULT_SONNET_MODEL`, `ANTHROPIC_DEFAULT_HAIKU_MODEL`, `ANTHROPIC_SMALL_FAST_MODEL`, `CLAUDE_CODE_SUBAGENT_MODEL` | same model | Every model tier and subagent stays on the local model |
| `CLAUDE_CODE_MAX_CONTEXT_TOKENS` | `CONTEXT_TOKENS` (default 65536) | Tell Claude Code the backend's context size |
| `CLAUDE_CODE_AUTO_COMPACT_WINDOW` | `AUTO_COMPACT_TOKENS` (default: 75% of `CONTEXT_TOKENS`) | Auto-compaction calibrated to leave ~25% headroom below the real window |
| `CLAUDE_CODE_DISABLE_NONESSENTIAL_TRAFFIC` | `1` | Keeps the session local-first; no calls to Anthropic services |
| `ENABLE_TOOL_SEARCH` | `false` | Tool search is specific to Anthropic's backend |

## Tuning the context window

`CONTEXT_TOKENS` must match the context length your server actually gives the model, or Claude Code will either compact too early or the server will truncate mid-session:

- **Ollama**: default context is often small (4K). Set `num_ctx` in the model's Modelfile, or run `ollama run <model> --ctx-size 65536` / set `OLLAMA_CONTEXT_LENGTH` on newer versions.
- **LM Studio**: set the context length when loading the model (Server tab → model load options). LM Studio recommends at least ~25K for coding agents.

Then set the same number in `claudelocal.conf`, e.g. `CONTEXT_TOKENS=32768`.

### How auto-compaction is calculated

Claude Code's default behavior is to compact at ~95% of the window — far too late for small local models, which start truncating or erroring near their real limit. Following community guidelines, the scripts therefore leave **~25% headroom**:

```
AUTO_COMPACT_TOKENS = CONTEXT_TOKENS × 0.75   (when not set explicitly)
```

so for `CONTEXT_TOKENS=65536` the compact window is `49152`, and compaction fires around 70% of the real window rather than at its edge. The launch banner shows both numbers so you can confirm. To override, set `AUTO_COMPACT_TOKENS` in `claudelocal.conf`.

## Troubleshooting

- **`WARNING: could not reach http://...`** — the server isn't running, is on a different port, or a firewall is blocking the LAN port. Verify with `curl http://<host>:<port>/v1/models`.
- **`ERROR: no model configured and none could be auto-detected`** — the server is running but has no model available/loaded. Pull one (`ollama pull ...`) or load one in LM Studio, or pass `-m` explicitly.
- **`claudelocal: command not found`** — the script's folder isn't on your `PATH`, or you haven't opened a new terminal since adding it.
- **401 / Unauthorized from LM Studio** — "Require Authentication" is on; pass your LM Studio API token with `-k` or set `AUTH_TOKEN` in the config.
- **Model not found errors** — the model name must match exactly what the server reports (`ollama list`, or the identifier in LM Studio), including tags like `:7b`.
- **Answers degrade or get cut off on long sessions** — your `CONTEXT_TOKENS` is larger than the model's actual context (see *Tuning the context window*), or the model is simply too small for agentic coding. Prefer coding-tuned models (e.g. Qwen coder variants) with the largest context your hardware allows.
- **Claude Code asks to save an API key** — answer **No**; the placeholder token is only for the local session.

## License

[MIT](LICENSE)
