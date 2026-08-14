import 'package:flutter/material.dart';

import '../theme/app_spacing.dart';

/// Filled Material 3 text field used everywhere in ArtVault.
class AppTextField extends StatelessWidget {
  final String? label;
  final String? hint;
  final IconData? icon;
  final Widget? suffixIcon;
  final TextEditingController? controller;
  final String? initialValue;
  final String? Function(String?)? validator;
  final TextInputType? keyboardType;
  final bool obscureText;
  final bool enabled;
  final bool readOnly;
  final int maxLines;
  final TextInputAction? textInputAction;
  final ValueChanged<String>? onChanged;
  final VoidCallback? onTap;
  final String? prefixText;
  final TextCapitalization capitalization;
  /// When set, the leading [icon] becomes a tappable, highlighted button
  /// (e.g. the date field's calendar) instead of a plain static icon.
  final VoidCallback? onIconTap;
  final Color? iconColor;
  final double? iconSize;

  const AppTextField({
    super.key,
    this.label,
    this.hint,
    this.icon,
    this.suffixIcon,
    this.controller,
    this.initialValue,
    this.validator,
    this.keyboardType,
    this.obscureText = false,
    this.enabled = true,
    this.readOnly = false,
    this.maxLines = 1,
    this.textInputAction,
    this.onChanged,
    this.onTap,
    this.prefixText,
    this.capitalization = TextCapitalization.none,
    this.onIconTap,
    this.iconColor,
    this.iconSize,
  });

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      initialValue: initialValue,
      validator: validator,
      keyboardType: keyboardType,
      obscureText: obscureText,
      enabled: enabled,
      readOnly: readOnly,
      maxLines: maxLines,
      textInputAction: textInputAction,
      onChanged: onChanged,
      onTap: onTap,
      textCapitalization: capitalization,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        // prefixText and prefixIcon can't both be set (icon wins and the
        // text is dropped) — callers pick one.
        prefixIcon: _buildPrefixIcon(context),
        prefixText: prefixText,
        suffixIcon: suffixIcon,
      ),
    );
  }

  /// The leading icon: a plain icon by default, or a tappable, highlighted
  /// button when [onIconTap] is provided (so callers like the date field can
  /// turn the icon itself into the action instead of bolting on a duplicate
  /// suffix button).
  Widget? _buildPrefixIcon(BuildContext context) {
    if (prefixText != null || icon == null) return null;
    final tap = onIconTap;
    if (tap == null) {
      return Icon(icon, size: iconSize ?? 20);
    }
    return InkWell(
      onTap: tap,
      borderRadius: BorderRadius.circular(24),
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Icon(
          icon,
          size: iconSize ?? 22,
          color: iconColor ?? Theme.of(context).colorScheme.primary,
        ),
      ),
    );
  }
}

/// Dropdown that adapts to a list of string options.
class AppDropdown<T> extends StatelessWidget {
  final String label;
  final T? value;
  final List<T> items;
  final String Function(T) labelFor;
  final ValueChanged<T?> onChanged;
  final IconData? icon;

  const AppDropdown({
    super.key,
    required this.label,
    required this.value,
    required this.items,
    required this.labelFor,
    required this.onChanged,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<T>(
      initialValue: value,
      isExpanded: true,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: icon == null ? null : Icon(icon, size: 20),
      ),
      items: [
        for (final item in items)
          DropdownMenuItem(value: item, child: Text(labelFor(item))),
      ],
      onChanged: onChanged,
    );
  }
}

/// Chip input for tags — Enter (or comma) commits a tag, tap to remove.
class AppTagsField extends StatefulWidget {
  final List<String> tags;
  final ValueChanged<List<String>> onChanged;
  final String? hint;

  const AppTagsField({
    super.key,
    required this.tags,
    required this.onChanged,
    this.hint = 'Add a tag and press Enter',
  });

  @override
  State<AppTagsField> createState() => _AppTagsFieldState();
}

class _AppTagsFieldState extends State<AppTagsField> {
  final TextEditingController _controller = TextEditingController();

  void _commit() {
    final text = _controller.text.trim();
    if (text.isEmpty) return;
    if (widget.tags.contains(text)) {
      _controller.clear();
      return;
    }
    widget.onChanged([...widget.tags, text]);
    _controller.clear();
  }

  void _remove(String tag) {
    widget.onChanged([...widget.tags]..remove(tag));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: AppSpacing.xs,
          runSpacing: AppSpacing.xs,
          children: [
            for (final tag in widget.tags)
              InputChip(
                label: Text(tag),
                onDeleted: () => _remove(tag),
                deleteIcon: const Icon(Icons.close, size: 16),
              ),
          ],
        ),
        const SizedBox(height: AppSpacing.xs),
        TextField(
          controller: _controller,
          decoration: InputDecoration(
            hintText: widget.hint,
            prefixIcon: const Icon(Icons.tag, size: 20),
          ),
          onSubmitted: (_) => _commit(),
          onEditingComplete: _commit,
          textInputAction: TextInputAction.done,
        ),
      ],
    );
  }
}
