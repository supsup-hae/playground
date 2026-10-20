import 'package:flutter_test/flutter_test.dart';
import 'package:recipe_slot_manager/photo/place.dart';

void main() {
  group('placeKey', () {
    test('소수 넷째 자리로 반올림한다', () {
      expect(
        placeKey((latitude: 35.65874, longitude: 139.70046)),
        '35.6587,139.7005',
      );
    });

    test('남위·서경은 음수, 0 근처의 -0 은 0 으로 쓴다', () {
      expect(
        placeKey((latitude: -33.86882, longitude: -0.00001)),
        '-33.8688,0.0000',
      );
    });

    test('가까운 두 좌표(약 5 m)는 같은 키', () {
      expect(
        placeKey((latitude: 35.65871, longitude: 139.70001)),
        placeKey((latitude: 35.65874, longitude: 139.70004)),
      );
    });
  });

  group('Place', () {
    const shibuya = Place(
      country: '일본',
      admin: '도쿄도',
      locality: '시부야구',
      subLocality: '진난',
      thoroughfare: '공원 거리',
    );

    test('label 은 동네·도시·나라 순이고 빈 칸은 건너뛴다', () {
      expect(shibuya.label, '진난, 시부야구, 일본');
      expect(const Place(country: '일본', admin: '도쿄도').label, '도쿄도, 일본');
      expect(const Place().label, '');
    });

    test('모든 칸을 담는 parts 는 나라부터 길까지', () {
      expect(shibuya.parts, ['일본', '도쿄도', '시부야구', '진난', '공원 거리']);
    });

    test('JSON 왕복, 빈 칸은 키를 뺀다', () {
      expect(Place.fromJson(shibuya.toJson()).parts, shibuya.parts);
      expect(const Place(country: '일본').toJson(), {'country': '일본'});
      expect(const Place().isEmpty, isTrue);
    });

    test('형식이 맞지 않으면 FormatException', () {
      expect(() => Place.fromJson({'country': 1}), throwsFormatException);
      expect(() => Place.fromJson(null), throwsFormatException);
    });
  });
}
