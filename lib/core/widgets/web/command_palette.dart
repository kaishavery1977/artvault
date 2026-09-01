import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_colors.dart';

/// Spotlight-style command palette — Ctrl+K / Cmd+K to open.
/// Search commands, navigate, perform actions.
class CommandPalette extends StatefulWidget {
  const CommandPalette({super.key});

  static void open(BuildContext context) {
    showDialog(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.5),
      builder: (_) => const CommandPalette(),
    );
  }

  @override
  State<CommandPalette> createState() => _CommandPaletteState();
}

class _CommandPaletteState extends State<CommandPalette> {
  final _controller = TextEditingController();
  final _focusNode = FocusNode();
  int _selectedIndex = 0;

  static const _commands = [
    _Cmd(Icons.home_rounded, 'Go to Home', '/home'),
    _Cmd(Icons.grid_view_rounded, 'Go to Gallery', '/gallery'),
    _Cmd(Icons.person_rounded, 'Go to Artists', '/artists'),
    _Cmd(Icons.description_rounded, 'Go to Documents', '/documents'),
    _Cmd(Icons.settings_rounded, 'Go to Settings', '/settings'),
    _Cmd(Icons.add_photo_alternate, 'Upload Painting', '/painting/new'),
    _Cmd(Icons.person_add, 'Add Artist', '/artist/new'),
    _Cmd(Icons.search, 'Search', '/search'),
    _Cmd(Icons.insights, 'Reports', '/reports'),
    _Cmd(Icons.qr_code_scanner, 'Scan QR', '/scan'),
    _Cmd(Icons.notifications_outlined, 'Notifications', '/notifications'),
    _Cmd(Icons.backup, 'Backup', '/backup'),
    _Cmd(Icons.palette, 'About', '/about'),
  ];

  List<_Cmd> get _filtered {
    final q = _controller.text.toLowerCase();
    if (q.isEmpty) return _commands;
    return _commands.where((c) => c.label.toLowerCase().contains(q)).toList();
  }

  @override
  void initState() {
    super.initState();
    _focusNode.requestFocus();
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _execute(_Cmd cmd) {
    Navigator.of(context).pop();
    context.push(cmd.route);
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final filtered = _filtered;

    return Shortcuts(
      shortcuts: {
        LogicalKeySet(LogicalKeyboardKey.escape): const _DismissIntent(),
      },
      child: Actions(
        actions: {
          _DismissIntent: CallbackAction<_DismissIntent>(
            onInvoke: (_) => Navigator.of(context).pop(),
          ),
        },
        child: Center(
          child: Container(
            width: 520,
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(context).size.height * 0.6,
            ),
            margin: const EdgeInsets.symmetric(horizontal: 24),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1C1F30) : Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isDark
                    ? Colors.white.withValues(alpha: 0.1)
                    : Colors.black.withValues(alpha: 0.08),
                width: 0.8,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.3),
                  blurRadius: 40,
                  offset: const Offset(0, 20),
                ),
                BoxShadow(
                  color: AppColors.accent.withValues(alpha: 0.1),
                  blurRadius: 20,
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Search input
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                  child: TextField(
                    controller: _controller,
                    focusNode: _focusNode,
                    onChanged: (_) => setState(() {
                      _selectedIndex = 0;
                    }),
                    decoration: InputDecoration(
                      hintText: 'Type a command or search...',
                      prefixIcon: Icon(Icons.search, color: scheme.onSurfaceVariant),
                      border: InputBorder.none,
                      hintStyle: TextStyle(
                        color: scheme.onSurface.withValues(alpha: 0.4),
                        fontSize: 15,
                      ),
                    ),
                    style: TextStyle(
                      fontSize: 15,
                      color: scheme.onSurface,
                    ),
                    onSubmitted: (_) {
                      if (filtered.isNotEmpty) _execute(filtered[_selectedIndex]);
                    },
                  ),
                ),
                Divider(height: 1, color: scheme.outlineVariant.withValues(alpha: 0.3)),
                // Command list
                Flexible(
                  child: ListView.builder(
                    shrinkWrap: true,
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    itemCount: filtered.length,
                    itemBuilder: (_, i) {
                      final cmd = filtered[i];
                      final isSelected = i == _selectedIndex;
                      return MouseRegion(
                        onEnter: (_) => setState(() => _selectedIndex = i),
                        child: GestureDetector(
                          onTap: () => _execute(cmd),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 100),
                            margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 1),
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? AppColors.accent.withValues(alpha: 0.1)
                                  : Colors.transparent,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  cmd.icon,
                                  size: 18,
                                  color: isSelected ? AppColors.accent : scheme.onSurfaceVariant,
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    cmd.label,
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                                      color: isSelected ? scheme.onSurface : scheme.onSurfaceVariant,
                                    ),
                                  ),
                                ),
                                Icon(
                                  Icons.arrow_forward_ios_rounded,
                                  size: 12,
                                  color: scheme.onSurface.withValues(alpha: 0.2),
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
                // Footer hint
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.02),
                    borderRadius: const BorderRadius.vertical(bottom: Radius.circular(16)),
                  ),
                  child: Row(
                    children: [
                      _KeyHint(label: '↵', small: true),
                      const SizedBox(width: 4),
                      Text('select', style: TextStyle(fontSize: 11, color: scheme.onSurface.withValues(alpha: 0.4))),
                      const SizedBox(width: 12),
                      _KeyHint(label: '↑↓', small: true),
                      const SizedBox(width: 4),
                      Text('navigate', style: TextStyle(fontSize: 11, color: scheme.onSurface.withValues(alpha: 0.4))),
                      const SizedBox(width: 12),
                      _KeyHint(label: 'esc', small: true),
                      const SizedBox(width: 4),
                      Text('close', style: TextStyle(fontSize: 11, color: scheme.onSurface.withValues(alpha: 0.4))),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _DismissIntent extends Intent {
  const _DismissIntent();
}

class _Cmd {
  final IconData icon;
  final String label;
  final String route;
  const _Cmd(this.icon, this.label, this.route);
}

class _KeyHint extends StatelessWidget {
  final String label;
  final bool small;
  const _KeyHint({required this.label, this.small = false});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: small ? 4 : 6, vertical: 2),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(
          color: Theme.of(context).colorScheme.outlineVariant,
          width: 0.5,
        ),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: small ? 10 : 11,
          fontWeight: FontWeight.w600,
          color: Theme.of(context).colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }
}
