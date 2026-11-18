import 'package:flutter/material.dart';

import '../agent/context_builder.dart';

/// Colour tokens, matching the mockup.
@immutable
class Palette extends ThemeExtension<Palette> {
  const Palette({
    required this.page,
    required this.window,
    required this.bar,
    required this.sunk,
    required this.line,
    required this.fg,
    required this.muted,
    required this.faint,
    required this.accent,
    required this.onAccent,
    required this.userBubble,
    required this.ok,
    required this.okBg,
    required this.warn,
    required this.warnBg,
    required this.crit,
    required this.critBg,
    required this.instructions,
    required this.memory,
    required this.summary,
    required this.conversation,
    required this.toolResults,
  });

  final Color page, window, bar, sunk, line, fg, muted, faint, accent, onAccent;
  final Color userBubble, ok, okBg, warn, warnBg, crit, critBg;
  final Color instructions, memory, summary, conversation, toolResults;

  Color section(SectionKind k) => switch (k) {
        SectionKind.instructions => instructions,
        SectionKind.memory => memory,
        SectionKind.summary => summary,
        SectionKind.conversation => conversation,
        SectionKind.toolResults => toolResults,
      };

  static const light = Palette(
    page: Color(0xFFECEEF2),
    window: Color(0xFFFFFFFF),
    bar: Color(0xFFF5F6F8),
    sunk: Color(0xFFF0F2F5),
    line: Color(0xFFDFE3E8),
    fg: Color(0xFF1B1F26),
    muted: Color(0xFF667080),
    faint: Color(0xFF9AA3AF),
    accent: Color(0xFF0A66D8),
    onAccent: Color(0xFFFFFFFF),
    userBubble: Color(0xFFEEF2F8),
    ok: Color(0xFF1A7F4B),
    okBg: Color(0xFFE3F3EA),
    warn: Color(0xFFA35D00),
    warnBg: Color(0xFFFCF1DE),
    crit: Color(0xFFC2302F),
    critBg: Color(0xFFFBE8E7),
    instructions: Color(0xFF6D5CE8),
    memory: Color(0xFFCC4F9C),
    summary: Color(0xFFC9861D),
    conversation: Color(0xFF3A7FD6),
    toolResults: Color(0xFF14967F),
  );

  static const dark = Palette(
    page: Color(0xFF0B0D11),
    window: Color(0xFF16191F),
    bar: Color(0xFF1C2028),
    sunk: Color(0xFF20252E),
    line: Color(0xFF2C323D),
    fg: Color(0xFFEEF1F5),
    muted: Color(0xFFA2ACBA),
    faint: Color(0xFF6F7886),
    accent: Color(0xFF4C9BFF),
    onAccent: Color(0xFF06121F),
    userBubble: Color(0xFF232A35),
    ok: Color(0xFF5FD398),
    okBg: Color(0xFF16301F),
    warn: Color(0xFFF0B354),
    warnBg: Color(0xFF382A12),
    crit: Color(0xFFFF8077),
    critBg: Color(0xFF3A1B1A),
    instructions: Color(0xFF9D90FF),
    memory: Color(0xFFEE7CC0),
    summary: Color(0xFFEEB04F),
    conversation: Color(0xFF6AA9F2),
    toolResults: Color(0xFF3FCFB4),
  );

  @override
  Palette copyWith() => this;

  @override
  Palette lerp(ThemeExtension<Palette>? other, double t) =>
      t < 0.5 ? this : (other as Palette? ?? this);
}

extension PaletteX on BuildContext {
  Palette get pal => Theme.of(this).extension<Palette>()!;
}

const monoFamily = 'Menlo';

ThemeData buildTheme(Brightness b) {
  final p = b == Brightness.dark ? Palette.dark : Palette.light;
  final base = ThemeData(
    brightness: b,
    useMaterial3: true,
    colorScheme: ColorScheme.fromSeed(
      seedColor: p.accent,
      brightness: b,
      primary: p.accent,
      onPrimary: p.onAccent,
      surface: p.window,
      onSurface: p.fg,
    ),
    scaffoldBackgroundColor: p.page,
    dividerColor: p.line,
    extensions: [p],
  );
  return base.copyWith(
    textTheme: base.textTheme.apply(bodyColor: p.fg, displayColor: p.fg),
    tooltipTheme: TooltipThemeData(
      waitDuration: const Duration(milliseconds: 400),
      textStyle: TextStyle(color: p.window, fontSize: 12),
      decoration: BoxDecoration(color: p.fg, borderRadius: BorderRadius.circular(6)),
    ),
  );
}

/// Small rounded label.
class Pill extends StatelessWidget {
  const Pill(this.text, {super.key, required this.fg, required this.bg, this.bold = true});
  final String text;
  final Color fg, bg;
  final bool bold;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 2),
        decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(99)),
        child: Text(text,
            style: TextStyle(
                fontSize: 12, fontWeight: bold ? FontWeight.w600 : FontWeight.w400, color: fg)),
      );
}

class Cap extends StatelessWidget {
  const Cap(this.text, {super.key});
  final String text;
  @override
  Widget build(BuildContext context) => Text(text.toUpperCase(),
      style: TextStyle(
          fontSize: 11,
          letterSpacing: .8,
          fontWeight: FontWeight.w700,
          color: context.pal.muted));
}
