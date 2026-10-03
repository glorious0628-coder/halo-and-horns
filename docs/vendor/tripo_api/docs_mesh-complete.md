# Mesh Part Completion

**Base URL:** `https://openapi.tripo3d.ai/v3`

**Endpoint:** `POST /mesh/complete`

Complete segmented mesh parts and repair missing regions.

## Request Parameters

### input

- **Type:** string
- **Required:** Required

task_id of a `mesh/segment` task, starting with `task_`.
### model

- **Type:** string
- **Required:** Optional
- **Default:** `v1.0-20250506`

Completion model version.
- `v1.0-20250506` — default (current only version).

### part_names

- **Type:** string[]
- **Required:** Optional

List of part names to complete. If omitted, all parts are completed.
### completion_mode

- **Type:** string
- **Required:** Optional
- **Default:** `ai_completion`

Completion mode.
- `ai_completion` — AI diffusion-based completion (default). Generates realistic geometry to fill missing regions.
- `quick_cap` — Quick hole-fill. Fast sealing of open boundaries without AI generation.


## Request Example

### Complete (AI)

```bash
curl --request POST \
  --url https://openapi.tripo3d.ai/v3/mesh/complete \
  --header 'Authorization: Bearer <token>' \
  --header 'Content-Type: application/json' \
  --data '{
  "input": "task_abc123",
  "part_names": [
    "head",
    "body"
  ]
}'
```

### Quick Cap

```bash
curl --request POST \
  --url https://openapi.tripo3d.ai/v3/mesh/complete \
  --header 'Authorization: Bearer <token>' \
  --header 'Content-Type: application/json' \
  --data '{
  "input": "task_abc123",
  "completion_mode": "quick_cap"
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
