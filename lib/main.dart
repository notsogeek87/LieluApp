import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lieluapp/features/app_update/app_update_banner.dart';

void main() => runApp(const ProviderScope(child: LieluApp()));

class LieluApp extends StatelessWidget {
  const LieluApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'LieluApp',
      theme: ThemeData(colorSchemeSeed: Colors.teal, useMaterial3: true),
      home: const HomePage(),
    );
  }
}

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('LieluApp')),
      body: const Column(
        children: [
          AppUpdateBanner(),
          Expanded(child: Center(child: Text('LieluApp'))),
        ],
      ),
    );
  }
}
