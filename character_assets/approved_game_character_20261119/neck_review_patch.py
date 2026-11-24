"""승인 캐릭터의 목 연결부 색과 실루엣을 정리한다."""

import io
import struct
import zlib

import numpy as np


def face_pixels(encoded):
    try:
        from PIL import Image
    except ImportError:
        # Blender의 기본 Python에는 Pillow가 없으므로 패킹된 JPEG를 Blender로 읽는다.
        import bpy
        import tempfile
        from pathlib import Path
        with tempfile.TemporaryDirectory() as folder:
            path = Path(folder) / "face.jpg"
            path.write_bytes(encoded)
            image = bpy.data.images.load(str(path))
            try:
                width, height = image.size
                pixels = np.empty(width * height * 4, dtype=np.float32)
                image.pixels.foreach_get(pixels)
                linear = pixels.reshape(height, width, 4)[::-1, :, :3]
                return np.clip(255 * (1.055 * linear ** (1 / 2.4) - 0.055), 0, 255)
            finally:
                bpy.data.images.remove(image)
    return np.array(Image.open(io.BytesIO(encoded)).convert("RGB"))


def blend_neck(document, buffer, primitives, skin, glb):
    # 얼굴 아래쪽 피부의 실제 텍셀을 접합부 둘레에서 읽는다.
    face = max((p for p in primitives if "baseColorTexture" in document["materials"][p["material"]]["pbrMetallicRoughness"]), key=lambda p: document["accessors"][p["attributes"]["POSITION"]]["max"][1])
    attrs = face["attributes"]
    positions = glb.array(document, buffer, attrs["POSITION"])
    band = (positions[:, 1] < 1.425) & (positions[:, 2] > -0.15)
    points = positions[band].copy()
    uv = glb.array(document, buffer, attrs["TEXCOORD_0"])[band]
    material = document["materials"][face["material"]]["pbrMetallicRoughness"]
    texture = document["textures"][material["baseColorTexture"]["index"]]
    view = document["bufferViews"][document["images"][texture["source"]]["bufferView"]]
    offset = view.get("byteOffset", 0)
    pixels = face_pixels(buffer[offset:offset + view["byteLength"]])
    h, w = pixels.shape[:2]
    colors = pixels[(uv[:, 1] * h).astype(int) % h, (uv[:, 0] * w).astype(int) % w]
    # 접합부 무늬를 UV 섬 경계까지 매끄럽게 보간할 수 있도록 피부색 램프를 공유한다.
    ramp = np.clip(np.arange(256)[:, None] + [77, 0, -49], 0, 255).astype(np.uint8)
    def chunk(kind, payload):
        return struct.pack(">I", len(payload)) + kind + payload + struct.pack(">I", zlib.crc32(kind + payload))
    png = (b"\x89PNG\r\n\x1a\n" + chunk(b"IHDR", struct.pack(">IIBBBBB", 256, 1, 8, 2, 0, 0, 0))
           + chunk(b"IDAT", zlib.compress(b"\0" + ramp.tobytes())) + chunk(b"IEND", b""))
    for primitive in primitives:
        if primitive["material"] != skin:
            continue
        a = primitive["attributes"]
        vertices = glb.array(document, buffer, a["POSITION"])
        coords = glb.array(document, buffer, a["TEXCOORD_0"])
        for i, vertex in enumerate(vertices):
            squared = np.sum((points - vertex) ** 2, axis=1)
            near = np.argpartition(squared, 8)[:8]
            weights = 1 / (squared[near] + 0.000001)
            shade = np.average(colors[near, 1], weights=weights)
            fade = np.clip(np.sqrt(squared[near].min()) / 0.085, 0, 1)
            fade = fade * fade * (3 - 2 * fade)
            coords[i] = ((shade * (1 - fade) + 159 * fade + 0.5) / 256, 0.5)
    buffer.extend(bytes(-len(buffer) % 4))
    document["bufferViews"].append({"buffer": 0, "byteOffset": len(buffer), "byteLength": len(png)})
    buffer.extend(png)
    document["images"].append({"name": "neck_skin_ramp", "mimeType": "image/png", "bufferView": len(document["bufferViews"]) - 1})
    document["textures"].append({"source": len(document["images"]) - 1})
    neck = document["materials"][skin]["pbrMetallicRoughness"]
    neck.pop("baseColorFactor", None)
    neck["baseColorTexture"] = {"index": len(document["textures"]) - 1}



def refine_neck(path, glb):
    document, buffer = glb.load(path)
    body = next(node for node in document["nodes"] if node.get("name") == "Body")
    primitives = document["meshes"][body["mesh"]]["primitives"]
    materials = document["materials"]
    neck_materials = {"M_BodyNeckVertexColor", "M_HeadNeckVertexColor", "M_NeckConnection"}
    skin = next(i for i, material in enumerate(materials) if material["name"] == "M_NeckConnection")
    materials[skin]["pbrMetallicRoughness"]["baseColorFactor"] = [0.77, 0.38, 0.20, 1.0]

    for primitive in primitives:
        attributes = primitive["attributes"]
        name = materials[primitive["material"]]["name"]
        if name in neck_materials:
            primitive["material"] = skin
            attributes.pop("COLOR_0", None)

        position_index = attributes["POSITION"]
        vertices = glb.array(document, buffer, position_index)
        normals = glb.array(document, buffer, attributes["NORMAL"])
        height = vertices[:, 1].copy()
        # 셔츠 목선과 턱은 고정하고, 중간 목의 급한 꺾임만 뒤로 완만하게 보낸다.
        t = np.clip((height - 1.255) / 0.17, 0.0, 1.0)
        shift = 0.018 * np.sin(np.pi * t) ** 2
        slope = 0.018 * np.pi / 0.17 * np.sin(2.0 * np.pi * t)
        # 턱 앞쪽은 보존하며, 접합 경계를 공유하는 목 메시에는 동일한 변형을 적용한다.
        depth = vertices[:, 2].copy()
        u = np.clip((depth + 0.205) / 0.07, 0.0, 1.0)
        weight = u * u * (3.0 - 2.0 * u)
        vertices[:, 2] += shift * weight
        # 변형의 역전치로 기존 로우폴리 셰이딩을 유지한다.
        normals[:, 2] /= 1.0 + shift * 6.0 * u * (1.0 - u) / 0.07
        normals[:, 1] -= normals[:, 2] * slope * weight
        if name in neck_materials:
            # 옷깃 높이에서 앞뒤 두께를 줄이고, 턱 아래에서 원래 단면으로 이어 준다.
            t_collar = np.clip((height - 1.25) / 0.14, 0.0, 1.0)
            blend = 1.0 - t_collar**2 * (3.0 - 2.0 * t_collar)
            derivative = -6.0 * t_collar * (1.0 - t_collar) / 0.14
            center_z = -0.040
            offset = vertices[:, 2].copy() - center_z
            scale = 1.0 - 0.40 * blend
            vertices[:, 2] = center_z + offset * scale
            normals[:, 2] /= scale
            normals[:, 1] += normals[:, 2] * 0.40 * derivative * offset
        normals[:] /= np.maximum(np.linalg.norm(normals, axis=1, keepdims=True), 1e-8)
        accessor = document["accessors"][position_index]
        accessor["min"] = vertices.min(axis=0).tolist()
        accessor["max"] = vertices.max(axis=0).tolist()

    blend_neck(document, buffer, primitives, skin, glb)
    glb.save(path, document, buffer)
