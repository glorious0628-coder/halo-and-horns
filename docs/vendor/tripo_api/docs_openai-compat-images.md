# OpenAI-Compatible Images API

**Base URL:** `https://openapi.tripo3d.ai/v3`

**Endpoint:** `POST /openai/images/generations`

**Fully compatible with the OpenAI Images API protocol.** Point your existing client at `https://openapi.tripo3d.ai/v3/openai`, change the model name, and keep the rest of your integration unchanged.Endpoints
- `POST /v3/openai/images/generations` — text to image
- `POST /v3/openai/images/edits` — image to image (multipart or JSON)

Two deliberate differences from OpenAI
- **The image is always returned as a signed URL** in `data[0].url`, never as `b64_json`. Passing `response_format="b64_json"` returns 400 rather than being silently ignored.
- **No `usage` block.** Billing is in credits, not tokens. Use Account or Task Query for spend.

Model namesModel ids use OpenAI's own spelling, so the string already in your code keeps working. These three are the only versions that exist — anything else, dated snapshot ids included, returns 404 `model_not_found` listing the three supported ids.


- `gpt-image-2`
- `gpt-image-2.5-flare`
- `gpt-image-2.5-sunburst`

Billing and timingIdentical to Text to Image and Image to Image — same credits, same content moderation, same concurrency limits. The request blocks until the image is ready (typically 20–80s). If it is still running after 240s you get a 400 with code `generation_in_progress`: the task has not failed and was charged once, so poll `GET /v3/tasks/{task_id}` (the id is in `X-Tripo-Task-Id` and in `tripo.task_id`) instead of resubmitting.





## Request Parameters

### model

- **Type:** string
- **Required:** Required

Model id, in OpenAI's spelling. Anything outside the three listed versions is rejected with 404 model_not_found.

One of: gpt-image-2, gpt-image-2.5-flare, gpt-image-2.5-sunburst — these three only. Dated snapshot ids are not accepted, nor are the Tripo chat_image_* ids.
### prompt

- **Type:** string
- **Required:** Required

Text description of the desired image.
### image

- **Type:** file | file[]
- **Required:** Conditional

Edits only, multipart form. Both 'image' and 'image[]' part names are accepted; send one part per input image.
### images

- **Type:** object[]
- **Required:** Conditional

Edits only, JSON body. Each entry sets exactly one of image_url (public https URL, or base64 data: URL up to 10 MiB) or file_id (a Tripo file_token from POST /v3/files).
### size

- **Type:** string
- **Required:** Optional
- **Default:** `1024x1024`

Output resolution. 'auto' and an omitted value both resolve to 1024x1024 so the credit cost is known before the request runs.

Same rules as the native endpoints: each edge must be a multiple of 16px.
### quality

- **Type:** string
- **Required:** Optional
- **Default:** `low`

Rendering tier. 'auto' and an omitted value both mean the base tier.

gpt-image-2: low, medium, high. gpt-image-2.5-*: additionally xhigh and max.
### background

- **Type:** string
- **Required:** Optional

auto, opaque or transparent. Only effective on gpt-image-2.5-*; transparent requires output_format=png.
### output_format

- **Type:** string
- **Required:** Optional
- **Default:** `png`

png or jpeg. webp is rejected.
### n

- **Type:** integer
- **Required:** Optional
- **Default:** `1`

Must be 1 — one image per request. Any other value returns 400.
### response_format

- **Type:** string
- **Required:** Optional
- **Default:** `url`

Only 'url' is supported. 'b64_json' returns 400 rather than being silently downgraded.
### stream

- **Type:** boolean
- **Required:** Optional

Not supported; must be false or omitted. Partial images are not available.
### mask

- **Type:** file
- **Required:** Optional

Optional inpainting mask, applied to the first input image. Must be a PNG with an alpha channel, sent as a file part; its fully transparent pixels mark the region to redraw. Anything else returns 400.

Same dimensions as the input image, and at most 20 MiB. The mask guides the model semantically rather than clipping pixels, so word the prompt to describe the region rather than an object that sits outside it. The input image itself is capped at 10 MiB, whether it is uploaded or sent as a data: URL.

## Response Fields

### created

- **Type:** integer
- **Required:** Required

Unix timestamp in seconds.
### data[].url

- **Type:** string
- **Required:** Required

Signed CDN URL of the generated image. This replaces b64_json.
### size / quality / output_format / background

- **Type:** string
- **Required:** Optional

Echo of what was actually applied — useful to confirm how 'auto' was resolved.
### tripo.task_id

- **Type:** string
- **Required:** Required

Tripo extension. The same id is returned in the X-Tripo-Task-Id response header, including on errors, so a task can always be reconciled with GET /v3/tasks/{task_id}.

## Request Example

### Text to image (official SDK)

```
from openai import OpenAI

client = OpenAI(
    api_key="<YOUR_API_KEY>",
    base_url="https://openapi.tripo3d.ai/v3/openai",
)

result = client.images.generate(
    model="gpt-image-2.5-flare",
    prompt="a cute baby sea otter on a rock",
    n=1,
    size="auto",
    quality="auto",
)

print(result.data[0].url)
```

### Image to image (official SDK)

```
result = client.images.edit(
    model="gpt-image-2.5-flare",
    prompt="replace the background with pure white",
    image=open("input.png", "rb"),
    size="1024x1024",
)

print(result.data[0].url)
```

### Image to image (JSON body)

```
curl -X POST 'https://openapi.tripo3d.ai/v3/openai/images/edits' \
  -H 'Authorization: Bearer <YOUR_API_KEY>' \
  -H 'Content-Type: application/json' \
  -d '{
    "model": "gpt-image-2.5-flare",
    "prompt": "replace the background with pure white",
    "images": [{ "image_url": "https://example.com/input.png" }],
    "size": "1024x1024"
  }'
```

### Image to image (multipart, two images)

```
curl -X POST 'https://openapi.tripo3d.ai/v3/openai/images/edits' \
  -H 'Authorization: Bearer <YOUR_API_KEY>' \
  -F 'model=gpt-image-2.5-flare' \
  -F 'prompt=combine both objects into one product photo' \
  -F 'image[]=@a.png;type=image/png' \
  -F 'image[]=@b.png;type=image/png' \
  -F 'size=1024x1024'
```


## Response Example

### Success

```json
{
  "created": 1789598400,
  "data": [
    {
      "url": "https://cdn.tripo3d.com/.../generated_image.png?..."
    }
  ],
  "size": "1024x1024",
  "quality": "low",
  "output_format": "png",
  "tripo": {
    "task_id": "2f67cafc-c1aa-492f-85e8-93ec95fc6fd8"
  }
}
```

### Error envelope

```json
{
  "error": {
    "message": "model 'chat_image_2' is not supported here; use 'gpt-image-2' instead",
    "type": "invalid_request_error",
    "param": "model",
    "code": "model_not_found"
  }
}
```

### Still generating after the wait limit

```json
{
  "error": {
    "message": "the image is still being generated after 240s; it has not failed and you have been charged once — poll GET /v3/tasks/2f67cafc-... for the result instead of resubmitting",
    "type": "invalid_request_error",
    "code": "generation_in_progress"
  }
}
```
