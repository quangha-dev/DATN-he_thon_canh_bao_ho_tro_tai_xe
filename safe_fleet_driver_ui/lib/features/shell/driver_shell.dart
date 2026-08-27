import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app.dart';
import '../../core/ai/cabin_safety_provider.dart';
import '../../core/ai/temporal_safety_engine.dart';
import '../../core/agent/agent_conversation_provider.dart';
import '../../core/location/vehicle_location_tracker.dart';
import '../../core/widgets/ui.dart';
import '../agent/agent_chat_screen.dart';
import '../home/home_screen.dart';
import '../insights/monthly_insights_screen.dart';
import '../navigation/route_planner_screen.dart';
import '../profile/profile_screen.dart';

class DriverShell extends ConsumerStatefulWidget {
  const DriverShell({super.key});

  @override
  ConsumerState<DriverShell> createState() => _DriverShellState();
}

class _DriverShellState extends ConsumerState<DriverShell>
    with SingleTickerProviderStateMixin {
  int _index = 0;
  final Set<int> _loadedPages = {0};
  late final VehicleLocationTracker _locationTracker;

  /// Cảnh báo an toàn đang hiển thị. `null` = cấp 0, không có gì phải báo.
  SafetyDetection? _alert;
  Timer? _criticalBuzz;

  late final AnimationController _tabAnimation = AnimationController(
    vsync: this,
    duration: SfMotion.dTab,
    value: 1,
  );

  @override
  void initState() {
    super.initState();
    _locationTracker = VehicleLocationTracker(
      ref.read(driverRepositoryProvider),
      ref.read(syncQueueProvider),
    );
    unawaited(_locationTracker.start());
    // Trợ lý phải gọi được ngay khi mở app, không đợi vào chuyến. Lựa chọn của
    // tài xế được nhớ lại giữa các lần mở máy.
    unawaited(
      ref.read(agentConversationProvider.notifier).restoreWakePreference(),
    );
  }

  @override
  void dispose() {
    _criticalBuzz?.cancel();
    _tabAnimation.dispose();
    unawaited(_locationTracker.stop());
    super.dispose();
  }

  Widget _page(int index) => switch (index) {
    0 => const HomeScreen(),
    1 => const RoutePlannerScreen(),
    // Trợ lý là tab: nút đóng quay về Nhà chứ không pop navigator.
    2 => AgentChatScreen(onClose: () => _selectPage(0)),
    3 => const MonthlyInsightsScreen(),
    _ => const ProfileScreen(),
  };

  void _selectPage(int value) {
    if (_index == value) return;
    setState(() {
      _index = value;
      _loadedPages.add(value);
    });
    _tabAnimation
      ..duration = SfMotion.of(context, SfMotion.dTab)
      ..forward(from: 0);
  }

  // ---- Cảnh báo an toàn ----

  bool get _isCritical => _alert?.severity == 'CRITICAL';

  void _raiseAlert(SafetyDetection detection) {
    _criticalBuzz?.cancel();
    setState(() => _alert = detection);

    if (detection.severity == 'CRITICAL') {
      // Rung liên tục cho tới khi tài xế xác nhận.
      HapticFeedback.heavyImpact();
      _criticalBuzz = Timer.periodic(
        const Duration(milliseconds: 900),
        (_) => HapticFeedback.heavyImpact(),
      );
    } else {
      HapticFeedback.mediumImpact();
    }
  }

  void _clearAlert() {
    _criticalBuzz?.cancel();
    _criticalBuzz = null;
    if (_alert != null) setState(() => _alert = null);
  }

  String _alertTitle(SafetyDetection detection) =>
      switch ((detection.severity, detection.apiEventType)) {
        ('CRITICAL', _) => 'Dừng xe ngay',
        (_, 'PHONE_USAGE') => 'Mất tập trung',
        _ => 'Có dấu hiệu buồn ngủ',
      };

  String _alertMessage(SafetyDetection detection) {
    final reason = detection.reason.trim();
    if (detection.severity == 'CRITICAL') {
      return '${reason.isEmpty ? 'Mức buồn ngủ vượt ngưỡng an toàn.' : reason}\n'
          'Đã báo tổng đài. Tấp vào lề, tắt máy, nghỉ ít nhất 15 phút.';
    }
    return reason.isEmpty
        ? 'Tìm chỗ dừng an toàn trong 10 phút tới.'
        : '$reason\nTìm chỗ dừng an toàn trong 10 phút tới.';
  }

  /// Engine nào đang chạy — tài xế và điều hành viên đều cần biết.
  String _alertSource(SafetyDetection detection, CabinSafetyState cabin) =>
      '${cabin.modelMode.label} · ${detection.source}';

  @override
  Widget build(BuildContext context) {
    ref.listen(cabinSafetyProvider.select((value) => value.lastDetection), (
      previous,
      next,
    ) {
      if (next == null || identical(previous, next)) return;
      _raiseAlert(next);
    });

    final cabin = ref.watch(cabinSafetyProvider);
    final agent = ref.watch(agentConversationProvider);
    final alert = _alert;

    return Scaffold(
      extendBody: true,
      body: Stack(
        children: [
          AnimatedBuilder(
            animation: _tabAnimation,
            builder: (context, child) {
              final t = Curves.easeOut.transform(_tabAnimation.value);
              return Opacity(
                opacity: t,
                child: Transform.translate(
                  offset: Offset(0, 10 * (1 - t)),
                  child: child,
                ),
              );
            },
            child: IndexedStack(
              index: _index,
              children: List.generate(
                5,
                (index) => _loadedPages.contains(index)
                    ? _page(index)
                    : const SizedBox.shrink(),
              ),
            ),
          ),
          if (agent.engaged && _index != 2)
            Positioned.fill(
              child: _VoiceOverlay(
                state: agent,
                showConversation: _index == 0,
                onClose: () => ref
                    .read(agentConversationProvider.notifier)
                    .dismissOverlay(),
                onOpenAgent: () => _selectPage(2),
              ),
            ),

          // Cảnh báo cấp 1: banner trên đỉnh, vẫn dùng app được.
          if (alert != null && !_isCritical)
            Positioned(
              top: MediaQuery.paddingOf(context).top + SfSpace.x8,
              left: SfSpace.x16,
              right: SfSpace.x16,
              child: SfAlertBanner(
                level: SfAlertLevel.caution,
                title: _alertTitle(alert),
                message: _alertMessage(alert),
                source: _alertSource(alert, cabin),
                primaryLabel: 'Tìm điểm dừng an toàn',
                onPrimary: () {
                  _clearAlert();
                  _selectPage(1);
                },
                onDismiss: _clearAlert,
              ),
            ),

          // Cảnh báo cấp 2: tràn màn hình, không có nút bỏ qua.
          if (alert != null && _isCritical)
            Positioned.fill(
              child: SfCriticalAlertOverlay(
                title: _alertTitle(alert),
                message: _alertMessage(alert),
                source: _alertSource(alert, cabin),
                actionLabel: 'Tôi sẽ nghỉ ngay',
                onAction: _clearAlert,
              ),
            ),
        ],
      ),
      // Dock ẩn khi có cảnh báo cấp 2 và khi đang ở màn Trợ lý (nền tối).
      bottomNavigationBar: _isCritical || _index == 2
          ? null
          : SafeArea(
              minimum: const EdgeInsets.fromLTRB(
                SfSpace.x12,
                0,
                SfSpace.x12,
                SfSpace.x10,
              ),
              child: _FloatingDock(index: _index, onSelected: _selectPage),
            ),
    );
  }
}

class _VoiceOverlay extends StatelessWidget {
  const _VoiceOverlay({
    required this.state,
    required this.showConversation,
    required this.onClose,
    required this.onOpenAgent,
  });

  final AgentConversationState state;
  final bool showConversation;
  final VoidCallback onClose;
  final VoidCallback onOpenAgent;

  @override
  Widget build(BuildContext context) {
    final recent = state.messages.length > 2
        ? state.messages.sublist(state.messages.length - 2)
        : state.messages;
    return Material(
      color: SfColors.scrim,
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            SfSpace.x20,
            SfSpace.x12,
            SfSpace.x20,
            SfSpace.x40 + SfSpace.x40,
          ),
          child: Column(
            children: [
              Align(
                alignment: Alignment.topRight,
                child: IconButton(
                  onPressed: onClose,
                  color: SfColors.darkTextPrimary,
                  icon: const Icon(Icons.close),
                ),
              ),
              const Spacer(),
              Text(
                'SafeFleet đang lắng nghe',
                style: SfType.titleSub.copyWith(
                  color: SfColors.darkTextPrimary,
                ),
              ),
              const SizedBox(height: SfSpace.x20),
              const SfWaveform(bars: 9, height: 42, barWidth: 5),
              const SizedBox(height: SfSpace.x20),
              Text(
                state.transcript.isEmpty
                    ? 'Bạn cần tôi hỗ trợ điều gì?'
                    : '“${state.transcript}”',
                textAlign: TextAlign.center,
                style: SfType.body.copyWith(
                  color: SfColors.darkTextSecondary,
                  fontSize: SfTouch.driveFontFloor,
                ),
              ),
              if (showConversation) ...[
                const SizedBox(height: SfSpace.x20),
                ...recent.map(
                  (message) => Padding(
                    padding: const EdgeInsets.only(bottom: SfSpace.x8),
                    child: Text(
                      '${message.role == 'user' ? 'Bạn' : 'Agent'}: ${message.content}',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                      style: SfType.body.copyWith(
                        color: SfColors.darkTextPrimary,
                      ),
                    ),
                  ),
                ),
              ],
              const SizedBox(height: SfSpace.x20),
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  foregroundColor: SfColors.darkTextPrimary,
                  side: const BorderSide(color: SfColors.darkBorder),
                  shape: const RoundedRectangleBorder(
                    borderRadius: SfRadius.controlR,
                  ),
                ),
                onPressed: onOpenAgent,
                icon: const Icon(Icons.forum_outlined),
                label: const Text('Mở cuộc trò chuyện'),
              ),
              const Spacer(),
            ],
          ),
        ),
      ),
    );
  }
}

/// Dock nổi: cao 74, bo 26, kính mờ 12px, gạch chỉ báo 28×3 trượt.
///
/// 5 ô: NHÀ · BẢN ĐỒ · nút mic tròn 50px ở giữa · THÁNG · HỒ SƠ.
class _FloatingDock extends StatelessWidget {
  const _FloatingDock({required this.index, required this.onSelected});

  static const _count = 5;

  final int index;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    final p = context.sf;
    return DecoratedBox(
      decoration: const BoxDecoration(
        borderRadius: SfRadius.dockR,
        boxShadow: SfShadow.dock,
      ),
      child: SfBlur(
        child: Material(
          color: p.surface.withValues(alpha: 0.92),
          child: SizedBox(
            height: SfTouch.dock,
            child: LayoutBuilder(
              builder: (context, constraints) {
                final slot = constraints.maxWidth / _count;
                return Stack(
                  children: [
                    // Gạch chỉ báo trượt ngang tới tab đang chọn.
                    AnimatedPositioned(
                      duration: SfMotion.of(
                        context,
                        const Duration(milliseconds: 280),
                      ),
                      curve: SfMotion.curveOf(
                        context,
                        const Cubic(0.2, 0, 0, 1),
                      ),
                      left: slot * index + (slot - 28) / 2,
                      top: 0,
                      child: Container(
                        width: 28,
                        height: 3,
                        decoration: const BoxDecoration(
                          color: SfColors.green700,
                          borderRadius: SfRadius.pillR,
                        ),
                      ),
                    ),
                    Row(
                      children: [
                        _item(context, 0, Icons.home_rounded, 'NHÀ'),
                        _item(context, 1, Icons.map_rounded, 'BẢN ĐỒ'),
                        _agentItem(context),
                        _item(context, 3, Icons.bar_chart_rounded, 'THÁNG'),
                        _item(context, 4, Icons.person_rounded, 'HỒ SƠ'),
                      ],
                    ),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  Widget _item(
    BuildContext context,
    int value,
    IconData icon,
    String label,
  ) {
    final selected = index == value;
    final ink = selected ? SfColors.green700 : SfColors.textDisabled;
    return Expanded(
      child: InkWell(
        onTap: () => onSelected(value),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            TweenAnimationBuilder<Color?>(
              tween: ColorTween(end: ink),
              duration: SfMotion.of(
                context,
                const Duration(milliseconds: 180),
              ),
              curve: SfMotion.curveOf(context, SfMotion.standard),
              builder: (context, color, _) =>
                  Icon(icon, size: 23, color: color ?? ink),
            ),
            const SizedBox(height: 5),
            Text(label, style: SfType.tabLabel.copyWith(color: ink)),
          ],
        ),
      ),
    );
  }

  Widget _agentItem(BuildContext context) => Expanded(
    child: InkWell(
      onTap: () => onSelected(2),
      child: Center(
        child: Container(
          width: SfTouch.micDock,
          height: SfTouch.micDock,
          decoration: const BoxDecoration(
            gradient: SfGradients.mic,
            shape: BoxShape.circle,
            boxShadow: SfShadow.card,
          ),
          child: const Icon(
            Icons.mic_rounded,
            size: 24,
            color: SfColors.onAccent,
          ),
        ),
      ),
    ),
  );
}
