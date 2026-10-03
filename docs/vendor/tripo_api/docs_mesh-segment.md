# Mesh Segmentation

**Base URL:** `https://openapi.tripo3d.ai/v3`

**Endpoint:** `POST /mesh/segment`

Perform semantic segmentation on a 3D model and automatically split it into parts. Supports v1 (geometry-based, default) and v2 (semantic labeling + geometry, Beta).

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



- Supported formats: `GLB`, `GLTF`, `FBX`, `OBJ`, `STL`
- Max file size: **150 MB**

### model

- **Type:** string
- **Required:** Optional
- **Default:** `v1.0-20250506`

Segmentation model version.
- `v1.0-20250506` — default, geometry-based segmentation.
- `v2.0-20260430` Beta — semantic segmentation with labeling.

### segmentation_granularity

- **Type:** string
- **Required:** Optional
- **Default:** `balanced`

**v2 only.** Segmentation granularity.
- `simple`
- `balanced` — default
- `detailed`

### split_by_connectivity

- **Type:** boolean
- **Required:** Optional
- **Default:** `true`

**v2 only.** Whether to split by connected components.
### ref_image

- **Type:** string
- **Required:** Optional

**v2 only.** Optional reference image for semantic analysis. Accepts `file_token` (from file upload) or a public URL.When `ref_image` is provided, `segmentation_granularity` and `split_by_connectivity` are **ignored**.
Left: 3D model (.glb)  |  Right: segmentation mask used as `ref_image`




## Request Example

### Segment (v1)

```bash
curl --request POST \
  --url https://openapi.tripo3d.ai/v3/mesh/segment \
  --header 'Authorization: Bearer <token>' \
  --header 'Content-Type: application/json' \
  --data '{
  "input": "task_abc123"
}'
```

### Segment (v2 + granularity)

```bash
curl --request POST \
  --url https://openapi.tripo3d.ai/v3/mesh/segment \
  --header 'Authorization: Bearer <token>' \
  --header 'Content-Type: application/json' \
  --data '{
  "model": "v2.0-20260430",
  "input": "task_abc123",
  "segmentation_granularity": "balanced",
  "split_by_connectivity": true
}'
```

### Segment (v2 + ref_image)

```bash
curl --request POST \
  --url https://openapi.tripo3d.ai/v3/mesh/segment \
  --header 'Authorization: Bearer <token>' \
  --header 'Content-Type: application/json' \
  --data '{
  "model": "v2.0-20260430",
  "input": "task_abc123",
  "ref_image": "file_a1b2c3d4-e5f6-7890-abcd-ef1234567890"
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
    "type": "mesh_segmentation",
    "status": "success",
    "progress": 100,
    "output": {
      "model_url": "https://cdn.tripo3d.ai/output/mesh_seg.glb",
      "rendered_image_url": "https://cdn.tripo3d.ai/output/mesh_seg.webp"
    },
    "credits_consumed": 40.00,
    "created_at": "2026-05-27T02:22:56Z",
    "completed_at": "2026-05-27T02:25:33Z"
  }
}
```
