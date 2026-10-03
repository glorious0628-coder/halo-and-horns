# Riggability Check

**Base URL:** `https://openapi.tripo3d.ai/v3`

**Endpoint:** `POST /animations/rig-check`

Check whether a model can be rigged and return the recommended rig type.

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



- Supported formats: `GLB`
- Max file size: **150 MB**


## Response Fields

### riggable

- **Type:** boolean
- **Required:** Required

Whether the model is riggable.
### rig_type

- **Type:** string
- **Required:** Required

Recommended rig type.
- `biped` — humanoid, two legs.
- `quadruped` — four-legged animal.
- `hexapod` — six-legged creature.
- `octopod` — eight-legged creature.
- `avian` — bird / winged.
- `serpentine` — snake-like.
- `aquatic` — fish / aquatic.


## Request Example

### Check

```bash
curl --request POST \
  --url https://openapi.tripo3d.ai/v3/animations/rig-check \
  --header 'Authorization: Bearer <token>' \
  --header 'Content-Type: application/json' \
  --data '{
  "input": "task_abc123"
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
      "riggable": true,
      "rig_type": "biped"
    },
    "credits_consumed": 0.00
  }
}
```
