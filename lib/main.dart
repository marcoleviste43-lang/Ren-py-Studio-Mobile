import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'services/project_service.dart';
import 'services/ai_service.dart';
import 'theme/app_theme.dart';
import 'screens/home_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const RenPyStudioApp());
}

class RenPyStudioApp extends StatelessWidget {
  const RenPyStudioApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => ProjectService()..init()),
        ChangeNotifierProvider(create: (_) => AiService()..init()),
      ],
      child: MaterialApp(
        title: "Ren'Py Studio Mobile",
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light,
        darkTheme: AppTheme.dark,
        themeMode: ThemeMode.dark,
        home: const HomeScreen(),
      ),
    );
  }
}
