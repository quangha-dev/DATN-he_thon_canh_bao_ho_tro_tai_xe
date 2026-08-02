import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Nguồn chân lý duy nhất cho màu, chữ, khoảng cách, bo góc, đổ bóng.
///
/// Quy ước: KHÔNG khai báo `Color(0x...)` hay dựng `TextStyle(...)` từ đầu ở
/// bất kỳ file nào khác. Mọi màn dùng token ở đây, hoặc `.copyWith()` từ token.
class SfColors {
  const SfColors._();

  // ---- Thương hiệu ----
  static const navy = Color(0xFF12243D);
  static const navy700 = Color(0xFF1C3858);
  static const navy500 = Color(0xFF315A87);
  static const navyTint = Color(0xFFEAF2FA);
  static const teal = Color(0xFF087F73);
  static const tealTint = Color(0xFFE5F6F2);
  static const mint = Color(0xFF57D4C5);

  // ---- Trạng thái ----
  static const amber = Color(0xFFF59E0B);
  static const amberTint = Color(0xFFFEF6E7);
  static const amberInk = Color(0xFF2A1C02);
  static const danger = Color(0xFFB42318);
  static const dangerHot = Color(0xFFE0342A);
  static const dangerTint = Color(0xFFFFF0ED);
  static const success = Color(0xFF0E7C5A);
  static const successTint = Color(0xFFE8F8F4);

  // ---- Chế độ sáng ----
  static const bg = Color(0xFFF7F9FB);
  static const surface = Color(0xFFFFFFFF);
  static const surfaceAlt = Color(0xFFF4F7F9);
  static const border = Color(0xFFE4E9EE);
  static const textPrimary = Color(0xFF12243D);
  static const textSecondary = Color(0xFF667788);
  static const textMuted = Color(0xFF9AABB9);

  // ---- Chế độ tối (không phải màu đảo ngược tự động) ----
  static const darkBg = Color(0xFF0F1216);
  static const darkSurface = Color(0xFF1A1F26);
  static const darkSurfaceAlt = Color(0xFF151A20);
  static const darkBorder = Color(0x14FFFFFF); // trắng 8%
  static const darkTextPrimary = Color(0xFFE8ECF1);
  static const darkTextSecondary = Color(0xFF8C98A6);
  static const darkTextMuted = Color(0xFF6C7885);

  // ---- Dùng chung ----
  static const onAccent = Color(0xFFFFFFFF);
  static const onDanger = Color(0xFFFFFFFF);
  static const scrim = Color(0xD9111C2B);
  static const shadow = Color(0x24000000); // đen 14%
}

/// Chuỗi hex `#RRGGBB` của một token màu — dùng cho MapLibre, vốn nhận màu
/// dưới dạng chuỗi chứ không nhận [Color].
String sfHex(Color color) =>
    '#${(color.toARGB32() & 0xFFFFFF).toRadixString(16).padLeft(6, '0').toUpperCase()}';

/// Thang khoảng cách. Không dùng số ngoài thang này.
class SfSpace {
  const SfSpace._();

  static const double x4 = 4;
  static const double x8 = 8;
  static const double x12 = 12;
  static const double x16 = 16;
  static const double x20 = 20;
  static const double x24 = 24;
  static const double x32 = 32;
  static const double x40 = 40;

  /// Padding ngang chuẩn của màn mobile.
  static const screenH = EdgeInsets.symmetric(horizontal: x16);

  /// Padding đầy đủ của một màn cuộn.
  static const screen = EdgeInsets.fromLTRB(x16, x8, x16, x24);

  /// Ruột thẻ.
  static const card = EdgeInsets.all(x16);
}

/// Bo góc.
class SfRadius {
  const SfRadius._();

  static const double card = 20;
  static const double control = 14; // ô nhập & nút
  static const double pill = 999;
  static const double sheet = 18; // chỉ 2 góc trên
  static const double dock = 26;

  static const cardR = BorderRadius.all(Radius.circular(card));
  static const controlR = BorderRadius.all(Radius.circular(control));
  static const pillR = BorderRadius.all(Radius.circular(pill));
  static const dockR = BorderRadius.all(Radius.circular(dock));
  static const sheetR = BorderRadius.vertical(top: Radius.circular(sheet));
}

/// Đổ bóng — đúng 2 mức, không hơn.
class SfShadow {
  const SfShadow._();

  /// Thẻ: không bóng, chỉ viền 1px.
  static const List<BoxShadow> card = <BoxShadow>[];

  /// Nổi: dock, sheet, dialog.
  static const List<BoxShadow> floating = <BoxShadow>[
    BoxShadow(color: SfColors.shadow, blurRadius: 24, offset: Offset(0, 8)),
  ];
}

/// Vùng chạm và chiều cao điều khiển.
class SfTouch {
  const SfTouch._();

  static const double min = 48;
  static const double drive = 64;
  static const double primaryHeight = 52;
  static const double driveHeight = 64;

  /// Sàn cỡ chữ trong chế độ lái. Không có ngoại lệ.
  static const double driveFontFloor = 18;
}

/// Kiểu chữ.
///
/// Chữ: Be Vietnam Pro (dựng dấu tiếng Việt đúng, đủ 4 độ đậm).
/// Số: cùng font nhưng bật `tabularFigures` để cột số luôn thẳng — tránh phải
/// tải thêm một họ chữ thứ hai, vốn là gánh nặng cho phiên chạy ngoại tuyến.
///
/// Muốn chạy hoàn toàn ngoại tuyến: thả 4 file `.ttf` Be Vietnam Pro vào
/// `assets/google_fonts/`, khai báo thư mục đó trong `pubspec.yaml`; gói
/// google_fonts sẽ ưu tiên bản nhúng và không chạm mạng.
class SfType {
  const SfType._();

  static const _tabular = <FontFeature>[FontFeature.tabularFigures()];

  /// 44 / 700 / 1.05 — số km, tốc độ trong chế độ lái.
  static TextStyle get displayDrive => GoogleFonts.beVietnamPro(
    fontSize: 44,
    fontWeight: FontWeight.w700,
    height: 1.05,
    fontFeatures: _tabular,
  );

  /// 24 / 700 / 1.2 — tiêu đề màn.
  static TextStyle get titleScreen => GoogleFonts.beVietnamPro(
    fontSize: 24,
    fontWeight: FontWeight.w700,
    height: 1.2,
  );

  /// 17 / 600 / 1.3 — tiêu đề thẻ chuyến.
  static TextStyle get titleCard => GoogleFonts.beVietnamPro(
    fontSize: 17,
    fontWeight: FontWeight.w600,
    height: 1.3,
  );

  /// 15 / 400 / 1.5 — nội dung.
  static TextStyle get body => GoogleFonts.beVietnamPro(
    fontSize: 15,
    fontWeight: FontWeight.w400,
    height: 1.5,
  );

  /// 13 / 400 / 1.45 — phụ đề, thời gian.
  static TextStyle get meta => GoogleFonts.beVietnamPro(
    fontSize: 13,
    fontWeight: FontWeight.w400,
    height: 1.45,
  );

  /// 11 / 600 / 1.2, letter-spacing 0.08em, VIẾT HOA — nhãn nhóm, kicker.
  static TextStyle get label => GoogleFonts.beVietnamPro(
    fontSize: 11,
    fontWeight: FontWeight.w600,
    height: 1.2,
    letterSpacing: 0.88, // 0.08em × 11
  );

  /// 13 / 500 tabular — mọi con số.
  static TextStyle get mono => GoogleFonts.beVietnamPro(
    fontSize: 13,
    fontWeight: FontWeight.w500,
    height: 1.3,
    fontFeatures: _tabular,
  );

  /// Bảng chữ đầy đủ cho ThemeData.
  static TextTheme themeText(Color primary, Color secondary) => TextTheme(
    displayLarge: displayDrive.copyWith(color: primary),
    headlineSmall: titleScreen.copyWith(color: primary),
    titleMedium: titleCard.copyWith(color: primary),
    bodyMedium: body.copyWith(color: primary),
    bodySmall: meta.copyWith(color: secondary),
    labelSmall: label.copyWith(color: secondary),
    labelMedium: mono.copyWith(color: primary),
  );
}

/// Bảng màu ngữ nghĩa — widget đọc qua đây để tự đổi theo sáng/tối.
///
/// Dùng: `context.sf.surface`, `context.sf.textSecondary`, …
@immutable
class SfPalette extends ThemeExtension<SfPalette> {
  const SfPalette({
    required this.isDark,
    required this.bg,
    required this.surface,
    required this.surfaceAlt,
    required this.border,
    required this.textPrimary,
    required this.textSecondary,
    required this.textMuted,
    required this.accent,
    required this.accentTint,
    required this.goodTint,
    required this.warnTint,
    required this.dangerTint,
  });

  static const light = SfPalette(
    isDark: false,
    bg: SfColors.bg,
    surface: SfColors.surface,
    surfaceAlt: SfColors.surfaceAlt,
    border: SfColors.border,
    textPrimary: SfColors.textPrimary,
    textSecondary: SfColors.textSecondary,
    textMuted: SfColors.textMuted,
    accent: SfColors.teal,
    accentTint: SfColors.tealTint,
    goodTint: SfColors.successTint,
    warnTint: SfColors.amberTint,
    dangerTint: SfColors.dangerTint,
  );

  /// Trên nền tối dùng `mint` làm màu nhấn — `teal` không đủ tương phản.
  static const dark = SfPalette(
    isDark: true,
    bg: SfColors.darkBg,
    surface: SfColors.darkSurface,
    surfaceAlt: SfColors.darkSurfaceAlt,
    border: SfColors.darkBorder,
    textPrimary: SfColors.darkTextPrimary,
    textSecondary: SfColors.darkTextSecondary,
    textMuted: SfColors.darkTextMuted,
    accent: SfColors.mint,
    accentTint: SfColors.darkSurfaceAlt,
    goodTint: SfColors.darkSurfaceAlt,
    warnTint: SfColors.darkSurfaceAlt,
    dangerTint: SfColors.darkSurfaceAlt,
  );

  final bool isDark;
  final Color bg;
  final Color surface;
  final Color surfaceAlt;
  final Color border;
  final Color textPrimary;
  final Color textSecondary;
  final Color textMuted;
  final Color accent;
  final Color accentTint;
  final Color goodTint;
  final Color warnTint;
  final Color dangerTint;

  /// Màu chữ/icon trên nền màu nhấn.
  Color get onAccent => isDark ? SfColors.darkBg : SfColors.onAccent;

  @override
  SfPalette copyWith({
    bool? isDark,
    Color? bg,
    Color? surface,
    Color? surfaceAlt,
    Color? border,
    Color? textPrimary,
    Color? textSecondary,
    Color? textMuted,
    Color? accent,
    Color? accentTint,
    Color? goodTint,
    Color? warnTint,
    Color? dangerTint,
  }) => SfPalette(
    isDark: isDark ?? this.isDark,
    bg: bg ?? this.bg,
    surface: surface ?? this.surface,
    surfaceAlt: surfaceAlt ?? this.surfaceAlt,
    border: border ?? this.border,
    textPrimary: textPrimary ?? this.textPrimary,
    textSecondary: textSecondary ?? this.textSecondary,
    textMuted: textMuted ?? this.textMuted,
    accent: accent ?? this.accent,
    accentTint: accentTint ?? this.accentTint,
    goodTint: goodTint ?? this.goodTint,
    warnTint: warnTint ?? this.warnTint,
    dangerTint: dangerTint ?? this.dangerTint,
  );

  @override
  SfPalette lerp(ThemeExtension<SfPalette>? other, double t) {
    if (other is! SfPalette) return this;
    return SfPalette(
      isDark: t < 0.5 ? isDark : other.isDark,
      bg: Color.lerp(bg, other.bg, t)!,
      surface: Color.lerp(surface, other.surface, t)!,
      surfaceAlt: Color.lerp(surfaceAlt, other.surfaceAlt, t)!,
      border: Color.lerp(border, other.border, t)!,
      textPrimary: Color.lerp(textPrimary, other.textPrimary, t)!,
      textSecondary: Color.lerp(textSecondary, other.textSecondary, t)!,
      textMuted: Color.lerp(textMuted, other.textMuted, t)!,
      accent: Color.lerp(accent, other.accent, t)!,
      accentTint: Color.lerp(accentTint, other.accentTint, t)!,
      goodTint: Color.lerp(goodTint, other.goodTint, t)!,
      warnTint: Color.lerp(warnTint, other.warnTint, t)!,
      dangerTint: Color.lerp(dangerTint, other.dangerTint, t)!,
    );
  }
}

extension SfPaletteContext on BuildContext {
  /// Bảng màu ngữ nghĩa của theme đang áp dụng tại vị trí này trong cây widget.
  SfPalette get sf =>
      Theme.of(this).extension<SfPalette>() ??
      (Theme.of(this).brightness == Brightness.dark
          ? SfPalette.dark
          : SfPalette.light);
}
