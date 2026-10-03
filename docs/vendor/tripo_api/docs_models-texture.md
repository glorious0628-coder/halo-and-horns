# Texture

**Base URL:** `https://openapi.tripo3d.ai/v3`

**Endpoint:** `POST /models/texture`

Regenerate texture maps for an existing model.

## Request Parameters

### input

- **Type:** string
- **Required:** Required

Model source. Accepts task_id, file_token, or URL. Accepts the following input types:**Choose exactly one** of the following — do not pass multiple types simultaneously.

- task_id — The task ID returned by a previous 3D generation task (`text_to_model`, `image_to_model`, or `multiview_to_model`). The system automatically uses the 3D model output from that task.
Example: `task_abc123`
- file_token — Upload a 3D model file via the File Upload API first, then pass the returned token.
Example: `file_abc123`
- URL — A publicly accessible direct link to a 3D model file.
Example: `https://example.com/model.glb`



- Supported formats: `GLB`, `GLTF`, `FBX`, `OBJ`, `STL`
- Max file size: **150 MB**

### model

- **Type:** string
- **Required:** Optional
- **Default:** `v3.0-20250812`

Texture model version. Choose based on the generation model used for the source 3D model:
- `v3.5-20260815` — newest texture model. Required for `texture_quality=fast` and `delight`.
- `v3.0-20250812` — default. Recommended for models generated with `v3.0-20250812` or `v3.1-20260211`.
- `v2.5-20250123` — recommended for models generated with `v2.5-20250123`.

### texture_prompt

- **Type:** object
- **Required:** Optional

Texture guidance input. Optional if the model was generated via Tripo.**`text` / `image` / `images` are mutually exclusive — use exactly one (`style_image` may accompany `text`).**

- text — A text prompt describing the desired texture style.
Example: `{"text": "worn leather with scratches"}`
- style_image — A reference image to influence artistic style. Only used with `text` mode. Accepts `file_token` or `url`. Recommended resolution: at least 256×256 px.
Example: `{"text": "cyberpunk style", "style_image": {"url": "https://..."}}`
- image — A single reference image for texture generation. Accepts file_token or URL.
- images — A list of exactly 4 reference images in the order [front, left, back, right] for multi-angle texture guidance.



- When initiating a texture task based on an existing task_id, it is **strongly recommended** to re-supply the reference image in this request.
- `text`, `image`, and `images` are mutually exclusive.
- Optional `style_image` can be added alongside `text` to influence artistic style.

### pbr

- **Type:** boolean
- **Required:** Optional
- **Default:** `true`

Enable PBR material generation.
### texture_seed

- **Type:** integer
- **Required:** Optional

Random seed for texture generation. Using the same seed will produce identical textures. If not set, a random seed will be used each time. To get a model with different textures but the same geometry, keep model_seed unchanged and vary texture_seed.
### texture_alignment

- **Type:** string
- **Required:** Optional
- **Default:** `original_image`

Texture alignment priority.
- `original_image` — prioritize matching the input image colors.
- `geometry` — prioritize matching the generated geometry.

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
### part_names

- **Type:** string[]
- **Required:** Optional

List of part names from a previous mesh segmentation task. If omitted, all parts are textured.
### compress

- **Type:** string
- **Required:** Optional

Compression type.
- `geometry` — meshopt compression for reduced file size.



- The following parameters are only valid when `model ≥ v3.0-20250812`: `texture_quality`, `geometry_quality`, `auto_size`, `quad`, `smart_low_poly`, `generate_parts`, `compress`.

### bake

- **Type:** boolean
- **Required:** Optional
- **Default:** `true`

Bake advanced material effects into base textures for broader compatibility.
### delight

- **Type:** boolean
- **Required:** Optional
- **Default:** `true`

Removes baked-in lighting from the reference image before texturing. Set `false` to keep the original shading. Only the `v3.5-20260815` texture model reads this; older texture versions ignore it.

## Request Example

### Basic (v2.5 model)

```bash
curl --request POST \
  --url https://openapi.tripo3d.ai/v3/models/texture \
  --header 'Authorization: Bearer <token>' \
  --header 'Content-Type: application/json' \
  --data '{
  "input": "task_abc123",
  "model": "v2.5-20250123",
  "texture_quality": "detailed",
  "pbr": true
}'
```

### Fast (v3.5 model)

```bash
curl --request POST \
  --url https://openapi.tripo3d.ai/v3/models/texture \
  --header 'Authorization: Bearer <token>' \
  --header 'Content-Type: application/json' \
  --data '{
  "input": "task_abc123",
  "model": "v3.5-20260815",
  "texture_quality": "fast",
  "delight": true,
  "pbr": true
}'
```

### For v3.x model

```bash
curl --request POST \
  --url https://openapi.tripo3d.ai/v3/models/texture \
  --header 'Authorization: Bearer <token>' \
  --header 'Content-Type: application/json' \
  --data '{
  "input": "task_abc123",
  "model": "v3.0-20250812",
  "texture_quality": "detailed",
  "pbr": true
}'
```

### With prompt

```bash
curl --request POST \
  --url https://openapi.tripo3d.ai/v3/models/texture \
  --header 'Authorization: Bearer <token>' \
  --header 'Content-Type: application/json' \
  --data '{
  "input": "task_abc123",
  "model": "v3.0-20250812",
  "texture_prompt": {
    "text": "worn leather with scratches"
  },
  "texture_quality": "detailed"
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
