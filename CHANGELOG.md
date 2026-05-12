# Changelog

**2026-05-12 — Cross-agent bootstrap shims**
- Expanded published `AGENTS.md` templates so non-native skill loaders know to read `.agents/skills/godogen/SKILL.md`
- Added generated compatibility shims for Claude Code, Gemini CLI, OpenCode, Cursor, Cline, Windsurf, and Continue
- Preserved existing user-owned compatibility files when publishing into an existing project

**2026-05-10 — Universal agent support + Meshy AI**
- Removed Claude/Codex-specific publish paths; `publish.sh` now outputs a universal agent-agnostic layout (`AGENTS.md` + `.agents/skills/`)
- Replaced Gemini/Grok image generation and Tripo3D with Meshy AI for all image and 3D model generation
- Added six art styles: realistic, cartoon, anime, pixel-art, voxel, clay
- Meshy provides text-to-3D, image-to-3D, rigging, animation, retexturing, text-to-image, and image-to-image
- Removed `--agent` flag from `publish.sh`; works with any coding agent out of the box
- Consolidated publish scripts into one `generate_agent_metadata.py`
- Updated all documentation to be agent-agnostic

**2026-04-26 — Bevy support**
- Added Bevy as a first-class engine alongside Godot
- Replaced the four Claude/Codex source trees with `shared/`, `godot/`, and `bevy/`
- Added one root `publish.sh` switcher: `--engine godot|bevy`

**2026-04-14 — Codex support**
- Added a parallel Codex source tree alongside the existing Claude Code one

**2026-04-06 — C# migration**
- All skills and generated code migrated from GDScript to C# / .NET 9 ([comparison](docs/gdscript-vs-csharp.md))

**2026-04-03 — Single-context architecture**
- Orchestrator and task execution merged into one main pipeline

**2026-03-25 — xAI Grok video**
- Added Grok video generation for animated sprite workflows

**2026-03-09 — Initial release**
- Initial Godogen release
