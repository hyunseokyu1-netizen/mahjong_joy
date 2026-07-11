import '../models/tile.dart';

/// 승리 판정: 손패가 "몸통 N개 + 머리 1쌍"으로 완전히 분해되는지 검사한다.
///
/// [tiles]는 아직 공개하지 않은 손패 + 방금 얻은 패.
/// [meldCount]는 이미 뺏어오기로 공개한 몸통 수 (0~4).
/// 필요한 몸통 수는 4 - meldCount이며, tiles.length는
/// (4 - meldCount) * 3 + 2 여야 한다.
bool isWinningHand(List<Tile> tiles, {int meldCount = 0}) {
  final setsNeeded = 4 - meldCount;
  if (setsNeeded < 0 || tiles.length != setsNeeded * 3 + 2) return false;

  final counts = List<int>.filled(Tile.kindCount, 0);
  for (final t in tiles) {
    counts[t.key]++;
    if (counts[t.key] > 4) return false; // 같은 패는 4장까지만 존재
  }

  // 머리(쌍) 후보를 하나씩 잡아 제거한 뒤, 나머지가 몸통으로 분해되는지 확인.
  for (var key = 0; key < Tile.kindCount; key++) {
    if (counts[key] < 2) continue;
    counts[key] -= 2;
    if (_decomposeIntoSets(counts, setsNeeded)) {
      counts[key] += 2;
      return true;
    }
    counts[key] += 2;
  }
  return false;
}

/// counts에 남은 패가 정확히 [setsNeeded]개의 몸통(트리플 or 스트레이트)으로
/// 분해되는지 재귀적으로 검사한다.
bool _decomposeIntoSets(List<int> counts, int setsNeeded) {
  if (setsNeeded == 0) return true;

  // 가장 작은 키의 남은 패를 찾는다. 이 패는 반드시 어떤 몸통의
  // 시작(또는 트리플)이어야 하므로 두 가지 경우만 시도하면 된다.
  var key = 0;
  while (key < Tile.kindCount && counts[key] == 0) {
    key++;
  }
  if (key == Tile.kindCount) return false; // 패는 없는데 몸통이 부족 → 불가

  // 경우 1: 트리플
  if (counts[key] >= 3) {
    counts[key] -= 3;
    if (_decomposeIntoSets(counts, setsNeeded - 1)) {
      counts[key] += 3;
      return true;
    }
    counts[key] += 3;
  }

  // 경우 2: 스트레이트 (수패에서만, rank 7까지 시작 가능)
  final tile = Tile.fromKey(key);
  if (!tile.isHonor && tile.rank <= 7) {
    if (counts[key + 1] > 0 && counts[key + 2] > 0) {
      counts[key]--;
      counts[key + 1]--;
      counts[key + 2]--;
      if (_decomposeIntoSets(counts, setsNeeded - 1)) {
        counts[key]++;
        counts[key + 1]++;
        counts[key + 2]++;
        return true;
      }
      counts[key]++;
      counts[key + 1]++;
      counts[key + 2]++;
    }
  }

  return false;
}

/// 텐파이 검사: 13장(-3×meld) 손패에서 어떤 패를 얻으면 완성되는지 계산한다.
/// "필요한 패 가이드" UI의 데이터 소스.
///
/// 반환: 완성으로 이어지는 타일 종류 목록 (오름차순).
List<Tile> waitingTiles(List<Tile> hand, {int meldCount = 0}) {
  final setsNeeded = 4 - meldCount;
  if (hand.length != setsNeeded * 3 + 1) return const [];

  final inHand = List<int>.filled(Tile.kindCount, 0);
  for (final t in hand) {
    inHand[t.key]++;
  }

  final waits = <Tile>[];
  for (var key = 0; key < Tile.kindCount; key++) {
    if (inHand[key] >= 4) continue; // 이미 4장 다 들고 있으면 얻을 수 없음
    final candidate = Tile.fromKey(key);
    if (isWinningHand([...hand, candidate], meldCount: meldCount)) {
      waits.add(candidate);
    }
  }
  return waits;
}
