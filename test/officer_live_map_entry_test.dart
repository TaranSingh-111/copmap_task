import 'package:copmap/data/models/officer_live_map_entry.dart';
import 'package:copmap/data/models/officer_location.dart';
import 'package:copmap/data/models/user_profile.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const profile = UserProfile(id: 'officer-1', role: UserRole.officer);
  const noDuty = null;
  final now = DateTime.utc(2026, 11, 27, 10);

  OfficerLiveMapEntry entryWithLocation(DateTime updatedAt) =>
      OfficerLiveMapEntry(
        officer: profile,
        location: OfficerLocation(
          officerId: profile.id,
          latitude: 28.654137,
          longitude: 77.475693,
          accuracy: 12.1,
          updatedAt: updatedAt,
        ),
        activeDuty: noDuty,
      );

  test('classifies a location younger than two minutes as CURRENT', () {
    final entry = entryWithLocation(now.subtract(const Duration(seconds: 119)));

    expect(entry.locationStatusAt(now), OfficerLocationStatus.current);
  });

  test('classifies a location at the two-minute boundary as STALE', () {
    final entry = entryWithLocation(now.subtract(const Duration(minutes: 2)));

    expect(entry.locationStatusAt(now), OfficerLocationStatus.stale);
  });

  test('classifies an officer without a location as NO LOCATION', () {
    const entry = OfficerLiveMapEntry(
      officer: profile,
      location: null,
      activeDuty: null,
    );

    expect(entry.locationStatusAt(now), OfficerLocationStatus.noLocation);
  });
}
