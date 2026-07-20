#!/usr/bin/env python3
"""adb screencap 원본을 스토어 규격으로 크롭한다.

상태바(위)와 제스처/내비게이션 바(아래)를 잘라내 순수 앱 화면만 남긴다.
기본값(top=100, bottom=125)은 1080x2340 물리 해상도 기준(SM-S731N)이며,
결과 크기는 1080x2115. 다른 해상도의 기기라면 top/bottom을 인자로 넘길 것.
"""
import sys

from PIL import Image


def main() -> None:
    if len(sys.argv) < 3:
        print("usage: crop.py <src.png> <dst.png> [top=100] [bottom=125]")
        sys.exit(1)

    src, dst = sys.argv[1], sys.argv[2]
    top = int(sys.argv[3]) if len(sys.argv) > 3 else 100
    bottom = int(sys.argv[4]) if len(sys.argv) > 4 else 125

    im = Image.open(src)
    w, h = im.size
    if h <= top + bottom:
        print(f"error: 이미지 높이({h})가 top+bottom({top + bottom})보다 작거나 같음")
        sys.exit(1)

    cropped = im.crop((0, top, w, h - bottom))
    cropped.save(dst)
    print(f"saved {dst} ({cropped.width}x{cropped.height}, 원본 {w}x{h}에서 위 {top}px/아래 {bottom}px 제거)")


if __name__ == "__main__":
    main()
