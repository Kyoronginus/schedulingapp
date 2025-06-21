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
    final screenSize = MediaQuery.of(context).size;
    final screenWidth = screenSize.width;
    const double screenPadding = 16.0;

    double estimatedMenuWidth = 0;
    for (final item in widget.items) {
      final textPainter = TextPainter(
        text: TextSpan(text: item.text, style: const TextStyle(fontSize: 14)),
        maxLines: 1,
        textDirection: TextDirection.ltr,
      )..layout();

      final double iconWidth = item.icon != null ? 30.0 : 0.0;
      final double itemWidth = textPainter.width + iconWidth + 32.0;

      if (itemWidth > estimatedMenuWidth) {
        estimatedMenuWidth = itemWidth;
      }
    }
    estimatedMenuWidth =
        estimatedMenuWidth.clamp(120.0, screenWidth - (2 * screenPadding));

    double horizontalOffset = 0;
    if (offset.dx + estimatedMenuWidth > screenWidth - screenPadding) {
      horizontalOffset = size.width - estimatedMenuWidth;
    }

    _overlayEntry = OverlayEntry(
      builder: (context) => GestureDetector(
        onTap: _hideMenu,
        behavior: HitTestBehavior.translucent,
        child: Stack(
          children: [
            CompositedTransformFollower(
              link: _layerLink,
              showWhenUnlinked: false,
              offset: Offset(horizontalOffset, size.height + 12),
              child: Material(
                elevation: 8,
                borderRadius: BorderRadius.circular(8),
                color: widget.backgroundColor ?? Theme.of(context).cardColor,
                child: SizedBox(
                  width: estimatedMenuWidth,
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
                            children: [
                              if (item.icon != null) ...[
                                Icon(
                                  item.icon,
                                  size: 18,
                                  color: item.iconColor,
                                ),
                                const SizedBox(width: 12),
                              ],
                              Expanded(
                                child: Text(
                                  item.text,
                                  style: TextStyle(
                                    color: item.textColor,
                                    fontSize: 14,
                                  ),
                                  // Ellipsis will now work correctly
                                  overflow: TextOverflow.ellipsis,
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
