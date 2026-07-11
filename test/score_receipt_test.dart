import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mahjong_joy/i18n/strings.dart';
import 'package:mahjong_joy/logic/score.dart';
import 'package:mahjong_joy/models/tile.dart';
import 'package:mahjong_joy/sound/sound_service.dart';
import 'package:mahjong_joy/ui/score_receipt.dart';

Tile m(int r) => Tile(Suit.man, r);

void main() {
  setUpAll(() => SoundService.instance.enabled.value = false);

  testWidgets('영수증: 항목이 순차적으로 나타나고 마지막에 총점이 등장한다', (tester) async {
    // 원 컬러 손패 → 기본 완성 / 혼자 힘으로 / 원 컬러 3줄, 총점 1000
    final score = calculateScore(
      hand: [
        m(1), m(2), m(3), m(4), m(5), m(6), m(7), m(8), m(9),
        m(1), m(1), m(1), m(9), m(9),
      ],
      melds: [],
      isTsumo: false,
      wallCount: 50,
    );
    expect(score.lines, hasLength(3));

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ScoreReceipt(score, strings: stringsOf(AppLang.ko)),
        ),
      ),
    );

    // 아직 아무 항목도 안 보인다
    expect(find.text('기본 완성'), findsNothing);
    expect(find.text('소계'), findsOneWidget);

    // 550ms 간격으로 한 줄씩 등장
    await tester.pump(const Duration(milliseconds: 600));
    expect(find.text('기본 완성'), findsOneWidget);
    expect(find.text('혼자 힘으로'), findsNothing);

    await tester.pump(const Duration(milliseconds: 600));
    expect(find.text('혼자 힘으로'), findsOneWidget);

    await tester.pump(const Duration(milliseconds: 600));
    expect(find.text('원 컬러'), findsOneWidget);
    expect(find.text('×5'), findsOneWidget);
    expect(find.text('총점 🎉'), findsNothing);

    // 마지막 틱에 총점 등장, 타이머 종료
    await tester.pump(const Duration(milliseconds: 600));
    expect(find.text('총점 🎉'), findsOneWidget);
    expect(find.text('1000점'), findsOneWidget);

    await tester.pumpAndSettle();
  });
}
