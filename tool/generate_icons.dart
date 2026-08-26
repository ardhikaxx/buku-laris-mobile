// ignore_for_file: avoid_print, prefer_const_declarations
import 'dart:io';
import 'package:image/image.dart' as img;

void main() {
  final inputPath = 'assets/images/logo_vector_concept3.jpg';
  final bytes = File(inputPath).readAsBytesSync();
  final image = img.decodeImage(bytes);

  if (image == null) {
    print('Failed to decode image from ');
    return;
  }

  // 1. Save main high-res app logo as PNG
  final logo512 = img.copyResize(image, width: 512, height: 512, interpolation: img.Interpolation.cubic);
  File('assets/images/logo.png').writeAsBytesSync(img.encodePng(logo512));
  print('Saved assets/images/logo.png');

  // 2. Generate Android Mipmap Icons
  final mipmaps = {
    'android/app/src/main/res/mipmap-mdpi/ic_launcher.png': 48,
    'android/app/src/main/res/mipmap-hdpi/ic_launcher.png': 72,
    'android/app/src/main/res/mipmap-xhdpi/ic_launcher.png': 96,
    'android/app/src/main/res/mipmap-xxhdpi/ic_launcher.png': 144,
    'android/app/src/main/res/mipmap-xxxhdpi/ic_launcher.png': 192,
  };

  for (final entry in mipmaps.entries) {
    final resized = img.copyResize(image, width: entry.value, height: entry.value, interpolation: img.Interpolation.cubic);
    final file = File(entry.key);
    file.parent.createSync(recursive: true);
    file.writeAsBytesSync(img.encodePng(resized));
    print('Generated  (x)');
  }

  // 3. Web icons if available
  if (Directory('web/icons').existsSync()) {
    final icon192 = img.copyResize(image, width: 192, height: 192, interpolation: img.Interpolation.cubic);
    File('web/icons/Icon-192.png').writeAsBytesSync(img.encodePng(icon192));
    final icon512 = img.copyResize(image, width: 512, height: 512, interpolation: img.Interpolation.cubic);
    File('web/icons/Icon-512.png').writeAsBytesSync(img.encodePng(icon512));
    final iconMaskable192 = img.copyResize(image, width: 192, height: 192, interpolation: img.Interpolation.cubic);
    File('web/icons/Icon-maskable-192.png').writeAsBytesSync(img.encodePng(iconMaskable192));
    final iconMaskable512 = img.copyResize(image, width: 512, height: 512, interpolation: img.Interpolation.cubic);
    File('web/icons/Icon-maskable-512.png').writeAsBytesSync(img.encodePng(iconMaskable512));
    print('Updated web icons');
  }

  if (File('web/favicon.png').existsSync()) {
    final favicon = img.copyResize(image, width: 32, height: 32, interpolation: img.Interpolation.cubic);
    File('web/favicon.png').writeAsBytesSync(img.encodePng(favicon));
    print('Updated web/favicon.png');
  }

  print('All launcher icons successfully generated!');
}
