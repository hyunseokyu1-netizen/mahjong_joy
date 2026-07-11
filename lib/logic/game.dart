import 'dart:math';

import '../models/tile.dart';
import 'claim.dart';
import 'deck.dart';
import 'win_checker.dart';

/// 승리 방식: 스스로 뽑아 완성(츠모) vs 남이 버린 패로 완성(론).
enum WinType { tsumo, ron }

enum GamePhase {
  /// 현재 플레이어가 버릴 패를 고르는 중 (드로우/뺏어오기 직후).
  awaitingDiscard,

  /// 방금 버려진 패에 대해 다른 플레이어들의 완성/뺏어오기 응답 대기.
  awaitingClaims,

  /// 승리 또는 유국으로 종료.
  finished,
}

class Player {
  final int seat;

  /// 비공개 손패 (항상 정렬 유지). 대기 중 크기 = 13 - 3 × melds.length.
  final List<Tile> hand = [];

  /// 뺏어오기로 공개한 몸통.
  final List<Meld> melds = [];

  /// 이 플레이어가 버린 패 (뺏긴 패는 제거됨).
  final List<Tile> discards = [];

  Player(this.seat);

  int get meldCount => melds.length;
}

/// 다른 플레이어의 버림패에 대한 응답 기회.
class ClaimOpportunity {
  final int seat;

  /// 이 패로 즉시 완성(론) 가능한지.
  final bool canWin;

  /// 뺏어와서 만들 수 있는 몸통 목록.
  final List<ClaimOption> options;

  ClaimOpportunity(this.seat, {required this.canWin, required this.options});
}

/// 심플 마작 게임 엔진 (순수 로직, UI 독립).
///
/// 흐름: 드로우 → [awaitingDiscard] → 버리기 → [awaitingClaims]
///       → (완성/뺏어오기/패스) → 다음 드로우 …
/// 덱 소진 시 유국. 규칙 검증은 엔진이, 의사결정 순서(우선순위)는
/// 컨트롤러가 [claimOpportunities]를 보고 결정한다.
/// 우선순위 규칙: 완성 > 뺏어오기, 동순위면 버린 사람 기준 턴 순서가 빠른 쪽.
class Game {
  final List<Player> players;
  final List<Tile> _wall;

  int current;
  GamePhase phase;

  /// 방금 드로우한 패 (awaitingDiscard이고 드로우 직후일 때만).
  Tile? drawnTile;

  Tile? lastDiscard;
  int? lastDiscarder;

  /// 승자 좌석. null이면서 finished면 유국.
  int? winner;

  /// 승자의 완성 손패 (공개 몸통 제외).
  List<Tile>? winningHand;

  /// 승리 방식. 승자가 없으면 null.
  WinType? winType;

  /// 론 승리일 때 그 패를 버린 사람 (점수 전액 지불자).
  int? ronLoser;

  List<ClaimOpportunity> _claimOpportunities = const [];

  Game.start({Random? random, int playerCount = 4})
      : players = List.generate(playerCount, Player.new),
        _wall = [],
        current = 0,
        phase = GamePhase.awaitingDiscard {
    final result = deal(random: random, playerCount: playerCount);
    for (var i = 0; i < playerCount; i++) {
      players[i].hand.addAll(result.hands[i]);
    }
    _wall.addAll(result.wall);
    _draw();
  }

  /// LAN 대전 클라이언트가 호스트 상태를 그대로 비추기 위한 빈 껍데기.
  /// 딜 없이 시작하며, 내용은 전적으로 수신한 view로 채워진다.
  /// 이 게임에는 규칙 메서드(discard 등)를 호출하지 말 것.
  Game.mirror({int playerCount = 4})
      : players = List.generate(playerCount, Player.new),
        _wall = [],
        current = 0,
        phase = GamePhase.awaitingDiscard;

  /// 미러 전용: 남은 패 수 표시를 맞춘다 (벽 내용은 사용하지 않는다).
  void syncMirrorWall(int count) {
    _wall
      ..clear()
      ..addAll(List.filled(count, const Tile(Suit.man, 1)));
  }

  int get wallCount => _wall.length;

  bool get isExhaustedDraw => phase == GamePhase.finished && winner == null;

  List<ClaimOpportunity> get claimOpportunities => _claimOpportunities;

  /// 현재 플레이어(드로우 직후)가 츠모 완성 가능한지.
  bool canDeclareTsumo() =>
      phase == GamePhase.awaitingDiscard &&
      isWinningHand(players[current].hand,
          meldCount: players[current].meldCount);

  void declareTsumo() {
    _require(canDeclareTsumo(), '츠모 불가 상태');
    winType = WinType.tsumo;
    _finishWithWinner(current, List.of(players[current].hand));
  }

  /// [seat]가 방금 버려진 패로 완성(론) 선언.
  void declareRon(int seat) {
    _require(phase == GamePhase.awaitingClaims, '클레임 대기 상태가 아님');
    final opp = _opportunityOf(seat);
    _require(opp != null && opp.canWin, '완성 조건 미충족');
    final p = players[seat];
    winType = WinType.ron;
    ronLoser = lastDiscarder;
    _finishWithWinner(seat, [...p.hand, lastDiscard!]..sort());
  }

  /// 현재 플레이어가 [tile]을 버린다.
  void discard(Tile tile) {
    _require(phase == GamePhase.awaitingDiscard, '버리기 단계가 아님');
    final p = players[current];
    final removed = p.hand.remove(tile);
    _require(removed, '손에 없는 패: $tile');
    p.discards.add(tile);
    lastDiscard = tile;
    lastDiscarder = current;
    drawnTile = null;

    _claimOpportunities = _computeClaimOpportunities(tile);
    if (_claimOpportunities.isEmpty) {
      _advanceTurn();
    } else {
      phase = GamePhase.awaitingClaims;
    }
  }

  /// [seat]가 버려진 패를 뺏어와 몸통을 공개한다. 이후 그 플레이어가 버릴 차례.
  void applyClaim(int seat, ClaimOption option) {
    _require(phase == GamePhase.awaitingClaims, '클레임 대기 상태가 아님');
    final opp = _opportunityOf(seat);
    _require(opp != null && opp.options.contains(option), '유효하지 않은 뺏어오기');

    final p = players[seat];
    for (final t in option.tilesFromHand) {
      _require(p.hand.remove(t), '손에 없는 패: $t');
    }
    p.melds.add(option.meld);
    players[lastDiscarder!].discards.removeLast();

    lastDiscard = null;
    _claimOpportunities = const [];
    current = seat;
    phase = GamePhase.awaitingDiscard;
  }

  /// 아무도 완성/뺏어오기를 하지 않음 → 다음 플레이어 드로우.
  void passClaims() {
    _require(phase == GamePhase.awaitingClaims, '클레임 대기 상태가 아님');
    _claimOpportunities = const [];
    _advanceTurn();
  }

  // ---- 내부 구현 ----

  void _advanceTurn() {
    if (_wall.isEmpty) {
      phase = GamePhase.finished; // 유국
      return;
    }
    current = (lastDiscarder! + 1) % players.length;
    phase = GamePhase.awaitingDiscard;
    _draw();
  }

  void _draw() {
    final tile = _wall.removeAt(0);
    drawnTile = tile;
    final hand = players[current].hand;
    hand.add(tile);
    hand.sort();
  }

  List<ClaimOpportunity> _computeClaimOpportunities(Tile discarded) {
    final result = <ClaimOpportunity>[];
    // 버린 사람 다음 좌석부터 턴 순서대로 (우선순위 판단 편의를 위해)
    for (var i = 1; i < players.length; i++) {
      final seat = (lastDiscarder! + i) % players.length;
      final p = players[seat];
      final canWin =
          isWinningHand([...p.hand, discarded], meldCount: p.meldCount);
      final options = claimableSets(p.hand, discarded);
      if (canWin || options.isNotEmpty) {
        result.add(ClaimOpportunity(seat, canWin: canWin, options: options));
      }
    }
    return result;
  }

  ClaimOpportunity? _opportunityOf(int seat) {
    for (final o in _claimOpportunities) {
      if (o.seat == seat) return o;
    }
    return null;
  }

  void _finishWithWinner(int seat, List<Tile> hand) {
    winner = seat;
    winningHand = hand;
    _claimOpportunities = const [];
    phase = GamePhase.finished;
  }

  void _require(bool condition, String message) {
    if (!condition) throw StateError(message);
  }
}
