import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:speech_to_text/speech_to_text.dart';
import 'package:speech_to_text/speech_recognition_result.dart';

import '../../app.dart';

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
            'Xin chào! Tôi có thể hỗ trợ dẫn đường, đọc cảnh báo, báo ngập và xử lý tình huống khẩn cấp.',
      ),
    ],
    this.busy = false,
    this.listening = false,
    this.wakeEnabled = false,
    this.engaged = false,
    this.transcript = '',
    this.error,
  });

  final List<AgentMessage> messages;
  final bool busy;
  final bool listening;
  final bool wakeEnabled;
  final bool engaged;
  final String transcript;
  final String? error;

  AgentConversationState copyWith({
    List<AgentMessage>? messages,
    bool? busy,
    bool? listening,
    bool? wakeEnabled,
    bool? engaged,
    String? transcript,
    String? error,
    bool clearError = false,
  }) => AgentConversationState(
    messages: messages ?? this.messages,
    busy: busy ?? this.busy,
    listening: listening ?? this.listening,
    wakeEnabled: wakeEnabled ?? this.wakeEnabled,
    engaged: engaged ?? this.engaged,
    transcript: transcript ?? this.transcript,
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
      final normalized = words.toLowerCase();
      final wake = _wakePhrases.firstWhere(
        normalized.contains,
        orElse: () => '',
      );
      if (wake.isEmpty) return;
      final remainder = normalized.replaceFirst(wake, '').trim();
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

  static const _wakePhrases = [
    'hi siri',
    'hey siri',
    'hi safefleet',
    'hey safefleet',
  ];
}
