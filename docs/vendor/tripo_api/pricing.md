# Tripo API Pricing (captured 2026-10-03 from https://developers.tripo3d.ai/en/pricing)

Simple, transparent pay-as-you-go pricing. Purchase credits and use them across all API operations.
1 credit = $0.01 USD. 100 credits = $1.00 USD.

## 3D Model Generation

### H Series
| Task | No texture | Standard texture |
|---|---|---|
| Text to 3D | 10 | 20 |
| Image to 3D | 20 | 30 |
| Multiview to 3D | 20 | 30 |

Add-ons (stacked on base credits): HD Texture +10 · 8K Ultra Texture +20 · HD Geometry Quality +20 · Quad Mesh +5 · Smart Low-poly +10 · Generate Parts +20

### P Series
| Task | No texture P1 | No texture P2 | Standard texture P1 | Standard texture P2 |
|---|---|---|---|---|
| Text to 3D | 30 | 100 | 40 | 110 |
| Image to 3D | 40 | 100 | 50 | 110 |
| Multiview to 3D | 40 | 100 | 50 | 110 |

P1 does not support quad, smart_low_poly, generate_parts, or geometry_quality.
P2 base is 100 credits; texture add-ons match P1 (standard +10). P2 face_limit: triangle 48–50,000; quad 48–25,000. P2 supports quad.

### Splat Series
Image to Gaussian Splat: 30

## Model Processing
| Operation | Credits |
|---|---|
| Texture (Fast) | 10 |
| Texture (Standard) | 10 |
| Texture (HD) | 20 |
| Texture (8K Ultra) | 30 |
| Format Convert (Basic) | 5 |
| Format Convert (Advanced) | 10 |
| Retopology (v2.0 Smart) | 30 |
| Retopology (v1.0 Basic) | 10 |
| Segmentation | 40 |
| Part Completion (Default) | 50 |
| Part Completion (Quick Cap) | 30 |
| Smart Segmentation (Image) | 85 |
| Smart Segmentation (Model) | 55 |

Triggers Advanced Convert pricing (any non-default value = 10 credits): quad, face_limit, flatten_bottom, flatten_bottom_threshold, texture_size, texture_format, pivot_to_center_bottom, scale_factor

## Animation
| Operation | Credits |
|---|---|
| Rig Check | Free |
| Auto Rig | 25 |
| Animation Retarget | 10 / animation |

## Image Generation
| Model | ≤1K | 2K | 4K |
|---|---|---|---|
| seedream_v5 / seedream_v4 | 5 | 5 | 5 |
| banana | 5 | — | — |
| banana2 | 10 | 10 | 15 |
| banana_pro | 15 | 15 | 20 |
| chat_image_1 (retiring 2026-10-23) | 5 | — | — |
| chat_image_1.5 (retiring 2026-12-01) | 10 | — | — |
| chat_image_2 | 10 | 10 | 15 |
| chat_image_2.5_flare | 10 | 10 | 15 |
| chat_image_2.5_sunburst | 10 | 10 | 15 |

GPT quality tiers: chat_image_2 · high 20/25/40 · chat_image_2.5_* · high 20/25/40 · xhigh 25/30/45 · max 30/50/50. Omitting quality, or low/medium, is billed at base price; auto not supported; size auto → 2K tier.
Image to Multiview: 10 · Edit Multiview: 5 / edited image

Enterprise: business@tripo3d.ai
