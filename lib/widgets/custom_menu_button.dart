import 'package:flutter/material.dart';

/// A custom menu button that replaces PopupMenuButton to avoid lifecycle issues
class CustomMenuButton extends StatefulWidget {
  final Widget child;
  final List<CustomMenuItem> items;
  final Function(String) onSelected;
  final Color? backgroundColor;
  final Color? iconColor;

  const CustomMenuButton({
    super.key,
    required this.child,
    required this.items,
    required this.onSelected,
    this.backgroundColor,
    this.iconColor,
  });

  @override
  State<CustomMenuButton> createState() => _CustomMenuButtonState();
}

class _CustomMenuButtonState extends State<CustomMenuButton> {
  OverlayEntry? _overlayEntry;
  final LayerLink _layerLink = LayerLink();

  void _showMenu() {
    if (_overlayEntry != null) return;

    final RenderBox renderBox = context.findRenderObject() as RenderBox;
    final size = renderBox.size;
    final offset = renderBox.localToGlobal(Offset.zero);

    _overlayEntry = OverlayEntry(
      builder: (context) => GestureDetector(
        onTap: _hideMenu, // Close menu when tapping outside
        behavior: HitTestBehavior.translucent,
        child: Stack(
          children: [
            // Full screen transparent area to catch taps
            Positioned.fill(
              child: Container(color: Colors.transparent),
            ),
            // The actual menu
            Positioned(
              left: offset.dx,
              top: offset.dy + size.height,
              child: CompositedTransformFollower(
                link: _layerLink,
                showWhenUnlinked: false,
                child: Material(
                  elevation: 8,
                  borderRadius: BorderRadius.circular(8),
                  color: widget.backgroundColor ?? Theme.of(context).cardColor,
                  child: IntrinsicWidth(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: widget.items.map((item) {
                        return InkWell(
                          onTap: () {
                            _hideMenu();
                            widget.onSelected(item.value);
                          },
                          borderRadius: BorderRadius.circular(8),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 12,
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                if (item.icon != null) ...[
                                  Icon(
                                    item.icon,
                                    size: 18,
                                    color: item.iconColor,
                                  ),
                                  const SizedBox(width: 8),
                                ],
                                Text(
                                  item.text,
                                  style: TextStyle(
                                    color: item.textColor,
                                    fontSize: 14,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );

    Overlay.of(context).insert(_overlayEntry!);
  }

  void _hideMenu() {
    _overlayEntry?.remove();
    _overlayEntry = null;
  }

  @override
  void dispose() {
    _hideMenu();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return CompositedTransformTarget(
      link: _layerLink,
      child: GestureDetector(
        onTap: _showMenu,
        child: widget.child,
      ),
    );
  }
}

class CustomMenuItem {
  final String value;
  final String text;
  final IconData? icon;
  final Color? iconColor;
  final Color? textColor;

  const CustomMenuItem({
    required this.value,
    required this.text,
    this.icon,
    this.iconColor,
    this.textColor,
  });
}
