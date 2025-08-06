import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tflite_flutter/tflite_flutter.dart';
import 'place_details_page.dart';

//  SMART SUGGESTIONS

class SmartSuggestionsWidget extends StatefulWidget {
  final String? userId;

  const SmartSuggestionsWidget({super.key, required this.userId});

  @override
  State<SmartSuggestionsWidget> createState() => _SmartSuggestionsWidgetState();
}

class _SmartSuggestionsWidgetState extends State<SmartSuggestionsWidget>
    with SingleTickerProviderStateMixin {
  List<Map<String, dynamic>> suggestions = [];
  bool isLoading = true;
  bool isMLPowered = false;
  Map<String, dynamic> userPreferences = {};
  String? currentUserId;

  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();

    currentUserId = widget.userId;

    _animationController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeOut),
    );

    _initializeSuggestions();
  }

  @override
  void didUpdateWidget(SmartSuggestionsWidget oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.userId != widget.userId) {
      print(' User changed from ${oldWidget.userId} to ${widget.userId}');
      currentUserId = widget.userId;
      _refreshSuggestions();
    }
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _initializeSuggestions() async {
    try {
      await EnhancedSuggestionEngine.initialize(userId: currentUserId);

      final suggestionsData =
          await EnhancedSuggestionEngine.getPersonalizedSuggestions(
        userId: currentUserId,
        userBudget: 150.0,
        groupSize: 2,
        duration: 3,
        season: _getCurrentSeason(),
      );

      final behaviorTracker = UserBehaviorTracker(currentUserId: currentUserId);
      await behaviorTracker.loadBehaviorData();
      final prefs = behaviorTracker.getUserPreferences();

      if (mounted) {
        setState(() {
          suggestions = suggestionsData;
          userPreferences = prefs;
          isMLPowered = suggestions.isNotEmpty &&
              suggestions.first['suggestion_type'] == 'ml_powered';
          isLoading = false;
        });

        if (_animationController.status != AnimationStatus.forward) {
          _animationController.forward();
        }
      }
    } catch (e) {
      print('Error loading suggestions: $e');
      if (mounted) {
        setState(() {
          isLoading = false;
        });
      }
    }
  }

  String _getCurrentSeason() {
    int month = DateTime.now().month;
    if (month >= 12 || month <= 2) return 'summer';
    if (month >= 3 && month <= 5) return 'spring';
    if (month >= 6 && month <= 8) return 'monsoon';
    return 'autumn';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeader(),
          SizedBox(height: 16),
          if (userPreferences['post_count'] != null &&
              userPreferences['post_count'] > 0)
            _buildUserInsightsCard(),
          if (isLoading)
            _buildLoadingIndicator()
          else if (suggestions.isEmpty)
            _buildNoSuggestionsCard()
          else
            _buildSuggestionsList(),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return FadeTransition(
      opacity: _fadeAnimation,
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    if (isMLPowered) ...[
                      Container(
                        padding:
                            EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              Colors.purple.shade600,
                              Colors.blue.shade600
                            ],
                          ),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              'AI POWERED',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                      SizedBox(width: 12),
                    ],
                    Expanded(
                      child: Text(
                        currentUserId != null
                            ? 'Personalized for You'
                            : 'General Recommendations',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Colors.grey.shade800,
                        ),
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 4),
                Text(
                  currentUserId != null
                      ? (isMLPowered
                          ? 'Based on your travel patterns and preferences'
                          : userPreferences['post_count'] > 0
                              ? 'Based on your ${userPreferences['post_count']} shared places'
                              : 'Curated recommendations to get you started')
                      : 'Sign in to get personalized recommendations',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey.shade600,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: _refreshSuggestions,
            icon: Icon(Icons.refresh, color: Colors.blue),
            tooltip: 'Refresh suggestions',
          ),
        ],
      ),
    );
  }

  Widget _buildUserInsightsCard() {
    return FadeTransition(
      opacity: _fadeAnimation,
      child: Container(
        margin: EdgeInsets.only(bottom: 16),
        padding: EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [Colors.blue.shade50, Colors.purple.shade50],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.blue.shade200, width: 0.5),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.insights, color: Colors.blue.shade700, size: 20),
                SizedBox(width: 8),
                Text(
                  'Your Travel Profile',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.blue.shade800,
                  ),
                ),
                Spacer(),
                if (currentUserId != null)
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.green.shade100,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      'User: ${currentUserId!.length > 8 ? currentUserId!.substring(0, 8) + '...' : currentUserId!}',
                      style: TextStyle(
                        fontSize: 10,
                        color: Colors.green.shade700,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
              ],
            ),
            SizedBox(height: 12),
            _buildInsightRow(
                'Travel Style',
                _capitalizeFirst(
                    userPreferences['dominant_type'] ?? 'Explorer')),
            SizedBox(height: 8),
            _buildInsightRow(
                'Climate Preference',
                _capitalizeFirst(
                    userPreferences['climate_preference'] ?? 'Temperate')),
            SizedBox(height: 8),
            _buildInsightRow(
                'Posts Shared', '${userPreferences['post_count'] ?? 0} places'),
            if (userPreferences['confidence'] != null &&
                userPreferences['confidence'] > 0.3)
              Padding(
                padding: EdgeInsets.only(top: 8),
                child: Row(
                  children: [
                    Icon(Icons.psychology,
                        color: Colors.green.shade600, size: 16),
                    SizedBox(width: 4),
                    Text(
                      'Confidence: ${(userPreferences['confidence'] * 100).round()}%',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.green.shade700,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildInsightRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 14,
            color: Colors.grey.shade700,
          ),
        ),
        Container(
          padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.7),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            value,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: Colors.blue.shade800,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildLoadingIndicator() {
    return Container(
      height: 200,
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SizedBox(
              width: 40,
              height: 40,
              child: CircularProgressIndicator(
                strokeWidth: 3,
                valueColor: AlwaysStoppedAnimation<Color>(Colors.blue),
              ),
            ),
            SizedBox(height: 16),
            Text(
              currentUserId != null
                  ? 'Loading personalized suggestions...'
                  : 'Loading general suggestions...',
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey.shade600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNoSuggestionsCard() {
    return FadeTransition(
      opacity: _fadeAnimation,
      child: Container(
        padding: EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Colors.grey.shade50,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.grey.shade200),
        ),
        child: Column(
          children: [
            Icon(Icons.explore, size: 48, color: Colors.grey.shade400),
            SizedBox(height: 16),
            Text(
              currentUserId != null
                  ? 'Start Your Journey'
                  : 'Welcome Explorer!',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.grey.shade700,
              ),
            ),
            SizedBox(height: 8),
            Text(
              currentUserId != null
                  ? 'Share a few posts about places you visit to get personalized recommendations!'
                  : 'Sign in and share your travel experiences to get personalized recommendations!',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey.shade600,
              ),
            ),
            SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: () {
                // Navigate to add post page or login page
              },
              icon: Icon(Icons.add, color: Colors.white),
              label: Text(
                  currentUserId != null
                      ? 'Share Your First Post'
                      : 'Sign In to Start',
                  style: TextStyle(color: Colors.white)),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSuggestionsList() {
    return Column(
      children: suggestions.asMap().entries.map((entry) {
        int index = entry.key;
        Map<String, dynamic> suggestion = entry.value;

        return AnimatedBuilder(
          animation: _animationController,
          builder: (context, child) {
            double rawValue = _animationController.value - index * 0.1;
            double clampedValue = rawValue.clamp(0.0, 1.0);
            double animationValue = Curves.easeOut.transform(clampedValue);

            return Transform.translate(
              offset: Offset(0, 50 * (1 - animationValue)),
              child: Opacity(
                opacity: animationValue,
                child: _buildSuggestionCard(suggestion, index),
              ),
            );
          },
        );
      }).toList(),
    );
  }

  Widget _buildSuggestionCard(Map<String, dynamic> suggestion, int index) {
    double confidence = suggestion['confidence'] ?? 0.7;
    bool isHighConfidence = confidence > 0.8;

    return Container(
      margin: EdgeInsets.only(bottom: 16),
      child: Card(
        elevation: isHighConfidence ? 8 : 4,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            gradient: isHighConfidence
                ? LinearGradient(
                    colors: [Colors.blue.shade50, Colors.white],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  )
                : null,
            border: isHighConfidence
                ? Border.all(color: Colors.blue.shade200, width: 1)
                : null,
          ),
          child: Padding(
            padding: EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header row
                Row(
                  children: [
                    Container(
                      padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: _getCategoryColor(suggestion['category']),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        _capitalizeFirst(suggestion['category']),
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    Spacer(),
                    if (isHighConfidence) ...[
                      Icon(Icons.recommend, color: Colors.orange, size: 20),
                      SizedBox(width: 4),
                      Text(
                        'Top Pick',
                        style: TextStyle(
                          color: Colors.orange.shade700,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ],
                ),
                SizedBox(height: 12),

                // Place name
                Text(
                  suggestion['name'] ?? 'Unknown Place',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey.shade800,
                  ),
                ),
                SizedBox(height: 8),

                // Details row
                Row(
                  children: [
                    _buildDetailChip(Icons.attach_money,
                        ' ${_safeInt(suggestion["cost"], 100)}'),
                    SizedBox(width: 8),
                    _buildDetailChip(Icons.schedule,
                        '${_safeInt(suggestion['duration'], 1)} days'),
                    Spacer(),
                    Container(
                      padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: _getConfidenceColor(confidence).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                            color: _getConfidenceColor(confidence), width: 1),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.trending_up,
                            size: 14,
                            color: _getConfidenceColor(confidence),
                          ),
                          SizedBox(width: 4),
                          Text(
                            '${(confidence * 100).round()}%',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: _getConfidenceColor(confidence),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 12),

                // Activities
                if (suggestion['activities'] != null)
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: (suggestion['activities'] as List)
                        .take(3)
                        .map((activity) {
                      return Container(
                        padding:
                            EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade100,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          _formatActivity(activity.toString()),
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey.shade700,
                          ),
                        ),
                      );
                    }).toList(),
                  ),

                SizedBox(height: 16),

                // Action button - Only Explore button now
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () => _navigateToPlaceDetails(suggestion),
                    icon: Icon(Icons.explore, size: 16, color: Colors.white),
                    label:
                        Text('Explore', style: TextStyle(color: Colors.white)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      padding: EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDetailChip(IconData icon, String text) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.blue.shade50,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: Colors.blue.shade700),
          SizedBox(width: 4),
          Text(
            text,
            style: TextStyle(
              fontSize: 12,
              color: Colors.blue.shade700,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  // Helper Methods
  Color _getCategoryColor(String category) {
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

  // Action Methods
  Future<void> _refreshSuggestions() async {
    if (!mounted) return;

    setState(() {
      isLoading = true;
    });

    _animationController.reset();
    await _initializeSuggestions();
  }

  void _onSuggestionAction(Map<String, dynamic> suggestion, String action) {
    EnhancedSuggestionEngine.trackSuggestionInteraction(
        currentUserId, suggestion, action);

    switch (action) {
      case 'save':
        _showSnackBar(
            '${suggestion['name']} saved to your wishlist!', Colors.green);
        break;
      case 'view':
        _showSnackBar('Opening ${suggestion['name']} details...', Colors.blue);
        break;
      case 'like':
        _showSnackBar('Thanks for the feedback!', Colors.red);
        break;
    }
  }

  //  NAVIGATE TO PLACE DETAILS PAGE
  void _navigateToPlaceDetails(Map<String, dynamic> suggestion) {
    // Track that user viewed place details
    EnhancedSuggestionEngine.trackSuggestionInteraction(
      currentUserId,
      suggestion,
      'view_details',
    );

    // Navigate to place details page
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => PlaceDetailsPage(
          placeData: suggestion,
          userId: currentUserId,
        ),
      ),
    );
  }

  void _showSnackBar(String message, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        margin: EdgeInsets.all(20),
      ),
    );
  }

  // Helper method to safely convert to int
  int _safeInt(dynamic value, int defaultValue) {
    if (value == null) return defaultValue;
    if (value is int) return value;
    if (value is double) return value.toInt();
    if (value is String) {
      try {
        return int.parse(value);
      } catch (e) {
        try {
          return double.parse(value).toInt();
        } catch (e) {
          return defaultValue;
        }
      }
    }
    return defaultValue;
  }

  // Helper method to safely convert to double
  double _safeDouble(dynamic value, double defaultValue) {
    if (value == null) return defaultValue;
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is String) {
      try {
        return double.parse(value);
      } catch (e) {
        return defaultValue;
      }
    }
    return defaultValue;
  }
}

// SUGGESTION ENGINE

class EnhancedSuggestionEngine {
  static Interpreter? _interpreter;
  static Map<String, dynamic>? _preprocessingParams;
  static Map<String, dynamic>? _placesData;
  static Map<String, UserBehaviorTracker> _userTrackers = {};

  static UserBehaviorTracker _getBehaviorTracker(String? userId) {
    String userKey = userId ?? 'anonymous';

    if (!_userTrackers.containsKey(userKey)) {
      _userTrackers[userKey] = UserBehaviorTracker(currentUserId: userId);
    }

    return _userTrackers[userKey]!;
  }

  static Future<void> initialize({String? userId}) async {
    try {
      if (_interpreter == null) {
        _interpreter = await Interpreter.fromAsset(
            'models/travel_recommendation_model.tflite');

        String paramsJson = await rootBundle
            .loadString('assets/models/preprocessing_params.json');
        _preprocessingParams = jsonDecode(paramsJson);

        String placesJson =
            await rootBundle.loadString('assets/models/places_data.json');
        _placesData = jsonDecode(placesJson);

        print(' ML Model loaded successfully');
        print(' Categories: ${_preprocessingParams!['category_names']}');
      }

      UserBehaviorTracker behaviorTracker = _getBehaviorTracker(userId);
      await behaviorTracker.loadBehaviorData();

      print(' Initialized suggestion engine for user: $userId');
    } catch (e) {
      print(' ML Model failed to load: $e');
      print(' Using fallback rule-based suggestions');

      UserBehaviorTracker behaviorTracker = _getBehaviorTracker(userId);
      await behaviorTracker.loadBehaviorData();

      try {
        String placesJson =
            await rootBundle.loadString('assets/models/places_data.json');
        _placesData = jsonDecode(placesJson);
      } catch (e2) {
        print(' Places data also failed to load: $e2');
        _placesData = _getDefaultPlacesData();
      }
    }
  }

  static Future<void> userLogout(String? userId) async {
    try {
      if (userId != null && _userTrackers.containsKey(userId)) {
        await _userTrackers[userId]!._saveBehaviorData();
        _userTrackers.remove(userId);
        print(' User $userId logged out - cleaned up behavior data');
      }
    } catch (e) {
      print(' Error during user logout: $e');
    }
  }

  static Future<void> userLogin(String? newUserId) async {
    try {
      UserBehaviorTracker behaviorTracker = _getBehaviorTracker(newUserId);
      await behaviorTracker.loadBehaviorData();
      print(' User $newUserId logged in');
    } catch (e) {
      print(' Error during user login: $e');
    }
  }

  static Future<List<Map<String, dynamic>>> getPersonalizedSuggestions({
    required String? userId,
    double? userBudget,
    int? groupSize,
    int? duration,
    String? season,
  }) async {
    try {
      List<Map<String, dynamic>> suggestions = [];

      UserBehaviorTracker behaviorTracker = _getBehaviorTracker(userId);
      Map<String, dynamic> userPrefs = behaviorTracker.getUserPreferences();

      print(
          ' Getting suggestions for user: $userId (${userPrefs['post_count']} posts)');

      if (_interpreter != null && userPrefs['post_count'] > 2) {
        suggestions = await _getMLSuggestions(
            userPrefs, userBudget, groupSize, duration, season);
      } else {
        suggestions = _getRuleBasedSuggestions(
            userPrefs, userBudget, groupSize, duration, season);
      }

      for (var suggestion in suggestions) {
        suggestion['suggestion_type'] =
            _interpreter != null ? 'ml_powered' : 'rule_based';
        suggestion['confidence'] = suggestion['confidence'] ?? 0.7;
        suggestion['target_user'] = userId;
      }

      print(' Generated ${suggestions.length} suggestions for user: $userId');
      return suggestions;
    } catch (e) {
      print(' Error getting suggestions: $e');
      return _getFallbackSuggestions();
    }
  }

  static Future<void> trackUserPost({
    required String? userId,
    required String placeName,
    required String cityName,
    required String caption,
    required double estimatedBudget,
  }) async {
    try {
      UserBehaviorTracker behaviorTracker = _getBehaviorTracker(userId);
      await behaviorTracker.trackPost(
        placeName: placeName,
        cityName: cityName,
        caption: caption,
        estimatedBudget: estimatedBudget,
      );

      print(' Tracked post for user $userId: $placeName');
    } catch (e) {
      print(' Error tracking user post: $e');
    }
  }

  //   ML SUGGESTIONS METHOD
  static Future<List<Map<String, dynamic>>> _getMLSuggestions(
    Map<String, dynamic> userPrefs,
    double? budget,
    int? groupSize,
    int? duration,
    String? season,
  ) async {
    try {
      //  _prepareFeatures method
      List<double> features =
          _prepareFeatures(userPrefs, budget, groupSize, duration, season);

      //  Proper input/output handling
      var input = [features];
      var output = List.filled(10, 0.0);

      _interpreter!.run(input, [output]);

      List<double> probabilities = output;
      List<int> topIndices = _getTopIndices(probabilities, 3);

      List<Map<String, dynamic>> suggestions = [];
      List<String> categoryNames =
          List<String>.from(_preprocessingParams!['category_names']);

      for (int i = 0; i < topIndices.length; i++) {
        int categoryIndex = topIndices[i];
        String category = categoryNames[categoryIndex];
        double confidence = probabilities[categoryIndex];

        List<dynamic> categoryPlaces = _placesData![category] ?? [];

        for (var place in categoryPlaces.take(2)) {
          try {
            Map<String, dynamic> suggestion = Map<String, dynamic>.from(place);
            suggestion['category'] = category;
            suggestion['confidence'] = confidence;
            suggestion['ml_score'] = confidence;
            suggestion['rank'] = i + 1;

            suggestion['cost'] = suggestion['cost'] ?? 100;
            suggestion['duration'] = suggestion['duration'] ?? 1;
            suggestion['name'] = suggestion['name'] ?? 'Unknown Place';
            suggestion['activities'] = suggestion['activities'] ?? [];

            if (budget != null &&
                _safeDouble(suggestion['cost'], 0) > budget * 1.2) {
              continue;
            }

            suggestions.add(suggestion);
          } catch (e) {
            print(' Error processing place suggestion: $e');
            continue;
          }
        }
      }

      return suggestions.take(5).toList();
    } catch (e) {
      print(' ML inference error: $e');
      return _getRuleBasedSuggestions(
          userPrefs, budget, groupSize, duration, season);
    }
  }

  static List<double> _prepareFeatures(
    Map<String, dynamic> userPrefs,
    double? budget,
    int? groupSize,
    int? duration,
    String? season,
  ) {
    List<double> features = List.filled(25, 0.0);

    features[0] = budget != null ? math.log(budget + 1) : 6.0;
    features[1] = (duration ?? 2).toDouble();
    features[2] = (groupSize ?? 2).toDouble();

    int postCount = userPrefs['post_count'] ?? 0;
    features[3] = (postCount / 4).clamp(1, 10).toDouble();
    features[4] = (postCount * 2).toDouble();
    features[5] = (postCount * 0.5).toDouble();

    Map<String, int> activities = userPrefs['activity_preferences'] ?? {};
    features[6] = _normalizeActivityScore(activities['hiking'] ?? 0);
    features[7] = _normalizeActivityScore(activities['cultural_visit'] ?? 0);
    features[8] = _normalizeActivityScore(activities['relaxation'] ?? 0);
    features[9] = _normalizeActivityScore(activities['food_exploration'] ?? 0);
    features[10] =
        _normalizeActivityScore(activities['wildlife_watching'] ?? 0);
    features[11] = _normalizeActivityScore(activities['photography'] ?? 0);

    String currentSeason = season ?? _getCurrentSeason();
    features[12] = currentSeason == 'spring' ? 1.0 : 0.0;
    features[13] = currentSeason == 'summer' ? 1.0 : 0.0;
    features[14] = currentSeason == 'autumn' ? 1.0 : 0.0;
    features[15] = currentSeason == 'winter' ? 1.0 : 0.0;

    String dominantClimate = userPrefs['climate_preference'] ?? 'temperate';
    features[16] = dominantClimate == 'cold' ? 1.0 : 0.0;
    features[17] = dominantClimate == 'temperate' ? 1.0 : 0.0;
    features[18] = dominantClimate == 'tropical' ? 1.0 : 0.0;
    features[19] = dominantClimate == 'hot' ? 1.0 : 0.0;

    String dominantType = userPrefs['dominant_type'] ?? 'general';
    features[20] = dominantType == 'adventure' ? 1.0 : 0.0;
    features[21] = dominantType == 'cultural' ? 1.0 : 0.0;
    features[22] = dominantType == 'relaxation' ? 1.0 : 0.0;
    features[23] = dominantType == 'nature' ? 1.0 : 0.0;
    features[24] = dominantType == 'urban' ? 1.0 : 0.0;

    return features;
  }

  static double _normalizeActivityScore(int count) {
    return (count / 5).clamp(0.0, 1.0);
  }

  static String _getCurrentSeason() {
    int month = DateTime.now().month;
    if (month >= 12 || month <= 2) return 'summer';
    if (month >= 3 && month <= 5) return 'spring';
    if (month >= 6 && month <= 8) return 'monsoon';
    return 'autumn';
  }

  static List<int> _getTopIndices(List<double> probabilities, int k) {
    List<MapEntry<int, double>> indexed = [];
    for (int i = 0; i < probabilities.length; i++) {
      indexed.add(MapEntry(i, probabilities[i]));
    }
    indexed.sort((a, b) => b.value.compareTo(a.value));
    return indexed.take(k).map((entry) => entry.key).toList();
  }

  static List<Map<String, dynamic>> _getRuleBasedSuggestions(
    Map<String, dynamic> userPrefs,
    double? budget,
    int? groupSize,
    int? duration,
    String? season,
  ) {
    List<Map<String, dynamic>> suggestions = [];

    String dominantType = userPrefs['dominant_type'] ?? 'general';
    String climatePreference = userPrefs['climate_preference'] ?? 'temperate';

    List<String> priorityCategories =
        _getPriorityCategories(dominantType, climatePreference);

    for (String category in priorityCategories) {
      List<dynamic> categoryPlaces = _placesData![category] ?? [];

      for (var place in categoryPlaces.take(2)) {
        try {
          Map<String, dynamic> suggestion = Map<String, dynamic>.from(place);
          suggestion['category'] = category;
          suggestion['confidence'] =
              _calculateRuleBasedConfidence(suggestion, userPrefs, budget);

          suggestion['cost'] = suggestion['cost'] ?? 100;
          suggestion['duration'] = suggestion['duration'] ?? 1;
          suggestion['name'] = suggestion['name'] ?? 'Unknown Place';
          suggestion['activities'] = suggestion['activities'] ?? [];

          if (budget != null &&
              _safeDouble(suggestion['cost'], 0) > budget * 1.2) {
            continue;
          }

          suggestions.add(suggestion);
        } catch (e) {
          print(' Error processing rule-based suggestion: $e');
          continue;
        }
      }
    }

    return suggestions.take(5).toList();
  }

  static List<String> _getPriorityCategories(
      String dominantType, String climatePreference) {
    List<String> categories = [];

    if (dominantType != 'general') {
      categories.add(dominantType);
    }

    if (climatePreference == 'cold') {
      categories.addAll(['mountain', 'nature', 'cultural']);
    } else if (climatePreference == 'tropical') {
      categories.addAll(['beach', 'relaxation', 'food_tourism']);
    } else if (climatePreference == 'hot') {
      categories.addAll(['historical', 'cultural', 'urban']);
    } else {
      categories.addAll(['nature', 'adventure', 'cultural']);
    }

    categories = categories.toSet().toList();

    List<String> allCategories = [
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

    for (String cat in allCategories) {
      if (!categories.contains(cat) && categories.length < 6) {
        categories.add(cat);
      }
    }

    return categories;
  }

  static double _calculateRuleBasedConfidence(
    Map<String, dynamic> suggestion,
    Map<String, dynamic> userPrefs,
    double? budget,
  ) {
    double confidence = 0.5;

    if (suggestion['category'] == userPrefs['dominant_type']) {
      confidence += 0.3;
    }

    if (budget != null && suggestion['cost'] != null) {
      double cost = _safeDouble(suggestion['cost'], 0);
      double costDiff = (cost - budget).abs() / budget;
      if (costDiff < 0.2) confidence += 0.2;
    }

    Map<String, int> userActivities = userPrefs['activity_preferences'] ?? {};
    List<dynamic> placeActivities = suggestion['activities'] ?? [];

    for (String activity in placeActivities) {
      if (userActivities.containsKey(activity) &&
          userActivities[activity]! > 0) {
        confidence += 0.1;
      }
    }

    return confidence.clamp(0.0, 1.0);
  }

  static List<Map<String, dynamic>> _getFallbackSuggestions() {
    return [
      {
        'name': 'Sigiriya Rock Fortress',
        'category': 'historical',
        'cost': 50,
        'duration': 1,
        'activities': ['hiking', 'photography', 'history'],
        'confidence': 0.7,
        'suggestion_type': 'fallback'
      },
      {
        'name': 'Kandy Cultural Triangle',
        'category': 'cultural',
        'cost': 40,
        'duration': 2,
        'activities': ['temple', 'cultural_show', 'lake'],
        'confidence': 0.7,
        'suggestion_type': 'fallback'
      },
      {
        'name': 'Bentota Beach Resort',
        'category': 'beach',
        'cost': 80,
        'duration': 3,
        'activities': ['beach', 'spa', 'water_sports'],
        'confidence': 0.6,
        'suggestion_type': 'fallback'
      }
    ];
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
      ],
      'cultural': [
        {
          'name': 'Kandy',
          'cost': 40,
          'duration': 3,
          'activities': ['temple', 'cultural_show', 'lake']
        },
        {
          'name': 'Anuradhapura',
          'cost': 35,
          'duration': 2,
          'activities': ['archaeology', 'temples', 'history']
        },
      ],
      'beach': [
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
      ],
      'nature': [
        {
          'name': 'Yala National Park',
          'cost': 70,
          'duration': 2,
          'activities': ['safari', 'wildlife', 'leopards']
        },
        {
          'name': 'Horton Plains',
          'cost': 40,
          'duration': 1,
          'activities': ['hiking', 'wildlife', 'worlds_end']
        },
      ],
    };
  }

  static Future<void> trackSuggestionInteraction(
    String? userId,
    Map<String, dynamic> suggestion,
    String interactionType,
  ) async {
    try {
      print(
          ' Tracking: User $userId $interactionType ${suggestion['name']} (${suggestion['category']})');

      Map<String, dynamic> interactionData = {
        'user_id': userId,
        'suggestion_id': suggestion['name'],
        'category': suggestion['category'],
        'interaction_type': interactionType,
        'confidence': suggestion['confidence'],
        'timestamp': DateTime.now().millisecondsSinceEpoch,
      };

      await _storeFeedbackData(interactionData);
    } catch (e) {
      print(' Error tracking interaction: $e');
    }
  }

  static Future<void> _storeFeedbackData(Map<String, dynamic> data) async {}

  static double _safeDouble(dynamic value, double defaultValue) {
    if (value == null) return defaultValue;
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is String) {
      try {
        return double.parse(value);
      } catch (e) {
        return defaultValue;
      }
    }
    return defaultValue;
  }
}

//  USER BEHAVIOR TRACKER

class UserBehaviorTracker {
  static String _getUserPrefsKey(String? userId) {
    return 'user_behavior_data_${userId ?? 'anonymous'}';
  }

  String? currentUserId;
  Map<String, int> placeTypeCount = {};
  Map<String, int> seasonalPreferences = {};
  Map<String, double> budgetRange = {};
  List<String> recentPosts = [];
  Map<String, int> activityPreferences = {};

  Map<String, int> climatePreferences = {
    'cold': 0,
    'temperate': 0,
    'tropical': 0,
    'hot': 0,
  };

  UserBehaviorTracker({required this.currentUserId});

  Future<void> loadBehaviorData() async {
    try {
      final prefs = await _getUserBehaviorData();
      if (prefs != null && prefs.isNotEmpty) {
        final data = jsonDecode(prefs);
        placeTypeCount = Map<String, int>.from(data['placeTypeCount'] ?? {});
        seasonalPreferences =
            Map<String, int>.from(data['seasonalPreferences'] ?? {});
        climatePreferences =
            Map<String, int>.from(data['climatePreferences'] ?? {});
        activityPreferences =
            Map<String, int>.from(data['activityPreferences'] ?? {});
        recentPosts = List<String>.from(data['recentPosts'] ?? []);
        budgetRange = Map<String, double>.from(data['budgetRange'] ?? {});

        print(' Loaded behavior data for user: $currentUserId');
        print(
            ' Post count: ${placeTypeCount.values.fold(0, (sum, count) => sum + count)}');
      } else {
        print(
            ' No existing behavior data for user: $currentUserId - starting fresh');
        _initializeDefaultData();
      }
    } catch (e) {
      print(' Error loading behavior data: $e');
      _initializeDefaultData();
    }
  }

  void _initializeDefaultData() {
    placeTypeCount = {};
    seasonalPreferences = {};
    climatePreferences = {
      'cold': 0,
      'temperate': 0,
      'tropical': 0,
      'hot': 0,
    };
    activityPreferences = {};
    budgetRange = {};
    recentPosts = [];
  }

  Future<void> trackPost({
    required String placeName,
    required String cityName,
    required String caption,
    required double estimatedBudget,
  }) async {
    try {
      if (currentUserId == null) {
        print(' No user ID set - cannot track post');
        return;
      }

      String placeType = _analyzePlaceType(placeName, cityName, caption);
      String climate = _analyzeClimate(placeName, cityName, caption);
      String season = _getCurrentSeason();
      List<String> activities = _extractActivities(caption);

      placeTypeCount[placeType] = (placeTypeCount[placeType] ?? 0) + 1;
      climatePreferences[climate] = (climatePreferences[climate] ?? 0) + 1;
      seasonalPreferences[season] = (seasonalPreferences[season] ?? 0) + 1;

      for (String activity in activities) {
        activityPreferences[activity] =
            (activityPreferences[activity] ?? 0) + 1;
      }

      String budgetCategory = _categorizeBudget(estimatedBudget);
      budgetRange[budgetCategory] = (budgetRange[budgetCategory] ?? 0) + 1;

      recentPosts.insert(0, '$placeName|$cityName|$placeType|$climate');
      if (recentPosts.length > 20) {
        recentPosts = recentPosts.take(20).toList();
      }

      await _saveBehaviorData();

      print(
          ' Tracked post for user $currentUserId: $placeType ($climate climate) - Budget: $budgetCategory');
    } catch (e) {
      print(' Error tracking post: $e');
    }
  }

  String _analyzePlaceType(String placeName, String cityName, String caption) {
    String text = '$placeName $cityName $caption'.toLowerCase();

    Map<String, List<String>> typeKeywords = {
      'mountain': [
        'mountain',
        'peak',
        'hill',
        'altitude',
        'hiking',
        'trekking',
        'climb',
        'summit',
        'ella',
        'nuwara eliya',
        'haputale',
        'adams peak',
        'sigiriya'
      ],
      'beach': [
        'beach',
        'coast',
        'ocean',
        'sea',
        'surf',
        'wave',
        'sand',
        'shore',
        'bentota',
        'unawatuna',
        'mirissa',
        'arugam bay',
        'negombo'
      ],
      'cultural': [
        'temple',
        'museum',
        'historic',
        'culture',
        'traditional',
        'heritage',
        'ancient',
        'kandy',
        'anuradhapura',
        'polonnaruwa',
        'dambulla'
      ],
      'nature': [
        'forest',
        'wildlife',
        'park',
        'safari',
        'bird',
        'elephant',
        'leopard',
        'rainforest',
        'yala',
        'udawalawe',
        'sinharaja',
        'horton plains'
      ],
      'urban': [
        'city',
        'shopping',
        'mall',
        'restaurant',
        'nightlife',
        'modern',
        'colombo',
        'galle fort'
      ],
      'adventure': [
        'adventure',
        'extreme',
        'zip',
        'rafting',
        'rock',
        'cave',
        'waterfall'
      ],
      'relaxation': [
        'spa',
        'relax',
        'peaceful',
        'quiet',
        'meditation',
        'resort',
        'luxury'
      ],
      'food': [
        'food',
        'restaurant',
        'cuisine',
        'street food',
        'spice',
        'tea',
        'cooking'
      ]
    };

    Map<String, int> scores = {};
    for (String type in typeKeywords.keys) {
      scores[type] = 0;
      for (String keyword in typeKeywords[type]!) {
        if (text.contains(keyword)) {
          scores[type] = scores[type]! + 1;
        }
      }
    }

    String bestType = scores.entries
            .where((entry) => entry.value > 0)
            .fold<MapEntry<String, int>?>(
                null,
                (prev, entry) =>
                    prev == null || entry.value > prev.value ? entry : prev)
            ?.key ??
        'general';

    return bestType;
  }

  String _analyzeClimate(String placeName, String cityName, String caption) {
    String text = '$placeName $cityName $caption'.toLowerCase();

    Map<String, String> locationClimate = {
      'nuwara eliya': 'cold',
      'ella': 'temperate',
      'haputale': 'cold',
      'kandy': 'temperate',
      'colombo': 'tropical',
      'bentota': 'tropical',
      'mirissa': 'tropical',
      'galle': 'tropical',
      'anuradhapura': 'hot',
      'polonnaruwa': 'hot',
      'sigiriya': 'hot',
      'dambulla': 'hot',
      'yala': 'hot',
      'arugam bay': 'tropical',
    };

    for (String location in locationClimate.keys) {
      if (text.contains(location)) {
        return locationClimate[location]!;
      }
    }

    if (text.contains(
        RegExp(r'cold|cool|chilly|tea estate|mountain|hill country'))) {
      return 'cold';
    } else if (text.contains(RegExp(r'hot|desert|dry|arid|sunny'))) {
      return 'hot';
    } else if (text.contains(RegExp(r'beach|coastal|sea|ocean|tropical'))) {
      return 'tropical';
    } else {
      return 'temperate';
    }
  }

  List<String> _extractActivities(String caption) {
    String text = caption.toLowerCase();
    List<String> activities = [];

    Map<String, List<String>> activityKeywords = {
      'hiking': ['hike', 'hiking', 'trek', 'walking', 'climb'],
      'photography': ['photo', 'picture', 'camera', 'shot', 'capture'],
      'swimming': ['swim', 'swimming', 'dive', 'snorkel'],
      'food_exploration': ['food', 'eat', 'taste', 'delicious', 'cuisine'],
      'cultural_visit': ['temple', 'museum', 'culture', 'traditional'],
      'wildlife_watching': [
        'elephant',
        'leopard',
        'bird',
        'wildlife',
        'safari'
      ],
      'relaxation': ['relax', 'peaceful', 'calm', 'rest', 'spa'],
      'adventure_sports': ['surf', 'zip', 'raft', 'climb', 'adventure']
    };

    for (String activity in activityKeywords.keys) {
      for (String keyword in activityKeywords[activity]!) {
        if (text.contains(keyword)) {
          activities.add(activity);
          break;
        }
      }
    }

    return activities;
  }

  String _getCurrentSeason() {
    int month = DateTime.now().month;
    if (month >= 12 || month <= 2) return 'summer';
    if (month >= 3 && month <= 5) return 'spring';
    if (month >= 6 && month <= 8) return 'monsoon';
    return 'autumn';
  }

  String _categorizeBudget(double budget) {
    if (budget < 50) return 'budget';
    if (budget < 150) return 'moderate';
    if (budget < 300) return 'premium';
    return 'luxury';
  }

  Future<void> _saveBehaviorData() async {
    try {
      if (currentUserId == null) {
        print(' No user ID set - cannot save behavior data');
        return;
      }

      Map<String, dynamic> data = {
        'userId': currentUserId,
        'placeTypeCount': placeTypeCount,
        'seasonalPreferences': seasonalPreferences,
        'climatePreferences': climatePreferences,
        'activityPreferences': activityPreferences,
        'budgetRange': budgetRange,
        'recentPosts': recentPosts,
        'lastUpdated': DateTime.now().millisecondsSinceEpoch,
      };

      await _saveBehaviorDataToPrefs(jsonEncode(data));
      print('💾 Saved behavior data for user: $currentUserId');
    } catch (e) {
      print('❌ Error saving behavior data: $e');
    }
  }

  Map<String, dynamic> getUserPreferences() {
    int totalPosts = placeTypeCount.values.fold(0, (sum, count) => sum + count);

    if (totalPosts == 0) {
      return {
        'user_id': currentUserId,
        'dominant_type': 'general',
        'climate_preference': 'temperate',
        'confidence': 0.0,
        'post_count': 0,
        'is_new_user': true,
      };
    }

    String dominantType = placeTypeCount.entries
            .fold<MapEntry<String, int>?>(
                null,
                (prev, entry) =>
                    prev == null || entry.value > prev.value ? entry : prev)
            ?.key ??
        'general';

    String climatePreference = climatePreferences.entries
            .fold<MapEntry<String, int>?>(
                null,
                (prev, entry) =>
                    prev == null || entry.value > prev.value ? entry : prev)
            ?.key ??
        'temperate';

    double confidence = (placeTypeCount[dominantType] ?? 0) / totalPosts;

    return {
      'user_id': currentUserId,
      'dominant_type': dominantType,
      'climate_preference': climatePreference,
      'confidence': confidence,
      'post_count': totalPosts,
      'type_distribution': placeTypeCount,
      'climate_distribution': climatePreferences,
      'activity_preferences': activityPreferences,
      'is_new_user': false,
    };
  }

  Future<void> _saveBehaviorDataToPrefs(String data) async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setString(_getUserPrefsKey(currentUserId), data);
  }

  Future<String?> _getUserBehaviorData() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    return prefs.getString(_getUserPrefsKey(currentUserId));
  }
}
