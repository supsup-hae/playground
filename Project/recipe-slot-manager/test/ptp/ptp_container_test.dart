import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:recipe_slot_manager/ptp/ptp_codes.dart';
import 'package:recipe_slot_manager/ptp/ptp_container.dart';

void main() {
  group('ptpCommand', () {
    test('GetDevicePropValue(0xD18C) 명령을 리틀 엔디언으로 조립한다', () {
      final bytes = ptpCommand(
        PtpOp.getDevicePropValue,
        transactionId: 1,
        params: [FujiProp.presetSlot],
      );

      expect(bytes, [
        0x10, 0x00, 0x00, 0x00, // 길이 16
        0x01, 0x00, // 명령
        0x15, 0x10, // 0x1015
        0x01, 0x00, 0x00, 0x00, // txId 1
        0x8C, 0xD1, 0x00, 0x00, // 0xD18C
      ]);
    });

    test('매개변수가 없으면 길이 12인 머리말만 만든다', () {
      final bytes = ptpCommand(PtpOp.closeSession, transactionId: 7);

      expect(bytes.length, 12);
      expect(bytes.sublist(0, 4), [0x0C, 0x00, 0x00, 0x00]);
      expect(bytes.sublist(8, 12), [0x07, 0x00, 0x00, 0x00]);
    });
  });

  group('ptpResponseCode', () {
    test('응답 컨테이너의 6–7 바이트를 응답 코드로 읽는다', () {
      final response = Uint8List.fromList([
        0x0C, 0x00, 0x00, 0x00, 0x03, 0x00, 0x01, 0x20, //
        0x01, 0x00, 0x00, 0x00,
      ]);

      expect(ptpResponseCode(response), PtpResponse.ok);
    });

    test('12바이트보다 짧은 응답은 FormatException 을 던진다', () {
      final response = Uint8List.fromList([
        0x08,
        0x00,
        0x00,
        0x00,
        0x03,
        0x00,
        0x01,
        0x20,
      ]);

      expect(() => ptpResponseCode(response), throwsFormatException);
    });

    test('타입이 응답(3)이 아니면 FormatException 을 던진다', () {
      final dataContainer = Uint8List.fromList([
        0x0E, 0x00, 0x00, 0x00, 0x02, 0x00, 0x15, 0x10, //
        0x01, 0x00, 0x00, 0x00, 0x11, 0x00,
      ]);

      expect(() => ptpResponseCode(dataContainer), throwsFormatException);
    });
  });
}
