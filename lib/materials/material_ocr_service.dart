import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:path/path.dart' as p;

import '../services/gueter_storage_service.dart';

class MaterialOcrResult {
  const MaterialOcrResult({
    required this.sourcePath,
    required this.text,
    required this.createdAt,
  });

  final String sourcePath;
  final String text;
  final DateTime createdAt;
}

class MaterialOcrService {
  const MaterialOcrService();

  bool get isSupported => defaultTargetPlatform == TargetPlatform.android;

  Future<MaterialOcrResult> recognizeImage(String imagePath) async {
    if (!isSupported) {
      throw UnsupportedError('当前平台暂不支持本地 OCR。');
    }
    final recognizer = TextRecognizer(script: TextRecognitionScript.chinese);
    try {
      final result = await recognizer.processImage(
        InputImage.fromFilePath(imagePath),
      );
      return MaterialOcrResult(
        sourcePath: imagePath,
        text: result.text.trim(),
        createdAt: DateTime.now(),
      );
    } finally {
      await recognizer.close();
    }
  }

  Future<File> saveText(MaterialOcrResult result) async {
    final dir = await GueterStorageService.instance.publicDirectory(
      GueterPublicDirectory.ocrTexts,
    );
    final stem = p.basenameWithoutExtension(result.sourcePath);
    final file = File(
      p.join(
        dir.path,
        '${stem}_${result.createdAt.millisecondsSinceEpoch}.txt',
      ),
    );
    await file.writeAsString(result.text, flush: true);
    return file;
  }
}
