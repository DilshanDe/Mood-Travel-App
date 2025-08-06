import 'dart:convert';
import 'dart:math' as math;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/services.dart';

class AutoTrainingMLService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static final FirebaseFunctions _functions = FirebaseFunctions.instance;
  static List<Map<String, dynamic>> _trainingBuffer = [];
  static const int RETRAIN_THRESHOLD = 1;

  // Store places data locally in this service
  static Map<String, dynamic>? _placesData;

  // Initialize and load places data
  static Future<void> initialize() async {
    try {
      await _loadPlacesData();
      print(' AutoTrainingMLService initialized successfully');
    } catch (e) {
      print('Error initializing AutoTrainingMLService: $e');
    }
  }

  // Load places data from assets
  static Future<void> _loadPlacesData() async {
    try {
      final String jsonString =
          await rootBundle.loadString('assets/models/places_data.json');
      _placesData = json.decode(jsonString);
      print(' Places data loaded: ${_placesData?.keys.length} categories');
    } catch (e) {
      print(' Error loading places data: $e');
      _placesData = _getDefaultPlacesData();
    }
  }

  // Check if place exists in dataset
  static bool checkIfPlaceExists(String placeName) {
    if (_placesData == null) {
      print(' Places data not loaded, initializing...');
      // Try to initialize if not loaded
      initialize();
      return false;
    }

    for (var categoryPlaces in _placesData!.values) {
      if (categoryPlaces is List) {
        for (var place in categoryPlaces) {
          if (place['name'].toString().toLowerCase() ==
              placeName.toLowerCase()) {
            print(' Place exists in dataset: $placeName');
            return true;
          }
        }
      }
    }
    print(' New place detected: $placeName');
    return false;
  }

  // Add new place for training
  static Future<void> addNewPlaceForTraining({
    required String placeName,
    required String cityName,
    required String caption,
    required double budget,
    required String userId,
    required double userLat,
    required double userLng,
    String? imageUrl,
  }) async {
    try {
      print(' Adding new place for training: $placeName');

      // Ensure places data is loaded
      if (_placesData == null) {
        await _loadPlacesData();
      }

      // Check if place exists
      bool placeExists = checkIfPlaceExists(placeName);

      if (!placeExists) {
        // Infer place type using AI techniques
        String inferredType = _inferPlaceType(placeName, cityName, caption);
        List<String> extractedActivities = _extractActivities(caption);

        // Create training data
        Map<String, dynamic> newPlaceData = {
          'name': placeName,
          'city': cityName,
          'type': inferredType,
          'cost': budget,
          'duration': _estimateDuration(caption, budget),
          'activities': extractedActivities,
          'image': imageUrl ?? _getDefaultImageForType(inferredType),
          'addedBy': userId,
          'addedAt': DateTime.now().millisecondsSinceEpoch,
          'userLocation': {
            'latitude': userLat,
            'longitude': userLng,
          },
          'caption': caption,
          'verified': false,
        };

        // Add to buffer
        _trainingBuffer.add(newPlaceData);

        // Save to Firestore
        await _saveTrainingDataToFirestore(newPlaceData);

        // Add to current places data for immediate use
        _addToCurrentPlacesData(newPlaceData);

        print(
            'New place added to training buffer. Buffer size: ${_trainingBuffer.length}');

        // Check if retraining needed
        if (_trainingBuffer.length >= RETRAIN_THRESHOLD) {
          await _triggerModelRetraining();
        }
      } else {
        print(' Place already exists in dataset: $placeName');
      }
    } catch (e) {
      print(' Error adding place for training: $e');
    }
  }

  // Add new place to current places data for immediate use
  static void _addToCurrentPlacesData(Map<String, dynamic> placeData) {
    if (_placesData != null) {
      String type = placeData['type'];
      _placesData![type] ??= [];
      _placesData![type]!.add(placeData);
      print(' Added ${placeData['name']} to $type category for immediate use');
    }
  }

  static String _inferPlaceType(
      String placeName, String cityName, String caption) {
    Map<String, List<String>> typeKeywords = {
      'beach': [
        // Basic beach terms
        'beach', 'sand', 'ocean', 'sea', 'wave', 'surf', 'swimming', 'bay',
        'coast',
        // Extended beach terms
        'shore', 'tide', 'coral', 'diving', 'snorkeling', 'sunset', 'palm',
        'lagoon', 'marina', 'fishing', 'boat', 'yacht', 'island', 'reef',
        'sunbathing', 'volleyball', 'lifeguard', 'boardwalk', 'pier',
        'seashell', 'driftwood', 'saltwater', 'horizon', 'lighthouse',
        'harbor', 'port', 'dock', 'jetty', 'cove', 'inlet', 'estuary',
        // Sri Lankan beach specific
        'galle face', 'negombo', 'hikkaduwa', 'mirissa', 'unawatuna',
        'bentota', 'tangalle', 'arugam bay', 'pasikuda', 'nilaveli'
      ],
      'cultural': [
        // Basic cultural terms
        'temple', 'museum', 'cultural', 'heritage', 'traditional', 'art',
        'gallery', 'festival',
        // Extended cultural terms
        'dagoba', 'stupa', 'shrine', 'monastery', 'pagoda', 'statue',
        'ceremony',
        'ritual', 'dance', 'music', 'craft', 'pottery', 'weaving', 'folklore',
        'buddhist', 'hindu', 'religious', 'sacred', 'holy', 'spiritual',
        'meditation', 'prayer', 'blessing', 'worship', 'pilgrimage',
        'relic', 'artifact', 'inscription', 'mural', 'fresco', 'sculpture',
        'architecture', 'design', 'pattern', 'symbol', 'tradition',
        // Sri Lankan cultural specific
        'poya', 'wesak', 'perahera', 'pirith', 'bo tree', 'bodhi',
        'viharaya', 'kovila', 'devala', 'pansala', 'rajamaha viharaya',
        'tooth relic', 'dalada maligawa', 'sinhala', 'tamil', 'buddhism'
      ],
      'historical': [
        // Basic historical terms
        'ancient', 'old', 'historical', 'heritage', 'ruins', 'colonial',
        'kingdom', 'palace',
        // Extended historical terms
        'archaeological', 'excavation', 'dynasty', 'empire', 'fortress',
        'citadel',
        'monument', 'memorial', 'legacy', 'civilization', 'era', 'period',
        'century', 'millennium', 'chronological', 'timeline', 'historic',
        'preservation', 'restoration', 'conservation', 'vintage', 'antique',
        'medieval', 'renaissance', 'baroque', 'neoclassical', 'victorian',
        // Sri Lankan historical specific
        'anuradhapura', 'polonnaruwa', 'sigiriya', 'dambulla', 'mihintale',
        'yapahuwa', 'ritigala', 'jetavanaramaya', 'abhayagiri', 'thuparamaya',
        'gal vihara', 'lankatilaka', 'tivanka', 'rankoth vehera', 'kiri vehera',
        'dutch fort', 'portuguese', 'british', 'kandyan', 'sinhalese kingdom'
      ],
      'nature': [
        // Basic nature terms
        'nature', 'forest', 'tree', 'green', 'park', 'garden', 'waterfall',
        'river', 'mountain',
        // Extended nature terms
        'jungle', 'rainforest', 'lake', 'pond', 'stream', 'valley', 'hill',
        'flower', 'plant', 'botanical', 'eco', 'environment', 'natural',
        'reservoir', 'spring', 'cave', 'rock', 'cliff', 'gorge', 'canyon',
        'meadow', 'grassland', 'wetland', 'marsh', 'swamp', 'mangrove',
        'biodiversity', 'ecosystem', 'flora', 'fauna', 'endemic', 'species',
        'conservation', 'sanctuary', 'preserve', 'wilderness', 'pristine',
        'scenic', 'landscape', 'vista', 'panorama', 'viewpoint', 'overlook',
        // Sri Lankan nature specific
        'horton plains', 'worlds end', 'knuckles', 'sinharaja',
        'peak wilderness',
        'ella rock', 'little adams peak', 'bambarakanda', 'diyaluma',
        'sekumpura',
        'udawatta kele', 'royal botanical gardens', 'hakgala', 'victoria park'
      ],
      'adventure': [
        // Basic adventure terms
        'adventure', 'hiking', 'climbing', 'trek', 'explore', 'challenge',
        'extreme',
        // Extended adventure terms
        'zip line', 'rappelling', 'rock climbing', 'white water', 'rafting',
        'bungee', 'paragliding', 'camping', 'backpacking', 'trail',
        'expedition',
        'adrenaline', 'thrill', 'outdoor', 'wilderness', 'survival',
        'mountaineering', 'abseiling', 'canyoning', 'spelunking', 'caving',
        'kayaking', 'canoeing', 'windsurfing', 'kitesurfing', 'skydiving',
        'base jumping', 'free climbing', 'via ferrata', 'orienteering',
        'bushcraft', 'wild camping', 'trekking', 'scrambling', 'bouldering',
        // Sri Lankan adventure specific
        'adams peak', 'pidurangala', 'ambuluwawa', 'bible rock',
        'mini worlds end',
        'ravana falls', 'whitewater rafting kelani', 'hot air balloon dambulla',
        'zip lining flying ravana', 'ella adventure park'
      ],
      'food_tourism': [
        // Basic food terms
        'food', 'restaurant', 'taste', 'delicious', 'cuisine', 'cooking',
        'spice',
        // Extended food terms
        'curry', 'rice', 'coconut', 'tea', 'street food', 'market', 'vendor',
        'local dish', 'traditional food', 'recipe', 'chef', 'dining', 'cafe',
        'bakery', 'seafood', 'vegetarian', 'buffet', 'lunch', 'dinner',
        'breakfast', 'snack', 'dessert', 'beverage', 'drink', 'juice',
        'fresh', 'organic', 'local', 'homemade', 'authentic', 'fusion',
        'gourmet', 'fine dining', 'casual dining', 'food court', 'food stall',
        // Sri Lankan food specific
        'kottu', 'hoppers', 'string hoppers', 'pol roti', 'wade', 'isso wade',
        'lamprais', 'biryani', 'pittu', 'kiribath', 'curd', 'treacle',
        'devilled', 'ambulthiyal', 'polos curry', 'gotukola sambol',
        'seeni sambol',
        'parippu', 'dhal curry', 'fish curry', 'chicken curry', 'beef curry',
        'ceylon tea', 'king coconut', 'thambili', 'faluda', 'wattalapam'
      ],
      'urban': [
        // Basic urban terms
        'city', 'urban', 'shopping', 'modern', 'downtown', 'street',
        'nightlife',
        // Extended urban terms
        'mall', 'plaza', 'complex', 'tower', 'skyscraper', 'building',
        'architecture', 'infrastructure', 'metro', 'subway', 'bus', 'traffic',
        'commercial', 'business', 'office', 'corporate', 'financial',
        'entertainment', 'cinema', 'theater', 'club', 'bar', 'pub',
        'boutique', 'store', 'market', 'bazaar', 'vendor', 'street vendor',
        'pedestrian', 'walkway', 'promenade', 'boulevard', 'avenue',
        'district', 'neighborhood', 'suburb', 'residential', 'industrial',
        // Sri Lankan urban specific
        'colombo city', 'fort', 'pettah', 'bambalapitiya', 'wellawatte',
        'mount lavinia', 'dehiwala', 'independence square', 'galle face green',
        'dutch hospital', 'red mosque', 'old parliament', 'town hall',
        'liberty plaza', 'odel', 'majestic city', 'crescat boulevard'
      ],
      'mountain': [
        // Basic mountain terms
        'mountain', 'hill', 'peak', 'view', 'altitude', 'climb', 'elevation',
        // Extended mountain terms
        'summit', 'ridge', 'slope', 'gradient', 'incline', 'ascent', 'descent',
        'panoramic', 'vista', 'overlook', 'viewpoint', 'scenic', 'landscape',
        'misty', 'cloud', 'fog', 'cool', 'fresh air', 'oxygen', 'breathing',
        'sunrise', 'sunset', 'dawn', 'dusk', 'golden hour', 'silhouette',
        'rocky', 'rugged', 'steep', 'challenging', 'demanding', 'strenuous',
        'trail', 'path', 'route', 'way', 'steps', 'stairs', 'pilgrimage',
        // Sri Lankan mountain specific
        'ella gap', 'gap view', 'tea country', 'hill country', 'upcountry',
        'nuwara eliya', 'badulla', 'bandarawela', 'haputale', 'diyatalawa',
        'ohiya', 'idalgashinna', 'pattipola', 'ambewela', 'horton plains'
      ],
      'wildlife': [
        // Basic wildlife terms
        'wildlife', 'animal', 'safari', 'elephant', 'leopard', 'bird', 'zoo',
        'sanctuary',
        // Extended wildlife terms
        'national park', 'game drive', 'spotting', 'tracking', 'observation',
        'binoculars', 'photography', 'birdwatching', 'ornithology', 'mammal',
        'reptile', 'amphibian', 'insect', 'butterfly', 'endemic', 'species',
        'habitat', 'ecosystem', 'conservation', 'protection', 'preservation',
        'ranger', 'guide', 'naturalist', 'jeep', 'tracker', 'camouflage',
        'migration', 'breeding', 'nesting', 'feeding', 'grazing', 'hunting',
        // Sri Lankan wildlife specific
        'yala', 'udawalawe', 'wilpattu', 'minneriya', 'kaudulla', 'wasgamuwa',
        'bundala', 'kumana', 'gal oya', 'lunugamvehera', 'maduru oya',
        'sri lankan elephant', 'sloth bear', 'water buffalo', 'spotted deer',
        'sambur', 'wild boar', 'purple faced langur', 'toque macaque',
        'fishing cat', 'rusty spotted cat', 'pangolin', 'civet'
      ],
      'relaxation': [
        // Basic relaxation terms
        'relax', 'peaceful', 'calm', 'spa', 'quiet', 'meditation', 'rest',
        // Extended relaxation terms
        'tranquil', 'serene', 'soothing', 'therapeutic', 'healing', 'wellness',
        'rejuvenation', 'restoration', 'refresh', 'recharge', 'unwind',
        'massage', 'ayurveda', 'yoga', 'mindfulness', 'zen', 'balance',
        'harmony', 'inner peace', 'stress relief', 'detox', 'cleansing',
        'retreat', 'getaway', 'escape', 'sanctuary', 'haven', 'oasis',
        'luxury', 'comfort', 'pampering', 'indulgence', 'leisure', 'vacation',
        'holiday', 'break', 'timeout', 'solitude', 'privacy', 'seclusion',
        // Sri Lankan relaxation specific
        'ayurveda spa', 'herbal bath', 'oil massage', 'panchakarma',
        'meditation retreat', 'yoga center', 'wellness resort', 'health resort',
        'natural springs', 'hot springs', 'thermal baths', 'mineral water'
      ]
    };

    String combinedText = '$placeName $cityName $caption'.toLowerCase();
    Map<String, int> typeScores = {};

    // Count keyword matches
    for (var entry in typeKeywords.entries) {
      int score = 0;
      for (var keyword in entry.value) {
        if (combinedText.contains(keyword)) {
          score++;
        }
      }
      typeScores[entry.key] = score;
    }

    // Return type with highest score
    String inferredType = typeScores.entries
            .where((entry) => entry.value > 0)
            .fold<MapEntry<String, int>?>(
                null,
                (prev, current) =>
                    prev == null || current.value > prev.value ? current : prev)
            ?.key ??
        'cultural';

    print(' Inferred type for $placeName: $inferredType');
    return inferredType;
  }

  // Extract activities from caption
  static List<String> _extractActivities(String caption) {
    List<String> allActivities = [
      'hiking',
      'swimming',
      'photography',
      'sightseeing',
      'eating',
      'shopping',
      'relaxing',
      'exploring',
      'climbing',
      'walking',
      'boating',
      'fishing',
      'camping',
      'cycling',
      'meditation',
      'surfing',
      'diving',
      'snorkeling',
      'bird_watching',
      'safari'
    ];

    String lowerCaption = caption.toLowerCase();
    List<String> foundActivities = [];

    for (String activity in allActivities) {
      if (lowerCaption.contains(activity.replaceAll('_', ' ')) ||
          lowerCaption.contains(activity)) {
        foundActivities.add(activity);
      }
    }

    // Default activities if none found
    if (foundActivities.isEmpty) {
      foundActivities.addAll(['sightseeing', 'photography', 'exploring']);
    }

    return foundActivities.take(5).toList();
  }

  // Estimate duration based on caption and budget
  static int _estimateDuration(String caption, double budget) {
    String lowerCaption = caption.toLowerCase();

    if (lowerCaption.contains('day trip') ||
        lowerCaption.contains('half day')) {
      return 1;
    } else if (lowerCaption.contains('weekend') || budget > 500) {
      return 2;
    } else if (lowerCaption.contains('week') || budget > 1000) {
      return 7;
    } else if (budget > 300) {
      return 3;
    }

    return 1;
  }

  // Get default image for place type
  static String _getDefaultImageForType(String type) {
    Map<String, String> defaultImages = {
      'beach':
          'https://images.unsplash.com/photo-1506905925346-21bda4d32df4?w=800&h=600&fit=crop&q=80',
      'cultural':
          'https://images.unsplash.com/photo-1545126490-12bd9ced9dff?w=800&h=600&fit=crop&q=80',
      'historical':
          'https://images.unsplash.com/photo-1539650116574-75c0c6d13dc9?w=800&h=600&fit=crop&q=80',
      'nature':
          'https://images.unsplash.com/photo-1441974231531-c6227db76b6e?w=800&h=600&fit=crop&q=80',
      'adventure':
          'https://images.unsplash.com/photo-1464822759844-d150baec4363?w=800&h=600&fit=crop&q=80',
      'food_tourism':
          'https://images.unsplash.com/photo-1504674900247-0877df9cc836?w=800&h=600&fit=crop&q=80',
      'urban':
          'https://images.unsplash.com/photo-1449824913935-59a10b8d2000?w=800&h=600&fit=crop&q=80',
      'mountain':
          'https://images.unsplash.com/photo-1506905925346-21bda4d32df4?w=800&h=600&fit=crop&q=80',
      'wildlife':
          'https://images.unsplash.com/photo-1564349683136-77e08dba1ef7?w=800&h=600&fit=crop&q=80',
      'relaxation':
          'https://images.unsplash.com/photo-1571019613454-1cb2f99b2d8b?w=800&h=600&fit=crop&q=80',
    };

    return defaultImages[type] ?? defaultImages['cultural']!;
  }

  // Save training data to Firestore
  static Future<void> _saveTrainingDataToFirestore(
      Map<String, dynamic> placeData) async {
    try {
      await _firestore.collection('pending_training_places').add(placeData);
      print(' Training data saved to Firestore');
    } catch (e) {
      print(' Error saving training data: $e');
    }
  }

  // Trigger model retraining
  static Future<void> _triggerModelRetraining() async {
    try {
      print(' Triggering model retraining...');

      final callable = _functions.httpsCallable('manualRetrain');
      await callable.call();

      _trainingBuffer.clear();
      print(' Model retraining triggered successfully');
    } catch (e) {
      print(' Error triggering retraining: $e');
    }
  }

  // Get training status
  static Map<String, dynamic> getTrainingStatus() {
    return {
      'bufferSize': _trainingBuffer.length,
      'retrainThreshold': RETRAIN_THRESHOLD,
      'needsRetraining': _trainingBuffer.length >= RETRAIN_THRESHOLD,
      'placesDataLoaded': _placesData != null,
      'totalCategories': _placesData?.keys.length ?? 0,
    };
  }

  // Get default places data (fallback)
  static Map<String, dynamic> _getDefaultPlacesData() {
    return {
      'adventure': [
        {
          'name': 'Sigiriya',
          'city': 'Dambulla',
          'cost': 50,
          'duration': 1,
          'activities': ['hiking', 'photography', 'history']
        },
        {
          'name': 'Adams Peak',
          'city': 'Hatton',
          'cost': 30,
          'duration': 1,
          'activities': ['pilgrimage', 'hiking', 'sunrise']
        },
      ],
      'cultural': [
        {
          'name': 'Kandy',
          'city': 'Kandy',
          'cost': 40,
          'duration': 2,
          'activities': ['temple', 'cultural_show', 'lake']
        },
        {
          'name': 'Anuradhapura',
          'city': 'Anuradhapura',
          'cost': 35,
          'duration': 2,
          'activities': ['archaeology', 'temples', 'history']
        },
      ],
      'relaxation': [
        {
          'name': 'Bentota',
          'city': 'Bentota',
          'cost': 80,
          'duration': 3,
          'activities': ['beach', 'spa', 'water_sports']
        },
        {
          'name': 'Unawatuna',
          'city': 'Galle',
          'cost': 60,
          'duration': 2,
          'activities': ['beach', 'swimming', 'snorkeling']
        },
      ],
      'nature': [
        {
          'name': 'Horton Plains',
          'city': 'Nuwara Eliya',
          'cost': 40,
          'duration': 1,
          'activities': ['hiking', 'wildlife', 'worlds_end']
        },
        {
          'name': 'Yala National Park',
          'city': 'Tissamaharama',
          'cost': 70,
          'duration': 2,
          'activities': ['safari', 'wildlife', 'leopards']
        },
      ],
      'urban': [
        {
          'name': 'Colombo City',
          'city': 'Colombo',
          'cost': 60,
          'duration': 2,
          'activities': ['shopping', 'museums', 'nightlife']
        },
        {
          'name': 'Galle Fort',
          'city': 'Galle',
          'cost': 40,
          'duration': 1,
          'activities': ['walking', 'colonial_architecture', 'galleries']
        },
      ],
    };
  }

  // Get current places data (for EnhancedMLService integration)
  static Map<String, dynamic>? get placesData => _placesData;

  // Clear cache and reload data
  static Future<void> refreshPlacesData() async {
    _placesData = null;
    await _loadPlacesData();
  }

  // Get places count by category
  static Map<String, int> getPlacesCountByCategory() {
    if (_placesData == null) return {};

    Map<String, int> counts = {};
    for (var entry in _placesData!.entries) {
      if (entry.value is List) {
        counts[entry.key] = (entry.value as List).length;
      }
    }
    return counts;
  }
}
