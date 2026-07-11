import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';

import '../logic/claim.dart';
import '../logic/game.dart';
import '../logic/match_state.dart';
import '../logic/win_checker.dart';
import '../models/tile.dart';
import '../sound/sound_service.dart';
import '../ui/table_controller.dart';
import 'protocol.dart';

enum NetClientStatus {
  connecting,

  /// 대기실: 호스트가 시작하기를 기다리는 중.
  lobby,

  /// 게임 진행 중 (view 수신 시작).
  playing,

  /// 게임 중 연결이 끊겨 다시 접속을 시도하는 중.
  reconnecting,

  /// 연결 종료/실패 (방 가득 참, 재접속 포기 포함).
  disconnected,
}

/// LAN 방의 참가자: 호스트가 보내주는 자기 시점(좌석 0으로 회전)의
/// 상태를 미러에 반영해 그리고, 행동은 소켓으로 보낸다.
class NetClientController extends TableController {
  final Game _mirror = Game.mirror();
  final MatchState _match = MatchState();

  Socket? _socket;
  NetClientStatus status = NetClientStatus.connecting;

  /// 대기실 참가자 이름 목록 (호스트 기준 좌석 순서, null = 빈자리/AI).
  List<String?> lobbyNames = const [null, null, null, null];

  List<String?> _viewNames = const [null, null, null, null];
  bool _simple = false;
  List<int> _claimAwait = const [];
  bool _claimAwaitMe = false;
  bool _sentClaimResponse = false;
  bool _hadMyDraw = false;
  bool _disposed = false;

  static const _maxReconnectTries = 8;
  InternetAddress? _address;
  int? _port;
  String? _name;
  int _reconnectTries = 0;

  Future<void> connect(InternetAddress address, int port,
      {required String name}) {
    _address = address;
    _port = port;
    _name = name;
    return _open();
  }

  Future<void> _open() async {
    try {
      _socket = await Socket.connect(_address!, _port!,
          timeout: const Duration(seconds: 5));
      _socket!.setOption(SocketOption.tcpNoDelay, true);
    } catch (_) {
      _onConnectionLost();
      return;
    }
    sendJson(_socket!, joinMessage(_name!));
    jsonMessages(_socket!).listen(
      _onMessage,
      onDone: _onConnectionLost,
      onError: (_) => _onConnectionLost(),
    );
  }

  /// 테스트 전용: 순간 끊김을 흉내 낸다 (재접속 로직 검증용).
  @visibleForTesting
  void debugDropConnection() => _socket?.destroy();

  void _onMessage(Map<String, dynamic> msg) {
    switch (msg['type']) {
      case 'lobby':
        lobbyNames = (msg['names'] as List).cast<String?>();
        if (status == NetClientStatus.connecting) {
          status = NetClientStatus.lobby;
        }
        _notify();
      case 'full':
        _onConnectionLost();
      case 'event':
        notice.value = TableNotice(
          TableNoticeKind.values.byName(msg['kind'] as String),
          msg['name'] as String,
        );
      case 'view':
        _applyView(msg);
    }
  }

  void _applyView(Map<String, dynamic> v) {
    final wasFinished = _mirror.phase == GamePhase.finished;
    final discardsBefore = _totalDiscards;
    final meldsBefore = _totalMelds;

    _claimAwait = applyView(v, _mirror, _match);
    _claimAwaitMe = _claimAwait.contains(0);
    if (!_claimAwaitMe) _sentClaimResponse = false;
    _viewNames = (v['names'] as List).cast<String?>();
    _simple = v['simple'] as bool;
    status = NetClientStatus.playing;
    _reconnectTries = 0; // view가 오면 연결이 건강하다는 뜻

    // 상태 전이에 맞춘 효과음 (판정은 호스트, 소리는 각자).
    if (!wasFinished && _mirror.phase == GamePhase.finished) {
      if (_mirror.winner == 0) {
        SoundService.instance.win();
      } else {
        SoundService.instance.lose();
      }
    } else {
      if (_totalDiscards > discardsBefore) SoundService.instance.tap();
      if (_totalMelds > meldsBefore) SoundService.instance.claim();
      final myDraw = _mirror.phase == GamePhase.awaitingDiscard &&
          _mirror.current == 0 &&
          _mirror.drawnTile != null;
      if (myDraw && !_hadMyDraw) SoundService.instance.draw();
      _hadMyDraw = myDraw;
    }

    _notify();
  }

  int get _totalDiscards {
    var total = 0;
    for (final p in _mirror.players) {
      total += p.discards.length;
    }
    return total;
  }

  int get _totalMelds {
    var total = 0;
    for (final p in _mirror.players) {
      total += p.melds.length;
    }
    return total;
  }

  /// 연결이 끊겼을 때: 게임 중이었다면 자리를 되찾기 위해 자동 재접속을
  /// 시도한다 (호스트가 이름으로 좌석을 돌려준다). 대기실/접속 단계 또는
  /// 재시도 소진이면 종료 처리.
  void _onConnectionLost() {
    if (_disposed) return;
    _socket?.destroy();
    _socket = null;
    final wasInGame = status == NetClientStatus.playing ||
        status == NetClientStatus.reconnecting;
    if (wasInGame && _reconnectTries < _maxReconnectTries) {
      _reconnectTries++;
      status = NetClientStatus.reconnecting;
      _notify();
      Future<void>.delayed(const Duration(seconds: 2), () {
        if (!_disposed && status == NetClientStatus.reconnecting) _open();
      });
      return;
    }
    status = NetClientStatus.disconnected;
    _notify();
  }

  void _send(Map<String, dynamic> msg) {
    final s = _socket;
    if (s != null) sendJson(s, msg);
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  // ---- TableController (미러 읽기 + 행동 전송) ----

  @override
  Game get game => _mirror;

  @override
  MatchState get match => _match;

  @override
  bool get simpleMode => _simple;

  @override
  bool get canControlRounds => false;

  @override
  bool get isReconnecting => status == NetClientStatus.reconnecting;

  @override
  List<int> get claimWaitingSeats => _claimAwait;

  @override
  List<String?>? get seatNames => _viewNames;

  @override
  bool get isFinished =>
      _mirror.phase == GamePhase.finished && _match.lastResult != null;

  @override
  bool get isHumanDiscardTurn =>
      _mirror.phase == GamePhase.awaitingDiscard &&
      _mirror.current == 0 &&
      humanClaimOpportunity == null;

  @override
  bool get canHumanTsumo =>
      isHumanDiscardTurn &&
      isWinningHand(human.hand, meldCount: human.meldCount);

  @override
  Player get human => _mirror.players[0];

  @override
  List<Tile> get humanWaits {
    final idle = 13 - 3 * human.meldCount;
    if (human.hand.length != idle) return const [];
    return waitingTiles(human.hand, meldCount: human.meldCount);
  }

  /// 완성/뺏어오기 기회: 호스트가 내 응답을 기다린다고 알려온 경우,
  /// 선택지는 내 손패 + 버려진 패로 (호스트와 같은 함수로) 재계산한다.
  @override
  ClaimOpportunity? get humanClaimOpportunity {
    if (!_claimAwaitMe || _sentClaimResponse) return null;
    final discarded = _mirror.lastDiscard;
    if (discarded == null) return null;
    final canWin =
        isWinningHand([...human.hand, discarded], meldCount: human.meldCount);
    final options = claimableSets(human.hand, discarded);
    if (!canWin && options.isEmpty) return null;
    return ClaimOpportunity(0, canWin: canWin, options: options);
  }

  @override
  void humanDiscard(Tile tile) {
    if (!isHumanDiscardTurn) return;
    _send(discardMessage(tile)); // 반영과 효과음은 호스트 echo로
  }

  @override
  void humanTsumo() {
    if (!canHumanTsumo) return;
    _send(tsumoMessage());
  }

  @override
  void humanRespondClaim({bool win = false, ClaimOption? option}) {
    if (humanClaimOpportunity == null) return;
    _sentClaimResponse = true;
    if (win) {
      _send(ronMessage());
    } else if (option != null) {
      _send(claimMessage(option));
    } else {
      _send(passMessage());
    }
    _notify();
  }

  /// 판 진행은 호스트 전용 — 클라이언트에서는 무시.
  @override
  void nextRound() {}

  @override
  void newMatch() {}

  @override
  void dispose() {
    _disposed = true;
    _socket?.destroy();
    super.dispose();
  }
}
