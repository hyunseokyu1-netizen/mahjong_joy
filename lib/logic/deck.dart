import 'dart:math';

import '../models/tile.dart';

/// 전체 덱 136장 생성 (34종 × 4장).
List<Tile> buildDeck() {
  final deck = <Tile>[];
  for (var key = 0; key < Tile.kindCount; key++) {
    final tile = Tile.fromKey(key);
    for (var i = 0; i < 4; i++) {
      deck.add(tile);
    }
  }
  return deck;
}

/// 배분 결과: 4인의 손패와 남은 덱.
class DealResult {
  final List<List<Tile>> hands; // 4명 × 13장 (정렬됨)
  final List<Tile> wall; // 남은 덱 (앞에서부터 드로우)

  DealResult(this.hands, this.wall);
}

/// 덱을 섞어 4인에게 13장씩 배분한다.
DealResult deal({Random? random, int playerCount = 4, int handSize = 13}) {
  final deck = buildDeck()..shuffle(random ?? Random());
  final hands = List.generate(
    playerCount,
    (i) => deck.sublist(i * handSize, (i + 1) * handSize)..sort(),
  );
  final wall = deck.sublist(playerCount * handSize);
  return DealResult(hands, wall);
}
