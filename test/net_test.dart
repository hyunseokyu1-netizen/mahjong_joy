import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:mahjong_joy/logic/game.dart';
import 'package:mahjong_joy/logic/match_state.dart';
import 'package:mahjong_joy/net/client_session.dart';
import 'package:mahjong_joy/net/host_session.dart';
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
}
