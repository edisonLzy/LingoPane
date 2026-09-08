#!/usr/bin/env python3
"""Compose a short LingoPane product demo from real application captures."""

from __future__ import annotations

import math
import subprocess
from pathlib import Path

from PIL import Image, ImageDraw, ImageFilter, ImageFont


ROOT = Path(__file__).resolve().parents[1]
ARTIFACTS = ROOT / "artifacts" / "lingopane-demo"
FRAMES = ARTIFACTS / "frames"
OUTPUT = ARTIFACTS / "LingoPane-10s-demo.mp4"

WIDTH, HEIGHT = 1920, 1080
FPS = 30
DURATION = 10.0
FRAME_COUNT = int(FPS * DURATION)

FONT_CN = "/System/Library/AssetsV2/com_apple_MobileAsset_Font7/3419f2a427639ad8c8e139149a287865a90fa17e.asset/AssetData/PingFang.ttc"
FONT_LATIN = "/System/Library/Fonts/SFNS.ttf"
FONT_ROUNDED = "/System/Library/Fonts/SFNSRounded.ttf"


def font(path: str, size: int, index: int = 0) -> ImageFont.FreeTypeFont:
    return ImageFont.truetype(path, size=size, index=index)


CN_REG = font(FONT_CN, 32, 0)
CN_MED = font(FONT_CN, 38, 1)
CN_BIG = font(FONT_CN, 56, 1)
LATIN_SMALL = font(FONT_LATIN, 24)
LATIN_BODY = font(FONT_LATIN, 34)
LATIN_TITLE = font(FONT_LATIN, 50)
ROUNDED = font(FONT_ROUNDED, 34)


def clamp(value: float, low: float = 0.0, high: float = 1.0) -> float:
    return max(low, min(high, value))


def ease_out_cubic(value: float) -> float:
    value = clamp(value)
    return 1 - (1 - value) ** 3


def ease_in_out(value: float) -> float:
    value = clamp(value)
    return value * value * (3 - 2 * value)


def interval(t: float, start: float, end: float) -> float:
    return clamp((t - start) / (end - start))


def rounded_mask(size: tuple[int, int], radius: int) -> Image.Image:
    mask = Image.new("L", size, 0)
    ImageDraw.Draw(mask).rounded_rectangle((0, 0, size[0] - 1, size[1] - 1), radius=radius, fill=255)
    return mask


def crop_panel(source: Path, box: tuple[int, int, int, int]) -> Image.Image:
    screenshot = Image.open(source).convert("RGB")
    panel = screenshot.crop(box).convert("RGBA")
    panel.putalpha(rounded_mask(panel.size, 42))
    return panel


def resize_rgba(image: Image.Image, width: int) -> Image.Image:
    height = round(image.height * width / image.width)
    return image.resize((width, height), Image.Resampling.LANCZOS)


def gradient_background() -> Image.Image:
    image = Image.new("RGB", (WIDTH, HEIGHT))
    pixels = image.load()
    for y in range(HEIGHT):
        for x in range(WIDTH):
            nx, ny = x / WIDTH, y / HEIGHT
            glow_a = math.exp(-((nx - 0.08) ** 2 + (ny - 0.06) ** 2) / 0.18)
            glow_b = math.exp(-((nx - 0.93) ** 2 + (ny - 0.87) ** 2) / 0.16)
            r = int(9 + 13 * glow_a + 4 * glow_b)
            g = int(18 + 20 * glow_a + 22 * glow_b)
            b = int(43 + 32 * glow_a + 40 * glow_b)
            pixels[x, y] = (r, g, b)
    return image


def shadowed_round_rect(
    base: Image.Image,
    box: tuple[int, int, int, int],
    radius: int,
    fill: tuple[int, int, int, int],
    shadow_alpha: int = 65,
    shadow_blur: int = 30,
    shadow_offset: tuple[int, int] = (0, 18),
) -> None:
    x0, y0, x1, y1 = box
    shadow = Image.new("RGBA", base.size, (0, 0, 0, 0))
    sd = ImageDraw.Draw(shadow)
    dx, dy = shadow_offset
    sd.rounded_rectangle((x0 + dx, y0 + dy, x1 + dx, y1 + dy), radius=radius, fill=(0, 0, 0, shadow_alpha))
    shadow = shadow.filter(ImageFilter.GaussianBlur(shadow_blur))
    base.alpha_composite(shadow)
    ImageDraw.Draw(base).rounded_rectangle(box, radius=radius, fill=fill)


def draw_document(base: Image.Image, t: float) -> tuple[float, float, float, float]:
    opacity = int(255 * ease_out_cubic(interval(t, 0.0, 0.55)))
    layer = Image.new("RGBA", base.size, (0, 0, 0, 0))
    card = (110, 150, 1255, 935)
    shadowed_round_rect(layer, card, 34, (247, 248, 252, opacity), shadow_alpha=int(72 * opacity / 255))
    draw = ImageDraw.Draw(layer)

    # Window chrome.
    draw.ellipse((150, 190, 170, 210), fill=(255, 95, 87, opacity))
    draw.ellipse((183, 190, 203, 210), fill=(255, 189, 46, opacity))
    draw.ellipse((216, 190, 236, 210), fill=(40, 201, 64, opacity))
    draw.rounded_rectangle((927, 184, 1185, 216), radius=16, fill=(228, 231, 239, opacity))

    # Article skeleton and copy.
    draw.text((180, 285), "PRODUCT DESIGN NOTES", font=LATIN_SMALL, fill=(62, 104, 174, opacity))
    draw.text((180, 332), "Shipping thoughtful software", font=LATIN_TITLE, fill=(28, 35, 51, opacity))
    draw.text((180, 410), "A calm interface helps people stay focused on the work", font=LATIN_BODY, fill=(83, 91, 108, opacity))
    draw.text((180, 455), "in front of them. Context should remain close at hand.", font=LATIN_BODY, fill=(83, 91, 108, opacity))

    sentence = "The feature that we discussed yesterday has been implemented."
    sentence_xy = (180, 565)
    sentence_bbox = draw.textbbox(sentence_xy, sentence, font=LATIN_BODY)

    # Animated text selection.
    selection = ease_in_out(interval(t, 0.72, 1.68))
    selected_width = (sentence_bbox[2] - sentence_bbox[0]) * selection
    if selection > 0:
        draw.rounded_rectangle(
            (sentence_bbox[0] - 5, sentence_bbox[1] - 4, sentence_bbox[0] + selected_width + 5, sentence_bbox[3] + 5),
            radius=8,
            fill=(78, 151, 247, int(142 * opacity / 255)),
        )
    draw.text(sentence_xy, sentence, font=LATIN_BODY, fill=(30, 39, 56, opacity))

    draw.rounded_rectangle((180, 675, 1015, 691), radius=8, fill=(220, 224, 233, opacity))
    draw.rounded_rectangle((180, 714, 1090, 730), radius=8, fill=(226, 229, 237, opacity))
    draw.rounded_rectangle((180, 753, 910, 769), radius=8, fill=(226, 229, 237, opacity))
    draw.rounded_rectangle((180, 832, 690, 848), radius=8, fill=(231, 233, 240, opacity))
    base.alpha_composite(layer)
    return sentence_bbox


def draw_cursor(base: Image.Image, t: float, sentence_bbox: tuple[float, float, float, float]) -> None:
    if t > 2.48:
        return
    p = ease_in_out(interval(t, 0.45, 1.68))
    x = (sentence_bbox[0] - 10) * (1 - p) + (sentence_bbox[2] + 12) * p
    y = sentence_bbox[3] + 22 - 5 * math.sin(p * math.pi)
    layer = Image.new("RGBA", base.size, (0, 0, 0, 0))
    draw = ImageDraw.Draw(layer)
    points = [(x, y), (x + 4, y + 31), (x + 12, y + 23), (x + 20, y + 42), (x + 29, y + 38), (x + 20, y + 19), (x + 31, y + 16)]
    draw.polygon(points, fill=(255, 255, 255, 255), outline=(22, 29, 45, 255))
    base.alpha_composite(layer)


def draw_keycap(base: Image.Image, t: float) -> None:
    visible = min(ease_out_cubic(interval(t, 1.7, 1.95)), 1 - ease_in_out(interval(t, 2.35, 2.6)))
    if visible <= 0:
        return
    scale = 0.91 + 0.09 * ease_out_cubic(interval(t, 1.7, 2.0))
    w, h = int(260 * scale), int(82 * scale)
    x, y = 500 - w // 2, 770 - h // 2
    layer = Image.new("RGBA", base.size, (0, 0, 0, 0))
    shadowed_round_rect(layer, (x, y, x + w, y + h), 22, (21, 28, 48, int(242 * visible)), shadow_alpha=int(90 * visible), shadow_blur=22)
    draw = ImageDraw.Draw(layer)
    label = "⌥  Space"
    bbox = draw.textbbox((0, 0), label, font=ROUNDED)
    draw.text((x + (w - bbox[2]) / 2, y + (h - bbox[3]) / 2 - 5), label, font=ROUNDED, fill=(244, 248, 255, int(255 * visible)))
    base.alpha_composite(layer)


def paste_with_shadow(base: Image.Image, image: Image.Image, xy: tuple[int, int], opacity: float, scale: float = 1.0) -> None:
    if opacity <= 0:
        return
    target = image
    if scale != 1:
        target = target.resize((round(image.width * scale), round(image.height * scale)), Image.Resampling.LANCZOS)
    if opacity < 0.999:
        alpha = target.getchannel("A").point(lambda value: int(value * opacity))
        target = target.copy()
        target.putalpha(alpha)
    x, y = xy
    shadow = Image.new("RGBA", base.size, (0, 0, 0, 0))
    mask = target.getchannel("A")
    shadow_blob = Image.new("RGBA", target.size, (0, 0, 0, int(110 * opacity)))
    shadow_blob.putalpha(mask.point(lambda value: int(value * 0.42)))
    shadow.alpha_composite(shadow_blob, (x, y + 24))
    shadow = shadow.filter(ImageFilter.GaussianBlur(28))
    base.alpha_composite(shadow)
    base.alpha_composite(target, (x, y))


def draw_panel(base: Image.Image, t: float, basic: Image.Image, annotated: Image.Image) -> None:
    appear = ease_out_cubic(interval(t, 2.42, 2.86))
    disappear = 1 - ease_in_out(interval(t, 8.65, 8.92))
    visibility = appear * disappear
    if visibility <= 0:
        return
    panel_x = 1160
    basic_y = 205
    annotated_y = 86
    switch = ease_in_out(interval(t, 5.15, 5.55))
    lift = int(22 * (1 - appear))
    scale = 0.965 + 0.035 * appear
    paste_with_shadow(base, basic, (panel_x, basic_y + lift), visibility * (1 - switch), scale)
    paste_with_shadow(base, annotated, (panel_x, annotated_y + lift), visibility * switch, scale)


def draw_caption(base: Image.Image, t: float) -> None:
    if t < 2.55:
        text = "读英文，不该打断思路。"
        alpha = min(ease_out_cubic(interval(t, 0.05, 0.5)), 1 - ease_in_out(interval(t, 2.2, 2.52)))
    elif t < 5.1:
        text = "划词，按下快捷键。"
        alpha = min(ease_out_cubic(interval(t, 2.55, 2.9)), 1 - ease_in_out(interval(t, 4.8, 5.08)))
    else:
        text = "翻译之外，直接看懂句子结构。"
        alpha = min(ease_out_cubic(interval(t, 5.18, 5.55)), 1 - ease_in_out(interval(t, 8.48, 8.72)))
    if alpha <= 0:
        return
    layer = Image.new("RGBA", base.size, (0, 0, 0, 0))
    draw = ImageDraw.Draw(layer)
    bbox = draw.textbbox((0, 0), text, font=CN_MED)
    pad_x, pad_y = 30, 18
    w, h = bbox[2] + pad_x * 2, bbox[3] + pad_y * 2
    x, y = 112, 62
    draw.rounded_rectangle((x, y, x + w, y + h), radius=26, fill=(9, 18, 40, int(190 * alpha)), outline=(108, 195, 255, int(80 * alpha)), width=2)
    draw.text((x + pad_x, y + pad_y - 5), text, font=CN_MED, fill=(245, 250, 255, int(255 * alpha)))
    base.alpha_composite(layer)


def draw_end_card(base: Image.Image, t: float, icon: Image.Image) -> None:
    p = ease_out_cubic(interval(t, 8.74, 9.18))
    if p <= 0:
        return
    veil = Image.new("RGBA", base.size, (5, 12, 35, int(248 * p)))
    base.alpha_composite(veil)
    icon_size = int(184 * (0.88 + 0.12 * p))
    icon_resized = icon.resize((icon_size, icon_size), Image.Resampling.LANCZOS)
    icon_alpha = icon_resized.getchannel("A").point(lambda value: int(value * p))
    icon_resized.putalpha(icon_alpha)
    icon_x = WIDTH // 2 - icon_size // 2
    icon_y = 250 - icon_size // 2
    glow = Image.new("RGBA", base.size, (0, 0, 0, 0))
    gd = ImageDraw.Draw(glow)
    gd.ellipse((icon_x - 80, icon_y - 80, icon_x + icon_size + 80, icon_y + icon_size + 80), fill=(33, 130, 255, int(80 * p)))
    glow = glow.filter(ImageFilter.GaussianBlur(70))
    base.alpha_composite(glow)
    base.alpha_composite(icon_resized, (icon_x, icon_y))
    draw = ImageDraw.Draw(base)
    brand = "LingoPane"
    tagline = "看懂，不只翻译。"
    brand_box = draw.textbbox((0, 0), brand, font=font(FONT_ROUNDED, 72))
    tag_box = draw.textbbox((0, 0), tagline, font=CN_BIG)
    draw.text(((WIDTH - brand_box[2]) / 2, 405), brand, font=font(FONT_ROUNDED, 72), fill=(248, 251, 255, int(255 * p)))
    draw.text(((WIDTH - tag_box[2]) / 2, 520), tagline, font=CN_BIG, fill=(194, 224, 255, int(255 * p)))
    line_w = int(210 * p)
    draw.rounded_rectangle((WIDTH // 2 - line_w // 2, 620, WIDTH // 2 + line_w // 2, 626), radius=3, fill=(48, 219, 220, int(220 * p)))


def main() -> None:
    ARTIFACTS.mkdir(parents=True, exist_ok=True)
    basic = crop_panel(FRAMES / "screen-current.png", (1570, 280, 2322, 975))
    annotated = crop_panel(FRAMES / "screen-annotated.png", (1570, 280, 2322, 1330))
    basic = resize_rgba(basic, 650)
    annotated = resize_rgba(annotated, 650)
    icon = Image.open(ROOT / "Resources" / "AppIcon-1024.png").convert("RGBA")
    background = gradient_background().convert("RGBA")

    command = [
        "ffmpeg", "-y", "-f", "rawvideo", "-pix_fmt", "rgb24",
        "-s", f"{WIDTH}x{HEIGHT}", "-r", str(FPS), "-i", "-",
        "-an", "-c:v", "libx264", "-preset", "medium", "-crf", "17",
        "-pix_fmt", "yuv420p", "-movflags", "+faststart", str(OUTPUT),
    ]
    process = subprocess.Popen(command, stdin=subprocess.PIPE)
    assert process.stdin is not None
    for frame_number in range(FRAME_COUNT):
        t = frame_number / FPS
        frame = background.copy()
        sentence_bbox = draw_document(frame, t)
        draw_cursor(frame, t, sentence_bbox)
        draw_keycap(frame, t)
        draw_panel(frame, t, basic, annotated)
        draw_caption(frame, t)
        draw_end_card(frame, t, icon)
        process.stdin.write(frame.convert("RGB").tobytes())
    process.stdin.close()
    if process.wait() != 0:
        raise SystemExit("ffmpeg failed")
    print(OUTPUT)


if __name__ == "__main__":
    main()
