# Batch Task Query

**Base URL:** `https://openapi.tripo3d.ai/v3`

**Endpoint:** `POST /tasks/list`

Query the status and output of multiple async tasks in a single request. Returns a map of task details keyed by task_id, plus a list of any task IDs that were not found.

## Request Parameters

### task_ids

- **Type:** string[]
- **Required:** Required

An array of task IDs to query. Maximum **100** items per request.
Example: `["task_abc123", "task_def456"]`

## Response Fields

### tasks

- **Type:** object
- **Required:** Required

A map of task details keyed by task_id. Each value has the same structure as the single task query response.
### missed

- **Type:** string[]
- **Required:** Required

List of task IDs that were not found (invalid ID, wrong API key, or expired).

## Request Example

### Batch query

```bash
curl --request POST \
  --url https://openapi.tripo3d.ai/v3/tasks/list \
  --header 'Authorization: Bearer <token>' \
  --header 'Content-Type: application/json' \
  --data '{
  "task_ids": [
    "task_abc123",
    "task_def456"
  ]
}'
```


## Response Example

### Batch result

```json
{
  "code": 0,
  "data": {
    "tasks": {
      "task_abc123": {
        "task_id": "task_abc123",
        "type": "text_to_model",
        "status": "success",
        "progress": 100,
        "credits_consumed": 100.00
      },
      "task_def456": {
        "task_id": "task_def456",
        "type": "image_to_model",
        "status": "running",
        "progress": 60
      }
    },
    "missed": []
  }
}
```
