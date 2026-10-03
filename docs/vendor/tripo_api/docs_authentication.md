# Authentication

All Tripo API requests must include an API Key in the HTTP request header for authentication.

## Authentication Method

Add the `Authorization` field to the request header, with the value `Bearer {api_key}`:

```
Authorization: Bearer {api_key}
```

## Get an API Key

1. Log in to the [Tripo Console](https://platform.tripo3d.ai)
2. Open the "API Keys" page
3. Click "Create Key" to generate a new API Key
4. Copy and store it securely. It is shown only once after creation

## Request Examples

### curl

```bash
curl -X GET https://openapi.tripo3d.ai/v3/account/balance \
  -H "Authorization: Bearer YOUR_API_KEY"
```

### Python

```python
import requests

headers = {
    "Authorization": "Bearer YOUR_API_KEY"
}

response = requests.get(
    "https://openapi.tripo3d.ai/v3/account/balance",
    headers=headers
)
print(response.json())
```

### JavaScript

```javascript
const response = await fetch("https://openapi.tripo3d.ai/v3/account/balance", {
  headers: {
    "Authorization": "Bearer YOUR_API_KEY"
  }
});

const data = await response.json();
console.log(data);
```

## Security Recommendations

- **Store API Keys in environment variables**. Do not hard-code them in source code
- **Do not commit API Keys to code repositories**. Add `.env` files to `.gitignore`
- **Do not use API Keys directly in frontend applications**. Proxy requests through your backend service
- **Rotate keys regularly**. If you suspect a leak, delete the key in the console immediately and create a new one

```bash
# Recommended: read the API Key from an environment variable
export TRIPO_API_KEY="your_api_key_here"
```

```python
import os

api_key = os.environ["TRIPO_API_KEY"]
```

```javascript
const apiKey = process.env.TRIPO_API_KEY;
```
