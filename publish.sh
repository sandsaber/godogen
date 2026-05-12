#!/usr/bin/env bash
# Publish Godogen runtime files into a target game repo.
#
# Usage:
#   ./publish.sh --engine godot|bevy --out <target_dir> [--force] [--merge]
#                [--agent-compat full|minimal|none] [--dry-run]
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
DRY_RUN=0
AGENT_COMPAT="full"

usage() {
    sed -n '1,6p' "$0" >&2
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

while [ $# -gt 0 ]; do
    case "$1" in
        --engine) ENGINE="${2:-}"; shift 2 ;;
        --out)    OUT="${2:-}";    shift 2 ;;
        --force)  FORCE=1;         shift   ;;
        --merge)  MERGE=1;         shift   ;;
        --dry-run) DRY_RUN=1;      shift   ;;
        --agent-compat) AGENT_COMPAT="${2:-}"; shift 2 ;;
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

case "$AGENT_COMPAT" in
    full|minimal|none) ;;
    *) echo "error: --agent-compat must be full, minimal, or none" >&2; usage; exit 1 ;;
esac

if [ -z "$OUT" ]; then
    echo "error: --out <target_dir> is required" >&2
    usage
    exit 1
fi

MANIFEST="AGENTS.md"
SKILLS_DIR_REL=".agents/skills"
HOOK_CONFIG_DIR=".agents"

if [ "$DRY_RUN" -eq 1 ]; then
    TARGET="$(resolve_path "$OUT")"
else
    TARGET="$(cd "$OUT" 2>/dev/null && pwd || (mkdir -p "$OUT" && cd "$OUT" && pwd))"
fi

if [ "$FORCE" -eq 1 ] && [ -d "$TARGET" ]; then
    if [ "$DRY_RUN" -eq 1 ]; then
        echo "Would clean $TARGET"
    else
        echo "Force: cleaning $TARGET"
        rm -rf "${TARGET:?}"
        mkdir -p "$TARGET"
    fi
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

if [ "$DRY_RUN" -eq 1 ]; then
    echo "Dry run: publishing $ENGINE to: $TARGET"
else
    echo "Publishing $ENGINE to: $TARGET"
fi

if [ "$DRY_RUN" -eq 1 ]; then
    echo "Would publish skills to $TARGET/$SKILLS_DIR_REL"
else
    mkdir -p "$TARGET/$SKILLS_DIR_REL"
    RSYNC_OPTS="-a"
    if [ "$MERGE" -eq 0 ]; then
        RSYNC_OPTS="-a --delete"
    fi
    rsync $RSYNC_OPTS "$TMP/skills/" "$TARGET/$SKILLS_DIR_REL/"
fi

if [ "$ENGINE" = "bevy" ]; then
    if [ "$DRY_RUN" -eq 1 ]; then
        echo "Would link bevy-help docs from source repo"
    else
        link_bevy_docs "$TARGET/$SKILLS_DIR_REL/bevy-help/docs"
        echo "Linked bevy-help docs from source repo"
    fi
fi

mkdir -p "$TMP/game"
cp "$REPO_ROOT/$ENGINE/game-engine.md" "$TMP/game/game-engine.md"
python3 "$HELPERS/render_dir.py" "$TMP/game"
if [ "$DRY_RUN" -eq 1 ]; then
    if [ -f "$TARGET/$MANIFEST" ]; then
        echo "Would update $MANIFEST"
    else
        echo "Would create $MANIFEST"
    fi
else
    cp "$TMP/game/game-engine.md" "$TARGET/$MANIFEST"
    echo "Created $MANIFEST"
fi
COMPAT_ARGS=(--target "$TARGET" --engine "$ENGINE" --mode "$AGENT_COMPAT")
if [ "$DRY_RUN" -eq 1 ]; then
    COMPAT_ARGS+=(--dry-run)
fi
python3 "$HELPERS/generate_agent_compat.py" "${COMPAT_ARGS[@]}"

if [ "$DRY_RUN" -eq 1 ]; then
    echo "Would publish hooks to $TARGET/$HOOK_CONFIG_DIR/hooks"
else
    mkdir -p "$TARGET/$HOOK_CONFIG_DIR/hooks"
    rsync -a "$REPO_ROOT/shared/hooks/stop_post_task_gate.py" \
        "$TARGET/$HOOK_CONFIG_DIR/hooks/"
    rsync -a "$REPO_ROOT/$ENGINE/hooks/" "$TARGET/$HOOK_CONFIG_DIR/hooks/"
    python3 "$HELPERS/render_dir.py" "$TARGET/$HOOK_CONFIG_DIR/hooks" \
        "HOOK_CONFIG_DIR=$HOOK_CONFIG_DIR" \
        "ENGINE_NAME=${ENGINE^}"
    chmod +x "$TARGET/$HOOK_CONFIG_DIR/hooks/stop_post_task_gate.py" "$TARGET/$HOOK_CONFIG_DIR/hooks/capture_result.sh"
fi

if [ ! -f "$TARGET/.gitignore" ]; then
    if [ "$DRY_RUN" -eq 1 ]; then
        echo "Would create .gitignore"
    else
        {
            printf '.agents\nAGENTS.md\n'
            if [ "$AGENT_COMPAT" != "none" ]; then
                printf 'GODOGEN.md\nopencode.jsonc\n'
            fi
            if [ "$AGENT_COMPAT" = "full" ]; then
                printf 'CLAUDE.md\nGEMINI.md\n.cursor/rules/godogen.mdc\n.clinerules/godogen.md\n.windsurf/rules/godogen.md\n.continue/rules/godogen.md\n'
            fi
            if [ "$ENGINE" = "godot" ]; then
                printf 'assets\nscreenshots\n.godot\n*.import\nbin/\nobj/\n'
            else
                printf '/target\n/screenshots\n.bevy-help.log\n'
            fi
        } > "$TARGET/.gitignore"
        echo "Created .gitignore"
    fi
fi

if [ "$DRY_RUN" -eq 1 ]; then
    echo "Would initialize git repo if needed"
else
    git -C "$TARGET" init -q 2>/dev/null || true
fi

echo "Done. skills: $(find "$TMP/skills" -mindepth 1 -maxdepth 1 -type d | wc -l)"
