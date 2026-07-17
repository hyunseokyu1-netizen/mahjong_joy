import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:flutter/foundation.dart';

import '../ai/simple_ai.dart';
import '../logic/claim.dart';
import '../logic/game.dart';
import '../logic/match_state.dart';
import '../logic/win_checker.dart';
import '../models/tile.dart';
import '../sound/sound_service.dart';
import '../ui/table_controller.dart';
import 'protocol.dart';

/// 클라이언트의 완성/뺏어오기 응답.
class _ClaimResponse {
  final bool win;
  final Meld? meld; // 뺏어오기로 만들 몸통 (null이면 패스)

  const _ClaimResponse({this.win = false, this.meld});
}

class _Client {
  final Socket socket;
  _Client(this.socket);
}

/// LAN 방의 호스트: 방 광고, 참가 관리, 게임 진행(심판)을 모두 맡는다.
/// 호스트 자신도 좌석 0의 플레이어다. 빈 좌석은 AI가 채운다.
class NetHostController extends TableController {
  NetHostController({
    required this.hostName,
    this.simpleModeOn = false,
    this.aiDelay = const Duration(milliseconds: 600),
    this.claimDelay = Duration.zero,
    this.claimTimeout = const Duration(seconds: 15),
    this.discardTimeout = turnTimeLimit,
    this.aiClaimThinkMax = const Duration(seconds: 13),
  }) {
    names[0] = hostName;
  }

  final String hostName;
  final bool simpleModeOn;
  final Duration aiDelay;

  /// AI끼리만 경쟁하는 완성/뺏어오기(사람이 전혀 관여하지 않는 라운드)를
  /// 확정하기 전 대기시간. 아무도 보고 있지 않은 결정이므로 굳이 늦출
  /// 이유가 없어 기본값은 0이다.
  final Duration claimDelay;

  /// 사람/네트워크 참가자와 AI가 같은 패를 동시에 노릴 때, AI가 응답을
  /// "숨기고 고민하는" 시간의 최댓값(무작위, 최소 500ms부터). AI가 항상
  /// 즉시 반응해 사람보다 먼저 채가는 것처럼 보이지 않도록 하기 위함.
  /// [Duration.zero]로 주면 기존처럼 AI가 즉시 응답한다(테스트용).
  final Duration aiClaimThinkMax;

  /// 완성/뺏어오기 응답 제한시간. 지나면 응답 안 한 사람만 자동 패스
  /// 처리해 한 사람 때문에 게임이 멈추지 않게 한다.
  final Duration claimTimeout;

  /// 버리기 응답 제한시간(사람/네트워크 좌석 전용). 지나면 방금 뽑은
  /// 패(뺏어온 직후처럼 뽑은 패가 없으면 AI 추천 패)를 자동으로 버려
  /// 진행을 이어간다. 로컬 AI 대전에는 적용되지 않는다(항상 즉시 응답
  /// 가능하므로).
  final Duration discardTimeout;

  final SimpleAi _ai = SimpleAi();
  final Random _random = Random();

  /// 좌석별 이름. null = AI(또는 빈 좌석).
  final List<String?> names = [null, null, null, null];

  final Map<int, _Client> _clients = {};

  /// 게임 중 이탈한 참가자의 좌석 (이름 → 좌석). 같은 이름으로
  /// 재접속하면 자리를 돌려준다 (그동안은 AI가 대신 진행).
  final Map<String, int> _lostSeats = {};

  ServerSocket? _server;
  RawDatagramSocket? _udp;

  /// 게임이 시작됐는지 (시작 후에는 참가 불가).
  bool started = false;

  @override
  late Game game;

  @override
  final MatchState match = MatchState();

  @override
  ClaimOpportunity? humanClaimOpportunity;

  /// 좌석 → 응답 (완성/뺏어오기 대기 중일 때만 non-null).
  Map<int, _ClaimResponse>? _responses;
  final Set<int> _awaiting = {};
  Timer? _claimTimer;

  /// 사람/네트워크 좌석의 버리기 대기 타이머. (좌석, 뽑을 때의 남은 패
  /// 수)로 지금 기다리는 턴을 식별해, 같은 턴에 중복으로 타이머를
  /// 새로 걸지 않는다.
  Timer? _discardTimer;
  (int, int)? _discardWaitKey;

  /// 사람/네트워크 참가자와 경쟁 중이라 무작위 고민 시간을 부여받은
  /// AI 좌석들의 타이머. 라운드가 끝나거나 dispose되면 모두 취소한다.
  final List<Timer> _aiThinkTimers = [];

  /// "먼저 응답한 사람이 가져간다" 판정을 위해, 사람/네트워크 참가자가
  /// 하나라도 경쟁 중인 라운드에서 가장 먼저 도착한 뺏어오기(비완성)
  /// 응답을 기억해둔다. 완성 가능자가 아직 다 응답하지 않았다면 이
  /// 응답보다 나중에 온 완성 선언이 있어도 그게 우선해야 하므로 곧바로
  /// 확정하지 않고 기록만 해둔다(완성은 뺏어오기보다 항상 우선).
  int? _leadingClaimSeat;
  Meld? _leadingClaimMeld;

  int _generation = 0;
  bool _driving = false;
  bool _disposed = false;
  bool _resultApplied = false;
  int? _drawSoundWall;

  int? get port => _server?.port;

  /// 테스트 전용: `game`을 직접 조작해 만든 상황을 심판 루프가
  /// 인식하게 한다 (여러 명이 동시에 클레임 대상인 상황 등, 실제
  /// 대국으로는 재현하기 번거로운 경우를 테스트하기 위함).
  @visibleForTesting
  void debugPoke() => _drive();

  int get humanCount => 1 + _clients.length;

  bool _isAiSeat(int seat) => seat != 0 && !_clients.containsKey(seat);

  /// 방 열기: TCP 수신 + (옵션) UDP 방 광고 시작.
  Future<void> open({bool advertise = true}) async {
    _server = await ServerSocket.bind(InternetAddress.anyIPv4, 0);
    _server!.listen(_onConnection);
    if (advertise) {
      try {
        _udp = await RawDatagramSocket.bind(
            InternetAddress.anyIPv4, discoveryPort, reuseAddress: true);
        _udp!.listen(_onDiscoveryPing);
      } catch (_) {
        // 광고 실패(포트 충돌 등)해도 직접 접속은 가능하므로 계속 진행.
      }
    }
    notifyListeners();
  }

  void _onDiscoveryPing(RawSocketEvent event) {
    if (event != RawSocketEvent.read) return;
    final datagram = _udp?.receive();
    if (datagram == null || started) return;
    String text;
    try {
      text = utf8.decode(datagram.data);
    } catch (_) {
      return;
    }
    if (text != discoveryPing) return;
    final reply = discoveryReplyPrefix +
        jsonEncode({
          'name': hostName,
          'port': port,
          'n': humanCount,
          'max': names.length,
        });
    _udp?.send(utf8.encode(reply), datagram.address, datagram.port);
  }

  void _onConnection(Socket socket) {
    try {
      socket.setOption(SocketOption.tcpNoDelay, true);
    } catch (_) {}
    int? seat;
    jsonMessages(socket).listen((msg) {
      if (seat == null) {
        if (msg['type'] != 'join') return;
        final name = (msg['name'] as String?)?.trim().isNotEmpty == true
            ? (msg['name'] as String).trim()
            : 'Player';
        // 게임 중이면 신규 참가는 거절하되, 이탈했던 이름은 자리 복귀.
        final int? assigned;
        if (started) {
          final lost = _lostSeats[name];
          assigned =
              lost != null && !_clients.containsKey(lost) ? lost : null;
        } else {
          assigned = _freeSeat();
        }
        if (assigned == null) {
          sendJson(socket, fullMessage());
          socket.destroy();
          return;
        }
        seat = assigned;
        final isRejoin = _lostSeats.remove(name) != null;
        names[assigned] = name;
        _clients[assigned] = _Client(socket);
        if (started) {
          if (isRejoin) _announce(TableNoticeKind.rejoined, name);
          _notifyBroadcast(); // 복귀자에게 현재 상태 전송 + 전원 이름 갱신
        } else {
          _broadcastLobby();
          notifyListeners();
        }
      } else {
        _onClientMessage(seat!, msg);
      }
    },
        onDone: () => _onDisconnect(seat, socket),
        onError: (_) => _onDisconnect(seat, socket));
  }

  int? _freeSeat() {
    for (var s = 1; s < names.length; s++) {
      if (!_clients.containsKey(s)) return s;
    }
    return null;
  }

  void _onDisconnect(int? seat, Socket socket) {
    if (seat == null || _disposed) return;
    // 이미 같은 이름으로 재접속해 좌석을 되찾은 경우(옛 소켓의 늦은
    // onDone)에는 건드리지 않는다.
    if (_clients[seat]?.socket != socket) return;
    final lostName = names[seat];
    _clients.remove(seat);
    if (started && lostName != null) {
      _lostSeats[lostName] = seat;
      _announce(TableNoticeKind.left, lostName);
    }
    names[seat] = null; // 복귀 전까지 이 좌석은 AI가 이어받는다
    if (started && game.current == seat) {
      _clearDiscardTimer(); // 이제 AI가 대신 버림
    }
    if (!started) {
      _broadcastLobby();
      notifyListeners();
      return;
    }
    // 이 좌석의 응답/차례를 기다리는 중이었다면 AI가 대신 진행.
    if (_awaiting.contains(seat)) {
      _respondClaim(seat, _aiClaimResponse(seat));
    } else {
      _notifyBroadcast();
      _drive();
    }
  }

  void _broadcastLobby() {
    final msg = lobbyMessage(names);
    for (final c in _clients.values) {
      sendJson(c.socket, msg);
    }
  }

  /// 퇴장/복귀를 방 전체(호스트 자신 포함)에 알린다.
  void _announce(TableNoticeKind kind, String name) {
    notice.value = TableNotice(kind, name);
    final msg = eventMessage(kind.name, name);
    for (final c in _clients.values) {
      sendJson(c.socket, msg);
    }
  }

  /// 여러 명이 동시에 뺏어오기/완성 기회를 받았을 때, 실제로 가져간
  /// 사람을 방 전체에 알린다. 좌석 번호는 받는 사람 시점으로 회전해
  /// 보내고, 표시 이름은 각자 UI가 언어에 맞게 붙인다.
  void _announceClaim(int actualSeat) {
    final n = names.length;
    int rot(int seat, int forSeat) => (seat - forSeat + n) % n;
    notice.value = TableNotice(TableNoticeKind.claimed, '', seat: actualSeat);
    for (final entry in _clients.entries) {
      sendJson(
        entry.value.socket,
        eventMessage('claimed', '', seat: rot(actualSeat, entry.key)),
      );
    }
  }

  /// 대국 시작 (재시작 포함). 빈 좌석은 AI.
  void startGame() {
    started = true;
    _udp?.close();
    _udp = null;
    _lostSeats.clear();
    match.reset();
    _startRound();
  }

  void _startRound() {
    _generation++;
    game = Game.start();
    humanClaimOpportunity = null;
    _responses = null;
    _awaiting.clear();
    _claimTimer?.cancel();
    _discardTimer?.cancel();
    _discardWaitKey = null;
    _cancelAiThinkTimers();
    _leadingClaimSeat = null;
    _leadingClaimMeld = null;
    _resultApplied = false;
    _notifyBroadcast();
    _drive();
  }

  // ---- TableController ----

  @override
  bool get simpleMode => simpleModeOn;

  @override
  bool get canControlRounds => true;

  @override
  List<String?>? get seatNames => names;

  @override
  List<int> get claimWaitingSeats => _awaiting.toList();

  @override
  Duration? get discardTimeLimit => discardTimeout;

  @override
  bool get isFinished => game.phase == GamePhase.finished;

  @override
  bool get isHumanDiscardTurn =>
      game.phase == GamePhase.awaitingDiscard &&
      game.current == 0 &&
      humanClaimOpportunity == null;

  @override
  bool get canHumanTsumo => isHumanDiscardTurn && game.canDeclareTsumo();

  @override
  Player get human => game.players[0];

  @override
  List<Tile> get humanWaits {
    final idle = 13 - 3 * human.meldCount;
    if (human.hand.length != idle) return const [];
    return waitingTiles(human.hand, meldCount: human.meldCount);
  }

  @override
  void humanDiscard(Tile tile) {
    if (!isHumanDiscardTurn) return;
    _clearDiscardTimer();
    game.discard(tile);
    SoundService.instance.tap();
    _notifyBroadcast();
    _drive();
  }

  @override
  void humanTsumo() {
    if (!canHumanTsumo) return;
    _clearDiscardTimer();
    game.declareTsumo();
    _notifyBroadcast();
  }

  @override
  void humanRespondClaim({bool win = false, ClaimOption? option}) {
    if (humanClaimOpportunity == null || !_awaiting.contains(0)) return;
    humanClaimOpportunity = null;
    _respondClaim(0, _ClaimResponse(win: win, meld: option?.meld));
  }

  @override
  void nextRound() {
    if (!isFinished || match.isMatchOver) return;
    _startRound();
  }

  @override
  void newMatch() {
    match.reset();
    _startRound();
  }

  // ---- 게임 진행 (심판) ----

  Future<void> _drive() async {
    if (_driving) return;
    _driving = true;
    final gen = _generation;
    try {
      while (!_disposed && gen == _generation && !isFinished) {
        if (game.phase == GamePhase.awaitingDiscard) {
          if (!_isAiSeat(game.current)) {
            // 호스트(좌석 0) 자신의 차례면 드로우 사운드 (한 번만).
            if (game.current == 0 &&
                game.drawnTile != null &&
                _drawSoundWall != game.wallCount) {
              _drawSoundWall = game.wallCount;
              SoundService.instance.draw();
            }
            _armDiscardTimer();
            return; // 사람 입력 대기 (호스트 UI 또는 소켓)
          }
          await Future<void>.delayed(aiDelay);
          if (_disposed || gen != _generation) return;
          if (game.canDeclareTsumo()) {
            game.declareTsumo();
          } else {
            final p = game.players[game.current];
            game.discard(_ai.chooseDiscard(p.hand, p.meldCount));
            SoundService.instance.tap();
          }
          _notifyBroadcast();
        } else {
          // awaitingClaims
          if (_responses == null) {
            _setupClaims();
            _notifyBroadcast();
          }
          if (_awaiting.isNotEmpty) return; // 사람 응답 대기
          await Future<void>.delayed(claimDelay);
          if (_disposed || gen != _generation) return;
          _resolveClaims();
          _notifyBroadcast();
        }
      }
    } finally {
      _driving = false;
    }
  }

  /// 사람/네트워크 좌석의 버리기 차례가 되면 제한시간 타이머를 건다.
  /// 같은 턴에 대해 이미 걸려 있으면 다시 걸지 않는다.
  void _armDiscardTimer() {
    final key = (game.current, game.wallCount);
    if (_discardWaitKey == key) return;
    _discardWaitKey = key;
    _discardTimer?.cancel();
    _discardTimer = Timer(discardTimeout, () => _onDiscardTimeout(key));
  }

  void _clearDiscardTimer() {
    _discardTimer?.cancel();
    _discardTimer = null;
    _discardWaitKey = null;
  }

  /// 제한시간 초과: 방금 뽑은 패를 그대로 버려 진행을 이어간다.
  /// 뺏어온 직후라 뽑은 패가 없으면 AI 추천 패를 대신 버린다 — 이
  /// 경우에도 안 버리고 버티면 방 전체가 멈추는 건 마찬가지이므로.
  /// 혼자 안 내고 있는 사람 때문에 네트워크 대전 전체가 멈추는 것을 막는다.
  void _onDiscardTimeout((int, int) key) {
    if (_disposed || _discardWaitKey != key) return;
    if (game.phase != GamePhase.awaitingDiscard) return;
    final p = game.players[game.current];
    final tile = game.drawnTile ?? _ai.chooseDiscard(p.hand, p.meldCount);
    _clearDiscardTimer();
    game.discard(tile);
    SoundService.instance.tap();
    _notifyBroadcast();
    _drive();
  }

  void _setupClaims() {
    _responses = {};
    _awaiting.clear();
    final opportunities = game.claimOpportunities;
    // 사람/네트워크 참가자가 하나라도 경쟁 중이면, AI는 즉시 답을 내지
    // 않고 무작위 시간만큼 "고민"한다 — 항상 즉시 응답하면 사람이
    // 결정하기도 전에 AI가 채가는 것처럼 느껴진다는 피드백을 반영했다.
    // 경쟁자가 전혀 없는 순수 AI-only 상황(사람이 관여 안 함)은 굳이
    // 늦출 필요가 없어 기존처럼 즉시 처리한다.
    final hasHumanCompetitor = opportunities.any((o) => !_isAiSeat(o.seat));
    for (final opp in opportunities) {
      if (_isAiSeat(opp.seat)) {
        if (hasHumanCompetitor && aiClaimThinkMax > Duration.zero) {
          _awaiting.add(opp.seat); // "🤔 고르는 중" 배너에 노출
          _aiThinkTimers.add(Timer(_randomAiThink(), () {
            _resolveAiThinking(opp.seat);
          }));
        } else {
          _responses![opp.seat] = _aiClaimResponseFor(opp);
        }
      } else {
        _awaiting.add(opp.seat);
        if (opp.seat == 0) humanClaimOpportunity = opp;
      }
    }
    if (_awaiting.isNotEmpty) {
      _claimTimer?.cancel();
      _claimTimer = Timer(claimTimeout, _onClaimTimeout);
    }
  }

  /// 500ms ~ [aiClaimThinkMax] 사이의 무작위 지연. claimTimeout보다 먼저
  /// 끝나도록 상한을 걸어, AI의 "생각"이 응답 제한시간에 잘려 강제
  /// 패스되지 않게 한다.
  Duration _randomAiThink() {
    const minMs = 500;
    final capMs =
        min(aiClaimThinkMax.inMilliseconds, (claimTimeout.inMilliseconds * 0.85).round());
    if (capMs <= minMs) return const Duration(milliseconds: minMs);
    return Duration(milliseconds: minMs + _random.nextInt(capMs - minMs));
  }

  /// AI 좌석의 무작위 고민 시간이 끝나 실제 응답을 기록한다.
  void _resolveAiThinking(int seat) {
    if (_disposed || _responses == null || !_awaiting.contains(seat)) return;
    final opp = _opportunityOf(seat);
    if (opp == null) return; // 이미 라운드가 끝났음
    final response = _aiClaimResponseFor(opp);
    _responses![seat] = response;
    _awaiting.remove(seat);
    _onAwaitedResponse(seat, response);
    _notifyBroadcast();
    _drive();
  }

  void _cancelAiThinkTimers() {
    for (final t in _aiThinkTimers) {
      t.cancel();
    }
    _aiThinkTimers.clear();
  }

  /// 제한시간 초과: 아직 응답하지 않은 전원을 강제로 패스 처리한 뒤,
  /// 그때까지 기록해둔 가장 먼저 온 뺏어오기 응답이 있으면 그걸로
  /// 확정한다 (강제 패스도 "응답 도착" 이벤트로 취급해 같은 판정
  /// 경로를 탄다).
  void _onClaimTimeout() {
    if (_disposed || _responses == null || _awaiting.isEmpty) return;
    humanClaimOpportunity = null;
    for (final seat in _awaiting.toList()) {
      _responses![seat] = const _ClaimResponse();
      _awaiting.remove(seat);
    }
    _tryFinalizeAwaitedClaim();
    _notifyBroadcast();
    _drive();
  }

  ClaimOpportunity? _opportunityOf(int seat) {
    for (final o in game.claimOpportunities) {
      if (o.seat == seat) return o;
    }
    return null;
  }

  _ClaimResponse _aiClaimResponse(int seat) {
    for (final opp in game.claimOpportunities) {
      if (opp.seat == seat) return _aiClaimResponseFor(opp);
    }
    return const _ClaimResponse();
  }

  _ClaimResponse _aiClaimResponseFor(ClaimOpportunity opp) {
    if (opp.canWin) return const _ClaimResponse(win: true);
    final p = game.players[opp.seat];
    final choice = _ai.considerClaim(p.hand, p.meldCount, opp.options);
    return _ClaimResponse(meld: choice?.meld);
  }

  void _respondClaim(int seat, _ClaimResponse response) {
    if (_responses == null || !_awaiting.contains(seat)) return;
    _responses![seat] = response;
    _awaiting.remove(seat);
    _onAwaitedResponse(seat, response);
    _notifyBroadcast();
    _drive();
  }

  /// "먼저 응답한 사람이 가져간다": 사람/네트워크 참가자가 하나라도
  /// 관여하는 라운드([_awaiting] 경로)에서, 응답이 하나 도착할 때마다
  /// 호출된다.
  ///
  /// - 완성은 도착한 순간 그 자리에서 바로 확정한다. 이보다 먼저 응답한
  ///   사람은 있을 수 없으므로(방금 막 도착한 응답이니까) 기다릴 이유가
  ///   없다.
  /// - 뺏어오기는 가장 먼저 도착한 것만 기억해둔다. 완성 가능한 사람이
  ///   아직 응답하지 않았다면, 그 사람이 나중에라도 완성을 선언하면
  ///   완성이 항상 우선해야 하므로 곧바로 확정하지 않고 기다린다.
  void _onAwaitedResponse(int seat, _ClaimResponse response) {
    if (_responses == null) return; // 이미 다른 경로로 확정됨
    final opp = _opportunityOf(seat);
    if (opp == null) return;

    if (response.win && opp.canWin) {
      _finalizeAwaitedWin(seat);
      return;
    }
    if (response.meld != null) {
      _leadingClaimSeat ??= seat;
      _leadingClaimMeld ??= response.meld;
    }
    _tryFinalizeAwaitedClaim();
  }

  /// 아직 응답하지 않은 완성 가능자가 없어졌다면, 기록해둔 가장 먼저
  /// 온 뺏어오기 응답으로(있다면) 확정하거나, 아무도 안 가져갔다면
  /// 유찰 처리한다.
  void _tryFinalizeAwaitedClaim() {
    if (_responses == null) return;
    final winCapablePending =
        game.claimOpportunities.any((o) => o.canWin && _awaiting.contains(o.seat));
    if (winCapablePending) return; // 이 사람이 나중에 완성을 선언할 수도 있다

    if (_leadingClaimSeat != null) {
      _finalizeAwaitedClaim(_leadingClaimSeat!, _leadingClaimMeld!);
    } else if (_awaiting.isEmpty) {
      _finalizeAwaitedPass();
    }
  }

  void _finalizeAwaitedWin(int seat) {
    _claimTimer?.cancel();
    _cancelAiThinkTimers();
    final multiParty = game.claimOpportunities.length > 1;
    _clearClaimRoundState();
    game.declareRon(seat);
    if (multiParty) _announceClaim(seat);
  }

  void _finalizeAwaitedClaim(int seat, Meld meld) {
    final opp = _opportunityOf(seat);
    _claimTimer?.cancel();
    _cancelAiThinkTimers();
    final multiParty = game.claimOpportunities.length > 1;
    _clearClaimRoundState();
    if (opp != null) {
      for (final option in opp.options) {
        if (option.meld == meld) {
          game.applyClaim(seat, option);
          SoundService.instance.claim();
          if (multiParty) _announceClaim(seat);
          return;
        }
      }
    }
    game.passClaims(); // 안전망: 선택지를 못 찾으면(이론상 발생 안 함) 유찰
  }

  void _finalizeAwaitedPass() {
    _claimTimer?.cancel();
    _cancelAiThinkTimers();
    _clearClaimRoundState();
    game.passClaims();
  }

  void _clearClaimRoundState() {
    _responses = null;
    _awaiting.clear();
    humanClaimOpportunity = null;
    _leadingClaimSeat = null;
    _leadingClaimMeld = null;
  }

  /// AI끼리만 경쟁하는(사람이 전혀 관여하지 않는) 라운드를 우선순위
  /// (완성 > 뺏어오기, 동순위는 턴 순서)대로 처리한다. 이 경로는 아무도
  /// "누가 더 빨랐는지"를 보고 있지 않으므로 응답 도착 순서 대신
  /// 고정된 턴 순서로 결정해도 무방하다.
  void _resolveClaims() {
    _claimTimer?.cancel();
    _cancelAiThinkTimers();
    final responses = _responses ?? const <int, _ClaimResponse>{};
    final opportunities = game.claimOpportunities;
    final multiParty = opportunities.length > 1;
    _responses = null;
    _awaiting.clear();
    humanClaimOpportunity = null;

    for (final opp in opportunities) {
      final r = responses[opp.seat];
      if (r != null && r.win && opp.canWin) {
        game.declareRon(opp.seat);
        if (multiParty) _announceClaim(opp.seat);
        return;
      }
    }
    for (final opp in opportunities) {
      final meld = responses[opp.seat]?.meld;
      if (meld == null) continue;
      for (final option in opp.options) {
        if (option.meld == meld) {
          game.applyClaim(opp.seat, option);
          SoundService.instance.claim();
          if (multiParty) _announceClaim(opp.seat);
          return;
        }
      }
    }
    game.passClaims();
  }

  // ---- 클라이언트 메시지 처리 ----

  void _onClientMessage(int seat, Map<String, dynamic> msg) {
    try {
      switch (msg['type']) {
        case 'discard':
          if (game.phase == GamePhase.awaitingDiscard &&
              game.current == seat) {
            _clearDiscardTimer();
            game.discard(Tile.fromKey(msg['k'] as int));
            SoundService.instance.tap();
            _notifyBroadcast();
            _drive();
          }
        case 'tsumo':
          if (game.phase == GamePhase.awaitingDiscard &&
              game.current == seat &&
              game.canDeclareTsumo()) {
            _clearDiscardTimer();
            game.declareTsumo();
            _notifyBroadcast();
          }
        case 'ron':
          _respondClaim(seat, const _ClaimResponse(win: true));
        case 'claim':
          _respondClaim(
              seat,
              _ClaimResponse(
                  meld: meldFromJson(
                      (msg['meld'] as Map).cast<String, dynamic>())));
        case 'pass':
          _respondClaim(seat, const _ClaimResponse());
      }
    } catch (_) {
      // 잘못된/뒤늦은 메시지는 무시하고 현재 상태를 다시 보내 동기화.
      _notifyBroadcast();
    }
  }

  // ---- 상태 전파 ----

  void _notifyBroadcast() {
    if (_disposed) return;
    if (game.phase == GamePhase.finished && !_resultApplied) {
      match.applyGame(game, scored: !simpleModeOn);
      _resultApplied = true;
      if (game.winner == 0) {
        SoundService.instance.win();
      } else {
        SoundService.instance.lose();
      }
    }
    for (final entry in _clients.entries) {
      sendJson(
        entry.value.socket,
        buildView(
          game: game,
          match: match,
          names: names,
          forSeat: entry.key,
          claimAwait: _awaiting,
          simpleMode: simpleModeOn,
        ),
      );
    }
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _claimTimer?.cancel();
    _discardTimer?.cancel();
    _cancelAiThinkTimers();
    _leadingClaimSeat = null;
    _leadingClaimMeld = null;
    for (final c in _clients.values) {
      c.socket.destroy();
    }
    _clients.clear();
    _server?.close();
    _udp?.close();
    super.dispose();
  }
}
