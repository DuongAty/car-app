import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Remote/D-pad friendly tile. Reports real focus (not just the keyboard
/// highlight) so an autofocused element reads as focused at rest, which is how
/// the karaoke screens present their default selection.
class FocusableTile extends StatefulWidget {
  const FocusableTile({
    super.key,
    required this.builder,
    required this.onPressed,
    this.focusNode,
    this.autofocus = false,
    this.onFocusChange,
    this.onLongPress,
  });

  final Widget Function(BuildContext context, bool focused) builder;
  final VoidCallback onPressed;
  final FocusNode? focusNode;
  final bool autofocus;
  final ValueChanged<bool>? onFocusChange;
  final VoidCallback? onLongPress;

  @override
  State<FocusableTile> createState() => _FocusableTileState();
}

class _FocusableTileState extends State<FocusableTile> {
  bool _focused = false;

  void _handleFocusChange(bool value) {
    if (_focused != value) {
      setState(() => _focused = value);
    }
    widget.onFocusChange?.call(value);
  }

  @override
  Widget build(BuildContext context) {
    return FocusableActionDetector(
      focusNode: widget.focusNode,
      autofocus: widget.autofocus,
      onFocusChange: _handleFocusChange,
      mouseCursor: SystemMouseCursors.click,
      shortcuts: const {
        SingleActivator(LogicalKeyboardKey.enter): ActivateIntent(),
        SingleActivator(LogicalKeyboardKey.space): ActivateIntent(),
        SingleActivator(LogicalKeyboardKey.select): ActivateIntent(),
      },
      actions: {
        ActivateIntent: CallbackAction<ActivateIntent>(
          onInvoke: (intent) {
            widget.onPressed();
            return null;
          },
        ),
      },
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onLongPress: widget.onLongPress,
        onTap: () {
          widget.focusNode?.requestFocus();
          widget.onPressed();
        },
        child: widget.builder(context, _focused),
      ),
    );
  }
}
