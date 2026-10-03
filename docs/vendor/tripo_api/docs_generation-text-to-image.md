# Text to Image

**Base URL:** `https://openapi.tripo3d.ai/v3`

**Endpoint:** `POST /generation/text-to-image`

Generate an image from a text prompt. Does not accept reference images — use image-to-image for that.

## Request Parameters

### model

- **Type:** string
- **Required:** Optional
- **Default:** `seedream_v4`

Image generation model. Available models:
- `seedream_v5` — latest quality, stronger prompt following.
- `seedream_v4` — default balanced model.
- `banana` — fast generation.
- `banana_pro` — higher quality.
- `banana2` — latest fast option.
- `chat_image_1` — base image model. **Retiring 2026-10-23.**
- `chat_image_1.5` — higher quality. **Retiring 2026-12-01.**
- `chat_image_2` — latest, best quality.
- `chat_image_2.5_flare` — 2.5 speed tier; quality on par with `chat_image_2`, noticeably faster.
- `chat_image_2.5_sunburst` — 2.5 fidelity tier; best at preserving the rest of the image when editing.

### prompt

- **Type:** string
- **Required:** Required

Text prompt for image generation. Supports Chinese and English.


- Recommended: ≤ 300 Chinese characters or ≤ 600 English words.
- Put the most important elements first.
- Negative prompts: append after `--no`.

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

### output_format

- **Type:** string
- **Required:** Optional
- **Default:** `png`

Output image format.
- `png` — lossless, supports transparency.
- `jpeg` — smaller file size, no transparency.

### watermark

- **Type:** boolean
- **Required:** Optional
- **Default:** `false`

Add an AI-generated content watermark. Only effective for the seedream series; the banana series always embeds a non-removable invisible watermark, and the chat_image series has no watermark control.
### template

- **Type:** string
- **Required:** Optional

Generation template.
- `asset_extraction` — extract a subject from a scene.
- `character_completion` — complete a partial character.
- `t_pose` — generate a character in T-pose.
- `variants` — generate design variations.
- `figure` — generate a full-body figure.


## Request Example

### seedream_v5

```bash
curl --request POST \
  --url https://openapi.tripo3d.ai/v3/generation/text-to-image \
  --header 'Authorization: Bearer <token>' \
  --header 'Content-Type: application/json' \
  --data '{
  "prompt": "A high-fashion editorial portrait, dramatic studio lighting.",
  "model": "seedream_v5",
  "size": "2K",
  "output_format": "png",
  "watermark": false
}'
```

### banana

```bash
curl --request POST \
  --url https://openapi.tripo3d.ai/v3/generation/text-to-image \
  --header 'Authorization: Bearer <token>' \
  --header 'Content-Type: application/json' \
  --data '{
  "prompt": "A cinematic product render of a glass sneaker on a dark stage.",
  "model": "banana",
  "size": "1248x832",
  "output_format": "png"
}'
```

### banana_pro

```bash
curl --request POST \
  --url https://openapi.tripo3d.ai/v3/generation/text-to-image \
  --header 'Authorization: Bearer <token>' \
  --header 'Content-Type: application/json' \
  --data '{
  "prompt": "A cinematic product render of a glass sneaker on a dark stage.",
  "model": "banana_pro",
  "size": "2K",
  "aspect_ratio": "3:2",
  "output_format": "png"
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
    "type": "text_to_image",
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
