"""Meshy AI API client.

Docs: https://docs.meshy.ai

Provides image generation, 3D model generation, rigging, and animation
via the Meshy REST API.
"""

import os
import time
from pathlib import Path

import requests

API_BASE = "https://api.meshy.ai/v1"


def get_api_key() -> str:
    key = os.environ.get("MESHY_API_KEY")
    if not key:
        raise ValueError("MESHY_API_KEY environment variable not set")
    return key


def _headers() -> dict:
    return {"Authorization": f"Bearer {get_api_key()}", "Content-Type": "application/json"}


def _headers_upload() -> dict:
    return {"Authorization": f"Bearer {get_api_key()}"}


def upload_image(image_path: Path) -> str:
    with open(image_path, "rb") as f:
        files = {"file": (image_path.name, f, "image/png")}
        resp = requests.post(
            f"{API_BASE}/upload",
            headers=_headers_upload(),
            files=files,
        )
    resp.raise_for_status()
    return resp.json()["url"]


def _submit_task(endpoint: str, payload: dict) -> str:
    resp = requests.post(f"{API_BASE}/{endpoint}", headers=_headers(), json=payload)
    if not resp.ok:
        raise RuntimeError(f"Meshy task submit failed: HTTP {resp.status_code}: {resp.text}")
    return resp.json()["result"]


def create_text_to_3d_task(
    prompt: str,
    *,
    art_style: str = "realistic",
    negative_prompt: str = "",
    mode: str = "preview",
) -> str:
    payload = {
        "prompt": prompt,
        "art_style": art_style,
        "negative_prompt": negative_prompt,
        "mode": mode,
    }
    return _submit_task("text-to-3d", payload)


def create_image_to_3d_task(
    image_url: str,
    *,
    art_style: str = "realistic",
    mode: str = "preview",
) -> str:
    payload = {
        "image_url": image_url,
        "art_style": art_style,
        "mode": mode,
    }
    return _submit_task("image-to-3d", payload)


def refine_3d_task(
    preview_task_id: str,
    *,
    texture_richness: int = 0,
    topology: str = "triangle",
    target_face_count: int = 30000,
) -> str:
    payload = {
        "mode": "refine",
        "preview_task_id": preview_task_id,
        "texture_richness": texture_richness,
        "topology": topology,
        "target_face_count": target_face_count,
    }
    return _submit_task("text-to-3d", payload)


def create_text_to_image_task(
    prompt: str,
    *,
    art_style: str = "realistic",
    negative_prompt: str = "",
    image_size: str = "1024x1024",
) -> str:
    payload = {
        "prompt": prompt,
        "art_style": art_style,
        "negative_prompt": negative_prompt,
        "image_size": image_size,
    }
    return _submit_task("text-to-image", payload)


def create_image_to_image_task(
    image_url: str,
    *,
    prompt: str,
    art_style: str = "realistic",
    strength: float = 0.6,
) -> str:
    payload = {
        "image_url": image_url,
        "prompt": prompt,
        "art_style": art_style,
        "strength": strength,
    }
    return _submit_task("image-to-image", payload)


def create_rig_task(model_task_id: str) -> str:
    payload = {
        "model_task_id": model_task_id,
    }
    return _submit_task("rig", payload)


def create_animate_task(rig_task_id: str, animation: str) -> str:
    payload = {
        "rig_task_id": rig_task_id,
        "animation": animation,
    }
    return _submit_task("animate", payload)


def create_retexture_task(
    model_task_id: str,
    *,
    prompt: str,
    art_style: str = "realistic",
) -> str:
    payload = {
        "model_task_id": model_task_id,
        "prompt": prompt,
        "art_style": art_style,
    }
    return _submit_task("retexture", payload)


def poll_task(task_id: str, endpoint: str = "tasks", timeout: int = 600, interval: int = 5) -> dict:
    start = time.time()
    url = f"{API_BASE}/{endpoint}/{task_id}"
    while time.time() - start < timeout:
        resp = requests.get(url, headers=_headers_upload())
        resp.raise_for_status()
        data = resp.json()
        status = data.get("status")
        if status == "SUCCEEDED":
            return data
        if status in ("FAILED", "CANCELLED"):
            raise RuntimeError(f"Task {task_id} {status}: {data}")
        time.sleep(interval)
    raise TimeoutError(f"Task {task_id} timed out after {timeout}s")


def download_model(task_result: dict, output_path: Path) -> Path:
    model_urls = task_result.get("model_urls", {})
    url = model_urls.get("glb") or model_urls.get("obj") or model_urls.get("fbx")
    if not url:
        out = task_result.get("output", {})
        url = out.get("model_url") or out.get("url")
    if not url:
        raise ValueError(f"No model URL in result: {list(task_result.keys())}")
    resp = requests.get(url)
    resp.raise_for_status()
    output_path.write_bytes(resp.content)
    return output_path


def download_image(task_result: dict, output_path: Path) -> Path:
    url = None
    out = task_result.get("output", {})
    if isinstance(out, dict):
        url = out.get("image_url") or out.get("url")
    if not url:
        url = task_result.get("image_url")
    if not url:
        raise ValueError(f"No image URL in result: {list(task_result.keys())}")
    resp = requests.get(url)
    resp.raise_for_status()
    output_path.write_bytes(resp.content)
    return output_path
