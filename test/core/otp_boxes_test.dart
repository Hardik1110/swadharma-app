import 'package:astro_connect/core/widgets/otp_boxes.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('shows one digit per box and completes at six', (tester) async {
    final controller = TextEditingController();
    final focus = FocusNode();
    String? completed;
    addTearDown(() {
      controller.dispose();
      focus.dispose();
    });

    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: Padding(
          padding: const EdgeInsets.all(16),
          child: OtpBoxes(
            controller: controller,
            focusNode: focus,
            onCompleted: (v) => completed = v,
          ),
        ),
      ),
    ));

    await tester.enterText(find.byKey(const Key('otp_field')), '123');
    await tester.pump();
    expect(completed, isNull);
    for (final d in ['1', '2', '3']) {
      expect(find.text(d), findsOneWidget);
    }

    // Non-digits are dropped, extra digits beyond six are ignored.
    await tester.enterText(find.byKey(const Key('otp_field')), '12a3456789');
    await tester.pump();
    expect(controller.text, '123456');
    expect(completed, '123456');
    for (final d in ['1', '2', '3', '4', '5', '6']) {
      expect(find.text(d), findsOneWidget);
    }
  });
}
