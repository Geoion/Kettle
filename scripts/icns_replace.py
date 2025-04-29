import os
import shutil
import subprocess
import json
from pathlib import Path

# ---------- 配置区域 ----------
# 输入 PNG 的绝对路径
SOURCE_PNG_PATH = "/Users/eskiyin/Documents/Code/Kettle/scripts/image.png"  # ← 修改为你的图标路径
# Xcode 中 Assets.xcassets 的 AppIcon.appiconset 目标路径
XC_ASSET_APPICONSET_PATH = "/Users/eskiyin/Documents/Code/Kettle/Kettle/Assets.xcassets/AppIcon.appiconset"  # ← 修改为你的目标目录
# 圆角半径（按比例，0-1之间，0表示无圆角，1表示最大圆角）
CORNER_RADIUS_RATIO = 0.2
# --------------------------------

# 所需 icon 尺寸与 scale 定义
icon_definitions = [
    {"size": 20, "scales": [2, 3], "idiom": "iphone"},
    {"size": 29, "scales": [2, 3], "idiom": "iphone"},
    {"size": 40, "scales": [2, 3], "idiom": "iphone"},
    {"size": 60, "scales": [2, 3], "idiom": "iphone"},
    {"size": 20, "scales": [1, 2], "idiom": "ipad"},
    {"size": 29, "scales": [1, 2], "idiom": "ipad"},
    {"size": 40, "scales": [1, 2], "idiom": "ipad"},
    {"size": 76, "scales": [1, 2], "idiom": "ipad"},
    {"size": 83.5, "scales": [2], "idiom": "ipad"},
    {"size": 1024, "scales": [1], "idiom": "ios-marketing"}
]

def add_corners(im, rad_ratio):
    circle = Image.new('L', (im.width, im.height), 0)
    draw = ImageDraw.Draw(circle)
    radius = int(min(im.width, im.height) * rad_ratio)
    draw.rounded_rectangle([(0, 0), (im.width, im.height)], radius=radius, fill=255)
    output = Image.new('RGBA', (im.width, im.height), (0, 0, 0, 0))
    output.paste(im, (0, 0))
    output.putalpha(circle)
    return output

def create_sized_icon(src_png_path: str, output_path: str, size_px: int):
    # 打开原始图片
    img = Image.open(src_png_path).convert('RGBA')
    # 调整大小
    img = img.resize((size_px, size_px), Image.Resampling.LANCZOS)
    # 添加圆角
    img = add_corners(img, CORNER_RADIUS_RATIO)
    # 保存
    img.save(output_path, 'PNG')

def create_appiconset(src_png_path: str, dest_iconset_path: str):
    src_png = Path(src_png_path)
    iconset_dir = Path(dest_iconset_path)

    # 清理旧目录并创建新目录
    if iconset_dir.exists():
        shutil.rmtree(iconset_dir)
    iconset_dir.mkdir(parents=True)

    contents = {
        "images": [],
        "info": {
            "version": 1,
            "author": "xcode"
        }
    }

    for definition in icon_definitions:
        for scale in definition["scales"]:
            size_pt = definition["size"]
            size_px = int(size_pt * scale)
            filename = f"icon_{size_pt}x{size_pt}@{scale}x.png"
            output_path = iconset_dir / filename

            # 使用 sips 生成目标尺寸图标
            subprocess.run([
                "sips", "-z", str(size_px), str(size_px), str(src_png),
                "--out", str(output_path)
            ], check=True)

            contents["images"].append({
                "idiom": definition["idiom"],
                "size": f"{size_pt}x{size_pt}",
                "scale": f"{scale}x",
                "filename": filename
            })

    # 写入 Contents.json
    with open(iconset_dir / "Contents.json", "w") as f:
        json.dump(contents, f, indent=4)

    print(f"✅ 已生成 AppIcon.appiconset 到：{iconset_dir}")

# 执行生成
create_appiconset(SOURCE_PNG_PATH, XC_ASSET_APPICONSET_PATH)