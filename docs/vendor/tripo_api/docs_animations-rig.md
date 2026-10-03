# Auto Rigging

**Base URL:** `https://openapi.tripo3d.ai/v3`

**Endpoint:** `POST /animations/rig`

Automatically add a skeleton rig to a 3D model. Run rig-check first to verify compatibility.

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

### model

- **Type:** string
- **Required:** Optional
- **Default:** `v1.0-20240301`

Rigging model version.
- `v1.0-20240301` — biped (humanoid) only. Recommended for humanoid characters. Supports 90+ animation presets.
- `v2.5-20260210` — non-humanoid creatures (quadruped, hexapod, octopod, serpentine, aquatic, avian).

### rig_type

- **Type:** string
- **Required:** Optional
- **Default:** `biped`

Rig type. Recommend calling `rig-check` first.
- `biped` — humanoid, two legs.
- `quadruped` — four-legged animal.
- `hexapod` — six-legged creature.
- `octopod` — eight-legged creature.
- `avian` — bird / winged.
- `serpentine` — snake-like.
- `aquatic` — fish / aquatic.

### spec

- **Type:** string
- **Required:** Optional
- **Default:** `tripo`

Rigging specification.
- `tripo` — Tripo native bone naming.
- `mixamo` — Mixamo-compatible bone naming.

### out_format

- **Type:** string
- **Required:** Optional
- **Default:** `glb`

Output format.
- `glb` — binary glTF, web-ready.
- `fbx` — FBX for DCC tools and game engines.


## Request Example

### Auto rig

```bash
curl --request POST \
  --url https://openapi.tripo3d.ai/v3/animations/rig \
  --header 'Authorization: Bearer <token>' \
  --header 'Content-Type: application/json' \
  --data '{
  "input": "task_abc123",
  "model": "v2.5-20260210",
  "rig_type": "biped",
  "spec": "mixamo",
  "out_format": "glb"
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
    "task_id": "task_def456",
    "status": "success",
    "output": {
      "model_url": "https://cdn.tripo3d.ai/output/rigged.glb"
    },
    "credits_consumed": 30.00
  }
}
```
