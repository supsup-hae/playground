/// 넘겨받은 비동기 작업을 들어온 순서대로 하나씩 실행한다. 앞 작업이 실패해도 다음 작업은
/// 실행하고, 실패는 그 작업을 넘긴 쪽에만 전해진다.
class SerialQueue {
  Future<void> _tail = Future.value();

  Future<T> run<T>(Future<T> Function() task) {
    final result = _tail.then((_) => task());
    _tail = result.then<void>((_) {}, onError: (Object _) {});
    return result;
  }
}
