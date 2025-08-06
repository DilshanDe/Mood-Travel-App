import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:geolocator/geolocator.dart';

import 'package:url_launcher/url_launcher.dart';
import 'enhanced_ml_service.dart';
import 'weather_service.dart';

class PlaceDetailsPage extends StatefulWidget {
  final Map<String, dynamic> placeData;
  final String? userId;

  const PlaceDetailsPage({
    super.key,
    required this.placeData,
    this.userId,
  });

  @override
  State<PlaceDetailsPage> createState() => _PlaceDetailsPageState();
}

class _PlaceDetailsPageState extends State<PlaceDetailsPage>
    with TickerProviderStateMixin {
  late AnimationController _slideController;
  late AnimationController _fadeController;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _fadeAnimation;

  List<Map<String, dynamic>> relatedPlaces = [];
  List<Map<String, dynamic>> reviews = [];
  Map<String, dynamic>? weatherInfo;
  bool _imageLoaded = false;
  bool _isLoadingDirections = false;
  Position? _currentPosition;

  @override
  void initState() {
    super.initState();

    _slideController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );

    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0.0, 0.3),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _slideController,
      curve: Curves.easeOutCubic,
    ));

    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeOut,
    ));

    _initializePage();
  }

  @override
  void dispose() {
    _slideController.dispose();
    _fadeController.dispose();
    super.dispose();
  }

  Future<void> _initializePage() async {
    // Start animations
    _slideController.forward();
    _fadeController.forward();

    // Initialize data
    await _loadPlaceDetails();
    await _loadRelatedPlaces();
    await _loadReviews();
    await _loadWeatherInfo();
  }

  Future<void> _loadPlaceDetails() async {
    // Simulate loading
    await Future.delayed(Duration(milliseconds: 500));
  }

  Future<void> _loadRelatedPlaces() async {
    try {
      // Load places data from assets
      String placesJson =
          await rootBundle.loadString('assets/models/places_data.json');
      Map<String, dynamic> allPlaces = jsonDecode(placesJson);

      String currentCategory = widget.placeData['category'] ?? 'general';
      List<dynamic> categoryPlaces = allPlaces[currentCategory] ?? [];

      // Get 3 random related places (excluding current place)
      List<Map<String, dynamic>> related = [];
      for (var place in categoryPlaces) {
        if (place['name'] != widget.placeData['name']) {
          related.add(Map<String, dynamic>.from(place));
        }
      }

      related.shuffle();

      setState(() {
        relatedPlaces = related.take(3).toList();
      });
    } catch (e) {
      print('Error loading related places: $e');
      setState(() {
        relatedPlaces = _getFallbackRelatedPlaces();
      });
    }
  }

  List<Map<String, dynamic>> _getFallbackRelatedPlaces() {
    return [
      {
        'name': 'Similar Adventure Spot',
        'cost': 45,
        'duration': 1,
        'activities': ['hiking', 'photography'],
        'category': widget.placeData['category'],
        'image': ''
      },
      {
        'name': 'Another Great Place',
        'cost': 60,
        'duration': 2,
        'activities': ['sightseeing', 'relaxation'],
        'category': widget.placeData['category'],
        'image': ''
      },
    ];
  }

  Future<void> _loadReviews() async {
    await Future.delayed(Duration(milliseconds: 800));

    List<Map<String, dynamic>> sampleReviews = [
      {
        'user': 'Dilshan De Silva',
        'rating': 5,
        'comment':
            'Absolutely stunning! The ${widget.placeData['name']} exceeded all expectations. Perfect for ${_getActivityString()}.',
        'date': '2 days ago',
        'helpful': 12
      },
      {
        'user': 'Kasun Perera',
        'rating': 4,
        'comment':
            'Great experience! Budget-friendly and well worth the Rs ${widget.placeData['cost']}. Would definitely recommend.',
        'date': '1 week ago',
        'helpful': 8
      },
      {
        'user': 'Kavindu Perera',
        'rating': 5,
        'comment':
            'Perfect ${widget.placeData['duration']}-day trip. The activities were amazing, especially the ${_getRandomActivity()}!',
        'date': '2 weeks ago',
        'helpful': 15
      },
    ];

    setState(() {
      reviews = sampleReviews;
    });
  }

  Future<void> _loadWeatherInfo() async {
    try {
      // Show loading state
      setState(() {
        weatherInfo = {
          'temperature': 'Loading...',
          'condition': 'Loading...',
          'humidity': 'Loading...',
          'best_time': 'Loading...',
        };
      });

      // Get weather for the specific place using enhanced service
      String placeName = widget.placeData['name'] ?? 'Colombo';
      Map<String, dynamic>? weather =
          await WeatherService.getSriLankanPlaceWeather(placeName);

      if (weather != null) {
        setState(() {
          weatherInfo = weather;
        });
      } else {
        // Fallback to mock data if API fails
        setState(() {
          weatherInfo = {
            'temperature': '${math.Random().nextInt(10) + 25}°C',
            'condition': [
              'Sunny',
              'Partly Cloudy',
              'Clear'
            ][math.Random().nextInt(3)],
            'humidity': '${math.Random().nextInt(20) + 60}%',
            'best_time': _getBestTimeToVisit(),
          };
        });
      }
    } catch (e) {
      print('Error loading weather: $e');
      // Fallback to mock data
      setState(() {
        weatherInfo = {
          'temperature': '${math.Random().nextInt(10) + 25}°C',
          'condition': 'Partly Cloudy',
          'humidity': '${math.Random().nextInt(20) + 60}%',
          'best_time': _getBestTimeToVisit(),
        };
      });
    }
  }

  String _getBestTimeToVisit() {
    String category = widget.placeData['category'] ?? 'general';
    Map<String, String> bestTimes = {
      'mountain': 'Early morning (6-8 AM)',
      'beach': 'Late afternoon (4-6 PM)',
      'cultural': 'Morning (8-11 AM)',
      'nature': 'Early morning (5-7 AM)',
      'historical': 'Morning (8-11 AM)',
      'adventure': 'Early morning (6-9 AM)',
      'urban': 'Evening (5-8 PM)',
      'food_tourism': 'Lunch/Dinner time',
      'wildlife': 'Early morning (5-8 AM)',
      'relaxation': 'Anytime',
    };
    return bestTimes[category] ?? 'Morning (8-11 AM)';
  }

  String _getActivityString() {
    List<dynamic> activities = widget.placeData['activities'] ?? [];
    if (activities.isEmpty) return 'sightseeing';
    return activities.first.toString().replaceAll('_', ' ');
  }

  String _getRandomActivity() {
    List<dynamic> activities = widget.placeData['activities'] ?? ['exploring'];
    activities.shuffle();
    return activities.first.toString().replaceAll('_', ' ');
  }

  // Enhanced direction method
  Future<void> _openDirections() async {
    setState(() {
      _isLoadingDirections = true;
    });

    try {
      // Show loading state
      _showSnackBar(
        'Getting your location...',
        Colors.orange,
      );

      // Get current location
      Position? position = await _getCurrentLocation();

      if (position != null) {
        setState(() {
          _currentPosition = position;
        });

        // Show pending direction with current location
        _showDirectionPendingDialog(position);
      } else {
        // Fallback: Open directions without current location
        _openDirectionsWithoutLocation();
      }
    } catch (e) {
      _showSnackBar(
        'Error getting location: $e',
        Colors.red,
      );
      // Fallback: Open directions without current location
      _openDirectionsWithoutLocation();
    } finally {
      setState(() {
        _isLoadingDirections = false;
      });
    }
  }

  Future<Position?> _getCurrentLocation() async {
    try {
      // Check if location services are enabled
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        _showSnackBar(
          'Location services are disabled. Please enable them.',
          Colors.red,
        );
        return null;
      }

      // Check location permission
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          _showSnackBar(
            'Location permissions are denied',
            Colors.red,
          );
          return null;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        _showSnackBar(
          'Location permissions are permanently denied',
          Colors.red,
        );
        return null;
      }

      // Get current position
      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: Duration(seconds: 10),
      );

      return position;
    } catch (e) {
      print('Error getting current location: $e');
      return null;
    }
  }

  void _showDirectionPendingDialog(Position currentPosition) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          elevation: 8,
          child: Container(
            padding: EdgeInsets.all(24),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Colors.blue.shade50,
                  Colors.white,
                ],
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header
                Row(
                  children: [
                    Container(
                      padding: EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.blue.shade100,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        Icons.directions,
                        color: Colors.blue.shade700,
                        size: 24,
                      ),
                    ),
                    SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Navigation Ready',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.grey.shade800,
                            ),
                          ),
                          Text(
                            'Direction to ${widget.placeData['name']}',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey.shade600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),

                SizedBox(height: 24),

                // Current Location Card
                Container(
                  width: double.infinity,
                  padding: EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.green.shade50,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.green.shade200, width: 1),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.my_location,
                              color: Colors.green.shade700, size: 20),
                          SizedBox(width: 8),
                          Text(
                            'Your Current Location',
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 15,
                              color: Colors.green.shade800,
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 8),
                      Container(
                        padding:
                            EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.green.shade100),
                        ),
                        child: Text(
                          'Lat: ${currentPosition.latitude.toStringAsFixed(4)}, '
                          'Lng: ${currentPosition.longitude.toStringAsFixed(4)}',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey.shade700,
                            fontFamily: 'monospace',
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                SizedBox(height: 12),

                // Destination Card
                Container(
                  width: double.infinity,
                  padding: EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey.shade300, width: 1),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.place,
                              color: Colors.grey.shade700, size: 20),
                          SizedBox(width: 8),
                          Text(
                            'Destination',
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 15,
                              color: Colors.grey.shade700,
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 8),
                      Text(
                        widget.placeData['name'] ?? 'Unknown Place',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.grey.shade800,
                        ),
                      ),
                      SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(Icons.location_on,
                              color: Colors.grey.shade600, size: 14),
                          SizedBox(width: 4),
                          Text(
                            'Sri Lanka',
                            style: TextStyle(
                              fontSize: 13,
                              color: Colors.grey.shade600,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                SizedBox(height: 24),

                // Action Buttons
                Row(
                  children: [
                    Expanded(
                      child: TextButton(
                        onPressed: () {
                          Navigator.of(context).pop();
                        },
                        child: Text(
                          'Cancel',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        style: TextButton.styleFrom(
                          foregroundColor: Colors.grey.shade700,
                          padding: EdgeInsets.symmetric(vertical: 12),
                        ),
                      ),
                    ),
                    SizedBox(width: 12),
                    Expanded(
                      flex: 2,
                      child: ElevatedButton.icon(
                        onPressed: () {
                          Navigator.of(context).pop();
                          _openInGoogleMaps(currentPosition);
                        },
                        icon: Icon(Icons.map, size: 20),
                        label: Text(
                          'Open in Google Maps',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green.shade600,
                          foregroundColor: Colors.white,
                          padding: EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          elevation: 2,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _openInGoogleMaps(Position currentPosition) async {
    final String placeName = widget.placeData['name'] ?? 'Unknown Place';
    final String encodedPlaceName = Uri.encodeComponent(placeName);

    // Google Maps URL with current location
    final String googleMapsUrl = 'https://www.google.com/maps/dir/'
        '${currentPosition.latitude},${currentPosition.longitude}/'
        '$encodedPlaceName,+Sri+Lanka';

    try {
      if (await canLaunch(googleMapsUrl)) {
        await launch(googleMapsUrl);
        _showSnackBar(
          'Opening directions in Google Maps',
          Colors.blue,
          icon: Icons.map,
        );
      } else {
        throw 'Could not launch Google Maps';
      }
    } catch (e) {
      _showSnackBar(
        'Error opening Google Maps. Please ensure it\'s installed.',
        Colors.red,
        icon: Icons.error,
      );
    }
  }

  void _openDirectionsWithoutLocation() {
    final String placeName = widget.placeData['name'] ?? 'Unknown Place';
    final String encodedPlaceName = Uri.encodeComponent(placeName);

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          elevation: 8,
          child: Container(
            padding: EdgeInsets.all(24),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Colors.orange.shade50,
                  Colors.white,
                ],
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header
                Row(
                  children: [
                    Container(
                      padding: EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.orange.shade100,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        Icons.location_off,
                        color: Colors.orange.shade700,
                        size: 24,
                      ),
                    ),
                    SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Location Unavailable',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.grey.shade800,
                            ),
                          ),
                          Text(
                            'Unable to get your current location',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey.shade600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),

                SizedBox(height: 20),

                // Info Card
                Container(
                  width: double.infinity,
                  padding: EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade50,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.blue.shade200, width: 1),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.info_outline,
                              color: Colors.blue.shade700, size: 20),
                          SizedBox(width: 8),
                          Text(
                            'Alternative Option',
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 15,
                              color: Colors.blue.shade800,
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 8),
                      Text(
                        'You can still open the destination in Google Maps.',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey.shade700,
                          height: 1.4,
                        ),
                      ),
                    ],
                  ),
                ),

                SizedBox(height: 16),

                // Destination Info
                Container(
                  width: double.infinity,
                  padding: EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade50,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey.shade200, width: 1),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.place,
                              color: Colors.grey.shade700, size: 20),
                          SizedBox(width: 8),
                          Text(
                            'Destination',
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 15,
                              color: Colors.grey.shade800,
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 8),
                      Text(
                        placeName,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.grey.shade800,
                        ),
                      ),
                      SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(Icons.location_on,
                              color: Colors.grey.shade600, size: 14),
                          SizedBox(width: 4),
                          Text(
                            'Sri Lanka',
                            style: TextStyle(
                              fontSize: 13,
                              color: Colors.grey.shade600,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                SizedBox(height: 24),

                // Action Buttons
                Row(
                  children: [
                    Expanded(
                      child: TextButton(
                        onPressed: () => Navigator.of(context).pop(),
                        child: Text(
                          'Cancel',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        style: TextButton.styleFrom(
                          foregroundColor: Colors.grey.shade700,
                          padding: EdgeInsets.symmetric(vertical: 12),
                        ),
                      ),
                    ),
                    SizedBox(width: 12),
                    Expanded(
                      flex: 2,
                      child: ElevatedButton.icon(
                        onPressed: () {
                          Navigator.of(context).pop();
                          _launchUrl(
                              'https://www.google.com/maps/search/$encodedPlaceName,+Sri+Lanka');
                        },
                        icon: Icon(Icons.map, size: 20),
                        label: Text(
                          'Open in Google Maps',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green.shade600,
                          foregroundColor: Colors.white,
                          padding: EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          elevation: 2,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _launchUrl(String url) async {
    try {
      if (await canLaunch(url)) {
        await launch(url);
        _showSnackBar(
          'Opening Google Maps...',
          Colors.green,
          icon: Icons.map,
        );
      } else {
        throw 'Could not launch $url';
      }
    } catch (e) {
      _showSnackBar(
        'Error opening Google Maps. Please ensure it\'s installed.',
        Colors.red,
        icon: Icons.error,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: CustomScrollView(
        slivers: [
          _buildSliverAppBar(),
          SliverToBoxAdapter(
            child: SlideTransition(
              position: _slideAnimation,
              child: FadeTransition(
                opacity: _fadeAnimation,
                child: Column(
                  children: [
                    _buildPlaceInfo(),
                    _buildActionButtons(),
                    _buildImageGallery(),
                    _buildDetailsSection(),
                    _buildActivitiesSection(),
                    _buildWeatherSection(),
                    _buildReviewsSection(),
                    _buildRelatedPlacesSection(),
                    SizedBox(height: 100),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
    );
  }

  Widget _buildSliverAppBar() {
    String? imageUrl = widget.placeData['image'];

    return SliverAppBar(
      expandedHeight: 350,
      pinned: true,
      elevation: 0,
      backgroundColor: Colors.white,
      leading: Container(
        margin: EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.9),
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.2),
              blurRadius: 8,
              offset: Offset(0, 2),
            ),
          ],
        ),
        child: IconButton(
          icon: Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      flexibleSpace: FlexibleSpaceBar(
        background: Stack(
          fit: StackFit.expand,
          children: [
            // Background Image
            if (imageUrl != null && imageUrl.isNotEmpty)
              CachedNetworkImage(
                imageUrl: imageUrl,
                fit: BoxFit.cover,
                placeholder: (context, url) => Container(
                  color: _getCategoryColor(widget.placeData['category'])
                      .withOpacity(0.3),
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        CircularProgressIndicator(
                          valueColor:
                              AlwaysStoppedAnimation<Color>(Colors.white),
                        ),
                        SizedBox(height: 16),
                        Text(
                          'Loading image',
                          style: TextStyle(color: Colors.white),
                        ),
                      ],
                    ),
                  ),
                ),
                errorWidget: (context, url, error) => Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        _getCategoryColor(widget.placeData['category'])
                            .withOpacity(0.8),
                        _getCategoryColor(widget.placeData['category'])
                            .withOpacity(0.4),
                      ],
                    ),
                  ),
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          _getCategoryIcon(widget.placeData['category']),
                          size: 80,
                          color: Colors.white,
                        ),
                        SizedBox(height: 16),
                        Text(
                          widget.placeData['name'] ?? 'Unknown Place',
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                ),
                imageBuilder: (context, imageProvider) {
                  _imageLoaded = true;
                  return Container(
                    decoration: BoxDecoration(
                      image: DecorationImage(
                        image: imageProvider,
                        fit: BoxFit.cover,
                      ),
                    ),
                  );
                },
              )
            else
              // Fallback gradient background
              Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      _getCategoryColor(widget.placeData['category'])
                          .withOpacity(0.8),
                      _getCategoryColor(widget.placeData['category'])
                          .withOpacity(0.4),
                    ],
                  ),
                ),
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        _getCategoryIcon(widget.placeData['category']),
                        size: 80,
                        color: Colors.white,
                      ),
                      SizedBox(height: 16),
                      Text(
                        widget.placeData['name'] ?? 'Unknown Place',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              ),

            // Dark overlay for better text readability
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black.withOpacity(0.3),
                    Colors.black.withOpacity(0.1),
                    Colors.black.withOpacity(0.7),
                  ],
                  stops: [0.0, 0.5, 1.0],
                ),
              ),
            ),

            // Place name overlay at bottom
            Positioned(
              bottom: 20,
              left: 20,
              right: 20,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: _getCategoryColor(widget.placeData['category']),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      _capitalizeFirst(
                          widget.placeData['category'] ?? 'General'),
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  SizedBox(height: 8),
                  Text(
                    widget.placeData['name'] ?? 'Unknown Place',
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                      shadows: [
                        Shadow(
                          color: Colors.black.withOpacity(0.5),
                          offset: Offset(0, 2),
                          blurRadius: 4,
                        ),
                      ],
                    ),
                  ),
                  SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(Icons.location_on, color: Colors.white, size: 16),
                      SizedBox(width: 4),
                      Text(
                        'Sri Lanka',
                        style: TextStyle(
                          fontSize: 16,
                          color: Colors.white.withOpacity(0.9),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildImageGallery() {
    String? imageUrl = widget.placeData['image'];
    if (imageUrl == null || imageUrl.isEmpty) return SizedBox.shrink();

    return Container(
      margin: EdgeInsets.all(20),
      height: 200,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.3),
            spreadRadius: 2,
            blurRadius: 8,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: CachedNetworkImage(
          imageUrl: imageUrl,
          fit: BoxFit.cover,
          width: double.infinity,
          placeholder: (context, url) => Container(
            color: Colors.grey.shade200,
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation<Color>(
                      _getCategoryColor(widget.placeData['category']),
                    ),
                  ),
                  SizedBox(height: 12),
                  Text(
                    'Loading image',
                    style: TextStyle(color: Colors.grey.shade600),
                  ),
                ],
              ),
            ),
          ),
          errorWidget: (context, url, error) => Container(
            color: Colors.grey.shade200,
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.image_not_supported,
                    size: 48,
                    color: Colors.grey.shade400,
                  ),
                  SizedBox(height: 8),
                  Text(
                    'Image not available',
                    style: TextStyle(
                      color: Colors.grey.shade600,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPlaceInfo() {
    return Container(
      padding: EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (widget.placeData['confidence'] != null) ...[
            Container(
              padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: _getConfidenceColor(widget.placeData['confidence'])
                    .withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: _getConfidenceColor(widget.placeData['confidence']),
                  width: 1,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.psychology,
                    size: 14,
                    color: _getConfidenceColor(widget.placeData['confidence']),
                  ),
                  SizedBox(width: 4),
                  Text(
                    '${(widget.placeData['confidence'] * 100).round()}% Match',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color:
                          _getConfidenceColor(widget.placeData['confidence']),
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(height: 16),
          ],
          Text(
            widget.placeData['name'] ?? 'Unknown Place',
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: Colors.grey.shade800,
            ),
          ),
          SizedBox(height: 8),
          Row(
            children: [
              Icon(Icons.location_on, color: Colors.red, size: 16),
              SizedBox(width: 4),
              Text(
                'Sri Lanka',
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.grey.shade600,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildActionButtons() {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: SizedBox(
        width: double.infinity,
        child: ElevatedButton.icon(
          onPressed: _isLoadingDirections ? null : _openDirections,
          icon: _isLoadingDirections
              ? SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  ),
                )
              : Icon(Icons.directions, color: Colors.white, size: 20),
          label: Text(
            _isLoadingDirections ? 'Getting Location' : 'Get Directions',
            style: TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
          style: ElevatedButton.styleFrom(
            backgroundColor: _isLoadingDirections ? Colors.grey : Colors.blue,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            padding: EdgeInsets.symmetric(vertical: 14),
            elevation: 2,
          ),
        ),
      ),
    );
  }

  Widget _buildDetailsSection() {
    return Container(
      margin: EdgeInsets.all(20),
      padding: EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            spreadRadius: 1,
            blurRadius: 10,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.info_outline, color: Colors.blue, size: 24),
              SizedBox(width: 8),
              Text(
                'Details',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey.shade800,
                ),
              ),
            ],
          ),
          SizedBox(height: 20),
          _buildDetailRow(Icons.attach_money, 'Cost',
              ' ${widget.placeData['cost'] ?? 100}'),
          SizedBox(height: 16),
          _buildDetailRow(Icons.schedule, 'Duration',
              '${widget.placeData['duration'] ?? 1} day(s)'),
          SizedBox(height: 16),
          _buildDetailRow(Icons.group, 'Best for', _getBestGroupSize()),
          SizedBox(height: 16),
          _buildDetailRow(Icons.access_time, 'Best time',
              weatherInfo?['best_time'] ?? 'Morning'),
        ],
      ),
    );
  }

  Widget _buildDetailRow(IconData icon, String label, String value) {
    return Row(
      children: [
        Container(
          padding: EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.blue.shade50,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: Colors.blue, size: 20),
        ),
        SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey.shade600,
                ),
              ),
              Text(
                value,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey.shade800,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildActivitiesSection() {
    List<dynamic> activities = widget.placeData['activities'] ?? [];
    if (activities.isEmpty) return SizedBox.shrink();

    return Container(
      margin: EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      padding: EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            spreadRadius: 1,
            blurRadius: 10,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.local_activity, color: Colors.orange, size: 24),
              SizedBox(width: 8),
              Text(
                'Activities',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey.shade800,
                ),
              ),
            ],
          ),
          SizedBox(height: 16),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: activities.map((activity) {
              return Container(
                padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      _getCategoryColor(widget.placeData['category'])
                          .withOpacity(0.1),
                      _getCategoryColor(widget.placeData['category'])
                          .withOpacity(0.05),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: _getCategoryColor(widget.placeData['category'])
                        .withOpacity(0.3),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      _getActivityIcon(activity.toString()),
                      size: 16,
                      color: _getCategoryColor(widget.placeData['category']),
                    ),
                    SizedBox(width: 6),
                    Text(
                      _formatActivity(activity.toString()),
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: _getCategoryColor(widget.placeData['category']),
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildWeatherSection() {
    if (weatherInfo == null) return SizedBox.shrink();

    return Container(
      margin: EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      padding: EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            WeatherService.getWeatherColor(weatherInfo!['condition'] ?? 'Clear')
                .withOpacity(0.1),
            WeatherService.getWeatherColor(weatherInfo!['condition'] ?? 'Clear')
                .withOpacity(0.05),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: WeatherService.getWeatherColor(
                  weatherInfo!['condition'] ?? 'Clear')
              .withOpacity(0.3),
          width: 0.5,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                WeatherService.getWeatherIcon(
                    weatherInfo!['condition'] ?? 'Clear'),
                color: WeatherService.getWeatherColor(
                    weatherInfo!['condition'] ?? 'Clear'),
                size: 24,
              ),
              SizedBox(width: 8),
              Text(
                'Current Weather',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey.shade800,
                ),
              ),
              Spacer(),
              if (weatherInfo!['city'] != null) ...[
                Icon(Icons.location_on, size: 16, color: Colors.grey.shade600),
                SizedBox(width: 4),
                Text(
                  weatherInfo!['city'],
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey.shade600,
                  ),
                ),
              ],
            ],
          ),
          SizedBox(height: 16),

          // Main weather info
          Row(
            children: [
              Expanded(
                child: _buildWeatherDetail(
                  'Temperature',
                  weatherInfo!['temperature'],
                  icon: Icons.thermostat,
                ),
              ),
              Expanded(
                child: _buildWeatherDetail(
                  'Condition',
                  weatherInfo!['condition'],
                  icon: WeatherService.getWeatherIcon(
                      weatherInfo!['condition'] ?? 'Clear'),
                ),
              ),
            ],
          ),
          SizedBox(height: 12),

          // Additional weather info
          Row(
            children: [
              Expanded(
                child: _buildWeatherDetail(
                  'Humidity',
                  weatherInfo!['humidity'],
                  icon: Icons.water_drop,
                ),
              ),
              Expanded(
                child: _buildWeatherDetail(
                  'Best Time',
                  weatherInfo!['best_time'],
                  icon: Icons.schedule,
                ),
              ),
            ],
          ),

          // Additional details if available
          if (weatherInfo!['feels_like'] != null) ...[
            SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _buildWeatherDetail(
                    'Feels Like',
                    weatherInfo!['feels_like'],
                    icon: Icons.thermostat_outlined,
                  ),
                ),
                if (weatherInfo!['wind_speed'] != null)
                  Expanded(
                    child: _buildWeatherDetail(
                      'Wind Speed',
                      weatherInfo!['wind_speed'],
                      icon: Icons.air,
                    ),
                  ),
              ],
            ),
          ],

          // Weather description
          if (weatherInfo!['description'] != null) ...[
            SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.7),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                weatherInfo!['description'].toString().toUpperCase(),
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey.shade700,
                  letterSpacing: 0.5,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildWeatherDetail(String label, String value, {IconData? icon}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            if (icon != null) ...[
              Icon(icon, size: 14, color: Colors.grey.shade600),
              SizedBox(width: 4),
            ],
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey.shade600,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
        SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: Colors.grey.shade800,
          ),
        ),
      ],
    );
  }

  Widget _buildReviewsSection() {
    if (reviews.isEmpty) return SizedBox.shrink();

    return Container(
      margin: EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      padding: EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            spreadRadius: 1,
            blurRadius: 10,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              SizedBox(width: 8),
              Text(
                'Reviews',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey.shade800,
                ),
              ),
              Spacer(),
            ],
          ),
          SizedBox(height: 16),
          ...reviews.take(2).map((review) => _buildReviewCard(review)).toList(),
        ],
      ),
    );
  }

  Widget _buildReviewCard(Map<String, dynamic> review) {
    return Container(
      margin: EdgeInsets.only(bottom: 16),
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 16,
                backgroundColor: Colors.blue.shade100,
                child: Text(
                  review['user'][0],
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.blue.shade700,
                  ),
                ),
              ),
              SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      review['user'],
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                      ),
                    ),
                    Row(
                      children: [
                        ...List.generate(5, (index) {
                          return Icon(
                            index < review['rating']
                                ? Icons.star
                                : Icons.star_border,
                            size: 16,
                            color: Colors.amber,
                          );
                        }),
                        SizedBox(width: 8),
                        Text(
                          review['date'],
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey.shade600,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          SizedBox(height: 12),
          Text(
            review['comment'],
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey.shade700,
              height: 1.4,
            ),
          ),
          SizedBox(height: 8),
          Row(
            children: [
              Icon(Icons.thumb_up_outlined,
                  size: 16, color: Colors.grey.shade600),
              SizedBox(width: 4),
              Text(
                'Helpful (${review['helpful']})',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey.shade600,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildRelatedPlacesSection() {
    if (relatedPlaces.isEmpty) return SizedBox.shrink();

    return Container(
      margin: EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: EdgeInsets.only(bottom: 16),
            child: Row(
              children: [
                Icon(Icons.explore, color: Colors.teal, size: 24),
                SizedBox(width: 8),
                Text(
                  'You might also like',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey.shade800,
                  ),
                ),
              ],
            ),
          ),
          SizedBox(
            height: 280,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: EdgeInsets.symmetric(horizontal: 4),
              itemCount: relatedPlaces.length,
              itemBuilder: (context, index) {
                return _buildRelatedPlaceCard(relatedPlaces[index]);
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRelatedPlaceCard(Map<String, dynamic> place) {
    String? imageUrl = place['image'];

    return Container(
      width: 200,
      margin: EdgeInsets.only(right: 16),
      child: Card(
        elevation: 3,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Image section
            Container(
              height: 120,
              width: double.infinity,
              child: ClipRRect(
                borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
                child: imageUrl != null && imageUrl.isNotEmpty
                    ? CachedNetworkImage(
                        imageUrl: imageUrl,
                        fit: BoxFit.cover,
                        placeholder: (context, url) => Container(
                          color: _getCategoryColor(place['category'])
                              .withOpacity(0.3),
                          child: Center(
                            child: CircularProgressIndicator(
                              valueColor:
                                  AlwaysStoppedAnimation<Color>(Colors.white),
                            ),
                          ),
                        ),
                        errorWidget: (context, url, error) => Container(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                _getCategoryColor(place['category'])
                                    .withOpacity(0.8),
                                _getCategoryColor(place['category'])
                                    .withOpacity(0.4),
                              ],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                          ),
                          child: Center(
                            child: Icon(
                              _getCategoryIcon(place['category']),
                              color: Colors.white,
                              size: 32,
                            ),
                          ),
                        ),
                      )
                    : Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              _getCategoryColor(place['category'])
                                  .withOpacity(0.8),
                              _getCategoryColor(place['category'])
                                  .withOpacity(0.4),
                            ],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                        ),
                        child: Center(
                          child: Icon(
                            _getCategoryIcon(place['category']),
                            color: Colors.white,
                            size: 32,
                          ),
                        ),
                      ),
              ),
            ),

            // Content section
            Expanded(
              child: Padding(
                padding: EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding:
                              EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: _getCategoryColor(place['category'])
                                .withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: _getCategoryColor(place['category'])
                                  .withOpacity(0.3),
                            ),
                          ),
                          child: Text(
                            _capitalizeFirst(place['category'] ?? 'General'),
                            style: TextStyle(
                              color: _getCategoryColor(place['category']),
                              fontSize: 9,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        Spacer(),
                        Icon(
                          _getCategoryIcon(place['category']),
                          color: _getCategoryColor(place['category']),
                          size: 14,
                        ),
                      ],
                    ),
                    SizedBox(height: 6),
                    Text(
                      place['name'] ?? 'Unknown Place',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey.shade800,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Spacer(),
                    Row(
                      children: [
                        Icon(Icons.attach_money,
                            color: Colors.grey.shade600, size: 14),
                        Text(
                          ' ${place['cost'] ?? 100}',
                          style: TextStyle(
                            color: Colors.grey.shade600,
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        Spacer(),
                        TextButton(
                          onPressed: () => _navigateToRelatedPlace(place),
                          child: Text(
                            'View',
                            style: TextStyle(
                              color: _getCategoryColor(place['category']),
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                          ),
                          style: TextButton.styleFrom(
                            backgroundColor:
                                _getCategoryColor(place['category'])
                                    .withOpacity(0.1),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(6),
                            ),
                            padding: EdgeInsets.symmetric(
                                horizontal: 8, vertical: 4),
                            minimumSize: Size(0, 0),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Helper Methods
  Color _getCategoryColor(String? category) {
    Map<String, Color> categoryColors = {
      'adventure': Colors.orange,
      'cultural': Colors.purple,
      'relaxation': Colors.green,
      'food_tourism': Colors.red,
      'nature': Colors.teal,
      'urban': Colors.indigo,
      'beach': Colors.cyan,
      'mountain': Colors.brown,
      'historical': Colors.amber,
      'wildlife': Colors.lime,
      'food': Colors.red,
      'general': Colors.grey,
    };
    return categoryColors[category] ?? Colors.grey;
  }

  IconData _getCategoryIcon(String? category) {
    Map<String, IconData> categoryIcons = {
      'adventure': Icons.terrain,
      'cultural': Icons.temple_buddhist,
      'relaxation': Icons.spa,
      'food_tourism': Icons.restaurant,
      'nature': Icons.nature,
      'urban': Icons.location_city,
      'beach': Icons.beach_access,
      'mountain': Icons.landscape,
      'historical': Icons.account_balance,
      'wildlife': Icons.pets,
      'food': Icons.local_dining,
      'general': Icons.place,
    };
    return categoryIcons[category] ?? Icons.place;
  }

  IconData _getActivityIcon(String activity) {
    Map<String, IconData> activityIcons = {
      'hiking': Icons.hiking,
      'photography': Icons.camera_alt,
      'swimming': Icons.pool,
      'surfing': Icons.surfing,
      'temple': Icons.temple_buddhist,
      'museum': Icons.museum,
      'safari': Icons.directions_car,
      'wildlife': Icons.pets,
      'beach': Icons.beach_access,
      'spa': Icons.spa,
      'food': Icons.restaurant,
      'cooking': Icons.restaurant_menu,
      'cultural_show': Icons.theater_comedy,
      'lake': Icons.water,
      'waterfall': Icons.water_drop,
      'cave': Icons.landscape,
      'fishing': Icons.phishing,
      'boat': Icons.directions_boat,
      'cycling': Icons.directions_bike,
      'history': Icons.history_edu,
      'archaeology': Icons.account_balance,
      'pilgrimage': Icons.temple_buddhist,
      'sunrise': Icons.wb_sunny,
      'views': Icons.visibility,
      'meditation': Icons.self_improvement,
      'shopping': Icons.shopping_bag,
      'nightlife': Icons.nightlife,
      'water_sports': Icons.kayaking,
      'snorkeling': Icons.scuba_diving,
      'diving': Icons.scuba_diving,
      'rock_climbing': Icons.terrain,
      'adventure_sports': Icons.sports_motorsports,
    };
    return activityIcons[activity] ?? Icons.local_activity;
  }

  Color _getConfidenceColor(double confidence) {
    if (confidence > 0.8) return Colors.green;
    if (confidence > 0.6) return Colors.orange;
    return Colors.red;
  }

  String _capitalizeFirst(String text) {
    if (text.isEmpty) return text;
    return text[0].toUpperCase() + text.substring(1).replaceAll('_', ' ');
  }

  String _formatActivity(String activity) {
    return activity
        .replaceAll('_', ' ')
        .split(' ')
        .map((word) => word[0].toUpperCase() + word.substring(1))
        .join(' ');
  }

  String _getBestGroupSize() {
    String category = widget.placeData['category'] ?? 'general';
    Map<String, String> groupSizes = {
      'adventure': '2-4 people',
      'cultural': 'Any group size',
      'relaxation': '1-2 people',
      'food_tourism': '2-6 people',
      'nature': '2-4 people',
      'urban': 'Any group size',
      'beach': '2-8 people',
      'mountain': '2-4 people',
      'historical': 'Any group size',
      'wildlife': '2-6 people',
    };
    return groupSizes[category] ?? 'Any group size';
  }

  // Action Methods
  void _planTrip() {
    _showSnackBar(
      '${widget.placeData['name']} added to your trip plan!',
      Colors.purple,
    );
  }

  void _viewAllReviews() {
    _showSnackBar('Opening all reviews...', Colors.purple);
  }

  void _navigateToRelatedPlace(Map<String, dynamic> place) {
    // Navigate to the related place details
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => PlaceDetailsPage(
          placeData: place,
          userId: widget.userId,
        ),
      ),
    );
  }

  void _showSnackBar(String message, Color color, {IconData? icon}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            if (icon != null) ...[
              Icon(icon, color: Colors.white, size: 20),
              SizedBox(width: 8),
            ],
            Expanded(
              child: Text(
                message,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        margin: EdgeInsets.all(20),
        duration: Duration(seconds: 3),
        elevation: 4,
      ),
    );
  }
}
