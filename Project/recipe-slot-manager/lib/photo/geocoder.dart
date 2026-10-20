import 'dart:async';

import 'package:flutter/services.dart';
import 'package:recipe_slot_manager/photo/photo_info.dart';
import 'package:recipe_slot_manager/photo/place.dart';

/// 주소 변환 채널. macOS 는 `GeocoderChannel.swift`(CLGeocoder), Android 는
/// `GeocoderChannel.kt`(Geocoder)가 받고, 한국어 지명을 돌려준다.
const geocoderChannel = MethodChannel('recipe_slot_manager/geocoder');

/// 주소 변환 실패. [code] 는 `network`(연결 없음), `throttled`(호출 제한),
/// `unavailable`(기기에서 쓸 수 없음) 또는 그 밖의 플랫폼 오류 코드.
final class GeocodeException implements Exception {
  const GeocodeException(this.code, this.message);

  final String code;
  final String message;

  @override
  String toString() => 'GeocodeException($code): $message';
}

/// 좌표 → 주소 이름.
abstract interface class Geocoder {
  /// 이름이 없는 곳(바다 등)이면 null.
  Future<Place?> reverse(GeoPoint location);
}

/// 기기 내장 주소 변환.
class PlatformGeocoder implements Geocoder {
  const PlatformGeocoder({this.timeout = const Duration(seconds: 15)});

  /// 응답을 기다리는 시간. 넘으면 연결 문제(`network`)로 본다.
  final Duration timeout;

  @override
  Future<Place?> reverse(GeoPoint location) async {
    try {
      final result = await geocoderChannel
          .invokeMapMethod<String, Object?>('reverse', {
            'latitude': location.latitude,
            'longitude': location.longitude,
          })
          .timeout(timeout);
      return result == null ? null : Place.fromJson(result);
    } on PlatformException catch (e) {
      throw GeocodeException(e.code, e.message ?? e.code);
    } on TimeoutException {
      throw const GeocodeException('network', '주소 변환 응답이 없습니다');
    } on MissingPluginException {
      throw const GeocodeException('unavailable', '이 기기에서는 주소 변환을 쓸 수 없습니다');
    }
  }
}
