import 'duty_model.dart';
import 'officer_location.dart';
import 'user_profile.dart';

enum OfficerLocationStatus { current, stale, noLocation }

extension OfficerLocationStatusSortOrder on OfficerLocationStatus {
  int get sortOrder => switch (this) {
        OfficerLocationStatus.current => 0,
        OfficerLocationStatus.stale => 1,
        OfficerLocationStatus.noLocation => 2,
      };
}

class OfficerLiveMapEntry {
  const OfficerLiveMapEntry({
    required this.officer,
    required this.location,
    required this.activeDuty,
  });

  final UserProfile officer;
  final OfficerLocation? location;
  final DutyModel? activeDuty;

  bool get hasLocation => location != null;

  OfficerLocationStatus locationStatusAt(DateTime now) {
    if (!hasLocation) return OfficerLocationStatus.noLocation;
    return isFreshAt(now)
        ? OfficerLocationStatus.current
        : OfficerLocationStatus.stale;
  }

  bool isFreshAt(DateTime now) {
    final value = location;
    if (value == null) return false;
    final age = now.toUtc().difference(value.updatedAt.toUtc());
    return !age.isNegative && age < const Duration(minutes: 2);
  }

  String get displayName {
    final name = officer.fullName?.trim();
    return name == null || name.isEmpty ? 'Officer ${officer.id}' : name;
  }
}
