"""Strict, Blender-independent checks for bone-weight based R15 preparation."""

import math
import re


class RigError(ValueError):
    pass


PRIMARY = {
    "LowerTorso": "Hips", "UpperTorso": "Spine1", "Head": "Head",
    "LeftUpperArm": "LeftArm", "LeftLowerArm": "LeftForeArm", "LeftHand": "LeftHand",
    "RightUpperArm": "RightArm", "RightLowerArm": "RightForeArm", "RightHand": "RightHand",
    "LeftUpperLeg": "LeftUpLeg", "LeftLowerLeg": "LeftLeg", "LeftFoot": "LeftFoot",
    "RightUpperLeg": "RightUpLeg", "RightLowerLeg": "RightLeg", "RightFoot": "RightFoot",
}
REGION = {bone.lower(): part for part, bone in PRIMARY.items()}
REGION.update({"spine": "LowerTorso", "spine2": "UpperTorso", "neck": "UpperTorso",
               "leftshoulder": "UpperTorso", "rightshoulder": "UpperTorso"})
JOINTS = [
    ("Root", "HumanoidRootPart", "LowerTorso", "Hips"),
    ("Waist", "LowerTorso", "UpperTorso", "Spine1"),
    ("Neck", "UpperTorso", "Head", "Head"),
    ("LeftShoulder", "UpperTorso", "LeftUpperArm", "LeftArm"),
    ("LeftElbow", "LeftUpperArm", "LeftLowerArm", "LeftForeArm"),
    ("LeftWrist", "LeftLowerArm", "LeftHand", "LeftHand"),
    ("RightShoulder", "UpperTorso", "RightUpperArm", "RightArm"),
    ("RightElbow", "RightUpperArm", "RightLowerArm", "RightForeArm"),
    ("RightWrist", "RightLowerArm", "RightHand", "RightHand"),
    ("LeftHip", "LowerTorso", "LeftUpperLeg", "LeftUpLeg"),
    ("LeftKnee", "LeftUpperLeg", "LeftLowerLeg", "LeftLeg"),
    ("LeftAnkle", "LeftLowerLeg", "LeftFoot", "LeftFoot"),
    ("RightHip", "LowerTorso", "RightUpperLeg", "RightUpLeg"),
    ("RightKnee", "RightUpperLeg", "RightLowerLeg", "RightLeg"),
    ("RightAnkle", "RightLowerLeg", "RightFoot", "RightFoot"),
]
PARENTS = {child: parent for _, parent, child, _ in JOINTS}


def adjacent_regions(first, second):
    return PARENTS.get(first) == second or PARENTS.get(second) == first


def normalized_bone(name):
    name = re.sub(r"^mixamorig[:_]", "", name, flags=re.I)
    return name.lower()


def bone_regions(parents):
    """Use real bone ancestry for fingers/eyes; never use vertex position to guess a limb."""
    normalized = {}
    for name in parents:
        key = normalized_bone(name)
        if key in normalized:
            raise RigError(f"Ambiguous bone name: {name}")
        normalized[key] = name
        ancestor, visited = name, set()
        while ancestor is not None:
            if ancestor not in parents or ancestor in visited:
                raise RigError("Missing or cyclic bone ancestry")
            visited.add(ancestor)
            ancestor = parents[ancestor]
    missing = [bone for bone in PRIMARY.values() if bone.lower() not in normalized]
    if missing:
        raise RigError("Missing Mixamo bones: " + ", ".join(missing))
    mapping = {}
    for name in parents:
        ancestor, visited = name, set()
        while ancestor is not None:
            if ancestor in visited:
                raise RigError("Cyclic bone ancestry")
            visited.add(ancestor)
            region = REGION.get(normalized_bone(ancestor))
            if region:
                mapping[name] = region
                break
            ancestor = parents.get(ancestor)
    # Verify actual shoulder/hip/elbow/knee/wrist/ankle ancestry as well as the names.
    for _, parent_part, child_part, _ in JOINTS:
        if parent_part == "HumanoidRootPart":
            continue
        parent_bone = normalized[PRIMARY[parent_part].lower()]
        child_bone = normalized[PRIMARY[child_part].lower()]
        current, seen = parents.get(child_bone), set()
        while current is not None and current != parent_bone:
            if current in seen:
                raise RigError("Cyclic bone ancestry")
            seen.add(current)
            current = parents.get(current)
        if current != parent_bone:
            raise RigError(f"Invalid bone hierarchy: {child_bone} is not below {parent_bone}")
    return mapping, {part: normalized[bone.lower()] for part, bone in PRIMARY.items()}


def region_weights(groups, mapping):
    weights = {}
    for name, weight in groups:
        if not math.isfinite(weight) or weight < 0:
            raise RigError("Non-finite or negative bone weight")
        if weight <= 1e-8:
            continue
        if name not in mapping:
            raise RigError(f"Weighted unmapped bone: {name}")
        part = mapping[name]
        weights[part] = weights.get(part, 0.0) + weight
    total = sum(weights.values())
    if not math.isfinite(total) or total <= 1e-8:
        raise RigError("Unweighted vertex; refusing geometry-based replacement")
    return {part: weight / total for part, weight in weights.items()}


def face_region(vertex_weights, nonadjacent_ties="refuse"):
    """Partition by the largest real skin weight; ties use a connected parent-first policy."""
    scores = {}
    for vertex in vertex_weights:
        for part, weight in vertex.items():
            scores[part] = scores.get(part, 0.0) + weight / len(vertex_weights)
    ordered = sorted(scores.items(), key=lambda item: (-item[1], item[0]))
    if not ordered:
        raise RigError("Triangle has no bone weights")
    tied = {part for part, score in ordered if ordered[0][1] - score <= 1e-8}
    if len(tied) == 1:
        return ordered[0]
    visited = {next(iter(tied))}
    while True:
        reached = visited | {part for part in tied if any(adjacent_regions(part, current) for current in visited)}
        if reached == visited:
            break
        visited = reached
    if visited != tied and nonadjacent_ties != "parent-depth":
        raise RigError("Equal maximum weights across non-adjacent body regions: " + ", ".join(sorted(tied)))
    def depth(part):
        count = 0
        while part in PARENTS:
            part, count = PARENTS[part], count + 1
        return count
    return min(tied, key=lambda part: (depth(part), part)), ordered[0][1]


def upload_batches(parts, texture_roles, max_assets=10):
    """Count one model wrapper, one mesh per part, and unique image/map roles conservatively."""
    batches, batch, roles = [], [], set()
    for part in parts:
        added = roles | set(texture_roles[part])
        estimate = 1 + len(batch) + 1 + len(added)
        if estimate > max_assets:
            if not batch:
                raise RigError(f"Single part exceeds upload budget: {part}")
            batches.append({"parts": batch, "estimated_assets": 1 + len(batch) + len(roles)})
            batch, roles = [], set()
            added = set(texture_roles[part])
            if 2 + len(added) > max_assets:
                raise RigError(f"Single part exceeds upload budget: {part}")
        batch.append(part)
        roles = added
    if batch:
        batches.append({"parts": batch, "estimated_assets": 1 + len(batch) + len(roles)})
    return batches
