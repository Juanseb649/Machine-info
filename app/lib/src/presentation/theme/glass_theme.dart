import 'package:flutter/material.dart';

@immutable
class GlassTokens extends ThemeExtension<GlassTokens> {
  const GlassTokens({
    required this.backgroundTop,
    required this.backgroundBottom,
    required this.blobs,
    required this.glassFill,
    required this.glassFillStrong,
    required this.glassEdgeLight,
    required this.glassEdgeDark,
    required this.shadow,
    required this.scrim,
    required this.textPrimary,
    required this.textSecondary,
    required this.textTertiary,
    required this.accent,
    required this.accentSoft,
    required this.success,
    required this.warning,
    required this.danger,
    required this.info,
    required this.track,
    required this.popover,
  });

  final Color backgroundTop;
  final Color backgroundBottom;
  final List<Color> blobs;
  final Color glassFill;
  final Color glassFillStrong;
  final Color glassEdgeLight;
  final Color glassEdgeDark;
  final Color shadow;
  final Color scrim;
  final Color textPrimary;
  final Color textSecondary;
  final Color textTertiary;
  final Color accent;
  final Color accentSoft;
  final Color success;
  final Color warning;
  final Color danger;
  final Color info;
  final Color track;
  final Color popover;

  static const light = GlassTokens(
    backgroundTop: Color(0xFFE9EFFB),
    backgroundBottom: Color(0xFFF5F2FF),
    blobs: [Color(0x997CC4FF), Color(0x80B59CFF), Color(0x708EF0D9)],
    glassFill: Color(0x8CFFFFFF),
    glassFillStrong: Color(0xC7FFFFFF),
    glassEdgeLight: Color(0xF2FFFFFF),
    glassEdgeDark: Color(0x40FFFFFF),
    shadow: Color(0x1A1E3A8A),
    scrim: Color(0x730B1324),
    textPrimary: Color(0xFF0B1324),
    textSecondary: Color(0xFF4A5568),
    textTertiary: Color(0xFF8A94A6),
    accent: Color(0xFF0A84FF),
    accentSoft: Color(0x240A84FF),
    success: Color(0xFF28C76F),
    warning: Color(0xFFFF9F0A),
    danger: Color(0xFFFF3B30),
    info: Color(0xFF32ADE6),
    track: Color(0x1F0B1324),
    popover: Color(0xF5F7F9FD),
  );

  static const dark = GlassTokens(
    backgroundTop: Color(0xFF070B16),
    backgroundBottom: Color(0xFF0E1022),
    blobs: [Color(0x731E6BFF), Color(0x667B3FF2), Color(0x4700C2A8)],
    glassFill: Color(0x12FFFFFF),
    glassFillStrong: Color(0x1FFFFFFF),
    glassEdgeLight: Color(0x47FFFFFF),
    glassEdgeDark: Color(0x0FFFFFFF),
    shadow: Color(0x73000000),
    scrim: Color(0x99000000),
    textPrimary: Color(0xFFF2F5FA),
    textSecondary: Color(0xFFA3ADC2),
    textTertiary: Color(0xFF6B7488),
    accent: Color(0xFF409CFF),
    accentSoft: Color(0x33409CFF),
    success: Color(0xFF30D158),
    warning: Color(0xFFFF9F0A),
    danger: Color(0xFFFF453A),
    info: Color(0xFF64D2FF),
    track: Color(0x1FFFFFFF),
    popover: Color(0xF5151A2B),
  );

  Color levelColor(double ratio) {
    if (ratio >= 0.9) return danger;
    if (ratio >= 0.75) return warning;
    return accent;
  }

  @override
  GlassTokens copyWith({Color? accent}) => GlassTokens(
        backgroundTop: backgroundTop,
        backgroundBottom: backgroundBottom,
        blobs: blobs,
        glassFill: glassFill,
        glassFillStrong: glassFillStrong,
        glassEdgeLight: glassEdgeLight,
        glassEdgeDark: glassEdgeDark,
        shadow: shadow,
        scrim: scrim,
        textPrimary: textPrimary,
        textSecondary: textSecondary,
        textTertiary: textTertiary,
        accent: accent ?? this.accent,
        accentSoft: accentSoft,
        success: success,
        warning: warning,
        danger: danger,
        info: info,
        track: track,
        popover: popover,
      );

  @override
  GlassTokens lerp(ThemeExtension<GlassTokens>? other, double t) {
    if (other is! GlassTokens) return this;
    Color c(Color a, Color b) => Color.lerp(a, b, t)!;
    return GlassTokens(
      backgroundTop: c(backgroundTop, other.backgroundTop),
      backgroundBottom: c(backgroundBottom, other.backgroundBottom),
      blobs: [for (var i = 0; i < blobs.length; i++) c(blobs[i], other.blobs[i])],
      glassFill: c(glassFill, other.glassFill),
      glassFillStrong: c(glassFillStrong, other.glassFillStrong),
      glassEdgeLight: c(glassEdgeLight, other.glassEdgeLight),
      glassEdgeDark: c(glassEdgeDark, other.glassEdgeDark),
      shadow: c(shadow, other.shadow),
      scrim: c(scrim, other.scrim),
      textPrimary: c(textPrimary, other.textPrimary),
      textSecondary: c(textSecondary, other.textSecondary),
      textTertiary: c(textTertiary, other.textTertiary),
      accent: c(accent, other.accent),
      accentSoft: c(accentSoft, other.accentSoft),
      success: c(success, other.success),
      warning: c(warning, other.warning),
      danger: c(danger, other.danger),
      info: c(info, other.info),
      track: c(track, other.track),
      popover: c(popover, other.popover),
    );
  }
}

extension GlassContext on BuildContext {
  GlassTokens get glass => Theme.of(this).extension<GlassTokens>()!;
}

ThemeData buildGlassTheme(Brightness brightness) {
  final tokens = brightness == Brightness.dark ? GlassTokens.dark : GlassTokens.light;
  final scheme = ColorScheme.fromSeed(
    seedColor: tokens.accent,
    brightness: brightness,
  ).copyWith(
    primary: tokens.accent,
    onPrimary: Colors.white,
    error: tokens.danger,
    surface: tokens.backgroundTop,
    onSurface: tokens.textPrimary,
    onSurfaceVariant: tokens.textSecondary,
    outline: tokens.textTertiary,
    outlineVariant: tokens.track,
  );

  final base = ThemeData(useMaterial3: true, brightness: brightness, colorScheme: scheme);
  final text = base.textTheme.apply(bodyColor: tokens.textPrimary, displayColor: tokens.textPrimary);

  return base.copyWith(
    scaffoldBackgroundColor: Colors.transparent,
    canvasColor: tokens.popover,
    extensions: [tokens],
    textTheme: text.copyWith(
      headlineSmall: text.headlineSmall?.copyWith(fontWeight: FontWeight.w700, letterSpacing: -0.4),
      titleLarge: text.titleLarge?.copyWith(fontWeight: FontWeight.w700, letterSpacing: -0.3),
      titleMedium: text.titleMedium?.copyWith(fontWeight: FontWeight.w600, letterSpacing: -0.1),
      bodySmall: text.bodySmall?.copyWith(color: tokens.textSecondary),
      labelSmall: text.labelSmall?.copyWith(color: tokens.textSecondary, letterSpacing: 0.4),
    ),
    iconTheme: IconThemeData(color: tokens.textPrimary),
    dividerTheme: DividerThemeData(color: tokens.track, thickness: 1, space: 1),
    tooltipTheme: TooltipThemeData(
      decoration: BoxDecoration(color: tokens.popover, borderRadius: BorderRadius.circular(10)),
      textStyle: TextStyle(color: tokens.textPrimary, fontSize: 12),
      waitDuration: const Duration(milliseconds: 400),
    ),
    popupMenuTheme: PopupMenuThemeData(
      color: tokens.popover,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      elevation: 8,
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: Colors.transparent,
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: tokens.popover,
      contentTextStyle: TextStyle(color: tokens.textPrimary),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      elevation: 6,
    ),
    switchTheme: SwitchThemeData(
      thumbColor: const WidgetStatePropertyAll(Colors.white),
      trackColor: WidgetStateProperty.resolveWith(
        (states) => states.contains(WidgetState.selected) ? tokens.success : tokens.track,
      ),
      trackOutlineColor: const WidgetStatePropertyAll(Colors.transparent),
    ),
    progressIndicatorTheme: ProgressIndicatorThemeData(color: tokens.accent, linearTrackColor: Colors.transparent),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: tokens.glassFill,
      isDense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      hintStyle: TextStyle(color: tokens.textTertiary),
      prefixIconColor: tokens.textSecondary,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: tokens.glassEdgeDark)),
      enabledBorder:
          OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: tokens.glassEdgeLight)),
      focusedBorder:
          OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: tokens.accent, width: 1.5)),
    ),
    scrollbarTheme: ScrollbarThemeData(
      thumbColor: WidgetStatePropertyAll(tokens.textTertiary.withValues(alpha: 0.5)),
      radius: const Radius.circular(8),
      thickness: const WidgetStatePropertyAll(6),
    ),
  );
}
