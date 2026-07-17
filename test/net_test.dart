import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:mahjong_joy/logic/game.dart';
import 'package:mahjong_joy/logic/match_state.dart';
import 'package:mahjong_joy/net/client_session.dart';
import 'package:mahjong_joy/net/host_session.dart';
import 'package:mahjong_joy/models/tile.dart';
import 'package:mahjong_joy/net/protocol.dart';
import 'package:mahjong_joy/sound/sound_service.dart';
import 'package:mahjong_joy/ui/table_controller.dart';

/// 조건이 될 때까지 실제 시간으로 대기 (루프백 소켓 테스트용).
Future<void> waitFor(bool Function() condition,
    {Duration timeout = const Duration(seconds: 10),
    String reason = ''}) async {
  final deadline = DateTime.now().add(timeout);
  while (!condition()) {
    if (DateTime.now().isAfter(deadline)) {
      fail('시간 초과: $reason');
    }
    await Future<void>.delayed(const Duration(milliseconds: 5));
  }
}

void main() {
  setUpAll(() => SoundService.instance.enabled.value = false);

  test('view 직렬화: 회전된 스냅샷을 미러에 반영하면 상태가 일치한다', () {
    final game = Game.start();
    final match = MatchState();
    final view = buildView(
      game: game,
      match: match,
      names: ['호스트', '친구', null, null],
      forSeat: 1,
      claimAwait: {1, 2},
      simpleMode: false,
    );

    final mirror = Game.mirror();
    final mirrorMatch = MatchState();
    final claimAwait = applyView(view, mirror, mirrorMatch);

    // 좌석 {1, 2}는 좌석 1 기준 회전 후 {0, 1}
    expect(claimAwait, containsAll([0, 1]));
    // 실제 좌석 번호가 그대로 전달돼야, AI 이름을 회전 위치가 아니라
    // 실제 좌석 기준으로 골라 참가자마다 다르게 보이지 않는다.
    expect(view['mySeat'], 1);
    expect(mirror.wallCount, game.wallCount);
    // 내 손패(좌석 1)는 그대로, 좌석 회전 확인
    expect(mirror.players[0].hand, game.players[1].hand);
    // 남의 손패는 장수만
    expect(mirror.players[1].hand.length, game.players[2].hand.length);
    expect(mirror.current, (game.current - 1 + 4) % 4);
    expect(mirrorMatch.scores[0], match.scores[1]);
  });

  test('LAN 대전: 호스트 1 + 클라이언트 2 + AI 1이 8판 대국을 완주한다', () async {
    final host = NetHostController(
      hostName: '방장',
      aiDelay: Duration.zero,
      claimDelay: Duration.zero,
      aiClaimThinkMax: Duration.zero,
    );
    await host.open(advertise: false);
    addTearDown(host.dispose);

    final clients = <NetClientController>[];
    for (var i = 0; i < 2; i++) {
      final client = NetClientController();
      addTearDown(client.dispose);
      clients.add(client);
      await client.connect(InternetAddress.loopbackIPv4, host.port!,
          name: '친구$i');
    }
    await waitFor(() => host.humanCount == 3, reason: '참가자 접속');
    expect(host.names.where((n) => n != null).length, 3);

    host.startGame();
    await waitFor(
        () => clients.every((c) => c.status == NetClientStatus.playing),
        reason: '게임 시작 view 수신');

    // 전원 단순 전략으로 8판 완주: 츠모/론 가능하면 완성, 아니면
    // 첫 패 버리기, 뺏어오기 기회는 완성일 때만 응답.
    var safety = 0;
    while (!host.match.isMatchOver) {
      expect(++safety, lessThan(200000), reason: '대국이 끝나지 않음');

      if (host.isFinished) {
        if (!host.match.isMatchOver) host.nextRound();
      } else {
        if (host.humanClaimOpportunity != null) {
          host.humanRespondClaim(win: host.humanClaimOpportunity!.canWin);
        } else if (host.canHumanTsumo) {
          host.humanTsumo();
        } else if (host.isHumanDiscardTurn) {
          host.humanDiscard(host.human.hand.first);
        }
        for (final c in clients) {
          final claim = c.humanClaimOpportunity;
          if (claim != null) {
            c.humanRespondClaim(win: claim.canWin);
          } else if (c.canHumanTsumo) {
            c.humanTsumo();
          } else if (c.isHumanDiscardTurn) {
            c.humanDiscard(c.human.hand.first);
          }
        }
      }
      await Future<void>.delayed(const Duration(milliseconds: 2));
    }

    // 클라이언트 미러가 호스트와 일치하는지 (회전 고려).
    await waitFor(() => clients.every((c) => c.isFinished),
        reason: '클라이언트 종료 상태 동기화');
    for (var i = 0; i < clients.length; i++) {
      final c = clients[i];
      final seat = host.names.indexOf('친구$i');
      expect(seat, greaterThan(0));
      expect(c.game.wallCount, host.game.wallCount, reason: '벽 동기화');
      expect(c.match.roundsPlayed, host.match.roundsPlayed);
      for (var pos = 0; pos < 4; pos++) {
        final actual = (pos + seat) % 4;
        expect(c.match.scores[pos], host.match.scores[actual],
            reason: '점수 회전 동기화 (client=$i pos=$pos)');
        expect(c.match.winCounts[pos], host.match.winCounts[actual]);
        expect(c.game.players[pos].discards,
            host.game.players[actual].discards,
            reason: '버림패 동기화');
      }
      // 내 손패는 실제 내용까지 일치
      expect(c.human.hand, host.game.players[seat].hand);
    }

    // 전체 점수 보존
    expect(host.match.scores.reduce((a, b) => a + b),
        MatchState.startingPoints * 4);
  });

  test('클라이언트가 끊기면 AI가 이어받아 판이 계속된다', () async {
    final host = NetHostController(
      hostName: '방장',
      aiDelay: Duration.zero,
      claimDelay: Duration.zero,
      aiClaimThinkMax: Duration.zero,
    );
    await host.open(advertise: false);
    addTearDown(host.dispose);

    final client = NetClientController();
    await client.connect(InternetAddress.loopbackIPv4, host.port!,
        name: '친구');
    await waitFor(() => host.humanCount == 2, reason: '참가자 접속');

    host.startGame();
    await waitFor(() => client.status == NetClientStatus.playing,
        reason: '게임 시작');

    client.dispose(); // 게임 도중 이탈
    await waitFor(() => host.humanCount == 1, reason: '이탈 감지');
    // 방 전체 알림: 나갔습니다
    expect(host.notice.value?.kind, TableNoticeKind.left);
    expect(host.notice.value?.name, '친구');

    // 남은 진행은 호스트 + AI 3으로 계속되어 판이 끝까지 간다.
    var safety = 0;
    while (!host.isFinished) {
      expect(++safety, lessThan(100000));
      if (host.humanClaimOpportunity != null) {
        host.humanRespondClaim(win: host.humanClaimOpportunity!.canWin);
      } else if (host.canHumanTsumo) {
        host.humanTsumo();
      } else if (host.isHumanDiscardTurn) {
        host.humanDiscard(host.human.hand.first);
      }
      await Future<void>.delayed(const Duration(milliseconds: 2));
    }
    expect(host.isFinished, isTrue);
  });

  test('순간 끊김: 클라이언트가 자동 재접속해 같은 자리로 복귀한다', () async {
    final host = NetHostController(
      hostName: '방장',
      aiDelay: const Duration(milliseconds: 50),
      claimDelay: Duration.zero,
      aiClaimThinkMax: Duration.zero,
    );
    await host.open(advertise: false);
    addTearDown(host.dispose);

    final client = NetClientController();
    addTearDown(client.dispose);
    await client.connect(InternetAddress.loopbackIPv4, host.port!,
        name: '친구');
    await waitFor(() => host.humanCount == 2, reason: '접속');
    final seat = host.names.indexOf('친구');

    host.startGame();
    await waitFor(() => client.status == NetClientStatus.playing,
        reason: '게임 시작');

    client.debugDropConnection(); // 순간 끊김
    await waitFor(() => client.status == NetClientStatus.reconnecting,
        reason: '재접속 상태 전환');
    expect(client.isReconnecting, isTrue);

    // 2초 후 자동 재접속 → 같은 좌석으로 복귀, view 수신 재개
    await waitFor(() => client.status == NetClientStatus.playing,
        timeout: const Duration(seconds: 15), reason: '재접속 완료');
    expect(host.names[seat], '친구');
    expect(host.humanCount, 2);
    expect(client.human.hand, host.game.players[seat].hand,
        reason: '복귀 후 손패 동기화');
    // 방 전체 알림: 돌아왔습니다
    expect(host.notice.value?.kind, TableNoticeKind.rejoined);
  });

  test('완성/뺏어오기 응답 제한시간: 무응답이면 자동 패스로 진행된다', () async {
    final host = NetHostController(
      hostName: '방장',
      aiDelay: Duration.zero,
      claimDelay: Duration.zero,
      claimTimeout: const Duration(milliseconds: 200),
      aiClaimThinkMax: Duration.zero,
    );
    await host.open(advertise: false);
    addTearDown(host.dispose);

    final client = NetClientController();
    addTearDown(client.dispose);
    await client.connect(InternetAddress.loopbackIPv4, host.port!,
        name: '느림보');
    await waitFor(() => host.humanCount == 2, reason: '접속');

    host.startGame();
    await waitFor(() => client.status == NetClientStatus.playing,
        reason: '게임 시작');

    // 클라이언트는 버리기 차례만 진행하고 뺏어오기/완성 응답은 절대
    // 하지 않는다. 기회가 와도 200ms 뒤 자동 패스되어 게임이 끝까지
    // 진행되어야 한다.
    var safety = 0;
    var clientSawClaim = false;
    while (!host.isFinished) {
      expect(++safety, lessThan(100000));
      if (host.humanClaimOpportunity != null) {
        host.humanRespondClaim();
      } else if (host.canHumanTsumo) {
        host.humanTsumo();
      } else if (host.isHumanDiscardTurn) {
        host.humanDiscard(host.human.hand.first);
      }
      if (client.humanClaimOpportunity != null) {
        clientSawClaim = true; // 응답하지 않고 방치
      } else if (client.isHumanDiscardTurn) {
        client.humanDiscard(client.human.hand.first);
      }
      await Future<void>.delayed(const Duration(milliseconds: 2));
    }
    expect(host.isFinished, isTrue);
    expect(clientSawClaim, isTrue, reason: '클라이언트에게 기회가 한 번은 와야 의미 있는 검증');
  });

  test('사람과 경쟁 중인 AI는 즉시 응답하지 않고 무작위로 "고민"한 뒤 반영된다',
      () async {
    final host = NetHostController(
      hostName: '방장',
      aiDelay: Duration.zero,
      claimDelay: Duration.zero,
      aiClaimThinkMax: const Duration(milliseconds: 800),
    );
    await host.open(advertise: false);
    addTearDown(host.dispose);

    final client = NetClientController();
    addTearDown(client.dispose);
    await client.connect(InternetAddress.loopbackIPv4, host.port!,
        name: '친구');
    await waitFor(() => host.humanCount == 2, reason: '접속');

    host.startGame();
    await waitFor(() => client.status == NetClientStatus.playing,
        reason: '게임 시작');

    // 좌석0(host)이 7m을 버린다. 먼저 접속한 클라이언트가 좌석1을
    // 차지하므로(m7 트리플 가능), 좌석2가 AI로 남아 8-9 스트레이트로
    // 뺏어올 수 있는 상황이 된다 — 사람(1)과 AI(2)가 같은 패를 동시에
    // 노리는 시나리오. 필러 타일은 서로 절대 조합되지 않는 낱장들로
    // 채워 우연히 완성(론) 손패가 되지 않게 한다.
    final game = host.game;
    for (final p in game.players) {
      p.hand.clear();
      p.melds.clear();
    }
    const filler = [
      Tile(Suit.honor, 1), Tile(Suit.honor, 2), Tile(Suit.honor, 3),
      Tile(Suit.honor, 4), Tile(Suit.honor, 5), Tile(Suit.honor, 6),
      Tile(Suit.honor, 7), Tile(Suit.sou, 2), Tile(Suit.sou, 4),
      Tile(Suit.sou, 6), Tile(Suit.sou, 8),
    ];
    game.players[0].hand.add(m(7));
    game.players[1].hand.addAll([m(7), m(7), ...filler]);
    game.players[2].hand.addAll([m(8), m(9), ...filler]);
    game.current = 0;
    game.discard(m(7));
    host.debugPoke();

    await waitFor(() => host.claimWaitingSeats.contains(2),
        reason: 'AI 좌석(2)이 즉시 응답하지 않고 "고민 중" 상태여야 함');

    // 클라이언트가 자기 몫의 기회(브로드캐스트로 수신)를 인지할 때까지
    // 기다린 뒤 곧바로 패스 — 그래도 AI가 아직 고민 중이면 라운드가
    // 끝나면 안 된다.
    await waitFor(() => client.humanClaimOpportunity != null,
        reason: '클라이언트가 자기 기회를 수신해야 함');
    client.humanRespondClaim();
    await Future<void>.delayed(const Duration(milliseconds: 100));
    expect(game.phase, GamePhase.awaitingClaims,
        reason: 'AI 고민 시간이 끝나기 전에는 라운드가 끝나면 안 됨');

    // 최대 고민 시간(800ms)이 지나면 AI 응답이 반영되어 라운드가 끝난다.
    await waitFor(() => host.claimWaitingSeats.isEmpty,
        timeout: const Duration(seconds: 2),
        reason: 'AI 고민이 끝나면 좌석이 대기 목록에서 빠져야 함');
    await waitFor(() => game.phase != GamePhase.awaitingClaims,
        timeout: const Duration(seconds: 2), reason: '라운드가 최종 확정돼야 함');
  });

  test('AI 좌석의 실제 좌석 번호는 회전과 무관하게 참가자마다 동일하다', () async {
    // 호스트 + 클라이언트 2명, 좌석3만 AI로 남긴다. 각자 화면에서는
    // 이 AI가 서로 다른 위치(회전 결과)에 보이지만, actualSeatOf로
    // 되돌린 "실제 좌석"은 누가 보든 3이어야 한다 — 이게 어긋나면
    // AI 이름이 참가자마다 다르게 보이는 버그로 이어진다.
    final host = NetHostController(hostName: '방장', aiDelay: Duration.zero);
    await host.open(advertise: false);
    addTearDown(host.dispose);

    final clients = <NetClientController>[];
    for (var i = 0; i < 2; i++) {
      final c = NetClientController();
      addTearDown(c.dispose);
      clients.add(c);
      await c.connect(InternetAddress.loopbackIPv4, host.port!, name: 'C$i');
    }
    await waitFor(() => host.humanCount == 3, reason: '2명 접속');

    host.startGame();
    await waitFor(
        () => clients.every((c) => c.status == NetClientStatus.playing),
        reason: '게임 시작');

    // 실제 좌석3이 AI(이름 미배정)임을 확인.
    expect(host.names[3], isNull);

    for (final c in clients) {
      // 이 클라이언트 화면에서 좌석3이 보이는 로컬 위치를 찾는다
      // (seatNames가 null인 자리 = AI).
      final localPos = c.seatNames!.indexWhere((n) => n == null);
      expect(localPos, isNonNegative, reason: 'AI 좌석이 화면에 있어야 함');
      // 로컬 위치가 서로 다를 수 있어도(회전 때문에), 실제 좌석으로
      // 되돌리면 항상 3이어야 한다 — 즉 이름 풀 인덱스가 참가자마다
      // 같아진다.
      expect(c.actualSeatOf(localPos), 3);
    }
  });

  test('방이 가득 차면 다섯 번째 참가자는 거절된다', () async {
    final host = NetHostController(hostName: '방장', aiDelay: Duration.zero);
    await host.open(advertise: false);
    addTearDown(host.dispose);

    final clients = <NetClientController>[];
    for (var i = 0; i < 3; i++) {
      final c = NetClientController();
      addTearDown(c.dispose);
      clients.add(c);
      await c.connect(InternetAddress.loopbackIPv4, host.port!, name: 'C$i');
    }
    await waitFor(() => host.humanCount == 4, reason: '3명 접속');

    final fifth = NetClientController();
    addTearDown(fifth.dispose);
    await fifth.connect(InternetAddress.loopbackIPv4, host.port!, name: 'C4');
    await waitFor(() => fifth.status == NetClientStatus.disconnected,
        reason: '거절 수신');
    expect(host.humanCount, 4);
  });

  test('여러 명이 동시에 응답 대상일 때: 완성 선언은 다른 사람 응답을 기다리지 않고 즉시 반영된다',
      () async {
    final host = NetHostController(
      hostName: '방장',
      aiDelay: Duration.zero,
      // 일부러 길게 잡아, 조기 확정이 이 딜레이를 기다리지 않는지 확인.
      claimDelay: const Duration(seconds: 5),
      claimTimeout: const Duration(seconds: 20),
      aiClaimThinkMax: Duration.zero,
    );
    await host.open(advertise: false);
    addTearDown(host.dispose);

    final winner = NetClientController(); // 좌석 1: 완성 가능
    final claimer = NetClientController(); // 좌석 2: 뺏어오기만 가능
    addTearDown(winner.dispose);
    addTearDown(claimer.dispose);
    await winner.connect(InternetAddress.loopbackIPv4, host.port!,
        name: '완성자');
    await waitFor(() => host.humanCount == 2, reason: '완성자 접속');
    await claimer.connect(InternetAddress.loopbackIPv4, host.port!,
        name: '뺏어오기');
    await waitFor(() => host.humanCount == 3, reason: '뺏어오기 접속');

    host.startGame();
    await waitFor(
        () =>
            winner.status == NetClientStatus.playing &&
            claimer.status == NetClientStatus.playing,
        reason: '게임 시작');

    // 좌석0이 5m을 버린 상황을 직접 구성한다: 좌석1은 그 패로 바로
    // 완성(론) 가능, 좌석2는 삼각(뺏어오기)만 가능. 좌석2가 canWin이
    // 아니므로, 좌석1이 완성을 선언하는 즉시 좌석2 응답과 무관하게
    // 확정되어야 한다 (완성은 뺏어오기보다 항상 우선하므로).
    // game.discard()를 실제로 호출해 claimOpportunities가 정상
    // 계산되게 한다 (내부 필드라 직접 대입할 수 없다).
    final game = host.game;
    for (final p in game.players) {
      p.hand.clear();
      p.melds.clear();
    }
    game.players[0].hand.add(m(5)); // 버릴 패
    game.players[1].hand.addAll([
      m(1), m(2), m(3), // 몸통
      m(7), m(7), m(7), // 몸통
      p(2), p(2), p(2), // 몸통
      s(9), s(9), // 머리
      m(4), m(6), // 5m을 받으면 4-5-6 완성
    ]);
    game.players[2].hand.addAll([
      m(5), m(5), // 5m 트리플 뺏어오기용
      m(9), m(9), p(8), p(8), p(7), s(3), s(3), s(2), s(1), h(1), h(2),
    ]);
    game.current = 0;
    game.discard(m(5));
    host.debugPoke();

    await waitFor(() => host.claimWaitingSeats.length == 2,
        reason: '두 좌석 모두 응답 대기 상태가 돼야 함(호스트 기준)');
    // 클라이언트들이 각자 브로드캐스트를 실제로 수신할 때까지 대기
    // (호스트 상태가 확정된 시점과 소켓 전달 시점은 다르다).
    await waitFor(() => claimer.humanClaimOpportunity != null,
        reason: '뺏어오기 좌석에 기회가 도착해야 함');
    await waitFor(() => winner.humanClaimOpportunity?.canWin == true,
        reason: '완성 좌석에 기회가 도착해야 함');

    // 뺏어오기 쪽(우선순위 낮음)이 아직 응답하지 않았는데도, 완성
    // 선언이 즉시(=claimDelay 5초를 기다리지 않고) 반영돼야 한다.
    final start = DateTime.now();
    winner.humanRespondClaim(win: true);
    await waitFor(() => host.game.winner == 1,
        timeout: const Duration(seconds: 2), reason: '완성이 즉시 반영돼야 함');
    expect(DateTime.now().difference(start).inMilliseconds, lessThan(1500),
        reason: 'claimDelay(5초)를 기다리지 않아야 한다');

    // 뒤늦게 응답을 보내도(이미 끝난 뒤이므로) 무시되고 에러가 나지 않는다.
    claimer.humanRespondClaim(); // 이 시점엔 opportunity가 이미 사라졌을 것
    await Future<void>.delayed(const Duration(milliseconds: 100));

    // 좌석2(뺏어오기 쪽) 클라이언트는 "완성자가 먼저 가져갔다" 알림을 받는다.
    await waitFor(() => claimer.notice.value?.kind == TableNoticeKind.claimed,
        reason: '뺏어오기 좌석에 알림이 와야 함');
    // claimer 시점(자신=0)에서 완성자는 좌석 1(자신 기준 회전 후에도 1).
    expect(claimer.notice.value?.seat, isNotNull);
  });

  test('버리기 제한시간: 응답 없으면 방금 뽑은 패를 그대로 자동으로 버린다', () async {
    final host = NetHostController(
      hostName: '방장',
      aiDelay: Duration.zero,
      claimDelay: Duration.zero,
      claimTimeout: const Duration(milliseconds: 200),
      discardTimeout: const Duration(milliseconds: 200),
      aiClaimThinkMax: Duration.zero,
    );
    await host.open(advertise: false);
    addTearDown(host.dispose);

    final client = NetClientController();
    addTearDown(client.dispose);
    await client.connect(InternetAddress.loopbackIPv4, host.port!,
        name: '느림보');
    await waitFor(() => host.humanCount == 2, reason: '접속');

    host.startGame();
    await waitFor(() => client.status == NetClientStatus.playing,
        reason: '게임 시작');

    // 호스트/AI 턴은 정상 진행시키되, 클라이언트 자신의 버리기 차례가
    // 되면 절대 응답하지 않고 제한시간에만 맡긴다.
    var safety = 0;
    while (!client.isHumanDiscardTurn && !host.isFinished) {
      expect(++safety, lessThan(50000));
      if (host.humanClaimOpportunity != null) {
        host.humanRespondClaim();
      } else if (host.canHumanTsumo) {
        host.humanTsumo();
      } else if (host.isHumanDiscardTurn) {
        host.humanDiscard(host.human.hand.first);
      }
      await Future<void>.delayed(const Duration(milliseconds: 2));
    }
    expect(client.isHumanDiscardTurn, isTrue, reason: '클라이언트 차례에 도달');
    final drawnBefore = client.game.drawnTile;
    expect(drawnBefore, isNotNull, reason: '뽑은 패가 있어야 함');

    // 200ms 뒤 자동으로 "방금 뽑은 패 그대로" 버려져야 한다.
    await waitFor(
        () =>
            client.game.players[0].discards.isNotEmpty &&
            client.game.players[0].discards.last == drawnBefore,
        timeout: const Duration(seconds: 5),
        reason: '뽑은 패가 자동으로 버려져야 함');
  });
}

Tile m(int r) => Tile(Suit.man, r);
Tile p(int r) => Tile(Suit.pin, r);
Tile s(int r) => Tile(Suit.sou, r);
Tile h(int r) => Tile(Suit.honor, r);
