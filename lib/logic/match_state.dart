import 'dart:math' as math;

import 'game.dart';
import 'score.dart';

/// 한 판의 점수 정산 결과.
class RoundResult {
  final int? winner; // null = 유국
  final WinType? winType;
  final int? loser; // 론일 때 전액 지불자

  /// 승리 점수 내역 (영수증). 유국이면 null.
  final ScoreResult? score;

  /// 승자가 얻은 총점 (유국이면 0). 츠모 분담 반올림으로
  /// score.total보다 최대 2점 클 수 있다.
  final int value;

  /// 좌석별 점수 변동 (합계 0).
  final List<int> deltas;

  RoundResult({
    this.winner,
    this.winType,
    this.loser,
    this.score,
    required this.value,
    required this.deltas,
  });

  bool get isExhaustedDraw => winner == null;
}

/// 여러 판에 걸친 대국 점수 관리.
///
/// - 전원 1,000점 시작, 8판 진행 후 최종 순위.
/// - 판 점수는 [calculateScore]의 영수증 결과 (기본 100점 + 보너스).
/// - 론이면 버린 사람이 전액, 츠모면 나머지가 균등 분담.
/// - 누군가 0점 이하가 되면 대국 즉시 종료.
class MatchState {
  static const startingPoints = 1000;
  static const totalRounds = 8;

  final int playerCount;
  final List<int> scores;

  /// 좌석별 승리 횟수 (초보자 모드 순위의 기준).
  final List<int> winCounts;

  int roundsPlayed = 0;
  RoundResult? lastResult;

  MatchState([this.playerCount = 4])
      : scores = List.filled(playerCount, startingPoints),
        winCounts = List.filled(playerCount, 0);

  /// 지금 진행 중(또는 방금 끝난) 판 번호 (1~totalRounds).
  int get currentRound => math.min(roundsPlayed + 1, totalRounds);

  bool get isMatchOver =>
      roundsPlayed >= totalRounds || scores.any((s) => s <= 0);

  /// 종료된 판의 결과를 점수에 반영한다.
  /// [scored]가 false면(초보자 모드) 점수 계산 없이 승수만 기록한다.
  void applyGame(Game game, {bool scored = true}) {
    assert(game.phase == GamePhase.finished, '끝나지 않은 판은 정산할 수 없음');

    final deltas = List<int>.filled(playerCount, 0);
    var value = 0;
    ScoreResult? score;

    final w = game.winner;
    if (w != null) winCounts[w]++;
    if (w != null && scored) {
      score = scoreOf(game);
      value = score.total;
      if (game.winType == WinType.ron) {
        deltas[game.ronLoser!] = -value;
        deltas[w] = value;
      } else {
        // 균등 분담 (올림). 승자는 지불 합계만큼 받아 합계 0을 유지한다.
        final share = (value / (playerCount - 1)).ceil();
        for (var i = 0; i < playerCount; i++) {
          if (i != w) deltas[i] = -share;
        }
        value = share * (playerCount - 1);
        deltas[w] = value;
      }
    }

    for (var i = 0; i < playerCount; i++) {
      scores[i] += deltas[i];
    }
    roundsPlayed++;
    lastResult = RoundResult(
      winner: w,
      winType: game.winType,
      loser: game.ronLoser,
      score: score,
      value: value,
      deltas: deltas,
    );
  }

  /// 점수(또는 [byWins]면 승수) 내림차순 좌석 목록 (동점이면 좌석 번호 순).
  List<int> ranking({bool byWins = false}) {
    final key = byWins ? winCounts : scores;
    final seats = List.generate(playerCount, (i) => i);
    seats.sort((a, b) {
      final diff = key[b] - key[a];
      return diff != 0 ? diff : a - b;
    });
    return seats;
  }

  void reset() {
    for (var i = 0; i < playerCount; i++) {
      scores[i] = startingPoints;
      winCounts[i] = 0;
    }
    roundsPlayed = 0;
    lastResult = null;
  }
}
