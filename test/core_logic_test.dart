import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:mahjong_joy/logic/claim.dart';
import 'package:mahjong_joy/logic/deck.dart';
import 'package:mahjong_joy/logic/win_checker.dart';
import 'package:mahjong_joy/models/tile.dart';

/// 테스트용 손패 표기: 'm123 p456 s789 z1122' (z = 자패 rank).
List<Tile> hand(String notation) {
  final tiles = <Tile>[];
  for (final group in notation.split(' ')) {
    final suit = {
      'm': Suit.man,
      'p': Suit.pin,
      's': Suit.sou,
      'z': Suit.honor,
    }[group[0]]!;
    for (final ch in group.substring(1).split('')) {
      tiles.add(Tile(suit, int.parse(ch)));
    }
  }
  return tiles;
}

void main() {
  group('Tile', () {
    test('key 인코딩은 34종을 왕복 변환한다', () {
      for (var key = 0; key < Tile.kindCount; key++) {
        expect(Tile.fromKey(key).key, key);
      }
    });

    test('정렬은 만→통→삭→자패, 숫자 오름차순', () {
      final tiles = hand('z7 s9 m1 p5')..sort();
      expect(tiles.toString(), '[1m, 5p, 9s, 중]');
    });
  });

  group('덱 생성/배분', () {
    test('덱은 정확히 136장, 종류별 4장', () {
      final deck = buildDeck();
      expect(deck.length, 136);
      for (var key = 0; key < Tile.kindCount; key++) {
        expect(deck.where((t) => t.key == key).length, 4,
            reason: '${Tile.fromKey(key)}는 4장이어야 함');
      }
    });

    test('4인에게 13장씩 배분하고 84장이 남는다', () {
      final result = deal(random: Random(42));
      expect(result.hands.length, 4);
      for (final h in result.hands) {
        expect(h.length, 13);
        expect(h, List.of(h)..sort(), reason: '손패는 정렬 상태여야 함');
      }
      expect(result.wall.length, 136 - 52);

      // 배분 + 덱을 합치면 다시 완전한 136장
      final all = [...result.hands.expand((h) => h), ...result.wall];
      expect(all.length, 136);
      for (var key = 0; key < Tile.kindCount; key++) {
        expect(all.where((t) => t.key == key).length, 4);
      }
    });
  });

  group('승리 판정 isWinningHand', () {
    test('기본형: 스트레이트 3 + 트리플 1 + 머리', () {
      expect(isWinningHand(hand('m123 m456 m789 p111 s99')), isTrue);
    });

    test('트리플만으로 구성된 손패', () {
      expect(isWinningHand(hand('m111 p222 s333 z444 z55')), isTrue);
    });

    test('자패는 스트레이트가 될 수 없다', () {
      // z123(동남서)을 몸통으로 취급하면 안 됨
      expect(isWinningHand(hand('z123 m456 m789 p111 s99')), isFalse);
    });

    test('머리가 없으면 실패', () {
      expect(isWinningHand(hand('m123 m456 m789 p123 s12')), isFalse);
    });

    test('한 끗 모자란 손패는 실패', () {
      expect(isWinningHand(hand('m123 m456 m789 p111 s89')), isFalse);
    });

    test('다중 해석 손패: 순정구련보등 + 9', () {
      // 1112345678999 + 9: 여러 분해 경로 중 하나만 성립해도 승리
      expect(isWinningHand(hand('m1112345678999 m9')), isTrue);
    });

    test('연속 쌍 함정: 22334455는 스트레이트 2개로 분해 가능', () {
      expect(isWinningHand(hand('m223344 m556677 s88')), isTrue);
    });

    test('수패 8,9에서 시작하는 스트레이트는 없다', () {
      // 899 + 뭔가로 몸통을 만들 수 없음
      expect(isWinningHand(hand('m899 m123 m456 p111 s99')), isFalse);
    });

    test('장수가 틀리면 실패', () {
      expect(isWinningHand(hand('m123 m456 m789 p111 s9')), isFalse);
      expect(isWinningHand([]), isFalse);
    });

    test('공개 몸통 1개: 11장으로 몸통 3 + 머리 판정', () {
      expect(isWinningHand(hand('m123 m456 p111 s99'), meldCount: 1), isTrue);
      expect(isWinningHand(hand('m123 m456 p111 s99'), meldCount: 0), isFalse);
    });

    test('공개 몸통 4개: 머리 쌍만 남는 경우', () {
      expect(isWinningHand(hand('s99'), meldCount: 4), isTrue);
      expect(isWinningHand(hand('s89'), meldCount: 4), isFalse);
    });
  });

  group('대기패 waitingTiles', () {
    test('양면 대기: 45 → 3, 6', () {
      final waits = waitingTiles(hand('m123 m456 m789 p11 s45'));
      expect(waits, [const Tile(Suit.sou, 3), const Tile(Suit.sou, 6)]);
    });

    test('단기 대기: 머리 짝 기다리기', () {
      final waits = waitingTiles(hand('m123 m456 m789 p123 z5'));
      expect(waits, [const Tile(Suit.honor, 5)]);
    });

    test('텐파이가 아니면 빈 목록', () {
      final waits = waitingTiles(hand('m147 p258 s369 z123 z4'));
      expect(waits, isEmpty);
    });

    test('공개 몸통이 있는 손패의 대기', () {
      final waits = waitingTiles(hand('m123 p11 s45'), meldCount: 2);
      expect(waits, [const Tile(Suit.sou, 3), const Tile(Suit.sou, 6)]);
    });

    test('장수가 틀리면 빈 목록', () {
      expect(waitingTiles(hand('m123')), isEmpty);
    });
  });

  group('뺏어오기 claimableSets', () {
    test('트리플: 손에 같은 패 2장', () {
      final options = claimableSets(hand('m55 p123'), const Tile(Suit.man, 5));
      expect(options.length, 1);
      expect(options.first.meld.type, MeldType.triple);
      expect(options.first.tilesFromHand, hand('m55'));
    });

    test('스트레이트: 버려진 4에 대해 23/35/56 세 가지', () {
      final options = claimableSets(hand('m2356'), const Tile(Suit.man, 4));
      expect(options.length, 3);
      expect(options.every((o) => o.meld.type == MeldType.run), isTrue);
      final melds = options.map((o) => o.meld.toString()).toSet();
      expect(melds, {'2m 3m 4m', '3m 4m 5m', '4m 5m 6m'});
    });

    test('자패는 트리플만 가능', () {
      final options = claimableSets(hand('z11 z23'), const Tile(Suit.honor, 1));
      expect(options.length, 1);
      expect(options.first.meld.type, MeldType.triple);
    });

    test('다른 종류 수패와는 스트레이트 불가', () {
      final options = claimableSets(hand('p23'), const Tile(Suit.man, 4));
      expect(options, isEmpty);
    });

    test('뺏어올 수 없으면 빈 목록', () {
      final options = claimableSets(hand('m19 p5 z77'), const Tile(Suit.sou, 5));
      expect(options, isEmpty);
    });
  });
}
