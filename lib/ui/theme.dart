import 'package:flutter/material.dart';

/// 기획안 컬러 팔레트: 민트, 핑크, 크림 파스텔 톤.
class Palette {
  static const mint = Color(0xFFA8E6CF);
  static const mintDark = Color(0xFF5FBF9F);
  static const pink = Color(0xFFFFB3C1);
  static const pinkDark = Color(0xFFE98CA0);
  static const cream = Color(0xFFFFF6E9);
  static const tableGreen = Color(0xFFD3F0E4);
  static const textBrown = Color(0xFF6B5B4D);
  static const tileFace = Color(0xFFFFFDF8);
  static const tileBack = Color(0xFFB8E0D2);

  static ThemeData theme() {
    return ThemeData(
      useMaterial3: true,
      scaffoldBackgroundColor: cream,
      colorScheme: ColorScheme.fromSeed(
        seedColor: mint,
        surface: cream,
      ),
      textTheme: const TextTheme(
        bodyMedium: TextStyle(color: textBrown),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: pink,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          textStyle: const TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
    );
  }
}
