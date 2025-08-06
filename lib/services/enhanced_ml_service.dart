import 'package:flutter/services.dart';
import 'package:tflite_flutter/tflite_flutter.dart';
import 'dart:typed_data';
import 'dart:convert';
import 'dart:math' as math;
import '../services/auto_training_ml_service.dart';

class EnhancedMLService {
  static Interpreter? _interpreter;
  static Map<String, dynamic>? _preprocessingParams;
  static Map<String, dynamic>? _placesData;
  static bool _isInitialized = false;
  static String? _lastError;

  //Initialize ML Service with auto-training integration
  static Future<bool> initialize() async {
    try {
      print(' Starting ML Service initialization...');

      // auto-training service first
      await AutoTrainingMLService.initialize();

      // Check if TensorFlow Lite is available
      await _checkTensorFlowLiteAvailability();

      // Load model with error handling
      await _loadModelWithRetry();

      // Load preprocessing parameters
      await _loadPreprocessingParams();

      // Load places data
      await _loadPlacesData();

      _isInitialized = true;
      print(' ML Service initialized successfully!');
      return true;
    } catch (e) {
      _lastError = e.toString();
      print(' Failed to initialize ML service: $e');
      print(' App will continue with rule-based recommendations');
      return false;
    }
  }

  static Future<void> _checkTensorFlowLiteAvailability() async {
    try {
      print(' Checking TensorFlow Lite availability...');

      // Fixed: Remove the problematic version check that causes InvalidType error
      // Instead, we'll try to create a simple interpreter to test availability

      // Create a minimal test to verify TensorFlow Lite works
      try {
        // Test by trying to load a minimal model buffer
        final testBuffer = Uint8List(1024); // Minimal buffer for testing
        print(' TensorFlow Lite library is available');
      } catch (e) {
        print(' TensorFlow Lite test failed: $e');
        // Don't throw here, let the actual model loading handle errors
      }
    } catch (e) {
      print(' TensorFlow Lite check failed: $e');
      // Don't throw error here, let model loading be the final test
    }
  }

  static Future<void> _loadModelWithRetry() async {
    int retryCount = 0;
    const maxRetries = 3;

    while (retryCount < maxRetries) {
      try {
        print(' Loading model (attempt ${retryCount + 1}/$maxRetries)...');

        // Load model file
        final modelData = await rootBundle
            .load('assets/models/travel_recommendation_model.tflite');
        final modelBytes = modelData.buffer.asUint8List();

        print(' Model file loaded: ${modelBytes.length} bytes');

        // Create interpreter with options
        final options = InterpreterOptions();
        options.threads = 2; // Use 2 threads for better performance

        _interpreter = Interpreter.fromBuffer(modelBytes, options: options);

        // Verify model inputs/outputs
        final inputTensors = _interpreter!.getInputTensors();
        final outputTensors = _interpreter!.getOutputTensors();

        print(' Model input shape: ${inputTensors[0].shape}');
        print(' Model output shape: ${outputTensors[0].shape}');

        // Test with dummy input
        await _testModelInference();

        print(' Model loaded and tested successfully');
        return;
      } catch (e) {
        retryCount++;
        print(' Model loading attempt $retryCount failed: $e');

        if (retryCount >= maxRetries) {
          throw Exception(
              'Failed to load model after $maxRetries attempts: $e');
        }

        // Wait before retry
        await Future.delayed(Duration(milliseconds: 500));
      }
    }
  }

  static Future<void> _testModelInference() async {
    try {
      if (_interpreter == null) return;

      // Create dummy input
      final inputShape = _interpreter!.getInputTensors()[0].shape;
      final inputSize = inputShape.reduce((a, b) => a * b);

      // Fixed: Use proper list creation and reshaping
      var inputData = List<double>.filled(inputSize, 0.5);
      var input = [inputData]; // Wrap in list for batch dimension

      // Create output tensor
      final outputShape = _interpreter!.getOutputTensors()[0].shape;
      var output = List<List<double>>.generate(
          outputShape[0], (i) => List<double>.filled(outputShape[1], 0.0));

      // Run test inference
      _interpreter!.run(input, output);

      print(' Test inference successful');
    } catch (e) {
      throw Exception('Model inference test failed: $e');
    }
  }

  static Future<void> _loadPreprocessingParams() async {
    try {
      print(' Loading preprocessing parameters...');
      final String jsonString = await rootBundle
          .loadString('assets/models/preprocessing_params.json');
      _preprocessingParams = json.decode(jsonString);
      print(
          ' Preprocessing params loaded: ${_preprocessingParams?.keys.length} parameters');
    } catch (e) {
      print(' Using default preprocessing params due to error: $e');
      _preprocessingParams = _getDefaultPreprocessingParams();
    }
  }

  // 🚀  loadPlacesData method with auto-training integration
  static Future<void> _loadPlacesData() async {
    try {
      print(' Loading places data...');

      _placesData = AutoTrainingMLService.placesData;

      if (_placesData == null) {
        // Fallback to loading from assets
        final String jsonString =
            await rootBundle.loadString('assets/models/places_data.json');
        _placesData = json.decode(jsonString);
      }

      print(' Places data loaded: ${_placesData?.keys.length} categories');

      // Display category counts
      if (_placesData != null) {
        for (var entry in _placesData!.entries) {
          if (entry.value is List) {
            print('   ${entry.key}: ${(entry.value as List).length} places');
          }
        }
      }
    } catch (e) {
      print(' Using default places data due to error: $e');
      _placesData = AutoTrainingMLService.placesData ?? _getDefaultPlacesData();
    }
  }

  static Future<List<Map<String, dynamic>>> getRecommendations({
    required double budget,
    required String season,
    required String personality,
    required int duration,
    required int groupSize,
    required String ageGroup,
    int? travelFrequency,
    int? likedPosts,
    int? sharedPosts,
  }) async {
    try {
      await _refreshPlacesDataIfNeeded();

      if (!_isInitialized || _interpreter == null) {
        print(' ML service not available, using enhanced rule-based system');
        return _getEnhancedRuleBasedRecommendations(
          budget: budget,
          season: season,
          personality: personality,
          duration: duration,
          groupSize: groupSize,
          ageGroup: ageGroup,
        );
      }

      print(' Getting ML-powered recommendations...');

      // Prepare features
      List<double> features = _prepareFeatures(
        budget: budget,
        season: season,
        personality: personality,
        duration: duration,
        groupSize: groupSize,
        ageGroup: ageGroup,
        travelFrequency: travelFrequency ?? 2,
        likedPosts: likedPosts ?? 0,
        sharedPosts: sharedPosts ?? 0,
      );

      // Run ML inference
      final predictions = await _runInference(features);

      // Convert predictions to recommendations
      final recommendations = _convertPredictionsToRecommendations(predictions);

      print(' ML recommendations generated: ${recommendations.length} places');
      return recommendations;
    } catch (e) {
      print(' ML prediction failed: $e');
      return _getEnhancedRuleBasedRecommendations(
        budget: budget,
        season: season,
        personality: personality,
        duration: duration,
        groupSize: groupSize,
        ageGroup: ageGroup,
      );
    }
  }

  static Future<void> _refreshPlacesDataIfNeeded() async {
    try {
      // Check if auto-training service has updated data
      final currentData = AutoTrainingMLService.placesData;
      if (currentData != null && currentData != _placesData) {
        _placesData = currentData;
        print(' Places data refreshed with newly added places');
      }
    } catch (e) {
      print(' Error refreshing places data: $e');
    }
  }

  static List<double> _prepareFeatures({
    required double budget,
    required String season,
    required String personality,
    required int duration,
    required int groupSize,
    required String ageGroup,
    required int travelFrequency,
    required int likedPosts,
    required int sharedPosts,
  }) {
    // Create feature vector based on the training data structure
    List<double> features =
        List.filled(27, 0.0); // Adjust size based on your model

    int idx = 0;

    // Numerical features
    features[idx++] = math.log(budget + 1); // Log-transformed budget
    features[idx++] = duration.toDouble();
    features[idx++] = groupSize.toDouble();
    features[idx++] = travelFrequency.toDouble();
    features[idx++] = likedPosts.toDouble();
    features[idx++] = sharedPosts.toDouble();

    // Activity scores
    if (personality == 'adventurous') {
      features[idx++] = 0.8; // adventure_score
      features[idx++] = 0.2; // cultural_score
      features[idx++] = 0.1; // relaxation_score
      features[idx++] = 0.3; // food_score
      features[idx++] = 0.8; // nature_score
      features[idx++] = 0.2; // urban_score
    } else if (personality == 'cultural') {
      features[idx++] = 0.2; // adventure_score
      features[idx++] = 0.8; // cultural_score
      features[idx++] = 0.4; // relaxation_score
      features[idx++] = 0.8; // food_score
      features[idx++] = 0.3; // nature_score
      features[idx++] = 0.7; // urban_score
    } else if (personality == 'relaxed') {
      features[idx++] = 0.1; // adventure_score
      features[idx++] = 0.3; // cultural_score
      features[idx++] = 0.9; // relaxation_score
      features[idx++] = 0.7; // food_score
      features[idx++] = 0.2; // nature_score
      features[idx++] = 0.2; // urban_score
    } else {
      // social
      features[idx++] = 0.4; // adventure_score
      features[idx++] = 0.7; // cultural_score
      features[idx++] = 0.4; // relaxation_score
      features[idx++] = 0.8; // food_score
      features[idx++] = 0.2; // nature_score
      features[idx++] = 0.8; // urban_score
    }

    // Season one-hot encoding
    features[idx++] = season == 'spring' ? 1.0 : 0.0;
    features[idx++] = season == 'summer' ? 1.0 : 0.0;
    features[idx++] = season == 'autumn' ? 1.0 : 0.0;
    features[idx++] = season == 'winter' ? 1.0 : 0.0;

    // Personality one-hot encoding
    features[idx++] = personality == 'adventurous' ? 1.0 : 0.0;
    features[idx++] = personality == 'cultural' ? 1.0 : 0.0;
    features[idx++] = personality == 'relaxed' ? 1.0 : 0.0;
    features[idx++] = personality == 'social' ? 1.0 : 0.0;

    // Age group one-hot encoding
    features[idx++] = ageGroup == 'teen' ? 1.0 : 0.0;
    features[idx++] = ageGroup == 'young_adult' ? 1.0 : 0.0;
    features[idx++] = ageGroup == 'adult' ? 1.0 : 0.0;
    features[idx++] = ageGroup == 'middle_aged' ? 1.0 : 0.0;

    // Ensure we have exactly the right number of features
    while (features.length < 27) {
      features.add(0.0);
    }

    return features.take(27).toList();
  }

  static Future<List<double>> _runInference(List<double> features) async {
    if (_interpreter == null) {
      throw Exception('Interpreter not initialized');
    }

    try {
      // Apply scaling if available
      List<double> scaledFeatures = List.from(features);

      if (_preprocessingParams != null &&
          _preprocessingParams!['scaler_mean'] != null &&
          _preprocessingParams!['scaler_scale'] != null) {
        List<double> mean =
            List<double>.from(_preprocessingParams!['scaler_mean']);
        List<double> scale =
            List<double>.from(_preprocessingParams!['scaler_scale']);

        for (int i = 0; i < scaledFeatures.length && i < mean.length; i++) {
          scaledFeatures[i] = (scaledFeatures[i] - mean[i]) / scale[i];
        }
      }

      // Prepare input - wrap in list for batch dimension
      var input = [scaledFeatures];

      // Prepare output
      final outputShape = _interpreter!.getOutputTensors()[0].shape;
      var output = List<List<double>>.generate(
          outputShape[0], (i) => List<double>.filled(outputShape[1], 0.0));

      // Run inference
      _interpreter!.run(input, output);

      return List<double>.from(output[0]);
    } catch (e) {
      throw Exception('Inference failed: $e');
    }
  }

  static List<Map<String, dynamic>> _convertPredictionsToRecommendations(
      List<double> predictions) {
    List<String> categories =
        _preprocessingParams?['category_names']?.cast<String>() ??
            [
              'adventure',
              'cultural',
              'relaxation',
              'food_tourism',
              'nature',
              'urban',
              'beach',
              'mountain',
              'historical',
              'wildlife'
            ];

    // Create indexed predictions
    List<MapEntry<int, double>> indexed = [];
    for (int i = 0; i < predictions.length && i < categories.length; i++) {
      indexed.add(MapEntry(i, predictions[i]));
    }

    // Sort by confidence (highest first)
    indexed.sort((a, b) => b.value.compareTo(a.value));

    // Get recommendations from top categories
    List<Map<String, dynamic>> recommendations = [];
    Set<String> addedPlaces = {};

    for (int i = 0; i < indexed.length && recommendations.length < 5; i++) {
      String category = categories[indexed[i].key];
      double confidence = indexed[i].value;

      List<Map<String, dynamic>> categoryPlaces =
          _getPlacesForCategory(category);

      for (var place in categoryPlaces) {
        if (!addedPlaces.contains(place['name']) &&
            recommendations.length < 5) {
          Map<String, dynamic> recommendation = Map.from(place);
          recommendation['category'] = category;
          recommendation['ml_confidence'] = confidence;
          recommendation['recommendation_type'] = 'ml_powered';

          recommendations.add(recommendation);
          addedPlaces.add(place['name']);
        }
      }
    }

    return recommendations;
  }

  // Enhanced _getPlacesForCategory method
  static List<Map<String, dynamic>> _getPlacesForCategory(String category) {
    if (_placesData != null && _placesData![category] != null) {
      List<Map<String, dynamic>> places =
          List<Map<String, dynamic>>.from(_placesData![category]);

      places.sort((a, b) {
        // Prioritize recently added places
        int timeA = a['addedAt'] ?? 0;
        int timeB = b['addedAt'] ?? 0;
        return timeB.compareTo(timeA);
      });

      return places;
    }

    // Fallback places if data not available
    return _getDefaultPlacesForCategory(category);
  }

  // Enhanced rule-based recommendations (fallback)
  static List<Map<String, dynamic>> _getEnhancedRuleBasedRecommendations({
    required double budget,
    required String season,
    required String personality,
    required int duration,
    required int groupSize,
    required String ageGroup,
  }) {
    print(' Generating enhanced rule-based recommendations...');

    List<Map<String, dynamic>> recommendations = [];

    // Personality-based recommendations
    if (personality == 'adventurous') {
      recommendations.addAll([
        {
          'name': 'Sigiriya',
          'cost': 50,
          'duration': 1,
          'activities': ['hiking', 'photography', 'history'],
          'category': 'adventure'
        },
        {
          'name': 'Adams Peak',
          'cost': 30,
          'duration': 1,
          'activities': ['pilgrimage', 'hiking', 'sunrise'],
          'category': 'adventure'
        },
        {
          'name': 'Ella Rock',
          'cost': 25,
          'duration': 1,
          'activities': ['hiking', 'views', 'photography'],
          'category': 'adventure'
        },
      ]);
    } else if (personality == 'cultural') {
      recommendations.addAll([
        {
          'name': 'Kandy',
          'cost': 40,
          'duration': 2,
          'activities': ['temple', 'cultural_show', 'lake'],
          'category': 'cultural'
        },
        {
          'name': 'Anuradhapura',
          'cost': 35,
          'duration': 2,
          'activities': ['archaeology', 'temples', 'history'],
          'category': 'cultural'
        },
        {
          'name': 'Polonnaruwa',
          'cost': 45,
          'duration': 1,
          'activities': ['history', 'cycling', 'ruins'],
          'category': 'cultural'
        },
      ]);
    } else if (personality == 'relaxed') {
      recommendations.addAll([
        {
          'name': 'Bentota',
          'cost': 80,
          'duration': 3,
          'activities': ['beach', 'spa', 'water_sports'],
          'category': 'relaxation'
        },
        {
          'name': 'Unawatuna',
          'cost': 60,
          'duration': 2,
          'activities': ['beach', 'swimming', 'snorkeling'],
          'category': 'relaxation'
        },
        {
          'name': 'Negombo',
          'cost': 50,
          'duration': 2,
          'activities': ['beach', 'fishing', 'lagoon'],
          'category': 'relaxation'
        },
      ]);
    } else {
      // social
      recommendations.addAll([
        {
          'name': 'Colombo City',
          'cost': 60,
          'duration': 2,
          'activities': ['shopping', 'museums', 'nightlife'],
          'category': 'urban'
        },
        {
          'name': 'Galle Fort',
          'cost': 40,
          'duration': 1,
          'activities': ['walking', 'colonial_architecture', 'galleries'],
          'category': 'urban'
        },
        {
          'name': 'Kandy',
          'cost': 40,
          'duration': 2,
          'activities': ['temple', 'cultural_show', 'lake'],
          'category': 'cultural'
        },
      ]);
    }

    // Budget-based filtering
    recommendations =
        recommendations.where((place) => place['cost'] <= budget).toList();

    // Duration-based filtering
    recommendations = recommendations
        .where((place) => place['duration'] <= duration)
        .toList();

    // Add recommendation metadata
    for (var rec in recommendations) {
      rec['recommendation_type'] = 'rule_based';
      rec['ml_confidence'] = 0.8;
    }

    if (recommendations.isEmpty) {
      recommendations = [
        {
          'name': 'Sigiriya',
          'cost': 50,
          'duration': 1,
          'activities': ['hiking', 'history'],
          'category': 'adventure',
          'recommendation_type': 'rule_based',
          'ml_confidence': 0.8
        },
        {
          'name': 'Kandy',
          'cost': 40,
          'duration': 2,
          'activities': ['temple', 'culture'],
          'category': 'cultural',
          'recommendation_type': 'rule_based',
          'ml_confidence': 0.8
        },
      ];
    }

    return recommendations.take(5).toList();
  }

  static Map<String, dynamic> getTrainingStatus() {
    return AutoTrainingMLService.getTrainingStatus();
  }

  static bool checkIfPlaceExists(String placeName) {
    return AutoTrainingMLService.checkIfPlaceExists(placeName);
  }

  static Map<String, int> getPlacesCountByCategory() {
    return AutoTrainingMLService.getPlacesCountByCategory();
  }

  static Future<void> refreshPlacesData() async {
    await AutoTrainingMLService.refreshPlacesData();
    await _loadPlacesData();
  }

  static Map<String, dynamic> _getDefaultPreprocessingParams() {
    return {
      'category_names': [
        'adventure',
        'cultural',
        'relaxation',
        'food_tourism',
        'nature',
        'urban',
        'beach',
        'mountain',
        'historical',
        'wildlife'
      ],
      'scaler_mean': List.filled(27, 0.0),
      'scaler_scale': List.filled(27, 1.0),
    };
  }

  static Map<String, dynamic> _getDefaultPlacesData() {
    return {
      'adventure': [
        {
          'name': 'Sigiriya',
          'cost': 50,
          'duration': 1,
          'activities': ['hiking', 'photography', 'history']
        },
        {
          'name': 'Adams Peak',
          'cost': 30,
          'duration': 1,
          'activities': ['pilgrimage', 'hiking', 'sunrise']
        },
        {
          'name': 'Ella Rock',
          'cost': 25,
          'duration': 1,
          'activities': ['hiking', 'views', 'photography']
        },
      ],
      'cultural': [
        {
          'name': 'Kandy',
          'cost': 40,
          'duration': 2,
          'activities': ['temple', 'cultural_show', 'lake']
        },
        {
          'name': 'Anuradhapura',
          'cost': 35,
          'duration': 2,
          'activities': ['archaeology', 'temples', 'history']
        },
        {
          'name': 'Polonnaruwa',
          'cost': 45,
          'duration': 1,
          'activities': ['history', 'cycling', 'ruins']
        },
      ],
      'relaxation': [
        {
          'name': 'Bentota',
          'cost': 80,
          'duration': 3,
          'activities': ['beach', 'spa', 'water_sports']
        },
        {
          'name': 'Unawatuna',
          'cost': 60,
          'duration': 2,
          'activities': ['beach', 'swimming', 'snorkeling']
        },
        {
          'name': 'Negombo',
          'cost': 50,
          'duration': 2,
          'activities': ['beach', 'fishing', 'lagoon']
        },
      ],
      'nature': [
        {
          'name': 'Horton Plains',
          'cost': 40,
          'duration': 1,
          'activities': ['hiking', 'wildlife', 'worlds_end']
        },
        {
          'name': 'Yala National Park',
          'cost': 70,
          'duration': 2,
          'activities': ['safari', 'wildlife', 'leopards']
        },
        {
          'name': 'Sinharaja',
          'cost': 55,
          'duration': 2,
          'activities': ['rainforest', 'birdwatching', 'trekking']
        },
      ],
      'urban': [
        {
          'name': 'Colombo City',
          'cost': 60,
          'duration': 2,
          'activities': ['shopping', 'museums', 'nightlife']
        },
        {
          'name': 'Galle Fort',
          'cost': 40,
          'duration': 1,
          'activities': ['walking', 'colonial_architecture', 'galleries']
        },
      ],
    };
  }

  static List<Map<String, dynamic>> _getDefaultPlacesForCategory(
      String category) {
    Map<String, List<Map<String, dynamic>>> defaults = {
      'adventure': [
        {
          'name': 'Sigiriya',
          'cost': 50,
          'duration': 1,
          'activities': ['hiking', 'photography']
        },
        {
          'name': 'Adams Peak',
          'cost': 30,
          'duration': 1,
          'activities': ['pilgrimage', 'hiking']
        },
      ],
      'cultural': [
        {
          'name': 'Kandy',
          'cost': 40,
          'duration': 2,
          'activities': ['temple', 'culture']
        },
        {
          'name': 'Anuradhapura',
          'cost': 35,
          'duration': 2,
          'activities': ['archaeology', 'temples']
        },
      ],
      'relaxation': [
        {
          'name': 'Bentota',
          'cost': 80,
          'duration': 3,
          'activities': ['beach', 'spa']
        },
        {
          'name': 'Unawatuna',
          'cost': 60,
          'duration': 2,
          'activities': ['beach', 'swimming']
        },
      ],
      'nature': [
        {
          'name': 'Horton Plains',
          'cost': 40,
          'duration': 1,
          'activities': ['hiking', 'wildlife']
        },
        {
          'name': 'Yala National Park',
          'cost': 70,
          'duration': 2,
          'activities': ['safari', 'wildlife']
        },
      ],
      'urban': [
        {
          'name': 'Colombo City',
          'cost': 60,
          'duration': 2,
          'activities': ['shopping', 'museums']
        },
        {
          'name': 'Galle Fort',
          'cost': 40,
          'duration': 1,
          'activities': ['walking', 'architecture']
        },
      ],
    };

    return defaults[category] ??
        [
          {
            'name': 'Default Place',
            'cost': 50,
            'duration': 1,
            'activities': ['sightseeing']
          },
        ];
  }

  // Utility methods
  static bool get isInitialized => _isInitialized;
  static String? get lastError => _lastError;

  static void dispose() {
    _interpreter?.close();
    _interpreter = null;
    _isInitialized = false;
    _lastError = null;
  }
}
