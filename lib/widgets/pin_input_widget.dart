import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// A modern, robust 6-digit PIN input widget.
///
/// Displays PIN fields in a single, tidy row, prevents overflow, and ensures
/// smooth keyboard interactions for both typing and deleting.
class PinInputWidget extends StatefulWidget {
  final Function(String) onCompleted;
  final Function(String)? onChanged;
  final int length;
  final bool autoFocus;
  final String? errorText;
  final Color? primaryColor;

  const PinInputWidget({
    super.key,
    required this.onCompleted,
    this.onChanged,
    this.length = 6,
    this.autoFocus = true,
    this.errorText,
    this.primaryColor,
  });

  @override
  State<PinInputWidget> createState() => _PinInputWidgetState();
}

class _PinInputWidgetState extends State<PinInputWidget> {
  late List<TextEditingController> _controllers;
  late List<FocusNode> _focusNodes;

  @override
  void initState() {
    super.initState();
    _controllers = List.generate(widget.length, (_) => TextEditingController());
    _focusNodes = List.generate(widget.length, (_) => FocusNode());

    if (widget.autoFocus) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _focusNodes[0].requestFocus();
      });
    }
  }

  @override
  void dispose() {
    for (var controller in _controllers) {
      controller.dispose();
    }
    for (var focusNode in _focusNodes) {
      focusNode.dispose();
    }
    super.dispose();
  }

  void _notifyParent() {
    final pin = _controllers.map((c) => c.text).join();
    widget.onChanged?.call(pin);
    if (pin.length == widget.length) {
      widget.onCompleted(pin);
    }
  }

  void _onTextChanged(String value, int index) {
    if (value.isNotEmpty) {
      if (index < widget.length - 1) {
        _focusNodes[index + 1].requestFocus();
      } else {
        _focusNodes[index].unfocus();
      }
    }
    _notifyParent();
  }

  void _onBackspace(int index) {
    // If the current field is empty and it's not the first one...
    if (_controllers[index].text.isEmpty && index > 0) {
      // ...move focus to the previous field and clear its text.
      _focusNodes[index - 1].requestFocus();
      _controllers[index - 1].clear();
    }
    _notifyParent();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: List.generate(
            widget.length,
            (index) => _buildPinField(context, index),
          ),
        ),
        if (widget.errorText != null)
          Padding(
            padding: const EdgeInsets.only(top: 12),
            child: Text(
              widget.errorText!,
              style: const TextStyle(
                color: Colors.redAccent,
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
              textAlign: TextAlign.center,
            ),
          ),
      ],
    );
  }

  Widget _buildPinField(BuildContext context, int index) {
    final Color effectivePrimaryColor =
        widget.primaryColor ?? Theme.of(context).primaryColor;

    return SizedBox(
      // Slightly reduced width to prevent overflow on smaller screens
      width: 45,
      height: 56,
      child: KeyboardListener(
        // An unfocusable node for the listener
        focusNode: FocusNode(skipTraversal: true),
        onKeyEvent: (event) {
          if (event is KeyDownEvent &&
              event.logicalKey == LogicalKeyboardKey.backspace) {
            _onBackspace(index);
          }
        },
        child: TextFormField(
          controller: _controllers[index],
          focusNode: _focusNodes[index],
          textAlign: TextAlign.center,
          textAlignVertical: TextAlignVertical.center, // Perfect vertical centering
          style: const TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: Colors.black87,
          ),
          keyboardType: TextInputType.number,
          inputFormatters: [
            FilteringTextInputFormatter.digitsOnly,
            LengthLimitingTextInputFormatter(1),
          ],
          decoration: InputDecoration(
            counterText: '',
            filled: true,
            fillColor: Colors.white,
            contentPadding: EdgeInsets.zero, // Ensures text is centered
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.grey.shade400, width: 1.5),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: effectivePrimaryColor, width: 2.5),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Colors.redAccent, width: 2.0),
            ),
            focusedErrorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Colors.redAccent, width: 2.5),
            ),
          ),
          onChanged: (value) => _onTextChanged(value, index),
          onTap: () {
            // Clear the field on tap for easier editing and notify parent
            _controllers[index].clear();
            _notifyParent();
          },
        ),
      ),
    );
  }
}