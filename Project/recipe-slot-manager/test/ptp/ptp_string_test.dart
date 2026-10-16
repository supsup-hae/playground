import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:recipe_slot_manager/ptp/ptp_string.dart';

void main() {
  test('글자 수(널 포함) 뒤에 UTF-16LE 글자와 널을 붙인다', () {
    expect(encodePtpString('AB'), [0x03, 0x41, 0x00, 0x42, 0x00, 0x00, 0x00]);
  });

  test('빈 문자열은 0 한 바이트다', () {
    expect(encodePtpString(''), [0x00]);
  });

  test('바이트를 문자열로 되돌린다', () {
    final bytes = Uint8List.fromList([
      0x03,
      0x41,
      0x00,
      0x42,
      0x00,
      0x00,
      0x00,
    ]);

    expect(decodePtpString(bytes), 'AB');
  });

  test('0 한 바이트는 빈 문자열이다', () {
    expect(decodePtpString(Uint8List.fromList([0x00])), '');
  });

  test('254글자를 넘는 문자열은 ArgumentError 를 던진다', () {
    expect(encodePtpString('a' * 254).first, 255);
    expect(() => encodePtpString('a' * 255), throwsArgumentError);
  });

  test('한글 이름도 왕복 변환된다', () {
    expect(decodePtpString(encodePtpString('야간 거리')), '야간 거리');
  });

  test('글자 수가 바이트 길이를 넘으면 FormatException 을 던진다', () {
    final bytes = Uint8List.fromList([0x05, 0x41, 0x00]);

    expect(() => decodePtpString(bytes), throwsFormatException);
  });
}
