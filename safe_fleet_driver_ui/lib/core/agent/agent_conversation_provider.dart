import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:speech_to_text/speech_to_text.dart';
import 'package:speech_to_text/speech_recognition_result.dart';

import '../../app.dart';
import 'agent_voice.dart';

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
    this.speaking = false,
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

  /// Trợ lý đang đọc. Micro tắt trong lúc này để máy không nghe chính nó.
  final bool speaking;
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
    bool? speaking,
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
    speaking: speaking ?? this.speaking,
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
  static const _wakePreferenceKey = 'agent_wake_always_on';

  final SpeechToText _speech = SpeechToText();
  final AgentVoice _voice = AgentVoice();
  Timer? _restartTimer;
  bool _manualStop = false;
  bool _suspended = false;

  @override
  AgentConversationState build() {
    ref.onDispose(() {
      _restartTimer?.cancel();
      unawaited(_speech.cancel());
      unawaited(_voice.dispose());
    });
    return const AgentConversationState();
  }

  /// Giọng đang dùng, để màn cài đặt nói rõ tài xế đang nghe ai.
  Map<String, String>? get selectedVoice => _voice.selectedVoice;

  /// Bật lại chế độ nghe nền theo lựa chọn lần trước.
  ///
  /// Gọi một lần khi mở app: tài xế bật "gọi trợ lý bất cứ lúc nào" rồi thì
  /// lần sau mở máy phải gọi được ngay, không phải vào chuyến mới có.
  ///
  /// Chỉ khôi phục khi quyền micro đã được cấp từ trước. Bật micro ngay lúc mở
  /// app sẽ ném ra hộp thoại xin quyền không rõ lý do - quyền nhạy cảm phải
  /// được hỏi đúng lúc tài xế chủ động gạt công tắc.
  Future<void> restoreWakePreference() async {
    if (state.wakeEnabled) return;
    try {
      if (!await Permission.microphone.isGranted) return;
      final saved = await ref
          .read(databaseProvider)
          .cached<Map<String, dynamic>>(_wakePreferenceKey);
      if (saved?['enabled'] == true) await setWakeEnabled(true, remember: false);
    } catch (_) {
      // Không đọc được tuỳ chọn thì cứ để tắt, tài xế bật lại bằng tay.
    }
  }

  Future<void> setWakeEnabled(bool enabled, {bool remember = true}) async {
    state = state.copyWith(wakeEnabled: enabled, clearError: true);
    if (remember) {
      try {
        await ref
            .read(databaseProvider)
            .cache(_wakePreferenceKey, {'enabled': enabled});
      } catch (_) {
        // Lưu hỏng thì phiên này vẫn chạy đúng.
      }
    }
    if (enabled) {
      unawaited(_voice.initialize());
      await listen(wakeOnly: true);
    } else {
      _manualStop = true;
      await _speech.cancel();
      state = state.copyWith(listening: false, engaged: false);
    }
  }

  Future<void> listen({bool wakeOnly = false}) async {
    // Nghe trong lúc đang đọc thì máy tự nghe giọng của chính nó và có thể tự
    // kích hoạt bằng chữ "SafeFleet" trong câu trả lời.
    if (state.busy || state.speaking || _suspended || _speech.isListening) {
      return;
    }
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
    if (!listening &&
        state.wakeEnabled &&
        !state.busy &&
        !state.speaking &&
        !_manualStop) {
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
      await _speakAnswer(answer);
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
    if (pending['type']?.toString() == 'FLOOD_REPORT') {
      await _confirmFloodReport(pending);
      return;
    }
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
      await _speakAnswer(answer);
    } catch (error) {
      state = state.copyWith(busy: false, error: error.toString());
    }
  }

  Future<void> _confirmFloodReport(Map<String, dynamic> pending) async {
    final severity = pending['severity']?.toString() ?? 'HIGH';
    state = state.copyWith(busy: true, clearError: true);
    try {
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        throw StateError('Cần quyền vị trí để báo điểm ngập.');
      }
      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
        ),
      );
      final result = await ref
          .read(driverRepositoryProvider)
          .reportFlood(
            position: position,
            severity: severity,
            address: pending['description']?.toString(),
          );
      final queued = result['status']?.toString() == 'QUEUED_OFFLINE';
      final answer = queued
          ? 'Đã lưu điểm ngập vào hàng đợi và sẽ đồng bộ khi có mạng.'
          : 'Đã ghi nhận điểm ngập tại vị trí hiện tại. Tuyến của đội xe sẽ được đánh giá lại.';
      state = state.copyWith(
        messages: [
          ...state.messages,
          AgentMessage(role: 'assistant', content: answer),
        ],
        busy: false,
        clearConfirmation: true,
      );
      await _speakAnswer(answer);
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

  /// Nhường micro cho một màn khác đang cần ghi âm.
  ///
  /// Hai bộ nhận dạng cùng mở sẽ tranh nhau micro và cả hai đều nghe sai, nên
  /// chế độ nghe nền phải im lặng trong lúc sheet lệnh nghiệp vụ đang nghe.
  Future<void> suspendWake() async {
    if (_suspended) return;
    _suspended = true;
    _restartTimer?.cancel();
    _manualStop = true;
    await _speech.cancel();
    state = state.copyWith(listening: false, engaged: false);
  }

  /// Nghe nền trở lại sau khi màn kia trả micro.
  Future<void> resumeWake() async {
    if (!_suspended) return;
    _suspended = false;
    _manualStop = false;
    if (state.wakeEnabled) _scheduleWakeRestart();
  }

  /// Đọc một câu ngoài luồng hội thoại bằng đúng giọng trợ lý.
  Future<void> speakAside(String text) => _speakAnswer(text);

  /// Đọc câu trả lời, tắt micro suốt thời gian đó rồi mới nghe lại.
  Future<void> _speakAnswer(String answer) async {
    await _speech.stop();
    state = state.copyWith(speaking: true, listening: false);
    try {
      await _voice.speak(answer);
    } finally {
      state = state.copyWith(speaking: false);
      if (state.wakeEnabled) _scheduleWakeRestart();
    }
  }

  /// Ngắt lời trợ lý khi tài xế chạm micro giữa chừng.
  Future<void> stopSpeaking() async {
    await _voice.stop();
    state = state.copyWith(speaking: false);
  }

  void _scheduleWakeRestart() {
    _restartTimer?.cancel();
    if (_suspended) return;
    _restartTimer = Timer(const Duration(milliseconds: 700), () {
      if (state.wakeEnabled &&
          !_suspended &&
          !state.busy &&
          !state.speaking &&
          !_speech.isListening) {
        unawaited(listen(wakeOnly: !state.engaged));
      }
    });
  }
}
