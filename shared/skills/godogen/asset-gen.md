# Asset Generator

Generate images and 3D models via Meshy AI API.

## Art Styles

| Style | Best for |
|-------|----------|
| `realistic` (default) | Realistic game assets, reference images, 3D model refs |
| `cartoon` | Stylized characters, cartoon props |
| `anime` | Anime-style characters and backgrounds |
| `pixel-art` | Retro game sprites and tiles |
| `voxel` | Minecraft-style objects |
| `clay` | Soft, rounded, clay-mation look |

## CLI Reference

Tools live at `${GODOGEN_SKILL_DIR}/tools/`. Run from the project root.

Keep runtime-loaded outputs under `assets/`. Put review-only references, scratch crops, and other non-runtime artifacts outside `assets/` unless the game actually loads them.

### Generate image (3-9 credits)

```bash
python3 ${GODOGEN_SKILL_DIR}/tools/asset_gen.py image \
  --prompt "the full prompt" -o assets/img/car.png
```

`--art-style` (default `realistic`): `realistic`, `cartoon`, `anime`, `pixel-art`, `voxel`, `clay`
`--size` (default `1024x1024`): `512x512` (3cr), `1024x1024` (5cr), `1024x1536` (7cr), `1536x1024` (7cr), `1536x1536` (9cr)

Typical combos:
- `--art-style realistic --size 1024x1024` — reference images, 3D refs (5cr)
- `--art-style cartoon --size 1536x1536` — stylized backgrounds (9cr)
- `--art-style pixel-art --size 512x512` — retro sprites (3cr)

### Image-to-image edit (3-9 credits)

Feed a reference image and prompt for changes:

```bash
python3 ${GODOGEN_SKILL_DIR}/tools/asset_gen.py image \
  --prompt "different color, red instead of blue" \
  --image assets/img/car_ref.png \
  --strength 0.6 -o assets/img/car_red.png
```

`--strength` (0-1, default 0.6): how much to change. Lower = closer to original.

### Remove background

Read `${GODOGEN_SKILL_DIR}/rembg.md` for full guide: CLI, prompting strategy, troubleshooting, batch mode.

### Generate animated sprite

Workflow: reference → pose frame → extract frames → loop trim → rembg.

**Step 1: Reference image (5 credits)**

```bash
python3 ${GODOGEN_SKILL_DIR}/tools/asset_gen.py image \
  --art-style realistic --size 1024x1024 \
  --prompt "knight in armor, neutral standing pose, facing right, solid dark-green background" \
  -o assets/img/knight_ref.png
```

**Step 2: Pose frame via image-to-image (5 credits)**

```bash
python3 ${GODOGEN_SKILL_DIR}/tools/asset_gen.py image \
  --art-style realistic \
  --prompt "walking to the right, mid-stride pose, side view, solid dark-green background" \
  --image assets/img/knight_ref.png \
  --strength 0.7 -o assets/img/knight_walk_pose.png
```

**Step 3: Extract frames from a video**

If you have a video source, extract frames:
```bash
mkdir -p assets/video/knight_walk_frames
ffmpeg -i assets/video/knight_walk.mp4 -vsync 0 assets/video/knight_walk_frames/%04d.png
```

**Step 4: Loop trim (looping animations only)**

```bash
python3 ${GODOGEN_SKILL_DIR}/tools/find_loop_frame.py assets/video/knight_walk_frames/
```

Output: `{"loop_frame": 54, "similarity": 0.9983, "window": 7, "total_frames": 73}`

**Step 5: Batch background removal**

```bash
python3 ${GODOGEN_SKILL_DIR}/tools/rembg_matting.py \
  --batch assets/video/knight_walk_frames/ \
  -o assets/img/knight_walk/
```

### Generate 3D model from text (30 credits)

Preview + refine pipeline:

```bash
python3 ${GODOGEN_SKILL_DIR}/tools/asset_gen.py glb \
  --prompt "red sports car, detailed exterior" -o assets/glb/car.glb
```

`--art-style` (default `realistic`): same options as image
`--face-count` (default `30000`): target polygon count for the refined model

### Generate 3D model from image (30 credits)

```bash
python3 ${GODOGEN_SKILL_DIR}/tools/asset_gen.py glb \
  --image assets/img/car.png -o assets/glb/car.glb
```

Writes a `<output>.meshy.json` sidecar with task ids — consumed by `rig` and `animate`.

### Rig a character (5 credits)

```bash
python3 ${GODOGEN_SKILL_DIR}/tools/asset_gen.py rig \
  --model assets/glb/knight.glb -o assets/glb/knight_rigged.glb
```

### Animate a rigged character (3 credits per clip)

```bash
python3 ${GODOGEN_SKILL_DIR}/tools/asset_gen.py animate \
  --rigged assets/glb/knight_rigged.glb \
  --animation walk \
  -o assets/glb/knight_walk.glb
```

Common animations: `walk`, `run`, `idle`, `dance`, `jump`, `attack`, `die`, `sit`, `wave`

Each call is a separate 3-credit task. For a character with walk + idle + attack, run `animate` three times.

### Retexture a model (10 credits)

```bash
python3 ${GODOGEN_SKILL_DIR}/tools/asset_gen.py retexture \
  --model assets/glb/car.glb \
  --prompt "rusted metal, weathered paint, dirt" \
  -o assets/glb/car_rusty.glb
```

### Meshy operational quirks

- Jobs routinely take 1-3 minutes for 3D generation. Let the default timeout run.
- A timeout does **not** mean the job failed. The task id is persisted in `<output>.meshy.json`. Do **not** resubmit — that double-charges.
- Resume the stalled task with no extra cost:
  ```bash
  python3 ${GODOGEN_SKILL_DIR}/tools/asset_gen.py resume -o assets/glb/car.glb
  ```
  Safe to re-run — it no-ops when the sidecar reports `status: "complete"`.

### Set budget

```bash
python3 ${GODOGEN_SKILL_DIR}/tools/asset_gen.py set_budget 500
```

Sets the generation budget to 500 credits. CRITICAL: only call once at the start, and only when the user explicitly provides a budget.

### Check balance

```bash
python3 ${GODOGEN_SKILL_DIR}/tools/asset_gen.py balance
```

### Output format

JSON to stdout: `{"ok": true, "path": "assets/img/car.png", "cost_credits": 5}`

On failure: `{"ok": false, "error": "...", "cost_credits": 0}`

Progress and API client output goes to stderr. **Redirect stderr to a temp file** to keep context clean — read it only on failure:
```bash
_log=$(mktemp)
result=$(python3 ${GODOGEN_SKILL_DIR}/tools/asset_gen.py image --prompt "..." -o path.png 2>"$_log") || tail -20 "$_log"
```

## Cost Table

| Operation | Cost | Notes |
|-----------|------|-------|
| Image 512x512 | 3 credits | Small refs, quick tests |
| Image 1024x1024 | 5 credits | Standard images, references |
| Image 1024x1536 or 1536x1024 | 7 credits | Portrait or landscape |
| Image 1536x1536 | 9 credits | Large images |
| 3D model (text or image) | 30 credits | Preview (20cr) + refine (10cr) |
| Rig | 5 credits | Per character |
| Animate | 3 credits | Per animation clip |
| Retexture | 10 credits | Per model |

A full 3D asset (5cr image + 30cr GLB) costs 35 credits. A rigged character with walk/idle/attack is 35 + 5 rig + 3x3 animate = 49 credits. A texture is 5 credits. A background is 5-9 credits.

## Image Resolution

Use the full generation resolution — don't downscale for aesthetic reasons.
- `512x512`: quick tests, pixel art, small sprites
- `1024x1024` (default): textures, sprites, 3D references, character refs
- `1024x1536` / `1536x1024`: portrait/landscape backgrounds
- `1536x1536`: large game maps, panoramic backgrounds

### Small sprites problem

Minimum generation resolution is 512x512. A 512px image downscaled to 64px or even 128px loses fine detail and looks muddy. Mitigations:

1. **Avoid tiny display sizes.** Design game elements at 128px+ where possible.
2. **Generate a kit image** — put multiple objects on one 1024x1024 image and crop the regions you need.
3. **Prompt for bold, simple forms.** Thick outlines, flat colors, minimal fine detail.

## What to Generate — Cheatsheet

For any asset needing transparency, read `${GODOGEN_SKILL_DIR}/rembg.md` first.

### Background / large scenic image (5-9 credits)

```
{description in the art style}. {composition instructions}.
```
`image --prompt "..." --size 1536x1536 -o path.png`

Use `--art-style` to match the game aesthetic. No post-processing — use as-is.

### Texture (5 credits)

```
{name}, {description}. Top-down view, uniform lighting, no shadows, seamless tileable texture, suitable for game engine tiling, clean edges.
```
`image --prompt "..." -o path.png`

No background removal — the entire image IS the texture.

### Single object / sprite

**Simple objects** (5cr) — props, items, icons:
```
{name}, {description}. Centered on a solid {bg_color} background.
```
`image --prompt "..." -o path.png`

**Character design** (5cr):
```
{name}, {description}. Centered on a solid {bg_color} background.
```
`image --prompt "..." -o path.png`

**Variant from reference** (uses `--image`):
```
{what to change: different angle, pose, color, etc.}
```
`image --prompt "..." --image path_ref.png -o path_variant.png`

### Item kit (5cr for 4 items)

Generate multiple objects in one image, then slice:

```
{item1}, {item2}, {item3}, {item4}. 2x2 grid layout, each item centered in its cell, solid {bg_color} background.
```
`image --prompt "..." -o path_grid.png`

Slice:
```bash
python3 ${GODOGEN_SKILL_DIR}/tools/grid_slice.py path_grid.png \
  -o assets/img/items/ --grid 2x2 --names "sword,shield,potion,helm"
```

### 3D model (35 credits total: 5cr image + 30cr GLB)

Reference image first, then convert:

```
3D model reference of {name}. {description}. 3/4 front elevated camera angle, solid white background, soft diffused studio lighting, matte material finish, single centered subject, no shadows on background.
```
`image --prompt "..." -o path.png`

Then: `glb --image ... -o ...` — do NOT remove the background; Meshy needs the solid bg for clean separation.

### Animated sprite

Full workflow (ref → pose → frames → loop trim → rembg) is in CLI Reference above.

## Visual Pitfalls

Image generators have poor spatial understanding. Verify carefully.

### Direction and orientation

Generators cannot reliably distinguish left vs right facing.

**Solution:** Generate one direction only, then flip horizontally at runtime.

### Size consistency

When mixing assets of different source sizes, resize everything to the smallest source size.

```bash
magick identify input.png
magick input.png -resize 720x720 -filter Lanczos output.png
magick input.png -flop output.png
```

## Tips

- **Image-to-image prompting**: when `--image` is provided, the model sees the reference. Don't re-describe the object — focus the prompt on what's different.
- Generate multiple images in parallel via multiple Bash calls.
- Always review generated PNGs before GLB conversion — read each image and check: centered? complete? clean background?
- Convert approved images to GLBs in parallel.
