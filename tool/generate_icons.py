# © 2026 Tephra. All rights reserved.
import os
import sys
from PIL import Image

def generate_icons(source_path):
    if not os.path.exists(source_path):
        print(f"Error: Source image not found at {source_path}")
        sys.exit(1)

    print(f"Loading source image from {source_path}...")
    source = Image.open(source_path).convert("RGBA")
    w, h = source.size
    print(f"Source image size: {w}x{h}")

    # Ensure square aspect ratio
    if w != h:
        dim = min(w, h)
        left = (w - dim) // 2
        top = (h - dim) // 2
        source = source.crop((left, top, left + dim, top + dim))

    # Master asset (1024x1024)
    os.makedirs("app/assets/icons", exist_ok=True)
    master = source.resize((1024, 1024), Image.Resampling.LANCZOS)
    master.save("app/assets/icons/app_icon.png", "PNG", optimize=True)
    print("Generated app/assets/icons/app_icon.png (1024x1024)")

    # Android mipmaps
    android_sizes = {
        "mipmap-mdpi": (48, 48),
        "mipmap-hdpi": (72, 72),
        "mipmap-xhdpi": (96, 96),
        "mipmap-xxhdpi": (144, 144),
        "mipmap-xxxhdpi": (192, 192),
    }
    for folder, size in android_sizes.items():
        out_dir = os.path.join("app/android/app/src/main/res", folder)
        os.makedirs(out_dir, exist_ok=True)
        out_path = os.path.join(out_dir, "ic_launcher.png")
        resized = source.resize(size, Image.Resampling.LANCZOS)
        resized.save(out_path, "PNG", optimize=True)
        print(f"Generated {out_path} ({size[0]}x{size[1]})")

    # Windows application icon
    win_sizes = [(16, 16), (24, 24), (32, 32), (48, 48), (64, 64), (128, 128), (256, 256)]
    win_ico_path = "app/windows/runner/resources/app_icon.ico"
    os.makedirs(os.path.dirname(win_ico_path), exist_ok=True)
    source.save(win_ico_path, format="ICO", sizes=win_sizes)
    print(f"Generated {win_ico_path} (multi-size ICO)")

    # System tray icon
    tray_ico_path = "app/assets/tray/tray.ico"
    os.makedirs(os.path.dirname(tray_ico_path), exist_ok=True)
    source.save(tray_ico_path, format="ICO", sizes=win_sizes)
    print(f"Generated {tray_ico_path} (multi-size ICO)")

    # Web icons
    web_icons = {
        "app/web/favicon.png": (16, 16),
        "app/web/icons/Icon-192.png": (192, 192),
        "app/web/icons/Icon-512.png": (512, 512),
        "app/web/icons/Icon-maskable-192.png": (192, 192),
        "app/web/icons/Icon-maskable-512.png": (512, 512),
    }
    for path, size in web_icons.items():
        os.makedirs(os.path.dirname(path), exist_ok=True)
        resized = source.resize(size, Image.Resampling.LANCZOS)
        resized.save(path, "PNG", optimize=True)
        print(f"Generated {path} ({size[0]}x{size[1]})")

    print("All icons successfully generated!")

if __name__ == "__main__":
    src = sys.argv[1] if len(sys.argv) > 1 else os.path.expanduser("~/Downloads/Molten Tephra Crystal Icon.png")
    generate_icons(src)
