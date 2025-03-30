import 'package:flutter/material.dart';
import '../utils/utils_functions.dart';

class CustomTextFormField extends StatelessWidget {
  final TextEditingController controller;
  final String labelText;
  final bool obscureText;
  final String? Function(String?)? validator;
  final Widget? prefixIcon;

  const CustomTextFormField({
    super.key,
    required this.controller,
    required this.labelText,
    this.obscureText = false,
    this.validator,
    this.prefixIcon,
  });

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      decoration: InputDecoration(
        labelText: labelText,
        fillColor: panaceaTeal20,
        filled: true,
        prefixIcon: prefixIcon,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12.0),
          borderSide: BorderSide(
            color: panaceaTeal20,
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12.0),
          borderSide: BorderSide(
            color: panaceaTeal20,
          ),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12.0),
          borderSide: BorderSide(
            color: panaceaTeal20,
          ),
        ),
      ),
      obscureText: obscureText,
      validator: validator,
    );
  }
}
