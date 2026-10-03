# Image to Multiview

**Base URL:** `https://openapi.tripo3d.ai/v3`

**Endpoint:** `POST /generation/image-to-multiview`

Generate multiview images from a single image. Useful as preprocessing for multiview-to-model, or for turntable previews.

## Request Parameters

### input

- **Type:** string
- **Required:** Required

Source image for multiview generation. Accepts the following input types:**Choose exactly one** — do not pass multiple types simultaneously.

- file_token — Upload an image via the File Upload API first, then pass the returned token.
Example: `file_abc123`
- URL — A publicly accessible direct link to an image.
Example: `https://example.com/character.png`



- Formats: `PNG`, `JPEG`, `WebP`
- Subject should be clearly visible against a clean background.


## Request Example

### Basic

```bash
curl --request POST \
  --url https://openapi.tripo3d.ai/v3/generation/image-to-multiview \
  --header 'Authorization: Bearer <token>' \
  --header 'Content-Type: application/json' \
  --data '{
  "input": "https://example.com/character.png"
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
    "status": "success",
    "output": {
      "front_view_url": "https://cdn.tripo3d.ai/front.png",
      "left_view_url": "https://cdn.tripo3d.ai/left.png",
      "back_view_url": "https://cdn.tripo3d.ai/back.png",
      "right_view_url": "https://cdn.tripo3d.ai/right.png"
    }
  }
}
```
