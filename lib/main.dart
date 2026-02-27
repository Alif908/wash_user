import 'package:flutter/material.dart';
import 'package:wash_user/views/login_page.dart';

void main() {
  runApp(const CleanWashApp());
}

class CleanWashApp extends StatelessWidget {
  const CleanWashApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Clean.Wash',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF050A0F),
        fontFamily: 'Roboto',
      ),
      home: LoginPage(),
    );
  }
}
