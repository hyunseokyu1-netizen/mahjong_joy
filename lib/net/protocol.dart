import 'dart:convert';
import 'dart:io';

import '../logic/claim.dart';
import '../logic/game.dart';
import '../logic/match_state.dart';
import '../logic/score.dart';
import '../models/tile.dart';

/// LAN 대전 프로토콜.
///
/// - 전송: TCP 위에 개행(\n)으로 구분한 JSON 한 줄 = 메시지 한 개.
/// - 호스트가 유일한 심판: 게임 엔진은 호스트에서만 돌고, 클라이언트는
///   행동(action)만 보내고 자기 시점의 상태(view)를 받아 그린다.
/// - 좌석 회전: 각 클라이언트에게는 자기가 항상 좌석 0이 되도록 회전한
///   상태를 보낸다. 기존 UI(내가 아래 = 좌석 0)가 그대로 동작한다.
/// - 다른 사람의 손패는 장수만 보낸다 (내용은 호스트만 안다).

/// 방 찾기 UDP 포트와 핸드셰이크 문자열.
const int discoveryPort = 47777;
const String discoveryPing = 'MJJOY?';
const String discoveryReplyPrefix = 'MJJOY!';

/// 버리기 차례 제한시간. 호스트가 강제하는 값이자, 클라이언트가
/// 카운트다운 UI에 쓰는 값 — 프로토콜에 값이 실려오지 않으므로
/// 양쪽이 이 상수를 공유해 맞춘다.
const Duration turnTimeLimit = Duration(seconds: 15);

List<int> tileKeys(List<Tile> tiles) => [for (final t in tiles) t.key];

List<Tile> tilesFromKeys(List<dynamic> keys) =>
    [for (final k in keys) Tile.fromKey(k as int)];

Map<String, dynamic> meldToJson(Meld m) =>
    {'t': m.type.name, 'k': tileKeys(m.tiles)};

Meld meldFromJson(Map<String, dynamic> m) =>
    Meld(MeldType.values.byName(m['t'] as String), tilesFromKeys(m['k'] as List));

/// 소켓 바이트 스트림 → JSON 메시지 스트림.
Stream<Map<String, dynamic>> jsonMessages(Stream<List<int>> source) => source
    .cast<List<int>>()
    .transform(utf8.decoder)
    .transform(const LineSplitter())
    .where((line) => line.trim().isNotEmpty)
    .map((line) => jsonDecode(line) as Map<String, dynamic>);

/// 메시지 한 줄 전송. 소켓이 닫혔으면 조용히 무시한다.
void sendJson(Socket socket, Map<String, dynamic> message) {
  try {
    socket.write('${jsonEncode(message)}\n');
  } catch (_) {}
}

// ---- 클라이언트 → 호스트 ----

Map<String, dynamic> joinMessage(String name) =>
    {'type': 'join', 'name': name};

Map<String, dynamic> discardMessage(Tile tile) =>
    {'type': 'discard', 'k': tile.key};

Map<String, dynamic> tsumoMessage() => {'type': 'tsumo'};

Map<String, dynamic> ronMessage() => {'type': 'ron'};

Map<String, dynamic> claimMessage(ClaimOption option) =>
    {'type': 'claim', 'meld': meldToJson(option.meld)};

Map<String, dynamic> passMessage() => {'type': 'pass'};

// ---- 호스트 → 클라이언트 ----

Map<String, dynamic> lobbyMessage(List<String?> names) =>
    {'type': 'lobby', 'names': names};

/// 방 전체 알림: 참가자 퇴장('left')/복귀('rejoined')/뺏어오기('claimed').
/// [seat]는 'claimed' 전용이며, 받는 클라이언트 시점으로 이미 회전된 값이다.
Map<String, dynamic> eventMessage(String kind, String name, {int? seat}) =>
    {'type': 'event', 'kind': kind, 'name': name, 'seat': ?seat};

Map<String, dynamic> fullMessage() => {'type': 'full'};

/// [forSeat] 시점(자기 = 0으로 회전)의 게임 상태 스냅샷.
///
/// [claimAwait]: 호스트가 아직 완성/뺏어오기 응답을 기다리는 좌석들.
Map<String, dynamic> buildView({
  required Game game,
  required MatchState match,
  required List<String?> names,
  required int forSeat,
  required Set<int> claimAwait,
  required bool simpleMode,
}) {
  final n = game.players.length;
  int rot(int seat) => (seat - forSeat + n) % n;

  final players = <Map<String, dynamic>>[];
  final viewNames = <String?>[];
  for (var pos = 0; pos < n; pos++) {
    final actual = (pos + forSeat) % n;
    final p = game.players[actual];
    players.add({
      'n': p.hand.length,
      'melds': [for (final m in p.melds) meldToJson(m)],
      'discards': tileKeys(p.discards),
    });
    viewNames.add(names[actual]);
  }

  final result = match.lastResult;
  final finished = game.phase == GamePhase.finished;

  return {
    'type': 'view',
    'phase': game.phase.name,
    'current': rot(game.current),
    'wall': game.wallCount,
    'players': players,
    'names': viewNames,
    // 참가자 자신의 실제(회전 전) 좌석 번호. AI/빈 좌석 이름은 각자
    // 로컬 언어로 채우는데, 그 기준을 "화면에 보이는 위치"가 아니라
    // 이 실제 좌석 번호로 잡아야 같은 AI가 참가자마다 다른 이름으로
    // 보이지 않는다 (자세한 이유는 game_screen.dart의 _nameOf 참고).
    'mySeat': forSeat,
    'myHand': tileKeys(game.players[forSeat].hand),
    'drawn': game.current == forSeat ? game.drawnTile?.key : null,
    'lastDiscard': game.lastDiscard?.key,
    'lastDiscarder':
        game.lastDiscarder == null ? null : rot(game.lastDiscarder!),
    'claimAwait': [for (final s in claimAwait) rot(s)],
    'simple': simpleMode,
    'match': {
      'scores': [for (var p = 0; p < n; p++) match.scores[(p + forSeat) % n]],
      'wins': [for (var p = 0; p < n; p++) match.winCounts[(p + forSeat) % n]],
      'played': match.roundsPlayed,
    },
    'winner': game.winner == null ? null : rot(game.winner!),
    'winningHand':
        game.winningHand == null ? null : tileKeys(game.winningHand!),
    'result': !finished || result == null
        ? null
        : {
            'winner': result.winner == null ? null : rot(result.winner!),
            'winType': result.winType?.name,
            'loser': result.loser == null ? null : rot(result.loser!),
            'value': result.value,
            'deltas': [
              for (var p = 0; p < n; p++) result.deltas[(p + forSeat) % n]
            ],
            'lines': result.score == null
                ? null
                : [
                    for (final l in result.score!.lines)
                      {'b': l.bonus.name, 'c': l.count, 'p': l.plus, 'x': l.times}
                  ],
          },
  };
}

/// 수신한 view를 클라이언트의 미러 [game]/[match]에 반영한다.
/// 반환: 완성/뺏어오기 응답을 아직 기다리는 좌석들 (회전됨, 0 = 나).
List<int> applyView(Map<String, dynamic> v, Game game, MatchState match) {
  game.phase = GamePhase.values.byName(v['phase'] as String);
  game.current = v['current'] as int;
  game.syncMirrorWall(v['wall'] as int);

  final players = v['players'] as List;
  final myHand = tilesFromKeys(v['myHand'] as List);
  for (var i = 0; i < game.players.length; i++) {
    final p = game.players[i];
    final data = players[i] as Map<String, dynamic>;
    p.melds
      ..clear()
      ..addAll([
        for (final m in data['melds'] as List)
          meldFromJson((m as Map).cast<String, dynamic>())
      ]);
    p.discards
      ..clear()
      ..addAll(tilesFromKeys(data['discards'] as List));
    p.hand.clear();
    if (i == 0) {
      p.hand.addAll(myHand);
    } else {
      // 남의 손패는 장수만 안다. 내용은 그리지 않으므로 자리 채움용.
      p.hand.addAll(List.filled(data['n'] as int, const Tile(Suit.man, 1)));
    }
  }

  game.drawnTile =
      v['drawn'] == null ? null : Tile.fromKey(v['drawn'] as int);
  game.lastDiscard =
      v['lastDiscard'] == null ? null : Tile.fromKey(v['lastDiscard'] as int);
  game.lastDiscarder = v['lastDiscarder'] as int?;
  game.winner = v['winner'] as int?;
  game.winningHand = v['winningHand'] == null
      ? null
      : tilesFromKeys(v['winningHand'] as List);

  final m = v['match'] as Map<String, dynamic>;
  match.scores.setAll(0, (m['scores'] as List).cast<int>());
  match.winCounts.setAll(0, (m['wins'] as List).cast<int>());
  match.roundsPlayed = m['played'] as int;

  final r = v['result'] as Map<String, dynamic>?;
  if (r != null) {
    final lines = r['lines'] as List?;
    game.winType =
        r['winType'] == null ? null : WinType.values.byName(r['winType']);
    game.ronLoser = r['loser'] as int?;
    match.lastResult = RoundResult(
      winner: r['winner'] as int?,
      winType: game.winType,
      loser: r['loser'] as int?,
      value: r['value'] as int,
      deltas: (r['deltas'] as List).cast<int>(),
      score: lines == null
          ? null
          : ScoreResult([
              for (final l in lines.cast<Map>())
                l['p'] != null
                    ? ScoreLine.plus(ScoreBonus.values.byName(l['b']),
                        l['p'] as int, count: l['c'] as int)
                    : ScoreLine.times(ScoreBonus.values.byName(l['b']),
                        l['x'] as int, count: l['c'] as int)
            ]),
    );
  }

  return (v['claimAwait'] as List).cast<int>();
}
