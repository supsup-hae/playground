import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:recipe_slot_manager/photo/photo_indexer.dart';

/// 지금 한 번, 그리고 앱이 다시 앞으로 올 때마다 모든 사진 출처를 읽는다. 바뀐 사진만 읽으므로
/// 새 사진이 없으면 목록만 비교하고 끝난다. 돌려준 리스너를 dispose 하면 멈춘다.
AppLifecycleListener startAutoIndex(PhotoIndexer indexer) {
  unawaited(indexer.indexAll());
  return AppLifecycleListener(onResume: () => unawaited(indexer.indexAll()));
}
