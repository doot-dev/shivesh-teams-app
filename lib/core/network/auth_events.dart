import 'dart:async';

/// Broadcasts "the server rejected our token" from the Dio interceptor up to the
/// auth layer.
///
/// The interceptor lives below Riverpod and cannot read providers, so it cannot
/// call logout() directly. It publishes here instead and AuthNotifier listens —
/// which is what makes a revoked or expired 30-day token bounce the technician
/// to the login screen instead of leaving them on a screen that silently fails
/// every request.
class AuthEventBus {
  final _controller = StreamController<String>.broadcast();

  Stream<String> get sessionExpiredStream => _controller.stream;

  void sessionExpired(String message) {
    if (!_controller.isClosed) _controller.add(message);
  }

  void dispose() => _controller.close();
}
