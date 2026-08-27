import 'package:flutter_test/flutter_test.dart';
import 'package:safe_fleet_driver_ui/core/agent/agent_conversation_provider.dart';

void main() {
  group('agentWakeRemainder', () {
    test('không mở agent khi chưa gọi tên', () {
      expect(agentWakeRemainder('báo ngập phía trước'), isNull);
      expect(agentWakeRemainder('còn bao xa nữa'), isNull);
    });

    test('nhận cả cách đọc SafeFleet liền và tách', () {
      expect(agentWakeRemainder('Hey SafeFleet'), '');
      expect(agentWakeRemainder('Safe Fleet ơi'), '');
    });

    test('giữ lại câu lệnh nói sau tên gọi', () {
      expect(
        agentWakeRemainder('Hey Safe Fleet còn bao xa nữa'),
        'còn bao xa nữa',
      );
    });

    test('không phụ thuộc chữ hoa thường hay khoảng trắng thừa', () {
      expect(agentWakeRemainder('  HEY SAFEFLEET  báo ngập  '), 'báo ngập');
      expect(agentWakeRemainder('SafeFleet ơi'), '');
    });

    test('cụm dài được ưu tiên khớp trước cụm ngắn', () {
      // Nếu "safe fleet" khớp trước thì phần còn lại sẽ dính chữ "hey".
      expect(agentWakeRemainder('hey safe fleet mở bản đồ'), 'mở bản đồ');
      expect(agentWakeRemainder('trợ lý safefleet mở bản đồ'), 'mở bản đồ');
    });

    test('chính câu trả lời của trợ lý cũng khớp tên gọi', () {
      // Đây là lý do micro phải tắt trong lúc trợ lý đang đọc: nếu vẫn nghe,
      // máy sẽ nghe thấy tên mình trong câu trả lời và tự kích hoạt vòng lặp.
      expect(
        agentWakeRemainder('Tôi là trợ lý SafeFleet, bạn cần gì ạ'),
        isNotNull,
      );
    });
  });
}
