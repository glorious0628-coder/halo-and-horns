# Account Management

**Base URL:** `https://openapi.tripo3d.ai/v3`

**Endpoint:** `GET /account/balance`

Query account balance and usage details. Balance returns available and frozen credits; Usage returns per-task consumption history.

## Response Fields

### balance

- **Type:** number
- **Required:** Required

Available credit balance. Decimal number with up to two decimal places (e.g. 41465.00).
### frozen

- **Type:** number
- **Required:** Required

Frozen credits reserved for in-progress tasks. Decimal number with up to two decimal places (e.g. 0.00).

## Request Example

### Balance

```
curl -s \
  -H "Authorization: Bearer YOUR_API_KEY" \
  https://openapi.tripo3d.ai/v3/account/balance
```

### Usage

```
curl -s \
  -H "Authorization: Bearer YOUR_API_KEY" \
  https://openapi.tripo3d.ai/v3/account/usage
```


## Response Example

### Balance

```json
{
  "code": 0,
  "data": {
    "balance": 10000.00,
    "frozen": 200.00
  }
}
```

### Usage

```json
{
  "code": 0,
  "data": [
    {
      "task_id": "task_abc123",
      "type": "text_to_model",
      "credits_consumed": 100.00,
      "created_at": "2025-01-01T00:00:00Z"
    }
  ]
}
```
