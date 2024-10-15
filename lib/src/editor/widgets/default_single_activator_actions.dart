import 'package:flutter/material.dart'
    show
        AxisDirection,
        Intent,
        RedoTextIntent,
        ScrollIncrementType,
        ScrollIntent,
        ScrollToDocumentBoundaryIntent,
        SelectAllTextIntent,
        SelectionChangedCause,
        SingleActivator,
        UndoTextIntent;
import 'package:flutter/services.dart'
    show LogicalKeyboardKey, SelectionChangedCause;

import '../../document/attribute.dart';
import '../raw_editor/raw_editor_actions.dart'
    show
        HideSelectionToolbarIntent,
        IndentSelectionIntent,
        OpenSearchIntent,
        QuillEditorApplyCheckListIntent,
        QuillEditorApplyHeaderIntent,
        QuillEditorApplyLinkIntent,
        QuillEditorInsertEmbedIntent,
        ToggleTextStyleIntent;

Map<SingleActivator, Intent> defaultSinlgeActivatorActions(
  bool isDesktopMacOS, {
  required bool handleEscapeKey,
  required bool handleFormattingKeys,
  required bool handleImageKey,
  required bool allowLists,
  required bool allowCheckLists,
}) =>
    {
      if (handleEscapeKey)
        const SingleActivator(
          LogicalKeyboardKey.escape,
        ): const HideSelectionToolbarIntent(),
      SingleActivator(
        LogicalKeyboardKey.keyA,
        control: !isDesktopMacOS,
        meta: isDesktopMacOS,
      ): const SelectAllTextIntent(SelectionChangedCause.keyboard),
      SingleActivator(
        LogicalKeyboardKey.keyZ,
        control: !isDesktopMacOS,
        meta: isDesktopMacOS,
      ): const UndoTextIntent(SelectionChangedCause.keyboard),
      SingleActivator(
        LogicalKeyboardKey.keyY,
        control: !isDesktopMacOS,
        meta: isDesktopMacOS,
      ): const RedoTextIntent(SelectionChangedCause.keyboard),

      // Selection formatting.
      if (handleFormattingKeys)
        SingleActivator(
          LogicalKeyboardKey.keyB,
          control: !isDesktopMacOS,
          meta: isDesktopMacOS,
        ): const ToggleTextStyleIntent(Attribute.bold),
      if (handleFormattingKeys)
        SingleActivator(
          LogicalKeyboardKey.keyU,
          control: !isDesktopMacOS,
          meta: isDesktopMacOS,
        ): const ToggleTextStyleIntent(Attribute.underline),
      if (handleFormattingKeys)
        SingleActivator(
          LogicalKeyboardKey.keyI,
          control: !isDesktopMacOS,
          meta: isDesktopMacOS,
        ): const ToggleTextStyleIntent(Attribute.italic),
      if (handleFormattingKeys)
        SingleActivator(
          LogicalKeyboardKey.keyS,
          control: !isDesktopMacOS,
          meta: isDesktopMacOS,
          shift: true,
        ): const ToggleTextStyleIntent(Attribute.strikeThrough),
      if (handleFormattingKeys)
        SingleActivator(
          LogicalKeyboardKey.backquote,
          control: !isDesktopMacOS,
          meta: isDesktopMacOS,
        ): const ToggleTextStyleIntent(Attribute.inlineCode),
      if (handleFormattingKeys)
        SingleActivator(
          LogicalKeyboardKey.tilde,
          control: !isDesktopMacOS,
          meta: isDesktopMacOS,
          shift: true,
        ): const ToggleTextStyleIntent(Attribute.codeBlock),
      if (handleFormattingKeys)
        SingleActivator(
          LogicalKeyboardKey.keyB,
          control: !isDesktopMacOS,
          meta: isDesktopMacOS,
          shift: true,
        ): const ToggleTextStyleIntent(Attribute.blockQuote),
      if (handleFormattingKeys)
        SingleActivator(
          LogicalKeyboardKey.keyK,
          control: !isDesktopMacOS,
          meta: isDesktopMacOS,
        ): const QuillEditorApplyLinkIntent(),

      // Lists
      if (allowLists)
        SingleActivator(
          LogicalKeyboardKey.keyL,
          control: !isDesktopMacOS,
          meta: isDesktopMacOS,
          shift: true,
        ): const ToggleTextStyleIntent(Attribute.ul),
      if (allowLists)
        SingleActivator(
          LogicalKeyboardKey.keyO,
          control: !isDesktopMacOS,
          meta: isDesktopMacOS,
          shift: true,
        ): const ToggleTextStyleIntent(Attribute.ol),
      if (allowCheckLists)
        SingleActivator(
          LogicalKeyboardKey.keyC,
          control: !isDesktopMacOS,
          meta: isDesktopMacOS,
          shift: true,
        ): const QuillEditorApplyCheckListIntent(),

      // Indents
      if (handleFormattingKeys)
        SingleActivator(
          LogicalKeyboardKey.keyM,
          control: !isDesktopMacOS,
          meta: isDesktopMacOS,
        ): const IndentSelectionIntent(true),
      if (handleFormattingKeys)
        SingleActivator(
          LogicalKeyboardKey.keyM,
          control: !isDesktopMacOS,
          meta: isDesktopMacOS,
          shift: true,
        ): const IndentSelectionIntent(false),

      // Headers
      if (handleFormattingKeys)
        SingleActivator(
          LogicalKeyboardKey.digit1,
          control: !isDesktopMacOS,
          meta: isDesktopMacOS,
        ): const QuillEditorApplyHeaderIntent(Attribute.h1),
      if (handleFormattingKeys)
        SingleActivator(
          LogicalKeyboardKey.digit2,
          control: !isDesktopMacOS,
          meta: isDesktopMacOS,
        ): const QuillEditorApplyHeaderIntent(Attribute.h2),
      if (handleFormattingKeys)
        SingleActivator(
          LogicalKeyboardKey.digit3,
          control: !isDesktopMacOS,
          meta: isDesktopMacOS,
        ): const QuillEditorApplyHeaderIntent(Attribute.h3),
      if (handleFormattingKeys)
        SingleActivator(
          LogicalKeyboardKey.digit4,
          control: !isDesktopMacOS,
          meta: isDesktopMacOS,
        ): const QuillEditorApplyHeaderIntent(Attribute.h4),
      if (handleFormattingKeys)
        SingleActivator(
          LogicalKeyboardKey.digit5,
          control: !isDesktopMacOS,
          meta: isDesktopMacOS,
        ): const QuillEditorApplyHeaderIntent(Attribute.h5),
      if (handleFormattingKeys)
        SingleActivator(
          LogicalKeyboardKey.digit6,
          control: !isDesktopMacOS,
          meta: isDesktopMacOS,
        ): const QuillEditorApplyHeaderIntent(Attribute.h6),
      if (handleFormattingKeys)
        SingleActivator(
          LogicalKeyboardKey.digit0,
          control: !isDesktopMacOS,
          meta: isDesktopMacOS,
        ): const QuillEditorApplyHeaderIntent(Attribute.header),
      if (handleImageKey)
        SingleActivator(
          LogicalKeyboardKey.keyG,
          control: !isDesktopMacOS,
          meta: isDesktopMacOS,
        ): const QuillEditorInsertEmbedIntent(Attribute.image),

      if (handleFormattingKeys)
        SingleActivator(
          LogicalKeyboardKey.keyF,
          control: !isDesktopMacOS,
          meta: isDesktopMacOS,
        ): const OpenSearchIntent(),

      // Navigate to the start or end of the document
      SingleActivator(
        LogicalKeyboardKey.home,
        control: !isDesktopMacOS,
        meta: isDesktopMacOS,
      ): const ScrollToDocumentBoundaryIntent(forward: false),
      SingleActivator(
        LogicalKeyboardKey.end,
        control: !isDesktopMacOS,
        meta: isDesktopMacOS,
      ): const ScrollToDocumentBoundaryIntent(forward: true),

      //  Arrow key scrolling
      SingleActivator(
        LogicalKeyboardKey.arrowUp,
        control: !isDesktopMacOS,
        meta: isDesktopMacOS,
      ): const ScrollIntent(direction: AxisDirection.up),
      SingleActivator(
        LogicalKeyboardKey.arrowDown,
        control: !isDesktopMacOS,
        meta: isDesktopMacOS,
      ): const ScrollIntent(direction: AxisDirection.down),
      SingleActivator(
        LogicalKeyboardKey.pageUp,
        control: !isDesktopMacOS,
        meta: isDesktopMacOS,
      ): const ScrollIntent(
          direction: AxisDirection.up, type: ScrollIncrementType.page),
      SingleActivator(
        LogicalKeyboardKey.pageDown,
        control: !isDesktopMacOS,
        meta: isDesktopMacOS,
      ): const ScrollIntent(
          direction: AxisDirection.down, type: ScrollIncrementType.page),
    };
