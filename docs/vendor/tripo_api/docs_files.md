# File Management

**Base URL:** `https://openapi.tripo3d.ai/v3`

**Endpoint:** `POST /files`

Upload a file and get a file_token for subsequent API calls.

## Request Parameters

### file

- **Type:** binary
- **Required:** Required

File data. Use `multipart/form-data` encoding.


- Images: `JPEG`, `PNG`. Max **20 MB**.
- Models: `GLB`, `GLTF`, `FBX`, `OBJ`, `STL`. Max **150 MB**.
- For files larger than 60 MB, consider using File Upload (Large Files) for better performance.


## Response Fields

### file_token

- **Type:** string
- **Required:** Required

File reference token (e.g., `file_abc123`). Use in the `input` field of other API calls.

## Request Example

### Upload

```
curl -s \
  -H "Authorization: Bearer YOUR_API_KEY" \
  -F "file=@product-photo.png" \
  https://openapi.tripo3d.ai/v3/files
```


## Response Example

### Upload

```json
{
  "code": 0,
  "data": {
    "file_token": "file_abc123"
  }
}
```
