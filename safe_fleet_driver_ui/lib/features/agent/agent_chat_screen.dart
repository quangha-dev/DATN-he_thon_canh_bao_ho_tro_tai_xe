import 'package:flutter/material.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app.dart';
import '../../core/agent/agent_conversation_provider.dart';
import '../../core/widgets/ui.dart';
import '../../models/driver_models.dart';
import '../documents/driving_log_list_screen.dart';
import '../insights/monthly_insights_screen.dart';
import '../navigation/route_planner_screen.dart';
import '../notifications/notifications_screen.dart';
import '../safety/safety_summary_screen.dart';
import '../trips/trip_detail_screen.dart';
import '../trips/trips_today_screen.dart';
import 'agent_voice_sheet.dart';

class AgentChatScreen extends ConsumerStatefulWidget {
  const AgentChatScreen({super.key, this.onClose});

  /// Trợ lý là một tab trong shell chứ không phải màn được push, nên nút đóng
  /// phải quay về tab trước chứ không pop navigator. Khi màn được mở bằng
  /// `Navigator.push` thì để `null` và nút sẽ pop như bình thường.
  final VoidCallback? onClose;

  @override
  ConsumerState<AgentChatScreen> createState() => _AgentChatScreenState();
}

class _AgentChatScreenState extends ConsumerState<AgentChatScreen> {
  final _text = TextEditingController();
  final _scroll = ScrollController();

  /// Bàn phím thay cho sóng âm. Giọng nói là kênh chính khi đang lái, gõ chữ
  /// chỉ là lối thoát khi xe đã dừng hoặc nơi quá ồn.
  bool _typing = false;

  @override
  void dispose() {
    _text.dispose();
    _scroll.dispose();
    super.dispose();
  }

  void _send() {
    final value = _text.text.trim();
    if (value.isEmpty) return;
    _text.clear();
    ref.read(agentConversationProvider.notifier).send(value);
  }

  Future<void> _handleClientActions(List<Map<String, dynamic>> actions) async {
    if (actions.isEmpty || !mounted) return;
    ref.read(agentConversationProvider.notifier).consumeClientActions();
    for (final action in actions) {
      if (!mounted) continue;
      if (action['type'] == 'START_NAVIGATION') {
        final lat = (action['destinationLat'] as num?)?.toDouble();
        final lng = (action['destinationLng'] as num?)?.toDouble();
        if (lat != null && lng != null) {
          final destination = LocationPoint(
            name: action['destinationName']?.toString() ?? 'Điểm đến',
            address: action['destinationAddress']?.toString() ?? '',
            lat: lat,
            lng: lng,
            source: 'AGENT_MCP',
          );
          await Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (_) => RoutePlannerScreen(
                initialDestination: destination,
                autoStart: action['autoStart'] == true,
              ),
            ),
          );
        }
        continue;
      }
      if (action['type'] != 'NAVIGATE') continue;
      final destination = action['destination']?.toString();
      Widget? screen;
      switch (destination) {
        case 'DOCUMENT_SCAN':
          screen = const DrivingLogListScreen();
        case 'TRIPS':
          screen = const TripsTodayScreen();
        case 'TRIP_DETAIL':
          final id = (action['tripId'] as num?)?.toInt();
          if (id != null) screen = TripDetailScreen(tripId: id);
        case 'ROUTE':
          screen = const RoutePlannerScreen();
        case 'MONTHLY_REPORT':
          screen = const MonthlyInsightsScreen();
        case 'NOTIFICATIONS':
          screen = const NotificationsScreen();
        case 'SAFETY':
          final data = await ref.read(driverRepositoryProvider).bootstrap();
          screen = SafetySummaryScreen(data: data);
        case 'HOME':
          Navigator.of(context).popUntil((route) => route.isFirst);
      }
      if (screen != null && mounted) {
        await Navigator.of(
          context,
        ).push(MaterialPageRoute<void>(builder: (_) => screen!));
      }
    }
  }

  /// Chip gợi ý câu — bấm là gửi luôn, không phải gõ.
  static const _suggestions = <String>[
    'Báo ngập tại đây',
    'Nghỉ 15 phút',
    'Gọi điều hành',
  ];

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(agentConversationProvider);
    ref.listen(
      agentConversationProvider.select((value) => value.messages.length),
      (_, next) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (_scroll.hasClients) {
            _scroll.animateTo(
              _scroll.position.maxScrollExtent,
              duration: SfMotion.of(context, SfMotion.dTab),
              curve: SfMotion.curveOf(context, SfMotion.standard),
            );
          }
        });
      },
    );
    ref.listen(
      agentConversationProvider.select((value) => value.clientActions),
      (_, actions) {
        if (actions.isEmpty) return;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _handleClientActions(actions);
        });
      },
    );

    // Màn trợ lý luôn nền tối, kể cả khi phần còn lại của app đang sáng.
    return SfTheme.darkWrap(
      child: Scaffold(
        backgroundColor: SfColors.darkBg,
        body: SafeArea(
          child: Column(
            children: [
              _header(state),
              Expanded(child: _conversation(state)),
              if (state.confirmationRequest != null)
                _ConfirmationCard(
                  request: state.confirmationRequest!,
                  busy: state.busy,
                  onConfirm: () => ref
                      .read(agentConversationProvider.notifier)
                      .confirmPendingAction(),
                  onCancel: () => ref
                      .read(agentConversationProvider.notifier)
                      .cancelPendingAction(),
                ),
              if (state.error != null)
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                    SfSpace.x16,
                    0,
                    SfSpace.x16,
                    SfSpace.x8,
                  ),
                  child: SfInfoBox(
                    icon: Icons.error_outline_rounded,
                    text: state.error!,
                    status: SfStatus.danger,
                  ),
                ),
              _suggestionRow(state),
              _console(state),
            ],
          ),
        ),
      ),
    );
  }

  // ---- Header ----

  Widget _header(AgentConversationState state) => Padding(
    padding: const EdgeInsets.fromLTRB(
      SfSpace.x16,
      SfSpace.x8,
      SfSpace.x16,
      SfSpace.x12,
    ),
    child: Row(
      children: [
        SfIconButton(
          icon: Icons.expand_more_rounded,
          onDark: true,
          tooltip: 'Đóng trợ lý',
          onTap: widget.onClose ?? () => Navigator.of(context).maybePop(),
        ),
        const SizedBox(width: SfSpace.x12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Trợ lý SafeFleet',
                style: SfType.titleSub.copyWith(
                  color: SfColors.darkTextPrimary,
                ),
              ),
              const SizedBox(height: 2),
              Row(
                children: [
                  if (state.listening) const SfPulseDot(),
                  if (state.listening) const SizedBox(width: SfSpace.x8),
                  Text(
                    state.listening
                        ? 'Đang nghe · tiếng Việt'
                        : 'Nhấn giữ nút mic để nói',
                    style: SfType.caption.copyWith(
                      color: state.listening
                          ? SfColors.green400
                          : SfColors.darkTextFaint,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        SfIconButton(
          icon: Icons.history_rounded,
          onDark: true,
          tooltip: 'Lệnh nghiệp vụ có xác nhận',
          onTap: () => showModalBottomSheet<void>(
            context: context,
            isScrollControlled: true,
            showDragHandle: true,
            builder: (_) => const AgentVoiceSheet(),
          ),
        ),
      ],
    ),
  );

  // ---- Hội thoại ----

  Widget _conversation(AgentConversationState state) {
    if (state.messages.isEmpty && !state.busy) {
      return const SfEmptyState(
        icon: Icons.auto_awesome_rounded,
        title: 'Hỏi tôi khi đang lái',
        message:
            'Ví dụ: "Các chuyến tôi đã đi hôm nay", "Tôi còn chuyến nào '
            'chưa đi?", "Báo cáo tháng 8".\n'
            'Agent chỉ đọc dữ liệu của tài khoản đang đăng nhập.',
      );
    }
    return ListView.builder(
      controller: _scroll,
      padding: const EdgeInsets.fromLTRB(
        SfSpace.x16,
        SfSpace.x4,
        SfSpace.x16,
        SfSpace.x12,
      ),
      itemCount: state.messages.length + (state.busy ? 1 : 0),
      itemBuilder: (context, index) {
        if (index == state.messages.length) {
          return const AgentThinkingBubble();
        }
        final message = state.messages[index];
        return AgentMessageBubble(
          text: message.content,
          user: message.role == 'user',
        );
      },
    );
  }

  // ---- Chip gợi ý ----

  Widget _suggestionRow(AgentConversationState state) => SizedBox(
    height: 36,
    child: ListView.separated(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: SfSpace.x16),
      itemCount: _suggestions.length,
      separatorBuilder: (_, _) => const SizedBox(width: SfSpace.x8),
      itemBuilder: (_, index) => SfFilterChip(
        label: _suggestions[index],
        selected: false,
        onDark: true,
        onTap: state.busy
            ? null
            : () => ref
                  .read(agentConversationProvider.notifier)
                  .send(_suggestions[index]),
      ),
    ),
  );

  // ---- Bảng điều khiển đáy: sóng âm, nút mic 88px, 2 nút phụ ----

  Widget _console(AgentConversationState state) => Container(
    padding: const EdgeInsets.fromLTRB(
      SfSpace.x16,
      SfSpace.x16,
      SfSpace.x16,
      SfSpace.x20,
    ),
    decoration: const BoxDecoration(
      color: SfColors.darkSurface2,
      borderRadius: SfRadius.sheetR,
      boxShadow: SfShadow.sheetDark,
    ),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (_typing) ...[
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _text,
                  autofocus: true,
                  enabled: !state.busy,
                  textInputAction: TextInputAction.send,
                  onSubmitted: (_) => _send(),
                  style: SfType.bodySm.copyWith(
                    color: SfColors.darkTextPrimary,
                  ),
                  decoration: const InputDecoration(
                    hintText: 'Hỏi SafeFleet',
                    isDense: true,
                  ),
                ),
              ),
              const SizedBox(width: SfSpace.x8),
              SfIconButton(
                icon: Icons.arrow_upward_rounded,
                onDark: true,
                tooltip: 'Gửi',
                onTap: state.busy ? null : _send,
              ),
            ],
          ),
          const SizedBox(height: SfSpace.x16),
        ] else ...[
          SfWaveform(
            active: state.listening,
            color: state.listening ? SfColors.green400 : SfColors.darkSurface4,
          ),
          const SizedBox(height: SfSpace.x16),
        ],
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            _sideButton(
              icon: _typing ? Icons.graphic_eq_rounded : Icons.keyboard_rounded,
              tooltip: _typing ? 'Dùng giọng nói' : 'Gõ chữ',
              onTap: () => setState(() => _typing = !_typing),
            ),
            _MicButton(
              listening: state.listening,
              busy: state.busy,
              onTap: () =>
                  ref.read(agentConversationProvider.notifier).listen(),
            ),
            _sideButton(
              icon: Icons.volume_up_rounded,
              tooltip: 'Đọc to câu trả lời',
              onTap: () => ref
                  .read(agentConversationProvider.notifier)
                  .setWakeEnabled(!state.wakeEnabled),
              active: state.wakeEnabled,
            ),
          ],
        ),
        const SizedBox(height: SfSpace.x12),
        Text(
          state.transcript.isNotEmpty
              ? '“${state.transcript}”'
              : 'Nhấn giữ để nói · thả ra để gửi',
          textAlign: TextAlign.center,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: SfType.caption.copyWith(
            color: state.transcript.isNotEmpty
                ? SfColors.green400
                : SfColors.darkTextFaint,
          ),
        ),
      ],
    ),
  );

  Widget _sideButton({
    required IconData icon,
    required String tooltip,
    required VoidCallback onTap,
    bool active = false,
  }) => SfIconButton(
    icon: icon,
    size: 54,
    onDark: true,
    tooltip: tooltip,
    onTap: onTap,
    foreground: active ? SfColors.green400 : SfColors.darkTextMuted,
  );
}

/// Nút mic 88px nền gradient — kênh điều khiển chính trong lúc lái.
class _MicButton extends StatelessWidget {
  const _MicButton({
    required this.listening,
    required this.busy,
    required this.onTap,
  });

  final bool listening;
  final bool busy;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final button = SfPressable(
      onTap: busy ? null : onTap,
      child: Container(
        width: SfTouch.mic,
        height: SfTouch.mic,
        alignment: Alignment.center,
        decoration: const BoxDecoration(
          gradient: SfGradients.mic,
          shape: BoxShape.circle,
        ),
        child: Icon(
          listening ? Icons.graphic_eq_rounded : Icons.mic_rounded,
          size: 36,
          color: SfColors.onAccent,
        ),
      ),
    );
    return listening
        ? SfPulseRing(
            duration: const Duration(milliseconds: 1600),
            maxScale: 1.35,
            child: button,
          )
        : button;
  }
}

class _ConfirmationCard extends StatelessWidget {
  const _ConfirmationCard({
    required this.request,
    required this.busy,
    required this.onConfirm,
    required this.onCancel,
  });

  final Map<String, dynamic> request;
  final bool busy;
  final VoidCallback onConfirm;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.fromLTRB(SfSpace.x16, 0, SfSpace.x16, SfSpace.x8),
    padding: const EdgeInsets.all(SfSpace.x16),
    decoration: BoxDecoration(
      color: SfColors.darkSurface,
      border: Border.all(color: SfColors.amber),
      borderRadius: SfRadius.cardR,
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          request['prompt']?.toString() ?? 'Xác nhận thao tác?',
          style: SfType.titleCardSm.copyWith(color: SfColors.darkTextPrimary),
        ),
        const SizedBox(height: SfSpace.x12),
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            TextButton(
              onPressed: busy ? null : onCancel,
              child: const Text('Hủy'),
            ),
            const SizedBox(width: SfSpace.x8),
            FilledButton.icon(
              onPressed: busy ? null : onConfirm,
              style: FilledButton.styleFrom(minimumSize: const Size(0, 44)),
              icon: const Icon(Icons.verified_user_rounded, size: 18),
              label: const Text('Xác nhận'),
            ),
          ],
        ),
      ],
    ),
  );
}

/// Bong bóng hội thoại.
///
/// Tài xế: nền `green700`, bo `20 20 6 20`, canh phải.
/// Trợ lý: nền `darkSurface` viền `darkBorder`, bo `20 20 20 6`, canh trái.
class AgentMessageBubble extends StatelessWidget {
  const AgentMessageBubble({required this.text, required this.user, super.key});

  final String text;
  final bool user;

  @override
  Widget build(BuildContext context) {
    final textColor = user ? SfColors.onAccent : SfColors.darkTextSecondary;
    return Align(
      alignment: user ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 320),
        margin: const EdgeInsets.only(bottom: SfSpace.x12),
        padding: const EdgeInsets.symmetric(
          horizontal: SfSpace.x14,
          vertical: SfSpace.x12,
        ),
        decoration: BoxDecoration(
          color: user ? SfColors.green700 : SfColors.darkSurface,
          border: user ? null : Border.all(color: SfColors.darkBorder),
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(SfRadius.card),
            topRight: const Radius.circular(SfRadius.card),
            bottomLeft: Radius.circular(user ? SfRadius.card : 6),
            bottomRight: Radius.circular(user ? 6 : SfRadius.card),
          ),
        ),
        child: user
            ? Text(text, style: SfType.bodySm.copyWith(color: textColor))
            : MarkdownBody(
                data: text,
                selectable: true,
                styleSheet: MarkdownStyleSheet.fromTheme(Theme.of(context))
                    .copyWith(
                      p: SfType.bodySm.copyWith(color: textColor),
                      strong: SfType.bodySm.copyWith(
                        color: SfColors.darkTextPrimary,
                        fontWeight: FontWeight.w700,
                      ),
                      em: SfType.bodySm.copyWith(
                        color: textColor,
                        fontStyle: FontStyle.italic,
                      ),
                      listBullet: SfType.bodySm.copyWith(
                        color: SfColors.green400,
                        fontWeight: FontWeight.w700,
                      ),
                      blockSpacing: SfSpace.x8,
                      listIndent: SfSpace.x20,
                    ),
              ),
      ),
    );
  }
}

class AgentThinkingBubble extends StatelessWidget {
  const AgentThinkingBubble({super.key});

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: SfSpace.x12),
    child: Align(
      alignment: Alignment.centerLeft,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 320),
        padding: const EdgeInsets.symmetric(
          horizontal: SfSpace.x14,
          vertical: SfSpace.x12,
        ),
        decoration: BoxDecoration(
          color: SfColors.darkSurface,
          border: Border.all(color: SfColors.darkBorder),
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(SfRadius.card),
            topRight: Radius.circular(SfRadius.card),
            bottomLeft: Radius.circular(6),
            bottomRight: Radius.circular(SfRadius.card),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox.square(
              dimension: 16,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
            const SizedBox(width: SfSpace.x10),
            Flexible(
              child: Text(
                'Server đang lập kế hoạch và kiểm tra dữ liệu…',
                style: SfType.caption.copyWith(color: SfColors.darkTextMuted),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}
