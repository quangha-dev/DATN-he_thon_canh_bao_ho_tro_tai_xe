import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:safe_fleet_driver_ui/features/agent/agent_voice_sheet.dart';

void main() {
  testWidgets('agent sheet offers voice and typed Vietnamese command input', (
    tester,
  ) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(home: Scaffold(body: AgentVoiceSheet(tripId: 42))),
      ),
    );

    expect(find.text('Trợ lý SafeFleet'), findsOneWidget);
    expect(find.byTooltip('Ra lệnh bằng giọng nói'), findsOneWidget);
    expect(find.text('Gửi lệnh'), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'Tôi cần SOS cứu hộ');
    expect(find.text('Tôi cần SOS cứu hộ'), findsOneWidget);
  });
}
