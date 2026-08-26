import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:flutter_quill/quill_delta.dart';
import 'package:flutter_test/flutter_test.dart';

Future<DefaultStyles> getStyles(WidgetTester tester) async {
  late DefaultStyles result;
  await tester.pumpWidget(MaterialApp(
    builder: (context, _) {
      result = DefaultStyles.getInstance(context);
      return const SizedBox();
    },
  ));
  return result;
}

void main() {
  Line firstLine(Document document) {
    final node = document.root.children.first;
    return (node is Block ? node.children.first : node) as Line;
  }

  Block? firstBlock(Document document) =>
      document.root.children.whereType<Block>().firstOrNull;

  testWidgets('DefaultStyles.fromTheme matches getInstance', (tester) async {
    late BuildContext captured;
    await tester.pumpWidget(MaterialApp(
      builder: (context, _) {
        captured = context;
        return const SizedBox();
      },
    ));
    final viaContext = DefaultStyles.getInstance(captured);
    final viaTheme = DefaultStyles.fromTheme(
      themeData: Theme.of(captured),
      defaultTextStyle: DefaultTextStyle.of(captured).style,
    );
    expect(viaTheme.h1!.style.fontSize, viaContext.h1!.style.fontSize);
    expect(viaTheme.quote!.decoration, viaContext.quote!.decoration);
    expect(viaTheme.lists!.lineSpacing, viaContext.lists!.lineSpacing);
    expect(viaTheme.inlineCode!.style.fontSize,
        viaContext.inlineCode!.style.fontSize);
    expect(viaTheme.placeHolder!.style.color, viaContext.placeHolder!.style.color);
  });

  test('resolveTextAlign defaults and all four alignments', () {
    Line lineOf(String? align) => firstLine(Document.fromDelta(Delta()
      ..insert('text\n',
          align == null ? null : <String, dynamic>{'align': align})));
    expect(resolveTextAlign(lineOf(null)), TextAlign.start);
    expect(resolveTextAlign(lineOf('left')), TextAlign.start);
    expect(resolveTextAlign(lineOf('center')), TextAlign.center);
    expect(resolveTextAlign(lineOf('right')), TextAlign.end);
    expect(resolveTextAlign(lineOf('justify')), TextAlign.justify);
  });

  testWidgets('resolveLineStyle plain paragraph', (tester) async {
    final styles = await getStyles(tester);
    final document = Document.fromDelta(Delta()..insert('plain\n'));
    final style = resolveLineStyle(firstLine(document), styles);
    expect(style.fontSize, styles.paragraph!.style.fontSize);
  });

  testWidgets('resolveLineStyle header maps to heading styles',
      (tester) async {
    final styles = await getStyles(tester);
    for (var level = 1; level <= 6; level++) {
      final document = Document.fromDelta(
          Delta()..insert('title\n', <String, dynamic>{'header': level}));
      final style = resolveLineStyle(firstLine(document), styles);
      final expected = switch (level) {
        1 => styles.h1!.style,
        2 => styles.h2!.style,
        3 => styles.h3!.style,
        4 => styles.h4!.style,
        5 => styles.h5!.style,
        _ => styles.h6!.style,
      };
      expect(style.fontSize, expected.fontSize);
      expect(style.fontWeight, expected.fontWeight);
    }
  });

  testWidgets('resolveLineStyle block quote merges quote style',
      (tester) async {
    final styles = await getStyles(tester);
    final document = Document.fromDelta(
        Delta()..insert('quote\n', <String, dynamic>{'blockquote': true}));
    final style = resolveLineStyle(firstLine(document), styles);
    final expected = styles.paragraph!.style.merge(styles.quote!.style);
    expect(style.fontSize, expected.fontSize);
    expect(style.fontStyle, expected.fontStyle);
  });

  testWidgets('resolveLineStyle placeholder line', (tester) async {
    final styles = await getStyles(tester);
    final document = Document.fromDelta(Delta()
      ..insert('Placeholder\n', <String, dynamic>{'placeholder': 'Hint'}));
    final style = resolveLineStyle(firstLine(document), styles);
    expect(style.color, styles.placeHolder!.style.color);
  });

  testWidgets('resolveLineStyle line height attribute overrides height only',
      (tester) async {
    final styles = await getStyles(tester);
    final document = Document.fromDelta(
        Delta()..insert('text\n', <String, dynamic>{'line-height': 2}));
    final style = resolveLineStyle(firstLine(document), styles);
    expect(style.height, styles.lineHeightDouble!.style.height);
    expect(style.fontSize, styles.paragraph!.style.fontSize);
  });

  testWidgets('resolveInlineTextStyle bold merges bold style',
      (tester) async {
    final styles = await getStyles(tester);
    final res = resolveInlineTextStyle(
        const Style.attr({'bold': Attribute.bold}), styles, const Style(), false);
    expect(res.fontWeight, styles.bold!.fontWeight);
  });

  testWidgets('resolveInlineTextStyle attribute without inline styles',
      (tester) async {
    final styles = await getStyles(tester);
    final res = resolveInlineTextStyle(
        const Style.attr({'list': Attribute.ul}), styles, const Style(), false);
    expect(res.color, isNull);
  });

  testWidgets('resolveInlineTextStyle link with value resolves link style',
      (tester) async {
    final styles = await getStyles(tester);
    final res = resolveInlineTextStyle(
        const Style.attr({'link': LinkAttribute('https://example.com')}),
        styles,
        const Style(),
        true);
    expect(res.color, styles.link!.color);
    expect(res.decoration, styles.link!.decoration);
  });

  testWidgets('resolveInlineTextStyle color string resolves to Color',
      (tester) async {
    final styles = await getStyles(tester);
    final res = resolveInlineTextStyle(
        const Style.attr({'color': ColorAttribute('#ff0000')}),
        styles,
        const Style(),
        false);
    expect(res.color, const Color(0xffff0000));
  });

  testWidgets('resolveInlineTextStyle named size maps to size styles',
      (tester) async {
    final styles = await getStyles(tester);
    final res = resolveInlineTextStyle(
        const Style.attr({'size': SizeAttribute('large')}),
        styles,
        const Style(),
        false);
    expect(res.fontSize, styles.sizeLarge!.fontSize);
  });

  testWidgets('resolveInlineTextStyle numeric size maps to fontSize',
      (tester) async {
    final styles = await getStyles(tester);
    final res = resolveInlineTextStyle(
        const Style.attr({'size': SizeAttribute('18.0')}),
        styles,
        const Style(),
        false);
    expect(res.fontSize, 18.0);
  });

  test('resolveScriptCharStyle reduces size and shifts glyph', () {
    const run = TextStyle(fontSize: 20, fontWeight: FontWeight.w400);
    final superSpec = resolveScriptCharStyle(true, run, const TextStyle());
    expect(superSpec.style.fontSize, 14);
    expect(superSpec.offset.dy, closeTo(-8.0, 1e-9));
    final subSpec = resolveScriptCharStyle(false, run, const TextStyle());
    expect(subSpec.offset.dy, closeTo(2.8, 1e-9));
  });

  testWidgets('resolveLeading plain line has no leading', (tester) async {
    final styles = await getStyles(tester);
    final document = Document.fromDelta(Delta()..insert('plain\n'));
    expect(resolveLeading(firstLine(document), styles, 1, 1), isNull);
  });

  testWidgets('resolveLeading bullet width is fontSize * 2', (tester) async {
    final styles = await getStyles(tester);
    final document = Document.fromDelta(
        Delta()..insert('item\n', <String, dynamic>{'list': 'bullet'}));
    final spec = resolveLeading(firstLine(document), styles, 1, 1);
    expect(spec!.kind, LeadingKind.bullet);
    expect(spec.width, 32);
    expect(spec.padding, 8);
    expect(spec.style!.fontWeight, FontWeight.bold);
  });

  testWidgets('resolveLeading ordered carries index', (tester) async {
    final styles = await getStyles(tester);
    final document = Document.fromDelta(
        Delta()..insert('first\n', <String, dynamic>{'list': 'ordered'}));
    final spec = resolveLeading(firstLine(document), styles, 1, 3);
    expect(spec!.kind, LeadingKind.number);
    expect(spec.index, 1);
    expect(spec.width, 32);
  });

  testWidgets('resolveLeading checkbox carries size and value',
      (tester) async {
    final styles = await getStyles(tester);
    final document = Document.fromDelta(
        Delta()..insert('todo\n', <String, dynamic>{'list': 'checked'}));
    final spec = resolveLeading(firstLine(document), styles, 1, 1);
    expect(spec!.kind, LeadingKind.checkbox);
    expect(spec.checked, isTrue);
    expect(spec.lineSize, 16);
    expect(spec.width, isNull);
  });

  test('resolveIndexNumberByIndent sequential numbering without indent', () {
    final counts = <int, int>{};
    const attrs = <String, Attribute>{};
    expect(resolveIndexNumberByIndent(1, attrs, counts), '1');
    expect(resolveIndexNumberByIndent(2, attrs, counts), '2');
    expect(resolveIndexNumberByIndent(3, attrs, counts), '3');
  });

  test('resolveIndexNumberByIndent indent levels use letters then romans',
      () {
    final counts = <int, int>{};
    const attrsLevel1 = <String, Attribute>{
      'indent': IndentAttribute(level: 1),
    };
    expect(resolveIndexNumberByIndent(1, attrsLevel1, counts), 'a');
    expect(resolveIndexNumberByIndent(2, attrsLevel1, counts), 'b');
    const attrsLevel2 = <String, Attribute>{
      'indent': IndentAttribute(level: 2),
    };
    expect(resolveIndexNumberByIndent(1, attrsLevel2, counts), 'i');
    expect(resolveIndexNumberByIndent(2, attrsLevel2, counts), 'ii');
  });

  test('resolveIndexNumberByIndent back from indent restarts top level', () {
    final counts = <int, int>{};
    const attrs = <String, Attribute>{};
    const attrsLevel1 = <String, Attribute>{
      'indent': IndentAttribute(level: 1),
    };
    expect(resolveIndexNumberByIndent(1, attrs, counts), '1');
    expect(resolveIndexNumberByIndent(1, attrsLevel1, counts), 'a');
    expect(resolveIndexNumberByIndent(2, attrs, counts), '2');
  });

  testWidgets('resolveSpacingForLine first drops top, last drops bottom',
      (tester) async {
    final styles = await getStyles(tester);
    final document = Document.fromDelta(Delta()
      ..insert('one\n', <String, dynamic>{'list': 'bullet'})
      ..insert('two\n', <String, dynamic>{'list': 'bullet'}));
    final block = firstBlock(document);
    final spacing = resolveSpacingForLine(block!, 1, 2, styles);
    expect(spacing.top, 0.0);
    expect(spacing.bottom, styles.lists!.lineSpacing.bottom);
    final spacing2 = resolveSpacingForLine(block, 2, 2, styles);
    expect(spacing2.top, styles.lists!.lineSpacing.top);
    expect(spacing2.bottom, 0.0);
  });

  testWidgets('resolveIndentSpacing bullet list indents by fontSize * 2',
      (tester) async {
    final styles = await getStyles(tester);
    final document = Document.fromDelta(
        Delta()..insert('item\n', <String, dynamic>{'list': 'bullet'}));
    final block = firstBlock(document);
    final spacing = resolveIndentSpacing(
        block!, styles, 1, TextBlockUtils.defaultNumberPointWidthBuilder);
    expect(spacing.left, 32.0);
  });

  testWidgets('resolveIndentSpacing quote indents by fontSize',
      (tester) async {
    final styles = await getStyles(tester);
    final document = Document.fromDelta(
        Delta()..insert('quote\n', <String, dynamic>{'blockquote': true}));
    final block = firstBlock(document);
    final spacing = resolveIndentSpacing(
        block!, styles, 1, TextBlockUtils.defaultNumberPointWidthBuilder);
    expect(spacing.left, 16.0);
  });

  testWidgets('resolveBlockDecoration quote and code block', (tester) async {
    final styles = await getStyles(tester);
    final quoteDocument = Document.fromDelta(
        Delta()..insert('quote\n', <String, dynamic>{'blockquote': true}));
    final quoteBlock = firstBlock(quoteDocument);
    expect(
      resolveBlockDecoration(quoteBlock!, styles, TextDirection.ltr),
      styles.quote!.decoration,
    );

    final codeDocument = Document.fromDelta(
        Delta()..insert('code\n', <String, dynamic>{'code-block': true}));
    final codeBlock = firstBlock(codeDocument);
    expect(
      resolveBlockDecoration(codeBlock!, styles, TextDirection.ltr),
      styles.code!.decoration,
    );
  });

  testWidgets('resolveBlockDecoration rtl quote moves the bar right',
      (tester) async {
    final styles = await getStyles(tester);
    final quoteDocument = Document.fromDelta(
        Delta()..insert('quote\n', <String, dynamic>{'blockquote': true}));
    final quoteBlock = firstBlock(quoteDocument);
    final rtl = resolveBlockDecoration(quoteBlock!, styles, TextDirection.rtl);
    expect((rtl!.border as Border).right.width, 4.0);
    expect((rtl.border as Border).left.width, 0.0);
  });
}
