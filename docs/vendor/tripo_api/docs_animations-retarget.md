# Animation Retargeting

**Base URL:** `https://openapi.tripo3d.ai/v3`

**Endpoint:** `POST /animations/retarget`

Apply a preset animation to a rigged 3D model.

## Request Parameters

### input

- **Type:** string
- **Required:** Required

task_id of the rigged model, starting with `task_`.
### animation

- **Type:** string
- **Required:** Conditional

Single preset animation identifier.**Mutually exclusive with `animations` — provide only one.**


Rig v2.5-20260210 — All rig types


- Biped: `preset:idle`, `preset:walk`, `preset:run`, `preset:dive`, `preset:climb`, `preset:jump`, `preset:slash`, `preset:shoot`, `preset:hurt`, `preset:fall`, `preset:turn`
- Quadruped: `preset:quadruped:walk`
- Others: `preset:hexapod:walk`, `preset:octopod:walk`, `preset:serpentine:march`, `preset:aquatic:march`
Rig v1.0-20240301 — Biped only (90+ presets, click to expand)`preset:biped:afraid``preset:biped:agree``preset:biped:angry_01``preset:biped:angry_02``preset:biped:angry_03``preset:biped:basketball_shot``preset:biped:bow``preset:biped:box_01``preset:biped:box_02``preset:biped:box_03``preset:biped:cast_a_spell``preset:biped:cheer``preset:biped:chop``preset:biped:clap``preset:biped:climb``preset:biped:complain_01``preset:biped:complain_02``preset:biped:cross_body_crunch``preset:biped:crossover_dribble``preset:biped:cry``preset:biped:dance_01``preset:biped:dance_02``preset:biped:dance_03``preset:biped:dance_04``preset:biped:dance_05``preset:biped:dance_06``preset:biped:defeat_02``preset:biped:defeat_03``preset:biped:depressed``preset:biped:dig``preset:biped:dive``preset:biped:dribble``preset:biped:fall``preset:biped:fire``preset:biped:flee_01``preset:biped:flee_02``preset:biped:flip``preset:biped:fold_arms``preset:biped:football_catch``preset:biped:football_save``preset:biped:football_pass``preset:biped:freaky``preset:biped:frightened``preset:biped:front_kick_01``preset:biped:front_kick_02``preset:biped:frustrated_01``preset:biped:frustrated_02``preset:biped:golf``preset:biped:greet_01``preset:biped:greet_02``preset:biped:greet_03``preset:biped:greet_04``preset:biped:heart_pose``preset:biped:hit_to_body_01``preset:biped:hit_to_body_02``preset:biped:hit_to_head``preset:biped:hit_to_side``preset:biped:hit_to_stomach``preset:biped:hug``preset:biped:hurt``preset:biped:idle``preset:biped:jump_down``preset:biped:jump``preset:biped:jump_rope_01``preset:biped:jump_rope_02``preset:biped:laugh_01``preset:biped:laugh_02``preset:biped:lift_heavy``preset:biped:look_around``preset:biped:make_a_call_01``preset:biped:make_a_call_02``preset:biped:pitch_baseball``preset:biped:play_mobile_game``preset:biped:play_video_game``preset:biped:press-up``preset:biped:run_upstairs``preset:biped:run``preset:biped:scared_01``preset:biped:scared_02``preset:biped:scratch``preset:biped:shoot``preset:biped:shovel``preset:biped:sing_01``preset:biped:sing_02``preset:biped:sing_03``preset:biped:sing_04``preset:biped:sit``preset:biped:slash``preset:biped:sob``preset:biped:standing_relax``preset:biped:surf``preset:biped:swagger``preset:biped:swim``preset:biped:turn``preset:biped:victory_celebration``preset:biped:volleyball``preset:biped:wait``preset:biped:walk``preset:biped:warm_up``preset:biped:wave_goodbye_01``preset:biped:wave_goodbye_02`

### animations

- **Type:** string[]
- **Required:** Conditional

List of multiple preset animation identifiers.**Mutually exclusive with `animation` — provide only one.**

### out_format

- **Type:** string
- **Required:** Optional
- **Default:** `glb`

Output format.
- `glb` — binary glTF, web-ready.
- `fbx` — FBX for DCC tools and game engines.

### bake_animation

- **Type:** boolean
- **Required:** Optional
- **Default:** `true`

Bake animation into the model. Only effective for `glb` output.
### export_with_geometry

- **Type:** boolean
- **Required:** Optional
- **Default:** `true`

Export with geometry included.
### animate_in_place

- **Type:** boolean
- **Required:** Optional
- **Default:** `false`

Play animation in place without displacement.

## Request Example

### Single

```bash
curl --request POST \
  --url https://openapi.tripo3d.ai/v3/animations/retarget \
  --header 'Authorization: Bearer <token>' \
  --header 'Content-Type: application/json' \
  --data '{
  "input": "task_abc123",
  "animation": "preset:walk",
  "out_format": "glb",
  "bake_animation": true
}'
```

### Batch

```bash
curl --request POST \
  --url https://openapi.tripo3d.ai/v3/animations/retarget \
  --header 'Authorization: Bearer <token>' \
  --header 'Content-Type: application/json' \
  --data '{
  "input": "task_abc123",
  "animations": [
    "preset:idle",
    "preset:walk",
    "preset:run"
  ],
  "out_format": "fbx"
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
    "status": "success",
    "output": {
      "model_url": "https://cdn.tripo3d.ai/output/animated.glb"
    },
    "credits_consumed": 20.00
  }
}
```
