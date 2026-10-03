# claudelocal

Launcher scripts that run [Claude Code](https://docs.anthropic.com/en/docs/claude-code) (Anthropic's CLI coding agent) against a **local model hosted on Ollama, LM Studio, or oMLX** — on `localhost` or any reachable machine on your network.

Ollama, LM Studio, and oMLX all expose an Anthropic-compatible Messages API, so Claude Code can talk to them directly. These scripts set all the required environment variables for you and then launch `claude`, forwarding any extra arguments. Your normal Anthropic-backed `claude` setup is untouched — the variables only apply to the launched session.

Based on the official integration guides:

- Ollama: <https://docs.ollama.com/integrations/claude-code>
- LM Studio: <https://lmstudio.ai/docs/integrations/claude-code>
- oMLX: <https://github.com/jundot/omlx> (its built-in `omlx launch claude` integration)

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

   - **oMLX** — <https://github.com/jundot/omlx>. An MLX inference server for **Apple Silicon Macs** (the Mac runs the server; `claudelocal` can run on the Mac or on any machine that can reach it). Install the macOS app from the [releases page](https://github.com/jundot/omlx/releases), or use Homebrew, then start the server (port `8000` by default):

     ```sh
     brew tap jundot/omlx https://github.com/jundot/omlx
     brew install jundot/omlx/omlx
     omlx start                        # background service; or: omlx serve --model-dir ~/models
     ```

     Models are MLX-format subdirectories of the model directory (`~/.omlx/models` by default); you can also download them from the admin panel at `http://localhost:8000/admin`.

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
BACKEND=ollama           # ollama | lmstudio | omlx
HOST=localhost           # hostname or IP of the model server
PORT=                    # blank = 11434 (Ollama) / 1234 (LM Studio) / 8000 (oMLX)
MODEL=                   # blank = auto-detect from the server
CONTEXT_TOKENS=65536     # context window Claude Code should assume
AUTO_COMPACT_TOKENS=     # blank = auto-calculated (75% of CONTEXT_TOKENS)
AUTH_TOKEN=              # LM Studio "Require Authentication" token, or the oMLX API key
TIMEOUT_MS=              # blank = Claude Code's own default (600000 / 10 min)
```

> **If you put a real LM Studio token or oMLX API key in `claudelocal.conf`, don't commit it to source control.** The provided `.gitignore` already excludes it.

### Command-line flags

```
claudelocal [options] [--] [claude args...]

  -m, --model NAME      Model name (default: auto-detect the server's first model)
  -b, --backend NAME    ollama | lmstudio | omlx
  -H, --host HOST       Hostname or IP (may include http://)
  -p, --port PORT       Server port
  -x, --context N       Context window in tokens (auto-compact = 75% of this)
  -k, --token TOKEN     Auth token (LM Studio "Require Authentication", or the oMLX API key)
  -t, --timeout MS      API request timeout in milliseconds (default: 600000)
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
claudelocal -b omlx -H 192.168.1.60 -k "$OMLX_KEY" -m "Qwen3-Coder-30B-A3B-Instruct-4bit"
claudelocal -x 262144                          # 256K context (compact at 196608)
claudelocal -t 1200000                         # raise API timeout to 20 minutes
claudelocal -- --verbose                       # pass --verbose to claude
```

> On Windows (`claudelocal.cmd`), `-c`/`--config` must be the **first** option when used. The bash script accepts it anywhere.

### Model auto-detection

If `MODEL` is unset (config and flag), the script queries `http://<host>:<port>/v1/models` (sending `AUTH_TOKEN` as a bearer token) and uses the **first model the server reports**. For LM Studio that's the currently loaded model; for Ollama it's the first entry in `ollama list`; for oMLX it's the first model in its model directory, with favorites listed first, whether or not it's loaded. Set `MODEL` explicitly if you run multiple models.

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

- **oMLX** binds to localhost by default and **refuses to start on a network address without an API key**. Set both together, either in the admin panel's global settings or on the command line:

  ```sh
  OMLX_API_KEY=your-secret-key omlx serve --host 0.0.0.0
  ```

  then pass the same key to `claudelocal` with `-k` or `AUTH_TOKEN`.

Then:

```powershell
claudelocal -H 192.168.1.50
```

> Exposing a model server on your network gives anyone who can reach it access to the model. Keep it to trusted networks, or use LM Studio's "Require Authentication" (or oMLX's API key) with `-k`.

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
curl -H "Authorization: Bearer <api-key>" http://localhost:8000/v1/models   # oMLX
```

## What the scripts configure

| Variable | Value | Why |
|---|---|---|
| `ANTHROPIC_BASE_URL` | `http://<host>:<port>` | The server's Anthropic-compatible endpoint (no `/v1` suffix — Claude Code appends paths itself) |
| `ANTHROPIC_AUTH_TOKEN` | placeholder (`ollama`/`lmstudio`/`omlx`) or `-k` value | Claude Code requires a non-empty token; local servers don't validate it unless LM Studio auth is enabled or oMLX has an API key |
| `ANTHROPIC_API_KEY` | unset | Prevents a stray cloud key from taking precedence |
| `ANTHROPIC_MODEL` | configured/auto-detected model | The model every request uses |
| `ANTHROPIC_DEFAULT_FABLE_MODEL`, `ANTHROPIC_DEFAULT_OPUS_MODEL`, `ANTHROPIC_DEFAULT_SONNET_MODEL`, `ANTHROPIC_DEFAULT_HAIKU_MODEL`, `ANTHROPIC_SMALL_FAST_MODEL`, `CLAUDE_CODE_SUBAGENT_MODEL` | same model | Every model tier and subagent stays on the local model |
| `CLAUDE_CODE_MAX_CONTEXT_TOKENS` | `CONTEXT_TOKENS` (default 65536) | Tell Claude Code the backend's context size |
| `CLAUDE_CODE_AUTO_COMPACT_WINDOW` | `AUTO_COMPACT_TOKENS` (default: 75% of `CONTEXT_TOKENS`) | Auto-compaction calibrated to leave ~25% headroom below the real window |
| `CLAUDE_CODE_DISABLE_NONESSENTIAL_TRAFFIC` | `1` | Keeps the session local-first; no calls to Anthropic services |
| `ENABLE_TOOL_SEARCH` | `false` | Tool search needs an API that honors `defer_loading` and `tool_reference` blocks. Ollama, LM Studio, and oMLX ignore them, so it would only add a `ToolSearch` tool that always comes back empty, without saving any context |
| `CLAUDE_CODE_ATTRIBUTION_HEADER` | `0` | Omits Claude Code's attribution block (client version and prompt fingerprint) from the start of the system prompt so it can't disturb the server's prompt cache. Recommended by LM Studio and oMLX |
| `API_TIMEOUT_MS` | `TIMEOUT_MS` (only set if configured) | Per-request timeout; raise it if slow local inference triggers "API Error (Request timed out)" |

For the `omlx` backend only, the scripts also pass `--disallowedTools=LSP` to `claude`. Claude Code adds the LSP tool's schema to the tools array when a language server connects mid-session, and because tool schemas sit at the front of the prompt, that one change forces oMLX to re-process the whole conversation instead of reusing its cache. oMLX's own launcher does the same. If you pass your own `--disallowedTools`, the scripts leave it alone, so include `LSP` in your list if you still want it denied.

## Tuning the context window

`CONTEXT_TOKENS` must match the context length your server actually gives the model, or Claude Code will either compact too early or the server will truncate mid-session:

- **Ollama**: default context is often small (4K). Set `num_ctx` in the model's Modelfile, or run `ollama run <model> --ctx-size 65536` / set `OLLAMA_CONTEXT_LENGTH` on newer versions.
- **LM Studio**: set the context length when loading the model (Server tab → model load options). LM Studio recommends at least ~25K for coding agents.
- **oMLX**: set the model's max context window in its per-model settings in the admin panel (`/admin`). Without one, oMLX falls back to 32K, and its own Claude Code launcher refuses models below 48K. `curl /v1/models` shows the effective value for each model as `max_model_len`.

Then set the same number in `claudelocal.conf`, e.g. `CONTEXT_TOKENS=32768`.

### How auto-compaction is calculated

Claude Code's default behavior is to compact at ~95% of the window — far too late for small local models, which start truncating or erroring near their real limit. Following community guidelines, the scripts therefore leave **~25% headroom**:

```
AUTO_COMPACT_TOKENS = CONTEXT_TOKENS × 0.75   (when not set explicitly)
```

so for `CONTEXT_TOKENS=65536` the compact window is `49152`, and compaction fires around 70% of the real window rather than at its edge. The launch banner shows both numbers so you can confirm. To override, set `AUTO_COMPACT_TOKENS` in `claudelocal.conf`.

## Tuning the API request timeout

Claude Code times out a request if it doesn't get a response within `API_TIMEOUT_MS` (default `600000`, i.e. 10 minutes). Local models can exceed that on modest hardware, with large `CONTEXT_TOKENS`, or with reasoning models that emit a long hidden "thinking" pass before the visible answer — surfacing as `API Error (Request timed out)`.

Set `TIMEOUT_MS` in `claudelocal.conf` or pass `-t`/`--timeout` to raise it, e.g.:

```sh
claudelocal -t 1200000   # 20 minutes
```

Leave it blank to keep Claude Code's own default — raising it only masks a real problem (undersized hardware, an oversized `CONTEXT_TOKENS`, or a wedged server) if the request was never going to finish.

oMLX sends keep-alive events while it processes a long prompt, and its own Claude Code launcher sets the timeout to `3000000` (50 minutes). If you see timeouts with oMLX, that's a reasonable value to try.

## Troubleshooting

- **`WARNING: could not reach http://...`** — the server isn't running, is on a different port, or a firewall is blocking the LAN port. Verify with `curl http://<host>:<port>/v1/models`.
- **`ERROR: no model configured and none could be auto-detected`** — the server is running but has no model available/loaded. Pull one (`ollama pull ...`) or load one in LM Studio, or pass `-m` explicitly.
- **`claudelocal: command not found`** — the script's folder isn't on your `PATH`, or you haven't opened a new terminal since adding it.
- **401 / Unauthorized from LM Studio** — "Require Authentication" is on; pass your LM Studio API token with `-k` or set `AUTH_TOKEN` in the config.
- **`WARNING: ... rejected the auth token (HTTP 401)` with oMLX** — oMLX has an API key configured (always the case when it serves on the network). Pass it with `-k` or set `AUTH_TOKEN`.
- **Model not found errors** — the model name must match exactly what the server reports (`ollama list`, or the identifier in LM Studio), including tags like `:7b`.
- **Answers degrade or get cut off on long sessions** — your `CONTEXT_TOKENS` is larger than the model's actual context (see *Tuning the context window*), or the model is simply too small for agentic coding. Prefer coding-tuned models (e.g. Qwen coder variants) with the largest context your hardware allows.
- **Claude Code asks to save an API key** — answer **No**; the placeholder token is only for the local session.
- **First response takes a minute or more (looks hung)** — reasoning/thinking models (e.g. Qwen3 variants) emit hidden `reasoning_content` before their real answer, and Claude Code's system prompt + tool definitions are large, so the initial prompt-processing pass can take 30-60+ seconds on consumer hardware — especially with a large `CONTEXT_TOKENS`. This is normal; subsequent turns in the same session are typically faster once the prompt is cached. Check the server's own logs (Ollama's console output, LM Studio's `~/.lmstudio/server-logs/`, or oMLX's `~/.omlx/logs/server.log`) for prompt-processing progress if you want to confirm it's still working rather than stuck.
- **`API Error (Request timed out.)`** — the request exceeded `API_TIMEOUT_MS` (default 10 minutes). Set `TIMEOUT_MS` in `claudelocal.conf` or pass `-t`/`--timeout` to raise it (see *Tuning the API request timeout*).

## License

[MIT](LICENSE)
