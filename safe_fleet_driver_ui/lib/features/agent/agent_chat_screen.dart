import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/agent/agent_conversation_provider.dart';
import '../../core/widgets/ui.dart';
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
                        'Ví dụ: "Tuyến nào ít ngập hơn", "Tôi cần nghỉ", "Gọi cứu hộ".\nLệnh làm thay đổi chuyến luôn hỏi xác nhận trước khi chạy.',
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
                        return const _ThinkingBubble();
                      }
                      final message = state.messages[index];
                      return _Bubble(
                        text: message.content,
                        user: message.role == 'user',
                      );
                    },
                  ),
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
                style: SfType.meta.copyWith(
                  color: SfColors.darkTextSecondary,
                ),
              ),
            ],
          ),
        ),
        Switch.adaptive(value: wakeEnabled, onChanged: onWakeChanged),
      ],
    ),
  );
}

class _Bubble extends StatelessWidget {
  const _Bubble({required this.text, required this.user});

  final String text;
  final bool user;

  @override
  Widget build(BuildContext context) {
    final p = context.sf;
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
        child: Text(
          text,
          style: SfType.body.copyWith(
            color: user ? SfColors.darkTextPrimary : p.textPrimary,
          ),
        ),
      ),
    );
  }
}

class _ThinkingBubble extends StatelessWidget {
  const _ThinkingBubble();

  @override
  Widget build(BuildContext context) => const Align(
    alignment: Alignment.centerLeft,
    child: Padding(
      padding: EdgeInsets.all(SfSpace.x16),
      child: SizedBox.square(
        dimension: 20,
        child: CircularProgressIndicator(strokeWidth: 2),
      ),
    ),
  );
}
