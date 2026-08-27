import 'package:flutter/material.dart';

import 'tokens.dart';

/// Theme sáng và tối của SafeFleet.
///
/// Chế độ tối KHÔNG phải màu đảo ngược tự động — nó là một bảng màu riêng
/// (xem [SfPalette.dark]). Các màn Chế độ lái / Camera cabin / Trợ lý / Quét
/// phiếu bọc bằng [SfTheme.darkWrap] để luôn tối, kể cả khi phần còn lại của
/// app đang ở chế độ sáng.
class SfTheme {
  const SfTheme._();

  static ThemeData get light => _build(SfPalette.light, Brightness.light);
  static ThemeData get dark => _build(SfPalette.dark, Brightness.dark);

  /// Bọc một cây widget vào chế độ tối bất kể theme cha.
  static Widget darkWrap({required Widget child}) =>
      Theme(data: dark, child: child);

  static ThemeData _build(SfPalette p, Brightness brightness) {
    final scheme =
        ColorScheme.fromSeed(
          seedColor: SfColors.green700,
          brightness: brightness,
          surface: p.surface,
        ).copyWith(
          primary: p.accent,
          onPrimary: p.onAccent,
          secondary: p.isDark ? SfColors.green300 : SfColors.green600,
          error: SfColors.danger,
          onError: SfColors.onDanger,
          surface: p.surface,
          onSurface: p.textPrimary,
          outline: p.border,
          surfaceContainerLowest: p.surface,
          surfaceContainer: p.surfaceAlt,
        );

    final text = SfType.themeText(p.textPrimary, p.textSecondary);

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: scheme,
      scaffoldBackgroundColor: p.bg,
      canvasColor: p.surface,
      dividerColor: p.border,
      textTheme: text,
      primaryTextTheme: text,
      extensions: <ThemeExtension<dynamic>>[p],
      splashFactory: InkSparkle.splashFactory,
      appBarTheme: AppBarTheme(
        backgroundColor: p.bg,
        foregroundColor: p.textPrimary,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: SfType.titleSub.copyWith(color: p.textPrimary),
      ),
      cardTheme: CardThemeData(
        color: p.surface,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: SfRadius.cardR,
          side: BorderSide(color: p.border),
        ),
      ),
      dividerTheme: DividerThemeData(color: p.border, space: 1, thickness: 1),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: p.isDark ? p.surfaceAlt : SfColors.fieldBg,
        hintStyle: SfType.bodySm.copyWith(color: p.textMuted),
        labelStyle: SfType.meta.copyWith(color: p.textSecondary),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: SfSpace.x14,
          vertical: SfSpace.x14,
        ),
        border: OutlineInputBorder(
          borderRadius: SfRadius.controlR,
          borderSide: BorderSide(color: p.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: SfRadius.controlR,
          borderSide: BorderSide(color: p.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: SfRadius.controlR,
          borderSide: BorderSide(color: p.accent, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: SfRadius.controlR,
          borderSide: const BorderSide(color: SfColors.danger),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: p.accent,
          foregroundColor: p.onAccent,
          disabledBackgroundColor: p.isDark
              ? p.surfaceAlt
              : SfColors.dividerStrong,
          disabledForegroundColor: p.textMuted,
          minimumSize: const Size.fromHeight(SfTouch.primaryHeight),
          textStyle: SfType.titleCardSm,
          shape: const RoundedRectangleBorder(
            borderRadius: SfRadius.controlLgR,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: p.textPrimary,
          minimumSize: const Size.fromHeight(SfTouch.primaryHeight),
          textStyle: SfType.titleCardSm,
          side: BorderSide(color: p.border),
          shape: const RoundedRectangleBorder(
            borderRadius: SfRadius.controlLgR,
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: p.accent,
          textStyle: SfType.bodySm.copyWith(fontWeight: FontWeight.w600),
        ),
      ),
      iconTheme: IconThemeData(color: p.textSecondary),
      chipTheme: ChipThemeData(
        backgroundColor: p.surfaceAlt,
        side: BorderSide(color: p.border),
        labelStyle: SfType.meta.copyWith(color: p.textPrimary),
        shape: const StadiumBorder(),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: p.surface,
        surfaceTintColor: Colors.transparent,
        modalBarrierColor: SfColors.scrim,
        shape: const RoundedRectangleBorder(borderRadius: SfRadius.sheetR),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: p.surface,
        surfaceTintColor: Colors.transparent,
        shape: const RoundedRectangleBorder(borderRadius: SfRadius.cardR),
        titleTextStyle: SfType.titleCard.copyWith(color: p.textPrimary),
        contentTextStyle: SfType.bodySm.copyWith(color: p.textSecondary),
      ),
      // SnackBar chỉ dành cho phản hồi thao tác thường (đã lưu, đã gửi).
      // Cảnh báo an toàn dùng SfAlertBanner.
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: SfColors.green800,
        contentTextStyle: SfType.bodySm.copyWith(color: SfColors.onAccent),
        shape: const RoundedRectangleBorder(
          borderRadius: SfRadius.controlR,
        ),
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: p.accent,
        linearTrackColor: p.isDark ? p.surfaceAlt : SfColors.divider,
        circularTrackColor: p.isDark ? p.surfaceAlt : SfColors.divider,
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? SfColors.onAccent
              : p.textMuted,
        ),
        trackColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? p.accent
              : (p.isDark ? p.surfaceAlt : SfColors.dividerStrong),
        ),
        trackOutlineColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? p.accent
              : p.border,
        ),
      ),
    );
  }
}
