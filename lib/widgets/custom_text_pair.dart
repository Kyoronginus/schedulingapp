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
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: theme.textTheme.titleMedium?.color,
          ),
        ),
        const SizedBox(height: 5),
        Text(
          subtitle,
          style: TextStyle(
            color: theme.textTheme.bodyMedium?.color,
          ),
        ),
        const SizedBox(height: 10),
      ],
    );
  }
}
