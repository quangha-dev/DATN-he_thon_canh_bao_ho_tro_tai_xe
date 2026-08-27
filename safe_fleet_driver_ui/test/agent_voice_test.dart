import 'package:flutter_test/flutter_test.dart';
import 'package:safe_fleet_driver_ui/core/agent/agent_voice.dart';

/// Danh sách giọng đúng như các máy thật báo về.
const _androidGoogle = <Map<String, String>>[
  {'name': 'vi-vn-x-vic-local', 'locale': 'vi-VN'},
  {'name': 'vi-vn-x-vic-network', 'locale': 'vi-VN'},
  {'name': 'vi-vn-x-vif-local', 'locale': 'vi-VN'},
  {'name': 'vi-vn-x-vif-network', 'locale': 'vi-VN'},
  {'name': 'en-us-x-sfg#female_1-local', 'locale': 'en-US'},
];

const _androidSamsung = <Map<String, String>>[
  {'name': 'vi-VN-language', 'locale': 'vi-VN'},
  {'name': 'vi-vn-x-gnh#male_1-local', 'locale': 'vi-VN'},
  {'name': 'vi-vn-x-gnh#female_1-local', 'locale': 'vi-VN'},
];

const _ios = <Map<String, String>>[
  {'name': 'Linh', 'locale': 'vi-VN', 'gender': 'female'},
  {'name': 'Daniel', 'locale': 'en-GB', 'gender': 'male'},
];

void main() {
  group('chọn giọng trợ lý', () {
    test('lấy giọng nữ tiếng Việt trên máy Android dùng Google TTS', () {
      final voice = pickVietnameseAssistantVoice(_androidGoogle);

      expect(voice, isNotNull);
      // vif = giọng nữ, bản cài sẵn để còn đọc được khi mất sóng.
      expect(voice!['name'], 'vi-vn-x-vif-local');
    });

    test('đọc được dấu #female trong tên giọng', () {
      final voice = pickVietnameseAssistantVoice(_androidSamsung);

      expect(voice!['name'], 'vi-vn-x-gnh#female_1-local');
    });

    test('nhận trường gender trên iOS', () {
      final voice = pickVietnameseAssistantVoice(_ios);

      expect(voice!['name'], 'Linh');
    });

    test('không bao giờ chọn giọng ngoài tiếng Việt', () {
      final voice = pickVietnameseAssistantVoice(const [
        {'name': 'en-us-x-sfg#female_1-local', 'locale': 'en-US'},
        {'name': 'Samantha', 'locale': 'en-US', 'gender': 'female'},
      ]);

      expect(
        voice,
        isNull,
        reason: 'thà để engine đọc giọng mặc định còn hơn đọc tiếng Việt bằng '
            'giọng tiếng Anh',
      );
    });

    test('máy không có giọng nào thì trả về null chứ không nổ', () {
      expect(pickVietnameseAssistantVoice(const []), isNull);
    });
  });

  group('chấm điểm giọng', () {
    test('"female" không bị đếm nhầm thành "male"', () {
      // Bẫy kinh điển: chuỗi "female" chứa "male".
      final female = scoreVietnameseVoice({
        'name': 'vi-vn-x-gnh#female_1-local',
        'locale': 'vi-VN',
      });
      final male = scoreVietnameseVoice({
        'name': 'vi-vn-x-gnh#male_1-local',
        'locale': 'vi-VN',
      });

      expect(female, greaterThan(0));
      expect(male, lessThan(female));
    });

    test('giọng nam tiếng Việt xếp dưới giọng nữ tiếng Việt', () {
      expect(
        scoreVietnameseVoice({'name': 'vi-vn-x-vif-local', 'locale': 'vi-VN'}),
        greaterThan(
          scoreVietnameseVoice({
            'name': 'vi-vn-x-vic-local',
            'locale': 'vi-VN',
          }),
        ),
      );
    });

    test('ưu tiên giọng cài sẵn hơn giọng tải qua mạng', () {
      expect(
        scoreVietnameseVoice({'name': 'vi-vn-x-vif-local', 'locale': 'vi-VN'}),
        greaterThan(
          scoreVietnameseVoice({
            'name': 'vi-vn-x-vif-network',
            'locale': 'vi-VN',
          }),
        ),
      );
    });

    test('giọng không phải tiếng Việt bị loại thẳng', () {
      expect(
        scoreVietnameseVoice({'name': 'Samantha', 'locale': 'en-US'}),
        isNegative,
      );
    });
  });

  group('kiểu đọc', () {
    test('mặc định là chậm và dịu hơn giọng máy thông thường', () {
      const style = AgentVoiceStyle();

      // Trên thang của flutter_tts, 0.5 là tốc độ thường.
      expect(style.speechRate, lessThan(0.5));
      expect(style.pitch, greaterThan(1.0));
      expect(style.volume, greaterThan(0.9));
    });
  });
}
