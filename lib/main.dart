import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lieluapp/features/home_widget/widget_order.dart';
import 'package:lieluapp/state/settings.dart';
import 'package:lieluapp/ui/shell.dart';
import 'package:lieluapp/ui/theme.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final prefs = await SharedPreferences.getInstance();
  final container = ProviderContainer(
    overrides: [sharedPrefsProvider.overrideWithValue(prefs)],
  );
  startHomeWidgetSync(container);
  runApp(UncontrolledProviderScope(
    container: container,
    child: const LieluStoreApp(),
  ));
}

class LieluStoreApp extends ConsumerWidget {
  const LieluStoreApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mode = ref.watch(settingsProvider.select((s) => s.themeMode));
    return MaterialApp(
      title: 'Lielu Store',
      debugShowCheckedModeBanner: false,
      theme: lieluTheme(Brightness.light),
      darkTheme: lieluTheme(Brightness.dark),
      themeMode: mode,
      home: const Shell(),
    );
  }
}
