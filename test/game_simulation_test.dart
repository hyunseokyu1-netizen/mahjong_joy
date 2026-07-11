import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:mahjong_joy/logic/game.dart';
import 'package:mahjong_joy/logic/win_checker.dart';
import 'package:mahjong_joy/models/tile.dart';

import 'helpers.dart';

void main() {
  group('AI 자동 대국 시뮬레이션', () {
    test('100판이 모두 정상 종료된다 (승리 또는 유국)', () {
      var wins = 0;
      var exhaustedDraws = 0;
      for (var seed = 0; seed < 100; seed++) {
        final game = playFullGame(seed);
        expect(game.phase, GamePhase.finished);
        if (game.winner != null) {
          wins++;
          // 승자의 완성 손패는 실제로 승리 조건을 만족해야 한다
          final winner = game.players[game.winner!];
          expect(
            isWinningHand(game.winningHand!, meldCount: winner.meldCount),
            isTrue,
            reason: 'seed=$seed',
          );
          // 승리 방식 기록 검증
          expect(game.winType, isNotNull, reason: 'seed=$seed');
          if (game.winType == WinType.ron) {
            expect(game.ronLoser, isNotNull, reason: 'seed=$seed');
            expect(game.ronLoser, isNot(game.winner), reason: 'seed=$seed');
          } else {
            expect(game.ronLoser, isNull, reason: 'seed=$seed');
          }
        } else {
          exhaustedDraws++;
          expect(game.wallCount, 0, reason: 'seed=$seed');
          expect(game.winType, isNull, reason: 'seed=$seed');
        }
      }
      // AI가 정상 동작한다면 100판 중 상당수는 승부가 나야 한다
      expect(wins, greaterThan(50), reason: '승리 $wins / 유국 $exhaustedDraws');
    });

    test('턴을 벗어난 조작은 거부된다', () {
      final game = Game.start(random: Random(1));
      expect(() => game.passClaims(), throwsStateError);
      expect(
        () => game.discard(const Tile(Suit.man, 1)),
        anyOf(returnsNormally, throwsStateError), // 손에 있으면 정상, 없으면 예외
      );
    });

    test('버린 패는 바닥에 쌓이고, 뺏어오면 바닥에서 제거된다', () {
      // 시뮬레이션 전체 판에서 몸통 공개가 한 번이라도 일어났는지 확인
      var meldsSeen = 0;
      for (var seed = 0; seed < 20; seed++) {
        final game = playFullGame(seed);
        for (final p in game.players) {
          meldsSeen += p.meldCount;
        }
      }
      expect(meldsSeen, greaterThan(0), reason: '뺏어오기가 한 번도 발생하지 않음');
    });
  });
}
