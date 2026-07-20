import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../i18n/strings.dart';
import '../settings/app_settings.dart';
import 'theme.dart';

/// 설정 화면: 언어 선택.
class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<AppSettings>();
    final s = settings.strings;

    return Scaffold(
      appBar: AppBar(
        title: Text(s.settingsTitle,
            style: const TextStyle(
                fontWeight: FontWeight.bold, color: Palette.textBrown)),
        backgroundColor: Palette.mint,
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          _card(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _cardHeader(
                    const Icon(Icons.language_rounded,
                        size: 20, color: Palette.textBrown),
                    s.languageLabel),
                const SizedBox(height: 4),
                for (final lang in AppLang.values)
                  _langTile(
                    label: langNativeNames[lang]!,
                    selected: settings.lang == lang,
                    onTap: () => settings.setLang(lang),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _card({required Widget child}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.65),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Palette.mint, width: 2),
      ),
      child: child,
    );
  }

  Widget _cardHeader(Widget icon, String title) {
    return Row(
      children: [
        icon,
        const SizedBox(width: 6),
        Text(title,
            style: const TextStyle(
                fontWeight: FontWeight.bold, color: Palette.textBrown)),
      ],
    );
  }

  Widget _langTile({
    required String label,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        margin: const EdgeInsets.only(top: 6),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: selected ? Palette.mint : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(label,
                  style: TextStyle(
                    fontSize: 15,
                    color: Palette.textBrown,
                    fontWeight:
                        selected ? FontWeight.bold : FontWeight.normal,
                  )),
            ),
            if (selected)
              const Icon(Icons.check_rounded,
                  size: 20, color: Palette.textBrown),
          ],
        ),
      ),
    );
  }
}
