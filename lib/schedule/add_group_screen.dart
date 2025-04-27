import 'package:flutter/material.dart';
import '../../widgets/custom_app_bar.dart';

class AddGroupScreen extends StatelessWidget {
  const AddGroupScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: CustomAppBar(title: Text('Create a New Group')),
      body: Center(
        child: Text('add group screen'),
      ),
    );
  }
}
