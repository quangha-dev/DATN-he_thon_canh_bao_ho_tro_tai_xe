import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:safe_fleet_driver_ui/features/agent/agent_chat_screen.dart';

void main() {
  testWidgets('agent thinking row does not overflow on a narrow phone', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(360, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: AgentThinkingBubble())),
    );

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(
      find.text('Server đang lập kế hoạch và kiểm tra dữ liệu…'),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });
}
