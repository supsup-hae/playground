/// PTP 명령 코드 (ISO 15740).
abstract final class PtpOp {
  static const getDeviceInfo = 0x1001;
  static const openSession = 0x1002;
  static const closeSession = 0x1003;
  static const getDevicePropValue = 0x1015;
  static const setDevicePropValue = 0x1016;
}

/// PTP 응답 코드 (ISO 15740).
abstract final class PtpResponse {
  static const ok = 0x2001;
  static const devicePropNotSupported = 0x200A;
  static const invalidParameter = 0x201D;
  static const sessionAlreadyOpen = 0x201E;
}

/// 후지필름 커스텀 슬롯(C1–C7) 속성 코드.
abstract final class FujiProp {
  /// 1–7을 쓰면 해당 커스텀 슬롯이 선택된다.
  static const presetSlot = 0xD18C;
  static const presetName = 0xD18D;
  static const presetFirst = 0xD18E;
  static const presetLast = 0xD1A5;

  static const slotCount = 7;

  /// 슬롯 하나에 속한 레시피 속성 코드 24개.
  static final presetProps = List<int>.unmodifiable([
    for (var code = presetFirst; code <= presetLast; code++) code,
  ]);

  /// 카메라에 쓰는 순서. 색온도(D19C)는 WB 모드(D199) 바로 뒤, WB 시프트(D19A·D19B)보다
  /// 앞이어야 카메라가 받아들인다. 나머지는 코드 순서다.
  static final writeOrder = List<int>.unmodifiable([
    for (var code = presetFirst; code <= 0xD199; code++) code,
    0xD19C,
    0xD19A,
    0xD19B,
    for (var code = 0xD19D; code <= presetLast; code++) code,
  ]);
}

/// 속성 코드를 `D18E` 같은 4자리 대문자 16진수로 바꾼다.
String propLabel(int code) =>
    code.toRadixString(16).toUpperCase().padLeft(4, '0');
