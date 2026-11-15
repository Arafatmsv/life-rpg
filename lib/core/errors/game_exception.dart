/// A rule violation the player should see (e.g. "not enough Gold").
class GameException implements Exception {
  const GameException(this.message);
  final String message;

  @override
  String toString() => message;
}

/// Unexpected failure of storage, network or a platform service.
class AppException implements Exception {
  const AppException(this.message, [this.cause]);
  final String message;
  final Object? cause;

  @override
  String toString() => cause == null ? message : '$message ($cause)';
}

/// Converts any error into a short message for the UI.
String describeError(Object e) => switch (e) {
      GameException g => g.message,
      AppException a => a.message,
      _ => 'Что-то пошло не так. Попробуйте ещё раз.',
    };
