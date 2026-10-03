# File Upload (Large Files)

**Base URL:** `https://openapi.tripo3d.ai/v3`

**Endpoint:** `POST /files/presign`

Get a presigned upload URL for direct file upload to storage — **faster performance** for large files. No SDK required — use a standard HTTP PUT request. Recommended for files exceeding 60 MB; for smaller files you can also use File Upload (multipart, max 150 MB).Upload flow
- Call `POST /v3/files/presign` with `format` to obtain `presigned_url` and `file_token`.
- Upload the file with **HTTP PUT** to `presigned_url` (direct to storage, no auth needed).
- Use `file_token` in the `input` field of subsequent API calls (e.g. Import Model, Retopology, Convert Model).




## Request Parameters

### format

- **Type:** string
- **Required:** Required

File extension without leading dot (e.g. glb, fbx, png).


- Images: `jpeg`, `jpg`, `png`, `webp`, `bmp`, `tiff`.
- Models: `glb`, `gltf`, `fbx`, `obj`, `stl`, `3mf`, `usdz`.


## Response Fields

### presigned_url

- **Type:** string
- **Required:** Required

Presigned PUT URL valid for 30 minutes. Upload the file with HTTP PUT to this URL.
### file_token

- **Type:** string
- **Required:** Required

File reference token (e.g., `file_abc123`). Use in the `input` field after upload completes.
### expires_in

- **Type:** integer
- **Required:** Required

Presigned URL validity in seconds. Fixed at 1800 (30 minutes).

## Request Example

### curl

```
# Step 1: Get presigned URL
curl -s -X POST \
  -H "Authorization: Bearer YOUR_API_KEY" \
  -H "Content-Type: application/json" \
  -d '{"format":"glb"}' \
  https://openapi.tripo3d.ai/v3/files/presign

# Step 2: Upload file directly to storage (no Auth needed)
curl -X PUT \
  -H "Content-Type: application/octet-stream" \
  -T model.glb \
  "<presigned_url from step 1>"

# Step 3: Create task using file_token
curl -s -X POST \
  -H "Authorization: Bearer YOUR_API_KEY" \
  -H "Content-Type: application/json" \
  -d '{"model":"default","input":"<file_token from step 1>"}' \
  https://openapi.tripo3d.ai/v3/models/import
```

### Python

```
import requests

API_KEY = "YOUR_API_KEY"
BASE = "https://openapi.tripo3d.ai"
headers = {"Authorization": f"Bearer {API_KEY}"}

# 1. Get presigned URL
resp = requests.post(f"{BASE}/v3/files/presign",
                     json={"format": "glb"}, headers=headers)
data = resp.json()["data"]
presigned_url = data["presigned_url"]
file_token = data["file_token"]

# 2. Upload file directly to storage
with open("model.glb", "rb") as f:
    put_resp = requests.put(presigned_url, data=f,
                            headers={"Content-Type": "application/octet-stream"})
    assert put_resp.status_code == 200

# 3. Create task with file_token
task_resp = requests.post(f"{BASE}/v3/models/import",
    json={"model": "default", "input": file_token},
    headers=headers)
print(task_resp.json())
```

### JavaScript

```
import fs from 'fs';

const API_KEY = 'YOUR_API_KEY';
const BASE = 'https://openapi.tripo3d.ai';

// 1. Get presigned URL
const presignRes = await fetch(`${BASE}/v3/files/presign`, {
  method: 'POST',
  headers: { 'Authorization': `Bearer ${API_KEY}`, 'Content-Type': 'application/json' },
  body: JSON.stringify({ format: 'glb' }),
});
const { data } = await presignRes.json();
const { presigned_url, file_token } = data;

// 2. Upload file directly to storage
const fileBuffer = fs.readFileSync('model.glb');
await fetch(presigned_url, {
  method: 'PUT',
  headers: { 'Content-Type': 'application/octet-stream' },
  body: fileBuffer,
});

// 3. Create task with file_token
const taskRes = await fetch(`${BASE}/v3/models/import`, {
  method: 'POST',
  headers: { 'Authorization': `Bearer ${API_KEY}`, 'Content-Type': 'application/json' },
  body: JSON.stringify({ model: 'default', input: file_token }),
});
console.log(await taskRes.json());
```


## Response Example

### Presign response

```json
{
  "code": 0,
  "data": {
    "presigned_url": "https://storage.example.com/bucket/path/input.glb?X-Amz-Signature=...",
    "file_token": "file_abc123",
    "expires_in": 1800
  }
}
```
