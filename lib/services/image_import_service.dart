import 'dart:io';
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as p;

class ImportedImage {
  final String originalPath;
  final String suggestedTag; // Ren'Py image tag guessed from filename
  ImportedImage(this.originalPath, this.suggestedTag);
}

/// Handles pulling images from the device gallery/camera and copying them
/// into a project's game/images folder, following Ren'Py's naming
/// convention of `tag attribute.png` where possible.
class ImageImportService {
  final _picker = ImagePicker();

  Future<List<ImportedImage>> pickFromGallery() async {
    final files = await _picker.pickMultiImage(imageQuality: 95);
    return files.map((f) => ImportedImage(f.path, _guessTag(f.path))).toList();
  }

  Future<ImportedImage?> pickFromCamera() async {
    final file = await _picker.pickImage(source: ImageSource.camera);
    if (file == null) return null;
    return ImportedImage(file.path, _guessTag(file.path));
  }

  String _guessTag(String path) {
    final base = p.basenameWithoutExtension(path);
    // strip common suffixes like _01, -copy, spaces -> underscores
    final cleaned = base
        .replaceAll(RegExp(r'[-\s]+'), '_')
        .replaceAll(RegExp(r'_\d+$'), '')
        .toLowerCase();
    return cleaned.isEmpty ? 'image' : cleaned;
  }

  /// Copies the picked image into `<projectDir>/game/images/<newName>`
  /// and returns the new absolute path.
  Future<String> importInto(String projectDir, ImportedImage image,
      {String? renameTo}) async {
    final imagesDir = Directory(p.join(projectDir, 'game', 'images'));
    if (!await imagesDir.exists()) await imagesDir.create(recursive: true);

    final ext = p.extension(image.originalPath);
    final fileName = (renameTo ?? image.suggestedTag) + ext;
    final destPath = p.join(imagesDir.path, fileName);
    await File(image.originalPath).copy(destPath);
    return destPath;
  }
}
