import 'dart:async';

/// Fires when a 401 occurs and the refresh token is also invalid/expired.
/// [AuthNotifier] listens to this stream and forces a proper logout.
final _tokenExpiredController = StreamController<void>.broadcast();

Stream<void> get tokenExpiredEvents => _tokenExpiredController.stream;

void notifyTokenExpired() {
  if (!_tokenExpiredController.isClosed) {
    _tokenExpiredController.add(null);
  }
}
