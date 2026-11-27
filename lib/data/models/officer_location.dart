class OfficerLocation {
  const OfficerLocation({
    required this.officerId,
    required this.latitude,
    required this.longitude,
    required this.accuracy,
    required this.updatedAt,
  });

  final String officerId;
  final double latitude;
  final double longitude;
  final double? accuracy;
  final DateTime updatedAt;

  factory OfficerLocation.fromJson(Map<String, dynamic> json) {
    final updatedAtValue = json['updated_at'];
    if (updatedAtValue == null) {
      throw const FormatException('Location updated_at is required.');
    }
    final latitude = json['latitude'];
    final longitude = json['longitude'];
    if (latitude is! num || longitude is! num) {
      throw const FormatException('Location coordinates must be numeric.');
    }
    final accuracy = json['accuracy'];
    return OfficerLocation(
      officerId: json['officer_id'] as String,
      latitude: latitude.toDouble(),
      longitude: longitude.toDouble(),
      accuracy: (accuracy as num?)?.toDouble(),
      updatedAt: DateTime.parse(updatedAtValue.toString()),
    );
  }

  Map<String, dynamic> toJson() => {
        'officer_id': officerId,
        'latitude': latitude,
        'longitude': longitude,
        'accuracy': accuracy,
        'updated_at': updatedAt.toUtc().toIso8601String(),
      };
}
