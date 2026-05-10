---
name: bevy-help
display_name: Bevy Help
short_description: Bevy APIs, examples, and implementation patterns
default_prompt: "Use bevy-help for any Bevy-related question, including API lookup, feature design, architecture, or implementation patterns."
allow_implicit_invocation: false
description: |
  Look up current Bevy engine APIs, crates, examples, and patterns. Use for any Bevy-related question, including API lookup, feature design, architecture, and implementation patterns.
---

# Bevy Help

Use this skill for any Bevy-related question, not just exact symbol lookup. It should be the default tool for Bevy API questions, feature design, architecture, and implementation-pattern questions. The local docs cache includes many examples that often provide the best pattern to copy. Keep answers targeted to the caller's question.

Single-version policy:

- Support the Bevy release installed in this skill's local docs cache.
- When the repo upgrades Bevy, update this skill forward and republish.
- Do not carry legacy compatibility guidance unless the caller explicitly asks about migration.
- If the project cannot be resolved to one current Bevy version, stop and ask.

This skill assumes the local docs cache is already installed. Do not try to install, refresh, or retarget it from inside this skill.

Required local paths:

- `${BEVY_HELP_SKILL_DIR}/docs/rustdoc/`
- `${BEVY_HELP_SKILL_DIR}/docs/bevy/`
- `${BEVY_HELP_SKILL_DIR}/docs/bevy-website/`

If any required path is missing or unreadable, stop with an error.

Resolve the installed docs release from `${BEVY_HELP_SKILL_DIR}/docs/bevy/`, then compare with the target project's Bevy dependency.

Lookup order:

1. `${BEVY_HELP_SKILL_DIR}/docs/rustdoc/`
2. `${BEVY_HELP_SKILL_DIR}/docs/bevy/` plus `examples/`
3. `${BEVY_HELP_SKILL_DIR}/docs/bevy-website/` Learn content
4. Small local notes in this skill, if any
5. Web fallback only when the caller explicitly asks for it or the local stack is unavailable

Use only the minimum source needed:

- Exact API or symbol names: rustdoc first
- "How do I do X?": examples first, then rustdoc
- Feature-design or architecture: examples, then Learn, then rustdoc
- Recommendation: examples, rustdoc, Learn
- Behavior or "why": crate source first, then rustdoc

Bevy-specific source traps:

- If behavior seems automatic, inspect component attributes such as `#[require(...)]` and `#[component(on_insert = ...)]` in crate source.
- Rustdoc is best for public names and signatures, but often hides internal reasons.
- Learn content is advisory. If it disagrees with examples or crate source, trust examples and source.

When answering:

- Start with the concrete answer, not version boilerplate.
- Name the exact files or pages you checked.
- Separate doc facts from inference.
- If you give code, use only symbols verified in current sources.

Mandatory action after every successful lookup:

- Append one short entry to `./.bevy-help.log` before returning. Create the file if it does not exist, always append.
- Record only: `requested`, `comment`, `result_files`
- Keep each entry short enough to scan later.

Do not dump whole rustdoc pages or enumerate large directories.
