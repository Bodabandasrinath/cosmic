import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../repositories/auth_repository.dart';
import 'routes.dart';
import 'theme.dart';

class CosmicApp extends StatelessWidget {
  const CosmicApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthRepository()),
      ],
      child: MaterialApp(
        title: 'Cosmic',
        debugShowCheckedModeBanner: false,
        theme: CosmicTheme.lightTheme,
        darkTheme: CosmicTheme.darkTheme,
        themeMode: ThemeMode.dark, // Default Cosmic dark space theme
        initialRoute: AppRoutes.splash,
        routes: AppRoutes.routes,
      ),
    );
  }
}
