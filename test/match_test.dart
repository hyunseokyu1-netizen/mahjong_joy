import 'package:flutter_test/flutter_test.dart';
import 'package:mahjong_joy/logic/game.dart';
import 'package:mahjong_joy/logic/match_state.dart';
import 'package:mahjong_joy/logic/score.dart';

import 'helpers.dart';

void main() {
  group('점수 정산 MatchState', () {
    test('론/츠모/유국 정산 규칙과 합계 보존', () {
      var sawRon = false;
      var sawTsumo = false;
      for (var seed = 0; seed < 60; seed++) {
        final game = playFullGame(seed);
        final match = MatchState();
        match.applyGame(game);

        final result = match.lastResult!;
        expect(result.deltas.reduce((a, b) => a + b), 0,
            reason: 'seed=$seed 변동 합계는 0');
        expect(match.scores.reduce((a, b) => a + b),
            MatchState.startingPoints * 4,
            reason: 'seed=$seed 전체 점수 보존');
        expect(match.roundsPlayed, 1);

        final w = game.winner;
        if (w == null) {
          expect(result.value, 0);
          expect(result.score, isNull);
          expect(result.deltas, everyElement(0));
          continue;
        }

        final score = result.score!;
        expect(score.total, greaterThanOrEqualTo(baseWinScore),
            reason: 'seed=$seed');
        expect(result.deltas[w], result.value, reason: 'seed=$seed');

        // 영수증 보너스가 실제 상황과 일치하는지
        final solo = game.players[w].melds.isEmpty;
        expect(score.lines.any((l) => l.bonus == ScoreBonus.solo), solo,
            reason: 'seed=$seed');
        expect(score.lines.any((l) => l.bonus == ScoreBonus.selfDraw),
            game.winType == WinType.tsumo,
            reason: 'seed=$seed');

        if (game.winType == WinType.ron) {
          sawRon = true;
          // 버린 사람이 영수증 총점 전액 지불, 나머지는 변동 없음
          expect(result.value, score.total, reason: 'seed=$seed');
          expect(result.deltas[game.ronLoser!], -result.value,
              reason: 'seed=$seed');
          for (var s = 0; s < 4; s++) {
            if (s != w && s != game.ronLoser) {
              expect(result.deltas[s], 0, reason: 'seed=$seed seat=$s');
            }
          }
        } else {
          sawTsumo = true;
          // 나머지 셋이 균등 분담 (올림), 승자는 그 합계를 받는다
          final share = (score.total / 3).ceil();
          expect(result.value, share * 3, reason: 'seed=$seed');
          for (var s = 0; s < 4; s++) {
            if (s != w) {
              expect(result.deltas[s], -share, reason: 'seed=$seed seat=$s');
            }
          }
        }
      }
      expect(sawRon, isTrue, reason: '60판 중 론이 한 번도 없음');
      expect(sawTsumo, isTrue, reason: '60판 중 츠모가 한 번도 없음');
    });

    test('대국은 8판 이내에 끝난다 (8판 완주 또는 파산 조기 종료)', () {
      final match = MatchState();
      expect(match.isMatchOver, isFalse);
      var seed = 0;
      while (!match.isMatchOver) {
        expect(match.roundsPlayed, lessThan(MatchState.totalRounds));
        match.applyGame(playFullGame(seed++));
      }
      // 종료 사유는 둘 중 하나: 8판 완주 or 누군가 0점 이하
      expect(
        match.roundsPlayed == MatchState.totalRounds ||
            match.scores.any((s) => s <= 0),
        isTrue,
      );
    });

    test('초보자 모드(scored: false): 점수 변동 없이 승수만 기록', () {
      var sawWinner = false;
      for (var seed = 0; seed < 20; seed++) {
        final game = playFullGame(seed);
        final match = MatchState();
        match.applyGame(game, scored: false);

        expect(match.scores, everyElement(MatchState.startingPoints),
            reason: 'seed=$seed');
        expect(match.lastResult!.score, isNull, reason: 'seed=$seed');
        expect(match.lastResult!.value, 0, reason: 'seed=$seed');
        expect(match.lastResult!.deltas, everyElement(0), reason: 'seed=$seed');

        final w = game.winner;
        if (w != null) {
          sawWinner = true;
          expect(match.winCounts[w], 1, reason: 'seed=$seed');
          expect(match.winCounts.reduce((a, b) => a + b), 1,
              reason: 'seed=$seed');
        }
      }
      expect(sawWinner, isTrue);
    });

    test('0점 이하가 나오면 즉시 종료', () {
      final match = MatchState();
      match.scores[2] = 0;
      expect(match.isMatchOver, isTrue);
    });

    test('순위는 점수 내림차순', () {
      final match = MatchState();
      match.scores.setAll(0, [8000, 12000, 12000, 9000]);
      expect(match.ranking(), [1, 2, 3, 0]); // 동점(1,2)은 좌석 순
    });

    test('reset으로 새 대국 시작', () {
      final match = MatchState();
      match.applyGame(playFullGame(0));
      match.reset();
      expect(match.scores, everyElement(MatchState.startingPoints));
      expect(match.winCounts, everyElement(0));
      expect(match.roundsPlayed, 0);
      expect(match.lastResult, isNull);
    });

    test('승수 순위: byWins는 승수 내림차순', () {
      final match = MatchState();
      match.winCounts.setAll(0, [1, 3, 0, 3]);
      expect(match.ranking(byWins: true), [1, 3, 0, 2]); // 동률(1,3)은 좌석 순
    });
  });
}
