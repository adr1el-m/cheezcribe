import 'package:appcon_ai_lab/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('Unconfigured app prevents requests and explains setup',
      (tester) async {
    await tester.pumpWidget(const AiLab(configured: false));
    expect(find.textContaining('Setup needed:'), findsOneWidget);
    final button = tester.widget<FilledButton>(find.byType(FilledButton));
    expect(button.onPressed, isNull);
    expect(find.text('Model response'), findsNothing);
    await tester.enterText(find.byType(TextField), 'A harmless prompt');
    expect(tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
        isNull);
  });
}
