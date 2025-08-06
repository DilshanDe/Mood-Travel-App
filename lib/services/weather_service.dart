import 'dart:convert';
import 'dart:math' as math;
import 'package:http/http.dart' as http;
import 'package:geolocator/geolocator.dart';
import 'package:flutter/services.dart';
import 'package:flutter/material.dart';

class WeatherService {
  static const String _apiKey = '556564c86c03864bb2d59e6844cb5837';
  static const String _baseUrl = 'https://api.openweathermap.org/data/2.5';

  // Sri Lankan places
  static Map<String, dynamic>? _placesDatabase;
  static Map<String, Map<String, double>>? _weatherLocations;

  /// Initialize the weather service with places database
  static Future<void> initialize() async {
    await _loadPlacesDatabase();
    _buildWeatherLocations();
  }

  /// Load places
  static Future<void> _loadPlacesDatabase() async {
    try {
      String placesJson =
          await rootBundle.loadString('assets/models/places_data.json');
      _placesDatabase = Map<String, dynamic>.from(jsonDecode(placesJson));
    } catch (e) {
      print('Error loading places database: $e');
      _placesDatabase = {};
    }
  }

  /// Build weather locations from places
  static void _buildWeatherLocations() {
    _weatherLocations = {};

    // Add major cities with precise coordinates
    Map<String, Map<String, double>> majorCities = {
      'colombo': {'lat': 6.9271, 'lon': 79.8612},
      'kandy': {'lat': 7.2906, 'lon': 80.6337},
      'galle': {'lat': 6.0535, 'lon': 80.2210},
      'jaffna': {'lat': 9.6615, 'lon': 80.0255},
      'negombo': {'lat': 7.2083, 'lon': 79.8358},
      'anuradhapura': {'lat': 8.3114, 'lon': 80.4037},
      'polonnaruwa': {'lat': 7.9403, 'lon': 81.0188},
      'batticaloa': {'lat': 7.7102, 'lon': 81.6924},
      'trincomalee': {'lat': 8.5874, 'lon': 81.2152},
      'matara': {'lat': 5.9485, 'lon': 80.5353},
      'ella': {'lat': 6.8721, 'lon': 81.0461},
      'nuwara eliya': {'lat': 6.9497, 'lon': 80.7891},
      'sigiriya': {'lat': 7.9568, 'lon': 80.7592},
      'mirissa': {'lat': 5.9467, 'lon': 80.4590},
      'unawatuna': {'lat': 6.0108, 'lon': 80.2506},
      'bentota': {'lat': 6.4263, 'lon': 80.0031},
      'hikkaduwa': {'lat': 6.1391, 'lon': 80.0990},
      'arugam bay': {'lat': 6.8403, 'lon': 81.8344},
      'dambulla': {'lat': 7.8731, 'lon': 80.6513},
      'kitulgala': {'lat': 6.9856, 'lon': 80.4172},
      'haputale': {'lat': 6.7676, 'lon': 80.9500},
      'badulla': {'lat': 6.9934, 'lon': 81.0550},
      'ratnapura': {'lat': 6.6828, 'lon': 80.3992},
      'kurunegala': {'lat': 7.4818, 'lon': 80.3609},
      'hambantota': {'lat': 6.1241, 'lon': 81.1185},
      'puttalam': {'lat': 8.0362, 'lon': 79.8283},
      'kalpitiya': {'lat': 8.2420, 'lon': 79.7679},
      'mannar': {'lat': 8.9810, 'lon': 79.9049},
      'vavuniya': {'lat': 8.7514, 'lon': 80.4971},
      'kilinochchi': {'lat': 9.3964, 'lon': 80.4103},
      'mullaitivu': {'lat': 9.2670, 'lon': 80.8142},
      'ampara': {'lat': 7.3022, 'lon': 81.6747},
      'monaragala': {'lat': 6.8727, 'lon': 81.3510},
      'embilipitiya': {'lat': 6.3432, 'lon': 80.8492},
      'balangoda': {'lat': 6.6519, 'lon': 80.6982},
      'kegalle': {'lat': 7.2513, 'lon': 80.3464},
      'gampaha': {'lat': 7.0873, 'lon': 79.9990},
      'kalutara': {'lat': 6.5854, 'lon': 79.9607},
      'chilaw': {'lat': 7.5759, 'lon': 79.7956},
      'pasikudah': {'lat': 7.9022, 'lon': 81.5562},
      'nilaveli': {'lat': 8.7089, 'lon': 81.1900},
      'uppuveli': {'lat': 8.5874, 'lon': 81.2152},
      'tangalle': {'lat': 6.0235, 'lon': 80.7928},
      'weligama': {'lat': 5.9749, 'lon': 80.4293},
      'koggala': {'lat': 5.9942, 'lon': 80.3231},
      'ahungalla': {'lat': 6.3667, 'lon': 80.0167},
      'beruwala': {'lat': 6.4790, 'lon': 79.9823},
      'wadduwa': {'lat': 6.6667, 'lon': 79.9333},
      'mount lavinia': {'lat': 6.8344, 'lon': 79.8627},
      'panadura': {'lat': 6.7133, 'lon': 79.9027},
      'moratuwa': {'lat': 6.7730, 'lon': 79.8816},
      'tissamaharama': {'lat': 6.2722, 'lon': 81.2925},
      'kataragama': {'lat': 6.4133, 'lon': 81.3344},
      'wellawaya': {'lat': 6.7377, 'lon': 81.1082},
      'bandarawela': {'lat': 6.8326, 'lon': 80.9857},
      'diyatalawa': {'lat': 6.8000, 'lon': 80.9667},
      'welimada': {'lat': 6.9167, 'lon': 80.9000},
      'pussellawa': {'lat': 7.0167, 'lon': 80.7000},
      'maskeliya': {'lat': 6.8833, 'lon': 80.5167},
      'hatton': {'lat': 6.8911, 'lon': 80.5958},
      'talawakelle': {'lat': 6.9333, 'lon': 80.6500},
      'ramboda': {'lat': 7.0500, 'lon': 80.7167},
      'ohiya': {'lat': 6.8167, 'lon': 80.8333},
      'ambewela': {'lat': 6.9667, 'lon': 80.8000},
      'horton plains': {'lat': 6.8097, 'lon': 80.7933},
      'adams peak': {'lat': 6.8097, 'lon': 80.4992},
      'pidurangala': {'lat': 7.9667, 'lon': 80.7500},
      'mihintale': {'lat': 8.3503, 'lon': 80.5006},
      'yapahuwa': {'lat': 7.8167, 'lon': 80.2833},
      'ritigala': {'lat': 8.1667, 'lon': 80.5833},
      'medirigiriya': {'lat': 7.9667, 'lon': 80.9833},
      'dimbulagala': {'lat': 7.9500, 'lon': 81.0167},
      'aluvihara': {'lat': 7.4167, 'lon': 80.6167},
      'dowa': {'lat': 7.2667, 'lon': 80.6333},
      'mulkirigala': {'lat': 6.1167, 'lon': 80.7333},
      'buduruwagala': {'lat': 6.7833, 'lon': 81.0500},
      'isurumuniya': {'lat': 8.3333, 'lon': 80.3833},
      'kelaniya': {'lat': 6.9558, 'lon': 79.9219},
      'embekke': {'lat': 7.2833, 'lon': 80.6167},
      'gadaladeniya': {'lat': 7.2500, 'lon': 80.5833},
      'lankathilaka': {'lat': 7.2667, 'lon': 80.6000},
      'degaldoruwa': {'lat': 7.3167, 'lon': 80.6833},
      'pinnawala': {'lat': 7.2967, 'lon': 80.3886},
      'kithulgala': {'lat': 6.9856, 'lon': 80.4172},
      'belilena': {'lat': 6.9667, 'lon': 80.4833},
      'sinharaja': {'lat': 6.4167, 'lon': 80.4167},
      'udawalawe': {'lat': 6.4667, 'lon': 80.8833},
      'yala': {'lat': 6.3833, 'lon': 81.5167},
      'wilpattu': {'lat': 8.5167, 'lon': 80.0333},
      'minneriya': {'lat': 8.0167, 'lon': 80.8833},
      'kaudulla': {'lat': 8.1167, 'lon': 80.8500},
      'bundala': {'lat': 6.1833, 'lon': 81.2500},
      'kumana': {'lat': 6.6167, 'lon': 81.6833},
      'gal oya': {'lat': 7.2333, 'lon': 81.3833},
      'wasgamuwa': {'lat': 7.7333, 'lon': 80.9333},
      'maduru oya': {'lat': 7.4500, 'lon': 81.2167},
      'lunugamvehera': {'lat': 6.4667, 'lon': 81.1667},
      'lahugala': {'lat': 7.1167, 'lon': 81.7000},
      'somawathiya': {'lat': 8.0667, 'lon': 81.1333},
      'chundikkulam': {'lat': 9.3333, 'lon': 80.7000},
      'angammedilla': {'lat': 8.0333, 'lon': 80.7667},
      'horowpothana': {'lat': 8.4167, 'lon': 80.1667},
      'flood plains': {'lat': 6.5000, 'lon': 81.0000},
      'pigeon island': {'lat': 8.7069, 'lon': 81.2269},
      'bar reef': {'lat': 8.3500, 'lon': 79.8000},
      'muthurajawela': {'lat': 7.1167, 'lon': 79.8500},
      'bellanwila': {'lat': 6.8167, 'lon': 79.8833},
      'thalangama': {'lat': 6.9167, 'lon': 79.9333},
      'beddagana': {'lat': 6.9000, 'lon': 79.9500},
      'kalametiya': {'lat': 6.0833, 'lon': 80.9333},
      'mannar bird sanctuary': {'lat': 8.9810, 'lon': 79.9049},
      'vankalai': {'lat': 8.7833, 'lon': 79.9333},
      'giants tank': {'lat': 8.9167, 'lon': 80.5833},
      'senanayake samudraya': {'lat': 7.1667, 'lon': 81.5833},
      'victoria': {'lat': 7.2167, 'lon': 80.7833},
      'randenigala': {'lat': 7.2833, 'lon': 80.9333},
      'kotmale': {'lat': 7.0167, 'lon': 80.6000},
      'dambulla cave temple': {'lat': 7.8731, 'lon': 80.6513},
      'ella rock': {'lat': 6.8721, 'lon': 81.0461},
      'little adams peak': {'lat': 6.8721, 'lon': 81.0461},
      'nine arch bridge': {'lat': 6.8721, 'lon': 81.0461},
      'ambuluwawa tower': {'lat': 7.2906, 'lon': 80.6337},
      'knuckles mountain range': {'lat': 7.4167, 'lon': 80.7500},
      'riverston peak': {'lat': 7.5167, 'lon': 80.6833},
      'diyaluma falls': {'lat': 6.7167, 'lon': 81.0500},
      'bambarakanda falls': {'lat': 6.8167, 'lon': 80.8000},
      'bopath ella': {'lat': 6.7167, 'lon': 80.2833},
      'ramboda falls': {'lat': 7.0500, 'lon': 80.7167},
      'devon falls': {'lat': 6.9333, 'lon': 80.6500},
      'st clairs falls': {'lat': 6.9333, 'lon': 80.6500},
      'dunhinda falls': {'lat': 6.9934, 'lon': 81.0550},
      'ravana falls': {'lat': 6.8721, 'lon': 81.0461},
      'sekumpura falls': {'lat': 6.8167, 'lon': 80.8000},
      'lovers leap falls': {'lat': 6.9333, 'lon': 80.6500},
      'peradeniya botanical garden': {'lat': 7.2653, 'lon': 80.5955},
      'hakgala botanical garden': {'lat': 6.9167, 'lon': 80.8000},
      'gampaha botanical garden': {'lat': 7.0873, 'lon': 79.9990},
      'brief garden': {'lat': 6.4263, 'lon': 80.0031},
      'lunuganga garden': {'lat': 6.4263, 'lon': 80.0031},
      'henerathgoda botanic garden': {'lat': 7.0873, 'lon': 79.9990},
      'pinnawala elephant orphanage': {'lat': 7.2967, 'lon': 80.3886},
      'millennium elephant foundation': {'lat': 7.2967, 'lon': 80.3886},
      'elephant transit home': {'lat': 6.4667, 'lon': 80.8833},
      'turtle hatchery kosgoda': {'lat': 6.4263, 'lon': 80.0031},
      'turtle hatchery bentota': {'lat': 6.4263, 'lon': 80.0031},
      'whale watching mirissa': {'lat': 5.9467, 'lon': 80.4590},
      'dolphin watching kalpitiya': {'lat': 8.2420, 'lon': 79.7679},
      'colombo city': {'lat': 6.9271, 'lon': 79.8612},
      'galle fort': {'lat': 6.0535, 'lon': 80.2210},
      'jaffna city': {'lat': 9.6615, 'lon': 80.0255},
      'coconut tree hill': {'lat': 5.9467, 'lon': 80.4590},
      'jungle beach': {'lat': 6.0108, 'lon': 80.2506},
      'dalawella beach': {'lat': 6.0108, 'lon': 80.2506},
      'hiriketiya beach': {'lat': 5.9467, 'lon': 80.4590},
      'rekawa beach': {'lat': 6.0235, 'lon': 80.7928},
      'kalkudah': {'lat': 7.9022, 'lon': 81.5562},
      'polhena beach': {'lat': 5.9485, 'lon': 80.5353},
      'colombo national museum': {'lat': 6.9271, 'lon': 79.8612},
      'dutch museum colombo': {'lat': 6.9271, 'lon': 79.8612},
      'sri dalada maligawa': {'lat': 7.2906, 'lon': 80.6337},
      'temple of the tooth': {'lat': 7.2906, 'lon': 80.6337},
    };

    _weatherLocations!.addAll(majorCities);

    // places from your database and add coordinates
    if (_placesDatabase != null) {
      _placesDatabase!.forEach((category, places) {
        if (places is List<dynamic>) {
          // Handle direct list of places
          for (var place in places) {
            if (place is Map<String, dynamic> && place.containsKey('name')) {
              String placeName = place['name'].toString().toLowerCase();
              // Add to weather locations if not already present
              if (!_weatherLocations!.containsKey(placeName)) {
                _weatherLocations![placeName] =
                    _estimateCoordinates(placeName, category);
              }
            }
          }
        } else if (places is Map<String, dynamic> &&
            places.containsKey('places')) {
          // Handle if places are nested under a 'places' key
          List<dynamic> placesList = places['places'];
          for (var place in placesList) {
            if (place is Map<String, dynamic> && place.containsKey('name')) {
              String placeName = place['name'].toString().toLowerCase();
              // Add to weather locations if not already present
              if (!_weatherLocations!.containsKey(placeName)) {
                _weatherLocations![placeName] =
                    _estimateCoordinates(placeName, category);
              }
            }
          }
        }
      });
    }
  }

  ///  coordinates based on place name and category
  static Map<String, double> _estimateCoordinates(
      String placeName, String category) {
    // Category-based coordinate estimation
    Map<String, Map<String, double>> categoryDefaults = {
      'beach': {'lat': 6.0535, 'lon': 80.2210}, // Southern
      'mountain': {'lat': 6.9497, 'lon': 80.7891}, // Hill count
      'cultural': {'lat': 8.3114, 'lon': 80.4037}, // Cultural triangle
      'historical': {'lat': 7.9403, 'lon': 81.0188}, // Ancient cities
      'nature': {'lat': 6.4167, 'lon': 80.4167}, // Sinharaja region
      'wildlife': {'lat': 6.3833, 'lon': 81.5167}, // Yala region
      'adventure': {'lat': 7.9568, 'lon': 80.7592}, // Sigiriya region
      'urban': {'lat': 6.9271, 'lon': 79.8612}, // Colombo region
      'relaxation': {'lat': 6.4263, 'lon': 80.0031}, // Bentota region
      'food_tourism': {'lat': 6.9271, 'lon': 79.8612}, // Colombo region
    };

    // Try to match with known patterns
    if (categoryDefaults.containsKey(category)) {
      return categoryDefaults[category]!;
    }

    // Default to Colombo if no match found
    return {'lat': 6.9271, 'lon': 79.8612};
  }

  /// Get weather for any Sri Lankan place
  static Future<Map<String, dynamic>?> getSriLankanPlaceWeather(
      String placeName) async {
    await initialize();

    String searchKey = placeName.toLowerCase().trim();

    // Direct match
    if (_weatherLocations!.containsKey(searchKey)) {
      Map<String, double> coords = _weatherLocations![searchKey]!;
      return await getCurrentWeather(
        latitude: coords['lat']!,
        longitude: coords['lon']!,
      );
    }

    // Fuzzy matching - find similar place names
    String? bestMatch = _findBestMatch(searchKey);
    if (bestMatch != null) {
      Map<String, double> coords = _weatherLocations![bestMatch]!;
      return await getCurrentWeather(
        latitude: coords['lat']!,
        longitude: coords['lon']!,
      );
    }

    // Try OpenWeatherMap city search as fallback
    try {
      return await getCurrentWeatherByCity(placeName);
    } catch (e) {
      print('City search failed: $e');
    }

    // Ultimate fallback to Colombo
    return await getCurrentWeather(
      latitude: 6.9271,
      longitude: 79.8612,
    );
  }

  /// Find best matching place name using fuzzy matching
  static String? _findBestMatch(String searchKey) {
    String? bestMatch;
    int bestScore = 0;

    for (String placeName in _weatherLocations!.keys) {
      int score = _calculateSimilarity(searchKey, placeName);
      if (score > bestScore && score > 60) {
        // Minimum 60% similarity
        bestScore = score;
        bestMatch = placeName;
      }
    }

    return bestMatch;
  }

  /// Calculate similarity between two strings
  static int _calculateSimilarity(String a, String b) {
    // Simple similarity calculation
    if (a == b) return 100;
    if (a.contains(b) || b.contains(a)) return 80;

    // Check for partial matches
    List<String> aWords = a.split(' ');
    List<String> bWords = b.split(' ');

    int matches = 0;
    int totalWords = aWords.length + bWords.length;

    for (String aWord in aWords) {
      for (String bWord in bWords) {
        if (aWord == bWord || aWord.contains(bWord) || bWord.contains(aWord)) {
          matches++;
        }
      }
    }

    return ((matches * 2) / totalWords * 100).round();
  }

  /// Get current weather by coordinates
  static Future<Map<String, dynamic>?> getCurrentWeather({
    required double latitude,
    required double longitude,
  }) async {
    try {
      final response = await http.get(
        Uri.parse(
            '$_baseUrl/weather?lat=$latitude&lon=$longitude&appid=$_apiKey&units=metric'),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return _formatWeatherData(data);
      }
    } catch (e) {
      print('Error fetching weather: $e');
    }
    return null;
  }

  /// Get current weather by city name
  static Future<Map<String, dynamic>?> getCurrentWeatherByCity(
      String cityName) async {
    try {
      final response = await http.get(
        Uri.parse(
            '$_baseUrl/weather?q=$cityName,LK&appid=$_apiKey&units=metric'),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return _formatWeatherData(data);
      }
    } catch (e) {
      print('Error fetching weather by city: $e');
    }
    return null;
  }

  /// Get weather forecast for 5 days
  static Future<List<Map<String, dynamic>>?> getWeatherForecast({
    required double latitude,
    required double longitude,
  }) async {
    try {
      final response = await http.get(
        Uri.parse(
            '$_baseUrl/forecast?lat=$latitude&lon=$longitude&appid=$_apiKey&units=metric'),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return _formatForecastData(data);
      }
    } catch (e) {
      print('Error fetching forecast: $e');
    }
    return null;
  }

  /// Format weather data from API response
  static Map<String, dynamic> _formatWeatherData(Map<String, dynamic> data) {
    return {
      'temperature': '${data['main']['temp'].round()}°C',
      'condition': data['weather'][0]['main'],
      'description': data['weather'][0]['description'],
      'humidity': '${data['main']['humidity']}%',
      'wind_speed': '${data['wind']['speed']} m/s',
      'pressure': '${data['main']['pressure']} hPa',
      'feels_like': '${data['main']['feels_like'].round()}°C',
      'visibility': data['visibility'] != null
          ? '${(data['visibility'] / 1000).toStringAsFixed(1)} km'
          : 'N/A',
      'sunrise':
          DateTime.fromMillisecondsSinceEpoch(data['sys']['sunrise'] * 1000),
      'sunset':
          DateTime.fromMillisecondsSinceEpoch(data['sys']['sunset'] * 1000),
      'icon': data['weather'][0]['icon'],
      'city': data['name'],
      'country': data['sys']['country'],
      'best_time':
          _getBestTimeToVisit(data['weather'][0]['main'], data['main']['temp']),
    };
  }

  /// Format forecast data from API response
  static List<Map<String, dynamic>> _formatForecastData(
      Map<String, dynamic> data) {
    List<Map<String, dynamic>> forecast = [];

    for (var item in data['list']) {
      forecast.add({
        'date': DateTime.fromMillisecondsSinceEpoch(item['dt'] * 1000),
        'temperature': '${item['main']['temp'].round()}°C',
        'condition': item['weather'][0]['main'],
        'description': item['weather'][0]['description'],
        'humidity': '${item['main']['humidity']}%',
        'icon': item['weather'][0]['icon'],
      });
    }

    return forecast;
  }

  /// Get best time to visit based on weather conditions
  static String _getBestTimeToVisit(String condition, double temperature) {
    if (condition.toLowerCase().contains('rain') ||
        condition.toLowerCase().contains('storm')) {
      return 'Wait for better weather';
    }

    if (temperature > 35) {
      return 'Early morning (5-8 AM) or evening (5-7 PM)';
    } else if (temperature > 30) {
      return 'Morning (6-10 AM) or late afternoon (4-6 PM)';
    } else if (temperature > 25) {
      return 'Anytime during daylight';
    } else {
      return 'Midday (10 AM - 3 PM) for warmth';
    }
  }

  /// Get weather icon URL
  static String getWeatherIconUrl(String iconCode) {
    return 'https://openweathermap.org/img/wn/$iconCode@2x.png';
  }

  /// Get weather color based on condition
  static Color getWeatherColor(String condition) {
    switch (condition.toLowerCase()) {
      case 'clear':
        return Colors.orange;
      case 'clouds':
        return Colors.grey;
      case 'rain':
      case 'drizzle':
        return Colors.blue;
      case 'thunderstorm':
        return Colors.purple;
      case 'snow':
        return Colors.lightBlue;
      case 'mist':
      case 'fog':
        return Colors.blueGrey;
      default:
        return Colors.blue;
    }
  }

  /// Get weather icon based on condition
  static IconData getWeatherIcon(String condition) {
    switch (condition.toLowerCase()) {
      case 'clear':
        return Icons.wb_sunny;
      case 'clouds':
        return Icons.cloud;
      case 'rain':
        return Icons.grain;
      case 'drizzle':
        return Icons.grain;
      case 'thunderstorm':
        return Icons.flash_on;
      case 'snow':
        return Icons.ac_unit;
      case 'mist':
      case 'fog':
        return Icons.foggy;
      default:
        return Icons.wb_cloudy;
    }
  }

  /// Get all available places for weather
  static List<String> getAllAvailablePlaces() {
    return _weatherLocations?.keys.toList() ?? [];
  }

  /// Check if a place has weather data available
  static bool hasWeatherData(String placeName) {
    return _weatherLocations?.containsKey(placeName.toLowerCase()) ?? false;
  }

  /// Get nearest weather location
  static String? getNearestWeatherLocation(double latitude, double longitude) {
    if (_weatherLocations == null) return null;

    String? nearestPlace;
    double minDistance = double.infinity;

    _weatherLocations!.forEach((placeName, coords) {
      double distance = _calculateDistance(
          latitude, longitude, coords['lat']!, coords['lon']!);

      if (distance < minDistance) {
        minDistance = distance;
        nearestPlace = placeName;
      }
    });

    return nearestPlace;
  }

  /// Calculate distance between two coordinates (Haversine formula)
  static double _calculateDistance(
      double lat1, double lon1, double lat2, double lon2) {
    const double R = 6371; // Earth's radius in km

    double dLat = _toRadians(lat2 - lat1);
    double dLon = _toRadians(lon2 - lon1);

    double a = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(_toRadians(lat1)) *
            math.cos(_toRadians(lat2)) *
            math.sin(dLon / 2) *
            math.sin(dLon / 2);

    double c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));

    return R * c;
  }

  /// Convert degrees to radians
  static double _toRadians(double degrees) {
    return degrees * (math.pi / 180);
  }

  /// Get weather for multiple places
  static Future<Map<String, Map<String, dynamic>?>> getMultipleWeather(
      List<String> placeNames) async {
    Map<String, Map<String, dynamic>?> results = {};

    for (String placeName in placeNames) {
      results[placeName] = await getSriLankanPlaceWeather(placeName);

      // Add small delay to avoid rate limiting
      await Future.delayed(Duration(milliseconds: 100));
    }

    return results;
  }

  /// Get weather suggestions based on conditions
  static List<String> getWeatherSuggestions(Map<String, dynamic> weather) {
    List<String> suggestions = [];

    String condition = weather['condition']?.toLowerCase() ?? '';
    double? temp =
        double.tryParse(weather['temperature']?.replaceAll('°C', '') ?? '');

    if (condition.contains('rain')) {
      suggestions.add(' Carry an umbrella');
      suggestions.add(' Great time for indoor activities');
      suggestions.add('Perfect weather for hot beverages');
    } else if (condition.contains('clear') || condition.contains('sunny')) {
      suggestions.add(' Perfect for outdoor activities');
      suggestions.add(' Don\'t forget sunscreen');
      suggestions.add(' Stay hydrated');
    } else if (condition.contains('cloud')) {
      suggestions.add(' Good for photography');
      suggestions.add(' Great for walking tours');
      suggestions.add(' Soft lighting conditions');
    }

    if (temp != null) {
      if (temp > 30) {
        suggestions.add(' Very warm - seek shade');
        suggestions.add(' Light clothing recommended');
      } else if (temp < 20) {
        suggestions.add(' Cool weather - bring a jacket');
        suggestions.add(' Warm drinks recommended');
      } else {
        suggestions.add(' Comfortable temperature');
        suggestions.add(' Perfect weather for any activity');
      }
    }

    return suggestions;
  }

  /// Cache weather data to reduce API calls
  static final Map<String, Map<String, dynamic>> _weatherCache = {};
  static final Map<String, DateTime> _cacheTimestamps = {};
  static const Duration _cacheExpiry = Duration(minutes: 30);

  /// Check if cached data is still valid
  static bool _isCacheValid(String key) {
    if (!_weatherCache.containsKey(key) || !_cacheTimestamps.containsKey(key)) {
      return false;
    }

    DateTime cachedTime = _cacheTimestamps[key]!;
    return DateTime.now().difference(cachedTime) < _cacheExpiry;
  }

  /// Get cached weather data
  static Map<String, dynamic>? _getCachedWeather(String key) {
    if (_isCacheValid(key)) {
      return _weatherCache[key];
    }
    return null;
  }

  /// Cache weather data
  static void _cacheWeather(String key, Map<String, dynamic> data) {
    _weatherCache[key] = data;
    _cacheTimestamps[key] = DateTime.now();
  }

  /// Get weather with caching
  static Future<Map<String, dynamic>?> getWeatherWithCache(
      double latitude, double longitude) async {
    String cacheKey =
        '${latitude.toStringAsFixed(4)},${longitude.toStringAsFixed(4)}';

    // Check cache first
    Map<String, dynamic>? cachedData = _getCachedWeather(cacheKey);
    if (cachedData != null) {
      return cachedData;
    }

    // Fetch new data
    Map<String, dynamic>? weatherData = await getCurrentWeather(
      latitude: latitude,
      longitude: longitude,
    );

    // Cache the result
    if (weatherData != null) {
      _cacheWeather(cacheKey, weatherData);
    }

    return weatherData;
  }

  /// Clear weather cache
  static void clearCache() {
    _weatherCache.clear();
    _cacheTimestamps.clear();
  }

  /// Get cache statistics
  static Map<String, dynamic> getCacheStats() {
    return {
      'cached_entries': _weatherCache.length,
      'cache_size': _weatherCache.length,
      'oldest_entry': _cacheTimestamps.values.isNotEmpty
          ? _cacheTimestamps.values.reduce((a, b) => a.isBefore(b) ? a : b)
          : null,
      'newest_entry': _cacheTimestamps.values.isNotEmpty
          ? _cacheTimestamps.values.reduce((a, b) => a.isAfter(b) ? a : b)
          : null,
    };
  }

  /// Debug method to print all available places
  static void debugPrintAllPlaces() {
    if (_weatherLocations != null) {
      print(
          '=== Available Weather Locations (${_weatherLocations!.length}) ===');
      _weatherLocations!.forEach((name, coords) {
        print('$name: ${coords['lat']}, ${coords['lon']}');
      });
    }
  }

  /// Get weather locations count
  static int getWeatherLocationsCount() {
    return _weatherLocations?.length ?? 0;
  }

  /// Test connection to weather API
  static Future<bool> testConnection() async {
    try {
      final response = await http.get(
        Uri.parse(
            '$_baseUrl/weather?lat=6.9271&lon=79.8612&appid=$_apiKey&units=metric'),
      );
      return response.statusCode == 200;
    } catch (e) {
      print('Connection test failed: $e');
      return false;
    }
  }
}
