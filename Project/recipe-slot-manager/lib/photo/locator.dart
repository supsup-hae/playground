import 'dart:async';

import 'package:flutter/services.dart';
import 'package:recipe_slot_manager/photo/photo_info.dart';

/// 휴대폰 위치 채널. Android `LocationChannel.kt` 가 받는다.
const locationChannel = MethodChannel('recipe_slot_manager/location');

/// 위치와 오차 반경(m).
typedef LocationFix = ({GeoPoint point, double? accuracy});

/// 위치를 받지 못함. [code] 는 `denied`(권한 없음), `disabled`(위치 꺼짐), `timeout`,
/// `unavailable`(받지 못함·기기에서 쓸 수 없음) 또는 그 밖의 플랫폼 오류 코드.
final class LocateException implements Exception {
  const LocateException(this.code, this.message);

  final String code;
  final String message;

  @override
  String toString() => 'LocateException($code): $message';
}

/// 현재 위치를 한 번 받는다.
abstract interface class Locator {
  /// 위치 권한이 있으면 true. 없으면 요청 창을 띄우고 결과를 돌려준다.
  Future<bool> requestAccess();

  /// 받지 못하면 [LocateException].
  Future<LocationFix> current();
}

const _messages = {
  'denied': '위치 권한이 없습니다',
  'disabled': '위치 서비스가 꺼져 있습니다',
  'unavailable': '위치를 받지 못했습니다',
};

/// 기기 위치(Android).
class PlatformLocator implements Locator {
  const PlatformLocator({this.timeout = const Duration(seconds: 15)});

  /// 응답을 기다리는 시간. 넘으면 `timeout`.
  final Duration timeout;

  @override
  Future<bool> requestAccess() async {
    try {
      return await locationChannel.invokeMethod<bool>('requestAccess') ?? false;
    } on PlatformException {
      return false;
    } on MissingPluginException {
      return false;
    }
  }

  @override
  Future<LocationFix> current() async {
    try {
      final result = await locationChannel
          .invokeMapMethod<String, Object?>('current')
          .timeout(timeout);
      if (result case {
        'latitude': final num latitude,
        'longitude': final num longitude,
      }) {
        return (
          point: (
            latitude: latitude.toDouble(),
            longitude: longitude.toDouble(),
          ),
          accuracy: (result['accuracy'] as num?)?.toDouble(),
        );
      }
      throw LocateException('unavailable', _messages['unavailable']!);
    } on PlatformException catch (e) {
      throw LocateException(e.code, _messages[e.code] ?? e.message ?? e.code);
    } on TimeoutException {
      throw const LocateException('timeout', '위치 응답이 없습니다');
    } on MissingPluginException {
      throw const LocateException('unavailable', '이 기기에서는 위치를 받을 수 없습니다');
    }
  }
}
