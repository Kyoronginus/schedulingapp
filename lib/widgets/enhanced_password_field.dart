import 'package:flutter/material.dart';
import '../utils/utils_functions.dart';

/// Enhanced password field with visual feedback (checkmarks, border colors)
/// matching the implementation in change_password_screen.dart
class EnhancedPasswordField extends StatefulWidget {
  final TextEditingController controller;
  final FocusNode? focusNode;
  final String hintText;
  final String labelText;
  final String? Function(String?)? validator;
  final bool showValidationIcon;
  final bool isValid;
  final bool hasMismatch;
  final String? inlineError;
  final VoidCallback? onChanged;

  const EnhancedPasswordField({
    super.key,
    required this.controller,
    this.focusNode,
    required this.hintText,
    required this.labelText,
    this.validator,
    this.showValidationIcon = false,
    this.isValid = false,
    this.hasMismatch = false,
    this.inlineError,
    this.onChanged,
  });

  @override
  State<EnhancedPasswordField> createState() => _EnhancedPasswordFieldState();
}

class _EnhancedPasswordFieldState extends State<EnhancedPasswordField> {
  bool _obscurePassword = true;

  @override
  void initState() {
    super.initState();
    if (widget.onChanged != null) {
      widget.controller.addListener(() {
        widget.onChanged!();
      });
    }
  }

  Color _getBorderColor() {
    final focusNode = widget.focusNode;
    if (focusNode != null && focusNode.hasFocus) {
      if (widget.hasMismatch) return Colors.red;
      return widget.isValid ? Colors.green : primaryColor;
    }
    return primaryColor; // Default color when not focused
  }

  Widget? _getValidationIcon() {
    if (!widget.showValidationIcon || widget.controller.text.isEmpty) {
      return null;
    }
    
    return Icon(
      widget.isValid ? Icons.check_circle : Icons.cancel,
      color: widget.isValid ? Colors.green : Colors.red,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextFormField(
          controller: widget.controller,
          focusNode: widget.focusNode,
          decoration: InputDecoration(
            hintText: widget.hintText,
            hintStyle: const TextStyle(color: Color(0xFF999999)),
            labelText: widget.labelText,
            labelStyle: const TextStyle(color: Color(0xFF999999)),
            fillColor: Colors.white,
            filled: true,
            suffixIcon: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (_getValidationIcon() != null) _getValidationIcon()!,
                IconButton(
                  icon: Icon(
                    _obscurePassword
                        ? Icons.visibility_outlined
                        : Icons.visibility_off_outlined,
                    color: primaryColor,
                  ),
                  onPressed: () {
                    setState(() {
                      _obscurePassword = !_obscurePassword;
                    });
                  },
                ),
              ],
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10.0),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10.0),
              borderSide: BorderSide(color: secondaryColor, width: 1.5),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10.0),
              borderSide: BorderSide(color: _getBorderColor(), width: 1.5),
            ),
          ),
          obscureText: _obscurePassword,
          validator: widget.validator,
        ),
        if (widget.inlineError != null)
          Padding(
            padding: const EdgeInsets.only(top: 6, left: 16),
            child: Text(
              widget.inlineError!,
              style: const TextStyle(
                color: Colors.redAccent,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
      ],
    );
  }
}
