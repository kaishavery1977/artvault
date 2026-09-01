import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import 'command_palette.dart';
import 'web_toast.dart';

/// Global keyboard shortcuts handler for web.
/// Wraps the app and intercepts key events for shortcuts.
class WebShortcutsHandler extends StatefulWidget {
  final Widget child;
  const WebShortcutsHandler({super.key, required this.child});

  @override
  State<WebShortcutsHandler> createState() => _WebShortcutsHandlerState();
}

class _WebShortcutsHandlerState extends State<WebShortcutsHandler> {
  final _focusNode = FocusNode();

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Shortcuts(
      shortcuts: <ShortcutActivator, Intent>{
        // Ctrl+K / Cmd+K: Command palette
        LogicalKeySet(LogicalKeyboardKey.control, LogicalKeyboardKey.keyK): const _CommandPaletteIntent(),
        // Ctrl+U / Cmd+U: Upload
        LogicalKeySet(LogicalKeyboardKey.control, LogicalKeyboardKey.keyU): const _UploadIntent(),
        // G: Go to Gallery (only when no text field focused)
        LogicalKeySet(LogicalKeyboardKey.keyG): const _GalleryIntent(),
        // H: Go to Home
        LogicalKeySet(LogicalKeyboardKey.keyH): const _HomeIntent(),
        // ?: Show shortcuts
        LogicalKeySet(LogicalKeyboardKey.slash, LogicalKeyboardKey.shiftLeft): const _ShortcutsHelpIntent(),
      },
      child: Actions(
        actions: <Type, Action<Intent>>{
          _CommandPaletteIntent: CallbackAction<_CommandPaletteIntent>(
            onInvoke: (_) => CommandPalette.open(context),
          ),
          _UploadIntent: CallbackAction<_UploadIntent>(
            onInvoke: (_) {
              context.push('/painting/new');
              WebToast.show(context, message: 'Opening upload...', icon: Icons.add_photo_alternate);
              return null;
            },
          ),
          _GalleryIntent: CallbackAction<_GalleryIntent>(
            onInvoke: (_) => context.go('/gallery'),
          ),
          _HomeIntent: CallbackAction<_HomeIntent>(
            onInvoke: (_) => context.go('/home'),
          ),
          _ShortcutsHelpIntent: CallbackAction<_ShortcutsHelpIntent>(
            onInvoke: (_) => _showShortcutsHelp(context),
          ),
        },
        child: Focus(
          autofocus: true,
          child: widget.child,
        ),
      ),
    );
  }

  void _showShortcutsHelp(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Keyboard Shortcuts'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _ShortcutRow(keys: 'Ctrl + K', action: 'Command palette'),
            _ShortcutRow(keys: 'Ctrl + U', action: 'Upload painting'),
            _ShortcutRow(keys: 'G', action: 'Go to Gallery'),
            _ShortcutRow(keys: 'H', action: 'Go to Home'),
            _ShortcutRow(keys: '?', action: 'Show this help'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }
}

class _ShortcutRow extends StatelessWidget {
  final String keys;
  final String action;
  const _ShortcutRow({required this.keys, required this.action});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              keys,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                fontFamily: 'monospace',
                color: Theme.of(context).colorScheme.onSurface,
              ),
            ),
          ),
          const SizedBox(width: 16),
          Text(action, style: TextStyle(fontSize: 14, color: Theme.of(context).colorScheme.onSurfaceVariant)),
        ],
      ),
    );
  }
}

// Intent classes
class _CommandPaletteIntent extends Intent { const _CommandPaletteIntent(); }
class _UploadIntent extends Intent { const _UploadIntent(); }
class _GalleryIntent extends Intent { const _GalleryIntent(); }
class _HomeIntent extends Intent { const _HomeIntent(); }
class _ShortcutsHelpIntent extends Intent { const _ShortcutsHelpIntent(); }
