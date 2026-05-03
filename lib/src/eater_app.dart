import 'package:flutter/material.dart';

import 'app_theme.dart';
import 'screens/menu_screen.dart';

class BawarchiiEaterApp extends StatelessWidget {
  const BawarchiiEaterApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Bawarchii',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      home: const MenuScreen(),
    );
  }
}
