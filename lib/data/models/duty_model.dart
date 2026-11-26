enum DutyStatus {
  pending, assigned, inProgress, completed, cancelled;

  String get databaseValue => switch (this) {
    DutyStatus.pending => 'PENDING',
    DutyStatus.assigned => 'ASSIGNED',
    DutyStatus.inProgress => 'IN_PROGRESS',
    DutyStatus.completed => 'COMPLETED',
    DutyStatus.cancelled => 'CANCELLED',
  };

  static DutyStatus fromDatabaseValue(Object? value) {
    final normalized = value?.toString().toUpperCase();
    return DutyStatus.values.firstWhere(
      (status) => status.databaseValue == normalized,
      orElse: () => throw FormatException('Unsupported duty status: $value'),
    );
  }
}

class DutyModel {
  const DutyModel({
    required this.id, required this.title, required this.assignedTo,
    required this.status, this.description, this.locationName, this.latitude,
    this.longitude, this.startTime, this.endTime, this.createdBy,
    this.createdAt, this.updatedAt,
  });

  final String id;
  final String title;
  final String assignedTo;
  final DutyStatus status;
  final String? description;
  final String? locationName;
  final double? latitude;
  final double? longitude;
  final DateTime? startTime;
  final DateTime? endTime;
  final String? createdBy;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  bool get canStart =>
      status == DutyStatus.pending || status == DutyStatus.assigned;
  bool get canComplete => status == DutyStatus.inProgress;

  DutyModel copyWith({DutyStatus? status}) => DutyModel(
    id: id,
    title: title,
    assignedTo: assignedTo,
    status: status ?? this.status,
    description: description,
    locationName: locationName,
    latitude: latitude,
    longitude: longitude,
    startTime: startTime,
    endTime: endTime,
    createdBy: createdBy,
    createdAt: createdAt,
    updatedAt: updatedAt,
  );

  factory DutyModel.fromJson(Map<String, dynamic> json) => DutyModel(
    id: json['id'] as String,
    title: json['title'] as String,
    description: json['description'] as String?,
    locationName: json['location_name'] as String?,
    latitude: (json['latitude'] as num?)?.toDouble(),
    longitude: (json['longitude'] as num?)?.toDouble(),
    assignedTo: json['assigned_to'] as String,
    status: DutyStatus.fromDatabaseValue(json['status']),
    startTime: _parseDateTime(json['start_time']),
    endTime: _parseDateTime(json['end_time']),
    createdBy: json['created_by'] as String?,
    createdAt: _parseDateTime(json['created_at']),
    updatedAt: _parseDateTime(json['updated_at']),
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'description': description,
    'location_name': locationName,
    'latitude': latitude,
    'longitude': longitude,
    'assigned_to': assignedTo,
    'status': status.databaseValue,
    'start_time': startTime?.toIso8601String(),
    'end_time': endTime?.toIso8601String(),
    'created_by': createdBy,
    'created_at': createdAt?.toIso8601String(),
    'updated_at': updatedAt?.toIso8601String(),
  };

  static DateTime? _parseDateTime(Object? value) {
    if (value == null) return null;
    if (value is DateTime) return value;
    return DateTime.parse(value.toString());
  }
}

String formatDutyDateTime(DateTime value) =>
    value.toLocal().toIso8601String().substring(0, 16).replaceFirst('T', ' at ');
