import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../i18n/strings.dart';
import '../logic/match_state.dart';
import '../logic/score.dart';
import '../models/tile.dart';
import '../settings/app_settings.dart';
import 'theme.dart';
import 'tile_widget.dart';

/// 게임 설명서: 목표, 진행, 뺏어오기/완성, 점수, 보너스, 타일 안내.
/// 초보자 모드(점수제 끔)에서는 점수/보너스 섹션을 숨긴다.
class HowToPlayScreen extends StatelessWidget {
  const HowToPlayScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<AppSettings>();
    final s = settings.strings;

    return Scaffold(
      appBar: AppBar(
        title: Text(s.manualTitle,
            style: const TextStyle(
                fontWeight: FontWeight.bold, color: Palette.textBrown)),
        backgroundColor: Palette.mint,
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          _section(
            s.tilesTitle,
            s.tilesBody,
            example: Padding(
              padding: const EdgeInsets.only(top: 8),
              child: TileRow(
                [for (var r = 1; r <= 7; r++) Tile(Suit.honor, r)],
                size: 30,
              ),
            ),
          ),
          _section(
            s.goalTitle,
            s.goalBody,
            example: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _comboRow(s.straightName, s.straightDesc,
                    const [Tile(Suit.man, 1), Tile(Suit.man, 2), Tile(Suit.man, 3)]),
                _comboRow(s.tripleName, s.tripleDesc,
                    const [Tile(Suit.pin, 7), Tile(Suit.pin, 7), Tile(Suit.pin, 7)]),
                _comboRow(s.headName, s.headDesc,
                    const [Tile(Suit.honor, 5), Tile(Suit.honor, 5)]),
              ],
            ),
          ),
          _section(s.flowTitle, s.flowBody),
          _section(s.claimTitle, s.claimBody),
          _section(
            s.completeTitle,
            s.completeBody,
            example: Padding(
              padding: const EdgeInsets.only(top: 10),
              child: Wrap(
                spacing: 10,
                runSpacing: 8,
                children: [
                  _labeledGroup(const [
                    Tile(Suit.man, 1), Tile(Suit.man, 2), Tile(Suit.man, 3),
                  ], s.meldLabel),
                  _labeledGroup(const [
                    Tile(Suit.pin, 4), Tile(Suit.pin, 5), Tile(Suit.pin, 6),
                  ], s.meldLabel),
                  _labeledGroup(const [
                    Tile(Suit.sou, 7), Tile(Suit.sou, 7), Tile(Suit.sou, 7),
                  ], s.meldLabel),
                  _labeledGroup(const [
                    Tile(Suit.honor, 2), Tile(Suit.honor, 2), Tile(Suit.honor, 2),
                  ], s.meldLabel),
                  _labeledGroup(const [
                    Tile(Suit.honor, 5), Tile(Suit.honor, 5),
                  ], s.headLabel),
                ],
              ),
            ),
          ),
          if (!settings.simpleMode) ...[
            _section(
              s.scoreTitle,
              s.scoreBody(_fmt(MatchState.startingPoints),
                  MatchState.totalRounds, baseWinScore),
            ),
            _section(
              s.bonusTitle,
              s.bonusIntro,
              example: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _bonusHeader(s.plusHeader),
                  _bonus(s, ScoreBonus.weatherSet, groups: const [
                    [Tile(Suit.honor, 6), Tile(Suit.honor, 6), Tile(Suit.honor, 6)],
                    [Tile(Suit.honor, 7), Tile(Suit.honor, 7), Tile(Suit.honor, 7)],
                  ]),
                  _bonus(s, ScoreBonus.selfDraw),
                  _bonus(s, ScoreBonus.allStraight, groups: const [
                    [Tile(Suit.man, 1), Tile(Suit.man, 2), Tile(Suit.man, 3)],
                    [Tile(Suit.man, 4), Tile(Suit.man, 5), Tile(Suit.man, 6)],
                    [Tile(Suit.pin, 1), Tile(Suit.pin, 2), Tile(Suit.pin, 3)],
                    [Tile(Suit.sou, 7), Tile(Suit.sou, 8), Tile(Suit.sou, 9)],
                    [Tile(Suit.pin, 5), Tile(Suit.pin, 5)],
                  ]),
                  _bonus(s, ScoreBonus.lastCatch),
                  const SizedBox(height: 8),
                  _bonusHeader(s.timesHeader),
                  _bonus(s, ScoreBonus.solo),
                  _bonus(s, ScoreBonus.halfHalf, groups: const [
                    [Tile(Suit.man, 1), Tile(Suit.man, 2), Tile(Suit.man, 3)],
                    [Tile(Suit.man, 4), Tile(Suit.man, 5), Tile(Suit.man, 6)],
                    [Tile(Suit.man, 7), Tile(Suit.man, 8), Tile(Suit.man, 9)],
                    [Tile(Suit.honor, 1), Tile(Suit.honor, 1), Tile(Suit.honor, 1)],
                    [Tile(Suit.honor, 5), Tile(Suit.honor, 5)],
                  ]),
                  _bonus(s, ScoreBonus.allTriple, groups: const [
                    [Tile(Suit.man, 1), Tile(Suit.man, 1), Tile(Suit.man, 1)],
                    [Tile(Suit.pin, 5), Tile(Suit.pin, 5), Tile(Suit.pin, 5)],
                    [Tile(Suit.sou, 7), Tile(Suit.sou, 7), Tile(Suit.sou, 7)],
                    [Tile(Suit.honor, 2), Tile(Suit.honor, 2), Tile(Suit.honor, 2)],
                    [Tile(Suit.man, 9), Tile(Suit.man, 9)],
                  ]),
                  _bonus(s, ScoreBonus.oneColor, groups: const [
                    [Tile(Suit.man, 1), Tile(Suit.man, 1), Tile(Suit.man, 1)],
                    [Tile(Suit.man, 2), Tile(Suit.man, 3), Tile(Suit.man, 4)],
                    [Tile(Suit.man, 5), Tile(Suit.man, 6), Tile(Suit.man, 7)],
                    [Tile(Suit.man, 8), Tile(Suit.man, 8), Tile(Suit.man, 8)],
                    [Tile(Suit.man, 9), Tile(Suit.man, 9)],
                  ]),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _section(String title, String body, {Widget? example}) {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.8),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Palette.mint, width: 2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title,
              style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Palette.textBrown)),
          const SizedBox(height: 8),
          Text(body,
              style: const TextStyle(
                  fontSize: 15, height: 1.5, color: Palette.textBrown)),
          ?example,
        ],
      ),
    );
  }

  /// 타일 묶음 아래에 작은 라벨(몸통/머리)을 붙인 예시.
  Widget _labeledGroup(List<Tile> tiles, String label) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        TileRow(tiles, size: 24),
        const SizedBox(height: 2),
        Text(label,
            style: const TextStyle(fontSize: 11, color: Colors.black45)),
      ],
    );
  }

  Widget _bonusHeader(String text) {
    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: Text(text,
          style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.bold,
              color: Palette.textBrown)),
    );
  }

  /// 보너스 한 항목: 이름 — 설명 (보상), 그리고 선택적으로 예시 타일 묶음들.
  Widget _bonus(Strings s, ScoreBonus bonus, {List<List<Tile>>? groups}) {
    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text.rich(
            TextSpan(
              children: [
                TextSpan(
                    text: '${bonusEmoji[bonus]} ${s.bonusName(bonus)}',
                    style: const TextStyle(fontWeight: FontWeight.bold)),
                TextSpan(
                    text:
                        ' — ${s.bonusDetail(bonus)} (${s.bonusRewards[bonus]})'),
              ],
            ),
            style: const TextStyle(
                fontSize: 14, height: 1.4, color: Palette.textBrown),
          ),
          if (groups != null)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Wrap(
                spacing: 10,
                runSpacing: 6,
                children: [for (final g in groups) TileRow(g, size: 20)],
              ),
            ),
        ],
      ),
    );
  }

  Widget _comboRow(String name, String desc, List<Tile> tiles) {
    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: Row(
        children: [
          TileRow(tiles, size: 28),
          const SizedBox(width: 12),
          Expanded(
            child: Text('$name — $desc',
                style: const TextStyle(fontSize: 14, color: Palette.textBrown)),
          ),
        ],
      ),
    );
  }

  static String _fmt(int n) => n
      .toString()
      .replaceAllMapped(RegExp(r'(\d)(?=(\d{3})+$)'), (m) => '${m[1]},');
}
