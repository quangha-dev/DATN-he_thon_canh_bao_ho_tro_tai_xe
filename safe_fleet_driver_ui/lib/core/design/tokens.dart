import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Nguồn chân lý duy nhất cho màu, chữ, khoảng cách, bo góc, đổ bóng.
///
/// Bảng màu chủ đạo xanh lá / trắng theo bản thiết kế
/// `Design/Mobile app driver interface` — dịu mắt nhưng tương phản rõ khi
/// nhìn lướt lúc đang lái.
///
/// Quy ước: KHÔNG khai báo `Color(0x...)` hay dựng `TextStyle(...)` từ đầu ở
/// bất kỳ file nào khác. Mọi màn dùng token ở đây, hoặc `.copyWith()` từ token.
class SfColors {
  const SfColors._();

  // ---- Thương hiệu: xanh lá ----
  /// Màu thương hiệu chính: nút chính, icon, nhấn mạnh.
  static const green700 = Color(0xFF0B7A52);

  /// Cuối gradient, trạng thái nhấn.
  static const green800 = Color(0xFF07553A);

  /// Giữa gradient thẻ chuyến.
  static const green600 = Color(0xFF0A6647);

  /// Điểm nhấn trên nền xanh đậm.
  static const green300 = Color(0xFF7BE8B8);

  /// Nhấn trên nền tối (chế độ lái, trợ lý).
  static const green400 = Color(0xFF3FD69A);

  /// Nền icon nhạt.
  static const green100 = Color(0xFFE4F3EA);

  /// Nền thẻ được chọn / khối thông tin.
  static const green050 = Color(0xFFF2F9F5);

  // ---- Trạng thái ----
  static const warning = Color(0xFFB4740A);
  static const warningBg = Color(0xFFFDF5E7);
  static const warningBorder = Color(0xFFF0DDBA);
  static const warningInk = Color(0xFF6B4605);

  static const danger = Color(0xFFB4271C);
  static const dangerStrong = Color(0xFF8E1E15);
  static const dangerDeep = Color(0xFF6E140D);
  static const dangerBg = Color(0xFFFDEDEA);
  static const dangerBorder = Color(0xFFF2CFC9);
  static const dangerSoft = Color(0xFFE0674F);

  static const info = Color(0xFF2E6BAA);
  static const infoLight = Color(0xFF5FA0D8);
  static const infoBg = Color(0xFFE9F1FB);

  /// Nhãn "rủi ro cao" trên nền xanh.
  static const amber = Color(0xFFF5C24A);

  /// Chữ trên nền [amber].
  static const amberInk = Color(0xFF3A2705);

  // ---- Chế độ sáng ----
  static const surface = Color(0xFFFFFFFF);
  static const bg = Color(0xFFF2F7F3);
  static const border = Color(0xFFE1EBE4);
  static const borderStrong = Color(0xFFC9E3D5);
  static const borderChecked = Color(0xFFBEE0CD);
  static const divider = Color(0xFFEDF3EE);
  static const dividerStrong = Color(0xFFDCE7DF);
  static const fieldBg = Color(0xFFF7FBF8);

  static const textPrimary = Color(0xFF0F2119);
  static const textSecondary = Color(0xFF3D4E45);
  static const textSecondaryAlt = Color(0xFF5A6F64);
  static const textTertiary = Color(0xFF93A69B);
  static const textDisabled = Color(0xFF8A9C92);

  // ---- Chế độ tối (bảng riêng, không phải màu đảo ngược tự động) ----
  static const darkBg = Color(0xFF0B1512);
  static const darkSurface = Color(0xFF14231D);
  static const darkSurface2 = Color(0xFF101C18);
  static const darkSurface3 = Color(0xFF1E332B);
  static const darkSurface4 = Color(0xFF243B32);
  static const darkBorder = Color(0xFF22362E);
  static const darkTextPrimary = Color(0xFFFFFFFF);
  static const darkTextSecondary = Color(0xFFE6EFE9);
  static const darkTextMuted = Color(0xFF9CB3A7);
  static const darkTextFaint = Color(0xFF7E9389);
  static const darkTextGhost = Color(0xFF5F7469);

  /// Nền màn xem ảnh hiện trường.
  static const photoBg = Color(0xFF0B0F0D);

  // ---- Dùng chung ----
  static const onAccent = Color(0xFFFFFFFF);
  static const onDanger = Color(0xFFFFFFFF);
  static const scrim = Color(0xD90B1512);

  /// Lớp phủ cảnh báo buồn ngủ — phủ kín màn.
  static const drowsyScrim = Color(0xF078120C);
}

/// Gradient dùng lại nhiều lần trong thiết kế.
class SfGradients {
  const SfGradients._();

  /// Thẻ chuyến đang chạy — `linear-gradient(140deg, …)`.
  static const heroTrip = LinearGradient(
    begin: Alignment(-0.82, -1),
    end: Alignment(0.82, 1),
    colors: [SfColors.green700, SfColors.green600, SfColors.green800],
    stops: [0, 0.55, 1],
  );

  /// Header màn con — `linear-gradient(150deg, …)`.
  static const header = LinearGradient(
    begin: Alignment(-0.9, -1),
    end: Alignment(0.9, 1),
    colors: [SfColors.green700, SfColors.green800],
  );

  /// Nút mic / trợ lý — `linear-gradient(135deg, …)`.
  static const mic = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [SfColors.green700, SfColors.green400],
  );

  /// Nền màn SOS.
  static const sos = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [SfColors.dangerStrong, SfColors.dangerDeep],
  );

  /// Thanh tiến độ trên thẻ hero.
  static const progressOnHero = LinearGradient(
    colors: [SfColors.green300, SfColors.onAccent],
  );
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
  static const double x10 = 10;
  static const double x12 = 12;
  static const double x14 = 14;
  static const double x16 = 16;
  static const double x18 = 18;
  static const double x20 = 20;
  static const double x24 = 24;
  static const double x32 = 32;
  static const double x40 = 40;

  /// Chừa chỗ cho dock nổi ở đáy màn tab.
  static const double dockGap = 108;

  /// Padding ngang chuẩn của màn mobile.
  static const screenH = EdgeInsets.symmetric(horizontal: x16);

  /// Padding đầy đủ của một màn cuộn có dock.
  static const screen = EdgeInsets.fromLTRB(x16, x8, x16, dockGap);

  /// Padding màn con (không có dock).
  static const screenSub = EdgeInsets.fromLTRB(x16, x16, x16, x24);

  /// Ruột thẻ.
  static const card = EdgeInsets.all(x16);
}

/// Bo góc.
class SfRadius {
  const SfRadius._();

  static const double dock = 26;
  static const double hero = 24;
  static const double sheet = 24;
  static const double card = 20;
  static const double cardSm = 18;
  static const double control = 14;
  static const double controlLg = 17;
  static const double iconBtn = 13;
  static const double pill = 999;

  static const dockR = BorderRadius.all(Radius.circular(dock));
  static const heroR = BorderRadius.all(Radius.circular(hero));
  static const cardR = BorderRadius.all(Radius.circular(card));
  static const cardSmR = BorderRadius.all(Radius.circular(cardSm));
  static const controlR = BorderRadius.all(Radius.circular(control));
  static const controlLgR = BorderRadius.all(Radius.circular(controlLg));
  static const iconBtnR = BorderRadius.all(Radius.circular(iconBtn));
  static const pillR = BorderRadius.all(Radius.circular(pill));
  static const sheetR = BorderRadius.vertical(top: Radius.circular(sheet));
}

/// Đổ bóng.
class SfShadow {
  const SfShadow._();

  /// Thẻ thường.
  static const List<BoxShadow> card = <BoxShadow>[
    BoxShadow(
      color: Color(0x1A0B7A52),
      blurRadius: 24,
      offset: Offset(0, 10),
    ),
  ];

  /// Thẻ hero gradient.
  static const List<BoxShadow> hero = <BoxShadow>[
    BoxShadow(
      color: Color(0x380A5A3E),
      blurRadius: 34,
      offset: Offset(0, 16),
    ),
  ];

  /// Dock nổi.
  static const List<BoxShadow> dock = <BoxShadow>[
    BoxShadow(
      color: Color(0x290C3223),
      blurRadius: 34,
      offset: Offset(0, 14),
    ),
  ];

  /// Bottom sheet trên nền tối.
  static const List<BoxShadow> sheetDark = <BoxShadow>[
    BoxShadow(
      color: Color(0x80000000),
      blurRadius: 34,
      offset: Offset(0, -10),
    ),
  ];

  /// Nổi chung — dialog, nút hành động.
  static const List<BoxShadow> floating = card;
}

/// Vùng chạm và chiều cao điều khiển. Không mục chạm nào dưới 44px.
class SfTouch {
  const SfTouch._();

  static const double min = 44;

  /// Nút chính.
  static const double primaryHeight = 56;

  /// Nút chính cỡ lớn.
  static const double primaryHeightLg = 58;

  /// Nút icon vuông trên header.
  static const double iconBtn = 42;

  /// Nút icon lớn (bản đồ, trợ lý).
  static const double iconBtnLg = 46;

  /// Nút trong chế độ lái.
  static const double drive = 64;
  static const double driveHeight = 64;

  /// Nút mic của trợ lý.
  static const double mic = 88;

  /// Nút mic giữa dock.
  static const double micDock = 50;

  /// Chiều cao dock nổi.
  static const double dock = 74;

  /// Dòng danh sách.
  static const double row = 56;

  /// Sàn cỡ chữ trong chế độ lái. Không có ngoại lệ.
  static const double driveFontFloor = 18;
}

/// Kiểu chữ.
///
/// Chữ: Be Vietnam Pro (dựng dấu tiếng Việt đúng, đủ 4 độ đậm).
/// Mọi con số (giờ, km, điểm, toạ độ) bật `tabularFigures` để cột số thẳng.
///
/// Muốn chạy hoàn toàn ngoại tuyến: thả 4 file `.ttf` Be Vietnam Pro vào
/// `assets/google_fonts/`, khai báo thư mục đó trong `pubspec.yaml`; gói
/// google_fonts sẽ ưu tiên bản nhúng và không chạm mạng.
class SfType {
  const SfType._();

  static const _tabular = <FontFeature>[FontFeature.tabularFigures()];

  /// 34 / 700 / 1.0 tabular — chỉ dẫn "400 m", tiêu đề lớp phủ cảnh báo.
  static TextStyle get displayDrive => GoogleFonts.beVietnamPro(
    fontSize: 34,
    fontWeight: FontWeight.w700,
    height: 1,
    fontFeatures: _tabular,
  );

  /// 25 / 700 / 1.1 tabular — số liệu lớn trong thẻ.
  static TextStyle get statLarge => GoogleFonts.beVietnamPro(
    fontSize: 25,
    fontWeight: FontWeight.w700,
    height: 1.1,
    fontFeatures: _tabular,
  );

  /// 20 / 700 / 1.1 tabular — số liệu thẻ.
  static TextStyle get stat => GoogleFonts.beVietnamPro(
    fontSize: 20,
    fontWeight: FontWeight.w700,
    height: 1.1,
    fontFeatures: _tabular,
  );

  /// 21 / 700 / 1.2 — tiêu đề màn tab.
  static TextStyle get titleScreen => GoogleFonts.beVietnamPro(
    fontSize: 21,
    fontWeight: FontWeight.w700,
    height: 1.2,
  );

  /// 19 / 700 / 1.2 — tiêu đề màn con.
  static TextStyle get titleSub => GoogleFonts.beVietnamPro(
    fontSize: 19,
    fontWeight: FontWeight.w700,
    height: 1.2,
  );

  /// 17 / 600 / 1.25 — tiêu đề thẻ lớn.
  static TextStyle get titleCard => GoogleFonts.beVietnamPro(
    fontSize: 17,
    fontWeight: FontWeight.w600,
    height: 1.25,
  );

  /// 15 / 600 / 1.3 — tiêu đề thẻ nhỏ.
  static TextStyle get titleCardSm => GoogleFonts.beVietnamPro(
    fontSize: 15,
    fontWeight: FontWeight.w600,
    height: 1.3,
  );

  /// 14.5 / 600 / 1.3 — tiêu đề dòng danh sách.
  static TextStyle get titleRow => GoogleFonts.beVietnamPro(
    fontSize: 14.5,
    fontWeight: FontWeight.w600,
    height: 1.3,
  );

  /// 14.5 / 400 / 1.55 — nội dung.
  static TextStyle get body => GoogleFonts.beVietnamPro(
    fontSize: 14.5,
    fontWeight: FontWeight.w400,
    height: 1.55,
  );

  /// 14 / 400 / 1.5 — nội dung dày.
  static TextStyle get bodySm => GoogleFonts.beVietnamPro(
    fontSize: 14,
    fontWeight: FontWeight.w400,
    height: 1.5,
  );

  /// 12.5 / 400 / 1.45 — phụ đề, thời gian.
  static TextStyle get meta => GoogleFonts.beVietnamPro(
    fontSize: 12.5,
    fontWeight: FontWeight.w400,
    height: 1.45,
  );

  /// 11.5 / 400 / 1.4 — chú thích.
  static TextStyle get caption => GoogleFonts.beVietnamPro(
    fontSize: 11.5,
    fontWeight: FontWeight.w400,
    height: 1.4,
  );

  /// 11 / 600, letter-spacing .08em, VIẾT HOA — nhãn nhóm.
  static TextStyle get label => GoogleFonts.beVietnamPro(
    fontSize: 11,
    fontWeight: FontWeight.w600,
    height: 1.2,
    letterSpacing: 0.88, // .08em × 11
  );

  /// 10.5 / 600, letter-spacing .06em, VIẾT HOA — chip trạng thái.
  static TextStyle get chip => GoogleFonts.beVietnamPro(
    fontSize: 10.5,
    fontWeight: FontWeight.w600,
    height: 1.2,
    letterSpacing: 0.63, // .06em × 10.5
  );

  /// 10 / 600, letter-spacing .06em — nhãn tab dock.
  static TextStyle get tabLabel => GoogleFonts.beVietnamPro(
    fontSize: 10,
    fontWeight: FontWeight.w600,
    height: 1.2,
    letterSpacing: 0.6,
  );

  /// 13 / 500 tabular — con số trong dòng chữ.
  static TextStyle get mono => GoogleFonts.beVietnamPro(
    fontSize: 13,
    fontWeight: FontWeight.w500,
    height: 1.3,
    fontFeatures: _tabular,
  );

  /// Bảng chữ đầy đủ cho ThemeData.
  static TextTheme themeText(Color primary, Color secondary) => TextTheme(
    displayLarge: displayDrive.copyWith(color: primary),
    headlineMedium: titleScreen.copyWith(color: primary),
    headlineSmall: titleSub.copyWith(color: primary),
    titleLarge: titleCard.copyWith(color: primary),
    titleMedium: titleCardSm.copyWith(color: primary),
    titleSmall: titleRow.copyWith(color: primary),
    bodyLarge: body.copyWith(color: primary),
    bodyMedium: bodySm.copyWith(color: primary),
    bodySmall: meta.copyWith(color: secondary),
    labelLarge: titleCardSm.copyWith(color: primary),
    labelMedium: mono.copyWith(color: primary),
    labelSmall: label.copyWith(color: secondary),
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
    required this.borderStrong,
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
    surfaceAlt: SfColors.green050,
    border: SfColors.border,
    borderStrong: SfColors.borderStrong,
    textPrimary: SfColors.textPrimary,
    textSecondary: SfColors.textSecondaryAlt,
    textMuted: SfColors.textTertiary,
    accent: SfColors.green700,
    accentTint: SfColors.green100,
    goodTint: SfColors.green050,
    warnTint: SfColors.warningBg,
    dangerTint: SfColors.dangerBg,
  );

  /// Trên nền tối dùng `green400` làm màu nhấn — `green700` không đủ tương phản.
  static const dark = SfPalette(
    isDark: true,
    bg: SfColors.darkBg,
    surface: SfColors.darkSurface,
    surfaceAlt: SfColors.darkSurface2,
    border: SfColors.darkBorder,
    borderStrong: SfColors.darkSurface4,
    textPrimary: SfColors.darkTextPrimary,
    textSecondary: SfColors.darkTextMuted,
    textMuted: SfColors.darkTextFaint,
    accent: SfColors.green400,
    accentTint: SfColors.darkSurface3,
    goodTint: SfColors.darkSurface3,
    warnTint: SfColors.darkSurface3,
    dangerTint: SfColors.darkSurface3,
  );

  final bool isDark;
  final Color bg;
  final Color surface;
  final Color surfaceAlt;
  final Color border;
  final Color borderStrong;
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
    Color? borderStrong,
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
    borderStrong: borderStrong ?? this.borderStrong,
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
      borderStrong: Color.lerp(borderStrong, other.borderStrong, t)!,
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
