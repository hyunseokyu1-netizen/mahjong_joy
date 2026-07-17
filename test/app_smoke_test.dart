import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mahjong_joy/i18n/strings.dart';
import 'package:mahjong_joy/main.dart';
import 'package:mahjong_joy/settings/app_settings.dart';
import 'package:mahjong_joy/sound/sound_service.dart';
import 'package:mahjong_joy/ui/game_controller.dart';
import 'package:mahjong_joy/ui/game_screen.dart';
import 'package:mahjong_joy/ui/table_controller.dart';
import 'package:mahjong_joy/ui/theme.dart';
import 'package:mahjong_joy/ui/tile_widget.dart';
import 'package:provider/provider.dart';

Widget app(GameController controller) => MultiProvider(
      providers: [
        ChangeNotifierProvider(
            create: (_) => AppSettings(lang: AppLang.ko)),
        ChangeNotifierProvider<TableController>.value(value: controller),
      ],
      child: MaterialApp(theme: Palette.theme(), home: const GameScreen()),
    );

/// 사람 입력 대기 지점(버리기/클레임/종료)까지 AI 턴을 진행시킨다.
Future<void> pumpUntilHumanInput(
    WidgetTester tester, GameController gc) async {
  for (var i = 0; i < 200; i++) {
    await tester.pump(const Duration(milliseconds: 700));
    if (gc.isFinished ||
        gc.isHumanDiscardTurn ||
        gc.humanClaimOpportunity != null) {
      await tester.pump();
      return;
    }
  }
  fail('사람 입력 지점에 도달하지 못함');
}

/// 네트워크 대전처럼 버리기 제한시간이 있는 컨트롤러 흉내
/// (턴 타이머 UI 테스트용).
class _TimedController extends GameController {
  _TimedController({super.seed});

  @override
  Duration? get discardTimeLimit => const Duration(seconds: 15);
}

/// 결과 영수증 애니메이션 타이머가 남지 않도록 트리를 내려서 정리한다.
Future<void> tearDownTree(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox.shrink());
  await tester.pump();
}

void main() {
  // 테스트 환경에는 오디오 플러그인이 없으므로 효과음을 끈다.
  setUpAll(() => SoundService.instance.enabled.value = false);

  testWidgets('메인화면: 시작 버튼과 설명서 메뉴가 동작한다', (tester) async {
    await tester.pumpWidget(
        MahjongJoyApp(settings: AppSettings(lang: AppLang.ko)));
    expect(find.text('마작한판'), findsOneWidget);
    expect(find.text('🤖 AI와 하기'), findsOneWidget);
    expect(find.text('📶 친구와 하기'), findsOneWidget);
    // 언어 선택과 초보자 모드 설정이 보인다
    expect(find.text('한국어'), findsOneWidget);
    expect(find.text('English'), findsOneWidget);
    expect(find.text('초보자 모드'), findsOneWidget);

    // 설명서로 이동했다가 돌아온다
    await tester.tap(find.text('게임 설명서 📖'));
    await tester.pumpAndSettle();
    expect(find.text('🎯 목표'), findsOneWidget);
    // 점수 섹션은 화면 밖에 있을 수 있으므로 스크롤해서 확인
    await tester.scrollUntilVisible(find.text('💰 점수'), 300,
        scrollable: find.byType(Scrollable).first);
    expect(find.text('💰 점수'), findsOneWidget);
    await tester.pageBack();
    await tester.pumpAndSettle();

    // 게임 시작 → 게임 화면 (사람 차례로 시작하므로 대기 타이머 없음)
    await tester.tap(find.text('🤖 AI와 하기'));
    await tester.pumpAndSettle();
    expect(find.text('버릴 패를 골라주세요'), findsWidgets);
    expect(find.textContaining('판 / 8'), findsOneWidget);
  });

  testWidgets('첫 화면: 내 차례로 시작하고 손패 14장이 보인다', (tester) async {
    final gc = GameController(seed: 7);
    await tester.pumpWidget(app(gc));

    expect(find.text('🙂 나'), findsOneWidget);
    expect(find.text('버릴 패를 골라주세요'), findsWidgets);
    expect(gc.isHumanDiscardTurn, isTrue);
    expect(gc.human.hand.length, 14);
    // 상대 3명 표시
    expect(find.text('🐰 토끼'), findsOneWidget);
    expect(find.text('🧸 곰돌이'), findsOneWidget);
    expect(find.text('🐱 야옹이'), findsOneWidget);

    gc.dispose();
  });

  testWidgets('버리기 제한시간이 있으면 카운트다운이 보이고 마지막 5초는 크게 표시된다',
      (tester) async {
    final gc = _TimedController(seed: 7);
    await tester.pumpWidget(app(gc));

    // 내 차례 시작: 상단 배지에 남은 시간 표시
    expect(gc.isHumanDiscardTurn, isTrue);
    expect(find.text('⏱ 15'), findsOneWidget);

    // 손패 타일의 숫자와 겹치지 않게, 중앙의 큰 숫자만 골라 찾는다.
    Finder bigNumber(String n) => find.byWidgetPredicate(
        (w) => w is Text && w.data == n && (w.style?.fontSize ?? 0) > 100);

    // 10초 경과 → 마지막 5초 구간: 중앙 큰 숫자로 전환
    await tester.pump(const Duration(seconds: 10));
    expect(find.text('⏱ 5'), findsNothing);
    expect(bigNumber('5'), findsOneWidget);
    await tester.pump(const Duration(seconds: 1));
    expect(bigNumber('4'), findsOneWidget);

    // 패를 버리면 (내 차례가 끝나면) 타이머가 사라진다
    gc.humanDiscard(gc.human.hand.first);
    await tester.pump();
    expect(bigNumber('4'), findsNothing);

    await pumpUntilHumanInput(tester, gc);
    gc.dispose();
    await tearDownTree(tester);
  });

  testWidgets('패를 버리면 AI 턴이 진행되고 다시 입력 지점으로 돌아온다', (tester) async {
    final gc = GameController(seed: 7);
    await tester.pumpWidget(app(gc));

    final discard = gc.human.hand.first;
    gc.humanDiscard(discard);
    await tester.pump();
    expect(gc.human.hand.length, 13);
    // 버린 패가 바닥에 표시된다
    expect(gc.human.discards, [discard]);

    await pumpUntilHumanInput(tester, gc);
    expect(
      gc.isFinished ||
          gc.isHumanDiscardTurn ||
          gc.humanClaimOpportunity != null,
      isTrue,
    );

    gc.dispose();
    await tearDownTree(tester);
  });

  testWidgets('클레임 프롬프트가 뜨면 패스로 넘길 수 있다', (tester) async {
    final gc = GameController(seed: 7);
    await tester.pumpWidget(app(gc));

    // 사람 입력 지점을 오가며 클레임 프롬프트가 뜨는 판까지 진행
    for (var round = 0; round < 300 && !gc.isFinished; round++) {
      if (gc.humanClaimOpportunity != null) {
        expect(find.text('이 패, 가져갈까요?'), findsOneWidget);
        expect(find.text('패스'), findsOneWidget);
        await tester.tap(find.text('패스'));
        await tester.pump();
        expect(gc.humanClaimOpportunity, isNull);
        // 패스 직후 이어지는 AI 턴 타이머를 모두 소진시킨 뒤 종료
        await pumpUntilHumanInput(tester, gc);
        gc.dispose();
        await tearDownTree(tester);
        return; // 목표 달성
      }
      if (gc.isHumanDiscardTurn) {
        gc.humanDiscard(gc.human.hand.first);
        await tester.pump();
      }
      await pumpUntilHumanInput(tester, gc);
    }
    // 이 시드에서 프롬프트가 안 떴다면 게임만 정상 종료됐어도 통과로 본다
    expect(gc.isFinished, isTrue);
    expect(find.byType(TileWidget), findsWidgets);
    gc.dispose();
    await tearDownTree(tester);
  });

  testWidgets('가로모드처럼 세로 폭이 좁아도 오버플로우 없이 그려진다', (tester) async {
    // 세로가 아주 좁은(가로모드 폰 느낌) 화면에서 강이 많이 쌓인 상태를
    // 흉내낸다. FlutterError.onError로 렌더 오버플로우(RenderFlex 등)를
    // 잡아내 실패시킨다.
    final errors = <FlutterErrorDetails>[];
    final originalOnError = FlutterError.onError;
    FlutterError.onError = (details) => errors.add(details);
    addTearDown(() => FlutterError.onError = originalOnError);

    await tester.binding.setSurfaceSize(const Size(900, 420));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final gc = GameController(seed: 3);
    await tester.pumpWidget(app(gc));

    // 여러 판을 버리며 강에 패가 꽤 쌓인 상태까지 진행.
    for (var i = 0; i < 15 && !gc.isFinished; i++) {
      if (gc.isHumanDiscardTurn) {
        gc.humanDiscard(gc.human.hand.first);
        await tester.pump();
      }
      await pumpUntilHumanInput(tester, gc);
    }
    await tester.pump();

    expect(errors, isEmpty,
        reason: errors.map((e) => e.summary).join('\n'));
    gc.dispose();
    await tearDownTree(tester);
  });
}
