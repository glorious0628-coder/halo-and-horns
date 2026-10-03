# v2 to v3 Migration Guide

This document helps you migrate existing code from Tripo API v2 to v3.

## Move from V2 to V3 with the Skill

You do not need to understand every API difference first. Download this Skill, place it in the project directory you want to migrate, and ask your AI coding tool to use it. It will help find V2 calls in your project and migrate them to V3 step by step.

### Step 1: Download the Skill

<a class="plugin-download-button" href="/assets/developer/tripo-v2-to-v3-migration/SKILL.md" download="SKILL.md">Download</a>

You will get a file named `SKILL.md`. Keep the filename unchanged.

### Step 2: Place the Skill in your project and use it

Place the downloaded `SKILL.md` in the project directory you want to migrate. Then open the project and tell your AI to use this Skill.

### Step 3: Copy this prompt to start

Open the project you want to migrate. Copy the full prompt below and send it to your AI coding tool:

```text
Use the `SKILL.md` file in this project directory to move this project's Tripo API integration from V2 to V3. First show me what needs to change. Wait for my confirmation, then make the changes. Finally, use the checklist in the file to make sure nothing was missed.
```

The tool will first find the V2 calls and show you a plan, so you do not need to search every file yourself.

## Major Changes

### 1. Base URL Change

```
# v2
https://api.tripo3d.ai/v2/openapi/

# v3
https://openapi.tripo3d.ai/v3/
```

### 2. Universal Endpoint Split into Dedicated Endpoints

v2 uses a single `POST /v2/openapi/task` endpoint and a `type` field to distinguish task types. v3 provides a dedicated endpoint for each capability, so the `type` field is no longer required.

```json
// v2
POST /v2/openapi/task
{ "type": "text_to_model", "prompt": "a cat" }

// v3
POST /v3/generation/text-to-model
{ "prompt": "a cat" }
```

### 3. File Inputs Unified as the `input` Field

In v2, different field names are used depending on the input source, such as `file`, `file_token`, `url`, and `object`. In v3, they are unified under the `input` field, and the system automatically infers the input type.

```json
// v2 - different field names are required
{ "type": "refine_model", "draft_model_task_id": "task_abc123" }
{ "type": "convert_model", "original_model_task_id": "task_abc123" }

// v3 - use input consistently
{ "input": "task_abc123" }
{ "input": "https://example.com/model.glb" }
{ "input": "file_token_abc123" }
```

### 4. Standardized Field Names

| v2 Field | v3 Field |
| :-: | :-: |
| `create_time` | `created_at` |
| `consumed_credit` | `credits_consumed` |

### 5. Text-to-Image and Image-to-Image Split

In v2, text-to-image and image-to-image share the same API. In v3, they are split into dedicated endpoints:

- `POST /v3/generation/text-to-image` - Generate an image from text-only input
- `POST /v3/generation/image-to-image` - Generate or edit an image based on a reference image

## Endpoint Mapping

### Generation

| v2 type Value | v3 Endpoint |
| :-: | :-: |
| `text_to_model` | `POST /v3/generation/text-to-model` |
| `image_to_model` | `POST /v3/generation/image-to-model` |
| `multiview_to_model` | `POST /v3/generation/multiview-to-model` |
| `text_to_image` | `POST /v3/generation/text-to-image` |
| `generate_image` | `POST /v3/generation/image-to-image` |
| `generate_multiview_image` | `POST /v3/generation/image-to-multiview` |
| `edit_multiview_image` | `POST /v3/generation/edit-multiview` |

### Model Processing

| v2 type Value | v3 Endpoint |
| :-: | :-: |
| `refine_model` | `POST /v3/models/refine` |
| `convert_model` | `POST /v3/models/convert` |
| `import_model` | `POST /v3/models/import` |
| `stylize_model` | `POST /v3/models/stylize` |
| `texture_model` | `POST /v3/models/texture` |

### Animation

| v2 type Value | v3 Endpoint |
| :-: | :-: |
| `animate_prerigcheck` | `POST /v3/animations/rig-check` |
| `animate_rig` | `POST /v3/animations/rig` |
| `animate_retarget` | `POST /v3/animations/retarget` |

### Mesh Editing

| v2 type Value | v3 Endpoint |
| :-: | :-: |
| `mesh_segmentation` | `POST /v3/mesh/segment` |
| `mesh_completion` | `POST /v3/mesh/complete` |
| `highpoly_to_lowpoly` | `POST /v3/mesh/decimate` |

### Tasks and Files

| v2 Endpoint | v3 Endpoint |
| :-: | :-: |
| `GET /v2/openapi/task/{task_id}` | `GET /v3/tasks/{task_id}` |
| `POST /v2/openapi/upload` | `POST /v3/files` |

## Migration Steps

### Step 1: Update the Base URL

```python
# v2
BASE_URL = "https://api.tripo3d.ai/v2/openapi"

# v3
BASE_URL = "https://openapi.tripo3d.ai/v3"
```

### Step 2: Replace Endpoints Using the Mapping Table

```python
# v2
response = requests.post(f"{BASE_URL}/task", json={
    "type": "text_to_model",
    "prompt": "a cat"
})

# v3
response = requests.post(f"{BASE_URL}/generation/text-to-model", json={
    "prompt": "a cat"
})
```

### Step 3: Remove the `type` Field

In v3, the endpoint path already implies the task type, so the request body no longer needs the `type` field.

### Step 4: Replace Input Fields with `input`

```python
# v2 - different task types use different field names
payload = {"type": "refine_model", "draft_model_task_id": "task_abc123"}
payload = {"type": "convert_model", "original_model_task_id": "task_abc123"}

# v3 - use input consistently
payload = {"input": "task_abc123"}
```

### Step 5: Update Response Field Names

```python
# v2
created = task["create_time"]
cost = task["consumed_credit"]

# v3
created = task["created_at"]
cost = task["credits_consumed"]
```

### Step 6: Test and Validate

1. Replace and test each endpoint one at a time
2. Verify that task creation and polling work correctly
3. Confirm that download links are available
4. Check that credit deduction and balance queries work correctly

## Notes

- v2 and v3 can run in parallel. We recommend migrating gradually instead of switching all at once
- API Keys are shared between v2 and v3. You do not need to create new keys
- The task ID format remains unchanged. Tasks created in v2 can be queried in v3
