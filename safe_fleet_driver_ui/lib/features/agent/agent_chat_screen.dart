import 'package:flutter/material.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app.dart';
import '../../core/agent/agent_conversation_provider.dart';
import '../../core/widgets/ui.dart';
import '../documents/driving_log_list_screen.dart';
import '../insights/monthly_insights_screen.dart';
import '../navigation/route_planner_screen.dart';
import '../notifications/notifications_screen.dart';
import '../safety/safety_summary_screen.dart';
import '../trips/trip_detail_screen.dart';
import '../trips/trips_today_screen.dart';
import 'agent_voice_sheet.dart';

class AgentChatScreen extends ConsumerStatefulWidget {
  const AgentChatScreen({super.key});

  @override
  ConsumerState<AgentChatScreen> createState() => _AgentChatScreenState();
}

class _AgentChatScreenState extends ConsumerState<AgentChatScreen> {
  final _text = TextEditingController();
  final _scroll = ScrollController();

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
      if (action['type'] != 'NAVIGATE' || !mounted) continue;
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

  @override
  Widget build(BuildContext context) {
    final p = context.sf;
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

    return Scaffold(
      backgroundColor: p.bg,
      appBar: AppBar(
        title: const Text('Trợ lý SafeFleet'),
        actions: [
          IconButton(
            tooltip: 'Lệnh nghiệp vụ có xác nhận',
            onPressed: () => showModalBottomSheet<void>(
              context: context,
              isScrollControlled: true,
              showDragHandle: true,
              builder: (_) => const AgentVoiceSheet(),
            ),
            icon: const Icon(Icons.verified_user_outlined),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
              SfSpace.x16,
              SfSpace.x4,
              SfSpace.x16,
              SfSpace.x12,
            ),
            child: _AgentHero(
              wakeEnabled: state.wakeEnabled,
              listening: state.listening,
              onWakeChanged: (enabled) => ref
                  .read(agentConversationProvider.notifier)
                  .setWakeEnabled(enabled),
            ),
          ),
          Expanded(
            child: state.messages.isEmpty && !state.busy
                ? const SfEmptyState(
                    icon: Icons.auto_awesome_outlined,
                    title: 'Hỏi tôi khi đang lái',
                    message:
                        'Ví dụ: "Các chuyến tôi đã đi hôm nay", "Tôi còn chuyến nào chưa đi?", "Báo cáo tháng 8".\nAgent tự lập kế hoạch và chỉ đọc dữ liệu của tài khoản đang đăng nhập.',
                  )
                : ListView.builder(
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
                  ),
          ),
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
          if (state.transcript.isNotEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: SfSpace.x16),
              child: Row(
                children: [
                  Icon(Icons.graphic_eq_rounded, size: 16, color: p.accent),
                  const SizedBox(width: SfSpace.x8),
                  Expanded(
                    child: Text(
                      state.transcript,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: SfType.body.copyWith(color: p.accent),
                    ),
                  ),
                ],
              ),
            ),
          if (state.error != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(
                SfSpace.x16,
                SfSpace.x8,
                SfSpace.x16,
                0,
              ),
              child: Text(
                state.error!,
                style: SfType.meta.copyWith(color: SfColors.danger),
              ),
            ),
          SafeArea(
            top: false,
            minimum: const EdgeInsets.fromLTRB(
              SfSpace.x16,
              SfSpace.x8,
              SfSpace.x16,
              SfSpace.x40 + SfSpace.x40 + SfSpace.x16,
            ),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _text,
                    enabled: !state.busy,
                    textInputAction: TextInputAction.send,
                    onSubmitted: (_) => _send(),
                    decoration: const InputDecoration(
                      hintText: 'Hỏi SafeFleet',
                      prefixIcon: Icon(Icons.auto_awesome_outlined),
                    ),
                  ),
                ),
                const SizedBox(width: SfSpace.x8),
                SizedBox(
                  width: SfTouch.min,
                  height: SfTouch.min,
                  child: IconButton.filled(
                    tooltip: state.listening ? 'Đang nghe' : 'Nói với trợ lý',
                    onPressed: state.busy
                        ? null
                        : () => ref
                              .read(agentConversationProvider.notifier)
                              .listen(),
                    icon: Icon(
                      state.listening
                          ? Icons.graphic_eq_rounded
                          : Icons.mic_none_rounded,
                    ),
                  ),
                ),
                const SizedBox(width: SfSpace.x4),
                SizedBox(
                  width: SfTouch.min,
                  height: SfTouch.min,
                  child: IconButton(
                    tooltip: 'Gửi',
                    onPressed: state.busy ? null : _send,
                    icon: const Icon(Icons.arrow_upward_rounded),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
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
  Widget build(BuildContext context) {
    final p = context.sf;
    return Container(
      margin: const EdgeInsets.fromLTRB(
        SfSpace.x16,
        0,
        SfSpace.x16,
        SfSpace.x8,
      ),
      padding: const EdgeInsets.all(SfSpace.x16),
      decoration: BoxDecoration(
        color: p.surface,
        border: Border.all(color: SfColors.amber),
        borderRadius: SfRadius.cardR,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            request['prompt']?.toString() ?? 'Xác nhận thao tác?',
            style: SfType.titleCard.copyWith(color: p.textPrimary),
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
                icon: const Icon(Icons.verified_user_outlined),
                label: const Text('Xác nhận'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _AgentHero extends StatelessWidget {
  const _AgentHero({
    required this.wakeEnabled,
    required this.listening,
    required this.onWakeChanged,
  });

  final bool wakeEnabled;
  final bool listening;
  final ValueChanged<bool> onWakeChanged;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.fromLTRB(
      SfSpace.x16,
      SfSpace.x12,
      SfSpace.x8,
      SfSpace.x12,
    ),
    decoration: const BoxDecoration(
      color: SfColors.navy,
      borderRadius: SfRadius.cardR,
    ),
    child: Row(
      children: [
        CircleAvatar(
          radius: 24,
          backgroundColor: listening ? SfColors.mint : SfColors.navy700,
          child: Icon(
            Icons.graphic_eq_rounded,
            color: listening ? SfColors.navy : SfColors.mint,
          ),
        ),
        const SizedBox(width: SfSpace.x12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                listening ? 'Đang nghe bạn nói' : 'Đánh thức bằng giọng nói',
                style: SfType.titleCard.copyWith(
                  color: SfColors.darkTextPrimary,
                ),
              ),
              const SizedBox(height: SfSpace.x4),
              Text(
                'Nói "Hi SafeFleet" để ra lệnh mà không rời tay khỏi vô lăng.',
                style: SfType.meta.copyWith(color: SfColors.darkTextSecondary),
              ),
            ],
          ),
        ),
        Switch.adaptive(value: wakeEnabled, onChanged: onWakeChanged),
      ],
    ),
  );
}

class AgentMessageBubble extends StatelessWidget {
  const AgentMessageBubble({required this.text, required this.user, super.key});

  final String text;
  final bool user;

  @override
  Widget build(BuildContext context) {
    final p = context.sf;
    final textColor = user ? SfColors.darkTextPrimary : p.textPrimary;
    return Align(
      alignment: user ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 320),
        margin: const EdgeInsets.only(bottom: SfSpace.x12),
        padding: const EdgeInsets.all(SfSpace.x16),
        decoration: BoxDecoration(
          color: user ? SfColors.navy : p.surface,
          border: user ? null : Border.all(color: p.border),
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(user ? SfRadius.card : SfSpace.x4),
            topRight: Radius.circular(user ? SfSpace.x4 : SfRadius.card),
            bottomLeft: const Radius.circular(SfRadius.card),
            bottomRight: const Radius.circular(SfRadius.card),
          ),
        ),
        child: user
            ? Text(text, style: SfType.body.copyWith(color: textColor))
            : MarkdownBody(
                data: text,
                selectable: true,
                styleSheet: MarkdownStyleSheet.fromTheme(Theme.of(context))
                    .copyWith(
                      p: SfType.body.copyWith(color: textColor),
                      strong: SfType.body.copyWith(
                        color: textColor,
                        fontWeight: FontWeight.w700,
                      ),
                      em: SfType.body.copyWith(
                        color: textColor,
                        fontStyle: FontStyle.italic,
                      ),
                      listBullet: SfType.body.copyWith(
                        color: p.accent,
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
  Widget build(BuildContext context) => const Padding(
    padding: EdgeInsets.fromLTRB(
      SfSpace.x16,
      SfSpace.x8,
      SfSpace.x16,
      SfSpace.x16,
    ),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        SizedBox.square(
          dimension: 20,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
        SizedBox(width: SfSpace.x8),
        Expanded(
          child: Text(
            'Server đang lập kế hoạch và kiểm tra dữ liệu…',
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    ),
  );
}
