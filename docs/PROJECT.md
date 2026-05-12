# Godogen — From Prompt to Playable Game

Godogen is an autonomous development pipeline for turning a natural-language game brief into a playable Godot or Bevy project. It plans the game, generates visual direction and assets, writes code, and captures media from the running engine for visual review.

It is not a game engine, a code generator, or an asset marketplace. It is a source repo for runtime skills that are published into a fresh game repo and then executed by any coding agent.

## Source Model

The repo is organized by engine:

- `shared/` — engine-agnostic `godogen` stages, the shared `Stop` hook, and common published-repo instructions
- `godot/` — Godot-specific `godogen` stages and `godot-api`
- `bevy/` — Bevy-specific `godogen` stages and `bevy-help`

Publishing is agent-agnostic:

```bash
./publish.sh --engine godot --out ~/game
./publish.sh --engine bevy  --out ~/game
```

Publishing writes `AGENTS.md` plus `.agents/skills/` with `agents/metadata.yaml` generated from each skill's `SKILL.md` frontmatter. It also writes small compatibility shims for common AI tools, including `CLAUDE.md`, `GEMINI.md`, `opencode.jsonc`, `.cursor/rules/`, `.clinerules/`, `.windsurf/rules/`, and `.continue/rules/`.

## Pipeline

The `godogen` skill orchestrates the run and loads stage-specific files only when they are needed:

1. **Visual target** — generate `reference.png` and write art direction into `ASSETS.md`.
2. **Decomposition** — write `PLAN.md`, isolating only genuinely risky features.
3. **Scaffold** — create or update the engine project shell and `STRUCTURE.md`.
4. **Asset planning and generation** — spend the user-provided budget on the assets that matter most via Meshy AI.
5. **Task execution** — implement risk slices first, then the main build.
6. **Capture** — create a fresh `screenshots/result/{N}/` bundle with raw `frameXXX.png` files and `video.mp4`.
7. **Telegram push** — the shared stop hook pushes the latest proof video to Telegram when configured; otherwise it no-ops.

The document protocol is deliberate. `PLAN.md`, `STRUCTURE.md`, `ASSETS.md`, and `MEMORY.md` survive context compaction and let the run resume from files instead of conversational memory.

## Engine Support

Godot output is a Godot 4 C#/.NET project. The Godot runtime skill uses scene builders for generated `.tscn` files, runtime scripts for gameplay, `godot-api` for targeted engine lookup, and a Godot capture helper for final proof bundles.

Bevy output is a Rust/Bevy project. The Bevy runtime skill uses code-first scene construction, local Bevy rustdoc/examples through `bevy-help`, and a dedicated capture path for final proof bundles.

Both engines share the same final-bundle contract: the latest numeric `screenshots/result/{N}/` folder containing `video.mp4` plus its raw `frameXXX.png` sequence.

## What Makes This Different

**Capture-first proof.** The pipeline captures actual frames from the game and assembles them into a final proof bundle, so the run is judged on what the game looks like rather than on what the code claims.

**Progressive loading.** The orchestrator reads only the stage file it needs at the moment. Support skills keep large engine references out of the main context.

**Budget-aware asset generation.** Meshy AI provides images, 3D models, rigging, and animation with consistent art styles. Generated assets are assigned back into `PLAN.md`.

**Agent-agnostic.** Published repos use `AGENTS.md` as the canonical instruction file and generate compatibility shims for common coding agents. If a tool does not load `.agents/skills/` natively, the root instructions tell it to read `.agents/skills/godogen/SKILL.md` directly.

## Runtime Limitations

The current runtime does not ship audio. Godot supports debug APK export when requested; Bevy Android export is not implemented yet.
