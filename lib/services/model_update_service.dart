import 'dart:io';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:path_provider/path_provider.dart';

class ModelUpdateService {
  static const String _modelVersionKey = 'ml_model_version';
  static const String _lastUpdateKey = 'ml_model_last_update';
  static const String _modelPathKey = 'ml_model_path';

  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static final FirebaseFunctions _functions = FirebaseFunctions.instance;

  // Check if model needs update
  static Future<bool> needsModelUpdate() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final currentVersion = prefs.getInt(_modelVersionKey) ?? 0;

      final modelDoc = await _firestore
          .collection('ml_models')
          .doc('travel_recommendation')
          .get();

      if (!modelDoc.exists) return false;

      final latestVersion = modelDoc.data()?['version'] ?? 0;
      return latestVersion > currentVersion;
    } catch (e) {
      print(' Error checking model update: $e');
      return false;
    }
  }

  // Download and update model
  static Future<bool> downloadAndUpdateModel({
    Function(double)? onProgress,
    Function(String)? onStatusUpdate,
  }) async {
    try {
      onStatusUpdate?.call('🔍 Checking for model updates...');

      final callable = _functions.httpsCallable('getModelDownloadUrl');
      final result = await callable.call();

      final downloadUrl = result.data['downloadUrl'] as String;
      final version = result.data['version'] as int;

      onStatusUpdate?.call(' Downloading updated model...');

      final response = await http.get(Uri.parse(downloadUrl));
      if (response.statusCode != 200) {
        throw Exception('Download failed: ${response.statusCode}');
      }

      onStatusUpdate?.call(' Saving model...');

      final modelPath = await _saveModelToLocal(response.bodyBytes, version);

      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(_modelVersionKey, version);
      await prefs.setInt(_lastUpdateKey, DateTime.now().millisecondsSinceEpoch);
      await prefs.setString(_modelPathKey, modelPath);

      onStatusUpdate?.call(' Model updated successfully!');
      return true;
    } catch (e) {
      print(' Error downloading model: $e');
      return false;
    }
  }

  // Save model to local storage
  static Future<String> _saveModelToLocal(
      List<int> modelBytes, int version) async {
    final directory = await getApplicationDocumentsDirectory();
    final modelDir = Directory('${directory.path}/ml_models');

    if (!await modelDir.exists()) {
      await modelDir.create(recursive: true);
    }

    final modelFile = File('${modelDir.path}/travel_model_v$version.tflite');
    await modelFile.writeAsBytes(modelBytes);

    return modelFile.path;
  }

  // Get model info
  static Future<Map<String, dynamic>> getModelInfo() async {
    final prefs = await SharedPreferences.getInstance();

    return {
      'version': prefs.getInt(_modelVersionKey) ?? 0,
      'lastUpdate': prefs.getInt(_lastUpdateKey) ?? 0,
      'path': prefs.getString(_modelPathKey) ?? '',
      'hasModel': prefs.getString(_modelPathKey) != null,
    };
  }
}
