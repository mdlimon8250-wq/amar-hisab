// Run AFTER `flutter create . --platforms=android` and BEFORE building:
//   dart run tool/patch_android.dart
// - sets the app name to "Amar Hisab"
// - turns off Android cloud/adb backup of the local database (privacy)
// - installs the Amar Hisab launcher icons
import 'dart:io';

void main() {
  final manifest = File('android/app/src/main/AndroidManifest.xml');
  if (!manifest.existsSync()) {
    stderr.writeln('android/ not found. Run: flutter create . --platforms=android');
    exit(1);
  }
  var xml = manifest.readAsStringSync();
  xml = xml.replaceAll(RegExp(r'android:label="[^"]*"'), 'android:label="Amar Hisab"');
  if (!xml.contains('android:allowBackup')) {
    xml = xml.replaceFirst('<application', '<application\n        android:allowBackup="false"');
  }
  manifest.writeAsStringSync(xml);

  final icons = Directory('tool/icons');
  if (icons.existsSync()) {
    for (final dir in icons.listSync().whereType<Directory>()) {
      final name = dir.uri.pathSegments.where((s) => s.isNotEmpty).last;
      for (final f in dir.listSync().whereType<File>()) {
        final fileName = f.uri.pathSegments.last;
        final target = Directory('android/app/src/main/res/$name');
        target.createSync(recursive: true);
        f.copySync('${target.path}/$fileName');
      }
    }
  }
  stdout.writeln('Android project patched.');
}
