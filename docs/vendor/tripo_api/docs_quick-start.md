# Quick Start

Get started with the Tripo API in 15 minutes and generate your first 3D model from scratch.

## 1. Get an API Key

Go to the [Tripo Console](https://platform.tripo3d.ai), create an account, and open the "API Keys" page to create an API Key.

## 2. Send Your First Request

Generate a 3D model from a text description:

### curl

```bash
curl -X POST https://openapi.tripo3d.ai/v3/generation/text-to-model \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer {api_key}" \
  -d '{
    "prompt": "a cute cat",
    "model": "tripo-v3.1"
  }'
```

Success response:

```json
{
  "code": 0,
  "data": {
    "task_id": "task_abc123"
  }
}
```

## 3. Query the Task Result

3D generation runs as an asynchronous task. Use the returned `task_id` to poll the task status:

```bash
curl -X GET https://openapi.tripo3d.ai/v3/tasks/task_abc123 \
  -H "Authorization: Bearer {api_key}"
```

When `status` is `success`, the task is complete:

```json
{
  "code": 0,
  "data": {
    "task_id": "task_abc123",
    "type": "text_to_model",
    "status": "success",
    "progress": 100,
    "output": {
      "model_url": "https://...",
      "rendered_image_url": "https://..."
    }
  }
}
```

## 4. Download the Model

Download the GLB 3D model file from `output.model_url` in the response. You can use it directly in tools such as Blender, Unity, and Three.js.

## Complete Example

### Python

```python
import time
import requests

API_KEY = "your_api_key_here"
BASE_URL = "https://openapi.tripo3d.ai/v3"

headers = {
    "Content-Type": "application/json",
    "Authorization": f"Bearer {API_KEY}"
}

# 1. Create a text-to-3D task
response = requests.post(
    f"{BASE_URL}/generation/text-to-model",
    headers=headers,
    json={
        "prompt": "a cute cat",
        "model": "tripo-v3.1"
    }
)
task_id = response.json()["data"]["task_id"]
print(f"Task created: {task_id}")

# 2. Poll until the task is complete
while True:
    response = requests.get(
        f"{BASE_URL}/tasks/{task_id}",
        headers={"Authorization": f"Bearer {API_KEY}"}
    )
    task = response.json()["data"]
    status = task["status"]
    progress = task.get("progress", 0)

    print(f"Status: {status}, progress: {progress}%")

    if status == "success":
        model_url = task["output"]["model_url"]
        print(f"Model download URL: {model_url}")
        break
    elif status in ("failed", "cancelled", "banned"):
        print(f"Task failed: {status}")
        break

    time.sleep(2)

# 3. Download the model file
if status == "success":
    model_data = requests.get(model_url)
    with open("model.glb", "wb") as f:
        f.write(model_data.content)
    print("Model saved as model.glb")
```

### JavaScript

```javascript
const API_KEY = "your_api_key_here";
const BASE_URL = "https://openapi.tripo3d.ai/v3";

async function generateModel() {
  // 1. Create a text-to-3D task
  const createResponse = await fetch(`${BASE_URL}/generation/text-to-model`, {
    method: "POST",
    headers: {
      "Content-Type": "application/json",
      "Authorization": `Bearer ${API_KEY}`
    },
    body: JSON.stringify({
      prompt: "a cute cat",
      model: "tripo-v3.1"
    })
  });
  const { data: { task_id } } = await createResponse.json();
  console.log(`Task created: ${task_id}`);

  // 2. Poll until the task is complete
  while (true) {
    const pollResponse = await fetch(`${BASE_URL}/tasks/${task_id}`, {
      headers: { "Authorization": `Bearer ${API_KEY}` }
    });
    const { data: task } = await pollResponse.json();
    const { status, progress = 0 } = task;

    console.log(`Status: ${status}, progress: ${progress}%`);

    if (status === "success") {
      console.log(`Model download URL: ${task.output.model_url}`);
      return task.output;
    }
    if (["failed", "cancelled", "banned"].includes(status)) {
      throw new Error(`Task failed: ${status}`);
    }

    await new Promise(resolve => setTimeout(resolve, 2000));
  }
}

generateModel().catch(console.error);
```
