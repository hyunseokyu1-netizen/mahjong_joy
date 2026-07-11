import '../logic/claim.dart';
import '../models/tile.dart';

/// 규칙 기반 단순 AI.
///
/// 판단 기준은 손패 잠재력 점수: 완성 몸통 100점, 부분 몸통(쌍/양면/간짱) 20점.
/// - 버리기: 제거했을 때 남은 손패 점수가 가장 높은 패를 버린다.
/// - 뺏어오기: 뺏은 뒤(몸통 +1, 최적 버리기 포함) 점수가 오를 때만 실행.
/// 완성 선언은 컨트롤러가 엔진의 판정으로 처리하므로 여기서 다루지 않는다.
class SimpleAi {
  /// 버릴 패 선택. [hand]는 버리기 직전 상태 (13 - 3×meld + 1 장).
  Tile chooseDiscard(List<Tile> hand, int meldCount) {
    Tile? best;
    var bestScore = -1;
    final seen = <int>{};
    for (final tile in hand) {
      if (!seen.add(tile.key)) continue; // 같은 종류는 한 번만 평가
      final rest = List.of(hand)..remove(tile);
      final score = _handPotential(rest, meldCount);
      if (score > bestScore) {
        bestScore = score;
        best = tile;
      }
    }
    return best!;
  }

  /// 뺏어오기 여부 결정. 이득이 없으면 null (패스).
  ClaimOption? considerClaim(
      List<Tile> hand, int meldCount, List<ClaimOption> options) {
    final baseline = _handPotential(hand, meldCount) + meldCount * 100;

    ClaimOption? best;
    var bestScore = baseline;
    for (final option in options) {
      final afterClaim = List.of(hand);
      for (final t in option.tilesFromHand) {
        afterClaim.remove(t);
      }
      // 뺏은 뒤에는 한 장을 버려야 하므로, 최적 버리기 후 점수로 평가
      final discard = chooseDiscard(afterClaim, meldCount + 1);
      final rest = List.of(afterClaim)..remove(discard);
      final score = _handPotential(rest, meldCount + 1) + (meldCount + 1) * 100;
      if (score > bestScore) {
        bestScore = score;
        best = option;
      }
    }
    return best;
  }

  /// 손패 잠재력: 몸통/부분몸통의 최적 조합 점수 (재귀 탐색).
  int _handPotential(List<Tile> hand, int meldCount) {
    final counts = List<int>.filled(Tile.kindCount, 0);
    for (final t in hand) {
      counts[t.key]++;
    }
    // 부분 몸통은 (남은 몸통 수 + 머리 1개)까지만 가치가 있다
    final maxPartials = (4 - meldCount) + 1;
    return _bestScore(counts, 0, 0, maxPartials);
  }

  int _bestScore(List<int> counts, int key, int partialsUsed, int maxPartials) {
    while (key < Tile.kindCount && counts[key] == 0) {
      key++;
    }
    if (key == Tile.kindCount) return 0;

    // 이 패를 아무 조합에도 쓰지 않는 경우
    counts[key]--;
    var best = _bestScore(counts, key, partialsUsed, maxPartials);
    counts[key]++;

    final tile = Tile.fromKey(key);
    final suited = !tile.isHonor;

    // 트리플
    if (counts[key] >= 3) {
      counts[key] -= 3;
      final s = 100 + _bestScore(counts, key, partialsUsed, maxPartials);
      counts[key] += 3;
      if (s > best) best = s;
    }
    // 스트레이트
    if (suited && tile.rank <= 7 && counts[key + 1] > 0 && counts[key + 2] > 0) {
      counts[key]--;
      counts[key + 1]--;
      counts[key + 2]--;
      final s = 100 + _bestScore(counts, key, partialsUsed, maxPartials);
      counts[key]++;
      counts[key + 1]++;
      counts[key + 2]++;
      if (s > best) best = s;
    }
    if (partialsUsed < maxPartials) {
      // 쌍 (머리 또는 트리플 후보)
      if (counts[key] >= 2) {
        counts[key] -= 2;
        final s = 20 + _bestScore(counts, key, partialsUsed + 1, maxPartials);
        counts[key] += 2;
        if (s > best) best = s;
      }
      // 양면/변짱 (연속 2장), 간짱 (한 칸 띈 2장)
      if (suited) {
        for (final gap in [1, 2]) {
          final next = key + gap;
          if (tile.rank + gap <= 9 && counts[next] > 0) {
            counts[key]--;
            counts[next]--;
            final s = 20 + _bestScore(counts, key, partialsUsed + 1, maxPartials);
            counts[key]++;
            counts[next]++;
            if (s > best) best = s;
          }
        }
      }
    }
    return best;
  }
}
