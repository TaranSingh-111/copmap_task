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

  Map<String, dynamic> toJson() => {
        'officer_id': officerId,
        'latitude': latitude,
        'longitude': longitude,
        'accuracy': accuracy,
        'updated_at': updatedAt.toUtc().toIso8601String(),
      };
}
