import 'package:flutter_test/flutter_test.dart';
import 'package:copmap/data/models/duty_model.dart';

void main() {
  test('nullable duty fields parse without null safety errors', () {
    final duty = DutyModel.fromJson({
      'id': 'duty-1',
      'title': 'Patrol',
      'assigned_to': 'officer-1',
      'status': 'ASSIGNED',
      'description': null,
      'location_name': null,
      'latitude': null,
      'longitude': null,
      'start_time': null,
      'end_time': null,
      'created_by': null,
      'created_at': null,
      'updated_at': null,
    });

    expect(duty.status, DutyStatus.assigned);
    expect(duty.description, isNull);
    expect(duty.locationName, isNull);
    expect(duty.latitude, isNull);
    expect(duty.longitude, isNull);
    expect(duty.startTime, isNull);
    expect(duty.endTime, isNull);
    expect(duty.createdBy, isNull);
    expect(duty.createdAt, isNull);
    expect(duty.updatedAt, isNull);
  });
}
