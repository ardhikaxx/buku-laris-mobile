import 'dart:convert';
import 'dart:typed_data';

import 'package:image/image.dart' as img;
import 'package:image_picker/image_picker.dart';

import '../core/constants/app_constants.dart';
import 'logger.dart';

class ImageService {
  ImageService._();
  static final ImageService instance = ImageService._();

  final _picker = ImagePicker();

  Future<String?> pickAndCompress({
    required int maxDimension,
    int quality = 72,
    int maxBytes = AppConstants.maxLogoBytes,
  }) async {
    try {
      final picked = await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1600,
        maxHeight: 1600,
        imageQuality: 90,
      );
      if (picked == null) return null;
      return await compressBytes(await picked.readAsBytes(),
          maxDimension: maxDimension, quality: quality, maxBytes: maxBytes);
    } catch (e) {
      Logger.e('pickAndCompress failed', e);
      return null;
    }
  }

  Future<String> compressBytes(
    Uint8List bytes, {
    required int maxDimension,
    int quality = 72,
    int maxBytes = AppConstants.maxLogoBytes,
  }) async {
    var decoded = img.decodeImage(bytes);
    if (decoded == null) {
      throw const FormatException('Gambar tidak dapat dibaca');
    }
    if (decoded.width > maxDimension || decoded.height > maxDimension) {
      decoded = img.copyResize(
        decoded,
        width: decoded.width >= decoded.height ? maxDimension : null,
        height: decoded.height > decoded.width ? maxDimension : null,
        interpolation: img.Interpolation.average,
      );
    }
    var encoded = img.encodeJpg(decoded, quality: quality);
    while (encoded.length > maxBytes && quality > 30) {
      quality -= 12;
      encoded = img.encodeJpg(decoded, quality: quality);
    }
    return 'data:image/jpeg;base64,${base64Encode(encoded)}';
  }
}
