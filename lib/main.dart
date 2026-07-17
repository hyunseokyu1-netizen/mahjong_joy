import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'settings/app_settings.dart';
import 'ui/home_screen.dart';
import 'ui/theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final settings = await AppSettings.load();
  runApp(MahjongJoyApp(settings: settings));
}

class MahjongJoyApp extends StatelessWidget {
  final AppSettings settings;

  const MahjongJoyApp({super.key, required this.settings});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider.value(
      value: settings,
      child: MaterialApp(
        title: settings.strings.appTitle,
        debugShowCheckedModeBanner: false,
        theme: Palette.theme(),
        home: const HomeScreen(),
      ),
    );
  }
}
