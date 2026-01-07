import 'package:flutter_test/flutter_test.dart';
import 'package:strayconnected/screens/meeting_requests_page.dart';

void main() {
  group('MeetingItem.fromMap', () {
    test('maps fields and uses first image from JSON list', () {
      final item = MeetingItem.fromMap({
        'meeting_id': 10,
        'status': 'Accepted',
        'date': '2024-09-01',
        'time': '10:30',
        'animal': {
          'name': 'Milo',
          'link_picture':
              '[" https://img.example/a.jpg ", "https://img.example/b.jpg"]',
        },
        'adopter_id': 'adopter-1',
        'rescuer_id': 'rescuer-1',
        'shelter_id': 'shelter-1',
      });

      expect(item.meetingId, 10);
      expect(item.status, 'Accepted');
      expect(item.date, '2024-09-01');
      expect(item.time, '10:30');
      expect(item.animalName, 'Milo');
      expect(item.animalImage, 'https://img.example/a.jpg');
      expect(item.adopterId, 'adopter-1');
      expect(item.rescuerId, 'rescuer-1');
      expect(item.shelterId, 'shelter-1');
    });

    test('uses raw string when image value is not JSON list', () {
      final item = MeetingItem.fromMap({
        'meeting_id': 11,
        'status': 'Pending',
        'date': '2024-10-12',
        'time': '14:00',
        'animal': {
          'name': 'Luna',
          'link_picture': 'https://img.example/only.jpg',
        },
      });

      expect(item.animalName, 'Luna');
      expect(item.animalImage, 'https://img.example/only.jpg');
    });

    test('defaults missing fields safely', () {
      final item = MeetingItem.fromMap({
        'meeting_id': 12,
        'animal': {},
      });

      expect(item.status, 'Pending');
      expect(item.date, '');
      expect(item.time, '');
      expect(item.animalName, null);
      expect(item.animalImage, null);
    });
  });

  test('copyWith overrides only status', () {
    final original = MeetingItem(
      meetingId: 20,
      status: 'Pending',
      date: '2024-11-01',
      time: '09:00',
      animalName: 'Buddy',
      animalImage: 'https://img.example/a.jpg',
      rescuerId: 'rescuer-2',
      shelterId: 'shelter-2',
      adopterId: 'adopter-2',
    );

    final updated = original.copyWith(status: 'Accepted');

    expect(updated.status, 'Accepted');
    expect(updated.meetingId, original.meetingId);
    expect(updated.date, original.date);
    expect(updated.time, original.time);
    expect(updated.animalName, original.animalName);
    expect(updated.animalImage, original.animalImage);
    expect(updated.rescuerId, original.rescuerId);
    expect(updated.shelterId, original.shelterId);
    expect(updated.adopterId, original.adopterId);
  });
}
