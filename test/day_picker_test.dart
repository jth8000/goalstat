import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:goalstat/widgets/day_picker_dialog.dart';

void main() {
  testWidgets('day picker fits on a phone screen and Cancel closes it',
      (tester) async {
    tester.view.physicalSize = const Size(1080, 2340);
    tester.view.devicePixelRatio = 2.75;
    addTearDown(tester.view.reset);

    DateTime? result = DateTime(1999);
    await tester.pumpWidget(MaterialApp(
      home: Builder(
        builder: (context) => TextButton(
          onPressed: () async => result = await showDayPicker(context,
              initialDay: DateTime.now(), loggedDates: const {}),
          child: const Text('open'),
        ),
      ),
    ));

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    // Overflow would have thrown during layout.
    expect(find.text('Cancel'), findsOneWidget);

    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(result, isNull);
  });
}
