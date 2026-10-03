# Task Query

**Base URL:** `https://openapi.tripo3d.ai/v3`

**Endpoint:** `GET /tasks/{task_id}`

Query the status and output of a single async task by its task ID. All generation and processing endpoints return a task_id that can be used here.

## Request Parameters

### task_id

- **Type:** string
- **Required:** Required

The unique task identifier, passed as a path parameter. Starts with task_.

## Response Fields

### task_id

- **Type:** string
- **Required:** Required

Unique task identifier.
### type

- **Type:** string
- **Required:** Required

Task type (e.g., text_to_model, rig, convert).
### status

- **Type:** string
- **Required:** Required

Task status.
- `queued` — waiting in queue.
- `running` — processing in progress.
- `success` — completed successfully.
- `failed` — failed with error.
- `cancelled` — cancelled by user.

### progress

- **Type:** integer
- **Required:** Required

0–100.
### error_code

- **Type:** integer
- **Required:** Optional

Present when status=failed. Standardized error code indicating the failure reason.
### error_message

- **Type:** string
- **Required:** Optional

Present when status=failed and error_code is available. Human-readable description of the error.
### output

- **Type:** object
- **Required:** Optional

Only populated when `status=success`. Contains `model_url`, `rendered_image_url`, etc.
### credits_consumed

- **Type:** number
- **Required:** Optional

Credits consumed. Decimal number with up to two decimal places (e.g. 48.00).
### created_at

- **Type:** string
- **Required:** Required

ISO 8601 creation time.
### completed_at

- **Type:** string
- **Required:** Optional

ISO 8601 completion time.

## Request Example

### Query task

```
curl -s \
  -H "Authorization: Bearer YOUR_API_KEY" \
  https://openapi.tripo3d.ai/v3/tasks/task_abc123
```


## Response Example

### Task detail

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
