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
  });
}
