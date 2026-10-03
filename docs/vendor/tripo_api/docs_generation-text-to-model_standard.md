# Text to 3D Model — H Series

**Base URL:** `https://openapi.tripo3d.ai/v3`

**Endpoint:** `POST /generation/text-to-model`

Generate a 3D model from a text prompt. Produces geometry, optional textures, and optional PBR material maps.

## Request Parameters

### prompt

- **Type:** string
- **Required:** Required

Text prompt, up to 1024 characters. Describe shape, material, style, and scale.


- Good: "A low-poly medieval wooden treasure chest with iron hinges and a rusty lock."
- Bad: "A box."
- Include material and style hints for better PBR results.

### model

- **Type:** string
- **Required:** Required

AI model version.
- `v3.1-20260211` — latest, best quality.
- `v3.0-20250812` — stable, advanced features.
- `v2.5-20250123` — balanced.

### negative_prompt

- **Type:** string
- **Required:** Optional

Negative prompt, up to 255 characters. Describe what you do NOT want in the generated model. For example: "blurry, low quality, broken mesh".
### model_seed

- **Type:** integer
- **Required:** Optional

Random seed for geometry generation. Using the same seed with the same input will produce an identical 3D mesh. If not set, a random seed is used each time.
### image_seed

- **Type:** integer
- **Required:** Optional

Random seed for the internal text-to-image stage. Controls the reference image generated from your text prompt before 3D conversion. If not set, a random seed is used each time.
### face_limit

- **Type:** integer
- **Required:** Optional

Maximum polycount for the output mesh.


- If omitted, the model uses adaptive topology.
Upper limits by mode
| Mode | Standard | Ultra | 
| Triangle — v3.1 | **1,500,000** | **2,000,000** | 
| Triangle — v3.0 | **1,000,000** | **2,000,000** | 
| Triangle — v2.5 | **500,000** | / | 
| Quad (`quad: true`) | **150,000** | 


- Game-ready assets: **50,000 – 100,000**. Web/mobile: **10,000 – 50,000**.
- When `smart_low_poly: true`, face limits are fixed regardless of model version: Triangle **500 – 20,000**, Quad **500 – 10,000**.

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
### geometry_quality

- **Type:** string
- **Required:** Optional
- **Default:** `standard`

Geometry quality level.
- `standard` — balanced quality and speed.
- `detailed` — Ultra mode, finer geometry detail.
Only effective for model version ≥ v3.0. Do NOT use this parameter with v2.5.

### auto_size

- **Type:** boolean
- **Required:** Optional
- **Default:** `false`

Whether to automatically scale the generated model to real-world dimensions. When enabled, the model size will be in meters, suitable for AR/VR or game engine scenes. Default is false.
### quad

- **Type:** boolean
- **Required:** Optional
- **Default:** `false`

Whether to output a quad mesh (four-sided polygons) instead of triangles. If `face_limit` is not set, the default face count will be 10,000.Enabling `quad` will force the output format to `FBX`.

### smart_low_poly

- **Type:** boolean
- **Required:** Optional
- **Default:** `false`

Whether to generate a low-poly model with hand-crafted, clean topology style. Best suited for simple, non-complex inputs. Complex models may occasionally fail. Default is false.
### generate_parts

- **Type:** boolean
- **Required:** Optional
- **Default:** `false`

Generate editable segmented parts.Not compatible with `texture`, `pbr`, `quad`, or `smart_low_poly`:
- `texture=true` or `pbr=true` — including omitting `texture`, which defaults to `true` — the request is rejected with error code `1004`.
- `quad=true` — quad is ignored; the returned parts are triangle meshes.
- `smart_low_poly=true` — smart_low_poly takes precedence and parts are NOT produced.
To generate parts, set `texture=false` and `pbr=false`, and do not send `quad` or `smart_low_poly`.


### compress

- **Type:** string
- **Required:** Optional

Compression type.
- `geometry` — meshopt compression for reduced file size.



- The following parameters are only valid when `model ≥ v3.0-20250812`: `texture_quality`, `geometry_quality`, `auto_size`, `quad`, `smart_low_poly`, `generate_parts`, `compress`.

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

### export_uv

- **Type:** boolean
- **Required:** Optional
- **Default:** `true`

Controls UV unwrapping during generation. Set `false` for faster generation and smaller file size. UV unwrapping will be handled during texturing.

## Request Example

### Basic

```bash
curl --request POST \
  --url https://openapi.tripo3d.ai/v3/generation/text-to-model \
  --header 'Authorization: Bearer <token>' \
  --header 'Content-Type: application/json' \
  --data '{
  "prompt": "A cat wearing a spacesuit",
  "model": "v3.1-20260211",
  "texture": true,
  "pbr": true,
  "texture_quality": "detailed"
}'
```

### Advanced

```bash
curl --request POST \
  --url https://openapi.tripo3d.ai/v3/generation/text-to-model \
  --header 'Authorization: Bearer <token>' \
  --header 'Content-Type: application/json' \
  --data '{
  "prompt": "A futuristic sci-fi helmet with glowing blue visor.",
  "model": "v3.1-20260211",
  "face_limit": 80000,
  "geometry_quality": "detailed",
  "auto_size": true
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
