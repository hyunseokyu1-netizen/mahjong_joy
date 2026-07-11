import 'dart:math';

import '../ai/simple_ai.dart';
import '../logic/claim.dart';
import '../logic/game.dart';
import '../logic/match_state.dart';
import '../logic/win_checker.dart';
import '../models/tile.dart';
import '../settings/app_settings.dart';
import '../sound/sound_service.dart';
import 'table_controller.dart';

/// UI와 게임 엔진 사이의 컨트롤러 (로컬 AI 대전).
///
/// - 사람은 좌석 0, 나머지 3좌석은 [SimpleAi]가 자동 진행 (딜레이 포함).
/// - 사람 입력이 필요한 시점([isHumanDiscardTurn], [humanClaimOpportunity])
///   에서 자동 진행을 멈추고 대기한다.
class GameController extends TableController {
  static const int humanSeat = 0;
  static const _aiDelay = Duration(milliseconds: 600);

  final SimpleAi _ai = SimpleAi();

  @override
  late Game game;

  /// 앱 설정 (초보자 모드 여부). null이면 기본 규칙.
  final AppSettings? settings;

  /// 대국 전체 점수판 (여러 판 유지).
  @override
  final MatchState match = MatchState();

  /// 사람에게 열린 완성/뺏어오기 기회 (응답 대기 중일 때만 non-null).
  @override
  ClaimOpportunity? humanClaimOpportunity;

  /// 새 판 시작 시 증가. 진행 중이던 옛 자동 루프를 중단시키는 토큰.
  int _generation = 0;
  bool _disposed = false;

  /// 이번 판 결과를 점수판에 반영했는지 (이중 정산 방지).
  bool _resultApplied = false;

  GameController({int? seed, this.settings}) {
    _startRound(seed: seed);
  }

  /// 초보자 모드: 점수 없이 짝 맞추기만.
  @override
  bool get simpleMode => settings?.simpleMode ?? false;

  @override
  bool get canControlRounds => true;

  @override
  List<String?>? get seatNames => null;

  /// 점수판을 초기화하고 첫 판부터 새 대국을 시작한다.
  @override
  void newMatch({int? seed}) {
    match.reset();
    _startRound(seed: seed);
  }

  /// 결과 화면에서 다음 판으로.
  @override
  void nextRound() {
    if (!isFinished || match.isMatchOver) return;
    _startRound();
  }

  void _startRound({int? seed}) {
    _generation++;
    game = Game.start(random: seed == null ? Random() : Random(seed));
    humanClaimOpportunity = null;
    _resultApplied = false;
    _notify();
    _drive();
  }

  // ---- UI가 읽는 상태 ----

  @override
  bool get isFinished => game.phase == GamePhase.finished;

  @override
  bool get isHumanDiscardTurn =>
      game.phase == GamePhase.awaitingDiscard &&
      game.current == humanSeat &&
      humanClaimOpportunity == null;

  @override
  bool get canHumanTsumo => isHumanDiscardTurn && game.canDeclareTsumo();

  @override
  Player get human => game.players[humanSeat];

  /// 텐파이 가이드: 지금 손패로 기다리는 패 목록 (기획안 "남은 패 가이드").
  /// 버리기 차례(14장)에는 비워서 혼동을 막는다.
  @override
  List<Tile> get humanWaits {
    final idle = 13 - 3 * human.meldCount;
    if (human.hand.length != idle) return const [];
    return waitingTiles(human.hand, meldCount: human.meldCount);
  }

  // ---- 사람의 행동 ----

  @override
  void humanDiscard(Tile tile) {
    if (!isHumanDiscardTurn) return;
    game.discard(tile);
    SoundService.instance.tap();
    _notify();
    _drive();
  }

  @override
  void humanTsumo() {
    if (!canHumanTsumo) return;
    game.declareTsumo();
    _notify();
  }

  /// 완성/뺏어오기 기회에 대한 사람의 응답.
  /// [win]이면 론 완성, [option]이면 해당 몸통으로 뺏어오기, 둘 다 아니면 패스.
  @override
  void humanRespondClaim({bool win = false, ClaimOption? option}) {
    if (humanClaimOpportunity == null) return;
    humanClaimOpportunity = null;
    _resolveClaims(humanWin: win, humanOption: option);
    _notify();
    _drive();
  }

  // ---- 자동 진행 ----

  Future<void> _drive() async {
    final gen = _generation;
    while (!_disposed && gen == _generation && !isFinished) {
      if (game.phase == GamePhase.awaitingDiscard) {
        if (game.current == humanSeat) {
          if (game.drawnTile != null) SoundService.instance.draw();
          return; // 사람 입력 대기
        }

        await Future<void>.delayed(_aiDelay);
        if (_disposed || gen != _generation) return;

        if (game.canDeclareTsumo()) {
          game.declareTsumo();
        } else {
          final p = game.players[game.current];
          game.discard(_ai.chooseDiscard(p.hand, p.meldCount));
          SoundService.instance.tap();
        }
        _notify();
      } else {
        // awaitingClaims: 사람이 관여하면 응답을 기다린다
        ClaimOpportunity? humanOpp;
        for (final o in game.claimOpportunities) {
          if (o.seat == humanSeat) humanOpp = o;
        }
        if (humanOpp != null) {
          humanClaimOpportunity = humanOpp;
          _notify();
          return; // humanRespondClaim이 이어받음
        }

        await Future<void>.delayed(const Duration(milliseconds: 350));
        if (_disposed || gen != _generation) return;
        _resolveClaims();
        _notify();
      }
    }
  }

  /// 우선순위(완성 > 뺏어오기, 동순위는 턴 순서)에 따라 클레임을 처리한다.
  /// 사람의 결정은 인자로 받고, AI는 즉석에서 판단한다.
  void _resolveClaims({bool humanWin = false, ClaimOption? humanOption}) {
    for (final o in game.claimOpportunities) {
      final wantsWin = o.seat == humanSeat ? humanWin : o.canWin;
      if (wantsWin) {
        game.declareRon(o.seat);
        return;
      }
    }
    for (final o in game.claimOpportunities) {
      final choice = o.seat == humanSeat
          ? humanOption
          : _ai.considerClaim(
              game.players[o.seat].hand, game.players[o.seat].meldCount,
              o.options);
      if (choice != null) {
        game.applyClaim(o.seat, choice);
        SoundService.instance.claim();
        return;
      }
    }
    game.passClaims();
  }

  void _notify() {
    if (_disposed) return;
    // 판이 끝나는 모든 경로는 _notify를 거치므로 여기서 한 번만 정산한다.
    if (game.phase == GamePhase.finished && !_resultApplied) {
      match.applyGame(game, scored: !simpleMode);
      _resultApplied = true;
      if (game.winner == humanSeat) {
        SoundService.instance.win();
      } else {
        SoundService.instance.lose();
      }
    }
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
