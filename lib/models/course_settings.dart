class CourseLocation {
  final double latitude;
  final double longitude;
  final String? address;

  CourseLocation({
    required this.latitude,
    required this.longitude,
    this.address,
  });

  Map<String, dynamic> toJson() {
    return {
      'latitude': latitude,
      'longitude': longitude,
      'address': address,
    };
  }

  factory CourseLocation.fromJson(Map<String, dynamic> json) {
    return CourseLocation(
      latitude: (json['latitude'] as num).toDouble(),
      longitude: (json['longitude'] as num).toDouble(),
      address: json['address'] as String?,
    );
  }

  CourseLocation copyWith({
    double? latitude,
    double? longitude,
    String? address,
  }) {
    return CourseLocation(
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      address: address ?? this.address,
    );
  }
}

class CourseSettings {
  final CourseLocation? location;
  final List<String>? imageObjectIds;

  CourseSettings({
    this.location,
    this.imageObjectIds,
  });

  Map<String, dynamic> toJson() {
    return {
      'location': location?.toJson(),
      'imageObjectIds': imageObjectIds,
    };
  }

  factory CourseSettings.fromJson(Map<String, dynamic> json) {
    return CourseSettings(
      location: json['location'] != null
          ? CourseLocation.fromJson(json['location'] as Map<String, dynamic>)
          : null,
      imageObjectIds: json['imageObjectIds'] != null
          ? List<String>.from(json['imageObjectIds'] as List)
          : null,
    );
  }

  CourseSettings copyWith({
    CourseLocation? location,
    List<String>? imageObjectIds,
  }) {
    return CourseSettings(
      location: location ?? this.location,
      imageObjectIds: imageObjectIds ?? this.imageObjectIds,
    );
  }
}
