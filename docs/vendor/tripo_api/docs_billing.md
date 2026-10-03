# Billing

## Credit System

The Tripo API uses credits for billing. Different task types consume different numbers of credits.

## Credit Freeze/Deduction Model

| Stage | Description |
| :-: | :-: |
| Task creation | Freeze the required credits from the available balance |
| Task succeeds | Frozen credits become consumed credits and are formally deducted |
| Task fails | Frozen credits are returned to the available balance |
| Task is cancelled | Frozen credits are returned to the available balance |

Failed and cancelled tasks are not charged.

## Query Balance

> **GET** `/v3/account/balance`

### curl

```bash
curl -X GET https://openapi.tripo3d.ai/v3/account/balance \
  -H "Authorization: Bearer {api_key}"
```

### Python

```python
import requests

url = "https://openapi.tripo3d.ai/v3/account/balance"
headers = {
    "Authorization": "Bearer {api_key}"
}

response = requests.get(url, headers=headers)
print(response.json())
```

### JavaScript

```javascript
const response = await fetch("https://openapi.tripo3d.ai/v3/account/balance", {
  headers: {
    "Authorization": "Bearer {api_key}"
  }
});

const data = await response.json();
console.log(data);
```

### Response Example

```json
{
  "code": 0,
  "data": {
    "balance": 10000.00,
    "frozen": 200.00
  }
}
```

| Field | Type | Description |
| :-: | :-: | :-: |
| balance | number | Available credit balance |
| frozen | number | Frozen credits, pre-authorized for in-progress tasks |

## View Usage

> **GET** `/v3/account/usage`

### curl

```bash
curl -X GET https://openapi.tripo3d.ai/v3/account/usage \
  -H "Authorization: Bearer {api_key}"
```

### Python

```python
import requests

url = "https://openapi.tripo3d.ai/v3/account/usage"
headers = {
    "Authorization": "Bearer {api_key}"
}

response = requests.get(url, headers=headers)
print(response.json())
```

### JavaScript

```javascript
const response = await fetch("https://openapi.tripo3d.ai/v3/account/usage", {
  headers: {
    "Authorization": "Bearer {api_key}"
  }
});

const data = await response.json();
console.log(data);
```

### Response Example

```json
{
  "code": 0,
  "data": [
    {
      "task_id": "task_abc123",
      "type": "text_to_model",
      "credits_consumed": 100.00,
      "created_at": "2026-01-01T00:00:00Z"
    }
  ]
}
```

| Field | Type | Description |
| :-: | :-: | :-: |
| task_id | string | Unique task identifier |
| type | string | Task type |
| credits_consumed | number | Credits consumed |
| created_at | string | Creation time, in ISO 8601 format |
