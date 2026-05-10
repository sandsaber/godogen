#!/usr/bin/env python3
"""Asset Generator CLI - creates images and 3D models via Meshy AI.

Subcommands:
  image     Generate a PNG from a text prompt (3-9 credits)
  glb       Generate a 3D model from text or image, preview+refine (20-30 credits)
  rig       Add skeleton to a humanoid 3D model (5 credits)
  animate   Apply animation to a rigged model (3 credits)
  retexture Apply new texture to an existing model (10 credits)
  resume    Resume a timed-out Meshy job from its sidecar — no extra cost

Output: JSON to stdout. Progress to stderr.
"""

import argparse
import json
import sys
from pathlib import Path

import requests
from PIL import Image

from meshy import (
    create_animate_task,
    create_image_to_3d_task,
    create_image_to_image_task,
    create_rig_task,
    create_text_to_3d_task,
    create_text_to_image_task,
    create_retexture_task,
    download_image,
    download_model,
    poll_task,
    refine_3d_task,
    upload_image,
)

TOOLS_DIR = Path(__file__).parent
BUDGET_FILE = Path("assets/budget.json")

IMAGE_COSTS = {
    "512x512": 3,
    "1024x1024": 5,
    "1024x1536": 7,
    "1536x1024": 7,
    "1536x1536": 9,
}

TEXT_TO_3D_COST = 20
REFINE_COST = 10
RIG_COST = 5
ANIMATE_COST = 3
RETEXTURE_COST = 10

IMAGE_SIZES = list(IMAGE_COSTS.keys())
ART_STYLES = ["realistic", "cartoon", "anime", "pixel-art", "voxel", "clay"]


def _load_budget():
    if not BUDGET_FILE.exists():
        return None
    return json.loads(BUDGET_FILE.read_text())


def _spent_total(budget):
    return sum(v for entry in budget.get("log", []) for v in entry.values())


def check_budget(cost_credits: int):
    budget = _load_budget()
    if budget is None:
        return
    spent = _spent_total(budget)
    remaining = budget.get("budget_credits", 0) - spent
    if cost_credits > remaining:
        result_json(False, error=f"Budget exceeded: need {cost_credits} credits but only {remaining} remaining ({spent} of {budget['budget_credits']} spent)")
        sys.exit(1)


def record_spend(cost_credits: int, service: str):
    budget = _load_budget()
    if budget is None:
        return
    budget.setdefault("log", []).append({service: cost_credits})
    BUDGET_FILE.write_text(json.dumps(budget, indent=2) + "\n")


def result_json(ok: bool, path: str | None = None, cost_credits: int = 0, error: str | None = None):
    d = {"ok": ok, "cost_credits": cost_credits}
    if path:
        d["path"] = path
    if error:
        d["error"] = error
    print(json.dumps(d))


def _sidecar_path(output: Path) -> Path:
    return output.with_suffix(output.suffix + ".meshy.json")


def _write_sidecar(output: Path, data: dict) -> None:
    _sidecar_path(output).write_text(json.dumps(data, indent=2) + "\n")


def _read_sidecar(path: Path) -> dict:
    sc = _sidecar_path(path)
    if not sc.exists():
        raise FileNotFoundError(f"Sidecar not found: {sc}")
    return json.loads(sc.read_text())


def _resume_hint(output: Path) -> str:
    return f"Task still processing. Resume (no extra cost) with: asset_gen.py resume -o {output}"


def cmd_image(args):
    size = args.size
    if size not in IMAGE_COSTS:
        result_json(False, error=f"Unsupported size {size}. Use: {', '.join(IMAGE_SIZES)}")
        sys.exit(1)

    cost = IMAGE_COSTS[size]
    check_budget(cost)

    output = Path(args.output)
    output.parent.mkdir(parents=True, exist_ok=True)

    label = f"meshy {size} {args.art_style}"
    if args.image:
        label += " (image-to-image)"
    print(f"Generating image ({label})...", file=sys.stderr)

    try:
        if args.image:
            ref_path = Path(args.image)
            if not ref_path.exists():
                result_json(False, error=f"Reference image not found: {ref_path}")
                sys.exit(1)
            image_url = upload_image(ref_path)
            task_id = create_image_to_image_task(
                image_url,
                prompt=args.prompt,
                art_style=args.art_style,
                strength=args.strength,
            )
        else:
            task_id = create_text_to_image_task(
                args.prompt,
                art_style=args.art_style,
                image_size=size,
            )

        print(f"  task: {task_id}", file=sys.stderr)
        record_spend(cost, "meshy-image")
        result = poll_task(task_id)
        download_image(result, output)
    except TimeoutError as e:
        result_json(False, error=f"{e}. {_resume_hint(output)}", cost_credits=cost)
        sys.exit(1)
    except Exception as e:
        result_json(False, error=str(e))
        sys.exit(1)

    print(f"Saved: {output}", file=sys.stderr)
    result_json(True, path=str(output), cost_credits=cost)


def cmd_glb(args):
    cost = TEXT_TO_3D_COST + REFINE_COST
    check_budget(cost)

    output = Path(args.output)
    output.parent.mkdir(parents=True, exist_ok=True)

    sidecar = {
        "kind": "mesh",
        "status": "pending",
    }

    try:
        if args.image:
            image_path = Path(args.image)
            if not image_path.exists():
                result_json(False, error=f"Image not found: {image_path}")
                sys.exit(1)
            image_url = upload_image(image_path)
            print(f"Generating 3D model from image...", file=sys.stderr)
            preview_id = create_image_to_3d_task(
                image_url,
                art_style=args.art_style,
            )
        else:
            if not args.prompt:
                result_json(False, error="--prompt is required when not using --image")
                sys.exit(1)
            print(f"Generating 3D model from text...", file=sys.stderr)
            preview_id = create_text_to_3d_task(
                args.prompt,
                art_style=args.art_style,
            )

        print(f"  preview: {preview_id}", file=sys.stderr)
        sidecar["preview_task_id"] = preview_id
        sidecar["stage"] = "preview"
        _write_sidecar(output, sidecar)
        record_spend(TEXT_TO_3D_COST, "meshy-3d-preview")

        print(f"  polling preview...", file=sys.stderr)
        poll_task(preview_id)

        print(f"  refining...", file=sys.stderr)
        refine_id = refine_3d_task(
            preview_id,
            target_face_count=args.face_count,
        )
        print(f"  refine: {refine_id}", file=sys.stderr)
        record_spend(REFINE_COST, "meshy-3d-refine")
        sidecar["refine_task_id"] = refine_id
        sidecar["stage"] = "refine"
        _write_sidecar(output, sidecar)

        result = poll_task(refine_id)
        download_model(result, output)
    except TimeoutError as e:
        result_json(False, error=f"{e}. {_resume_hint(output)}", cost_credits=cost)
        sys.exit(1)
    except Exception as e:
        result_json(False, error=str(e))
        sys.exit(1)

    sidecar["status"] = "complete"
    _write_sidecar(output, sidecar)
    print(f"Saved: {output}", file=sys.stderr)
    result_json(True, path=str(output), cost_credits=cost)


def cmd_rig(args):
    model_path = Path(args.model)
    if not model_path.exists():
        result_json(False, error=f"Model not found: {model_path}")
        sys.exit(1)

    try:
        model_sidecar = _read_sidecar(model_path)
    except FileNotFoundError as e:
        result_json(False, error=str(e))
        sys.exit(1)

    preview_id = model_sidecar.get("preview_task_id")
    if not preview_id:
        result_json(False, error=f"No preview_task_id in sidecar for {model_path}")
        sys.exit(1)

    cost = RIG_COST
    check_budget(cost)

    output = Path(args.output)
    output.parent.mkdir(parents=True, exist_ok=True)

    print(f"Rigging model...", file=sys.stderr)

    sidecar = {
        "kind": "rig",
        "preview_task_id": preview_id,
        "status": "pending",
    }

    try:
        rig_id = create_rig_task(preview_id)
        print(f"  rig: {rig_id}", file=sys.stderr)
        record_spend(cost, "meshy-rig")
        sidecar["rig_task_id"] = rig_id
        _write_sidecar(output, sidecar)

        result = poll_task(rig_id)
        download_model(result, output)
    except TimeoutError as e:
        result_json(False, error=f"{e}. {_resume_hint(output)}", cost_credits=cost)
        sys.exit(1)
    except Exception as e:
        result_json(False, error=str(e))
        sys.exit(1)

    sidecar["status"] = "complete"
    _write_sidecar(output, sidecar)
    print(f"Saved: {output}", file=sys.stderr)
    result_json(True, path=str(output), cost_credits=cost)


def cmd_animate(args):
    rigged = Path(args.rigged)
    if not rigged.exists():
        result_json(False, error=f"Rigged model not found: {rigged}")
        sys.exit(1)

    try:
        rig_sidecar = _read_sidecar(rigged)
    except FileNotFoundError as e:
        result_json(False, error=str(e))
        sys.exit(1)

    rig_task_id = rig_sidecar.get("rig_task_id")
    if not rig_task_id:
        result_json(False, error=f"No rig_task_id in sidecar for {rigged}")
        sys.exit(1)

    cost = ANIMATE_COST
    check_budget(cost)

    output = Path(args.output)
    output.parent.mkdir(parents=True, exist_ok=True)

    print(f"Animating ({args.animation})...", file=sys.stderr)

    sidecar = {
        "kind": "anim",
        "rig_task_id": rig_task_id,
        "animation": args.animation,
        "status": "pending",
    }

    try:
        anim_id = create_animate_task(rig_task_id, args.animation)
        print(f"  animate: {anim_id}", file=sys.stderr)
        record_spend(cost, "meshy-animate")
        sidecar["animate_task_id"] = anim_id
        _write_sidecar(output, sidecar)

        result = poll_task(anim_id)
        download_model(result, output)
    except TimeoutError as e:
        result_json(False, error=f"{e}. {_resume_hint(output)}", cost_credits=cost)
        sys.exit(1)
    except Exception as e:
        result_json(False, error=str(e))
        sys.exit(1)

    sidecar["status"] = "complete"
    _write_sidecar(output, sidecar)
    print(f"Saved: {output}", file=sys.stderr)
    result_json(True, path=str(output), cost_credits=cost)


def cmd_retexture(args):
    model_path = Path(args.model)
    if not model_path.exists():
        result_json(False, error=f"Model not found: {model_path}")
        sys.exit(1)

    try:
        model_sidecar = _read_sidecar(model_path)
    except FileNotFoundError as e:
        result_json(False, error=str(e))
        sys.exit(1)

    preview_id = model_sidecar.get("preview_task_id")
    if not preview_id:
        result_json(False, error=f"No preview_task_id in sidecar for {model_path}")
        sys.exit(1)

    cost = RETEXTURE_COST
    check_budget(cost)

    output = Path(args.output)
    output.parent.mkdir(parents=True, exist_ok=True)

    print(f"Retexturing model...", file=sys.stderr)

    try:
        retex_id = create_retexture_task(
            preview_id,
            prompt=args.prompt,
            art_style=args.art_style,
        )
        print(f"  retexture: {retex_id}", file=sys.stderr)
        record_spend(cost, "meshy-retexture")

        result = poll_task(retex_id)
        download_model(result, output)
    except TimeoutError as e:
        result_json(False, error=f"{e}. {_resume_hint(output)}", cost_credits=cost)
        sys.exit(1)
    except Exception as e:
        result_json(False, error=str(e))
        sys.exit(1)

    print(f"Saved: {output}", file=sys.stderr)
    result_json(True, path=str(output), cost_credits=cost)


def cmd_resume(args):
    output = Path(args.output)
    try:
        sidecar = _read_sidecar(output)
    except FileNotFoundError as e:
        result_json(False, error=str(e))
        sys.exit(1)

    if sidecar.get("status") == "complete":
        print(f"Already complete: {output}", file=sys.stderr)
        result_json(True, path=str(output), cost_credits=0)
        return

    output.parent.mkdir(parents=True, exist_ok=True)

    try:
        stage = sidecar.get("stage")

        if stage == "preview":
            preview_id = sidecar["preview_task_id"]
            print(f"  resuming preview: {preview_id}", file=sys.stderr)
            poll_task(preview_id)

            refine_id = refine_3d_task(preview_id)
            print(f"  refine: {refine_id}", file=sys.stderr)
            sidecar["refine_task_id"] = refine_id
            sidecar["stage"] = "refine"
            _write_sidecar(output, sidecar)
            stage = "refine"

        if stage == "refine":
            refine_id = sidecar["refine_task_id"]
            print(f"  resuming refine: {refine_id}", file=sys.stderr)
            result = poll_task(refine_id)
            download_model(result, output)

        elif stage == "rig":
            rig_id = sidecar["rig_task_id"]
            print(f"  resuming rig: {rig_id}", file=sys.stderr)
            result = poll_task(rig_id)
            download_model(result, output)

        elif stage == "animate":
            anim_id = sidecar["animate_task_id"]
            print(f"  resuming animate: {anim_id}", file=sys.stderr)
            result = poll_task(anim_id)
            download_model(result, output)

        else:
            result_json(False, error=f"Unknown stage: {stage}")
            sys.exit(1)

    except TimeoutError as e:
        result_json(False, error=f"{e}. Task still processing; retry resume.", cost_credits=0)
        sys.exit(1)
    except Exception as e:
        result_json(False, error=str(e))
        sys.exit(1)

    sidecar["status"] = "complete"
    _write_sidecar(output, sidecar)
    print(f"Saved: {output}", file=sys.stderr)
    result_json(True, path=str(output), cost_credits=0)


def cmd_set_budget(args):
    BUDGET_FILE.parent.mkdir(parents=True, exist_ok=True)
    budget = {"budget_credits": args.credits, "log": []}
    if BUDGET_FILE.exists():
        old = json.loads(BUDGET_FILE.read_text())
        budget["log"] = old.get("log", [])
    BUDGET_FILE.write_text(json.dumps(budget, indent=2) + "\n")
    spent = _spent_total(budget)
    print(json.dumps({"ok": True, "budget_credits": args.credits, "spent_credits": spent, "remaining_credits": args.credits - spent}))


def cmd_check_balance(args):
    from meshy import get_api_key, _headers_upload
    resp = requests.get("https://api.meshy.ai/v1/balance", headers={"Authorization": f"Bearer {get_api_key()}"})
    resp.raise_for_status()
    print(json.dumps(resp.json()))


def main():
    parser = argparse.ArgumentParser(description="Asset Generator — images and 3D models via Meshy AI")
    sub = parser.add_subparsers(dest="command", required=True)

    p_img = sub.add_parser("image", help="Generate a PNG image from text (3-9 credits)")
    p_img.add_argument("--prompt", required=True, help="Image generation prompt")
    p_img.add_argument("--art-style", choices=ART_STYLES, default="realistic", help="Art style. Default: realistic")
    p_img.add_argument("--size", choices=IMAGE_SIZES, default="1024x1024", help="Image size. Default: 1024x1024")
    p_img.add_argument("--image", default=None, help="Reference image for image-to-image")
    p_img.add_argument("--strength", type=float, default=0.6, help="Image-to-image strength (0-1). Default: 0.6")
    p_img.add_argument("-o", "--output", required=True, help="Output PNG path")
    p_img.set_defaults(func=cmd_image)

    p_glb = sub.add_parser("glb", help="Generate 3D model from text or image (20-30 credits)")
    p_glb.add_argument("--prompt", default=None, help="Text prompt for 3D model (required if not using --image)")
    p_glb.add_argument("--image", default=None, help="Input image for image-to-3D")
    p_glb.add_argument("--art-style", choices=ART_STYLES, default="realistic", help="Art style. Default: realistic")
    p_glb.add_argument("--face-count", type=int, default=30000, help="Target face count. Default: 30000")
    p_glb.add_argument("-o", "--output", required=True, help="Output GLB path")
    p_glb.set_defaults(func=cmd_glb)

    p_rig = sub.add_parser("rig", help="Add skeleton to humanoid 3D model (5 credits)")
    p_rig.add_argument("--model", required=True, help="GLB file produced by `glb`")
    p_rig.add_argument("-o", "--output", required=True, help="Output rigged GLB path")
    p_rig.set_defaults(func=cmd_rig)

    p_anim = sub.add_parser("animate", help="Apply animation to rigged model (3 credits)")
    p_anim.add_argument("--rigged", required=True, help="Rigged GLB produced by `rig`")
    p_anim.add_argument("--animation", required=True, help="Animation name (e.g. walk, run, idle, dance)")
    p_anim.add_argument("-o", "--output", required=True, help="Output animated GLB path")
    p_anim.set_defaults(func=cmd_animate)

    p_retex = sub.add_parser("retexture", help="Apply new texture to existing model (10 credits)")
    p_retex.add_argument("--model", required=True, help="GLB file produced by `glb`")
    p_retex.add_argument("--prompt", required=True, help="Texture prompt")
    p_retex.add_argument("--art-style", choices=ART_STYLES, default="realistic", help="Art style. Default: realistic")
    p_retex.add_argument("-o", "--output", required=True, help="Output GLB path")
    p_retex.set_defaults(func=cmd_retexture)

    p_res = sub.add_parser("resume", help="Resume a timed-out Meshy job from its sidecar (no extra cost)")
    p_res.add_argument("-o", "--output", required=True, help="Output path whose .meshy.json sidecar holds the pending task id(s)")
    p_res.set_defaults(func=cmd_resume)

    p_budget = sub.add_parser("set_budget", help="Set the asset generation budget in credits")
    p_budget.add_argument("credits", type=int, help="Budget in credits")
    p_budget.set_defaults(func=cmd_set_budget)

    p_bal = sub.add_parser("balance", help="Check Meshy API balance")
    p_bal.set_defaults(func=cmd_check_balance)

    args = parser.parse_args()
    args.func(args)


if __name__ == "__main__":
    main()
