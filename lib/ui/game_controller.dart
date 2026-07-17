import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';

import '../ai/simple_ai.dart';
import '../logic/claim.dart';
import '../logic/game.dart';
import '../logic/match_state.dart';
import '../logic/win_checker.dart';
import '../models/tile.dart';
import '../settings/app_settings.dart';
import '../sound/sound_service.dart';
import 'table_controller.dart';

/// 사람 또는 AI의 완성/뺏어오기 응답.
class _ClaimAnswer {
  final bool win;
  final ClaimOption? option;

  const _ClaimAnswer({this.win = false, this.option});
}

/// UI와 게임 엔진 사이의 컨트롤러 (로컬 AI 대전).
///
/// - 사람은 좌석 0, 나머지 3좌석은 [SimpleAi]가 자동 진행 (딜레이 포함).
/// - 사람 입력이 필요한 시점([isHumanDiscardTurn], [humanClaimOpportunity])
///   에서 자동 진행을 멈추고 대기한다.
class GameController extends TableController {
  static const int humanSeat = 0;
  static const _aiDelay = Duration(milliseconds: 600);

  /// AI끼리만 경쟁하는(사람이 전혀 관여하지 않는) 완성/뺏어오기를
  /// 확정하기 전 대기시간. 아무도 보고 있지 않은 결정이므로 늦출
  /// 이유가 없어 0으로 둔다.
  static const _aiClaimDelay = Duration.zero;

  static const _defaultAiThinkMin = 500;
  static const _defaultAiThinkRangeMs = 12500; // 기본: 0.5~13초

  final SimpleAi _ai = SimpleAi();
  final Random _random = Random();

  /// 좌석 → 응답 (이번 라운드에 관여하는 좌석만 채워진다). 라운드가
  /// 시작되지 않았으면 null.
  Map<int, _ClaimAnswer>? _responses;

  /// 아직 응답하지 않은 좌석들 (사람 포함, 사람이 관여하는 라운드에서만
  /// 쓰인다 — AI끼리만인 라운드는 즉시 계산되어 비어 있다).
  final Set<int> _awaiting = {};

  /// 사람과 경쟁 중인 AI 좌석별 고민 타이머. 좌석마다 독립적으로 돌아가며,
  /// 먼저 끝나는 쪽이 이긴다(사람의 클릭과도 마찬가지로 "먼저 응답한
  /// 쪽" 규칙을 그대로 적용).
  final Map<int, Timer> _aiThinkTimers = {};

  /// "먼저 응답한 사람이 가져간다" 판정을 위해 가장 먼저 도착한
  /// 뺏어오기(비완성) 응답을 기억해둔다. 완성 가능한 좌석이 아직 응답
  ///하지 않았다면 이보다 나중에 온 완성 선언이 우선해야 하므로 곧바로
  /// 확정하지 않고 기록만 해둔다.
  int? _leadingClaimSeat;
  ClaimOption? _leadingClaimOption;

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

  /// 사람과 AI가 같은 패를 동시에 노릴 때, AI 각자의 "고민 시간"
  /// 최솟값·범위. 항상 즉시 응답하면 AI가 사람보다 먼저 채가는 것처럼
  /// 느껴진다는 피드백을 반영해, 사람의 15초 응답 창과 비슷한 폭으로
  /// 무작위화한다. 최종 승자는 "먼저 응답한 쪽"이며(완성은 항상
  /// 뺏어오기보다 우선), AI마다 독립적으로 타이머가 돌아간다.
  /// 테스트에서 짧게 주입할 수 있도록 생성자 인자로 뺐다.
  final int aiThinkMin;
  final int aiThinkRangeMs;

  GameController({
    int? seed,
    this.settings,
    this.aiThinkMin = _defaultAiThinkMin,
    this.aiThinkRangeMs = _defaultAiThinkRangeMs,
  }) {
    _startRound(seed: seed);
  }

  /// [aiThinkMin] ~ [aiThinkMin]+[aiThinkRangeMs] 사이의 무작위 지연.
  Duration _randomAiThink() {
    if (aiThinkRangeMs <= 0) return Duration(milliseconds: aiThinkMin);
    return Duration(milliseconds: aiThinkMin + _random.nextInt(aiThinkRangeMs));
  }

  /// 초보자 모드: 점수 없이 짝 맞추기만.
  @override
  bool get simpleMode => settings?.simpleMode ?? false;

  @override
  bool get canControlRounds => true;

  @override
  List<String?>? get seatNames => null;

  /// AI가 사람과 경쟁 중이라 아직 고민 중인 좌석들. UI가
  /// "🤔 OO 고르는 중..." 배너에 사용한다.
  @override
  List<int> get claimWaitingSeats =>
      _awaiting.where((s) => s != humanSeat).toList();

  /// 테스트 전용: `game`을 직접 조작해 만든 상황을 자동 진행 루프가
  /// 인식하게 한다.
  @visibleForTesting
  void debugPoke() => _drive();

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
    _clearClaimRoundState();
    _resultApplied = false;
    _notify();
    _drive();
  }

  /// 진행 중이던 클레임 라운드 상태(응답 기록·AI 고민 타이머 포함)를
  /// 초기화한다.
  void _clearClaimRoundState() {
    _cancelAiThinkTimers();
    _responses = null;
    _awaiting.clear();
    humanClaimOpportunity = null;
    _leadingClaimSeat = null;
    _leadingClaimOption = null;
  }

  void _cancelAiThinkTimers() {
    for (final t in _aiThinkTimers.values) {
      t.cancel();
    }
    _aiThinkTimers.clear();
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

  /// 완성/뺏어오기 기회에 대한 사람의 응답. 먼저 응답한 쪽이 가져간다
  /// (완성은 뺏어오기보다 항상 우선). [win]이면 론 완성, [option]이면
  /// 해당 몸통으로 뺏어오기, 둘 다 아니면 패스.
  @override
  void humanRespondClaim({bool win = false, ClaimOption? option}) {
    if (humanClaimOpportunity == null || !_awaiting.contains(humanSeat)) {
      return;
    }
    final answer = _ClaimAnswer(win: win, option: option);
    _responses![humanSeat] = answer;
    _awaiting.remove(humanSeat);
    humanClaimOpportunity = null;
    _onAwaitedAnswer(humanSeat, answer);
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
        // awaitingClaims
        if (_responses == null) {
          _setupClaimRound(gen);
          _notify();
        }
        if (_awaiting.isNotEmpty) return; // 사람 또는 AI 고민 대기

        await Future<void>.delayed(_aiClaimDelay);
        if (_disposed || gen != _generation) return;
        _resolveClaimsByPriority();
        _notify();
      }
    }
  }

  /// 이번 완성/뺏어오기 라운드를 시작한다. 사람이 관여하지 않는(=AI끼리만
  /// 경쟁하는) 라운드는 즉시 계산해 우선순위로 처리하고, 사람이 관여하면
  /// 전원(AI 포함)을 "먼저 응답한 쪽이 가져간다" 경로로 돌린다 —
  /// AI 각자에게 독립적인 무작위 고민 시간을 부여한다.
  void _setupClaimRound(int gen) {
    _responses = {};
    _awaiting.clear();
    _leadingClaimSeat = null;
    _leadingClaimOption = null;
    final opportunities = game.claimOpportunities;
    final humanInvolved = opportunities.any((o) => o.seat == humanSeat);

    if (!humanInvolved) {
      for (final o in opportunities) {
        _responses![o.seat] = _aiAnswerFor(o);
      }
      return;
    }

    for (final o in opportunities) {
      _awaiting.add(o.seat);
      if (o.seat == humanSeat) {
        humanClaimOpportunity = o;
      } else {
        _aiThinkTimers[o.seat] =
            Timer(_randomAiThink(), () => _onAiThinkDone(o.seat, gen));
      }
    }
  }

  void _onAiThinkDone(int seat, int gen) {
    if (_disposed || gen != _generation) return;
    if (_responses == null || !_awaiting.contains(seat)) return;
    final opp = _opportunityOf(seat);
    if (opp == null) return; // 이미 라운드가 끝났음
    final answer = _aiAnswerFor(opp);
    _responses![seat] = answer;
    _awaiting.remove(seat);
    _onAwaitedAnswer(seat, answer);
    _notify();
    _drive();
  }

  _ClaimAnswer _aiAnswerFor(ClaimOpportunity opp) {
    if (opp.canWin) return const _ClaimAnswer(win: true);
    final p = game.players[opp.seat];
    final choice = _ai.considerClaim(p.hand, p.meldCount, opp.options);
    return _ClaimAnswer(option: choice);
  }

  ClaimOpportunity? _opportunityOf(int seat) {
    for (final o in game.claimOpportunities) {
      if (o.seat == seat) return o;
    }
    return null;
  }

  /// 응답이 하나 도착할 때마다 호출된다("먼저 응답한 사람이 가져간다").
  /// 완성은 도착한 즉시 확정하고(이보다 먼저 응답한 사람은 있을 수
  /// 없으므로), 뺏어오기는 가장 먼저 온 것만 기억해뒀다가 완성 가능한
  /// 좌석이 전부 응답을 마친 뒤에 확정한다(완성이 항상 우선하므로).
  void _onAwaitedAnswer(int seat, _ClaimAnswer answer) {
    if (_responses == null) return; // 이미 확정됨
    final opp = _opportunityOf(seat);
    if (opp == null) return;

    if (answer.win && opp.canWin) {
      _finalizeAwaitedWin(seat);
      return;
    }
    if (answer.option != null) {
      _leadingClaimSeat ??= seat;
      _leadingClaimOption ??= answer.option;
    }
    _tryFinalizeAwaitedClaim();
  }

  void _tryFinalizeAwaitedClaim() {
    if (_responses == null) return;
    final winCapablePending =
        game.claimOpportunities.any((o) => o.canWin && _awaiting.contains(o.seat));
    if (winCapablePending) return; // 이 좌석이 나중에 완성을 선언할 수도 있다

    if (_leadingClaimSeat != null) {
      _finalizeAwaitedClaim(_leadingClaimSeat!, _leadingClaimOption!);
    } else if (_awaiting.isEmpty) {
      _finalizeAwaitedPass();
    }
  }

  void _finalizeAwaitedWin(int seat) {
    _cancelAiThinkTimers();
    _responses = null;
    _awaiting.clear();
    humanClaimOpportunity = null;
    _leadingClaimSeat = null;
    _leadingClaimOption = null;
    game.declareRon(seat);
  }

  void _finalizeAwaitedClaim(int seat, ClaimOption option) {
    _cancelAiThinkTimers();
    _responses = null;
    _awaiting.clear();
    humanClaimOpportunity = null;
    _leadingClaimSeat = null;
    _leadingClaimOption = null;
    game.applyClaim(seat, option);
    SoundService.instance.claim();
  }

  void _finalizeAwaitedPass() {
    _cancelAiThinkTimers();
    _responses = null;
    _awaiting.clear();
    humanClaimOpportunity = null;
    _leadingClaimSeat = null;
    _leadingClaimOption = null;
    game.passClaims();
  }

  /// AI끼리만 경쟁하는(사람이 전혀 관여하지 않는) 라운드를 우선순위
  /// (완성 > 뺏어오기, 동순위는 턴 순서)대로 처리한다. 이 경로는 아무도
  /// "누가 더 빨랐는지"를 보고 있지 않으므로 고정된 턴 순서로
  /// 결정해도 무방하다.
  void _resolveClaimsByPriority() {
    final responses = _responses ?? const <int, _ClaimAnswer>{};
    _responses = null;
    for (final o in game.claimOpportunities) {
      if (responses[o.seat]?.win ?? false) {
        game.declareRon(o.seat);
        return;
      }
    }
    for (final o in game.claimOpportunities) {
      final option = responses[o.seat]?.option;
      if (option != null) {
        game.applyClaim(o.seat, option);
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
    _cancelAiThinkTimers();
    super.dispose();
  }
}
