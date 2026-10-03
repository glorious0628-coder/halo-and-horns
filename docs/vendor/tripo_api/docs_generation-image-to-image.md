# Image to Image

**Base URL:** `https://openapi.tripo3d.ai/v3`

**Endpoint:** `POST /generation/image-to-image`

Generate or edit an image from reference images. Supports editing, style transfer, and multi-image fusion.

## Request Parameters

### model

- **Type:** string
- **Required:** Optional
- **Default:** `seedream_v5`

Image editing model.
- `seedream_v5` — strongest editing, style transfer, and multi-image fusion.
- `banana` — fast editing.
- `banana_pro` — higher quality editing.
- `banana2` — latest fast editing.
- `chat_image_1` — base image editing. **Retiring 2026-10-23.**
- `chat_image_1.5` — higher quality editing. **Retiring 2026-12-01.**
- `chat_image_2` — latest, best editing.
- `chat_image_2.5_flare` — 2.5 speed tier; noticeably faster than sunburst at the same cost.
- `chat_image_2.5_sunburst` — 2.5 fidelity tier; keeps untouched parts of the image closest to the original.

### input

- **Type:** string
- **Required:** Required

Primary reference image. Accepts a public URL, `file_token`, or `task_id`.**Choose exactly one** — do not pass multiple types simultaneously.



- Formats: `jpeg`, `png` (recommended); `webp` is rejected on some provider routes
- Max file size: **20 MB**
- Max total pixels: **6000 × 6000 = 36 MP**
- Min width/height: 14 px
- Aspect ratio (W/H): **[1/3, 3]**
- URL images must be publicly accessible. Private files require `/v3/files` first.

### inputs

- **Type:** string[]
- **Required:** Optional

Multiple reference images. Each follows the same format as `input`.


- Max: **4** (seedream), **10** (banana), **16** (chat_image)
- Reference: `image[1]`, `image[2]`, etc.

### prompt

- **Type:** string
- **Required:** Conditional

Editing instruction. **Required when no template is specified.**
### size

- **Type:** string
- **Required:** Optional
- **Default:** `2048x2048`

Output image size. Accepts semantic keywords (e.g. 2K / 4K) or explicit WxH pixels (e.g. 2048x2048). Supported values vary by model — see tabs below.
### quality

- **Type:** string
- **Required:** Optional
- **Default:** `low`

Rendering quality tier. Only `chat_image_2`, `chat_image_2.5_flare` and `chat_image_2.5_sunburst` accept this parameter; passing it with any other model returns an error.


- `chat_image_2` — `low`, `medium`, `high`.
- `chat_image_2.5_flare` / `chat_image_2.5_sunburst` — `low`, `medium`, `high`, `xhigh`, `max`.
Omitting it is equivalent to `low`. Note this differs from OpenAI's own default of `auto`, and `auto` is **not** supported here — we need a known tier up front in order to price the request.

`high`, `xhigh` and `max` cost more credits and take noticeably longer; `low` and `medium` are billed at the base price. See the Pricing page.



### background

- **Type:** string
- **Required:** Optional

Background handling. Only `chat_image_2.5_flare` and `chat_image_2.5_sunburst` support it — one of `auto`, `opaque` or `transparent`.

Omit it to let the model decide. Passing it with any other model is ignored rather than rejected, so the request still succeeds but the background is left to the model.

`transparent` requires `output_format=png`. JPEG carries no alpha channel, so combining the two returns an error instead of silently flattening the transparency.


### aspect_ratio

- **Type:** string
- **Required:** Optional
- **Default:** `1:1`

Output aspect ratio. Default `1:1` when omitted (banana series only; filled by the gateway when both `size` and `aspect_ratio` are absent).
- `banana` / `banana_pro`: `1:1`, `2:3`, `3:2`, `3:4`, `4:3`, `4:5`, `5:4`, `9:16`, `16:9`, `21:9`.
- `banana2` additionally supports `1:8`, `1:4`, `4:1`, `8:1`.
Only the **banana** series supports this field. seedream / chat_image generate by `size` — use the `size` parameter instead.

### template

- **Type:** string
- **Required:** Optional

Editing template. When set, `prompt` becomes optional.
- `t_pose` — convert to T-pose.
- `character_completion` — complete a partial character.
- `3d_enhance` — enhance for 3D generation.
- `variants` — generate design variations.
- `figure` — generate a full-body figure.

### output_format

- **Type:** string
- **Required:** Optional
- **Default:** `png`

Output image format.
- `png` — lossless, supports transparency.
- `jpeg` — smaller file size, no transparency.


## Request Example

### Single image

```bash
curl --request POST \
  --url https://openapi.tripo3d.ai/v3/generation/image-to-image \
  --header 'Authorization: Bearer <token>' \
  --header 'Content-Type: application/json' \
  --data '{
  "input": "https://example.com/reference.png",
  "prompt": "Change the silver outfit into transparent glass.",
  "model": "seedream_v5",
  "size": "2K"
}'
```

### Multi-image

```bash
curl --request POST \
  --url https://openapi.tripo3d.ai/v3/generation/image-to-image \
  --header 'Authorization: Bearer <token>' \
  --header 'Content-Type: application/json' \
  --data '{
  "inputs": [
    "https://example.com/photo1.png",
    "https://example.com/photo2.png"
  ],
  "prompt": "Use character from image[1] and outfit from image[2].",
  "model": "seedream_v5"
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
    "type": "image_to_image",
    "status": "success",
    "progress": 100,
    "output": {
      "generated_image_url": "https://cdn.tripo3d.ai/output/image.png"
    },
    "credits_consumed": 20.00,
    "created_at": "2026-04-28T12:00:00Z",
    "completed_at": "2026-04-28T12:00:08Z"
  }
}
```
