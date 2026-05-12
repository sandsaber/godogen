# Godogen: Autonomous game development for Godot and Bevy

[![Watch the video](https://img.youtube.com/vi/eUz19GROIpY/maxresdefault.jpg)](https://youtu.be/eUz19GROIpY)

[Watch the demos](https://youtu.be/eUz19GROIpY) · [Prompts](docs/demo_prompts.md)

Describe a game. Godogen plans it, writes the code, generates assets, runs the engine, checks screenshots, and fixes what looks wrong.

This repo is not a game. It is the source for a generator that produces games: **godogen -> game repo -> game**. You publish the skills into a fresh game repo, choosing the engine, then any coding agent runs inside that repo to build the actual game.

## Source layout

The source is organized along the engine axis:

- `shared/` — engine-agnostic `godogen` stages, asset-generation tooling, shared stop hook, and common game-repo instructions
- `godot/` — Godot-specific `godogen` stages, Godot capture helpers, and the `godot-api` skill
- `bevy/` — Bevy-specific `godogen` stages, Bevy capture helpers, and the `bevy-help` skill

The root [publish.sh](publish.sh) renders the right runtime layout for the chosen engine. Works with any coding agent — Claude Code, Codex, Cursor, OpenCode, Cline, Gemini CLI, Windsurf, Continue, and others.

## What skills do

- **Godot 4 output** — real C#/.NET projects with proper scene trees, scene builders, scripts, and asset organization.
- **Godot Android export** — debug APK export remains available when the user requests an Android app.
- **Bevy output** — Rust/Bevy projects with code-first scenes, local Bevy docs lookup, deterministic capture guidance, and final proof bundles.
- **Asset generation** — Meshy AI generates images, 3D models, rigged characters, and animations. Six art styles: realistic, cartoon, anime, pixel-art, voxel, clay. Background removal via BiRefNet for sprite transparency.
- **C# / .NET 9 for Godot** — Godot output uses C#. See [why C# over GDScript](docs/gdscript-vs-csharp.md).
- **Frame-grounded self-repair** — the agent is prompted to judge progress from captured screenshots, not from code that compiles.
- **Telegram proof push** — published repos install a stop hook that pushes the latest `screenshots/result/{N}/video.mp4` to Telegram when `tg-push` and the TG_* env vars are configured. No-op otherwise.
- **Cross-agent bootstrap** — published repos include `AGENTS.md`, `CLAUDE.md`, `GEMINI.md`, `opencode.jsonc`, and common rule-file shims so tools that do not natively load `.agents/skills/` still find the Godogen runtime.
- **Runs on commodity hardware** — any machine with the relevant engine toolchain, Python, and the required API key can run the pipeline.

## Getting started

### Prerequisites

- [Godot 4](https://godotengine.org/download/) (.NET build) on `PATH` for Godot projects
- Rust/Cargo plus local Bevy docs for Bevy projects
- Python 3 with pip
- API key:
  - `MESHY_API_KEY` — [Meshy AI](https://www.meshy.ai/) for image and 3D generation
- System packages from [setup.md](setup.md): `vulkan-tools`, `xvfb`, `ffmpeg`, `imagemagick`, plus platform-specific extras
- Tested on Ubuntu, Debian, and macOS
- Any coding agent (Claude Code, Codex, Cursor, OpenCode, etc.)

### Publish a game repo

Pick the engine:

```bash
./publish.sh --engine godot --out ~/my-game
./publish.sh --engine bevy  --out ~/my-game
```

Flags:
- `--force` — wipe existing contents at the target before publishing
- `--merge` — preserve any existing custom skills in `.agents/skills/` alongside godogen skills

Useful for integrating godogen into an existing project:

```bash
./publish.sh --engine godot --merge --out ~/existing-project
```

### Bevy docs setup

If you're working on Bevy generation, configure and populate a shared Bevy docs folder once after clone:

```bash
./setup_bevy_docs.sh /absolute/or/user/path/to/bevy-docs
```

## Running on a server

A full generation run can take hours, so it's convenient to offload it to a server, ideally a GPU instance.

- Keep the session alive across SSH drops with `tmux` or `screen`.
- Install [tg-push](https://github.com/htdt/tg-push): the stop hook auto-sends the final proof video to Telegram on completion.
- Use remote control to check in and steer the run from any device.

## Improving the skills

After a full generation session, ask the agent to review how the pipeline performed:

> Analyze this session. Were the instructions optimal? Flag anything that was too obvious, missing, or misleading. Did any tools pollute context with noise? Did the capture loop catch the real problems? Any tool failures or workarounds?

## Changelog

See [CHANGELOG.md](CHANGELOG.md).

Follow progress: [@alex_erm](https://x.com/alex_erm)
