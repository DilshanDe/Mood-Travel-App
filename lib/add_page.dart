import 'dart:io';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:random_string/random_string.dart';
import 'package:geolocator/geolocator.dart';
import 'package:traveltest_app/services/database.dart';
import 'package:traveltest_app/services/shared_pref.dart';
import 'package:traveltest_app/services/smart_suggestions.dart';
import 'package:traveltest_app/services/ml_service.dart';
import 'package:traveltest_app/services/auto_training_ml_service.dart';
import 'package:traveltest_app/services/model_update_service.dart';

class LocationData {
  final double? latitude;
  final double? longitude;
  final double? accuracy;
  final double? altitude;
  final double? speed;
  final int? timestamp;

  LocationData({
    this.latitude,
    this.longitude,
    this.accuracy,
    this.altitude,
    this.speed,
    this.timestamp,
  });

  factory LocationData.fromPosition(Position position) {
    return LocationData(
      latitude: position.latitude,
      longitude: position.longitude,
      accuracy: position.accuracy,
      altitude: position.altitude,
      speed: position.speed,
      timestamp: position.timestamp.millisecondsSinceEpoch,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'latitude': latitude,
      'longitude': longitude,
      'accuracy': accuracy,
      'altitude': altitude,
      'speed': speed,
      'timestamp': timestamp,
    };
  }
}

class AddPage extends StatefulWidget {
  const AddPage({super.key});

  @override
  State<AddPage> createState() => _AddPageState();
}

class _AddPageState extends State<AddPage> with TickerProviderStateMixin {
  String? name, image, userId;
  bool isLoading = false;
  bool showSuccess = false;

  // ML-related state variables
  bool _isMLInitialized = false;
  bool _isLoadingMLSuggestions = false;
  List<PlaceRecommendation> _mlRecommendations = [];
  LocationData? _currentLocation;
  bool _showMLSuggestions = false;

  // Auto-training related state
  bool _isTrainingActive = false;
  Map<String, dynamic> _trainingStatus = {};

  late AnimationController _animationController;
  late AnimationController _successController;
  late AnimationController _mlSuggestionsController;
  late AnimationController _trainingController;

  late Animation<Offset> _slideAnimation;
  late Animation<double> _successAnimation;
  late Animation<double> _checkAnimation;
  late Animation<Offset> _mlSlideAnimation;
  late Animation<double> _mlFadeAnimation;
  late Animation<double> _trainingPulseAnimation;

  UserBehaviorTracker? _behaviorTracker;

  @override
  void initState() {
    super.initState();

    _animationController = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );
    _successController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    );
    _mlSuggestionsController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );

    _trainingController = AnimationController(
      duration: const Duration(milliseconds: 2000),
      vsync: this,
    );

    _slideAnimation = Tween<Offset>(
      begin: Offset(1.0, 0.0),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOutCubic,
    ));

    _successAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _successController, curve: Curves.elasticOut),
    );

    _checkAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _successController,
        curve: Interval(0.3, 1.0, curve: Curves.easeInOut),
      ),
    );

    _mlSlideAnimation = Tween<Offset>(
      begin: Offset(0.0, -1.0),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _mlSuggestionsController,
      curve: Curves.elasticOut,
    ));

    _mlFadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _mlSuggestionsController, curve: Curves.easeIn),
    );

    _trainingPulseAnimation = Tween<double>(begin: 0.8, end: 1.2).animate(
      CurvedAnimation(parent: _trainingController, curve: Curves.elasticInOut),
    );

    _initializeUserData();
    _initializeMLService();
    _initializeAutoTraining();
    _animationController.forward();
  }

  Future<void> _initializeAutoTraining() async {
    try {
      print(' Initializing Auto-Training Service...');
      await AutoTrainingMLService.initialize();
      _updateTrainingStatus();
      print(' Auto-Training Service initialized successfully!');
    } catch (e) {
      print(' Error initializing Auto-Training Service: $e');
    }
  }

  void _updateTrainingStatus() {
    setState(() {
      _trainingStatus = AutoTrainingMLService.getTrainingStatus();
      _isTrainingActive = _trainingStatus['isTraining'] ?? false;
    });

    if (_isTrainingActive) {
      _trainingController.repeat();
    } else {
      _trainingController.stop();
    }
  }

  Future<void> _initializeMLService() async {
    try {
      print(' Initializing ML Service...');
      await MLService.initializeModel();
      setState(() {
        _isMLInitialized = true;
      });
      print(' ML Service initialized successfully!');

      await _getLocationAndSuggestions();
    } catch (e) {
      print(' Error initializing ML Service: $e');
    }
  }

  Future<void> _getLocationAndSuggestions() async {
    if (!_isMLInitialized) return;

    try {
      print(' Getting location using Geolocator...');

      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        print(' Location service is disabled');
        _showSnackBar('Please enable location service', Colors.orange);
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          print(' Location permission denied');
          _showSnackBar('Location permission is required for AI suggestions',
              Colors.orange);
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        print(' Location permission denied forever');
        _showSnackBar(
            'Please enable location permission in settings', Colors.red);
        return;
      }

      print(' Getting current position...');
      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: Duration(seconds: 10),
      );

      _currentLocation = LocationData.fromPosition(position);

      print(
          ' Location obtained: ${_currentLocation!.latitude}, ${_currentLocation!.longitude}');

      await _getMLRecommendations();
    } catch (e) {
      print(' Error getting location: $e');
      _showSnackBar('Could not get location: $e', Colors.red);
    }
  }

  Future<void> _getMLRecommendations() async {
    if (_currentLocation == null || !_isMLInitialized) return;

    setState(() {
      _isLoadingMLSuggestions = true;
    });

    try {
      String preferredType = 'cultural';
      int preferredBudget = 5000;

      if (_behaviorTracker != null) {
        final prefs = _behaviorTracker!.getUserPreferences();
        preferredType = prefs['dominant_type'] ?? 'cultural';
        preferredBudget = (prefs['avg_budget'] ?? 5000).round();
      }

      print(' Getting ML recommendations...');
      print(
          '    Location: ${_currentLocation!.latitude}, ${_currentLocation!.longitude}');
      print('    Type: $preferredType, Budget: $preferredBudget');

      final recommendations = await MLService.getRecommendations(
        userLat: _currentLocation!.latitude!,
        userLng: _currentLocation!.longitude!,
        budget: preferredBudget,
        travelType: preferredType,
        duration: 3,
      );

      setState(() {
        _mlRecommendations = recommendations.take(5).toList();
        _isLoadingMLSuggestions = false;
      });

      print(' ML Recommendations loaded: ${_mlRecommendations.length} places');

      if (_mlRecommendations.isNotEmpty) {
        print(' Top recommendation: ${_mlRecommendations.first.name}');
      }
    } catch (e) {
      setState(() {
        _isLoadingMLSuggestions = false;
      });
      print(' Error getting ML recommendations: $e');
      _showSnackBar('Could not load AI suggestions: $e', Colors.red);
    }
  }

  void _toggleMLSuggestions() {
    setState(() {
      _showMLSuggestions = !_showMLSuggestions;
    });

    if (_showMLSuggestions) {
      _mlSuggestionsController.forward();
    } else {
      _mlSuggestionsController.reverse();
    }
  }

  Future<void> _initializeUserData() async {
    try {
      name = await SharedpreferenceHelper().getUserName() ?? "";
      image = await SharedpreferenceHelper().getUserImage() ?? "";
      userId = await SharedpreferenceHelper().getUserId() ?? "";

      print('👤 AddPage initialized for user: $userId');

      if (userId != null && userId!.isNotEmpty) {
        _behaviorTracker = UserBehaviorTracker(currentUserId: userId);
        await _behaviorTracker!.loadBehaviorData();
        print(' Behavior tracker loaded for user: $userId');
      } else {
        print(' No user ID found - behavior tracking disabled');
      }

      if (mounted) {
        setState(() {});
      }
    } catch (e) {
      print(' Error initializing user data: $e');
    }
  }

  @override
  void dispose() {
    _animationController.dispose();
    _successController.dispose();
    _mlSuggestionsController.dispose();
    _trainingController.dispose();
    placenamecontroller.dispose();
    citynamecontroller.dispose();
    captioncontroller.dispose();
    budgetcontroller.dispose();
    super.dispose();
  }

  final ImagePicker _picker = ImagePicker();
  File? selectedImage;

  Future<void> getImage() async {
    try {
      showModalBottomSheet(
        context: context,
        backgroundColor: Colors.transparent,
        builder: (context) => Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(25),
              topRight: Radius.circular(25),
            ),
          ),
          child: Wrap(
            children: [
              Container(
                padding: EdgeInsets.all(20),
                child: Column(
                  children: [
                    Container(
                      width: 50,
                      height: 5,
                      decoration: BoxDecoration(
                        color: Colors.grey.shade300,
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    SizedBox(height: 20),
                    Text(
                      "Select Image Source",
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: Colors.grey.shade800,
                      ),
                    ),
                    SizedBox(height: 25),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        _buildImageSourceOption(
                          icon: Icons.photo_library,
                          label: "Gallery",
                          color: Colors.blue,
                          onTap: () async {
                            Navigator.pop(context);
                            var pickedImage = await _picker.pickImage(
                                source: ImageSource.gallery);
                            if (pickedImage != null) {
                              selectedImage = File(pickedImage.path);
                              setState(() {});
                            }
                          },
                        ),
                        _buildImageSourceOption(
                          icon: Icons.camera_alt,
                          label: "Camera",
                          color: Colors.green,
                          onTap: () async {
                            Navigator.pop(context);
                            var pickedImage = await _picker.pickImage(
                                source: ImageSource.camera);
                            if (pickedImage != null) {
                              selectedImage = File(pickedImage.path);
                              setState(() {});
                            }
                          },
                        ),
                      ],
                    ),
                    SizedBox(height: 20),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
    } catch (e) {
      _showSnackBar("Error selecting image: $e", Colors.red);
    }
  }

  Widget _buildImageSourceOption({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.symmetric(vertical: 20, horizontal: 30),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(15),
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 40),
            SizedBox(height: 10),
            Text(
              label,
              style: TextStyle(
                color: color,
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  TextEditingController placenamecontroller = TextEditingController();
  TextEditingController citynamecontroller = TextEditingController();
  TextEditingController captioncontroller = TextEditingController();
  TextEditingController budgetcontroller = TextEditingController();

  void _showSnackBar(String message, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              color == Colors.green ? Icons.check_circle : Icons.error,
              color: Colors.white,
            ),
            SizedBox(width: 10),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        margin: EdgeInsets.all(20),
      ),
    );
  }

  void _showTrainingStatus() {
    Map<String, dynamic> status = AutoTrainingMLService.getTrainingStatus();

    String message;
    Color color;
    IconData icon;

    if (status['needsRetraining'] == true) {
      message = " AI is learning from your post Model will be updated soon.";
      color = Colors.purple;
      icon = Icons.psychology;

      setState(() {
        _isTrainingActive = true;
      });
      _trainingController.repeat();

      Future.delayed(Duration(seconds: 3), () {
        if (mounted) {
          setState(() {
            _isTrainingActive = false;
          });
          _trainingController.stop();
        }
      });
    } else {
      int bufferSize = status['bufferSize'] ?? 0;
      int threshold = status['retrainThreshold'] ?? 10;
      message = " Your place added to AI training ($bufferSize/$threshold)";
      color = Colors.blue;
      icon = Icons.school;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(icon, color: Colors.white),
            SizedBox(width: 10),
            Expanded(child: Text(message)),
            if (status['needsRetraining'] == true) ...[
              SizedBox(width: 10),
              SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              ),
            ],
          ],
        ),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        margin: EdgeInsets.all(20),
        duration: Duration(seconds: 4),
      ),
    );

    _updateTrainingStatus();
  }

  Future<void> uploadPost() async {
    if (selectedImage == null ||
        placenamecontroller.text.trim().isEmpty ||
        citynamecontroller.text.trim().isEmpty ||
        captioncontroller.text.trim().isEmpty) {
      _showSnackBar("All fields must be filled, and an image must be selected.",
          Colors.red);
      return;
    }

    if (userId == null || userId!.isEmpty) {
      _showSnackBar("Please log in to create a post.", Colors.red);
      return;
    }

    setState(() {
      isLoading = true;
    });

    String addId = randomAlphaNumeric(10);
    try {
      Reference firebaseStorageRef =
          FirebaseStorage.instance.ref().child("blogImage").child(addId);

      UploadTask uploadTask = firebaseStorageRef.putFile(selectedImage!);
      TaskSnapshot snapshot = await uploadTask.whenComplete(() => null);
      String downloadUrl = await snapshot.ref.getDownloadURL();

      double estimatedBudget = 100.0;
      try {
        estimatedBudget = double.parse(budgetcontroller.text.trim().isEmpty
            ? "100"
            : budgetcontroller.text.trim());
      } catch (e) {
        estimatedBudget = 100.0;
      }

      Map<String, dynamic> addPost = {
        "Image": downloadUrl,
        "PlaceName": placenamecontroller.text.trim(),
        "CityName": citynamecontroller.text.trim(),
        "Caption": captioncontroller.text.trim(),
        "EstimatedBudget": estimatedBudget,
        "Name": name,
        "UserImage": image,
        "UserId": userId,
        "Like": [],
        "Timestamp": DateTime.now().millisecondsSinceEpoch,
        "UserLocation":
            _currentLocation != null ? _currentLocation!.toMap() : null,
        "MLSuggested": _mlRecommendations
            .any((r) => r.name == placenamecontroller.text.trim()),
      };

      await DatabaseMethods().addPost(addPost, addId);
      await DatabaseMethods()
          .incrementLocationPostCount(citynamecontroller.text.trim());

      await _trackUserBehaviorWithML(estimatedBudget, downloadUrl);

      setState(() {
        isLoading = false;
        showSuccess = true;
      });

      _successController.forward();
      await Future.delayed(Duration(milliseconds: 500));
      _showSuccessDialog();
    } catch (e) {
      setState(() {
        isLoading = false;
      });
      _showSnackBar("Error uploading post: $e", Colors.red);
    }
  }

  Future<void> _trackUserBehaviorWithML(
      double budget, String downloadUrl) async {
    try {
      await EnhancedSuggestionEngine.trackUserPost(
        userId: userId,
        placeName: placenamecontroller.text.trim(),
        cityName: citynamecontroller.text.trim(),
        caption: captioncontroller.text.trim(),
        estimatedBudget: budget,
      );

      if (_currentLocation != null && _isMLInitialized) {
        await _updateMLUserFeedback();
      }

      if (_currentLocation != null) {
        await AutoTrainingMLService.addNewPlaceForTraining(
          placeName: placenamecontroller.text.trim(),
          cityName: citynamecontroller.text.trim(),
          caption: captioncontroller.text.trim(),
          budget: budget,
          userId: userId!,
          userLat: _currentLocation!.latitude!,
          userLng: _currentLocation!.longitude!,
          imageUrl: downloadUrl,
        );

        _showTrainingStatus();
      }

      if (_behaviorTracker != null) {
        await _behaviorTracker!.loadBehaviorData();
        Map<String, dynamic> prefs = _behaviorTracker!.getUserPreferences();

        print(' User Preferences Updated for $userId:');
        print('    Dominant Type: ${prefs['dominant_type']}');
        print('    Climate Preference: ${prefs['climate_preference']}');
        print('    Total Posts: ${prefs['post_count']}');
        print('    Confidence: ${(prefs['confidence'] * 100).toInt()}%');
      }
    } catch (e) {
      print(' Failed to track behavior for user $userId: $e');
    }
  }

  Future<void> _updateMLUserFeedback() async {
    try {
      bool usedMLSuggestion = _mlRecommendations.any((r) =>
          r.name.toLowerCase() ==
          placenamecontroller.text.trim().toLowerCase());

      if (usedMLSuggestion) {
        print(' User used ML suggestion - positive feedback');
      } else {
        print(' User chose different place - learning from preference');
      }
    } catch (e) {
      print(' Error updating ML feedback: $e');
    }
  }

  void _showSuccessDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return Dialog(
          backgroundColor: Colors.transparent,
          child: Container(
            padding: EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: Colors.black26,
                  blurRadius: 10,
                  offset: Offset(0, 5),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                AnimatedBuilder(
                  animation: _successAnimation,
                  builder: (context, child) {
                    return Transform.scale(
                      scale: _successAnimation.value,
                      child: Container(
                        width: 80,
                        height: 80,
                        decoration: BoxDecoration(
                          color: Colors.green,
                          shape: BoxShape.circle,
                        ),
                        child: AnimatedBuilder(
                          animation: _checkAnimation,
                          builder: (context, child) {
                            return Icon(
                              Icons.check,
                              color: Colors.white,
                              size: 50 * _checkAnimation.value,
                            );
                          },
                        ),
                      ),
                    );
                  },
                ),
                SizedBox(height: 25),
                Text(
                  "Post Uploaded Successfully!",
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey.shade800,
                  ),
                  textAlign: TextAlign.center,
                ),
                SizedBox(height: 15),
                Text(
                  "Your travel experience has been shared with the community!",
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey.shade600,
                  ),
                  textAlign: TextAlign.center,
                ),
                if (_trainingStatus.isNotEmpty) ...[
                  SizedBox(height: 15),
                  Container(
                    padding: EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.purple.shade50,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Colors.purple.shade200),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.psychology, color: Colors.purple, size: 20),
                        SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            "AI is learning from your post!",
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.purple.shade700,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                SizedBox(height: 25),
                Row(
                  children: [
                    Expanded(
                      child: TextButton(
                        onPressed: () {
                          Navigator.of(context).pop();
                          _clearForm();
                        },
                        child: Text(
                          "Add Another",
                          style: TextStyle(color: Colors.blue),
                        ),
                      ),
                    ),
                    SizedBox(width: 10),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () {
                          Navigator.of(context).pop();
                          Navigator.of(context).pop();
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                          padding: EdgeInsets.symmetric(vertical: 12),
                        ),
                        child: Text(
                          "View Suggestions",
                          style: TextStyle(color: Colors.white),
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

  void _clearForm() {
    placenamecontroller.clear();
    citynamecontroller.clear();
    captioncontroller.clear();
    budgetcontroller.clear();
    selectedImage = null;
    setState(() {
      showSuccess = false;
    });
    _successController.reset();
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    int maxLines = 1,
    required IconData icon,
    TextInputType? keyboardType,
  }) {
    return SlideTransition(
      position: _slideAnimation,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: Colors.blue, size: 20),
              SizedBox(width: 8),
              Text(
                label,
                style: TextStyle(
                  fontSize: 18.0,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey.shade800,
                ),
              ),
            ],
          ),
          SizedBox(height: 12.0),
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(15),
              border: Border.all(color: Colors.grey.shade300),
              boxShadow: [
                BoxShadow(
                  color: Colors.grey.shade100,
                  blurRadius: 5,
                  offset: Offset(0, 2),
                ),
              ],
            ),
            child: TextField(
              controller: controller,
              maxLines: maxLines,
              keyboardType: keyboardType,
              style: TextStyle(fontSize: 16),
              decoration: InputDecoration(
                filled: true,
                fillColor: Colors.white,
                hintText: hint,
                hintStyle: TextStyle(color: Colors.grey.shade500),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(15),
                  borderSide: BorderSide.none,
                ),
                contentPadding:
                    EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMLSuggestions() {
    if (!_isMLInitialized || _mlRecommendations.isEmpty) {
      return SizedBox.shrink();
    }

    return SlideTransition(
      position: _mlSlideAnimation,
      child: FadeTransition(
        opacity: _mlFadeAnimation,
        child: Container(
          margin: EdgeInsets.all(20),
          height: MediaQuery.of(context).size.height * 0.4,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [Colors.purple.shade50, Colors.blue.shade50],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.purple.shade200),
            boxShadow: [
              BoxShadow(
                color: Colors.purple.shade100,
                blurRadius: 10,
                offset: Offset(0, 5),
              ),
            ],
          ),
          child: Column(
            children: [
              Container(
                padding: EdgeInsets.all(16),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Colors.purple.shade400, Colors.blue.shade400],
                  ),
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(20),
                    topRight: Radius.circular(20),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(Icons.lightbulb, color: Colors.white, size: 20),
                    SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        "AI Suggestions Near You",
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed: _toggleMLSuggestions,
                      icon: Icon(Icons.close, color: Colors.white),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: _isLoadingMLSuggestions
                    ? Container(
                        padding: EdgeInsets.all(20),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            CircularProgressIndicator(),
                            SizedBox(width: 15),
                            Text("Finding perfect places for you"),
                          ],
                        ),
                      )
                    : SingleChildScrollView(
                        physics: BouncingScrollPhysics(),
                        child: Column(
                          children: [
                            ...(_mlRecommendations
                                .take(5)
                                .map((place) => _buildMLSuggestionItem(place))
                                .toList()),
                            Container(
                              margin: EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 8),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      "Showing ${_mlRecommendations.length} nearby recommendations",
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: Colors.purple.shade600,
                                        fontStyle: FontStyle.italic,
                                      ),
                                      textAlign: TextAlign.center,
                                    ),
                                  ),
                                  IconButton(
                                    onPressed: _getLocationAndSuggestions,
                                    icon: Icon(Icons.refresh,
                                        color: Colors.purple.shade600),
                                    tooltip: "Refresh location & suggestions",
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMLSuggestionItem(PlaceRecommendation place) {
    return Container(
      margin: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.shade100,
            blurRadius: 3,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: EdgeInsets.all(12),
        child: Row(
          children: [
            Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    _getTypeColor(place.type),
                    _getTypeColor(place.type).withOpacity(0.7),
                  ],
                ),
                borderRadius: BorderRadius.circular(25),
              ),
              child: Icon(
                _getTypeIcon(place.type),
                color: Colors.white,
                size: 24,
              ),
            ),
            SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    place.name,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey.shade800,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  SizedBox(height: 2),
                  Text(
                    " ${place.city}",
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey.shade600,
                    ),
                  ),
                  SizedBox(height: 2),
                  Text(
                    "AI Suggestion",
                    style: TextStyle(
                      fontSize: 10,
                      color: Colors.purple.shade600,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ],
              ),
            ),
            Container(
              padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: _getConfidenceColor(place.confidence).withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: _getConfidenceColor(place.confidence).withOpacity(0.3),
                ),
              ),
              child: Text(
                "${(place.confidence * 100).round()}%",
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: _getConfidenceColor(place.confidence),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Color _getTypeColor(String type) {
    switch (type.toLowerCase()) {
      case 'beach':
        return Colors.blue;
      case 'cultural':
        return Colors.purple;
      case 'historical':
        return Colors.brown;
      case 'nature':
        return Colors.green;
      case 'adventure':
        return Colors.orange;
      case 'religious':
        return Colors.amber;
      case 'wildlife':
        return Colors.teal;
      case 'scenic':
        return Colors.indigo;
      default:
        return Colors.grey;
    }
  }

  IconData _getTypeIcon(String type) {
    switch (type.toLowerCase()) {
      case 'beach':
        return Icons.beach_access;
      case 'cultural':
        return Icons.museum;
      case 'historical':
        return Icons.account_balance;
      case 'nature':
        return Icons.park;
      case 'adventure':
        return Icons.hiking;
      case 'religious':
        return Icons.temple_hindu;
      case 'wildlife':
        return Icons.pets;
      case 'scenic':
        return Icons.landscape;
      default:
        return Icons.place;
    }
  }

  Color _getConfidenceColor(double confidence) {
    if (confidence >= 0.8) return Colors.green;
    if (confidence >= 0.6) return Colors.orange;
    return Colors.red;
  }

  Widget _buildTrainingStatusIndicator() {
    if (_trainingStatus.isEmpty) return SizedBox.shrink();

    bool isTraining = _trainingStatus['isTraining'] ?? false;
    int bufferSize = _trainingStatus['bufferSize'] ?? 0;
    int threshold = _trainingStatus['retrainThreshold'] ?? 10;

    return AnimatedBuilder(
      animation: _trainingPulseAnimation,
      builder: (context, child) {
        return Container(
          margin: EdgeInsets.symmetric(horizontal: 20, vertical: 4),
          padding: EdgeInsets.all(10),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: isTraining
                  ? [Colors.purple.shade50, Colors.purple.shade100]
                  : [Colors.blue.shade50, Colors.blue.shade100],
            ),
            borderRadius: BorderRadius.circular(15),
            border: Border.all(
                color:
                    isTraining ? Colors.purple.shade200 : Colors.blue.shade200),
          ),
          child: Row(
            children: [
              Transform.scale(
                scale: isTraining ? _trainingPulseAnimation.value : 1.0,
                child: Icon(
                  isTraining ? Icons.psychology : Icons.school,
                  color: isTraining ? Colors.purple : Colors.blue,
                  size: 18,
                ),
              ),
              SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isTraining
                          ? " AI Training in Progress..."
                          : " AI Learning Buffer: $bufferSize/$threshold",
                      style: TextStyle(
                        fontSize: 11,
                        color: isTraining
                            ? Colors.purple.shade700
                            : Colors.blue.shade700,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if (isTraining)
                      Text(
                        "Your contributions are improving the AI model!",
                        style: TextStyle(
                          fontSize: 9,
                          color: Colors.purple.shade600,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                  ],
                ),
              ),
              if (isTraining)
                SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.purple),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      body: SafeArea(
        child: Column(
          children: [
            // Header
            Container(
              padding: EdgeInsets.symmetric(horizontal: 20.0, vertical: 15.0),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Colors.blue.shade600, Colors.blue.shade400],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.only(
                  bottomLeft: Radius.circular(30),
                  bottomRight: Radius.circular(30),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.blue.shade200,
                    blurRadius: 10,
                    offset: Offset(0, 5),
                  ),
                ],
              ),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () {
                      Navigator.pop(context);
                    },
                    child: Container(
                      padding: EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(15),
                      ),
                      child: Icon(
                        Icons.arrow_back_ios_new,
                        color: Colors.white,
                        size: 20,
                      ),
                    ),
                  ),
                  Expanded(
                    child: Center(
                      child: Text(
                        "Create Post",
                        style: TextStyle(
                            color: Colors.white,
                            fontSize: 22.0,
                            fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                  if (_isMLInitialized && _mlRecommendations.isNotEmpty)
                    GestureDetector(
                      onTap: _toggleMLSuggestions,
                      child: Container(
                        padding: EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(15),
                        ),
                        child: Stack(
                          children: [
                            Icon(
                              Icons.lightbulb,
                              color: Colors.white,
                              size: 20,
                            ),
                            Positioned(
                              right: 0,
                              top: 0,
                              child: Container(
                                width: 6,
                                height: 6,
                                decoration: BoxDecoration(
                                  color: Colors.yellow,
                                  shape: BoxShape.circle,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    )
                  else
                    SizedBox(width: 40),
                ],
              ),
            ),

            // Status Indicators
            _buildTrainingStatusIndicator(),

            if (_isMLInitialized)
              Container(
                margin: EdgeInsets.symmetric(horizontal: 20, vertical: 4),
                padding: EdgeInsets.all(10),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Colors.green.shade50, Colors.blue.shade50],
                  ),
                  borderRadius: BorderRadius.circular(15),
                  border: Border.all(color: Colors.green.shade200),
                ),
                child: Row(
                  children: [
                    Icon(Icons.check_circle, color: Colors.green, size: 18),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        " AI Assistant Ready • ${_mlRecommendations.length} places found",
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.green.shade700,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                    if (_mlRecommendations.isNotEmpty)
                      GestureDetector(
                        onTap: _toggleMLSuggestions,
                        child: Container(
                          padding:
                              EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                          decoration: BoxDecoration(
                            color: Colors.blue.shade100,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            "View",
                            style: TextStyle(
                              fontSize: 9,
                              color: Colors.blue.shade700,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),

            // Main Content
            Expanded(
              child: Stack(
                children: [
                  // Form content
                  SingleChildScrollView(
                    physics: BouncingScrollPhysics(),
                    child: Column(
                      children: [
                        // User info card
                        if (name != null && name!.isNotEmpty)
                          Container(
                            margin: EdgeInsets.all(15.0),
                            padding: EdgeInsets.all(15.0),
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [Colors.blue.shade50, Colors.white],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(color: Colors.blue.shade200),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.grey.shade200,
                                  blurRadius: 8,
                                  offset: Offset(0, 3),
                                ),
                              ],
                            ),
                            child: Row(
                              children: [
                                Container(
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(25),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.blue.shade200,
                                        blurRadius: 5,
                                        offset: Offset(0, 2),
                                      ),
                                    ],
                                  ),
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(25),
                                    child: image != null && image!.isNotEmpty
                                        ? Image.network(
                                            image!,
                                            height: 50,
                                            width: 50,
                                            fit: BoxFit.cover,
                                            errorBuilder:
                                                (context, error, stackTrace) {
                                              return Container(
                                                height: 50,
                                                width: 50,
                                                decoration: BoxDecoration(
                                                  gradient: LinearGradient(
                                                    colors: [
                                                      Colors.blue,
                                                      Colors.blue.shade700
                                                    ],
                                                  ),
                                                  borderRadius:
                                                      BorderRadius.circular(25),
                                                ),
                                                child: Icon(Icons.person,
                                                    color: Colors.white,
                                                    size: 25),
                                              );
                                            },
                                          )
                                        : Container(
                                            height: 50,
                                            width: 50,
                                            decoration: BoxDecoration(
                                              gradient: LinearGradient(
                                                colors: [
                                                  Colors.blue,
                                                  Colors.blue.shade700
                                                ],
                                              ),
                                              borderRadius:
                                                  BorderRadius.circular(25),
                                            ),
                                            child: Icon(Icons.person,
                                                color: Colors.white, size: 25),
                                          ),
                                  ),
                                ),
                                SizedBox(width: 15),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        "Posting as:",
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: Colors.grey.shade600,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                      SizedBox(height: 2),
                                      Text(
                                        name!,
                                        style: TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.blue.shade800,
                                        ),
                                      ),
                                      Text(
                                        userId != null
                                            ? "Verified User"
                                            : "Not logged in",
                                        style: TextStyle(
                                          fontSize: 10,
                                          color: userId != null
                                              ? Colors.green.shade600
                                              : Colors.red.shade600,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                Container(
                                  padding: EdgeInsets.all(6),
                                  decoration: BoxDecoration(
                                    color: userId != null
                                        ? Colors.green.shade100
                                        : Colors.red.shade100,
                                    borderRadius: BorderRadius.circular(15),
                                  ),
                                  child: Icon(
                                      userId != null
                                          ? Icons.verified_user
                                          : Icons.warning,
                                      color: userId != null
                                          ? Colors.green
                                          : Colors.red,
                                      size: 16),
                                ),
                              ],
                            ),
                          ),

                        // Image upload section
                        Container(
                          margin: EdgeInsets.symmetric(horizontal: 15),
                          child: GestureDetector(
                            onTap: getImage,
                            child: Container(
                              height: 160,
                              width: double.infinity,
                              margin: EdgeInsets.only(bottom: 20),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                  color: selectedImage != null
                                      ? Colors.blue
                                      : Colors.grey.shade300,
                                  width: 2.0,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.grey.shade200,
                                    blurRadius: 8,
                                    offset: Offset(0, 3),
                                  ),
                                ],
                              ),
                              child: selectedImage != null
                                  ? ClipRRect(
                                      borderRadius: BorderRadius.circular(18),
                                      child: Stack(
                                        children: [
                                          Image.file(
                                            selectedImage!,
                                            height: 160,
                                            width: double.infinity,
                                            fit: BoxFit.cover,
                                          ),
                                          Positioned(
                                            top: 8,
                                            right: 8,
                                            child: GestureDetector(
                                              onTap: () {
                                                setState(() {
                                                  selectedImage = null;
                                                });
                                              },
                                              child: Container(
                                                padding: EdgeInsets.all(6),
                                                decoration: BoxDecoration(
                                                  color: Colors.red,
                                                  shape: BoxShape.circle,
                                                ),
                                                child: Icon(Icons.close,
                                                    color: Colors.white,
                                                    size: 14),
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    )
                                  : Column(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        Container(
                                          padding: EdgeInsets.all(15),
                                          decoration: BoxDecoration(
                                            color: Colors.blue.shade50,
                                            shape: BoxShape.circle,
                                          ),
                                          child: Icon(
                                            Icons.add_a_photo,
                                            size: 30,
                                            color: Colors.blue,
                                          ),
                                        ),
                                        SizedBox(height: 12),
                                        Text(
                                          "Add Photo",
                                          style: TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.w600,
                                            color: Colors.grey.shade700,
                                          ),
                                        ),
                                        SizedBox(height: 6),
                                        Text(
                                          "Tap to select from gallery or camera",
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: Colors.grey.shade500,
                                          ),
                                          textAlign: TextAlign.center,
                                        ),
                                      ],
                                    ),
                            ),
                          ),
                        ),

                        // Form fields
                        Container(
                          margin: EdgeInsets.symmetric(horizontal: 15),
                          child: Column(
                            children: [
                              _buildTextField(
                                controller: placenamecontroller,
                                label: "Place Name",
                                hint: "Enter the place name",
                                icon: Icons.place,
                              ),
                              SizedBox(height: 20.0),
                              _buildTextField(
                                controller: citynamecontroller,
                                label: "City Name",
                                hint: "Enter the city name",
                                icon: Icons.location_city,
                              ),
                              SizedBox(height: 20.0),
                              _buildTextField(
                                controller: budgetcontroller,
                                label: "Estimated Budget",
                                hint: "Enter estimated cost per person",
                                icon: Icons.attach_money,
                                keyboardType: TextInputType.number,
                              ),
                              SizedBox(height: 20.0),
                              _buildTextField(
                                controller: captioncontroller,
                                label: "Caption",
                                hint:
                                    "Share your experience, activities, and feelings...",
                                maxLines: 3,
                                icon: Icons.edit_note,
                              ),
                              SizedBox(height: 25.0),
                            ],
                          ),
                        ),

                        // Upload button
                        Container(
                          margin: EdgeInsets.symmetric(horizontal: 15),
                          width: double.infinity,
                          height: 50,
                          child: ElevatedButton(
                            onPressed: isLoading ? null : uploadPost,
                            style: ElevatedButton.styleFrom(
                              backgroundColor:
                                  isLoading ? Colors.grey : Colors.blue,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(15),
                              ),
                              elevation: isLoading ? 0 : 5,
                              shadowColor: Colors.blue.shade200,
                            ),
                            child: isLoading
                                ? Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      SizedBox(
                                        width: 18,
                                        height: 18,
                                        child: CircularProgressIndicator(
                                          color: Colors.white,
                                          strokeWidth: 2,
                                        ),
                                      ),
                                      SizedBox(width: 12),
                                      Text(
                                        "Uploading...",
                                        style: TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.w600,
                                          color: Colors.white,
                                        ),
                                      ),
                                    ],
                                  )
                                : Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(Icons.publish,
                                          color: Colors.white, size: 20),
                                      SizedBox(width: 8),
                                      Text(
                                        "Share Post",
                                        style: TextStyle(
                                          fontSize: 16.0,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.white,
                                        ),
                                      ),
                                      if (_isMLInitialized) ...[
                                        SizedBox(width: 6),
                                        Container(
                                          padding: EdgeInsets.all(3),
                                          decoration: BoxDecoration(
                                            color:
                                                Colors.white.withOpacity(0.2),
                                            shape: BoxShape.circle,
                                          ),
                                          child: Icon(
                                            Icons.psychology,
                                            color: Colors.white,
                                            size: 14,
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                          ),
                        ),
                        SizedBox(height: 30.0),
                      ],
                    ),
                  ),

                  // ML Suggestions overlay
                  if (_showMLSuggestions) _buildMLSuggestions(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
