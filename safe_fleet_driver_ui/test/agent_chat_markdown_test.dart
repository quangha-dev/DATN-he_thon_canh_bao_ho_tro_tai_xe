import 'package:flutter/material.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:safe_fleet_driver_ui/features/agent/agent_chat_screen.dart';

void main() {
  testWidgets('assistant messages render Markdown instead of raw asterisks', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: AgentMessageBubble(
            user: false,
            text: '1. **Chuyến đi**: DEMO-001\n   - **Xe**: 001',
          ),
        ),
      ),
    );

    expect(find.byType(MarkdownBody), findsOneWidget);

    expect(
      find.textContaining('Chuyến đi', findRichText: true),
      findsOneWidget,
    );
    expect(find.textContaining('Xe', findRichText: true), findsOneWidget);
    expect(find.textContaining('**', findRichText: true), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('user messages remain plain text', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: AgentMessageBubble(user: true, text: '**tin nhắn**'),
        ),
      ),
    );

    expect(find.byType(MarkdownBody), findsNothing);
    expect(find.text('**tin nhắn**'), findsOneWidget);
  });
}
