import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:mahjong_joy/ai/simple_ai.dart';
import 'package:mahjong_joy/logic/game.dart';

enum ClaimActed { won, claimed }

/// AI 4인이 한 판을 끝까지 자동 진행한다. 종료된 Game을 반환.
Game playFullGame(int seed) {
  final game = Game.start(random: Random(seed));
  final ai = SimpleAi();
  var steps = 0;

  while (game.phase != GamePhase.finished) {
    steps++;
    expect(steps, lessThan(1000), reason: '게임이 끝나지 않음 (seed=$seed)');

    switch (game.phase) {
      case GamePhase.awaitingDiscard:
        if (game.canDeclareTsumo()) {
          game.declareTsumo();
        } else {
          final p = game.players[game.current];
          game.discard(ai.chooseDiscard(p.hand, p.meldCount));
        }
      case GamePhase.awaitingClaims:
        // 우선순위: 완성(론) > 뺏어오기. 목록은 이미 턴 순서로 정렬됨.
        final opportunities = game.claimOpportunities;
        ClaimActed? acted;
        for (final opp in opportunities) {
          if (opp.canWin) {
            game.declareRon(opp.seat);
            acted = ClaimActed.won;
            break;
          }
        }
        if (acted == null) {
          for (final opp in opportunities) {
            final p = game.players[opp.seat];
            final choice = ai.considerClaim(p.hand, p.meldCount, opp.options);
            if (choice != null) {
              game.applyClaim(opp.seat, choice);
              acted = ClaimActed.claimed;
              break;
            }
          }
        }
        if (acted == null) game.passClaims();
      case GamePhase.finished:
        break;
    }

    checkInvariants(game, seed);
  }
  return game;
}

/// 모든 단계에서 지켜져야 하는 불변 조건.
void checkInvariants(Game game, int seed) {
  // 타일 보존: 손패 + 공개몸통 + 바닥패 + 덱 = 136
  var total = game.wallCount;
  for (final p in game.players) {
    total += p.hand.length + p.melds.length * 3 + p.discards.length;
  }
  expect(total, 136, reason: 'seed=$seed');

  // 손패 크기: 대기 중 13-3m, 버리기 차례인 현재 플레이어만 +1.
  // 츠모 승자는 14번째 패를 든 채 끝나므로 종료 후에는 승자만 +1 허용.
  for (final p in game.players) {
    final idle = 13 - 3 * p.meldCount;
    final mayHoldExtra = game.phase == GamePhase.awaitingDiscard
        ? p.seat == game.current
        : game.phase == GamePhase.finished && p.seat == game.winner;
    expect(p.hand.length, anyOf(idle, mayHoldExtra ? idle + 1 : idle),
        reason: 'seed=$seed seat=${p.seat}');
  }
}
