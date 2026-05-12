# GDScript Mode

Use this file only when the user explicitly requests GDScript, asks to avoid C#/.NET, or the existing Godot project is already GDScript. C# remains the default for new Godot projects unless the user chooses otherwise.

## Language Decision

- Fresh Godot project, no language specified -> use C#.
- User asks for GDScript, `.gd` scripts, no .NET, or standard Godot -> use GDScript.
- Existing project has `.gd` scripts and no `.csproj` -> keep GDScript.
- Existing project has `.csproj` and `.cs` scripts -> keep C# unless the user explicitly asks to migrate.
- Do not mix C# and GDScript in one project unless the user explicitly asks for a mixed-language project.

Record the chosen language in `STRUCTURE.md`:

```markdown
## Godot Script Language
GDScript
```

## Scaffold Overrides

When using GDScript, apply these overrides to `scaffold.md`:

- Check `godot --version`; do not require `dotnet --version`.
- Do not write `.csproj`.
- Do not add a `[dotnet]` section to `project.godot`.
- Runtime scripts live under `scripts/*.gd`.
- Scene builder scripts live under `scenes/build_*.gd`.
- Test and capture scripts live under `test/*.gd`.
- Autoload entries point to `.gd` files, for example `GameManager="*res://scripts/game_manager.gd"`.
- Validate scripts with `godot --headless --check-only --script path/to/script.gd` where useful, then validate the project with `godot --headless --quit`.

Script stub shape:

```gdscript
extends CharacterBody3D
class_name PlayerController

signal died
signal scored

@export var speed: float = 7.0
@export var jump_velocity: float = 4.5

func _ready() -> void:
    pass

func _physics_process(delta: float) -> void:
    pass

func _on_hurt_area_entered(area: Area3D) -> void:
    pass
```

Prefer explicit type annotations. Avoid `:=` when the expression comes from `load()`, `preload()`, `instantiate()`, `get_node()`, array/dictionary access, or math helpers such as `clamp`, `lerp`, `min`, and `max`.

## Scene Generation Overrides

When using GDScript, apply these overrides to `scene-generation.md`:

- Use GDScript `SceneTree` scripts for scene builders.
- Save generated scenes with `ResourceSaver.save(packed_scene, output_path)`.
- Use `load("res://scripts/player_controller.gd")` for script attachment.
- There is no C# wrapper disposal issue after `set_script()`.
- Builder filenames should be snake_case, for example `scenes/build_player.gd`.

Minimal builder shape:

```gdscript
extends SceneTree

func _initialize() -> void:
    var root := CharacterBody3D.new()
    root.name = "Player"

    root.set_script(load("res://scripts/player_controller.gd"))

    var packed := PackedScene.new()
    var result := packed.pack(root)
    if result != OK:
        push_error("pack failed: %s" % result)
        quit(1)
        return

    result = ResourceSaver.save(packed, "res://scenes/player.tscn")
    if result != OK:
        push_error("save failed: %s" % result)
        quit(1)
        return

    quit(0)
```

Run builders in dependency order:

```bash
timeout 60 godot --headless --script scenes/build_player.gd
```

## Task Execution Overrides

When using GDScript, apply these overrides to `task-execution.md`:

- Replace `dotnet build` with targeted GDScript parse checks plus Godot project validation.
- Run `godot --headless --import` after asset changes.
- Run `godot --headless --quit` after script and scene changes.
- Use the `godot-api` skill for GDScript syntax and API names, not C# binding names.

Default loop:

1. Read `STRUCTURE.md`, current `.gd` files, scenes, `gdscript-mode.md`, `scene-generation.md`, `test-harness.md`, and `quirks.md`.
2. Import changed assets with `timeout 60 godot --headless --import 2>&1`.
3. Generate or update GDScript scene builders, then run them in the build order from `STRUCTURE.md`.
4. Write runtime `.gd` scripts.
5. For changed scripts, run `timeout 60 godot --headless --check-only --script path/to/script.gd 2>&1` when practical.
6. Validate the project with `timeout 60 godot --headless --quit 2>&1`.
7. Run capture through `capture.md`, using `.gd` test scripts.

Stop conditions:

- Relevant `.gd` scripts pass parse checks where practical.
- `godot --headless --quit` passes without actionable errors.
- Changed assets have been imported.
- A fresh `screenshots/result/{N}/` proof bundle exists when final media is required.
- `STRUCTURE.md` records GDScript and matches the shipped project.

## Capture Overrides

When using GDScript, apply these overrides to `capture.md` and `test-harness.md`:

- Write `test/capture_task.gd` and `test/presentation.gd`.
- Use `_initialize()` and `_process(delta: float) -> bool` on `SceneTree` scripts.
- Do not run `dotnet build`.
- Run capture commands with `--script test/presentation.gd`.

Minimal presentation script:

```gdscript
extends SceneTree

var frames := 0
var scene: Node

func _initialize() -> void:
    scene = load("res://scenes/main.tscn").instantiate()
    root.add_child(scene)

func _process(delta: float) -> bool:
    frames += 1
    return false
```

The movie writer handles exit through `--quit-after`; do not call `quit()` from presentation scripts unless the test is intentionally short.
