import 'package:shared_preferences/shared_preferences.dart';

class SharedpreferenceHelper {
  static String userIdKey = "USERKEY";
  static String userNameKey = "USERNAMEKEY";
  static String userEmailKey = "USEREMAILKEY";
  static String userImageKey = "USERIMAGEKEY";
  static String userDisplayNameKey = "USERDISPLAYNAMEKEY";

  // 🎯 NEW: Smart recommendation keys
  static String userBehaviorDataKey = "USER_BEHAVIOR_DATA";
  static String userPreferencesKey = "USER_PREFERENCES";
  static String mlModelConfigKey = "ML_MODEL_CONFIG";
  static String lastSuggestionUpdateKey = "LAST_SUGGESTION_UPDATE";

  // ==================== SAVE METHODS ====================

  // Save user ID
  Future<bool> saveUserId(String getUserId) async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    return prefs.setString(userIdKey, getUserId);
  }

  // Save user name
  Future<bool> saveUserName(String getUserName) async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    return prefs.setString(userNameKey, getUserName);
  }

  // Save user email
  Future<bool> saveUserEmail(String getUserEmail) async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    return prefs.setString(userEmailKey, getUserEmail);
  }

  // Save user profile image
  Future<bool> saveUserImage(String getUserImage) async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    return prefs.setString(userImageKey, getUserImage);
  }

  // Save user display name
  Future<bool> saveUserDisplayName(String getUserDisplayName) async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    return prefs.setString(userDisplayNameKey, getUserDisplayName);
  }

  // ==================== GET METHODS ====================

  // Get user ID
  Future<String?> getUserId() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    return prefs.getString(userIdKey);
  }

  // Get user name
  Future<String?> getUserName() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    return prefs.getString(userNameKey);
  }

  // Get user email
  Future<String?> getUserEmail() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    return prefs.getString(userEmailKey);
  }

  // Get user profile image
  Future<String?> getUserImage() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    return prefs.getString(userImageKey);
  }

  // Get user display name
  Future<String?> getUserDisplayName() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    return prefs.getString(userDisplayNameKey);
  }

  // ==================== UPDATE METHODS ====================

  // Update user ID
  Future<bool> updateUserId(String newUserId) async {
    return await saveUserId(newUserId);
  }

  // Update user name
  Future<bool> updateUserName(String newUserName) async {
    return await saveUserName(newUserName);
  }

  // Update user email
  Future<bool> updateUserEmail(String newUserEmail) async {
    return await saveUserEmail(newUserEmail);
  }

  // Update user profile image
  Future<bool> updateUserImage(String newUserImage) async {
    return await saveUserImage(newUserImage);
  }

  // Update user display name
  Future<bool> updateUserDisplayName(String newUserDisplayName) async {
    return await saveUserDisplayName(newUserDisplayName);
  }

  // Update multiple user profile fields at once
  Future<bool> updateUserProfile({
    String? userId,
    String? name,
    String? email,
    String? image,
    String? displayName,
  }) async {
    bool success = true;

    if (userId != null) {
      success = success && await updateUserId(userId);
    }
    if (name != null) {
      success = success && await updateUserName(name);
    }
    if (email != null) {
      success = success && await updateUserEmail(email);
    }
    if (image != null) {
      success = success && await updateUserImage(image);
    }
    if (displayName != null) {
      success = success && await updateUserDisplayName(displayName);
    }

    return success;
  }

  // ==================== CLEAR METHODS ====================

  // Clear specific user data
  Future<bool> clearUserId() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    return prefs.remove(userIdKey);
  }

  Future<bool> clearUserName() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    return prefs.remove(userNameKey);
  }

  Future<bool> clearUserEmail() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    return prefs.remove(userEmailKey);
  }

  Future<bool> clearUserImage() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    return prefs.remove(userImageKey);
  }

  Future<bool> clearUserDisplayName() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    return prefs.remove(userDisplayNameKey);
  }

  // Clear all user data
  Future<bool> clearUserData() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();

    // Remove all user-related keys
    await prefs.remove(userIdKey);
    await prefs.remove(userNameKey);
    await prefs.remove(userEmailKey);
    await prefs.remove(userImageKey);
    await prefs.remove(userDisplayNameKey);

    // 🎯 NEW: Also clear behavior data when clearing user data
    await prefs.remove(userBehaviorDataKey);
    await prefs.remove(userPreferencesKey);
    await prefs.remove(lastSuggestionUpdateKey);

    return true;
  }

  // ==================== UTILITY METHODS ====================

  // Check if user data exists (for auto-login purposes)
  Future<bool> hasUserData() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    return prefs.containsKey(userIdKey) && prefs.containsKey(userEmailKey);
  }

  // Get all user data at once
  Future<Map<String, String?>> getAllUserData() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();

    return {
      'userId': prefs.getString(userIdKey),
      'userName': prefs.getString(userNameKey),
      'userEmail': prefs.getString(userEmailKey),
      'userImage': prefs.getString(userImageKey),
      'userDisplayName': prefs.getString(userDisplayNameKey),
    };
  }

  // Check if specific user field exists
  Future<bool> hasUserId() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    return prefs.containsKey(userIdKey);
  }

  Future<bool> hasUserName() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    return prefs.containsKey(userNameKey);
  }

  Future<bool> hasUserEmail() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    return prefs.containsKey(userEmailKey);
  }

  Future<bool> hasUserImage() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    return prefs.containsKey(userImageKey);
  }

  Future<bool> hasUserDisplayName() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    return prefs.containsKey(userDisplayNameKey);
  }

  // ==================== BATCH OPERATIONS ====================

  // Save all user data at once
  Future<bool> saveAllUserData({
    required String userId,
    required String userName,
    required String userEmail,
    String? userImage,
    String? userDisplayName,
  }) async {
    bool success = true;

    success = success && await saveUserId(userId);
    success = success && await saveUserName(userName);
    success = success && await saveUserEmail(userEmail);

    if (userImage != null) {
      success = success && await saveUserImage(userImage);
    }
    if (userDisplayName != null) {
      success = success && await saveUserDisplayName(userDisplayName);
    }

    return success;
  }

  // Get user data with default values
  Future<Map<String, String>> getUserDataWithDefaults({
    String defaultUserId = '',
    String defaultUserName = '',
    String defaultUserEmail = '',
    String defaultUserImage = '',
    String defaultUserDisplayName = '',
  }) async {
    SharedPreferences prefs = await SharedPreferences.getInstance();

    return {
      'userId': prefs.getString(userIdKey) ?? defaultUserId,
      'userName': prefs.getString(userNameKey) ?? defaultUserName,
      'userEmail': prefs.getString(userEmailKey) ?? defaultUserEmail,
      'userImage': prefs.getString(userImageKey) ?? defaultUserImage,
      'userDisplayName':
          prefs.getString(userDisplayNameKey) ?? defaultUserDisplayName,
    };
  }

  // ==================== 🎯 NEW: SMART RECOMMENDATION METHODS ====================

  // Save user behavior data (posting patterns, preferences)
  Future<bool> saveBehaviorData(String data) async {
    try {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      return await prefs.setString(userBehaviorDataKey, data);
    } catch (e) {
      print('Error saving behavior data: $e');
      return false;
    }
  }

  // Get user behavior data
  Future<String?> getUserBehaviorData() async {
    try {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      return prefs.getString(userBehaviorDataKey);
    } catch (e) {
      print('Error getting behavior data: $e');
      return null;
    }
  }

  // Save user preferences (computed from behavior analysis)
  Future<bool> saveUserPreferences(String preferences) async {
    try {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      return await prefs.setString(userPreferencesKey, preferences);
    } catch (e) {
      print('Error saving user preferences: $e');
      return false;
    }
  }

  // Get user preferences
  Future<String?> getUserPreferences() async {
    try {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      return prefs.getString(userPreferencesKey);
    } catch (e) {
      print('Error getting user preferences: $e');
      return null;
    }
  }

  // Save ML model configuration
  Future<bool> saveMLModelConfig(String config) async {
    try {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      return await prefs.setString(mlModelConfigKey, config);
    } catch (e) {
      print('Error saving ML model config: $e');
      return false;
    }
  }

  // Get ML model configuration
  Future<String?> getMLModelConfig() async {
    try {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      return prefs.getString(mlModelConfigKey);
    } catch (e) {
      print('Error getting ML model config: $e');
      return null;
    }
  }

  // Save last suggestion update timestamp
  Future<bool> saveLastSuggestionUpdate(int timestamp) async {
    try {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      return await prefs.setInt(lastSuggestionUpdateKey, timestamp);
    } catch (e) {
      print('Error saving last suggestion update: $e');
      return false;
    }
  }

  // Get last suggestion update timestamp
  Future<int?> getLastSuggestionUpdate() async {
    try {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      return prefs.getInt(lastSuggestionUpdateKey);
    } catch (e) {
      print('Error getting last suggestion update: $e');
      return null;
    }
  }

  // ==================== 🎯 NEW: BEHAVIOR TRACKING UTILITIES ====================

  // Check if user has behavior data (has posted before)
  Future<bool> hasBehaviorData() async {
    try {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      return prefs.containsKey(userBehaviorDataKey);
    } catch (e) {
      print('Error checking behavior data: $e');
      return false;
    }
  }

  // Clear behavior data (for privacy or reset)
  Future<bool> clearBehaviorData() async {
    try {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      await prefs.remove(userBehaviorDataKey);
      await prefs.remove(userPreferencesKey);
      await prefs.remove(lastSuggestionUpdateKey);
      return true;
    } catch (e) {
      print('Error clearing behavior data: $e');
      return false;
    }
  }

  // Check if suggestions need refresh (based on timestamp)
  Future<bool> shouldRefreshSuggestions({int cacheHours = 4}) async {
    try {
      int? lastUpdate = await getLastSuggestionUpdate();
      if (lastUpdate == null) return true;

      int currentTime = DateTime.now().millisecondsSinceEpoch;
      int timeDiff = currentTime - lastUpdate;
      int cacheMillis =
          cacheHours * 60 * 60 * 1000; // Convert hours to milliseconds

      return timeDiff > cacheMillis;
    } catch (e) {
      print('Error checking suggestion refresh: $e');
      return true; // Default to refresh if error
    }
  }

  // ==================== 🎯 NEW: PREFERENCE QUICK ACCESS ====================

  // Save quick preference (for frequently accessed data)
  Future<bool> saveQuickPreference(String key, String value) async {
    try {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      return await prefs.setString('quick_$key', value);
    } catch (e) {
      print('Error saving quick preference: $e');
      return false;
    }
  }

  // Get quick preference
  Future<String?> getQuickPreference(String key) async {
    try {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      return prefs.getString('quick_$key');
    } catch (e) {
      print('Error getting quick preference: $e');
      return null;
    }
  }

  // Save user's dominant travel style (adventure, cultural, relaxation, etc.)
  Future<bool> saveDominantTravelStyle(String style) async {
    return await saveQuickPreference('travel_style', style);
  }

  // Get user's dominant travel style
  Future<String?> getDominantTravelStyle() async {
    return await getQuickPreference('travel_style');
  }

  // Save user's climate preference (cold, tropical, temperate, hot)
  Future<bool> saveClimatePreference(String climate) async {
    return await saveQuickPreference('climate_preference', climate);
  }

  // Get user's climate preference
  Future<String?> getClimatePreference() async {
    return await getQuickPreference('climate_preference');
  }

  // Save user's post count for quick access
  Future<bool> savePostCount(int count) async {
    try {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      return await prefs.setInt('post_count', count);
    } catch (e) {
      print('Error saving post count: $e');
      return false;
    }
  }

  // Get user's post count
  Future<int> getPostCount() async {
    try {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      return prefs.getInt('post_count') ?? 0;
    } catch (e) {
      print('Error getting post count: $e');
      return 0;
    }
  }

  // Increment post count
  Future<bool> incrementPostCount() async {
    try {
      int currentCount = await getPostCount();
      return await savePostCount(currentCount + 1);
    } catch (e) {
      print('Error incrementing post count: $e');
      return false;
    }
  }

  // ==================== 🎯 NEW: ANALYTICS SUPPORT ====================

  // Save suggestion interaction data
  Future<bool> saveSuggestionInteraction(
      Map<String, dynamic> interaction) async {
    try {
      SharedPreferences prefs = await SharedPreferences.getInstance();

      // Get existing interactions
      List<String> interactions =
          prefs.getStringList('suggestion_interactions') ?? [];

      // Add new interaction (keep last 50)
      String interactionJson = interaction.toString();
      interactions.insert(0, interactionJson);
      if (interactions.length > 50) {
        interactions = interactions.take(50).toList();
      }

      return await prefs.setStringList('suggestion_interactions', interactions);
    } catch (e) {
      print('Error saving suggestion interaction: $e');
      return false;
    }
  }

  // Get suggestion interactions for analytics
  Future<List<String>> getSuggestionInteractions() async {
    try {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      return prefs.getStringList('suggestion_interactions') ?? [];
    } catch (e) {
      print('Error getting suggestion interactions: $e');
      return [];
    }
  }

  // ==================== 🎯 NEW: DEBUG AND MAINTENANCE ====================

  // Get all smart recommendation related data (for debugging)
  Future<Map<String, dynamic>> getSmartRecommendationDebugData() async {
    try {
      return {
        'behavior_data': await getUserBehaviorData(),
        'preferences': await getUserPreferences(),
        'ml_config': await getMLModelConfig(),
        'last_update': await getLastSuggestionUpdate(),
        'post_count': await getPostCount(),
        'travel_style': await getDominantTravelStyle(),
        'climate_preference': await getClimatePreference(),
        'has_behavior_data': await hasBehaviorData(),
        'should_refresh': await shouldRefreshSuggestions(),
      };
    } catch (e) {
      print('Error getting debug data: $e');
      return {};
    }
  }

  // Clear all smart recommendation data
  Future<bool> clearAllSmartRecommendationData() async {
    try {
      SharedPreferences prefs = await SharedPreferences.getInstance();

      // Remove all smart recommendation keys
      await prefs.remove(userBehaviorDataKey);
      await prefs.remove(userPreferencesKey);
      await prefs.remove(mlModelConfigKey);
      await prefs.remove(lastSuggestionUpdateKey);
      await prefs.remove('post_count');
      await prefs.remove('quick_travel_style');
      await prefs.remove('quick_climate_preference');
      await prefs.remove('suggestion_interactions');

      return true;
    } catch (e) {
      print('Error clearing smart recommendation data: $e');
      return false;
    }
  }

  // Export user data for backup/transfer
  Future<Map<String, dynamic>> exportUserData() async {
    try {
      Map<String, String?> userData = await getAllUserData();
      Map<String, dynamic> smartData = await getSmartRecommendationDebugData();

      return {
        'user_profile': userData,
        'smart_recommendations': smartData,
        'export_timestamp': DateTime.now().millisecondsSinceEpoch,
        'version': '1.0',
      };
    } catch (e) {
      print('Error exporting user data: $e');
      return {};
    }
  }

  // ==================== 🎯 NEW: PRIVACY CONTROLS ====================

  // Privacy: Clear sensitive behavior data but keep basic preferences
  Future<bool> clearSensitiveBehaviorData() async {
    try {
      SharedPreferences prefs = await SharedPreferences.getInstance();

      // Clear detailed behavior tracking but keep summarized preferences
      await prefs.remove(userBehaviorDataKey);
      await prefs.remove('suggestion_interactions');

      return true;
    } catch (e) {
      print('Error clearing sensitive behavior data: $e');
      return false;
    }
  }

  // Check if user has opted into behavior tracking
  Future<bool> hasBehaviorTrackingConsent() async {
    try {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      return prefs.getBool('behavior_tracking_consent') ?? false;
    } catch (e) {
      print('Error checking behavior tracking consent: $e');
      return false;
    }
  }

  // Save behavior tracking consent
  Future<bool> saveBehaviorTrackingConsent(bool consent) async {
    try {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      return await prefs.setBool('behavior_tracking_consent', consent);
    } catch (e) {
      print('Error saving behavior tracking consent: $e');
      return false;
    }
  }
}
