# Multiview to 3D Model — P Series

**Base URL:** `https://openapi.tripo3d.ai/v3`

**Endpoint:** `POST /generation/multiview-to-model`

Generate a 3D model from multiview images using P Series. Optimized for low-poly output with clean topology.

## Request Parameters

### inputs

- **Type:** object[] | string[]
- **Required:** Required

**Three formats — use exactly one, do not mix.**

- **view-key (recommended)** — Array of objects; each object has exactly one key among `front`, `left`, `back`, `right`. Values may be a URL, `file_token`, or nested `{url}` / `{file_token}` / `{object:{bucket,key}}`. Order does not matter; the server canonicalizes to **[front, left, back, right]**.
- **legacy positional** — Exactly 4 strings in order **[front, left, back, right]**. Use an empty string `""` to skip a view.
- **task_id** — Pass the ID of a previous Image to Multiview or Edit Multiview task to reuse its 4-view output. Only `[{"task_id":"<uuid>"}]` (single-element array) is accepted — do not mix with view-key or positional slots. The source task must be `success` with type `generate_multiview_image` or `edit_multiview_image`.
For view-key and legacy positional, each image value accepts:


- file_token — Upload an image via the File Upload API first, then pass the returned token.
Example: `file_abc123`
- URL — A publicly accessible direct link to an image.
Example: `https://example.com/front.png`



- The front view **cannot be omitted**. You may omit other views, but at least 2 images are required.
- All images should depict the same object under consistent lighting.
- Formats: `PNG`, `JPEG`, `WebP`
- Recommended resolution: at least **256 × 256 px**.

### model

- **Type:** string
- **Required:** Required

P Series model version.
- `P1-20260311` — optimized for low-poly generation.
- `P2-20260801` — next-gen P Series with quad output support. Preview

### texture_alignment

- **Type:** string
- **Required:** Optional
- **Default:** `original_image`

Texture alignment priority.
- `original_image` — prioritize matching the input image colors.
- `geometry` — prioritize matching the generated geometry.

### orientation

- **Type:** string
- **Required:** Optional
- **Default:** `default`

Model orientation.
- `default` — automatic orientation.
- `align_image` — align the model to the input image viewpoint.
Only effective when `texture` is `true`. Has no effect without texture enabled.

### model_seed

- **Type:** integer
- **Required:** Optional

Random seed for geometry generation. Using the same seed with the same input will produce an identical 3D mesh. If not set, a random seed is used each time.
### face_limit

- **Type:** integer
- **Required:** Optional

Maximum polycount for the output mesh.


- `P1-20260311`: **50 – 20,000**
- `P2-20260801` triangle: **48 – 50,000**; with `quad=true`: **48 – 25,000**
- If omitted, adaptively determined.
For best quality: simple models start from **150** faces, complex models start from **250** faces. Lower values may result in poor generation quality.

### texture

- **Type:** boolean
- **Required:** Optional
- **Default:** `true`

Whether to generate texture maps for the model. Set to false to get a bare geometry without any textures. Default is true.
### pbr

- **Type:** boolean
- **Required:** Optional
- **Default:** `true`

Enable PBR material maps (`base_color`, `metallic`, `roughness`, `normal`).When `pbr` is set to `true`, `texture` will be automatically forced to `true`.

### texture_seed

- **Type:** integer
- **Required:** Optional

Random seed for texture generation. Using the same seed will produce identical textures. If not set, a random seed will be used each time. To get a model with different textures but the same geometry, keep model_seed unchanged and vary texture_seed.
### texture_quality

- **Type:** string
- **Required:** Optional
- **Default:** `standard`

Texture quality level.
- `fast` — the fastest generation, trading texture detail for speed. Output texture size is identical to `standard`. Requires texture `v3.5-20260815`; costs the same as `standard`.
- `standard` — balanced quality and speed.
- `detailed` — higher fidelity, slower generation.
- `extreme` — 8K textures, highest fidelity. Costs additional credits compared to detailed.


`fast` is only available on texture `v3.5-20260815`. On the generation endpoints that means `texture_version` must be set to it; on `/v3/models/texture` it means `model`. Any other texture version returns `1004` rather than silently falling back to `standard`.
### texture_version

- **Type:** string
- **Required:** Optional

Pins the texture model independently of the geometry `model`.
- `v3.5-20260815` — newest texture model. Required for `texture_quality=fast` and `delight`.
- `v3.0-20250812` — default for `v3.x` and P-series geometry.
- `v2.5-20250123` — default for `v2.5-20250123` geometry.
If omitted, it is derived from the geometry `model` as listed above.
### delight

- **Type:** boolean
- **Required:** Optional
- **Default:** `true`

Removes baked-in lighting from the reference image before texturing. Set `false` to keep the original shading. Only the `v3.5-20260815` texture model reads this; older texture versions ignore it.
### auto_size

- **Type:** boolean
- **Required:** Optional
- **Default:** `false`

Whether to automatically scale the generated model to real-world dimensions. When enabled, the model size will be in meters, suitable for AR/VR or game engine scenes. Default is false.
### export_uv

- **Type:** boolean
- **Required:** Optional
- **Default:** `true`

Controls UV unwrapping. Set `false` for faster generation and smaller file size.
### export_orientation

- **Type:** string
- **Required:** Optional
- **Default:** `+x`

Export orientation (forward axis).
- `+x` — default, X-forward.
- `-x` — negative X-forward.
- `-y` — negative Y-forward.
- `+y` — Y-forward.



- Applies to this generation only. If the model will be used in post-processing tasks (texture, rig, retarget, convert, ...), it is recommended **not** to set this parameter.
- When set, post-processing the model may produce a wrongly-oriented result while the task still reports `status: success` — no error is raised. Use with caution.
- If you plan to post-process the model, leave this unset and convert the orientation in the last step via `/v3/models/convert`.

### quad

- **Type:** boolean
- **Required:** Optional
- **Default:** `false`

**P2-20260801 only.** Whether to output a quad mesh (four-sided polygons) instead of triangles.

## Request Example

### View-key with URLs

```bash
curl --request POST \
  --url https://openapi.tripo3d.ai/v3/generation/multiview-to-model \
  --header 'Authorization: Bearer <token>' \
  --header 'Content-Type: application/json' \
  --data '{
  "inputs": [
    {
      "front": "https://example.com/front.png"
    },
    {
      "back": "https://example.com/back.png"
    },
    {
      "right": "https://example.com/right.png"
    }
  ],
  "model": "P1-20260311",
  "texture": true,
  "pbr": true
}'
```

### P2 Series

```bash
curl --request POST \
  --url https://openapi.tripo3d.ai/v3/generation/multiview-to-model \
  --header 'Authorization: Bearer <token>' \
  --header 'Content-Type: application/json' \
  --data '{
  "inputs": [
    {
      "front": "https://example.com/front.png"
    },
    {
      "back": "https://example.com/back.png"
    }
  ],
  "model": "P2-20260801",
  "quad": true,
  "texture": true,
  "pbr": true
}'
```

### View-key with file_tokens

```bash
curl --request POST \
  --url https://openapi.tripo3d.ai/v3/generation/multiview-to-model \
  --header 'Authorization: Bearer <token>' \
  --header 'Content-Type: application/json' \
  --data '{
  "inputs": [
    {
      "front": "3154b4b0-4647-4032-aa82-827441ae92ef"
    },
    {
      "back": "58ea3eab-6a08-4deb-98f9-e60f1802954d"
    },
    {
      "right": "584b0e07-8576-4eb4-bf49-2e149e0252f6"
    }
  ],
  "model": "P1-20260311",
  "texture": true,
  "pbr": true
}'
```

### Legacy positional

```bash
curl --request POST \
  --url https://openapi.tripo3d.ai/v3/generation/multiview-to-model \
  --header 'Authorization: Bearer <token>' \
  --header 'Content-Type: application/json' \
  --data '{
  "inputs": [
    "https://example.com/front.png",
    "",
    "https://example.com/back.png",
    "https://example.com/right.png"
  ],
  "model": "P1-20260311",
  "texture": true,
  "pbr": true
}'
```

### From multiview task

```bash
curl --request POST \
  --url https://openapi.tripo3d.ai/v3/generation/multiview-to-model \
  --header 'Authorization: Bearer <token>' \
  --header 'Content-Type: application/json' \
  --data '{
  "inputs": [
    {
      "task_id": "550e8400-e29b-41d4-a716-446655440000"
    }
  ],
  "model": "P1-20260311",
  "texture": true,
  "pbr": true
}'
```


## Response Example

### Create task

```json
{
  "code": 0,
  "data": {
    "task_id": "task_abc123"
  }
}
```

### Task result

```json
{
  "code": 0,
  "data": {
    "task_id": "task_abc123",
    "type": "text_to_model",
    "status": "success",
    "progress": 100,
    "output": {
      "model_url": "https://cdn.tripo3d.ai/output/model_pbr.glb",
      "rendered_image_url": "https://cdn.tripo3d.ai/output/preview.png"
    },
    "credits_consumed": 100.00,
    "created_at": "2026-04-28T12:00:00Z",
    "completed_at": "2026-04-28T12:01:30Z"
  }
}
```
