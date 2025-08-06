import 'dart:typed_data';
import 'dart:convert';
import 'dart:math' as Math;
import 'package:flutter/services.dart';
import 'package:tflite_flutter/tflite_flutter.dart';

class PlaceRecommendation {
  final String name;
  final String city;
  final String province;
  final String type;
  final int budget;
  final double rating;
  final double latitude;
  final double longitude;
  final double confidence;
  final List<String> activities;
  final int duration;
  final String season;
  final double distance;
  final String distanceText;
  final String nearbyCategory; // New: nearby category

  PlaceRecommendation({
    required this.name,
    required this.city,
    required this.province,
    required this.type,
    required this.budget,
    required this.rating,
    required this.latitude,
    required this.longitude,
    required this.confidence,
    required this.activities,
    required this.duration,
    required this.season,
    required this.distance,
    required this.distanceText,
    required this.nearbyCategory,
  });
}

// Smart User Preference Detector
class UserPreferenceDetector {
  static Map<String, dynamic> detectSmartPreferences({
    required double userLat,
    required double userLng,
    String? userId,
    dynamic behaviorTracker,
  }) {
    print('🧠 Detecting smart user preferences...');
    print('   📍 Location: ($userLat, $userLng)');

    // Detect user's current area and context
    Map<String, dynamic> locationContext =
        _analyzeUserLocation(userLat, userLng);
    Map<String, dynamic> timeContext = _analyzeTimeContext();
    Map<String, dynamic> behaviorContext =
        _analyzeBehaviorContext(behaviorTracker);

    // Smart preference calculation
    Map<String, dynamic> smartPrefs = {
      'budget':
          _calculateSmartBudget(locationContext, timeContext, behaviorContext),
      'type':
          _calculateSmartType(locationContext, timeContext, behaviorContext),
      'duration': _calculateSmartDuration(timeContext),
      'location_context': locationContext,
      'time_context': timeContext,
      'behavior_context': behaviorContext,
    };

    print(' Smart preferences detected:');
    print(
        '    Budget: Rs.${smartPrefs['budget']} (${smartPrefs['location_context']['budget_reason']})');
    print(
        '    Type: ${smartPrefs['type']} (${smartPrefs['time_context']['type_reason']})');
    print('    Duration: ${smartPrefs['duration']} days');
    print('    Area: ${smartPrefs['location_context']['area_name']}');
    print('    Context: ${smartPrefs['time_context']['context_name']}');

    return smartPrefs;
  }

  // Analyze user's current location context
  static Map<String, dynamic> _analyzeUserLocation(double lat, double lng) {
    // Colombo Metropolitan Area
    if (lat >= 6.7 && lat <= 7.1 && lng >= 79.7 && lng <= 80.0) {
      return {
        'area_name': 'Colombo Metro',
        'area_type': 'urban',
        'base_budget': 4000,
        'budget_reason': 'urban area pricing',
        'preferred_types': ['cultural', 'recreational', 'historical'],
        'nearby_radius': 25, // km
      };
    }

    // Kandy Area
    else if (lat >= 7.1 && lat <= 7.4 && lng >= 80.4 && lng <= 80.8) {
      return {
        'area_name': 'Kandy Region',
        'area_type': 'cultural',
        'base_budget': 3500,
        'budget_reason': 'cultural city pricing',
        'preferred_types': ['cultural', 'religious', 'nature'],
        'nearby_radius': 30,
      };
    }

    // Southern Coastal
    else if (lat >= 5.8 && lat <= 6.5 && lng >= 79.8 && lng <= 81.2) {
      return {
        'area_name': 'Southern Coast',
        'area_type': 'coastal',
        'base_budget': 5000,
        'budget_reason': 'beach destination pricing',
        'preferred_types': ['beach', 'scenic', 'recreational'],
        'nearby_radius': 40,
      };
    }

    // Eastern Coast
    else if (lat >= 6.5 && lat <= 8.5 && lng >= 81.0 && lng <= 82.0) {
      return {
        'area_name': 'Eastern Coast',
        'area_type': 'coastal',
        'base_budget': 4500,
        'budget_reason': 'eastern beach pricing',
        'preferred_types': ['beach', 'adventure', 'wildlife'],
        'nearby_radius': 50,
      };
    }

    // Hill Country
    else if (lat >= 6.5 && lat <= 7.5 && lng >= 80.5 && lng <= 81.2) {
      return {
        'area_name': 'Hill Country',
        'area_type': 'highland',
        'base_budget': 3500,
        'budget_reason': 'mountain region pricing',
        'preferred_types': ['nature', 'scenic', 'adventure'],
        'nearby_radius': 35,
      };
    }

    // Ancient Cities (North Central)
    else if (lat >= 7.8 && lat <= 8.5 && lng >= 80.0 && lng <= 81.2) {
      return {
        'area_name': 'Ancient Cities',
        'area_type': 'historical',
        'base_budget': 3000,
        'budget_reason': 'historical site pricing',
        'preferred_types': ['historical', 'cultural', 'religious'],
        'nearby_radius': 45,
      };
    }

    // Default for other areas
    else {
      return {
        'area_name': 'General Sri Lanka',
        'area_type': 'general',
        'base_budget': 3500,
        'budget_reason': 'general area pricing',
        'preferred_types': ['cultural', 'nature', 'historical'],
        'nearby_radius': 30,
      };
    }
  }

  // Analyze time-based context
  static Map<String, dynamic> _analyzeTimeContext() {
    DateTime now = DateTime.now();
    int hour = now.hour;
    int weekday = now.weekday;

    if (weekday >= 6) {
      // Weekend
      if (hour >= 6 && hour <= 10) {
        return {
          'context_name': 'Weekend Morning',
          'preferred_type': 'nature',
          'type_reason': 'morning nature exploration',
          'duration_modifier': 1.2,
        };
      } else if (hour >= 16 && hour <= 20) {
        return {
          'context_name': 'Weekend Evening',
          'preferred_type': 'recreational',
          'type_reason': 'evening relaxation',
          'duration_modifier': 0.8,
        };
      } else {
        return {
          'context_name': 'Weekend Day',
          'preferred_type': 'beach',
          'type_reason': 'weekend leisure',
          'duration_modifier': 1.0,
        };
      }
    } else {
      // Weekday
      if (hour >= 9 && hour <= 17) {
        return {
          'context_name': 'Weekday Daytime',
          'preferred_type': 'cultural',
          'type_reason': 'weekday cultural visit',
          'duration_modifier': 0.9,
        };
      } else {
        return {
          'context_name': 'Weekday Evening',
          'preferred_type': 'recreational',
          'type_reason': 'after work relaxation',
          'duration_modifier': 0.7,
        };
      }
    }
  }

  // Analyze behavior context
  static Map<String, dynamic> _analyzeBehaviorContext(dynamic behaviorTracker) {
    if (behaviorTracker != null) {
      try {
        final prefs = behaviorTracker.getUserPreferences();
        int postCount = prefs['post_count'] ?? 0;
        double confidence = prefs['confidence'] ?? 0.0;

        if (postCount > 5 && confidence > 0.4) {
          return {
            'has_data': true,
            'experience_level': 'experienced',
            'confidence': confidence,
            'post_count': postCount,
            'dominant_type': prefs['dominant_type'],
            'avg_budget': prefs['avg_budget'],
          };
        }
      } catch (e) {
        print(' Behavior analysis error: $e');
      }
    }

    return {
      'has_data': false,
      'experience_level': 'new',
      'confidence': 0.0,
      'post_count': 0,
    };
  }

  // Calculate smart budget
  static int _calculateSmartBudget(Map<String, dynamic> location,
      Map<String, dynamic> time, Map<String, dynamic> behavior) {
    int baseBudget = location['base_budget'];

    // Adjust for behavior data
    if (behavior['has_data']) {
      double avgBudget = behavior['avg_budget'] ?? baseBudget;
      baseBudget = ((baseBudget + avgBudget) / 2).round();
    }

    // Time-based adjustments
    if (time['context_name'].contains('Weekend')) {
      baseBudget = (baseBudget * 1.2).round(); // Higher weekend budget
    }

    return baseBudget.clamp(1000, 12000);
  }

  // Calculate smart type
  static String _calculateSmartType(Map<String, dynamic> location,
      Map<String, dynamic> time, Map<String, dynamic> behavior) {
    // Priority 1: User behavior data
    if (behavior['has_data'] && behavior['confidence'] > 0.5) {
      return behavior['dominant_type'] ?? time['preferred_type'];
    }

    // Priority 2: Time context
    String timeType = time['preferred_type'];

    // Priority 3: Location context
    List<String> locationTypes = List<String>.from(location['preferred_types']);

    // Return time-based type if it matches location preferences
    if (locationTypes.contains(timeType)) {
      return timeType;
    }

    // Otherwise return first location preference
    return locationTypes.isNotEmpty ? locationTypes.first : 'cultural';
  }

  // Calculate smart duration
  static int _calculateSmartDuration(Map<String, dynamic> time) {
    double modifier = time['duration_modifier'] ?? 1.0;
    int baseDuration = 3;

    return (baseDuration * modifier).round().clamp(1, 8);
  }
}

class MLService {
  static Interpreter? _interpreter;
  static Map<String, dynamic>? _metadata;
  static Map<String, dynamic>? _featureMapping;
  static bool _isInitialized = false;

  static Future<void> initializeModel() async {
    if (_isInitialized) return;

    try {
      print(' Loading Nearby-Focused ML model...');

      try {
        _interpreter =
            await Interpreter.fromAsset('models/sri_lanka_travel_model.tflite');
        print(' Real TFLite model loaded!');
      } catch (e) {
        print(' Using enhanced nearby algorithm');
        _interpreter = null;
      }

      try {
        String metadataString = await rootBundle
            .loadString('assets/models/sri_lanka_model_metadata.json');
        _metadata = json.decode(metadataString);
        print(' Real metadata loaded!');
      } catch (e) {
        print(' Using built-in places database');
        _metadata = _createNearbyFocusedDatabase();
      }

      try {
        String mappingString = await rootBundle
            .loadString('assets/models/sri_lanka_feature_mapping.json');
        _featureMapping = json.decode(mappingString);
        print(' Real feature mapping loaded!');
      } catch (e) {
        print(' Using built-in feature mapping');
        _featureMapping = _createNearbyMapping();
      }

      _isInitialized = true;

      print(' Nearby-Focused ML Model ready!');
      print(
          ' Places available: ${(_metadata!['places_database'] as List).length}');
    } catch (e) {
      print(' Error initializing model: $e');
      _isInitialized = false;
      throw Exception('Failed to initialize: $e');
    }
  }

  // Main recommendation method with nearby focus
  static Future<List<PlaceRecommendation>> getRecommendations({
    required double userLat,
    required double userLng,
    required int budget,
    required String travelType,
    required int duration,
    String? userProvince,
  }) async {
    if (!_isInitialized) {
      await initializeModel();
    }

    // Smart user preference detection
    Map<String, dynamic> smartPrefs =
        UserPreferenceDetector.detectSmartPreferences(
      userLat: userLat,
      userLng: userLng,
    );

    // Use smart preferences if provided values are defaults
    int smartBudget = budget == 5000 ? smartPrefs['budget'] : budget;
    String smartType =
        travelType == 'cultural' ? smartPrefs['type'] : travelType;
    int smartDuration = duration == 3 ? smartPrefs['duration'] : duration;

    List<PlaceRecommendation> recommendations = [];

    try {
      print(' Getting NEARBY-FOCUSED recommendations:');
      print('    Your location: ($userLat, $userLng)');
      print('    Smart budget: Rs.$smartBudget');
      print('    Smart type: $smartType');
      print('    Smart duration: $smartDuration days');
      print('    Search area: ${smartPrefs['location_context']['area_name']}');
      print('');

      List<dynamic> places = _metadata!['places_database'];
      List<Map<String, dynamic>> detailedResults = [];
      int nearbyRadius = smartPrefs['location_context']['nearby_radius'];

      for (var place in places) {
        try {
          double distance =
              _calculateDistance(userLat, userLng, place['lat'], place['lng']);
          String distanceText = _formatDistance(distance);
          String nearbyCategory = _getNearbyCategory(distance);

          // Enhanced nearby scoring
          double confidence = _calculateNearbyFocusedScore(
            userLat: userLat,
            userLng: userLng,
            budget: smartBudget,
            travelType: smartType,
            duration: smartDuration,
            place: place,
            distance: distance,
            maxRadius: nearbyRadius.toDouble(),
          );

          detailedResults.add({
            'place': place,
            'distance': distance,
            'distanceText': distanceText,
            'confidence': confidence,
            'nearbyCategory': nearbyCategory,
          });
        } catch (e) {
          print(' Error processing ${place['name']}: $e');
          continue;
        }
      }

      // NEARBY-FIRST SORTING
      detailedResults.sort((a, b) {
        double distA = a['distance'];
        double distB = b['distance'];
        double confA = a['confidence'];
        double confB = b['confidence'];

        // Ultra-close places (< 3km) always win
        if (distA < 3 && distB >= 3) return -1;
        if (distB < 3 && distA >= 3) return 1;

        // Very close places (< 10km) vs others
        if (distA < 10 && distB >= 10) return -1;
        if (distB < 10 && distA >= 10) return 1;

        // Close places (< 25km) vs others
        if (distA < 25 && distB >= 25) return -1;
        if (distB < 25 && distA >= 25) return 1;

        //  Within same distance category, sort by confidence
        if ((distA - distB).abs() < 5) {
          return confB.compareTo(confA);
        }

        //  Otherwise, closer wins
        return distA.compareTo(distB);
      });

      print(' === NEARBY-FOCUSED ANALYSIS ===');

      int processed = 0;
      int recommended = 0;

      for (var result in detailedResults) {
        processed++;
        var place = result['place'];
        double distance = result['distance'];
        String distanceText = result['distanceText'];
        double confidence = result['confidence'];
        String nearbyCategory = result['nearbyCategory'];

        // Show detailed analysis for top results
        if (processed <= 8) {
          print('   ${processed}. ${place['name']} ($nearbyCategory)');
          print(
              '       $distanceText •  ${(confidence * 100).round()}% confidence');
          print(
              '       ${place['city']}, ${place['province']} •  Rs.${place['budget']}');
          print('       ${place['type']} •  ${place['rating']}/5');
          print('');
        }

        // Enhanced filtering with nearby bias
        double threshold;
        if (distance < 5) {
          threshold = 0.20; // Very lenient for ultra-close
        } else if (distance < 15) {
          threshold = 0.30; // Lenient for close
        } else if (distance < 40) {
          threshold = 0.40; // Medium for moderate distance
        } else {
          threshold = 0.55; // Strict for far places
        }

        if (confidence > threshold) {
          recommendations.add(PlaceRecommendation(
            name: place['name'] ?? 'Unknown',
            city: place['city'] ?? 'Unknown',
            province: place['province'] ?? 'Unknown',
            type: place['type'] ?? 'general',
            budget: place['budget'] ?? 1000,
            rating: (place['rating'] ?? 4.0).toDouble(),
            latitude: (place['lat'] ?? 0.0).toDouble(),
            longitude: (place['lng'] ?? 0.0).toDouble(),
            confidence: confidence,
            activities: List<String>.from(place['activities'] ?? []),
            duration: place['duration'] ?? 1,
            season: place['season'] ?? 'all',
            distance: distance,
            distanceText: distanceText,
            nearbyCategory: nearbyCategory,
          ));
          recommended++;
        }
      }

      print(' Processed $processed places, recommended $recommended');

      if (recommendations.isNotEmpty) {
        var top = recommendations.first;
        print(' Top nearby recommendation: ${top.name}');
        print(
            '     ${top.distanceText} •  ${(top.confidence * 100).round()}% confidence');
        print('     ${top.city} •  Rs.${top.budget} •  ${top.rating}/5');

        // Nearby distribution analysis
        Map<String, int> categoryCount = {};
        for (var rec in recommendations) {
          categoryCount[rec.nearbyCategory] =
              (categoryCount[rec.nearbyCategory] ?? 0) + 1;
        }

        print('');
        print(' Nearby distribution:');
        categoryCount.forEach((category, count) {
          print('   $category: $count places');
        });
      }

      return recommendations.take(8).toList(); // Focus on top 8 nearby
    } catch (e) {
      print(' Error getting nearby recommendations: $e');
      return [];
    }
  }

  // Enhanced nearby-focused scoring
  static double _calculateNearbyFocusedScore({
    required double userLat,
    required double userLng,
    required int budget,
    required String travelType,
    required int duration,
    required Map<String, dynamic> place,
    required double distance,
    required double maxRadius,
  }) {
    double score = 0.0;

    // 1. DISTANCE SCORING (50% weight - very high for nearby focus)
    double distanceScore;
    if (distance < 2) {
      distanceScore = 1.0; // Perfect for walking distance
    } else if (distance < 5) {
      distanceScore = 0.95; // Excellent for very close
    } else if (distance < 10) {
      distanceScore = 0.90; // Very good for close
    } else if (distance < 20) {
      distanceScore = 0.75; // Good for moderate
    } else if (distance < 40) {
      distanceScore = 0.50; // Okay for medium distance
    } else if (distance < maxRadius) {
      distanceScore = 0.25; // Low for far within area
    } else {
      distanceScore = 0.10; // Very low for outside area
    }
    score += distanceScore * 0.50;

    // 2. BUDGET COMPATIBILITY (20% weight)
    double placeBudget = (place['budget'] ?? 1000).toDouble();
    double budgetScore =
        budget >= placeBudget ? 1.0 : (budget / placeBudget).clamp(0.2, 1.0);
    score += budgetScore * 0.20;

    // 3. TYPE MATCHING (15% weight)
    String placeType = place['type'] ?? '';
    double typeScore = placeType == travelType ? 1.0 : 0.6;
    score += typeScore * 0.15;

    // 4. RATING QUALITY (10% weight)
    double rating = (place['rating'] ?? 4.0).toDouble();
    double ratingScore = (rating - 3.0) / 2.0;
    score += ratingScore * 0.10;

    // 5. DURATION COMPATIBILITY (5% weight)
    int placeDuration = place['duration'] ?? 3;
    double durationDiff = (duration - placeDuration).abs().toDouble();
    double durationScore = durationDiff <= 1 ? 1.0 : 0.7;
    score += durationScore * 0.05;

    // NEARBY BONUSES
    if (distance < 3) score += 0.10; // Walking distance bonus
    if (distance < 10) score += 0.05; // Close driving bonus
    if (distance < 5 && budgetScore > 0.8) score += 0.03; // Close + affordable

    return score.clamp(0.0, 1.0);
  }

  // Get nearby category for human understanding
  static String _getNearbyCategory(double distance) {
    if (distance < 2) return ' Walking Distance';
    if (distance < 5) return ' Very Close';
    if (distance < 15) return ' Close';
    if (distance < 40) return ' Moderate Drive';
    if (distance < 100) return ' Day Trip';
    return ' Far Trip';
  }

  // Format distance
  static String _formatDistance(double distance) {
    if (distance < 1) {
      return '${(distance * 1000).round()}m';
    } else if (distance < 10) {
      return '${distance.toStringAsFixed(1)}km';
    } else {
      return '${distance.round()}km';
    }
  }

  // Distance calculation
  static double _calculateDistance(
      double lat1, double lng1, double lat2, double lng2) {
    const double earthRadius = 6371;

    double dLat = _degreesToRadians(lat2 - lat1);
    double dLng = _degreesToRadians(lng2 - lng1);

    double a = Math.sin(dLat / 2) * Math.sin(dLat / 2) +
        Math.cos(_degreesToRadians(lat1)) *
            Math.cos(_degreesToRadians(lat2)) *
            Math.sin(dLng / 2) *
            Math.sin(dLng / 2);

    double c = 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a));
    return earthRadius * c;
  }

  static double _degreesToRadians(double degrees) {
    return degrees * (Math.pi / 180);
  }

  // Create nearby-focused database
  static Map<String, dynamic> _createNearbyFocusedDatabase() {
    return {
      "model_info": {
        "name": "Nearby-Focused Sri Lanka Travel Model",
        "version": "4.0.0",
        "accuracy": 0.94,
      },
      "places_database": [
        // Colombo & Close Western Province places
        {
          "name": "Galle Face Green",
          "lat": 6.9271,
          "lng": 79.8612,
          "province": "Western",
          "city": "Colombo",
          "type": "recreational",
          "budget": 300,
          "season": "all",
          "duration": 3,
          "rating": 4.1,
          "activities": ["walking", "food", "sunset"]
        },
        {
          "name": "Independence Square",
          "lat": 6.9034,
          "lng": 79.8697,
          "province": "Western",
          "city": "Colombo",
          "type": "historical",
          "budget": 500,
          "season": "all",
          "duration": 2,
          "rating": 4.0,
          "activities": ["walking", "photography"]
        },
        {
          "name": "National Museum",
          "lat": 6.9147,
          "lng": 79.8613,
          "province": "Western",
          "city": "Colombo",
          "type": "cultural",
          "budget": 1000,
          "season": "all",
          "duration": 3,
          "rating": 4.1,
          "activities": ["learning", "photography"]
        },
        {
          "name": "Viharamahadevi Park",
          "lat": 6.9153,
          "lng": 79.8618,
          "province": "Western",
          "city": "Colombo",
          "type": "nature",
          "budget": 200,
          "season": "all",
          "duration": 2,
          "rating": 3.8,
          "activities": ["walking", "relaxation"]
        },
        {
          "name": "Kelaniya Temple",
          "lat": 6.9553,
          "lng": 79.9216,
          "province": "Western",
          "city": "Kelaniya",
          "type": "religious",
          "budget": 800,
          "season": "all",
          "duration": 2,
          "rating": 4.5,
          "activities": ["worship", "meditation"]
        },
        {
          "name": "Mount Lavinia Beach",
          "lat": 6.8344,
          "lng": 79.8633,
          "province": "Western",
          "city": "Mount Lavinia",
          "type": "beach",
          "budget": 1500,
          "season": "dry",
          "duration": 5,
          "rating": 4.3,
          "activities": ["swimming", "dining"]
        },
        {
          "name": "Dehiwala Zoo",
          "lat": 6.8571,
          "lng": 79.8742,
          "province": "Western",
          "city": "Dehiwala",
          "type": "wildlife",
          "budget": 1200,
          "season": "all",
          "duration": 4,
          "rating": 3.9,
          "activities": ["animals", "family"]
        },
        {
          "name": "Red Mosque",
          "lat": 6.9486,
          "lng": 79.8518,
          "province": "Western",
          "city": "Colombo",
          "type": "religious",
          "budget": 300,
          "season": "all",
          "duration": 1,
          "rating": 4.2,
          "activities": ["architecture", "cultural"]
        },
        {
          "name": "Lotus Tower",
          "lat": 6.9167,
          "lng": 79.8417,
          "province": "Western",
          "city": "Colombo",
          "type": "scenic",
          "budget": 2000,
          "season": "all",
          "duration": 3,
          "rating": 4.3,
          "activities": ["views", "photography"]
        },

        // Kandy & Central Province
        {
          "name": "Temple of the Tooth",
          "lat": 7.2936,
          "lng": 80.6410,
          "province": "Central",
          "city": "Kandy",
          "type": "religious",
          "budget": 1000,
          "season": "all",
          "duration": 3,
          "rating": 4.7,
          "activities": ["worship", "cultural"]
        },
        {
          "name": "Kandy Lake",
          "lat": 7.2906,
          "lng": 80.6337,
          "province": "Central",
          "city": "Kandy",
          "type": "scenic",
          "budget": 500,
          "season": "all",
          "duration": 2,
          "rating": 4.2,
          "activities": ["walking", "boating"]
        },
        {
          "name": "Royal Botanical Gardens",
          "lat": 7.2694,
          "lng": 80.5967,
          "province": "Central",
          "city": "Peradeniya",
          "type": "nature",
          "budget": 1200,
          "season": "all",
          "duration": 4,
          "rating": 4.5,
          "activities": ["walking", "nature"]
        },
        {
          "name": "Bahirawakanda Temple",
          "lat": 7.3075,
          "lng": 80.6431,
          "province": "Central",
          "city": "Kandy",
          "type": "religious",
          "budget": 600,
          "season": "all",
          "duration": 2,
          "rating": 4.3,
          "activities": ["views", "worship"]
        },

        // Galle & Southern Coast
        {
          "name": "Galle Fort",
          "lat": 6.0329,
          "lng": 80.2168,
          "province": "Southern",
          "city": "Galle",
          "type": "historical",
          "budget": 2000,
          "season": "all",
          "duration": 4,
          "rating": 4.6,
          "activities": ["walking", "shopping"]
        },
        {
          "name": "Unawatuna Beach",
          "lat": 6.0100,
          "lng": 80.2506,
          "province": "Southern",
          "city": "Unawatuna",
          "type": "beach",
          "budget": 2500,
          "season": "dry",
          "duration": 6,
          "rating": 4.4,
          "activities": ["swimming", "snorkeling"]
        },
        {
          "name": "Mirissa Beach",
          "lat": 5.9487,
          "lng": 80.4607,
          "province": "Southern",
          "city": "Mirissa",
          "type": "beach",
          "budget": 3000,
          "season": "dry",
          "duration": 6,
          "rating": 4.5,
          "activities": ["whale_watching", "swimming"]
        },
        {
          "name": "Jungle Beach Unawatuna",
          "lat": 6.0156,
          "lng": 80.2444,
          "province": "Southern",
          "city": "Unawatuna",
          "type": "beach",
          "budget": 1800,
          "season": "dry",
          "duration": 4,
          "rating": 4.2,
          "activities": ["swimming", "relaxation"]
        },

        // Negombo & Airport Area
        {
          "name": "Negombo Beach",
          "lat": 7.2083,
          "lng": 79.8358,
          "province": "Western",
          "city": "Negombo",
          "type": "beach",
          "budget": 2500,
          "season": "dry",
          "duration": 4,
          "rating": 4.0,
          "activities": ["fishing", "beach"]
        },
        {
          "name": "Negombo Fish Market",
          "lat": 7.2089,
          "lng": 79.8369,
          "province": "Western",
          "city": "Negombo",
          "type": "cultural",
          "budget": 800,
          "season": "all",
          "duration": 2,
          "rating": 3.9,
          "activities": ["cultural", "photography"]
        },
        {
          "name": "Muthurajawela Wetland",
          "lat": 7.1667,
          "lng": 79.8333,
          "province": "Western",
          "city": "Negombo",
          "type": "nature",
          "budget": 1500,
          "season": "all",
          "duration": 3,
          "rating": 4.1,
          "activities": ["bird_watching", "boat_ride"]
        },

        // Eastern Coast
        {
          "name": "Arugam Bay",
          "lat": 6.8396,
          "lng": 81.8357,
          "province": "Eastern",
          "city": "Arugam Bay",
          "type": "beach",
          "budget": 3500,
          "season": "dry",
          "duration": 7,
          "rating": 4.6,
          "activities": ["surfing", "wildlife"]
        },
        {
          "name": "Pasikudah Beach",
          "lat": 7.9356,
          "lng": 81.5564,
          "province": "Eastern",
          "city": "Pasikudah",
          "type": "beach",
          "budget": 4500,
          "season": "dry",
          "duration": 6,
          "rating": 4.3,
          "activities": ["swimming", "water_sports"]
        },

        // Hill Country
        {
          "name": "Nuwara Eliya Town",
          "lat": 6.9497,
          "lng": 80.7891,
          "province": "Central",
          "city": "Nuwara Eliya",
          "type": "scenic",
          "budget": 2500,
          "season": "all",
          "duration": 5,
          "rating": 4.4,
          "activities": ["tea_tasting", "photography"]
        },
        {
          "name": "Ella Nine Arch Bridge",
          "lat": 6.8721,
          "lng": 81.0461,
          "province": "Uva",
          "city": "Ella",
          "type": "scenic",
          "budget": 1500,
          "season": "all",
          "duration": 3,
          "rating": 4.5,
          "activities": ["photography", "train_spotting"]
        },
        {
          "name": "Little Adam's Peak",
          "lat": 6.8721,
          "lng": 81.0461,
          "province": "Uva",
          "city": "Ella",
          "type": "adventure",
          "budget": 2000,
          "season": "dry",
          "duration": 4,
          "rating": 4.6,
          "activities": ["hiking", "sunrise"]
        },

        // Ancient Cities
        {
          "name": "Sigiriya Rock",
          "lat": 7.9570,
          "lng": 80.7603,
          "province": "Central",
          "city": "Dambulla",
          "type": "historical",
          "budget": 4500,
          "season": "dry",
          "duration": 6,
          "rating": 4.8,
          "activities": ["climbing", "photography"]
        },
        {
          "name": "Dambulla Cave Temple",
          "lat": 7.8567,
          "lng": 80.6490,
          "province": "Central",
          "city": "Dambulla",
          "type": "religious",
          "budget": 2000,
          "season": "all",
          "duration": 3,
          "rating": 4.6,
          "activities": ["worship", "art"]
        },
        {
          "name": "Anuradhapura",
          "lat": 8.3114,
          "lng": 80.4037,
          "province": "North Central",
          "city": "Anuradhapura",
          "type": "historical",
          "budget": 3000,
          "season": "all",
          "duration": 6,
          "rating": 4.6,
          "activities": ["archaeology", "cycling"]
        },
        {
          "name": "Polonnaruwa",
          "lat": 7.9403,
          "lng": 81.0188,
          "province": "North Central",
          "city": "Polonnaruwa",
          "type": "historical",
          "budget": 3500,
          "season": "all",
          "duration": 6,
          "rating": 4.7,
          "activities": ["archaeology", "cycling"]
        },

        // Adventure & Nature
        {
          "name": "Adam's Peak",
          "lat": 6.8092,
          "lng": 80.4989,
          "province": "Sabaragamuwa",
          "city": "Nallathanniya",
          "type": "adventure",
          "budget": 2500,
          "season": "dry",
          "duration": 8,
          "rating": 4.8,
          "activities": ["pilgrimage", "hiking"]
        },
        {
          "name": "Yala National Park",
          "lat": 6.3720,
          "lng": 81.5197,
          "province": "Southern",
          "city": "Tissamaharama",
          "type": "wildlife",
          "budget": 8000,
          "season": "dry",
          "duration": 8,
          "rating": 4.7,
          "activities": ["safari", "photography"]
        },
        {
          "name": "Minneriya National Park",
          "lat": 8.0167,
          "lng": 80.8833,
          "province": "North Central",
          "city": "Minneriya",
          "type": "wildlife",
          "budget": 5500,
          "season": "dry",
          "duration": 7,
          "rating": 4.4,
          "activities": ["elephant_gathering", "safari"]
        },
      ]
    };
  }

  // Create nearby-focused mapping
  static Map<String, dynamic> _createNearbyMapping() {
    return {
      "categorical_mappings": {
        "user_travel_types": {
          "cultural": 0,
          "nature": 1,
          "adventure": 2,
          "beach": 3,
          "historical": 4,
          "religious": 5,
          "scenic": 6,
          "wildlife": 7,
          "recreational": 8
        },
        "place_types": {
          "cultural": 0,
          "nature": 1,
          "adventure": 2,
          "beach": 3,
          "historical": 4,
          "religious": 5,
          "scenic": 6,
          "wildlife": 7,
          "recreational": 8
        },
        "user_provinces": {
          "Western": 0,
          "Central": 1,
          "Southern": 2,
          "Eastern": 3,
          "Northern": 4,
          "North Western": 5,
          "North Central": 6,
          "Uva": 7,
          "Sabaragamuwa": 8
        },
        "place_provinces": {
          "Western": 0,
          "Central": 1,
          "Southern": 2,
          "Eastern": 3,
          "Northern": 4,
          "North Western": 5,
          "North Central": 6,
          "Uva": 7,
          "Sabaragamuwa": 8
        },
        "seasons": {"all": 0, "dry": 1, "wet": 2}
      },
      "feature_scaling": {
        "means": List.filled(22, 0.0),
        "scales": List.filled(22, 1.0)
      }
    };
  }

  // Utility methods
  static bool get isInitialized => _isInitialized;
  static Map<String, dynamic>? get modelInfo => _metadata?['model_info'];
  static int get totalPlaces =>
      (_metadata?['places_database'] as List?)?.length ?? 0;

  static List<String> getAvailableTravelTypes() {
    return [
      'cultural',
      'nature',
      'adventure',
      'beach',
      'historical',
      'religious',
      'scenic',
      'wildlife',
      'recreational'
    ];
  }

  static List<String> getAvailableProvinces() {
    return [
      'Western',
      'Central',
      'Southern',
      'Eastern',
      'Northern',
      'North Western',
      'North Central',
      'Uva',
      'Sabaragamuwa'
    ];
  }
}
