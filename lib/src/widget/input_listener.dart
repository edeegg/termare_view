import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';

// copy from xterm.dart
typedef KeyStrokeHandler = void Function(RawKeyEvent);
typedef InputHandler = TextEditingValue? Function(TextEditingValue);
typedef ActionHandler = void Function(TextInputAction);
typedef FocusHandler = void Function(bool);

abstract class InputListenerController {
  void requestKeyboard();
}

class InputListener extends StatefulWidget {
  const InputListener({
    required this.child,
    required this.onKeyStroke,
    required this.onTextInput,
    required this.onAction,
    required this.focusNode,
    this.onFocus,
    this.autofocus = false,
    this.listenKeyStroke = true,
    this.readOnly = false,
    this.initEditingState = const TextEditingValue(
      text: '  ',
      selection: TextSelection.collapsed(offset: 1),
    ),
  });

  final Widget child;
  final InputHandler onTextInput;
  final KeyStrokeHandler onKeyStroke;
  final ActionHandler? onAction;
  final FocusHandler? onFocus;
  final bool autofocus;
  final FocusNode focusNode;
  final bool listenKeyStroke;
  final bool readOnly;
  final TextEditingValue initEditingState;

  @override
  InputListenerState createState() => InputListenerState();

  static InputListenerController? of(BuildContext context) {
    return context.findAncestorStateOfType<InputListenerState>();
  }
}

class InputListenerState extends State<InputListener>
    implements InputListenerController {
  TextInputConnection? _conn;
  FocusAttachment? _focusAttachment;
  bool _didAutoFocus = false;

  @override
  void initState() {
    _focusAttachment = widget.focusNode.attach(context);
    widget.focusNode.addListener(onFocusChange);
    super.initState();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_didAutoFocus && widget.autofocus) {
      _didAutoFocus = true;
      SchedulerBinding.instance!.addPostFrameCallback((_) {
        if (mounted) {
          FocusScope.of(context).autofocus(widget.focusNode);
        }
      });
    }
  }

  bool get _shouldCreateInputConnection => kIsWeb || !widget.readOnly;
  bool get _hasInputConnection => _conn != null && _conn!.attached;

  @override
  void didUpdateWidget(InputListener oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.focusNode != oldWidget.focusNode) {
      oldWidget.focusNode.removeListener(onFocusChange);
      _focusAttachment?.detach();
      _focusAttachment = widget.focusNode.attach(context);
      widget.focusNode.addListener(onFocusChange);
    }
    if (!_shouldCreateInputConnection) {
      closeInputConnectionIfNeeded();
    } else {
      if (oldWidget.readOnly && widget.focusNode.hasFocus) {
        openInputConnection();
      }
    }
  }

  @override
  void dispose() {
    _focusAttachment!.detach();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    _focusAttachment!.reparent();
    if (widget.listenKeyStroke) {
      return RawKeyboardListener(
        focusNode: widget.focusNode,
        onKey: widget.onKeyStroke,
        autofocus: widget.autofocus,
        child: widget.child,
      );
    }
    return Focus(
      focusNode: widget.focusNode,
      autofocus: widget.autofocus,
      includeSemantics: false,
      child: widget.child,
    );
  }

  @override
  void requestKeyboard() {
    if (widget.focusNode.hasFocus) {
      openInputConnection();
    } else {
      widget.focusNode.requestFocus();
    }
  }

  void onFocusChange() {
    if (widget.onFocus != null) widget.onFocus!(widget.focusNode.hasFocus);
    openOrCloseInputConnectionIfNeeded();
  }

  void openOrCloseInputConnectionIfNeeded() {
    if (widget.focusNode.hasFocus && widget.focusNode.consumeKeyboardToken()) {
      openInputConnection();
    } else if (!widget.focusNode.hasFocus) {
      closeInputConnectionIfNeeded();
    }
  }

  void openInputConnection() {
    if (!_shouldCreateInputConnection) return;
    if (_hasInputConnection) {
      _conn!.show();
    } else {
      const config = TextInputConfiguration();
      final client = TerminalTextInputClient(onInput, onAction);
      _conn = TextInput.attach(client, config);
      _conn!.show();
      _conn!.setEditableSizeAndTransform(
        const Size(10, 10),
        Matrix4.translationValues(0, 0, 0),
      );
      _conn!.setEditingState(widget.initEditingState);
    }
  }

  void closeInputConnectionIfNeeded() {
    if (_conn != null && _conn!.attached) {
      _conn!.close();
      _conn = null;
    }
  }

  void onInput(TextEditingValue value) {
    final newValue = widget.onTextInput(value);
    if (newValue != null) _conn?.setEditingState(newValue);
  }

  void onAction(TextInputAction action) {
    widget.onAction?.call(action);
  }
}

/// Cliente personalizado de entrada de texto
class TerminalTextInputClient implements TextInputClient {
  TerminalTextInputClient(
    this.onInput,
    this.onAction,
  );

  final void Function(TextEditingValue) onInput;
  final ActionHandler onAction;
  TextEditingValue? _savedValue;

  // Getters obrigatórios
  @override
  TextEditingValue get currentTextEditingValue =>
      _savedValue ?? const TextEditingValue();  // :contentReference[oaicite:4]{index=4}

  @override
  AutofillScope? get currentAutofillScope => null;           // :contentReference[oaicite:5]{index=5}

  // Atualizações de edição e ações
  @override
  void updateEditingValue(TextEditingValue value) {         // :contentReference[oaicite:6]{index=6}
    onInput(value);
    _savedValue = value;
  }

  @override
  void performAction(TextInputAction action) {              // :contentReference[oaicite:7]{index=7}
    onAction(action);
  }

  // Cursor flutuante e autocorreção
  @override
  void updateFloatingCursor(RawFloatingCursorPoint point) {} // :contentReference[oaicite:8]{index=8}

  @override
  void showAutocorrectionPromptRect(int start, int end) {}   // :contentReference[oaicite:9]{index=9}

  @override
  void connectionClosed() {}                                 // :contentReference[oaicite:10]{index=10}

  @override
  void performPrivateCommand(String action, Map<String, dynamic> data) {} // :contentReference[oaicite:11]{index=11}

  @override
  void insertContent(KeyboardInsertedContent content) {}     // :contentReference[oaicite:12]{index=12}

  // Novas implementações obrigatórias:
  @override
  void insertTextPlaceholder(Size size) {}                   // :contentReference[oaicite:13]{index=13}

  @override
  void removeTextPlaceholder() {}                            // :contentReference[oaicite:14]{index=14}

  @override
  void performSelector(String selectorName) {}               // :contentReference[oaicite:15]{index=15}

  @override
  void showToolbar() {}                                      // :contentReference[oaicite:16]{index=16}

  @override
  void didChangeInputControl(
    TextInputControl? oldControl,
    TextInputControl? newControl,
  ) {}                                                       // :contentReference[oaicite:17]{index=17}
}
