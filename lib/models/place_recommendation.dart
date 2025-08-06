class PlaceRecommendation {
  final String name;
  final String city;
  final String type;
  final double confidence;
  final double cost;
  final int duration;
  final List<String> activities;
  final String? image;
  final double? distance;

  PlaceRecommendation({
    required this.name,
    required this.city,
    required this.type,
    required this.confidence,
    required this.cost,
    required this.duration,
    required this.activities,
    this.image,
    this.distance,
  });

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'city': city,
      'type': type,
      'confidence': confidence,
      'cost': cost,
      'duration': duration,
      'activities': activities,
      'image': image,
      'distance': distance,
    };
  }

  factory PlaceRecommendation.fromJson(Map<String, dynamic> json) {
    return PlaceRecommendation(
      name: json['name'] ?? '',
      city: json['city'] ?? '',
      type: json['type'] ?? '',
      confidence: (json['confidence'] ?? 0.0).toDouble(),
      cost: (json['cost'] ?? 0.0).toDouble(),
      duration: json['duration'] ?? 1,
      activities: List<String>.from(json['activities'] ?? []),
      image: json['image'],
      distance: json['distance']?.toDouble(),
    );
  }
}
