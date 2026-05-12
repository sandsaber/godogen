#!/usr/bin/env bash
# Publish Godogen runtime files into a target game repo.
#
# Usage:
#   ./publish.sh --engine godot|bevy --out <target_dir> [--force] [--merge]
#
# The Stop hook is best-effort: when `tg-push` and TG_* env vars are present at runtime
# it pushes the latest screenshots/result/{N}/video.mp4 to Telegram, otherwise it no-ops.
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")" && pwd)"
HELPERS="$REPO_ROOT/scripts/publish"

ENGINE=""
OUT=""
FORCE=0
MERGE=0

usage() {
    sed -n '1,9p' "$0" >&2
}

resolve_path() {
    python3 -c 'import pathlib,sys; print(pathlib.Path(sys.argv[1]).expanduser().resolve())' "$1"
}

link_bevy_docs() {
    local target_docs_dir="$1"
    local source_docs_dir="$REPO_ROOT/bevy/skills/bevy-help/docs"
    local name

    mkdir -p "$target_docs_dir"
    if [ -f "$source_docs_dir/.gitignore" ]; then
        cp "$source_docs_dir/.gitignore" "$target_docs_dir/.gitignore"
    fi

    for name in rustdoc bevy bevy-website; do
        local source_link="$source_docs_dir/$name"
        local target_link="$target_docs_dir/$name"
        local source_target

        if [ ! -L "$source_link" ]; then
            echo "error: $source_link is not configured." >&2
            echo "Run ./setup_bevy_docs.sh <shared_bevy_docs_dir> in this source repo before publishing." >&2
            exit 1
        fi

        source_target="$(resolve_path "$source_link")"
        if [ ! -d "$source_target" ]; then
            echo "error: $source_link points to missing docs at $source_target." >&2
            echo "Run ./setup_bevy_docs.sh <shared_bevy_docs_dir> again with a valid Bevy docs folder before publishing." >&2
            exit 1
        fi

        rm -rf "$target_link"
        ln -s "$source_target" "$target_link"
    done
}

write_generated_file() {
    local rel_path="$1"
    local source_path="$2"
    local target_path="$TARGET/$rel_path"

    if [ -f "$target_path" ] && ! grep -Fq "$GENERATED_MARKER" "$target_path"; then
        echo "Preserved existing $rel_path"
        return
    fi

    mkdir -p "$(dirname "$target_path")"
    cp "$source_path" "$target_path"
    echo "Created $rel_path"
}

write_agent_compat_files() {
    local compat_dir="$TMP/agent-compat"

    mkdir -p "$compat_dir"

    cat > "$compat_dir/CLAUDE.md" <<EOF
<!-- $GENERATED_MARKER Edit AGENTS.md in this repo to change Godogen runtime instructions. -->

@./AGENTS.md
EOF

    cat > "$compat_dir/GEMINI.md" <<EOF
<!-- $GENERATED_MARKER Edit AGENTS.md in this repo to change Godogen runtime instructions. -->

@./AGENTS.md
EOF

    cat > "$compat_dir/cursor-godogen.mdc" <<EOF
---
alwaysApply: true
---

<!-- $GENERATED_MARKER Edit AGENTS.md in this repo to change Godogen runtime instructions. -->

Follow the repository root \`AGENTS.md\`. For game generation or update requests, read \`.agents/skills/godogen/SKILL.md\` first if this tool does not load repository skills automatically.
EOF

    cat > "$compat_dir/cline-godogen.md" <<EOF
<!-- $GENERATED_MARKER Edit AGENTS.md in this repo to change Godogen runtime instructions. -->

Follow the repository root \`AGENTS.md\`. For game generation or update requests, read \`.agents/skills/godogen/SKILL.md\` first if this tool does not load repository skills automatically.
EOF

    cat > "$compat_dir/windsurf-godogen.md" <<EOF
<!-- $GENERATED_MARKER Edit AGENTS.md in this repo to change Godogen runtime instructions. -->

Follow the repository root \`AGENTS.md\`. For game generation or update requests, read \`.agents/skills/godogen/SKILL.md\` first if this tool does not load repository skills automatically.
EOF

    cat > "$compat_dir/continue-godogen.md" <<EOF
---
name: Godogen Runtime
description: Load Godogen instructions for game generation and updates.
---

<!-- $GENERATED_MARKER Edit AGENTS.md in this repo to change Godogen runtime instructions. -->

Follow the repository root \`AGENTS.md\`. For game generation or update requests, read \`.agents/skills/godogen/SKILL.md\` first if this tool does not load repository skills automatically.
EOF

    cat > "$compat_dir/opencode.jsonc" <<EOF
{
  "\$schema": "https://opencode.ai/config.json",
  "//": "$GENERATED_MARKER Edit AGENTS.md in this repo to change Godogen runtime instructions.",
  "instructions": [
    "AGENTS.md",
    ".agents/skills/godogen/SKILL.md"
  ]
}
EOF

    write_generated_file "CLAUDE.md" "$compat_dir/CLAUDE.md"
    write_generated_file "GEMINI.md" "$compat_dir/GEMINI.md"
    write_generated_file ".cursor/rules/godogen.mdc" "$compat_dir/cursor-godogen.mdc"
    write_generated_file ".clinerules/godogen.md" "$compat_dir/cline-godogen.md"
    write_generated_file ".windsurf/rules/godogen.md" "$compat_dir/windsurf-godogen.md"
    write_generated_file ".continue/rules/godogen.md" "$compat_dir/continue-godogen.md"
    if [ -f "$TARGET/opencode.json" ] && [ ! -f "$TARGET/opencode.jsonc" ]; then
        echo "Preserved existing opencode.json; skipped opencode.jsonc"
    else
        write_generated_file "opencode.jsonc" "$compat_dir/opencode.jsonc"
    fi
}

while [ $# -gt 0 ]; do
    case "$1" in
        --engine) ENGINE="${2:-}"; shift 2 ;;
        --out)    OUT="${2:-}";    shift 2 ;;
        --force)  FORCE=1;         shift   ;;
        --merge)  MERGE=1;         shift   ;;
        -h|--help) usage; exit 0 ;;
        -*) echo "error: unknown option $1" >&2; usage; exit 1 ;;
        *)
            if [ -n "$OUT" ]; then
                echo "error: target specified more than once" >&2
                exit 1
            fi
            OUT="$1"
            shift
            ;;
    esac
done

case "$ENGINE" in
    godot|bevy) ;;
    *) echo "error: --engine must be godot or bevy" >&2; usage; exit 1 ;;
esac

if [ -z "$OUT" ]; then
    echo "error: --out <target_dir> is required" >&2
    usage
    exit 1
fi

MANIFEST="AGENTS.md"
SKILLS_DIR_REL=".agents/skills"
HOOK_CONFIG_DIR=".agents"
GENERATED_MARKER="Generated by godogen publish.sh."

TARGET="$(cd "$OUT" 2>/dev/null && pwd || (mkdir -p "$OUT" && cd "$OUT" && pwd))"

if [ "$FORCE" -eq 1 ] && [ -d "$TARGET" ]; then
    echo "Force: cleaning $TARGET"
    rm -rf "${TARGET:?}"
    mkdir -p "$TARGET"
fi

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

mkdir -p "$TMP/skills/godogen"
rsync -a --delete --exclude='__pycache__/' "$REPO_ROOT/shared/skills/godogen/" "$TMP/skills/godogen/"
rsync -a --exclude='__pycache__/' "$REPO_ROOT/$ENGINE/skills/godogen/" "$TMP/skills/godogen/"

if [ "$ENGINE" = "godot" ]; then
    rsync -a --delete --exclude='doc_source/' --exclude='__pycache__/' \
        "$REPO_ROOT/godot/skills/godot-api" "$TMP/skills/"
else
    rsync -a --delete --exclude='docs/' --exclude='__pycache__/' \
        "$REPO_ROOT/bevy/skills/bevy-help" "$TMP/skills/"
fi

python3 "$HELPERS/render_dir.py" "$TMP" \
    "SKILLS_DIR=$SKILLS_DIR_REL" \
    "GODOGEN_SKILL_DIR=$SKILLS_DIR_REL/godogen" \
    "GODOT_API_SKILL_DIR=$SKILLS_DIR_REL/godot-api" \
    "BEVY_HELP_SKILL_DIR=$SKILLS_DIR_REL/bevy-help" \
    "ENGINE_NAME=${ENGINE^}"

python3 "$HELPERS/generate_agent_metadata.py" "$TMP/skills"

echo "Publishing $ENGINE to: $TARGET"

mkdir -p "$TARGET/$SKILLS_DIR_REL"
RSYNC_OPTS="-a"
if [ "$MERGE" -eq 0 ]; then
    RSYNC_OPTS="-a --delete"
fi
rsync $RSYNC_OPTS "$TMP/skills/" "$TARGET/$SKILLS_DIR_REL/"

if [ "$ENGINE" = "bevy" ]; then
    link_bevy_docs "$TARGET/$SKILLS_DIR_REL/bevy-help/docs"
    echo "Linked bevy-help docs from source repo"
fi

mkdir -p "$TMP/game"
cp "$REPO_ROOT/$ENGINE/game-engine.md" "$TMP/game/game-engine.md"
python3 "$HELPERS/render_dir.py" "$TMP/game"
cp "$TMP/game/game-engine.md" "$TARGET/$MANIFEST"
echo "Created $MANIFEST"
write_agent_compat_files

mkdir -p "$TARGET/$HOOK_CONFIG_DIR/hooks"
rsync -a "$REPO_ROOT/shared/hooks/stop_post_task_gate.py" \
    "$TARGET/$HOOK_CONFIG_DIR/hooks/"
rsync -a "$REPO_ROOT/$ENGINE/hooks/" "$TARGET/$HOOK_CONFIG_DIR/hooks/"
python3 "$HELPERS/render_dir.py" "$TARGET/$HOOK_CONFIG_DIR/hooks" \
    "HOOK_CONFIG_DIR=$HOOK_CONFIG_DIR" \
    "ENGINE_NAME=${ENGINE^}"
chmod +x "$TARGET/$HOOK_CONFIG_DIR/hooks/stop_post_task_gate.py" "$TARGET/$HOOK_CONFIG_DIR/hooks/capture_result.sh"

if [ ! -f "$TARGET/.gitignore" ]; then
    {
        printf '.agents\nAGENTS.md\nCLAUDE.md\nGEMINI.md\nopencode.jsonc\n.cursor/rules/godogen.mdc\n.clinerules/godogen.md\n.windsurf/rules/godogen.md\n.continue/rules/godogen.md\n'
        if [ "$ENGINE" = "godot" ]; then
            printf 'assets\nscreenshots\n.godot\n*.import\nbin/\nobj/\n'
        else
            printf '/target\n/screenshots\n.bevy-help.log\n'
        fi
    } > "$TARGET/.gitignore"
    echo "Created .gitignore"
fi

git -C "$TARGET" init -q 2>/dev/null || true

echo "Done. skills: $(find "$TARGET/$SKILLS_DIR_REL" -mindepth 1 -maxdepth 1 -type d | wc -l)"
