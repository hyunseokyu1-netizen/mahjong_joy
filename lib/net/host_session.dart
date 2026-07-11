import 'dart:async';
import 'dart:convert';
import 'dart:io';

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
    this.claimDelay = const Duration(milliseconds: 350),
    this.claimTimeout = const Duration(seconds: 15),
  }) {
    names[0] = hostName;
  }

  final String hostName;
  final bool simpleModeOn;
  final Duration aiDelay;
  final Duration claimDelay;

  /// 완성/뺏어오기 응답 제한시간. 지나면 전원 자동 패스 처리해
  /// 한 사람 때문에 게임이 멈추지 않게 한다.
  final Duration claimTimeout;

  final SimpleAi _ai = SimpleAi();

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

  int _generation = 0;
  bool _driving = false;
  bool _disposed = false;
  bool _resultApplied = false;
  int? _drawSoundWall;

  int? get port => _server?.port;

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
    game.discard(tile);
    SoundService.instance.tap();
    _notifyBroadcast();
    _drive();
  }

  @override
  void humanTsumo() {
    if (!canHumanTsumo) return;
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

  void _setupClaims() {
    _responses = {};
    _awaiting.clear();
    for (final opp in game.claimOpportunities) {
      if (_isAiSeat(opp.seat)) {
        _responses![opp.seat] = _aiClaimResponseFor(opp);
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

  /// 제한시간 초과: 아직 응답하지 않은 전원을 패스 처리.
  void _onClaimTimeout() {
    if (_disposed || _responses == null || _awaiting.isEmpty) return;
    humanClaimOpportunity = null;
    for (final seat in _awaiting.toList()) {
      _responses![seat] = const _ClaimResponse();
    }
    _awaiting.clear();
    _notifyBroadcast();
    _drive();
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
    _notifyBroadcast(); // claimAwait 목록 갱신
    _drive();
  }

  /// 우선순위(완성 > 뺏어오기, 동순위는 턴 순서)대로 응답을 처리한다.
  void _resolveClaims() {
    _claimTimer?.cancel();
    final responses = _responses ?? const <int, _ClaimResponse>{};
    _responses = null;
    _awaiting.clear();
    humanClaimOpportunity = null;

    for (final opp in game.claimOpportunities) {
      final r = responses[opp.seat];
      if (r != null && r.win && opp.canWin) {
        game.declareRon(opp.seat);
        return;
      }
    }
    for (final opp in game.claimOpportunities) {
      final meld = responses[opp.seat]?.meld;
      if (meld == null) continue;
      for (final option in opp.options) {
        if (option.meld == meld) {
          game.applyClaim(opp.seat, option);
          SoundService.instance.claim();
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
            game.discard(Tile.fromKey(msg['k'] as int));
            SoundService.instance.tap();
            _notifyBroadcast();
            _drive();
          }
        case 'tsumo':
          if (game.phase == GamePhase.awaitingDiscard &&
              game.current == seat &&
              game.canDeclareTsumo()) {
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
    for (final c in _clients.values) {
      c.socket.destroy();
    }
    _clients.clear();
    _server?.close();
    _udp?.close();
    super.dispose();
  }
}
