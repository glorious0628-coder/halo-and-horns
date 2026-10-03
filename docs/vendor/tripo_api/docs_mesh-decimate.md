# Retopology

**Base URL:** `https://openapi.tripo3d.ai/v3`

**Endpoint:** `POST /mesh/decimate`

Reduce model polycount with two algorithm tiers. Use model=v2.0 (default) for smart highpoly-to-lowpoly retopology with clean topology preservation, or model=v1.0 for basic decimation.

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
- **Default:** `v2.0`

Retopology algorithm version.
### face_limit

- **Type:** integer
- **Required:** Conditional

Target polycount.
### quad

- **Type:** boolean
- **Required:** Optional
- **Default:** `false`

Output a quad mesh. Supported by both v1.0 and v2.0.
### bake

- **Type:** boolean
- **Required:** Optional
- **Default:** `true`
- **Note:** v1.0 does not support this parameter.

Bake textures onto the low-poly model.
### part_names

- **Type:** string[]
- **Required:** Optional
- **Note:** v1.0 does not support this parameter.

Names of parts to decimate (from segmentation).

## Request Example

### v2.0 Smart

```bash
curl --request POST \
  --url https://openapi.tripo3d.ai/v3/mesh/decimate \
  --header 'Authorization: Bearer <token>' \
  --header 'Content-Type: application/json' \
  --data '{
  "input": "task_abc123",
  "model": "v2.0",
  "face_limit": 5000,
  "quad": false,
  "bake": true
}'
```

### v1.0 Basic

```bash
curl --request POST \
  --url https://openapi.tripo3d.ai/v3/mesh/decimate \
  --header 'Authorization: Bearer <token>' \
  --header 'Content-Type: application/json' \
  --data '{
  "input": "task_abc123",
  "model": "v1.0",
  "face_limit": 3000
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
