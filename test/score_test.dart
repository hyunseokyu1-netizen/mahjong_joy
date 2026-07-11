import 'package:flutter_test/flutter_test.dart';
import 'package:mahjong_joy/logic/claim.dart';
import 'package:mahjong_joy/logic/score.dart';
import 'package:mahjong_joy/models/tile.dart';

Tile m(int r) => Tile(Suit.man, r);
Tile p(int r) => Tile(Suit.pin, r);
Tile s(int r) => Tile(Suit.sou, r);
Tile h(int r) => Tile(Suit.honor, r);

List<ScoreBonus> bonusesOf(ScoreResult r) => [for (final l in r.lines) l.bonus];

void main() {
  group('점수 계산 calculateScore', () {
    test('보너스 없음: 몸통 공개(론) 완성은 기본 100점', () {
      // 손패 123m 789s 111s + 55p / 공개몸통 456p
      final r = calculateScore(
        hand: [m(1), m(2), m(3), s(7), s(8), s(9), s(1), s(1), s(1), p(5), p(5)],
        melds: [Meld(MeldType.run, [p(4), p(5), p(6)])],
        isTsumo: false,
        wallCount: 50,
      );
      expect(r.total, 100);
      expect(r.lines, hasLength(1));
      expect(r.subtotal(1), 100);
    });

    test('날씨 세트 2개 + 혼자 힘으로: (100+100)×2 = 400', () {
      // ☀☀☀ 🌈🌈🌈 123m 456p + 99s → 세 종류 숫자패라 깔맞춤 없음
      final r = calculateScore(
        hand: [
          h(1), h(1), h(1), h(7), h(7), h(7),
          m(1), m(2), m(3), p(4), p(5), p(6), s(9), s(9),
        ],
        melds: [],
        isTsumo: false,
        wallCount: 50,
      );
      expect(bonusesOf(r), containsAll([ScoreBonus.weatherSet, ScoreBonus.solo]));
      final weather =
          r.lines.firstWhere((l) => l.bonus == ScoreBonus.weatherSet);
      expect(weather.count, 2);
      expect(weather.plus, 100);
      expect(r.total, 400);
    });

    test('원 컬러 + 혼자 힘으로: 100×2×5 = 1000', () {
      // 123m 456m 789m 111m + 99m
      final r = calculateScore(
        hand: [
          m(1), m(2), m(3), m(4), m(5), m(6), m(7), m(8), m(9),
          m(1), m(1), m(1), m(9), m(9),
        ],
        melds: [],
        isTsumo: false,
        wallCount: 50,
      );
      expect(bonusesOf(r), containsAll([ScoreBonus.oneColor, ScoreBonus.solo]));
      expect(r.total, 1000);
    });

    test('하프 앤 하프 + 날씨 세트: (100+50)×2×2 = 600', () {
      // 123m 456m 777m ☀☀☀ + 99m
      final r = calculateScore(
        hand: [
          m(1), m(2), m(3), m(4), m(5), m(6), m(7), m(7), m(7),
          h(1), h(1), h(1), m(9), m(9),
        ],
        melds: [],
        isTsumo: false,
        wallCount: 50,
      );
      expect(
          bonusesOf(r),
          containsAll(
              [ScoreBonus.halfHalf, ScoreBonus.weatherSet, ScoreBonus.solo]));
      expect(r.total, 600);
    });

    test('올 스트레이트: (100+200)×2 = 600', () {
      // 123m 456m 789m 123p + 99s
      final r = calculateScore(
        hand: [
          m(1), m(2), m(3), m(4), m(5), m(6), m(7), m(8), m(9),
          p(1), p(2), p(3), s(9), s(9),
        ],
        melds: [],
        isTsumo: false,
        wallCount: 50,
      );
      expect(bonusesOf(r), contains(ScoreBonus.allStraight));
      expect(r.total, 600);
    });

    test('올 트리플 + 날씨 세트: (100+50)×2×3 = 900', () {
      // 111m 222m 333p ☀☀☀ + 99s
      final r = calculateScore(
        hand: [
          m(1), m(1), m(1), m(2), m(2), m(2), p(3), p(3), p(3),
          h(1), h(1), h(1), s(9), s(9),
        ],
        melds: [],
        isTsumo: false,
        wallCount: 50,
      );
      expect(bonusesOf(r),
          containsAll([ScoreBonus.allTriple, ScoreBonus.weatherSet]));
      expect(bonusesOf(r), isNot(contains(ScoreBonus.allStraight)));
      expect(r.total, 900);
    });

    test('내가 뽑았다 + 라스트 캐치 (몸통 공개): 100+100+200 = 400', () {
      final r = calculateScore(
        hand: [m(1), m(2), m(3), s(7), s(8), s(9), s(1), s(1), s(1), p(5), p(5)],
        melds: [Meld(MeldType.triple, [p(4), p(4), p(4)])],
        isTsumo: true,
        wallCount: 3,
      );
      expect(bonusesOf(r),
          containsAll([ScoreBonus.selfDraw, ScoreBonus.lastCatch]));
      expect(bonusesOf(r), isNot(contains(ScoreBonus.solo)));
      expect(r.total, 400);
    });

    test('올 웨더 잭팟: 전부 날씨패면 (100+200)×2×3×5 = 9000', () {
      // ☀☀☀ ☁☁☁ 🌧🌧🌧 ❄❄❄ + 🌙🌙
      final r = calculateScore(
        hand: [
          h(1), h(1), h(1), h(2), h(2), h(2), h(3), h(3), h(3),
          h(4), h(4), h(4), h(5), h(5),
        ],
        melds: [],
        isTsumo: false,
        wallCount: 50,
      );
      expect(
          bonusesOf(r),
          containsAll([
            ScoreBonus.allWeather,
            ScoreBonus.allTriple,
            ScoreBonus.weatherSet,
            ScoreBonus.solo,
          ]));
      expect(
          r.lines.firstWhere((l) => l.bonus == ScoreBonus.weatherSet).count, 4);
      expect(r.total, 9000);
    });

    test('몸통에 스트레이트가 섞이면 올 트리플이 아니다', () {
      final r = calculateScore(
        hand: [m(1), m(1), m(1), m(2), m(2), m(2), p(3), p(3), p(3), s(9), s(9)],
        melds: [Meld(MeldType.run, [p(4), p(5), p(6)])],
        isTsumo: false,
        wallCount: 50,
      );
      expect(bonusesOf(r), isNot(contains(ScoreBonus.allTriple)));
    });

    test('소계는 더하기 먼저, 곱하기 나중 순서로 커진다', () {
      // 원 컬러 손패: 기본 100 → ×2 → ×5
      final r = calculateScore(
        hand: [
          m(1), m(2), m(3), m(4), m(5), m(6), m(7), m(8), m(9),
          m(1), m(1), m(1), m(9), m(9),
        ],
        melds: [],
        isTsumo: false,
        wallCount: 50,
      );
      var prev = 0;
      for (var i = 1; i <= r.lines.length; i++) {
        expect(r.subtotal(i), greaterThan(prev));
        prev = r.subtotal(i);
      }
      expect(prev, r.total);
    });
  });
}
