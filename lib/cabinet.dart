import 'package:flutter/material.dart';
import 'rewards.dart';

class CabinetPalette {
  const CabinetPalette(this.frame, this.trim, this.field, this.bar, this.ball);
  final Color frame, trim, bar;
  final List<Color> field, ball;
  static CabinetPalette of(CabinetStyle style) => switch (style) {
    CabinetStyle.brass => const CabinetPalette(
      Color(0xFF163D3B),
      Color(0xFFD9AE65),
      [Color(0xFFF7E1AA), Color(0xFFE1BC77), Color(0xFFC49350)],
      Color(0xFFB9C5BA),
      [
        Color(0xFFFFFFFF),
        Color(0xFFE6E8DF),
        Color(0xFF778B88),
        Color(0xFF1C3234),
      ],
    ),
    CabinetStyle.jade => const CabinetPalette(
      Color(0xFF123F39),
      Color(0xFFD8C18A),
      [Color(0xFFD9EDCC), Color(0xFFACCAA6), Color(0xFF7DAD96)],
      Color(0xFFE0C78F),
      [
        Color(0xFFFFFFFF),
        Color(0xFFF8E3AB),
        Color(0xFFB89956),
        Color(0xFF4D3B25),
      ],
    ),
    CabinetStyle.porcelain => const CabinetPalette(
      Color(0xFF213854),
      Color(0xFFAEBDC8),
      [Color(0xFFFAF5E9), Color(0xFFE2E7E9), Color(0xFFB7CAD4)],
      Color(0xFF86A6C3),
      [
        Color(0xFFFFFFFF),
        Color(0xFFE0F1FF),
        Color(0xFF7E9CBC),
        Color(0xFF203E61),
      ],
    ),
    CabinetStyle.ember => const CabinetPalette(
      Color(0xFF462D32),
      Color(0xFFE4B780),
      [Color(0xFFF6D7B0), Color(0xFFE5AE86), Color(0xFFBF8066)],
      Color(0xFFE4C6A4),
      [
        Color(0xFFFFFFFF),
        Color(0xFFFFE4D1),
        Color(0xFFBA755E),
        Color(0xFF522D34),
      ],
    ),
  };
}
