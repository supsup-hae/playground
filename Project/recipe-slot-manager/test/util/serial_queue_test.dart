import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:recipe_slot_manager/util/serial_queue.dart';

void main() {
  test('앞 작업이 끝난 뒤에 다음 작업을 시작한다', () async {
    final queue = SerialQueue();
    final events = <String>[];
    final gate = Completer<void>();

    final first = queue.run(() async {
      events.add('first start');
      await gate.future;
      events.add('first end');
    });
    final second = queue.run(() async => events.add('second'));
    await Future<void>.delayed(Duration.zero);
    gate.complete();
    await Future.wait([first, second]);

    expect(events, ['first start', 'first end', 'second']);
  });

  test('앞 작업이 실패해도 다음 작업은 실행하고, 실패는 그 작업에만 전한다', () async {
    final queue = SerialQueue();

    final failed = queue.run<void>(() async => throw StateError('boom'));
    final next = queue.run(() async => 'ok');

    await expectLater(failed, throwsStateError);
    expect(await next, 'ok');
  });
}
