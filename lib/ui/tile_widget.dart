import 'package:flutter/material.dart';

import '../models/tile.dart';
import 'theme.dart';

/// 수패 심볼: 한자 대신 과일/동물/꽃 (기획안 "Tile Assets").
const _suitSymbols = {
  Suit.man: '🍊',
  Suit.pin: '🐻',
  Suit.sou: '🌸',
};

const _suitColors = {
  Suit.man: Color(0xFFE8933A),
  Suit.pin: Color(0xFF8A6BBE),
  Suit.sou: Color(0xFFE97FA0),
};

/// 자패 심볼: 날씨로 대체 (동남서북백발중 → 해/구름/비/눈/달/별/무지개).
const _honorSymbols = ['☀️', '☁️', '🌧️', '❄️', '🌙', '⭐', '🌈'];

class TileWidget extends StatelessWidget {
  final Tile? tile; // null이면 뒷면
  final double size; // 타일 너비 (높이 = 너비 × 1.4)
  final bool highlighted;
  final VoidCallback? onTap;

  const TileWidget(
    this.tile, {
    super.key,
    this.size = 44,
    this.highlighted = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final height = size * 1.4;
    final faceDown = tile == null;

    Widget content;
    if (faceDown) {
      content = const SizedBox.shrink();
    } else if (tile!.isHonor) {
      content = Center(
        child: Text(
          _honorSymbols[tile!.rank - 1],
          style: TextStyle(fontSize: size * 0.52),
        ),
      );
    } else {
      content = Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            '${tile!.rank}',
            style: TextStyle(
              fontSize: size * 0.46,
              fontWeight: FontWeight.w800,
              color: _suitColors[tile!.suit],
              height: 1.0,
            ),
          ),
          Text(
            _suitSymbols[tile!.suit]!,
            style: TextStyle(fontSize: size * 0.36, height: 1.2),
          ),
        ],
      );
    }

    final body = AnimatedContainer(
      duration: const Duration(milliseconds: 150),
      width: size,
      height: height,
      decoration: BoxDecoration(
        color: faceDown ? Palette.tileBack : Palette.tileFace,
        borderRadius: BorderRadius.circular(size * 0.18),
        border: Border.all(
          color: highlighted ? Palette.pinkDark : Colors.black12,
          width: highlighted ? 2.5 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.10),
            blurRadius: 3,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: content,
    );

    if (onTap == null) return body;
    return GestureDetector(onTap: onTap, child: body);
  }
}

/// 타일이 [from] 방향에서 미끄러져 들어와 자리에 놓이는 등장 애니메이션.
/// key가 바뀔 때마다 다시 재생된다 (새로 버려진/뽑은 패에 새 key를 줄 것).
class TileAppear extends StatelessWidget {
  final Widget child;

  /// 시작 지점 오프셋 (픽셀). 예: Offset(0, 40) = 아래(플레이어 쪽)에서 등장.
  final Offset from;

  const TileAppear({
    super.key,
    required this.child,
    this.from = const Offset(0, 40),
  });

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOutCubic,
      child: child,
      builder: (context, t, child) => Opacity(
        opacity: t,
        child: Transform.translate(
          offset: Offset(from.dx * (1 - t), from.dy * (1 - t)),
          child: Transform.scale(scale: 1.25 - 0.25 * t, child: child),
        ),
      ),
    );
  }
}

/// 작은 타일 여러 장을 가로로 나열 (몸통/바닥패 표시용).
class TileRow extends StatelessWidget {
  final List<Tile> tiles;
  final double size;
  final Tile? highlight;

  const TileRow(this.tiles, {super.key, this.size = 24, this.highlight});

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 2,
      runSpacing: 2,
      children: [
        for (var i = 0; i < tiles.length; i++)
          TileWidget(
            tiles[i],
            size: size,
            // 마지막으로 버려진 패 강조: 같은 종류의 마지막 장만
            highlighted: highlight != null &&
                i == tiles.length - 1 &&
                tiles[i] == highlight,
          ),
      ],
    );
  }
}
