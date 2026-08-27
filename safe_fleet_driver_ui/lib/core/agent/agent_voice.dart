import 'dart:async';

import 'package:flutter_tts/flutter_tts.dart';

/// Cách đọc của trợ lý: nữ, tiếng Việt, chậm và dịu.
///
/// Trong cabin, giọng máy phải nghe ra ngay là trợ lý chứ không lẫn với chỉ dẫn
/// dẫn đường, và phải dễ nghe khi xe ồn. Đọc chậm hơn mặc định một chút, cao độ
/// nhỉnh hơn một chút cho mềm giọng.
class AgentVoiceStyle {
  const AgentVoiceStyle({
    this.speechRate = 0.45,
    this.pitch = 1.06,
    this.volume = 0.95,
  });

  final double speechRate;
  final double pitch;
  final double volume;
}

/// Chấm điểm một giọng đọc theo mức phù hợp với trợ lý.
///
/// Điểm âm nghĩa là không dùng được.
int scoreVietnameseVoice(Map<String, String> voice) {
  final locale = (voice['locale'] ?? '').toLowerCase();
  if (!locale.startsWith('vi')) return -1;

  final name = (voice['name'] ?? '').toLowerCase();
  final gender = (voice['gender'] ?? '').toLowerCase();
  // "female" chứa "male": phải bóc "female" ra trước rồi mới dò "male", nếu
  // không thì mọi giọng nữ đều bị chấm là giọng nam.
  final withoutFemale = name.replaceAll('female', '');

  var score = 10;

  if (gender == 'female') {
    score += 60;
  } else if (gender == 'male') {
    score -= 60;
  }

  if (name.contains('female')) {
    score += 50;
  } else if (withoutFemale.contains('male')) {
    score -= 50;
  }

  // Các tên giọng nữ tiếng Việt hay gặp trên máy thật.
  const femaleNames = <String>[
    'vif', // Google: vi-vn-x-vif-local
    'linh', // iOS: Linh
    'hoaimy', // Microsoft: vi-VN-HoaiMyNeural
    'hoai my',
    'thuthao',
    'thu thao',
    'ngochuyen',
    'ngoc huyen',
  ];
  for (final candidate in femaleNames) {
    if (name.contains(candidate)) {
      score += 40;
      break;
    }
  }

  // Các tên giọng nam tiếng Việt hay gặp.
  const maleNames = <String>['vic', 'namminh', 'nam minh', 'gia huy', 'giahuy'];
  for (final candidate in maleNames) {
    if (name.contains(candidate)) {
      score -= 40;
      break;
    }
  }

  // Giọng cài sẵn trên máy vẫn đọc được khi xe ra khỏi vùng phủ sóng; giọng
  // tải qua mạng thì không.
  if (name.contains('local') || name.contains('embedded')) score += 15;
  if (name.contains('network')) score -= 10;

  // vi-VN cụ thể hơn là vi chung chung.
  if (locale.startsWith('vi-vn') || locale.startsWith('vi_vn')) score += 5;

  return score;
}

/// Chọn giọng hợp nhất trong danh sách máy báo về.
///
/// Trả về null khi máy không có giọng tiếng Việt nào — lúc đó cứ để engine đọc
/// bằng giọng mặc định còn hơn là im lặng.
Map<String, String>? pickVietnameseAssistantVoice(
  List<Map<String, String>> voices,
) {
  Map<String, String>? best;
  var bestScore = 0;
  for (final voice in voices) {
    final score = scoreVietnameseVoice(voice);
    if (score > bestScore) {
      bestScore = score;
      best = voice;
    }
  }
  return best;
}

/// Đọc câu trả lời của trợ lý.
///
/// Tách khỏi [AgentConversationController] để phần chọn giọng kiểm thử được mà
/// không cần chạm vào plugin, và để dẫn đường với trợ lý dùng chung một cách
/// quản lý hàng đợi.
class AgentVoice {
  AgentVoice({FlutterTts? tts, this.style = const AgentVoiceStyle()})
    : _tts = tts ?? FlutterTts();

  final FlutterTts _tts;
  final AgentVoiceStyle style;

  bool _ready = false;
  bool _speaking = false;
  Map<String, String>? _voice;

  bool get isSpeaking => _speaking;

  /// Giọng đang dùng, để màn cài đặt hiển thị cho tài xế biết.
  Map<String, String>? get selectedVoice => _voice;

  Future<void> initialize() async {
    if (_ready) return;
    try {
      await _tts.awaitSpeakCompletion(true);
      final available = await _tts.isLanguageAvailable('vi-VN');
      if (available == true) await _tts.setLanguage('vi-VN');

      final voices = await _tts.getVoices;
      if (voices is List) {
        final parsed = voices
            .whereType<Map>()
            .map(
              (item) => item.map(
                (key, value) =>
                    MapEntry(key.toString(), value?.toString() ?? ''),
              ),
            )
            .toList();
        _voice = pickVietnameseAssistantVoice(parsed);
        if (_voice != null) {
          await _tts.setVoice({
            'name': _voice!['name'] ?? '',
            'locale': _voice!['locale'] ?? 'vi-VN',
          });
        }
      }

      await _tts.setSpeechRate(style.speechRate);
      await _tts.setPitch(style.pitch);
      await _tts.setVolume(style.volume);
      _ready = true;
    } catch (_) {
      // Máy không có engine TTS thì trợ lý vẫn trả lời bằng chữ.
      _ready = false;
    }
  }

  /// Đọc [text] và chỉ trả về khi đã đọc xong, để bên gọi biết lúc nào bật lại
  /// micro mà không bị nghe chính giọng của mình.
  Future<void> speak(String text) async {
    final content = text.trim();
    if (content.isEmpty) return;
    if (!_ready) await initialize();
    _speaking = true;
    try {
      await _tts.speak(content);
    } catch (_) {
      // Bỏ qua câu này, không để hỏng luồng hội thoại.
    } finally {
      _speaking = false;
    }
  }

  Future<void> stop() async {
    _speaking = false;
    try {
      await _tts.stop();
    } catch (_) {
      // Không có gì đang đọc.
    }
  }

  Future<void> dispose() => stop();
}
