import 'dart:convert';
import 'package:flutter/services.dart';

class PlacesDataManager {
  static Map<String, dynamic>? _placesData;
  static bool _isInitialized = false;

  // Initialize places data from assets
  static Future<void> initialize() async {
    try {
      final String jsonString =
          await rootBundle.loadString('assets/models/places_data.json');
      _placesData = json.decode(jsonString);
      _isInitialized = true;
      print(' Places data loaded: ${_placesData?.keys.length} categories');
    } catch (e) {
      print(' Error loading places data: $e');
      _placesData = _getDefaultPlacesData();
      _isInitialized = true;
    }
  }

  // Check if place already exists
  static bool isPlaceExists(String placeName) {
    if (!_isInitialized || _placesData == null) return false;

    for (String category in _placesData!.keys) {
      List<dynamic> places = _placesData![category] ?? [];
      if (places.any((place) =>
          place['name']?.toString().toLowerCase() == placeName.toLowerCase())) {
        return true;
      }
    }
    return false;
  }

  // AI-powered category determination
  static String determineCategory(
      String caption, String placeName, String cityName) {
    String text = '$caption $placeName $cityName'.toLowerCase();

    Map<String, List<String>> categoryKeywords = {
      'adventure': [
        'hiking',
        'climbing',
        'adventure',
        'trek',
        'mountain',
        'rock',
        'peak'
      ],
      'cultural': [
        'temple',
        'culture',
        'traditional',
        'heritage',
        'museum',
        'art',
        'festival'
      ],
      'relaxation': [
        'beach',
        'spa',
        'relax',
        'peaceful',
        'calm',
        'resort',
        'wellness'
      ],
      'food_tourism': [
        'food',
        'restaurant',
        'cuisine',
        'spice',
        'cooking',
        'market',
        'taste'
      ],
      'nature': [
        'nature',
        'forest',
        'wildlife',
        'birds',
        'trees',
        'garden',
        'waterfall'
      ],
      'urban': [
        'city',
        'shopping',
        'building',
        'modern',
        'urban',
        'mall',
        'business'
      ],
      'beach': [
        'beach',
        'ocean',
        'sea',
        'waves',
        'sand',
        'swimming',
        'surfing'
      ],
      'mountain': [
        'mountain',
        'hill',
        'valley',
        'elevation',
        'highland',
        'tea estates'
      ],
      'historical': [
        'historical',
        'ancient',
        'ruins',
        'archaeological',
        'monument'
      ],
      'wildlife': [
        'wildlife',
        'animals',
        'safari',
        'elephant',
        'leopard',
        'national park'
      ]
    };

    Map<String, int> categoryScores = {};
    for (String category in categoryKeywords.keys) {
      categoryScores[category] = 0;
      for (String keyword in categoryKeywords[category]!) {
        if (text.contains(keyword)) {
          categoryScores[category] = categoryScores[category]! + 1;
        }
      }
    }

    String bestCategory = 'cultural'; // default
    int highestScore = 0;

    categoryScores.forEach((category, score) {
      if (score > highestScore) {
        highestScore = score;
        bestCategory = category;
      }
    });

    return bestCategory;
  }

  // Extract activities from caption
  static List<String> extractActivities(String caption, String category) {
    String text = caption.toLowerCase();
    List<String> activities = [];

    Map<String, List<String>> activityKeywords = {
      'adventure': [
        'hiking',
        'climbing',
        'trekking',
        'rock climbing',
        'rafting'
      ],
      'cultural': [
        'temple visit',
        'cultural show',
        'heritage tour',
        'traditional'
      ],
      'relaxation': ['beach', 'spa', 'relaxation', 'swimming', 'massage'],
      'food_tourism': [
        'food tasting',
        'cooking',
        'local cuisine',
        'market visit'
      ],
      'nature': ['nature walk', 'bird watching', 'forest', 'wildlife'],
      'urban': ['shopping', 'city tour', 'nightlife', 'museums'],
      'beach': ['swimming', 'surfing', 'beach', 'snorkeling', 'water sports'],
      'mountain': ['mountain climbing', 'views', 'tea estates', 'cool climate'],
      'historical': ['archaeology', 'ancient sites', 'monuments', 'ruins'],
      'wildlife': [
        'safari',
        'animal watching',
        'conservation',
        'nature reserve'
      ]
    };

    List<String> possibleActivities =
        activityKeywords[category] ?? ['sightseeing'];

    for (String activity in possibleActivities) {
      if (text.contains(activity.toLowerCase())) {
        activities.add(activity);
      }
    }

    if (activities.isEmpty) {
      activities.add('sightseeing');
    }

    return activities.take(3).toList();
  }

  // Add new place to database
  static Future<bool> addNewPlace({
    required String placeName,
    required String cityName,
    required String caption,
    required double estimatedBudget,
    required String category,
    String? imageUrl,
  }) async {
    try {
      if (!_isInitialized || _placesData == null) {
        await initialize();
      }

      Map<String, dynamic> newPlace = {
        'name': placeName,
        'cost': estimatedBudget.round(),
        'duration': estimatedBudget > 100 ? 2 : 1,
        'activities': extractActivities(caption, category),
        'image': imageUrl ??
            'https://images.unsplash.com/photo-1506905925346-21bda4d32df4?w=800&h=600&fit=crop&q=80',
        'city': cityName,
        'user_contributed': true,
        'added_date': DateTime.now().millisecondsSinceEpoch,
      };

      if (_placesData![category] == null) {
        _placesData![category] = [];
      }

      (_placesData![category] as List).add(newPlace);

      print(' New place added: $placeName to $category category');
      return true;
    } catch (e) {
      print(' Error adding new place: $e');
      return false;
    }
  }

  // Get default places data if assets fail to load
  static Map<String, dynamic> _getDefaultPlacesData() {
    return {
      'adventure': [],
      'cultural': [],
      'relaxation': [],
      'food_tourism': [],
      'nature': [],
      'urban': [],
      'beach': [],
      'mountain': [],
      'historical': [],
      'wildlife': []
    };
  }

  // Get places for category
  static List<Map<String, dynamic>> getPlacesForCategory(String category) {
    if (!_isInitialized || _placesData == null) return [];

    List<dynamic> places = _placesData![category] ?? [];
    return places.map((place) => Map<String, dynamic>.from(place)).toList();
  }

  // Get all places data
  static Map<String, dynamic>? getPlaceData() => _placesData;
}
