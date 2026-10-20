import 'package:recipe_slot_manager/photo/locator.dart';

/// [fix] 를 돌려주거나 [failure] 를 던진다. 권한 요청 수를 센다.
class FakeLocator implements Locator {
  FakeLocator({this.fix, this.failure, this.granted = true});

  LocationFix? fix;
  LocateException? failure;
  bool granted;
  var accessRequests = 0;

  @override
  Future<bool> requestAccess() async {
    accessRequests++;
    return granted;
  }

  @override
  Future<LocationFix> current() async {
    if (failure case final failure?) throw failure;
    return fix ?? (throw const LocateException('unavailable', '위치를 받지 못했습니다'));
  }
}
