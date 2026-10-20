import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late QuillController controller;

  tearDown(() {
    controller.dispose();
    debugDefaultTargetPlatformOverride = null;
  });

  List<List<List<num>>> sentRects(WidgetTester tester) => [
        for (final call in tester.testTextInput.log)
          if (call.method == 'TextInput.setSelectionRects')
            [for (final r in call.arguments as List) (r as List).cast<num>()],
      ];

  late Widget editorWidget;

  Widget app(double scale) => MaterialApp(
        home: Scaffold(
          body: Transform.scale(
            scale: scale,
            alignment: Alignment.topLeft,
            child: editorWidget,
          ),
        ),
      );

  Future<RenderEditor> pumpEditor(WidgetTester tester, String text,
      {bool enableScribble = true,
      double scale = 1,
      Document? document,
      FocusNode? focusNode}) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    controller = QuillController(
      document: document ?? (Document()..insert(0, text)),
      selection: const TextSelection.collapsed(offset: 0),
    );
    editorWidget = QuillEditor.basic(
      controller: controller,
      focusNode: focusNode,
      config: QuillEditorConfig(
        autoFocus: true,
        enableScribble: enableScribble,
        embedBuilders: [_BoxEmbedBuilder()],
      ),
    );
    await tester.pumpWidget(app(scale));
    await tester.pumpAndSettle();
    return tester.allRenderObjects.whereType<RenderEditor>().first;
  }

  QuillRawEditorState rawState(WidgetTester tester) =>
      tester.state<QuillRawEditorState>(find.byType(QuillRawEditor));

  testWidgets('sends one rect per character with document positions',
      (tester) async {
    final editor = await pumpEditor(tester, 'ab\ncd');
    expect(sentRects(tester), isNotEmpty);
    final rects = sentRects(tester).last;
    expect(rects.map((r) => r[4]).toList(), [0, 1, 2, 3, 4, 5]);

    final bRect = editor.getLocalRectForCaret(const TextPosition(offset: 1));
    expect(rects[1][0], closeTo(bRect.left, 1));
    final cRect = editor.getLocalRectForCaret(const TextPosition(offset: 3));
    expect(rects[3][1], greaterThan(rects[0][1]));
    expect(rects[3][0], closeTo(cRect.left, 1));
    debugDefaultTargetPlatformOverride = null;
  });

  testWidgets('sends nothing when scribble is off', (tester) async {
    await pumpEditor(tester, 'ab', enableScribble: false);
    expect(sentRects(tester), isEmpty);
    debugDefaultTargetPlatformOverride = null;
  });

  testWidgets('placeholder opens an empty line at the caret, not in the doc',
      (tester) async {
    final editor = await pumpEditor(tester, 'hello world');
    controller.updateSelection(
        const TextSelection.collapsed(offset: 5), ChangeSource.local);
    await tester.pumpAndSettle();
    final before = editor.size.height;
    final worldBefore =
        editor.getLocalRectForCaret(const TextPosition(offset: 6));

    rawState(tester).insertTextPlaceholder(const Size(100, 20));
    await tester.pumpAndSettle();
    expect(controller.document.toPlainText(), 'hello world\n');
    expect(editor.size.height, greaterThan(before));

    final world = sentRects(tester).last.firstWhere((r) => r[4] == 6);
    expect(world[1], greaterThan(worldBefore.top + 1));
    expect(sentRects(tester).last.map((r) => r[4]),
        containsAll(<int>[0, 1, 2, 3, 4, 6, 7, 8, 9, 10, 11]));

    rawState(tester).removeTextPlaceholder();
    await tester.pumpAndSettle();
    expect(editor.size.height, before);
    expect(sentRects(tester).last.firstWhere((r) => r[4] == 6)[1],
        closeTo(worldBefore.top, 1));
    debugDefaultTargetPlatformOverride = null;
  });

  testWidgets('scribble focus puts the caret at the pen', (tester) async {
    final editor = await pumpEditor(tester, 'hello world');
    final at = editor.localToGlobal(
        editor.getLocalRectForCaret(const TextPosition(offset: 3)).center);
    TextInput.scribbleClients.values.single.onScribbleFocus(at);
    await tester.pumpAndSettle();
    expect(controller.selection.baseOffset, 3);
    debugDefaultTargetPlatformOverride = null;
  });

  testWidgets('scaled editor reports on-screen geometry', (tester) async {
    final editor = await pumpEditor(tester, 'ab\ncd', scale: 2);
    final log = tester.testTextInput.log;
    final sizeCall = log
        .lastWhere((c) => c.method == 'TextInput.setEditableSizeAndTransform');
    final args = sizeCall.arguments as Map;
    final screen = MatrixUtils.transformRect(
        editor.getTransformTo(null), Offset.zero & editor.size);
    expect(args['width'], closeTo(screen.width, 0.01));
    expect(args['height'], closeTo(screen.height, 0.01));
    final matrix = (args['transform'] as List).cast<num>();
    expect(matrix[0], 1);
    expect(matrix[5], 1);
    expect(matrix[12], closeTo(screen.left, 0.01));
    expect(matrix[13], closeTo(screen.top, 0.01));

    final rects = sentRects(tester).last;
    List<num> at(int i) => rects.firstWhere((r) => r[4] == i);
    Rect caret(int i) => editor.getLocalRectForCaret(TextPosition(offset: i));
    expect(
        at(1)[0] - at(0)[0], closeTo((caret(1).left - caret(0).left) * 2, 1));
    expect(at(3)[1] - at(0)[1], closeTo((caret(3).top - caret(0).top) * 2, 1));
    expect(at(0)[2], closeTo((caret(1).left - caret(0).left) * 2, 1));
    expect(at(0)[0], inInclusiveRange(0, 40));
    debugDefaultTargetPlatformOverride = null;
  });

  testWidgets('zooming while editing resends scaled rects', (tester) async {
    await pumpEditor(tester, 'ab\ncd');
    final width = sentRects(tester).last[0][2];

    await tester.pumpWidget(app(2));
    await tester.pumpAndSettle();
    expect(sentRects(tester).last[0][2], closeTo(width * 2, 0.5));
    debugDefaultTargetPlatformOverride = null;
  });

  testWidgets('a gap at a block embed leaves the embed line as is',
      (tester) async {
    final document = Document()
      ..insert(0, 'ab\n')
      ..insert(3, const BlockEmbed('box', ''));
    final editor = await pumpEditor(tester, '', document: document);
    controller.updateSelection(
        const TextSelection.collapsed(offset: 3), ChangeSource.local);
    await tester.pumpAndSettle();
    List<SelectionRect> rects() {
      final out = <SelectionRect>[];
      editor.addScribbleSelectionRects(
          out, Offset.zero, Offset.zero & editor.size);
      return out;
    }

    final before = rects();
    rawState(tester).insertTextPlaceholder(const Size(100, 20));
    await tester.pumpAndSettle();
    expect(rects(), before);
    debugDefaultTargetPlatformOverride = null;
  });

  testWidgets('losing focus drops the gap', (tester) async {
    final focusNode = FocusNode();
    addTearDown(focusNode.dispose);
    final editor =
        await pumpEditor(tester, 'hello world', focusNode: focusNode);
    final before = editor.size.height;
    rawState(tester).insertTextPlaceholder(const Size(100, 20));
    await tester.pumpAndSettle();
    expect(editor.size.height, greaterThan(before));

    focusNode.unfocus();
    await tester.pumpAndSettle();
    expect(rawState(tester).scribblePlaceholder, isNull);
    expect(editor.size.height, before);
    debugDefaultTargetPlatformOverride = null;
  });
}

class _BoxEmbedBuilder extends EmbedBuilder {
  @override
  String get key => 'box';

  @override
  Widget build(BuildContext context, EmbedContext embedContext) =>
      const SizedBox(height: 40, width: 40);
}
