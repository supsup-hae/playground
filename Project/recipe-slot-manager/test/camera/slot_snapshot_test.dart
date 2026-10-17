import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:recipe_slot_manager/camera/slot_snapshot.dart';

void main() {
  final snapshot = SlotSnapshot(
    slot: 2,
    name: '야간 거리',
    props: {
      0xD192: Uint8List.fromList([0x11, 0x00]),
      0xD19D: Uint8List.fromList([0xF6, 0xFF]),
      0xD19C: Uint8List.fromList([0x7C, 0x15, 0x00, 0x00]),
    },
  );

  test('속성은 4자리 대문자 코드와 16진 문자열로 JSON에 남는다', () {
    expect(snapshot.toJson(), {
      'slot': 2,
      'name': '야간 거리',
      'props': {'D192': '1100', 'D19D': 'f6ff', 'D19C': '7c150000'},
    });
  });

  test('JSON에서 같은 스냅숏으로 되돌린다', () {
    final restored = SlotSnapshot.fromJson(snapshot.toJson());

    expect(restored.toJson(), snapshot.toJson());
    expect(restored.props[0xD19C], [0x7C, 0x15, 0x00, 0x00]);
  });

  group('fromJson 은 카메라에 쓰면 안 되는 값을 FormatException 으로 거른다', () {
    Map<String, dynamic> json({
      Object? slot = 1,
      Object? name = 'C1',
      Object? props = const {'D192': '1100'},
    }) => {'slot': slot, 'name': name, 'props': props};

    for (final (label, input) in [
      ('홀수 길이 16진수', json(props: {'D192': 'abc'})),
      ('16진수가 아닌 글자', json(props: {'D192': 'zz00'})),
      ('음수 부호', json(props: {'D192': '-100'})),
      ('빈 값', json(props: {'D192': ''})),
      ('레시피 범위 밖 속성 (슬롯 선택)', json(props: {'D18C': '0100'})),
      ('속성 코드가 16진수가 아님', json(props: {'XYZ1': '0100'})),
      ('슬롯 0', json(slot: 0)),
      ('슬롯 8', json(slot: 8)),
      ('슬롯이 문자열', json(slot: '1')),
      ('이름 없음', json(name: null)),
      ('이름이 PTP 문자열 한도를 넘음', json(name: 'a' * 255)),
      ('props 가 목록', json(props: ['1100'])),
    ]) {
      test(label, () {
        expect(() => SlotSnapshot.fromJson(input), throwsFormatException);
      });
    }
  });

  test('props 는 바깥에서 바꿀 수 없다', () {
    expect(() => snapshot.props[0xD18E] = Uint8List(2), throwsUnsupportedError);
  });
}
