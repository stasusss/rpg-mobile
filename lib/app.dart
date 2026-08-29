import 'package:flutter/material.dart';

import 'ui/screens/game_screen.dart';
import 'ui/theme.dart';

class IdleRpgApp extends StatelessWidget {
  const IdleRpgApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Idle Hero',
      debugShowCheckedModeBanner: false,
      theme: buildAppTheme(),
      home: const GameScreen(),
    );
  }
}
