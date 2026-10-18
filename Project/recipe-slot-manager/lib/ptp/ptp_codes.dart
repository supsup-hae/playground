/// PTP 명령 코드 (ISO 15740).
abstract final class PtpOp {
  static const getDeviceInfo = 0x1001;
  static const openSession = 0x1002;
  static const closeSession = 0x1003;
  static const getObjectHandles = 0x1007;
  static const getObject = 0x1009;
  static const deleteObject = 0x100B;
  static const getDevicePropValue = 0x1015;
  static const setDevicePropValue = 0x1016;
}

/// 후지필름 전용 명령 코드. RAF 를 카메라로 보낼 때 쓴다 (FilmKit `src/ptp/constants.ts`).
abstract final class FujiOp {
  static const sendObjectInfo = 0x900C;
  static const sendObject2 = 0x900D;

  /// RAF 의 ObjectFormat. 다른 값이면 카메라가 응답 없이 무시한다.
  static const rafFormat = 0xF802;
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

  /// RAW 현상 프로필. RAF 를 보낸 뒤에 읽고 쓸 수 있다.
  static const rawProfile = 0xD185;

  /// u16 0 을 쓰면 RAW 현상을 시작한다.
  static const startRawConversion = 0xD183;
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
