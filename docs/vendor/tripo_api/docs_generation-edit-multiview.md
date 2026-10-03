# Edit Multiview

**Base URL:** `https://openapi.tripo3d.ai/v3`

**Endpoint:** `POST /generation/edit-multiview`

Edit existing multiview images. Apply consistent changes across all views.

## Request Parameters

### input

- **Type:** string
- **Required:** Required

Source multiview image to edit. Accepts the following input types:**Choose exactly one** — do not pass multiple types simultaneously.

- task_id — The task ID from a previous multiview generation task. The system automatically uses the output multiview image. To generate multiview images first, use the Image to Multiview API.
Example: `task_abc123`
- file_token — Upload a multiview image via the File Upload API first.
Example: `file_abc123`
- URL — A publicly accessible direct link to a multiview image.
Example: `https://example.com/multiview.png`

### prompts

- **Type:** object[]
- **Required:** Required

A list of edit instructions, each targeting a specific view. Each item contains:
- prompt — The edit instruction describing the desired change.
Example: `change the shirt color to red`
- view — The view to apply the edit to.
- `front` — front view
- `left` — left view
- `back` — back view
- `right` — right view



## Request Example

### Edit views

```bash
curl --request POST \
  --url https://openapi.tripo3d.ai/v3/generation/edit-multiview \
  --header 'Authorization: Bearer <token>' \
  --header 'Content-Type: application/json' \
  --data '{
  "input": "task_abc123",
  "prompts": [
    {
      "prompt": "change the shirt color to red",
      "view": "front"
    },
    {
      "prompt": "add a logo on the back",
      "view": "back"
    }
  ]
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
