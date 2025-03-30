import 'package:flutter/material.dart';

class RobotoText extends StatelessWidget {
  final String text;
  final double fontSize;
  final Color color;
  final TextAlign textAlign;

  const RobotoText(
    this.text, {
    super.key,
    this.fontSize = 20,
    this.color = Colors.black,
    this.textAlign = TextAlign.left,
  });

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      textAlign: textAlign,
      style: TextStyle(
        color: color,
        fontFamily: 'Roboto',
        fontSize: fontSize,
        fontWeight: FontWeight.bold,
        height: 1,
      ),
    );
  }
}

class VitacureWidget extends StatelessWidget {
  const VitacureWidget({super.key});

  @override
  Widget build(BuildContext context) {
    return Text(
      'VitaCure',
      textAlign: TextAlign.left,
      style: TextStyle(
        color: Colors.black,
        fontFamily: 'Rounded Mplus 1c',
        fontSize: 32,
        letterSpacing: 0, // percentages not used in flutter. defaulting to zero
        fontWeight: FontWeight.normal,
        height: 1,
      ),
    );
  }
}
