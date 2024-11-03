// lib/screens/settings_screen.dart

import 'package:flutter/material.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key}); // use_super_parameters 적용

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('설정'),
      ),
      body: const Center(
        child: Text('설정 화면입니다.'),
      ),
    );
  }
}
