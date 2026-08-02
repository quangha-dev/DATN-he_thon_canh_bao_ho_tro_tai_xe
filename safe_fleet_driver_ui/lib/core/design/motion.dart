import 'package:flutter/material.dart';

/// Đặc tả chuyển cảnh.
///
/// Nguyên tắc: chuyển động giải thích không gian, không trang trí. Nếu một
/// animation không cho biết "vật này đến từ đâu / đi về đâu" thì bỏ nó.
class SfMotion {
  const SfMotion._();

  /// Vào chỗ, giảm tốc.
  static const standard = Cubic(0.20, 0.85, 0.25, 1.00);

  /// Rời đi, tăng tốc.
  static const exit = Cubic(0.40, 0.00, 1.00, 1.00);

  /// Nảy nhẹ — chỉ dùng cho xác nhận.
  static const emphasis = Cubic(0.30, 1.30, 0.40, 1.00);

  static const dTab = Duration(milliseconds: 220);
  static const dPush = Duration(milliseconds: 280);
  static const dMorph = Duration(milliseconds: 340);
  static const dDrive = Duration(milliseconds: 380);
  static const dSheet = Duration(milliseconds: 300);
  static const dPress = Duration(milliseconds: 90);
  static const dToggle = Duration(milliseconds: 200);
  static const dSkeleton = Duration(milliseconds: 1400);

  /// Cảnh báo an toàn: cắt vào, linear, không easing mềm.
  static const dAlert = Duration(milliseconds: 120);

  static const stagger = Duration(milliseconds: 45);

  /// Thời lượng khi người dùng bật "giảm chuyển động".
  static const dReduced = Duration(milliseconds: 100);

  /// Thời lượng thực tế, tôn trọng cài đặt giảm chuyển động của hệ thống.
  ///
  /// Cảnh báo an toàn KHÔNG đi qua hàm này — nó luôn chạy.
  static Duration of(BuildContext context, Duration duration) =>
      MediaQuery.disableAnimationsOf(context) ? dReduced : duration;

  /// Đường cong thực tế; khi giảm chuyển động thì rút về cross-fade tuyến tính.
  static Curve curveOf(BuildContext context, Curve curve) =>
      MediaQuery.disableAnimationsOf(context) ? Curves.linear : curve;

  /// Độ trễ so le giữa các dòng nội dung, tắt khi giảm chuyển động.
  static Duration staggerOf(BuildContext context, int index) =>
      MediaQuery.disableAnimationsOf(context)
      ? Duration.zero
      : stagger * index;
}
