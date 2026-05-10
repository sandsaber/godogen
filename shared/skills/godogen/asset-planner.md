# Asset Planner

Analyze a game, decide what assets it needs, and generate them within a budget.

## Input

The caller provides:
- `budget_credits` — total budget (or remaining budget for iterations)
- For iterations: a specific task description (e.g. "regenerate car model" or "add missing explosion sprite")

## Setup

Read `${GODOGEN_SKILL_DIR}/asset-gen.md` for CLI reference and prompt templates.

## Workflow

### 1. Analyze inputs → identify visual elements

Read `reference.png` — understand the visual composition: objects, proportions, environment, foreground vs background layers.

Read `STRUCTURE.md` (especially **Asset Hints**) and `PLAN.md` (especially **Assets needed** per task). Cross-reference both with the reference image:
- **3D models**: characters, vehicles, key props, buildings — anything that needs geometry
- **Textures**: ground surfaces, walls, UI backgrounds — flat materials that tile
- **Backgrounds**: sky panoramas, parallax layers, title screens — use `--size 1536x1536` or `--size 1536x1024` and appropriate `--art-style`
- **Animated sprites**: characters or objects with multiple actions — plan the motion graph

Keep runtime-loaded outputs under `assets/`.

### 2. Prioritize and budget

Each asset costs:
- Texture / simple sprite: 5 credits
- Character / reference / 3D ref: 5 credits
- Background: 5-9 credits
- 3D model: 35 credits (5cr image + 30cr GLB)

Animated sprites: reference (5cr) + pose frames via image-to-image (5cr each).

Prioritize by visual impact. Cut low-impact assets first if budget is tight. Reserve ~10% for retries.

### 3. Understand art direction

Read **Art direction** from `ASSETS.md`. Use it as context when crafting prompts — do NOT mechanically prepend it. Different asset types need different prompting:
- **Textures** often need no style language — describe material and tiling
- **3D model references** need clean studio lighting and neutral presentation
- **Backgrounds/panoramas** benefit most from art direction language
- **Sprites** may need some style cues adapted to the subject

#### Art style selection

Use `--art-style` to match the game aesthetic. Pick one style and use it consistently across all assets in a project:
- `realistic` — realistic games, references, 3D model inputs
- `cartoon` — stylized games, cartoon characters and props
- `pixel-art` — retro games
- `anime` — anime-styled games
- `voxel` — Minecraft-style
- `clay` — soft, rounded style

#### Using image references for consistency

Feed a generated image as `--image` input when subsequent assets need to match it. Common patterns:
- **Style family** — one hero asset as input for the rest of the set
- **Multiple views** — front view as input → side, back, 3/4 angle
- **Variants** — base object as input → recolors, damaged versions

Generate anchors first, review, then fan out derivatives in parallel.

### 4. Generate images, review, convert to 3D

Use the asset-gen instructions for prompt templates and CLI commands. Generate all images in parallel, review each PNG, regenerate bad ones (max 1 retry), then convert approved 3D images to GLBs in parallel.

For animated sprites, generate in dependency order — root actions first (parallel), extract frames and trim loops, then chained actions from predecessors' last frames (parallel).

#### Common Mistakes

- **Detailed image shrunk to a tile** — use kit images or prompt for bold forms
- **Tiling texture for a unique background** — use `--size 1536x1536` instead
- **Image where procedural drawing works** — pure geometric primitives (solid rectangles, circles) should be drawn in code. Anything with texture or artistic style should use generated assets.
- **Stretching one texture over a large area** — use tileable textures or generate at higher resolution

### 5. Write ASSETS.md

Every asset row **must** include a **Size** column — the intended in-game dimensions.

- **3D models:** target size in meters
- **Textures:** tile size in meters
- **Backgrounds:** pixel dimensions to display at
- **Sprites:** display size in pixels

```markdown
# Assets

**Art direction:** <the art direction string>
**Art style:** <meshy art-style used for generation>

## 3D Models

| Name | Description | Size | Image | GLB |
|------|-------------|------|-------|-----|
| car | sedan with spoiler | 4m long | assets/img/car.png | assets/glb/car.glb |

## Textures

| Name | Description | Size | Image |
|------|-------------|------|-------|
| grass | green meadow | 2m tile | assets/img/grass.png |

## Backgrounds

| Name | Description | Size | Image |
|------|-------------|------|-------|
| forest_bg | dense forest panorama | 1920x1080, fullscreen | assets/img/forest_bg.png |

## Sprites

| Name | Description | Size | Image |
|------|-------------|------|-------|
| coin | spinning gold coin | 64x64 px | assets/img/coin.png |

## Animated Sprites

### knight

**Reference:** `assets/img/knight_ref.png`
**Transitions:** idle <-> walk, walk -> attack -> idle

| Action | Type | Size | Duration | Start From | Frames Dir |
|--------|------|------|----------|------------|------------|
| idle | loop | 128x128 px | 2s | ref | assets/img/knight_idle/ |
| walk | loop | 128x128 px | 3s | ref | assets/img/knight_walk/ |
| attack | one-shot | 128x128 px | 2s | walk | assets/img/knight_attack/ |
```

### 6. Update PLAN.md with asset assignments

After generating assets, add concrete asset assignments to each task:

```markdown
- **Assets:**
  - `car` GLB model (`assets/glb/car.glb`) — scale to 4m long
  - `grass` texture (`assets/img/grass.png`) — tile every 2m via UV scale
```
