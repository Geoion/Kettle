#!/usr/bin/env python3
import os
import shutil
import subprocess
from pathlib import Path
from PIL import Image, ImageDraw

# ---------- 配置区域 ----------
# 输入 PNG 的路径
SOURCE_PNG_PATH = "/Users/eskiyin/Documents/Code/Kettle/scripts/image.png"
# 输出 ICNS 的路径
OUTPUT_ICNS_PATH = "/Users/eskiyin/Documents/Code/Kettle/scripts/AppIcon.icns"
# 圆角半径比例 (0.0-0.25, macOS 标准约为 0.23)
CORNER_RADIUS_RATIO = 0.23
# --------------------------------

def add_mac_style_corners(img, radius_ratio=0.23):
    """添加 macOS 风格的圆角"""
    width, height = img.size
    radius = int(min(width, height) * radius_ratio)
    
    # 创建圆角蒙版
    mask = Image.new('L', (width, height), 0)
    draw = ImageDraw.Draw(mask)
    
    # 绘制圆角矩形
    draw.rounded_rectangle([(0, 0), (width, height)], radius=radius, fill=255)
    
    # 创建透明背景图片
    result = Image.new('RGBA', (width, height), (0, 0, 0, 0))
    
    # 将原始图片应用圆角蒙版
    result.paste(img, (0, 0), mask)
    
    return result

def create_sized_icon(src_png_path, output_path, size_px):
    """创建单个尺寸的图标，带有 macOS 风格圆角"""
    # 打开原始图片
    img = Image.open(src_png_path).convert('RGBA')
    
    # 调整大小
    img = img.resize((size_px, size_px), Image.Resampling.LANCZOS)
    
    # 添加圆角
    img = add_mac_style_corners(img, CORNER_RADIUS_RATIO)
    
    # 保存
    img.save(output_path, 'PNG')

def create_icns(src_png_path, output_icns_path):
    src_png = Path(src_png_path)
    output_icns = Path(output_icns_path)
    
    # 创建临时的.iconset目录
    iconset_dir = Path("./temp.iconset")
    if iconset_dir.exists():
        shutil.rmtree(iconset_dir)
    iconset_dir.mkdir()
    
    # 为macOS生成各种尺寸的图标
    icon_sizes = [16, 32, 64, 128, 256, 512, 1024]
    
    for size in icon_sizes:
        # 1x版本
        output_path = iconset_dir / f"icon_{size}x{size}.png"
        create_sized_icon(str(src_png), str(output_path), size)
        
        # 2x版本 (对于16, 32, 64, 128, 256, 512)
        if size <= 512:
            output_path = iconset_dir / f"icon_{size}x{size}@2x.png"
            create_sized_icon(str(src_png), str(output_path), size*2)
    
    # 使用iconutil将iconset转换为icns文件
    subprocess.run([
        "iconutil", "-c", "icns", str(iconset_dir),
        "-o", str(output_icns)
    ], check=True)
    
    # 清理临时目录
    shutil.rmtree(iconset_dir)
    
    print(f"✅ 已生成 macOS 风格圆角图标文件: {output_icns}")

if __name__ == "__main__":
    create_icns(SOURCE_PNG_PATH, OUTPUT_ICNS_PATH) 