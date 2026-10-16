import 'package:flutter_test/flutter_test.dart';
import 'package:lieluapp/features/app_update/app_update.dart';

void main() {
  test('le numéro de build se lit dans le dernier segment du tag', () {
    expect(buildFromTag('v0.1.0.42'), 42);
    expect(buildFromTag('v0.1.0'), 0);
    expect(buildFromTag('debug-main'), isNull);
  });
}
