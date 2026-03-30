import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:wash_user/services/washing_session.dart';
import 'package:wash_user/views/login_page.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Restore any wash session that was active before app was killed
  await WashSessionManager.instance.tryRestoreSession();

  runApp(
    ChangeNotifierProvider.value(
      value: WashSessionManager.instance,
      child: const CleanWashApp(),
    ),
  );
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
