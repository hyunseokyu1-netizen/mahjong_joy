import '../models/tile.dart';
import 'claim.dart';
import 'game.dart';

/// 승리 점수 계산: "기본 100점 + 더하기 보너스, 그리고 곱하기 보너스".
///
/// 규칙을 최소한으로 유지해 아이도 영수증만 보고 이해할 수 있게 한다.
/// - 더하기: 날씨 세트(+50/개), 내가 뽑아 완성(+100), 올 스트레이트(+200),
///   라스트 캐치(+200)
/// - 곱하기: 혼자 힘으로(×2), 하프 앤 하프(×2), 올 트리플(×3), 원 컬러(×5)
/// 최종 점수 = (기본 + 더하기 전부) × 곱하기 전부.

/// 기본 완성 점수.
const int baseWinScore = 100;

/// 라스트 캐치 기준: 남은 덱이 이 수 이하일 때 완성하면 보너스.
const int lastCatchWallCount = 5;

/// 보너스 종류. 표시 이름/설명은 언어별로 Strings가 제공한다.
enum ScoreBonus {
  base,
  weatherSet,
  selfDraw,
  allStraight,
  lastCatch,
  solo,
  halfHalf,
  allTriple,
  oneColor,
  allWeather,
}

const Map<ScoreBonus, String> bonusEmoji = {
  ScoreBonus.base: '🀄',
  ScoreBonus.weatherSet: '🌈',
  ScoreBonus.selfDraw: '💪',
  ScoreBonus.allStraight: '📏',
  ScoreBonus.lastCatch: '🎣',
  ScoreBonus.solo: '🔒',
  ScoreBonus.halfHalf: '🌗',
  ScoreBonus.allTriple: '🎲',
  ScoreBonus.oneColor: '🎨',
  ScoreBonus.allWeather: '🌦️',
};

/// 영수증 한 줄. [plus]와 [times] 중 정확히 하나만 갖는다.
class ScoreLine {
  final ScoreBonus bonus;

  /// 같은 보너스가 여러 개일 때 개수 (날씨 세트 전용, 그 외 1).
  final int count;

  final int? plus;
  final int? times;

  const ScoreLine.plus(this.bonus, int score, {this.count = 1})
      : plus = score,
        times = null;

  const ScoreLine.times(this.bonus, int multiplier, {this.count = 1})
      : plus = null,
        times = multiplier;

  String get emoji => bonusEmoji[bonus]!;
}

/// 한 판 승리의 점수 내역. 영수증 UI가 [lines]를 순서대로 보여준다.
class ScoreResult {
  /// 기본 점수 포함, 더하기 → 곱하기 순서.
  final List<ScoreLine> lines;

  final int total;

  ScoreResult(this.lines) : total = _sumUp(lines);

  static int _sumUp(List<ScoreLine> lines) {
    var total = 0;
    for (final l in lines) {
      total = l.plus != null ? total + l.plus! : total * l.times!;
    }
    return total;
  }

  /// [count]번째 줄까지 반영한 소계 (영수증 연출용).
  int subtotal(int count) => _sumUp(lines.take(count).toList());
}

/// 끝난 판의 승자 점수를 계산한다. 승자가 없으면 호출하지 말 것.
ScoreResult scoreOf(Game game) {
  final winner = game.players[game.winner!];
  return calculateScore(
    hand: game.winningHand!,
    melds: winner.melds,
    isTsumo: game.winType == WinType.tsumo,
    wallCount: game.wallCount,
  );
}

/// 완성 손패([hand]: 비공개 패 + 승리 패)와 공개 몸통([melds])으로
/// 보너스를 판정한다.
ScoreResult calculateScore({
  required List<Tile> hand,
  required List<Meld> melds,
  required bool isTsumo,
  required int wallCount,
}) {
  final counts = List<int>.filled(Tile.kindCount, 0);
  for (final t in hand) {
    counts[t.key]++;
  }

  final lines = <ScoreLine>[
    const ScoreLine.plus(ScoreBonus.base, baseWinScore),
  ];

  // ---- 더하기 보너스 ----

  // 날씨 세트: 날씨(자패) 트리플 하나당 +50.
  // 날씨패는 스트레이트가 안 되므로 손패에 3장이면 반드시 트리플이다.
  var weatherSets = melds
      .where((m) => m.type == MeldType.triple && m.tiles.first.isHonor)
      .length;
  for (var key = 27; key < Tile.kindCount; key++) {
    if (counts[key] >= 3) weatherSets++;
  }
  if (weatherSets > 0) {
    lines.add(ScoreLine.plus(ScoreBonus.weatherSet, 50 * weatherSets,
        count: weatherSets));
  }

  if (isTsumo) {
    lines.add(const ScoreLine.plus(ScoreBonus.selfDraw, 100));
  }

  final allTriple = melds.every((m) => m.type == MeldType.triple) &&
      _isAllTripleHand(counts);
  final allStraight = !allTriple &&
      melds.every((m) => m.type == MeldType.run) &&
      _isAllStraightHand(counts);
  if (allStraight) {
    lines.add(const ScoreLine.plus(ScoreBonus.allStraight, 200));
  }

  if (wallCount <= lastCatchWallCount) {
    lines.add(const ScoreLine.plus(ScoreBonus.lastCatch, 200));
  }

  // ---- 곱하기 보너스 ----

  if (melds.isEmpty) {
    lines.add(const ScoreLine.times(ScoreBonus.solo, 2));
  }

  if (allTriple) {
    lines.add(const ScoreLine.times(ScoreBonus.allTriple, 3));
  }

  // 깔맞춤: 모든 패(몸통 포함)의 종류 구성으로 판정.
  final suits = <Suit>{
    for (final t in hand) t.suit,
    for (final m in melds)
      for (final t in m.tiles) t.suit,
  };
  final hasWeather = suits.remove(Suit.honor);
  if (suits.length == 1 && hasWeather) {
    lines.add(const ScoreLine.times(ScoreBonus.halfHalf, 2));
  } else if (suits.length == 1) {
    lines.add(const ScoreLine.times(ScoreBonus.oneColor, 5));
  } else if (suits.isEmpty) {
    lines.add(const ScoreLine.times(ScoreBonus.allWeather, 5));
  }

  return ScoreResult(lines);
}

/// 손패가 "머리 1쌍 + 나머지 전부 트리플"인지.
/// 조건: 모든 종류의 장수가 0/2/3장이고, 2장인 종류가 정확히 하나.
bool _isAllTripleHand(List<int> counts) {
  var pairs = 0;
  for (final c in counts) {
    if (c == 2) {
      pairs++;
    } else if (c != 0 && c != 3) {
      return false;
    }
  }
  return pairs == 1;
}

/// 손패가 "머리 1쌍 + 나머지 전부 스트레이트"로 분해 가능한지.
bool _isAllStraightHand(List<int> counts) {
  for (var head = 0; head < Tile.kindCount; head++) {
    if (counts[head] < 2) continue;
    counts[head] -= 2;
    final ok = _decomposeRunsOnly(List.of(counts));
    counts[head] += 2;
    if (ok) return true;
  }
  return false;
}

/// counts를 스트레이트만으로 소진할 수 있는지. 가장 작은 키는 반드시
/// (key, key+1, key+2) 스트레이트의 시작이어야 하므로 탐욕적으로 확정된다.
bool _decomposeRunsOnly(List<int> counts) {
  for (var key = 0; key < 27; key++) {
    while (counts[key] > 0) {
      final rank = key % 9 + 1;
      if (rank > 7 || counts[key + 1] == 0 || counts[key + 2] == 0) {
        return false;
      }
      counts[key]--;
      counts[key + 1]--;
      counts[key + 2]--;
    }
  }
  // 날씨패가 남아 있으면 스트레이트 불가.
  for (var key = 27; key < Tile.kindCount; key++) {
    if (counts[key] > 0) return false;
  }
  return true;
}
