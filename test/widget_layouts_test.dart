import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Vues autorisées dans un widget d'écran d'accueil (classes annotées @RemoteView
/// dans Android). Une autre vue — même un simple `<View>` — empêche Android
/// d'afficher le widget : le lanceur refuse alors de le poser.
const _remoteViews = {
  'FrameLayout', 'LinearLayout', 'RelativeLayout', 'GridLayout',
  'AnalogClock', 'Button', 'Chronometer', 'ImageButton', 'ImageView', 'ProgressBar',
  'TextView', 'ViewFlipper', 'ListView', 'GridView', 'StackView', 'AdapterViewFlipper',
  'ViewStub',
};

void main() {
  final layouts = Directory('android/app/src/main/res/layout')
      .listSync()
      .whereType<File>()
      .where((f) => f.uri.pathSegments.last.startsWith('widget_'))
      .toList();

  test('il existe des gabarits de widget', () => expect(layouts, isNotEmpty));

  for (final f in layouts) {
    test('${f.uri.pathSegments.last} : uniquement des vues autorisées dans un widget', () {
      final tags = RegExp(r'<([A-Za-z][A-Za-z0-9_.]*)')
          .allMatches(f.readAsStringSync())
          .map((m) => m.group(1)!)
          .toSet();
      expect(tags.difference(_remoteViews), isEmpty,
          reason: 'Vues interdites dans un widget Android');
    });
  }
}
