import 'package:flutter_test/flutter_test.dart';
import 'package:mahjong_joy/models/tile.dart';
import 'package:mahjong_joy/sound/sound_service.dart';
import 'package:mahjong_joy/ui/game_controller.dart';

Tile m(int r) => Tile(Suit.man, r);
Tile p(int r) => Tile(Suit.pin, r);
Tile s(int r) => Tile(Suit.sou, r);
Tile h(int r) => Tile(Suit.honor, r);

/// 조건이 될 때까지 실제 시간으로 대기.
Future<void> waitFor(bool Function() condition,
    {Duration timeout = const Duration(seconds: 5), String reason = ''}) async {
  final deadline = DateTime.now().add(timeout);
  while (!condition()) {
    if (DateTime.now().isAfter(deadline)) {
      fail('시간 초과: $reason');
    }
    await Future<void>.delayed(const Duration(milliseconds: 2));
  }
}

/// 좌석1(discarder)이 m(7)을 버리고 좌석0(사람)과 좌석2(AI)가 각각
/// 트리플·스트레이트로 뺏어올 수 있는 상황을 만든다. 둘 다 완성은
/// 불가능하도록(필러가 서로 조합되지 않게) 구성해 순수 "뺏어오기 경쟁"만
/// 검증한다.
void _setupClaimRace(GameController gc) {
  final game = gc.game;
  for (final pl in game.players) {
    pl.hand.clear();
    pl.melds.clear();
  }
  const filler = [
    Tile(Suit.honor, 1), Tile(Suit.honor, 2), Tile(Suit.honor, 3),
    Tile(Suit.honor, 4), Tile(Suit.honor, 5), Tile(Suit.honor, 6),
    Tile(Suit.honor, 7), Tile(Suit.sou, 2), Tile(Suit.sou, 4),
    Tile(Suit.sou, 6), Tile(Suit.sou, 8),
  ];
  game.players[1].hand.add(m(7)); // 버릴 패
  game.players[0].hand.addAll([m(7), m(7), ...filler]); // 사람: 트리플
  game.players[2].hand.addAll([m(8), m(9), ...filler]); // AI: 스트레이트
  game.current = 1;
  game.discard(m(7));
  gc.debugPoke();
}

void main() {
  setUpAll(() => SoundService.instance.enabled.value = false);

  test('사람이 AI의 최소 고민 시간(500ms)보다 먼저 응답하면 사람이 가져간다', () async {
    final gc = GameController(seed: 1, aiThinkMin: 500, aiThinkRangeMs: 12500);
    addTearDown(gc.dispose);
    _setupClaimRace(gc);

    await waitFor(() => gc.humanClaimOpportunity != null,
        reason: '사람에게 기회가 열려야 함');
    expect(gc.claimWaitingSeats, contains(2), reason: 'AI(2)가 고민 중이어야 함');

    // AI의 최소 지연(500ms)보다 훨씬 짧게 기다린 뒤 사람이 응답한다 —
    // AI가 그 전에 응답할 수 없으므로 사람이 반드시 먼저다.
    await Future<void>.delayed(const Duration(milliseconds: 50));
    final option = gc.humanClaimOpportunity!.options
        .firstWhere((o) => o.meld.tiles.contains(m(7)) && o.meld.tiles.length == 3);
    gc.humanRespondClaim(option: option);

    await waitFor(() => gc.human.melds.isNotEmpty,
        reason: '사람의 뺏어오기가 즉시 반영돼야 함');
    expect(gc.human.melds.single.tiles, containsAll([m(7), m(7), m(7)]));
    // AI 쪽 고민은 더 이상 의미 없으므로 취소되어 있어야 한다.
    expect(gc.claimWaitingSeats, isEmpty);
  });

  test('사람이 응답하지 않으면 AI의 고민 시간이 끝난 뒤 AI가 가져간다', () async {
    // 범위를 짧게 줘서 테스트가 오래 걸리지 않게 한다.
    final gc = GameController(seed: 1, aiThinkMin: 30, aiThinkRangeMs: 20);
    addTearDown(gc.dispose);
    _setupClaimRace(gc);

    await waitFor(() => gc.humanClaimOpportunity != null,
        reason: '사람에게 기회가 열려야 함');

    // 사람은 응답하지 않고 방치 — AI의 최대 고민 시간(50ms)이 지나면
    // AI가 대신 가져가야 한다.
    await waitFor(() => gc.game.players[2].melds.isNotEmpty,
        timeout: const Duration(seconds: 2),
        reason: 'AI가 시간 내에 뺏어와야 함');
    expect(gc.game.players[2].melds.single.tiles,
        containsAll([m(7), m(8), m(9)]));
    // 사람 쪽 기회는 라운드가 끝나며 함께 정리된다.
    expect(gc.humanClaimOpportunity, isNull);
  });

  test('완성 가능한 좌석이 아직 응답하지 않으면, 이미 도착한 뺏어오기는 확정되지 않는다',
      () async {
    final gc = GameController(seed: 1, aiThinkMin: 200, aiThinkRangeMs: 100);
    addTearDown(gc.dispose);

    final game = gc.game;
    for (final pl in game.players) {
      pl.hand.clear();
      pl.melds.clear();
    }
    // 좌석1이 5m을 버린다: 좌석0(사람)은 4-5-6으로 즉시 완성 가능,
    // 좌석2(AI)는 5m 트리플로 뺏어오기만 가능.
    game.players[1].hand.add(m(5));
    game.players[0].hand.addAll([
      m(1), m(2), m(3), m(7), m(7), m(7), p(2), p(2), p(2), s(9), s(9),
      m(4), m(6), // 5m을 받으면 4-5-6 완성
    ]);
    game.players[2].hand.addAll([
      m(5), m(5), m(9), m(9), p(8), p(8), p(7), s(3), s(3), s(2), s(1),
      h(1), h(2),
    ]);
    game.current = 1;
    game.discard(m(5));
    gc.debugPoke();

    await waitFor(() => gc.humanClaimOpportunity?.canWin == true,
        reason: '사람이 완성 가능해야 함');

    // AI(뺏어오기 전용)의 응답이 먼저 도착해도, 사람(완성 가능)이 아직
    // 응답하지 않았다면 확정되면 안 된다 — 완성이 뺏어오기보다 항상
    // 우선하므로.
    await waitFor(() => gc.claimWaitingSeats.isEmpty,
        timeout: const Duration(seconds: 1),
        reason: 'AI가 먼저 응답을 마쳐야 함(사람만 남음)');
    expect(gc.isFinished, isFalse, reason: '사람이 아직 답하지 않았으니 라운드가 끝나면 안 됨');
    expect(game.players[2].melds, isEmpty, reason: 'AI의 뺏어오기가 확정되면 안 됨');

    // 이제 사람이 완성(론)을 선언하면, 이미 도착해 있던 AI의 뺏어오기
    // 응답을 제치고 완성이 확정돼야 한다.
    gc.humanRespondClaim(win: true);

    await waitFor(() => gc.isFinished, reason: '완성으로 판이 끝나야 함');
    expect(gc.game.winner, 0);
    expect(game.players[2].melds, isEmpty,
        reason: '완성이 우선했으므로 AI의 뺏어오기는 무산돼야 함');
  });
}
