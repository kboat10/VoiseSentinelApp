import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// Download files from Hugging Face Hub using the resolve URL.
///
/// Model ID: e.g. "facebook/wav2vec2-xls-r-300m"
/// Files are downloaded from: https://huggingface.co/{repo_id}/resolve/{revision}/{filename}
class HuggingFaceDownload {
  static const String baseUrl = 'https://huggingface.co';

  /// Build the direct download URL for a file in a repo.
  /// [revision] is usually "main".
  static String resolveUrl({
    required String repoId,
    required String filename,
    String revision = 'main',
  }) {
    return '$baseUrl/$repoId/resolve/$revision/$filename';
  }

  /// Download a single file and save it to [destinationDir].
  /// Returns the path to the saved file. Follows Hugging Face redirects to CDN.
  static Future<File> downloadFile({
    required String repoId,
    required String filename,
    String revision = 'main',
    required String destinationDir,
    void Function(int received, int total)? onProgress,
  }) async {
    final url = resolveUrl(repoId: repoId, filename: filename, revision: revision);
    final response = await http.get(Uri.parse(url));
    if (response.statusCode != 200) {
      throw Exception('Download failed: ${response.statusCode} $url');
    }
    final bytes = response.bodyBytes;
    onProgress?.call(bytes.length, bytes.length);
    final dir = Directory(destinationDir);
    if (!await dir.exists()) await dir.create(recursive: true);
    final file = File(p.join(destinationDir, filename));
    await file.writeAsBytes(bytes);
    return file;
  }

  /// Download Wav2Vec2 model files (config + processor). Use this to get
  /// preprocessor_config.json and config.json for consistent audio preprocessing.
  /// For the actual ONNX, run scripts/export_wav2vec2_onnx.py and copy into the app,
  /// or host the exported ONNX and pass its URL to [downloadFile] with a custom repo/filename.
  static Future<Map<String, File>> downloadWav2Vec2Config({
    String repoId = 'facebook/wav2vec2-xls-r-300m',
    String revision = 'main',
    String? destinationDir,
  }) async {
    final dir = destinationDir ?? (await getTemporaryDirectory()).path;
    final dirPath = p.join(dir, 'wav2vec2_config');
    final files = <String, File>{};
    for (final name in ['config.json', 'preprocessor_config.json']) {
      files[name] = await downloadFile(
        repoId: repoId,
        filename: name,
        revision: revision,
        destinationDir: dirPath,
      );
    }
    return files;
  }
}
