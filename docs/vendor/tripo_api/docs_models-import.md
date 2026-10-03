# Import Model

**Base URL:** `https://openapi.tripo3d.ai/v3`

**Endpoint:** `POST /models/import`

Import an external 3D model file into the Tripo platform for downstream processing.

## Request Parameters

### input

- **Type:** string
- **Required:** Required

Model file source. Accepts `file_token` (prefix `file_`) or a URL.


- Formats: `GLB`, `GLTF`, `FBX`, `OBJ`, `STL`
- Max file size: **150 MB**


## Request Example

### From file

```bash
curl --request POST \
  --url https://openapi.tripo3d.ai/v3/models/import \
  --header 'Authorization: Bearer <token>' \
  --header 'Content-Type: application/json' \
  --data '{
  "input": "file_abc123"
}'
```

### From URL

```bash
curl --request POST \
  --url https://openapi.tripo3d.ai/v3/models/import \
  --header 'Authorization: Bearer <token>' \
  --header 'Content-Type: application/json' \
  --data '{
  "input": "https://example.com/my-model.glb"
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
