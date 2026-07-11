import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../i18n/strings.dart';
import '../settings/app_settings.dart';
import 'game_controller.dart';
import 'game_screen.dart';
import 'how_to_play_screen.dart';
import 'lobby_screen.dart';
import 'table_controller.dart';
import 'theme.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<AppSettings>();
    final s = settings.strings;

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Palette.cream, Palette.tableGreen],
          ),
        ),
        child: Center(
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('🀄', style: TextStyle(fontSize: 80)),
                const SizedBox(height: 8),
                const Text(
                  'Mahjong Joy',
                  style: TextStyle(
                    fontSize: 42,
                    fontWeight: FontWeight.w800,
                    color: Palette.textBrown,
                  ),
                ),
                Text(
                  s.tagline,
                  textAlign: TextAlign.center,
                  style:
                      const TextStyle(fontSize: 15, color: Palette.textBrown),
                ),
                const SizedBox(height: 32),
                ElevatedButton(
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) =>
                            ChangeNotifierProvider<TableController>(
                          create: (_) => GameController(settings: settings),
                          child: const GameScreen(),
                        ),
                      ),
                    );
                  },
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 40, vertical: 14),
                    child: Text('🤖 ${s.playWithAi}',
                        style: const TextStyle(fontSize: 19)),
                  ),
                ),
                const SizedBox(height: 14),
                ElevatedButton(
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                          builder: (_) => const FriendPlayScreen()),
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Palette.mintDark,
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 28, vertical: 14),
                    child: Text('📶 ${s.playWithFriends}',
                        style: const TextStyle(fontSize: 19)),
                  ),
                ),
                const SizedBox(height: 14),
                OutlinedButton(
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                          builder: (_) => const HowToPlayScreen()),
                    );
                  },
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Palette.textBrown,
                    side: const BorderSide(color: Palette.mintDark, width: 2),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 28, vertical: 12),
                    child: Text(s.howToPlayBtn,
                        style: const TextStyle(fontSize: 16)),
                  ),
                ),
                const SizedBox(height: 28),
                _settingsCard(settings, s),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// 언어 선택 + 초보자 모드 설정.
  Widget _settingsCard(AppSettings settings, Strings s) {
    return Container(
      constraints: const BoxConstraints(maxWidth: 340),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.65),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Palette.mint, width: 2),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              const Icon(Icons.language_rounded,
                  size: 20, color: Palette.textBrown),
              const SizedBox(width: 6),
              Text(s.languageLabel,
                  style: const TextStyle(
                      fontWeight: FontWeight.bold, color: Palette.textBrown)),
            ],
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final lang in AppLang.values)
                ChoiceChip(
                  label: Text(langNativeNames[lang]!,
                      style: const TextStyle(fontSize: 13)),
                  selected: settings.lang == lang,
                  selectedColor: Palette.mint,
                  onSelected: (_) => settings.setLang(lang),
                  visualDensity: VisualDensity.compact,
                ),
            ],
          ),
          const Divider(height: 20, color: Palette.mint),
          Row(
            children: [
              const Text('🐣', style: TextStyle(fontSize: 20)),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(s.beginnerTitle,
                        style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Palette.textBrown)),
                    Text(s.beginnerSubtitle,
                        style: const TextStyle(
                            fontSize: 12, color: Colors.black45)),
                  ],
                ),
              ),
              Switch(
                value: settings.simpleMode,
                activeThumbColor: Palette.mintDark,
                onChanged: settings.setSimpleMode,
              ),
            ],
          ),
        ],
      ),
    );
  }
}
