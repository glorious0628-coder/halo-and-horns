# Webhooks

**Base URL:** `https://openapi.tripo3d.ai/v3`

**Endpoint:** `POST https://<your-endpoint>`

Tripo posts JSON to your HTTPS URL when a task completes or fails, or when credits fall below your alert threshold—so you do not need to poll `GET /v3/tasks/{task_id}`.Setup
- Open **Settings → Webhooks** and click **Add Endpoint**.
- Enter your HTTPS URL (e.g. `https://api.yourapp.com/tripo-webhook`).
- Select the event types to subscribe to.
- Click **Save Endpoint**.
- Copy the **Signing Secret** (`whsec_…`) — shown only once; store it like an API key.

Event types
- `task.completed` — task finished successfully.
- `task.failed` — task failed or was cancelled.
- `balance.low` — balance dropped below the threshold in **Billing → Credit alert** (alerts do not by themselves fail tasks).

RetriesIf your endpoint returns non-2xx or times out, Tripo retries automatically. Inspect failures under Settings → Webhooks → Recent deliveries.
Best practices
- Verify every payload with the signing secret before acting on it.
- Return `2xx` within ~5s; do heavy work asynchronously.
- Deduplicate using `Tripo-Webhook-Delivery`.
- Enable `balance.low` alerts in Billing for early warning.




## Request Parameters

### id

- **Type:** string
- **Required:** Required

Composite event identifier (e.g. task_id + event type).
### type

- **Type:** string
- **Required:** Required

One of `task.completed`, `task.failed`, `balance.low`.
### created_at

- **Type:** string
- **Required:** Required

ISO 8601 timestamp when the event was created.
### data

- **Type:** object
- **Required:** Required

Event-specific payload. For task events it mirrors task output fields from the Task Query API; for balance.low it includes balance-related fields.


- Task events: expect `task_id`, `type`, `status`, and `output` (when successful).
- `balance.low`: configure the threshold under Billing → Credit alert.

### Tripo-Webhook-Id

- **Type:** header · string
- **Required:** Required

Webhook endpoint id on Tripo.
### Tripo-Webhook-Delivery

- **Type:** header · string
- **Required:** Required

Unique delivery id — use for idempotency if the same logical event is delivered more than once.
### Tripo-Webhook-Event

- **Type:** header · string
- **Required:** Required

Same as body `type` (e.g. task.completed).
### Tripo-Webhook-Signature

- **Type:** header · string
- **Required:** Required

HMAC-SHA256 over `{timestamp}.{raw_body}` using your signing secret. Format: `t=<unix>,v1=<hex>`.


- Parse `t` and `v1` from the header.
- Compute HMAC-SHA256(secret, `t + "." + rawBody`) as lowercase hex.
- Compare with `v1` using a constant-time compare.
- Optional: reject if `t` is older than ~5 minutes (replay protection).

### Content-Type

- **Type:** header · string
- **Required:** Required
- **Default:** `application/json`

Always application/json.

## Response Fields

### HTTP

- **Type:** status
- **Required:** Required

Respond with 2xx quickly (within a few seconds). Return before heavy processing finishes.

## Request Example

### task.completed

```
{
  "id": "task_abc123:task.completed",
  "type": "task.completed",
  "created_at": "2026-05-06T12:00:00Z",
  "data": {
    "task_id": "task_abc123",
    "type": "text_to_model",
    "status": "success",
    "output": {
      "model_url": "https://cdn.tripo3d.ai/output/model_pbr.glb"
    }
  }
}
```

### balance.low

```
{
  "id": "evt_balance_low:balance.low",
  "type": "balance.low",
  "created_at": "2026-05-06T12:00:00Z",
  "data": {
    "balance": 1200,
    "threshold": 5000
  }
}
```

### Verify · Python

```
import hmac
import hashlib
import time

def verify_webhook(payload: bytes, signature_header: str, secret: str) -> bool:
    parts = dict(p.split("=", 1) for p in signature_header.split(","))
    timestamp = parts.get("t", "")
    expected_sig = parts.get("v1", "")

    if abs(time.time() - int(timestamp)) > 300:
        return False

    computed = hmac.new(
        secret.encode("utf-8"),
        f"{timestamp}.{payload.decode('utf-8')}".encode("utf-8"),
        hashlib.sha256
    ).hexdigest()

    return hmac.compare_digest(computed, expected_sig)
```

### Verify · JavaScript

```
const crypto = require("crypto");

function verifyWebhook(payload, signatureHeader, secret) {
  const parts = Object.fromEntries(
    signatureHeader.split(",").map(p => p.split("=", 2))
  );
  const timestamp = parts.t;
  const expectedSig = parts.v1;

  if (Math.abs(Date.now() / 1000 - parseInt(timestamp)) > 300) {
    return false;
  }

  const computed = crypto
    .createHmac("sha256", secret)
    .update(`${timestamp}.${payload}`)
    .digest("hex");

  return crypto.timingSafeEqual(
    Buffer.from(computed),
    Buffer.from(expectedSig)
  );
}
```


## Response Example

### Tripo-Webhook-Signature

```json
Tripo-Webhook-Signature: t=1714992000,v1=5257a869e7ecebeda32affa62cdca3fa51cad7e77a0e56ff536d0ce8e108d8f9
```

### task.failed

```json
{
  "id": "task_abc123:task.failed",
  "type": "task.failed",
  "created_at": "2026-05-06T12:00:05Z",
  "data": {
    "task_id": "task_abc123",
    "type": "text_to_model",
    "status": "failed",
    "error": {
      "code": "task_failed",
      "message": "Generation failed"
    }
  }
}
```
