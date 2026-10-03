# ComfyUI Nodes

ComfyUI-Tripo is Tripo's official custom-node extension for ComfyUI. It supports generating 3D models from text, a single image, or multiview images within ComfyUI workflows, along with model import, texturing, refinement, mesh processing, low-poly optimization, stylization, rigging, animation retargeting, format conversion, and retopology.

| Item | Value |
| --- | --- |
| Node package version | <code>1.3.0</code> |
| Source tag | <code>v1.3.1.1</code> |
| Source | [VAST-AI-Research/ComfyUI-Tripo](https://github.com/VAST-AI-Research/ComfyUI-Tripo) |

## Capabilities and changelog

### Capabilities

- Generate 3D models from text prompts.
- Generate 3D models from images.
- Import models from a URL through <code>model_url</code>.
- Support splitting models into separate parts.
- Rig and animate 3D models.
- Convert formats and retopologize models.

### Changelog

- 2026-06-30: added Mesh Segmentation v2.0 for splitting models into separate parts and direct URL import through <code>model_url</code>.
- 2026-05-28: added model import.
- 2025-06-19: updated to the newest API and added more nodes.
- 2025-03-31: switched to the <code>tripo3d</code> package.
- 2025-02-24: removed <code>glbviewer</code>.
- 2025-02-01: adapted to the new API and switched model viewing to Preview 3D.
- 2024-11-11: adapted to the new API.
- 2024-10-14: added model conversion.
- 2024-09-13: added support for <code>model_version</code> <code>v2.0-20240919</code>.

## Installation

**Choose one** method, then restart ComfyUI.

### ComfyUI-Manager

Open [Custom Nodes Manager](https://github.com/ltdrdata/ComfyUI-Manager), search for <code>Tripo for ComfyUI</code>, and install it.

### comfy-cli

Install [comfy-cli](https://github.com/Comfy-Org/comfy-cli) through [Comfy Registry](https://registry.comfy.org/), then run:

~~~bash
comfy node registry-install comfyui-tripo
~~~

### From source

Place the repository in <code>ComfyUI/custom_nodes/ComfyUI-Tripo</code>, then install its dependencies:

~~~bash
cd ComfyUI/custom_nodes
git clone https://github.com/VAST-AI-Research/ComfyUI-Tripo.git
python -m pip install -r ComfyUI-Tripo/requirements.txt
~~~

## API key configuration

Create an API key on the [Tripo platform](https://platform.tripo3d.ai/), then configure it with one of the methods below.

The node package resolves an API key in this order:

1. A non-empty <code>apikey</code> input on the node.
2. The <code>TRIPO_API_KEY</code> environment variable.
3. <code>config.json</code> in the ComfyUI-Tripo directory, with a <code>TRIPO_API_KEY</code> field.

The Generate and Import nodes expose <code>apikey</code>. Downstream nodes receive the resolved key through <code>MODEL_INFO</code>.

Do not expose a real API key in screenshots, shared workflows, logs, or source repositories. Clear the <code>apikey</code> field before sharing a workflow and prefer an environment variable for local use.

### Environment variable launch examples

Windows:

~~~shell
set TRIPO_API_KEY=tsk_XXXXXXX
python.exe main.py [--cpu]
~~~

Linux or macOS:

~~~bash
TRIPO_API_KEY=tsk_XXXXXXX python main.py [--cpu]
~~~

## Node overview

ComfyUI-Tripo provides the following 11 Tripo nodes:

| Internal ID | Display name | Capability | Output |
| --- | --- | --- | --- |
| <code>TripoAPIDraft</code> | Tripo: Generate model | Generate from text, image, or multiple views | <code>model_file</code>, <code>MODEL_INFO</code> |
| <code>TripoImportModel</code> | Tripo: Import model | Import a local model or model URL | <code>MODEL_INFO</code> |
| <code>TripoTextureModel</code> | Tripo: Texture model | Texture a model | <code>model_file</code>, <code>MODEL_INFO</code> |
| <code>TripoRefineModel</code> | Tripo: Refine Draft model | Refine a draft model | <code>model_file</code>, <code>MODEL_INFO</code> |
| <code>TripoMeshSegmentation</code> | Tripo: Segment mesh | Segment a mesh | <code>model_file</code>, <code>MODEL_INFO</code> |
| <code>TripoMeshCompletion</code> | Tripo: Complete mesh | Complete a segmented mesh | <code>model_file</code>, <code>MODEL_INFO</code> |
| <code>TripoSmartLowPoly</code> | Tripo: Smart low poly | Create a low-poly model | <code>model_file</code>, <code>MODEL_INFO</code> |
| <code>TripoStylizeModel</code> | Tripo: Stylize model | Apply a geometric style | <code>model_file</code>, <code>MODEL_INFO</code> |
| <code>TripoAnimateRigNode</code> | Tripo: Rig model | Automatically rig a model | <code>model_file</code>, <code>MODEL_INFO</code> |
| <code>TripoAnimateRetargetNode</code> | Tripo: Retarget rigged model | Apply a preset animation | <code>model_file</code>, <code>MODEL_INFO</code> |
| <code>TripoConvertNode</code> | Tripo: Convert model | Convert and export a model | <code>model_file</code> |

Preview 3D is provided by ComfyUI and is not one of these 11 nodes.

## Connections and data flow

~~~mermaid
flowchart LR
    G["Generate model"] -->|MODEL_INFO| P["Model processing"]
    I["Import model"] -->|MODEL_INFO| P
    P -->|MODEL_INFO| R["Rig model"]
    R -->|MODEL_INFO| A["Retarget rigged model"]
    A -->|MODEL_INFO| C["Convert model"]
~~~

- <code>model_file</code> is the downloaded path produced by a generation or processing task. It can be sent to a ComfyUI preview or file-handling node.
- <code>MODEL_INFO</code> contains the Tripo task context used by downstream Tripo nodes: <code>task_id</code>, resolved <code>apikey</code>, <code>file_prefix</code>, and <code>output_directory</code>.
- A model from outside this node chain must first pass through <code>TripoImportModel</code>. A file path alone cannot replace <code>MODEL_INFO</code>.
- Connect nodes through <code>MODEL_INFO</code> when further Tripo processing is required. The <code>model_file</code> output is not the processing context.

## Complete node reference

“Required” indicates whether a node parameter must be provided. The <code>apikey</code> field may be left empty to use the environment or configuration fallback. A dash means no explicit default is set.

### Generation and import

### TripoAPIDraft — Tripo: Generate model

Creates the first Tripo task in a workflow. It has no node prerequisite.

| Input | Type | Required | Default | Values or range |
| --- | --- | --- | --- | --- |
| <code>mode</code> | ENUM | Yes | first value | <code>text_to_model</code>, <code>image_to_model</code>, <code>multiview_to_model</code> |
| <code>apikey</code> | STRING | Yes | empty | API key or fallback |
| <code>prompt</code> | STRING, multiline | No | empty | Text prompt |
| <code>negative_prompt</code> | STRING, multiline | No | empty | Negative text prompt |
| <code>image</code> | IMAGE | No | — | Source image; front image in multiview mode |
| <code>image_left</code> | IMAGE | No | — | Optional left view |
| <code>image_back</code> | IMAGE | No | — | Optional back view |
| <code>image_right</code> | IMAGE | No | — | Optional right view |
| <code>model_version</code> | ENUM | No | <code>v3.1-20260211</code> | <code>v1.4-20240625</code>, <code>v2.0-20240919</code>, <code>v2.5-20250123</code>, <code>v3.0-20250812</code>, <code>v3.1-20260211</code> |
| <code>texture</code> | BOOLEAN | No | <code>true</code> | Enable texture generation |
| <code>pbr</code> | BOOLEAN | No | <code>true</code> | Enable PBR maps |
| <code>image_seed</code> | INT | No | <code>42</code> | Used by text mode |
| <code>model_seed</code> | INT | No | <code>42</code> | Model seed |
| <code>texture_seed</code> | INT | No | <code>42</code> | Texture seed |
| <code>texture_quality</code> | ENUM | No | <code>standard</code> | <code>standard</code>, <code>detailed</code> |
| <code>geometry_quality</code> | ENUM | No | <code>standard</code> | <code>standard</code>, <code>detailed</code>; image mode only |
| <code>texture_alignment</code> | ENUM | No | <code>original_image</code> | <code>original_image</code>, <code>geometry</code> |
| <code>face_limit</code> | INT | No | <code>-1</code> | <code>-1</code>–<code>500000</code>; values ≤ 0 are sent as unset |
| <code>quad</code> | BOOLEAN | No | <code>false</code> | Request quad topology |
| <code>compress</code> | BOOLEAN | No | <code>false</code> | Compress output |
| <code>generate_parts</code> | BOOLEAN | No | <code>false</code> | Generate parts |
| <code>smart_low_poly</code> | BOOLEAN | No | <code>false</code> | Enable smart low-poly generation |
| <code>auto_size</code> | BOOLEAN | No | <code>false</code> | Automatically size the model |
| <code>orientation</code> | ENUM | No | <code>default</code> | <code>default</code>, <code>align_image</code>; image and multiview modes |
| <code>file_prefix</code> | STRING | No | empty | Prefix for the downloaded filename |
| <code>output_directory</code> | STRING | No | empty | Destination directory override |

Mode requirements:

| Mode | Conditionally required | Notes |
| --- | --- | --- |
| <code>text_to_model</code> | <code>prompt</code> | Fails with “Prompt is required” when empty |
| <code>image_to_model</code> | <code>image</code> | Fails with “Image is required” when absent |
| <code>multiview_to_model</code> | <code>image</code> | <code>image</code> is the front view; left, back, and right are optional |

Outputs: STRING <code>model_file</code> and <code>MODEL_INFO</code>. Common failures: missing conditional input, missing/invalid API key, rejected API task, or output move failure. Minimum connection: prompt or image → <code>TripoAPIDraft</code> → Preview 3D; use <code>MODEL_INFO</code> for later processing.

### TripoImportModel — Tripo: Import model

Creates Tripo task context for a model that did not originate in this node chain.

| Input | Type | Required | Default | Values or range |
| --- | --- | --- | --- | --- |
| <code>apikey</code> | STRING | Yes | empty | API key or fallback |
| <code>model_file</code> | file selector | No | <code>none</code> | Model in the ComfyUI input directory |
| <code>model_url</code> | STRING | No | empty | Direct URL to a model |
| <code>file_prefix</code> | STRING | No | empty | Prefix propagated to downstream downloads |
| <code>output_directory</code> | STRING | No | empty | Directory propagated to downstream downloads |

A non-empty <code>model_url</code> takes priority over <code>model_file</code>. If both are empty, the node fails. The upload control accepts <code>.glb</code>, <code>.fbx</code>, <code>.obj</code>, <code>.stl</code>, <code>.ply</code>, <code>.3mf</code>, and <code>.gltf</code>; the backend input scan also recognizes <code>.zip</code>.

Output: <code>MODEL_INFO</code> only. Common failures: neither source is provided, a local file is missing, the URL cannot be fetched, the format is rejected, or the import task fails. Minimum connection: local file or URL → <code>TripoImportModel</code> → any processor that accepts <code>MODEL_INFO</code>.

### Model processing

### TripoTextureModel — Tripo: Texture model

Requires <code>MODEL_INFO</code> from Generate, Import, or another compatible processor.

| Input | Type | Required | Default | Values or range |
| --- | --- | --- | --- | --- |
| <code>model_info</code> | MODEL_INFO | Yes | — | Upstream task context |
| <code>model_version</code> | ENUM | No | <code>v3.0-20250812</code> | <code>v2.5-20250123</code>, <code>v3.0-20250812</code> |
| <code>texture</code> | BOOLEAN | No | <code>true</code> | Enable texture |
| <code>pbr</code> | BOOLEAN | No | <code>true</code> | Enable PBR maps |
| <code>texture_seed</code> | INT | No | <code>42</code> | Texture seed |
| <code>texture_quality</code> | ENUM | No | <code>standard</code> | <code>standard</code>, <code>detailed</code> |
| <code>texture_alignment</code> | ENUM | No | <code>original_image</code> | <code>original_image</code>, <code>geometry</code> |
| <code>text_prompt</code> | STRING, multiline | No | empty | Texture guidance text |
| <code>image_prompt</code> | IMAGE | No | — | Texture reference |
| <code>style_image</code> | IMAGE | No | — | Style reference |
| <code>part_names</code> | STRING, multiline | No | empty | One part name per line |
| <code>compress</code> | BOOLEAN | No | <code>false</code> | Compress output |
| <code>bake</code> | BOOLEAN | No | <code>true</code> | Bake texture |

Outputs: STRING <code>model_file</code> and <code>MODEL_INFO</code>. Common failures: incompatible task context, invalid reference image, or API task failure. Minimum connection: Generate/Import <code>MODEL_INFO</code> → <code>TripoTextureModel</code> → Preview 3D or another processor.

### TripoRefineModel — Tripo: Refine Draft model

| Input | Type | Required | Default | Values or range |
| --- | --- | --- | --- | --- |
| <code>model_info</code> | MODEL_INFO | Yes | — | Draft-model task context |

Outputs: STRING <code>model_file</code> and <code>MODEL_INFO</code>. The upstream task must be a refinable draft; an incompatible task or failed API task causes failure. Minimum connection: Generate draft <code>MODEL_INFO</code> → <code>TripoRefineModel</code> → Preview 3D.

### TripoMeshSegmentation — Tripo: Segment mesh

| Input | Type | Required | Default | Values or range |
| --- | --- | --- | --- | --- |
| <code>model_info</code> | MODEL_INFO | Yes | — | Upstream task context |
| <code>model_version</code> | ENUM | Yes | <code>v1.0-20250506</code> | <code>v1.0-20250506</code>, <code>v2.0-20260430</code> |
| <code>segmentation_granularity</code> | ENUM | No | <code>balanced</code> | <code>simple</code>, <code>balanced</code>, <code>detailed</code> |
| <code>ref_image</code> | IMAGE | No | — | Segmentation reference image |
| <code>split_by_connectivity</code> | BOOLEAN | No | <code>true</code> | Split disconnected geometry |

<code>segmentation_granularity</code>, <code>ref_image</code>, and <code>split_by_connectivity</code> are sent only with <code>v2.0-20260430</code>; v1 ignores them. Outputs: STRING <code>model_file</code> and <code>MODEL_INFO</code>. Common failures: incompatible model, invalid reference image, or API task failure. Minimum connection: Generate/Import <code>MODEL_INFO</code> → <code>TripoMeshSegmentation</code> → Completion or Preview 3D.

### TripoMeshCompletion — Tripo: Complete mesh

| Input | Type | Required | Default | Values or range |
| --- | --- | --- | --- | --- |
| <code>model_info</code> | MODEL_INFO | Yes | — | Segmented-model task context |
| <code>model_version</code> | ENUM | Yes | <code>v1.0-20250506</code> | <code>v1.0-20250506</code> |
| <code>part_names</code> | STRING, multiline | No | empty | One part name per line |

Outputs: STRING <code>model_file</code> and <code>MODEL_INFO</code>. A task that is not suitable for completion or a failed API task causes failure. Minimum connection: Segment <code>MODEL_INFO</code> → <code>TripoMeshCompletion</code> → Preview 3D.

### TripoSmartLowPoly — Tripo: Smart low poly

| Input | Type | Required | Default | Values or range |
| --- | --- | --- | --- | --- |
| <code>model_info</code> | MODEL_INFO | Yes | — | Upstream task context |
| <code>model_version</code> | ENUM | Yes | <code>P-v2.0-20251225</code> | <code>P-v2.0-20251225</code> |
| <code>quad</code> | BOOLEAN | No | <code>false</code> | Request quad topology |
| <code>part_names</code> | STRING, multiline | No | empty | One part name per line |
| <code>face_limit</code> | INT | No | <code>10000</code> | <code>-1</code>–<code>20000</code> |
| <code>bake</code> | BOOLEAN | No | <code>true</code> | Bake output |

Outputs: STRING <code>model_file</code> and <code>MODEL_INFO</code>. Common failures: incompatible model/parts or API task failure. Minimum connection: Generate/Import <code>MODEL_INFO</code> → <code>TripoSmartLowPoly</code> → Preview 3D or Convert.

### TripoStylizeModel — Tripo: Stylize model

| Input | Type | Required | Default | Values or range |
| --- | --- | --- | --- | --- |
| <code>model_info</code> | MODEL_INFO | Yes | — | Upstream task context |
| <code>style</code> | ENUM | Yes | first value | <code>lego</code>, <code>voxel</code>, <code>voronoi</code>, <code>minecraft</code> |
| <code>block_size</code> | INT | Yes | <code>80</code> | <code>1</code>–<code>1000</code> |

Outputs: STRING <code>model_file</code> and <code>MODEL_INFO</code>. Common failures: incompatible model, unsupported style for the task, or API task failure. Minimum connection: Generate/Import <code>MODEL_INFO</code> → <code>TripoStylizeModel</code> → Preview 3D.

### Rigging and animation

### TripoAnimateRigNode — Tripo: Rig model

The node checks whether the model is riggable and obtains a rig type before submitting the rig task.

| Input | Type | Required | Default | Values or range |
| --- | --- | --- | --- | --- |
| <code>model_info</code> | MODEL_INFO | Yes | — | Upstream task context |
| <code>model_version</code> | ENUM | Yes | <code>v2.0-20250506</code> | <code>v1.0-20240301</code>, <code>v2.0-20250506</code> |
| <code>out_format</code> | ENUM | Yes | <code>glb</code> | <code>glb</code>, <code>fbx</code> |
| <code>spec</code> | ENUM | Yes | <code>tripo</code> | <code>mixamo</code>, <code>tripo</code> |

Outputs: STRING <code>model_file</code> and <code>MODEL_INFO</code>. It fails when the model cannot be rigged, no suitable rig type is found, or the API task fails. Minimum connection: Generate/Import <code>MODEL_INFO</code> → <code>TripoAnimateRigNode</code> → Retarget or Preview 3D.

### TripoAnimateRetargetNode — Tripo: Retarget rigged model

Requires <code>MODEL_INFO</code> from a successfully rigged model.

| Input | Type | Required | Default | Values or range |
| --- | --- | --- | --- | --- |
| <code>model_info</code> | MODEL_INFO | Yes | — | Rigged-model task context |
| <code>animation</code> | ENUM | Yes | first value | See all 16 presets below |
| <code>out_format</code> | ENUM | Yes | <code>glb</code> | <code>glb</code>, <code>fbx</code> |
| <code>bake_animation</code> | BOOLEAN | No | <code>true</code> | Bake the animation |
| <code>export_with_geometry</code> | BOOLEAN | No | <code>false</code> | Include geometry in export |

The 16 animation values are: <code>preset:idle</code>, <code>preset:walk</code>, <code>preset:run</code>, <code>preset:dive</code>, <code>preset:climb</code>, <code>preset:jump</code>, <code>preset:slash</code>, <code>preset:shoot</code>, <code>preset:hurt</code>, <code>preset:fall</code>, <code>preset:turn</code>, <code>preset:quadruped:walk</code>, <code>preset:hexapod:walk</code>, <code>preset:octopod:walk</code>, <code>preset:serpentine:march</code>, and <code>preset:aquatic:march</code>.

Outputs: STRING <code>model_file</code> and <code>MODEL_INFO</code>. An unrigged/incompatible task or failed API task causes failure. Minimum connection: Rig <code>MODEL_INFO</code> → <code>TripoAnimateRetargetNode</code> → Preview 3D or Convert.

### Format output

### TripoConvertNode — Tripo: Convert model

This is an output node and returns no <code>MODEL_INFO</code>.

| Input | Type | Required | Default | Values or range |
| --- | --- | --- | --- | --- |
| <code>model_info</code> | MODEL_INFO | Yes | — | Upstream task context |
| <code>format</code> | ENUM | Yes | first value | <code>GLTF</code>, <code>USDZ</code>, <code>FBX</code>, <code>OBJ</code>, <code>STL</code>, <code>3MF</code> |
| <code>quad</code> | BOOLEAN | No | <code>false</code> | Request quad topology |
| <code>force_symmetry</code> | BOOLEAN | No | <code>false</code> | Force symmetry |
| <code>face_limit</code> | INT | No | <code>-1</code> | <code>-1</code>–<code>500000</code> |
| <code>flatten_bottom</code> | BOOLEAN | No | <code>false</code> | Flatten the bottom |
| <code>flatten_bottom_threshold</code> | FLOAT | No | <code>0.01</code> | <code>0.0</code>–<code>1.0</code> |
| <code>texture_size</code> | INT | No | <code>4096</code> | <code>128</code>–<code>4096</code> |
| <code>texture_format</code> | ENUM | No | <code>JPEG</code> | <code>BMP</code>, <code>DPX</code>, <code>HDR</code>, <code>JPEG</code>, <code>OPEN_EXR</code>, <code>PNG</code>, <code>TARGA</code>, <code>TIFF</code>, <code>WEBP</code> |
| <code>pivot_to_center_bottom</code> | BOOLEAN | No | <code>false</code> | Move pivot to center-bottom |
| <code>scale_factor</code> | FLOAT | No | <code>1.0</code> | Minimum <code>0</code> |
| <code>with_animation</code> | BOOLEAN | No | <code>true</code> | Preserve animation |
| <code>pack_uv</code> | BOOLEAN | No | <code>false</code> | Pack UVs |
| <code>bake</code> | BOOLEAN | No | <code>true</code> | Bake output |
| <code>part_names</code> | STRING, multiline | No | empty | One part name per line |
| <code>fbx_preset</code> | ENUM | No | <code>blender</code> | <code>blender</code>, <code>mixamo</code>, <code>3dsmax</code> |
| <code>export_vertex_colors</code> | BOOLEAN | No | <code>false</code> | Export vertex colors |
| <code>export_orientation</code> | ENUM | No | <code>+x</code> | <code>+x</code>, <code>+y</code>, <code>-x</code>, <code>-y</code> |
| <code>animate_in_place</code> | BOOLEAN | No | <code>false</code> | Export animation in place |

Output: STRING <code>model_file</code>. Common failures: unsupported conversion for the source task, invalid export settings, or API/output move failure. Minimum connection: any compatible <code>MODEL_INFO</code> → <code>TripoConvertNode</code>.

## Workflow examples

Preview 3D is shown as an optional ComfyUI viewer and is not included in the Tripo node count.

~~~mermaid
flowchart LR
    T["Text"] --> GT["Generate model<br/>mode: text_to_model"]
    IM["Image"] --> GI["Generate model<br/>mode: image_to_model"]
    MV["Front + optional views"] --> GM["Generate model<br/>mode: multiview_to_model"]
    GT --> V["Preview 3D"]
    GI --> V
    GM --> V
~~~

1. **Text to Model:** provide <code>prompt</code>, select <code>text_to_model</code>, then send <code>model_file</code> to Preview 3D.
2. **Image to Model:** connect an IMAGE to <code>image</code>, select <code>image_to_model</code>, then preview <code>model_file</code>.
3. **Multiview to Model:** connect the front image to <code>image</code> and optional views to <code>image_left</code>, <code>image_back</code>, and <code>image_right</code>.
4. **Texture Model:** Generate or Import → connect <code>MODEL_INFO</code> to Texture → preview the new <code>model_file</code>.
5. **Refine Model:** Generate a compatible draft → connect <code>MODEL_INFO</code> to Refine → preview the refined file.
6. **Rig and Retarget:** Generate or Import → Rig → Retarget; use <code>MODEL_INFO</code> for both links, then preview or Convert.
7. **Import and Process:** local file or URL → Import → Segment/Smart low poly/Stylize/Texture. Import returns context, not a preview file.
8. **Convert and Export:** connect the final <code>MODEL_INFO</code> from Generate, Import, processing, Rig, or Retarget to Convert and choose the output format.

### Official workflow PNGs

The six PNG files below contain embedded ComfyUI workflow data. Save an original PNG with its download link, then drag it into ComfyUI or load it manually. Values visible in the images are workflow examples; use the parameter tables above for current defaults.

#### Text to Mesh

![ComfyUI text-to-mesh workflow connecting Tripo Generate model to Preview 3D](/assets/images/docs/comfyui-nodes/text_to_model.png)

Generate a model from a text prompt and send <code>model_file</code> to Preview 3D.

<a href="/assets/images/docs/comfyui-nodes/text_to_model.png" download>Download the original workflow PNG</a>

#### Image to Mesh

![ComfyUI image-to-mesh workflow connecting Load Image, Tripo Generate model, and Preview 3D](/assets/images/docs/comfyui-nodes/image_to_model.png)

Load an image, connect it to Generate model in <code>image_to_model</code> mode, and preview the result.

<a href="/assets/images/docs/comfyui-nodes/image_to_model.png" download>Download the original workflow PNG</a>

#### Multiview Images to Mesh

![ComfyUI multiview workflow connecting three Load Image nodes to Tripo Generate model and Preview 3D](/assets/images/docs/comfyui-nodes/multiview_to_model.png)

Connect the front and optional side views to Generate model in <code>multiview_to_model</code> mode.

<a href="/assets/images/docs/comfyui-nodes/multiview_to_model.png" download>Download the original workflow PNG</a>

#### Texture a generated model

![ComfyUI workflow connecting Generate model to Texture model with before and after Preview 3D nodes](/assets/images/docs/comfyui-nodes/texture_model.png)

Pass <code>MODEL_INFO</code> from Generate model to Texture model and preview both outputs.

<a href="/assets/images/docs/comfyui-nodes/texture_model.png" download>Download the original workflow PNG</a>

#### Refine a draft Mesh

![ComfyUI workflow connecting a draft Generate model task to Refine Draft model and Preview 3D](/assets/images/docs/comfyui-nodes/refine_model.png)

Generate a compatible draft, pass its <code>MODEL_INFO</code> to Refine Draft model, and preview the refined file.

<a href="/assets/images/docs/comfyui-nodes/refine_model.png" download>Download the original workflow PNG</a>

#### Animation / Rig and export

![ComfyUI workflow connecting Generate model, Rig model, Preview 3D, and Convert model](/assets/images/docs/comfyui-nodes/retarget.png)

<a href="/assets/images/docs/comfyui-nodes/retarget.png" download>Download the original workflow PNG</a>

## Output and troubleshooting

By default, downloaded models are written to <code>ComfyUI/output</code>. Generate and Import establish <code>file_prefix</code> and <code>output_directory</code>; that metadata is propagated through downstream <code>MODEL_INFO</code>. A non-empty prefix is prepended to the downloaded filename. A non-empty directory moves the downloaded file to that directory and creates it when needed.

| Symptom | Check |
| --- | --- |
| <code>TRIPO API key is required</code> | Set a non-empty node key, <code>TRIPO_API_KEY</code>, or the field in <code>config.json</code>. |
| Prompt/front image is required | Match <code>mode</code> with its conditionally required input. |
| Import does not start | Provide a reachable <code>model_url</code> or an existing <code>model_file</code>; URL has priority. |
| Model cannot be rigged | Try a suitable character model; Rig stops when the riggable check fails or returns no rig type. |
| API task fails | Read the reported <code>error_code</code> and <code>error_msg</code>; also verify account access and balance. |
| Output cannot be moved | Check that <code>output_directory</code> is valid and writable and that the source file still exists. |
| Nodes do not appear | Restart ComfyUI, verify the repository directory, and install <code>requirements.txt</code>. |
| Import upload button fails | Verify the extension listed by the upload control and inspect the ComfyUI upload response. |
