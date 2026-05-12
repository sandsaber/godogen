#!/usr/bin/env bash
# Smoke-test the publish pipeline without requiring engine binaries.
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
WORKDIR="$(mktemp -d "${TMPDIR:-/tmp}/godogen-publish-smoke.XXXXXX")"
trap 'rm -rf "$WORKDIR"' EXIT

assert_file() {
    test -f "$1" || {
        echo "missing file: $1" >&2
        exit 1
    }
}

assert_no_path() {
    test ! -e "$1" || {
        echo "unexpected path exists: $1" >&2
        exit 1
    }
}

assert_grep() {
    local pattern="$1"
    local path="$2"
    grep -Fq "$pattern" "$path" || {
        echo "missing pattern '$pattern' in $path" >&2
        exit 1
    }
}

FULL="$WORKDIR/godot-full"
"$REPO_ROOT/publish.sh" --engine godot --force --out "$FULL"
assert_file "$FULL/AGENTS.md"
assert_file "$FULL/GODOGEN.md"
assert_file "$FULL/CLAUDE.md"
assert_file "$FULL/GEMINI.md"
assert_file "$FULL/opencode.jsonc"
assert_file "$FULL/.cursor/rules/godogen.mdc"
assert_file "$FULL/.clinerules/godogen.md"
assert_file "$FULL/.windsurf/rules/godogen.md"
assert_file "$FULL/.continue/rules/godogen.md"
assert_file "$FULL/.agents/skills/godogen/agents/metadata.yaml"
assert_file "$FULL/.agents/skills/godot-api/agents/metadata.yaml"
assert_file "$FULL/.agents/skills/godogen/gdscript-mode.md"
assert_grep ".agents/skills/godogen/SKILL.md" "$FULL/opencode.jsonc"
assert_grep "GDScript syntax" "$FULL/GODOGEN.md"
assert_grep "GODOGEN.md" "$FULL/.gitignore"

printf 'custom claude instructions\n' > "$FULL/CLAUDE.md"
printf '{"model":"custom"}\n' > "$FULL/opencode.json"
rm -f "$FULL/opencode.jsonc"
"$REPO_ROOT/publish.sh" --engine godot --merge --out "$FULL"
assert_grep "custom claude instructions" "$FULL/CLAUDE.md"
assert_file "$FULL/opencode.json"
assert_no_path "$FULL/opencode.jsonc"

MINIMAL="$WORKDIR/godot-minimal"
"$REPO_ROOT/publish.sh" --engine godot --force --agent-compat minimal --out "$MINIMAL"
assert_file "$MINIMAL/GODOGEN.md"
assert_file "$MINIMAL/opencode.jsonc"
assert_no_path "$MINIMAL/CLAUDE.md"
assert_no_path "$MINIMAL/.cursor/rules/godogen.mdc"
assert_grep "opencode.jsonc" "$MINIMAL/.gitignore"

NONE="$WORKDIR/godot-none"
"$REPO_ROOT/publish.sh" --engine godot --force --agent-compat none --out "$NONE"
assert_file "$NONE/AGENTS.md"
assert_no_path "$NONE/GODOGEN.md"
assert_no_path "$NONE/opencode.jsonc"
assert_no_path "$NONE/CLAUDE.md"

DRY="$WORKDIR/dry-run-target"
"$REPO_ROOT/publish.sh" --engine godot --dry-run --out "$DRY" > "$WORKDIR/dry-run.log"
assert_no_path "$DRY"
assert_grep "Would create AGENTS.md" "$WORKDIR/dry-run.log"
assert_grep "Would create opencode.jsonc" "$WORKDIR/dry-run.log"

"$REPO_ROOT/publish.sh" --engine bevy --dry-run --out "$WORKDIR/bevy-dry" > "$WORKDIR/bevy-dry.log"
assert_grep "Would link bevy-help docs from source repo" "$WORKDIR/bevy-dry.log"

echo "publish smoke tests passed"
