import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_icons.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/shared/widgets/liquid_glass.dart';
import '../../../../core/shared/widgets/surface_scope.dart';

/// Native editable field for the browser. It deliberately uses [TextField]
/// so Android opens the installed system keyboard instead of an in-app one.
class NativeSongSearchField extends StatefulWidget {
  const NativeSongSearchField({
    super.key,
    required this.query,
    required this.placeholder,
    required this.onChanged,
    required this.onSubmitted,
  });

  final String query;
  final String placeholder;
  final ValueChanged<String> onChanged;
  final Future<void> Function() onSubmitted;

  @override
  State<NativeSongSearchField> createState() => _NativeSongSearchFieldState();
}

class _NativeSongSearchFieldState extends State<NativeSongSearchField> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.query);
  }

  @override
  void didUpdateWidget(covariant NativeSongSearchField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.query == _controller.text) {
      return;
    }
    _controller.value = TextEditingValue(
      text: widget.query,
      selection: TextSelection.collapsed(offset: widget.query.length),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bool inScope = SurfaceScope.of(context);

    final Widget field = TextField(
      key: const ValueKey('songBrowserNativeSearchField'),
      controller: _controller,
      onChanged: (value) {
        setState(() {});
        widget.onChanged(value);
      },
      onSubmitted: (_) async {
        FocusScope.of(context).unfocus();
        await widget.onSubmitted();
      },
      textInputAction: TextInputAction.search,
      autocorrect: false,
      enableSuggestions: true,
      maxLines: 1,
      style: Theme.of(
        context,
      ).textTheme.bodyMedium?.copyWith(color: AppColors.textPrimary),
      decoration: InputDecoration(
        isDense: true,
        border: InputBorder.none,
        // Inside a SurfaceScope the field sits flush on the slab it shares
        // with everything else: no fill and no pill outline at rest. The
        // app-wide focused pill (the D-pad/remote focus indicator) is
        // replaced with a green underline so remote focus stays obvious.
        // Outside a scope these stay null so the app-wide filled-pill theme
        // (six other screens) applies exactly as before.
        filled: inScope ? false : null,
        enabledBorder: inScope ? InputBorder.none : null,
        focusedBorder: inScope
            ? const UnderlineInputBorder(
                borderSide: BorderSide(color: AppColors.green, width: 1.5),
              )
            : null,
        hintText: widget.placeholder,
        hintStyle: Theme.of(
          context,
        ).textTheme.bodyMedium?.copyWith(color: AppColors.textMuted),
        prefixIcon: const Icon(AppIcons.search, color: AppColors.textSecondary),
        suffixIcon: _controller.text.isEmpty
            ? null
            : IconButton(
                tooltip: MaterialLocalizations.of(context).deleteButtonTooltip,
                onPressed: () {
                  _controller.clear();
                  setState(() {});
                  widget.onChanged('');
                },
                icon: const Icon(
                  AppIcons.close,
                  color: AppColors.textSecondary,
                ),
              ),
      ),
    );

    if (inScope) {
      // No extra outer inset here: the theme's own contentPadding already
      // insets the field, and adding AppSpacing.md on top of it (as the
      // pre-flatten pill did) pushed the search text well past the results
      // title's left edge below it (PanelFrame's own AppSpacing.md). Dropping
      // this wrapper lines the two up.
      return field;
    }

    return LiquidGlass(
      capsule: true,
      opacity: 0.4,
      rimColor: AppColors.glassBorder,
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
      child: field,
    );
  }
}
