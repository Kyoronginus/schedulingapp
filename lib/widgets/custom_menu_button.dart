// File: lib/widgets/custom_menu_button.dart

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart'; // Jangan lupa tambahkan import ini

// DIUBAH: Menambahkan parameter baru 'svgPath'
class CustomMenuItem {
  final String value;
  final String text;
  final IconData? icon; // Parameter lama, tetap ada untuk kompatibilitas
  final String? svgPath; // Parameter BARU untuk path file SVG
  final Color? iconColor;
  final Color? textColor;

  const CustomMenuItem({
    required this.value,
    required this.text,
    this.icon,
    this.svgPath, // Tambahkan di konstruktor
    this.iconColor,
    this.textColor,
  }) : assert(icon == null || svgPath == null, 'Cannot provide both an IconData and an svgPath.');
}

// Tidak ada perubahan pada widget utama, hanya di bagian State di bawah
class CustomMenuButton extends StatefulWidget {
  final Widget child;
  final List<CustomMenuItem> items;
  final Function(String) onSelected;
  final Color? backgroundColor;
  final ShapeBorder? shape;
  final List<BoxShadow>? boxShadow;
  final Offset offset;

  const CustomMenuButton({
    super.key,
    required this.child,
    required this.items,
    required this.onSelected,
    this.backgroundColor,
    this.shape,
    this.boxShadow,
    this.offset = const Offset(0, 12),
  });

  @override
  State<CustomMenuButton> createState() => _CustomMenuButtonState();
}

class _CustomMenuButtonState extends State<CustomMenuButton> {
  OverlayEntry? _overlayEntry;
  final LayerLink _layerLink = LayerLink();

  // ... (Fungsi _showMenu, _hideMenu, dispose, dan build tetap sama persis)

  void _showMenu() {
    if (_overlayEntry != null) {
      _hideMenu();
      return;
    }
    _overlayEntry = _createOverlayEntry();
    Overlay.of(context).insert(_overlayEntry!);
  }

  void _hideMenu() {
    if (_overlayEntry != null) {
      _overlayEntry!.remove();
      _overlayEntry = null;
    }
  }

  OverlayEntry _createOverlayEntry() {
    final renderBox = context.findRenderObject() as RenderBox;
    final size = renderBox.size;
    final screenSize = MediaQuery.of(context).size;

    final double estimatedMenuWidth = 180;
    double horizontalShift = 0;
    if (renderBox.localToGlobal(Offset.zero).dx + estimatedMenuWidth >
        screenSize.width - 16) {
      horizontalShift = -estimatedMenuWidth + size.width;
    }

    final shape = widget.shape ??
        RoundedRectangleBorder(borderRadius: BorderRadius.circular(15.0));
    final boxShadow = widget.boxShadow ??
        [
          BoxShadow(
              color: Colors.black.withOpacity(0.2),
              spreadRadius: 4,
              blurRadius: 15,
              offset: Offset.zero)
        ];

    return OverlayEntry(
      builder: (context) => GestureDetector(
        onTap: _hideMenu,
        behavior: HitTestBehavior.translucent,
        child: Stack(
          children: [
            CompositedTransformFollower(
              link: _layerLink,
              showWhenUnlinked: false,
              offset: Offset(horizontalShift + widget.offset.dx,
                  size.height + widget.offset.dy),
              child: Material(
                color: Colors.transparent,
                child: Container(
                  width: estimatedMenuWidth,
                  decoration: BoxDecoration(
                    color:
                        widget.backgroundColor ?? Theme.of(context).cardColor,
                    borderRadius: (shape is RoundedRectangleBorder)
                        ? shape.borderRadius.resolve(null)
                        : BorderRadius.zero,
                    boxShadow: boxShadow,
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: widget.items.map((item) {
                      final borderRadius = _getItemBorderRadius(item);
                      return InkWell(
                        onTap: () {
                          _hideMenu();
                          widget.onSelected(item.value);
                        },
                        borderRadius: borderRadius,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 12),
                          child: Row(
                            children: [
                              // ==== LOGIKA RENDER IKON DIPERBARUI DI SINI ====
                              if (item.svgPath != null && item.svgPath!.isNotEmpty)
                                // Jika ada svgPath, gunakan SvgPicture
                                SvgPicture.asset(
                                  item.svgPath!,
                                  width: 20,
                                  height: 20,
                                  colorFilter: item.iconColor != null
                                      ? ColorFilter.mode(
                                          item.iconColor!, BlendMode.srcIn)
                                      : null,
                                )
                              // Jika tidak ada svgPath tapi ada icon, gunakan Icon (kode lama)
                              else if (item.icon != null)
                                Icon(
                                  item.icon,
                                  size: 20,
                                  color: item.iconColor,
                                ),
                              
                              // Memberi jarak jika ada ikon
                              if(item.svgPath != null || item.icon != null)
                                const SizedBox(width: 12),

                              Expanded(
                                child: Text(
                                  item.text,
                                  style: TextStyle(
                                      color: item.textColor, fontSize: 14),
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
  }

  BorderRadius _getItemBorderRadius(CustomMenuItem item) {
    final isFirst = widget.items.first == item;
    final isLast = widget.items.last == item;

    if (widget.shape is RoundedRectangleBorder) {
      final radiusValue =
          (widget.shape as RoundedRectangleBorder).borderRadius.resolve(null).bottomLeft.x;
      if (widget.items.length == 1) {
        return BorderRadius.circular(radiusValue);
      }
      if (isFirst) {
        return BorderRadius.vertical(top: Radius.circular(radiusValue));
      }
      if (isLast) {
        return BorderRadius.vertical(bottom: Radius.circular(radiusValue));
      }
    }
    return BorderRadius.zero;
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