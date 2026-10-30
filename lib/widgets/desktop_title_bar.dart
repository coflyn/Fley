import 'dart:io';
import 'package:flutter/material.dart';
import 'package:window_manager/window_manager.dart';

class DesktopTitleBar extends StatefulWidget {
  final Color backgroundColor;
  final bool isLight;
  final Widget? leading;
  final Widget? trailing;

  const DesktopTitleBar({
    super.key,
    required this.backgroundColor,
    required this.isLight,
    this.leading,
    this.trailing,
  });

  @override
  State<DesktopTitleBar> createState() => _DesktopTitleBarState();
}

class _DesktopTitleBarState extends State<DesktopTitleBar> with WindowListener {
  bool _isMaximized = false;

  @override
  void initState() {
    super.initState();
    windowManager.addListener(this);
    _checkMaximized();
  }

  @override
  void dispose() {
    windowManager.removeListener(this);
    super.dispose();
  }

  Future<void> _checkMaximized() async {
    final maximized = await windowManager.isMaximized();
    if (mounted) {
      setState(() => _isMaximized = maximized);
    }
  }

  @override
  void onWindowMaximize() {
    setState(() => _isMaximized = true);
  }

  @override
  void onWindowUnmaximize() {
    setState(() => _isMaximized = false);
  }

  @override
  Widget build(BuildContext context) {
    if (!Platform.isMacOS && !Platform.isWindows && !Platform.isLinux) {
      return const SizedBox.shrink();
    }

    final textColor = widget.isLight
        ? const Color(0xFF1A1A1A)
        : Colors.white.withValues(alpha: 0.9);
    final hoverColor = widget.isLight
        ? Colors.black.withValues(alpha: 0.08)
        : Colors.white.withValues(alpha: 0.12);

    final isMac = Platform.isMacOS;

    return Container(
      height: 40,
      color: widget.backgroundColor,
      child: Row(
        children: [
          // Drag to move area spanning the title and leading space
          Expanded(
            child: DragToMoveArea(
              child: Container(
                padding: EdgeInsets.only(
                  left: isMac ? 82 : 16,
                  right: 16,
                ),
                color: Colors.transparent,
                alignment: Alignment.centerLeft,
                child: Row(
                  children: [
                    if (widget.leading != null) widget.leading!,
                  ],
                ),
              ),
            ),
          ),

          if (widget.trailing != null) widget.trailing!,

          // Window control buttons (Only on Windows and Linux)
          if (!isMac)
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _WindowButton(
                  icon: Icons.remove,
                  hoverColor: hoverColor,
                  iconColor: textColor,
                  onPressed: () => windowManager.minimize(),
                  tooltip: 'Minimize',
                ),
                _WindowButton(
                  icon: _isMaximized
                      ? Icons.crop_square_rounded
                      : Icons.check_box_outline_blank_rounded,
                  hoverColor: hoverColor,
                  iconColor: textColor,
                  iconSize: 14,
                  onPressed: () async {
                    if (_isMaximized) {
                      await windowManager.unmaximize();
                    } else {
                      await windowManager.maximize();
                    }
                  },
                  tooltip: _isMaximized ? 'Restore' : 'Maximize',
                ),
                _WindowButton(
                  icon: Icons.close,
                  hoverColor: Colors.redAccent.withValues(alpha: 0.9),
                  iconColor: textColor,
                  hoverIconColor: Colors.white,
                  onPressed: () => windowManager.close(),
                  tooltip: 'Close',
                ),
              ],
            ),
        ],
      ),
    );
  }
}

class _WindowButton extends StatefulWidget {
  final IconData icon;
  final Color hoverColor;
  final Color iconColor;
  final Color? hoverIconColor;
  final double iconSize;
  final VoidCallback onPressed;
  final String tooltip;

  const _WindowButton({
    required this.icon,
    required this.hoverColor,
    required this.iconColor,
    this.hoverIconColor,
    this.iconSize = 16,
    required this.onPressed,
    required this.tooltip,
  });

  @override
  State<_WindowButton> createState() => _WindowButtonState();
}

class _WindowButtonState extends State<_WindowButton> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: Tooltip(
        message: widget.tooltip,
        waitDuration: const Duration(milliseconds: 500),
        child: GestureDetector(
          onTap: widget.onPressed,
          child: Container(
            width: 44,
            height: 38,
            color: _isHovered ? widget.hoverColor : Colors.transparent,
            alignment: Alignment.center,
            child: Icon(
              widget.icon,
              size: widget.iconSize,
              color: _isHovered && widget.hoverIconColor != null
                  ? widget.hoverIconColor
                  : widget.iconColor,
            ),
          ),
        ),
      ),
    );
  }
}
