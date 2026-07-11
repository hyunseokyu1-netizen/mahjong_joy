import '../models/tile.dart';

enum MeldType { triple, run }

/// 공개 몸통 (뺏어오기로 완성한 세트).
class Meld {
  final MeldType type;

  /// 몸통을 구성하는 3장 (정렬됨). 버려진 패 포함.
  final List<Tile> tiles;

  Meld(this.type, List<Tile> tiles) : tiles = List.of(tiles)..sort();

  @override
  String toString() => tiles.join(' ');

  @override
  bool operator ==(Object other) =>
      other is Meld &&
      other.type == type &&
      other.tiles.length == tiles.length &&
      List.generate(tiles.length, (i) => other.tiles[i] == tiles[i])
          .every((e) => e);

  @override
  int get hashCode => Object.hash(type, Object.hashAll(tiles));
}

/// 뺏어오기 선택지: 버려진 패와 손패 2장으로 만드는 몸통.
class ClaimOption {
  final Meld meld;

  /// 손패에서 내놓아야 하는 2장.
  final List<Tile> tilesFromHand;

  ClaimOption(this.meld, this.tilesFromHand);

  @override
  String toString() => meld.toString();
}

/// 누군가 버린 [discarded] 패로 [hand]에서 완성할 수 있는 몸통 목록.
/// 심플 룰: 치/퐁 구분 없이, 어느 자리에서 버렸든 가능하면 뺏어올 수 있다.
List<ClaimOption> claimableSets(List<Tile> hand, Tile discarded) {
  final counts = List<int>.filled(Tile.kindCount, 0);
  for (final t in hand) {
    counts[t.key]++;
  }

  final options = <ClaimOption>[];

  // 트리플: 같은 패가 손에 2장 이상
  if (counts[discarded.key] >= 2) {
    options.add(ClaimOption(
      Meld(MeldType.triple, [discarded, discarded, discarded]),
      [discarded, discarded],
    ));
  }

  // 스트레이트: 수패만. discarded가 낀 연속 3구간 후보는 최대 3개.
  if (!discarded.isHonor) {
    final r = discarded.rank;
    for (final start in [r - 2, r - 1, r]) {
      if (start < 1 || start + 2 > 9) continue;
      final needed = [start, start + 1, start + 2]
          .where((rank) => rank != r)
          .map((rank) => Tile(discarded.suit, rank))
          .toList();
      if (needed.every((t) => counts[t.key] > 0)) {
        options.add(ClaimOption(
          Meld(MeldType.run, [discarded, ...needed]),
          needed,
        ));
      }
    }
  }

  return options;
}
