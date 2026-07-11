#!/usr/bin/env python3
"""마작 조이 앱 아이콘 생성.

게임 팔레트(민트/크림/핑크)와 타일 디자인을 그대로 살려서
- assets/icon/icon.png (1024x1024, iOS/레거시용 풀 아이콘)
- assets/icon/icon_foreground.png (안드로이드 적응형 아이콘 전경)
을 그린다. 이모지는 macOS Apple Color Emoji 폰트로 렌더링.
"""
import os

from PIL import Image, ImageDraw, ImageFilter, ImageFont

BASE = os.path.join(os.path.dirname(__file__), "..")
OUT = os.path.join(BASE, "assets", "icon")

# 게임 팔레트 (lib/ui/theme.dart)
MINT = (168, 230, 207)
MINT_DARK = (95, 191, 159)
CREAM = (255, 246, 233)
TILE_BACK = (184, 224, 210)
TILE_FACE = (255, 253, 248)

EMOJI_FONT = "/System/Library/Fonts/Apple Color Emoji.ttc"


def emoji_image(char, target_px):
    """이모지 한 글자를 target_px 크기의 RGBA 이미지로 렌더링."""
    strike = 160  # Apple Color Emoji의 최대 비트맵 크기
    font = ImageFont.truetype(EMOJI_FONT, size=strike)
    tmp = Image.new("RGBA", (strike * 2, strike * 2), (0, 0, 0, 0))
    d = ImageDraw.Draw(tmp)
    d.text((strike // 2, strike // 2), char, font=font, embedded_color=True)
    box = tmp.getbbox()
    tmp = tmp.crop(box)
    scale = target_px / max(tmp.size)
    return tmp.resize(
        (round(tmp.width * scale), round(tmp.height * scale)),
        Image.LANCZOS,
    )


def rounded_tile(w, h, face, border, border_w, radius):
    """게임 속 타일 모양: 둥근 사각형 + 테두리."""
    img = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    d.rounded_rectangle(
        [border_w // 2, border_w // 2, w - border_w // 2, h - border_w // 2],
        radius=radius,
        fill=face,
        outline=border,
        width=border_w,
    )
    return img


def tile_with_emoji(char, tile_w):
    """흰 타일 위에 이모지가 놓인 게임 타일 한 장."""
    tile_h = round(tile_w * 1.4)
    tile = rounded_tile(tile_w, tile_h, TILE_FACE, (0, 0, 0, 30),
                        max(4, tile_w // 40), tile_w // 5)
    icon = emoji_image(char, round(tile_w * 0.62))
    tile.alpha_composite(
        icon,
        ((tile_w - icon.width) // 2, (tile_h - icon.height) // 2),
    )
    return tile


def motif(size):
    """뒤에 민트 뒷면 타일, 앞에 🌸 타일이 살짝 기울어 겹친 모티브."""
    canvas = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    tile_w = round(size * 0.46)
    tile_h = round(tile_w * 1.4)

    back = rounded_tile(tile_w, tile_h, TILE_BACK, MINT_DARK,
                        max(4, tile_w // 40), tile_w // 5)
    back = back.rotate(10, expand=True, resample=Image.BICUBIC)

    front = tile_with_emoji("🌸", tile_w)
    front = front.rotate(-7, expand=True, resample=Image.BICUBIC)

    cx, cy = size // 2, size // 2
    canvas.alpha_composite(
        back, (cx - back.width // 2 + round(size * 0.10),
               cy - back.height // 2 - round(size * 0.04)))
    canvas.alpha_composite(
        front, (cx - front.width // 2 - round(size * 0.06),
                cy - front.height // 2 + round(size * 0.04)))
    return canvas


def gradient_bg(size, top, bottom):
    img = Image.new("RGBA", (size, size))
    for y in range(size):
        t = y / (size - 1)
        row = tuple(round(top[i] + (bottom[i] - top[i]) * t) for i in range(3))
        for_draw = ImageDraw.Draw(img)
        for_draw.line([(0, y), (size, y)], fill=row + (255,))
    return img


def main():
    os.makedirs(OUT, exist_ok=True)
    size = 1024

    # 풀 아이콘: 민트→크림 그라데이션 + 은은한 원 + 타일 모티브
    icon = gradient_bg(size, MINT, CREAM)
    # 은은한 장식 원 (반투명 흰색을 합성해 톤을 살짝만 올린다)
    deco = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    dd = ImageDraw.Draw(deco)
    dd.ellipse([size * 0.62, -size * 0.22, size * 1.35, size * 0.5],
               fill=(255, 255, 255, 55))
    dd.ellipse([-size * 0.28, size * 0.72, size * 0.3, size * 1.3],
               fill=(255, 255, 255, 40))
    icon.alpha_composite(deco)
    # 타일 아래 부드러운 그림자
    shadow = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    ImageDraw.Draw(shadow).ellipse(
        [size * 0.26, size * 0.74, size * 0.74, size * 0.85],
        fill=(60, 60, 60, 50))
    shadow = shadow.filter(ImageFilter.GaussianBlur(size // 40))
    icon.alpha_composite(shadow)
    icon.alpha_composite(motif(size), (0, 0))
    icon.convert("RGB").save(os.path.join(OUT, "icon.png"))
    print("wrote icon.png")

    # 적응형 아이콘 전경: 투명 배경, 안전 영역(중앙 66%) 안에 모티브
    fg = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    m = motif(round(size * 0.62))
    fg.alpha_composite(m, ((size - m.width) // 2, (size - m.height) // 2))
    fg.save(os.path.join(OUT, "icon_foreground.png"))
    print("wrote icon_foreground.png")


if __name__ == "__main__":
    main()
