import 'package:flutter/material.dart';

class CustomTextPair extends StatelessWidget {
  final String title;
  final String subtitle;

  const CustomTextPair({
    super.key,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 5),
        Text(subtitle),
        const SizedBox(height: 10),
      ],
    );
  }
}
