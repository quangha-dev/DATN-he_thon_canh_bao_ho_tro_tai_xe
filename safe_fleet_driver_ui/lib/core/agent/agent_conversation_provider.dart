import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:speech_to_text/speech_to_text.dart';
import 'package:speech_to_text/speech_recognition_result.dart';

import '../../app.dart';

const agentWakePhrases = <String>[
  'hey safe fleet',
  'hi safe fleet',
  'trợ lý safe fleet',
  'safe fleet ơi',
  'hey safefleet',
  'hi safefleet',
  'trợ lý safefleet',
  'safefleet ơi',
  'safe fleet',
  'safefleet',
];

String? agentWakeRemainder(String words) {
  final normalized = words.toLowerCase().trim();
  for (final phrase in agentWakePhrases) {
    if (normalized.contains(phrase)) {
      return normalized.replaceFirst(phrase, '').trim();
    }
  }
  return null;
}

class AgentMessage {
  const AgentMessage({required this.role, required this.content});

  final String role;
  final String content;

  Map<String, String> toJson() => {'role': role, 'content': content};
}

class AgentConversationState {
  const AgentConversationState({
    this.messages = const [
      AgentMessage(
        role: 'assistant',
        content:
            'Xin chào! Tôi có thể tra cứu chuyến đã đi, chuyến chưa đi, chi tiết chuyến và báo cáo tháng từ server SafeFleet.',
      ),
    ],
    this.busy = false,
    this.listening = false,
    this.wakeEnabled = false,
    this.engaged = false,
    this.transcript = '',
    this.clientActions = const [],
    this.confirmationRequest,
    this.error,
  });

  final List<AgentMessage> messages;
  final bool busy;
  final bool listening;
  final bool wakeEnabled;
  final bool engaged;
  final String transcript;
  final List<Map<String, dynamic>> clientActions;
  final Map<String, dynamic>? confirmationRequest;
  final String? error;

  AgentConversationState copyWith({
    List<AgentMessage>? messages,
    bool? busy,
    bool? listening,
    bool? wakeEnabled,
    bool? engaged,
    String? transcript,
    List<Map<String, dynamic>>? clientActions,
    Map<String, dynamic>? confirmationRequest,
    bool clearConfirmation = false,
    String? error,
    bool clearError = false,
  }) => AgentConversationState(
    messages: messages ?? this.messages,
    busy: busy ?? this.busy,
    listening: listening ?? this.listening,
    wakeEnabled: wakeEnabled ?? this.wakeEnabled,
    engaged: engaged ?? this.engaged,
    transcript: transcript ?? this.transcript,
    clientActions: clientActions ?? this.clientActions,
    confirmationRequest: clearConfirmation
        ? null
        : (confirmationRequest ?? this.confirmationRequest),
    error: clearError ? null : (error ?? this.error),
  );
}

final agentConversationProvider =
    NotifierProvider<AgentConversationController, AgentConversationState>(
      AgentConversationController.new,
    );

class AgentConversationController extends Notifier<AgentConversationState> {
  final SpeechToText _speech = SpeechToText();
  final FlutterTts _tts = FlutterTts();
  Timer? _restartTimer;
  bool _manualStop = false;

  @override
  AgentConversationState build() {
    ref.onDispose(() {
      _restartTimer?.cancel();
      unawaited(_speech.cancel());
      unawaited(_tts.stop());
    });
    return const AgentConversationState();
  }

  Future<void> setWakeEnabled(bool enabled) async {
    state = state.copyWith(wakeEnabled: enabled, clearError: true);
    if (enabled) {
      await listen(wakeOnly: true);
    } else {
      _manualStop = true;
      await _speech.cancel();
      state = state.copyWith(listening: false, engaged: false);
    }
  }

  Future<void> listen({bool wakeOnly = false}) async {
    if (state.busy || _speech.isListening) return;
    final available = await _speech.initialize(
      onStatus: _onStatus,
      onError: (error) {
        state = state.copyWith(listening: false, error: error.errorMsg);
      },
    );
    if (!available) {
      state = state.copyWith(
        listening: false,
        error: 'Thiết bị chưa hỗ trợ nhận dạng giọng nói.',
      );
      return;
    }
    _manualStop = false;
    if (!wakeOnly) state = state.copyWith(engaged: true);
    state = state.copyWith(listening: true, transcript: '', clearError: true);
    await _speech.listen(
      onResult: _onSpeech,
      listenOptions: SpeechListenOptions(
        localeId: 'vi_VN',
        listenFor: const Duration(seconds: 30),
        pauseFor: const Duration(seconds: 3),
        listenMode: ListenMode.dictation,
        partialResults: true,
        cancelOnError: false,
      ),
    );
  }

  void _onStatus(String status) {
    final listening = status == 'listening';
    state = state.copyWith(listening: listening);
    if (!listening && state.wakeEnabled && !state.busy && !_manualStop) {
      _scheduleWakeRestart();
    }
  }

  void _onSpeech(SpeechRecognitionResult result) {
    final words = result.recognizedWords.trim();
    state = state.copyWith(transcript: words);
    if (!state.engaged) {
      final remainder = agentWakeRemainder(words);
      if (remainder == null) return;
      state = state.copyWith(engaged: true, transcript: remainder);
      if (result.finalResult && remainder.isNotEmpty) {
        unawaited(send(remainder));
      }
      return;
    }
    if (result.finalResult && words.isNotEmpty) unawaited(send(words));
  }

  Future<void> send(String text) async {
    final message = text.trim();
    if (message.isEmpty || state.busy) return;
    _manualStop = true;
    await _speech.stop();
    final next = [
      ...state.messages,
      AgentMessage(role: 'user', content: message),
    ];
    state = state.copyWith(
      messages: next,
      busy: true,
      listening: false,
      transcript: '',
      engaged: true,
      clearError: true,
    );
    try {
      final response = await ref
          .read(driverRepositoryProvider)
          .agentChat(next.map((item) => item.toJson()).toList());
      final answer =
          response['responseText']?.toString() ??
          'Tôi chưa thể trả lời lúc này.';
      state = state.copyWith(
        messages: [
          ...state.messages,
          AgentMessage(role: 'assistant', content: answer),
        ],
        busy: false,
        clientActions: (response['clientActions'] as List<dynamic>? ?? const [])
            .whereType<Map>()
            .map((item) => Map<String, dynamic>.from(item))
            .toList(),
        confirmationRequest: response['confirmationRequest'] is Map
            ? Map<String, dynamic>.from(response['confirmationRequest'] as Map)
            : null,
        clearConfirmation: response['confirmationRequest'] == null,
      );
      await _tts.setLanguage('vi-VN');
      await _tts.setSpeechRate(0.48);
      await _tts.speak(answer);
    } catch (error) {
      state = state.copyWith(busy: false, error: error.toString());
    } finally {
      if (state.wakeEnabled) _scheduleWakeRestart();
    }
  }

  void consumeClientActions() {
    if (state.clientActions.isNotEmpty) {
      state = state.copyWith(clientActions: const []);
    }
  }

  Future<void> confirmPendingAction() async {
    final pending = state.confirmationRequest;
    if (pending == null || state.busy) return;
    final tripId = (pending['tripId'] as num?)?.toInt();
    final action = pending['action']?.toString();
    if (tripId == null || action == null) {
      state = state.copyWith(
        error: 'Yêu cầu xác nhận không hợp lệ.',
        clearConfirmation: true,
      );
      return;
    }
    state = state.copyWith(busy: true, clearError: true);
    try {
      final result = await ref
          .read(driverRepositoryProvider)
          .executeConfirmedTripAction(
            tripId: tripId,
            action: action,
            note: pending['note']?.toString(),
          );
      final status = result['status']?.toString();
      final answer = status == 'QUEUED_OFFLINE'
          ? 'Đã lưu thao tác vào hàng đợi; ứng dụng sẽ đồng bộ khi có mạng.'
          : 'Đã thực hiện thao tác ${action.toLowerCase()} cho chuyến #$tripId.';
      state = state.copyWith(
        messages: [
          ...state.messages,
          AgentMessage(role: 'assistant', content: answer),
        ],
        busy: false,
        clearConfirmation: true,
      );
      await _tts.speak(answer);
    } catch (error) {
      state = state.copyWith(busy: false, error: error.toString());
    }
  }

  void cancelPendingAction() {
    if (state.confirmationRequest == null) return;
    state = state.copyWith(
      messages: [
        ...state.messages,
        const AgentMessage(role: 'assistant', content: 'Đã hủy thao tác.'),
      ],
      clearConfirmation: true,
    );
  }

  Future<void> dismissOverlay() async {
    state = state.copyWith(engaged: false, transcript: '');
    if (state.wakeEnabled) {
      _manualStop = false;
      _scheduleWakeRestart();
    }
  }

  void _scheduleWakeRestart() {
    _restartTimer?.cancel();
    _restartTimer = Timer(const Duration(milliseconds: 700), () {
      if (state.wakeEnabled && !state.busy && !_speech.isListening) {
        unawaited(listen(wakeOnly: !state.engaged));
      }
    });
  }
}
