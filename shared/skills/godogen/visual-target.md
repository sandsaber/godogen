# Visual Target

Generate a reference image of what the finished game looks like. Anchors art direction for scaffold, asset planner, and task agents.

## CLI

```bash
python3 ${GODOGEN_SKILL_DIR}/tools/asset_gen.py image \
  --prompt "{prompt}" \
  --art-style realistic --size 1024x1024 -o reference.png
```

## Prompt

Must look like an in-game screenshot, not concept art. Every distinct object visible here becomes an asset requirement. Prompt only elements you will actually build.

### Prompt rules

- **Enumerate every game object** — player character, each enemy type, obstacles, collectibles, projectiles, platforms, props. Name each with position and approximate size.
- **Reflect real technical constraints.** Tiling backgrounds, separate sprite layers, etc.
- **Don't prompt downgraded quality** ("lowpoly", "retro"). Prompt clean, sharp rendering.
- **Focus on the most important gameplay moment.**
- **Exclude what you won't build.** Volumetric lighting, motion blur, depth of field, complex reflections — skip unless actually implemented.
- **Show HUD/UI elements.** Health bar, score counter, minimap — include every UI element with position.

```
Screenshot of a {2D/3D} video game. {Camera: angle, distance, perspective}.
Game objects: {player — appearance, position, size}. {enemies — each type, position}. {obstacles}. {collectibles}.
Environment: {background layers}. {playfield surface}. {boundaries}.
HUD: {each UI element — type and screen position}.
{Art style, color palette}. Clean sharp digital rendering, game engine output.
```

## Output

`reference.png` — default to 1024x1024.

Write the art direction and chosen art style into `ASSETS.md`:

```markdown
# Assets

**Art direction:** <the art style description>
**Art style:** <meshy art-style for all generation>
```
