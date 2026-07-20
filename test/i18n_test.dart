import 'package:flutter_test/flutter_test.dart';
import 'package:mahjong_joy/i18n/strings.dart';
import 'package:mahjong_joy/logic/score.dart';

void main() {
  group('언어 매핑', () {
    test('지원 언어는 그대로, 그 외에는 영어', () {
      expect(langFromCode('ko'), AppLang.ko);
      expect(langFromCode('ja'), AppLang.ja);
      expect(langFromCode('zh'), AppLang.zh);
      expect(langFromCode('en'), AppLang.en);
      expect(langFromCode('de'), AppLang.en);
    });
  });

  group('문자열 완결성', () {
    test('모든 언어가 모든 보너스의 이름/설명을 가진다', () {
      for (final lang in AppLang.values) {
        final s = stringsOf(lang);
        for (final b in ScoreBonus.values) {
          expect(s.bonusName(b), isNotEmpty, reason: '$lang $b name');
          expect(s.bonusDetail(b), isNotEmpty, reason: '$lang $b detail');
        }
        // 설명서 보상 표기는 base/allWeather(숨김 잭팟) 제외 전부
        for (final b in ScoreBonus.values) {
          if (b == ScoreBonus.base || b == ScoreBonus.allWeather) continue;
          expect(s.bonusRewards[b], isNotNull, reason: '$lang $b reward');
        }
        expect(s.playerNames, hasLength(4), reason: '$lang playerNames');
      }
    });

    test('템플릿 자리표시자가 채워진다', () {
      for (final lang in AppLang.values) {
        final s = stringsOf(lang);
        expect(s.roundOf(3, 8), isNot(contains('{')));
        expect(s.wallLeft(12), isNot(contains('{')));
        expect(s.points('1,000'), isNot(contains('{')));
        expect(s.wins(2), isNot(contains('{')));
        expect(s.otherWon('X'), isNot(contains('{')));
        expect(s.ronSub('X', '100'), isNot(contains('{')));
        expect(s.tsumoSub('100'), isNot(contains('{')));
        expect(s.simpleRonSub('X'), isNot(contains('{')));
        expect(s.nextRound(2, 8), isNot(contains('{')));
        expect(s.scoreBody('1,000', 8, 100), isNot(contains('{')));
        expect(s.bonusDetail(ScoreBonus.lastCatch), isNot(contains('{n}')));
      }
    });
  });
}
