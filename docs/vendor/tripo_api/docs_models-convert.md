# Model Format Conversion

**Base URL:** `https://openapi.tripo3d.ai/v3`

**Endpoint:** `POST /models/convert`

Convert a 3D model to another format with optional mesh processing, texture baking, and export settings.

## Request Parameters

### input

- **Type:** string
- **Required:** Required

Model source. Accepts task_id or file_token. Accepts the following input types:**Choose exactly one** of the following — do not pass multiple types simultaneously.

- task_id — The task ID returned by a previous 3D generation task (`text_to_model`, `image_to_model`, or `multiview_to_model`). The system automatically uses the 3D model output from that task.
Example: `task_abc123`
- file_token — Upload a 3D model file via the File Upload API first, then pass the returned token.
Example: `file_abc123`
- URL — A publicly accessible direct link to a 3D model file.
Example: `https://example.com/model.glb`



- Supported formats: `GLB`, `GLTF`, `FBX`, `OBJ`, `STL`
- Max file size: **150 MB**

### format

- **Type:** string
- **Required:** Required

Target export format.
- `GLTF` — web viewers, WebGL engines.
- `FBX` — Unreal, Unity, DCC tools.
- `USDZ` — Apple AR Quick Look.
- `OBJ` — legacy exchange, no animation.
- `STL` — 3D printing, geometry only.
- `3MF` — 3D with single color.



- `GLTF` — web viewers, WebGL engines (Three.js, Babylon.js).
- `FBX` — Unreal, Unity, DCC tools (Maya, Blender).
- `USDZ` — Apple AR Quick Look, RealityKit.
- `OBJ` — legacy exchange, no animation.
- `STL` / `3MF` — 3D printing, geometry only.

### quad

- **Type:** boolean
- **Required:** Optional
- **Default:** `false`

Whether to output a quad mesh (four-sided polygons) instead of triangles. If `face_limit` is not set, the default face count will be 10,000.Enabling `quad` will force the output format to `FBX`.

### force_symmetry

- **Type:** boolean
- **Required:** Optional
- **Default:** `false`

Force symmetry. Only valid when quad is true.
### face_limit

- **Type:** integer
- **Required:** Optional

Maximum polycount for the output mesh. If omitted, the original face count is preserved.
### flatten_bottom

- **Type:** boolean
- **Required:** Optional
- **Default:** `false`

Flatten the bottom of the model.
### flatten_bottom_threshold

- **Type:** float
- **Required:** Optional
- **Default:** `0.01`

Flattening depth threshold.
### texture_size

- **Type:** integer
- **Required:** Optional
- **Default:** `4096`

Diffuse texture size in pixels.
### texture_format

- **Type:** string
- **Required:** Optional
- **Default:** `JPEG`

Texture image format.
- `JPEG` — default, smallest file size.
- `PNG` — lossless, supports transparency.
- `WEBP` — modern web format.
- `BMP` / `DPX` / `HDR` / `OPEN_EXR` / `TARGA` / `TIFF` — specialized use.

### bake

- **Type:** boolean
- **Required:** Optional
- **Default:** `true`

Bake advanced materials into base textures.
### pack_uv

- **Type:** boolean
- **Required:** Optional
- **Default:** `false`

Pack all UVs into a unified layout.
### export_vertex_colors

- **Type:** boolean
- **Required:** Optional
- **Default:** `false`

Include vertex colors. **Only valid for `OBJ` and `GLTF`.**
### pivot_to_center_bottom

- **Type:** boolean
- **Required:** Optional
- **Default:** `false`

Move the pivot to the bottom center.
### scale_factor

- **Type:** float
- **Required:** Optional
- **Default:** `1`

Scale factor for the exported model.
### with_animation

- **Type:** boolean
- **Required:** Optional
- **Default:** `true`

Include skeleton and animation data.
### animate_in_place

- **Type:** boolean
- **Required:** Optional
- **Default:** `false`

In-place animation (no root displacement).
### part_names

- **Type:** string[]
- **Required:** Optional

Names of parts to export, from mesh/segment data.
### export_orientation

- **Type:** string
- **Required:** Optional
- **Default:** `+x`

Export orientation (forward axis).
- `+x` — default, X-forward.
- `-x` — negative X-forward.
- `-y` — negative Y-forward.
- `+y` — Y-forward.

### fbx_preset

- **Type:** string
- **Required:** Optional
- **Default:** `blender`

FBX compatibility preset.
- `blender` — optimized for Blender import.
- `3dsmax` — optimized for 3ds Max import.
- `mixamo` — compatible with Mixamo rigging.
- `bake_scale` — bakes the scale transform into the geometry on FBX export instead of leaving it on the node transform.


## Request Example

### To FBX

```bash
curl --request POST \
  --url https://openapi.tripo3d.ai/v3/models/convert \
  --header 'Authorization: Bearer <token>' \
  --header 'Content-Type: application/json' \
  --data '{
  "input": "task_abc123",
  "format": "FBX",
  "texture_size": 2048,
  "texture_format": "PNG",
  "pivot_to_center_bottom": true,
  "fbx_preset": "blender"
}'
```

### To GLTF

```bash
curl --request POST \
  --url https://openapi.tripo3d.ai/v3/models/convert \
  --header 'Authorization: Bearer <token>' \
  --header 'Content-Type: application/json' \
  --data '{
  "input": "task_abc123",
  "format": "GLTF",
  "texture_size": 4096,
  "bake": true
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
