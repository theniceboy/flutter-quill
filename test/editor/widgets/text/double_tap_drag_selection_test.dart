import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:flutter_quill/src/editor/editor.dart';
import 'package:flutter_quill_test/flutter_quill_test.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late QuillController controller;

  setUp(() {
    controller = QuillController.basic();
  });

  tearDown(() {
    controller.dispose();
  });

  Future<RenderEditor> pumpEditor(WidgetTester tester, String text) async {
    await tester.pumpWidget(
      MaterialApp(
        home: QuillEditor.basic(
          controller: controller,
          config: const QuillEditorConfig(autoFocus: true),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.quillEnterText(find.byType(QuillEditor), text);
    await tester.pumpAndSettle();
    return tester.allRenderObjects.whereType<RenderEditor>().first;
  }

  Offset globalCaretCenter(RenderEditor editor, int offset) =>
      editor.localToGlobal(
        editor.getLocalRectForCaret(TextPosition(offset: offset)).centerLeft,
      );

  testWidgets('double tap selects a word', (tester) async {
    final editor = await pumpEditor(tester, 'first second\n');

    final gesture = await tester.startGesture(
      globalCaretCenter(editor, 2),
      kind: PointerDeviceKind.mouse,
    );
    await tester.pump();
    await gesture.up();
    await tester.pump();

    final doubleTap = await tester.startGesture(
      globalCaretCenter(editor, 2),
      kind: PointerDeviceKind.mouse,
    );
    await tester.pump();
    await doubleTap.up();
    await tester.pump();

    expect(
      controller.selection,
      const TextSelection(baseOffset: 0, extentOffset: 5),
    );
  });

  testWidgets('double tap and drag extends selection word by word',
      (tester) async {
    final editor = await pumpEditor(tester, 'first second third\n');

    final start = globalCaretCenter(editor, 2);

    final gesture = await tester.startGesture(
      start,
      kind: PointerDeviceKind.mouse,
    );
    await tester.pump();
    await gesture.up();
    await tester.pump();

    final doubleTap = await tester.startGesture(
      start,
      kind: PointerDeviceKind.mouse,
    );
    await tester.pump(kPressTimeout);

    // The word under the double tap is selected before the drag starts.
    expect(
      controller.selection,
      const TextSelection(baseOffset: 0, extentOffset: 5),
    );

    // Drag into 'third'; the throttle fires the update after 50ms.
    await doubleTap.moveBy(
      globalCaretCenter(editor, 15) - start,
    );
    await tester.pump(const Duration(milliseconds: 50));
    await doubleTap.up();
    await tester.pump();

    expect(
      controller.selection,
      const TextSelection(baseOffset: 0, extentOffset: 18),
    );
  });

  testWidgets('double tap and drag backwards anchors the word end',
      (tester) async {
    final editor = await pumpEditor(tester, 'first second third\n');

    final start = globalCaretCenter(editor, 8);

    final gesture = await tester.startGesture(
      start,
      kind: PointerDeviceKind.mouse,
    );
    await tester.pump();
    await gesture.up();
    await tester.pump();

    final doubleTap = await tester.startGesture(
      start,
      kind: PointerDeviceKind.mouse,
    );
    await tester.pump(kPressTimeout);

    expect(
      controller.selection,
      const TextSelection(baseOffset: 6, extentOffset: 12),
    );

    await doubleTap.moveBy(
      globalCaretCenter(editor, 2) - start,
    );
    await tester.pump(const Duration(milliseconds: 50));
    await doubleTap.up();
    await tester.pump();

    expect(
      controller.selection,
      const TextSelection(baseOffset: 0, extentOffset: 12),
    );
  });

  testWidgets('single click drag still selects character-wise',
      (tester) async {
    final editor = await pumpEditor(tester, 'first second\n');

    final start = globalCaretCenter(editor, 0);

    final gesture = await tester.startGesture(
      start,
      kind: PointerDeviceKind.mouse,
    );
    await tester.pump();

    await gesture.moveBy(
      globalCaretCenter(editor, 2) - start,
    );
    await tester.pump(const Duration(milliseconds: 50));
    await gesture.up();
    await tester.pump();

    expect(
      controller.selection,
      const TextSelection(baseOffset: 0, extentOffset: 2),
    );
  });
}
