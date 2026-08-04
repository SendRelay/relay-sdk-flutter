/// Base error class for all Relay SDK errors
class RelayError implements Exception {
  /// Error message
  final String message;

  /// Optional underlying cause
  final dynamic cause;

  /// Create a Relay error
  const RelayError(this.message, [this.cause]);

  @override
  String toString() => 'RelayError: $message${cause != null ? ' (cause: $cause)' : ''}';
}

/// Connection-related errors
class ConnectionError extends RelayError {
  /// Create a connection error
  const ConnectionError(super.message, [super.cause]);

  @override
  String toString() => 'ConnectionError: $message${cause != null ? ' (cause: $cause)' : ''}';
}

/// Token-related errors
class TokenError extends RelayError {
  /// Create a token error
  const TokenError(super.message, [super.cause]);

  @override
  String toString() => 'TokenError: $message${cause != null ? ' (cause: $cause)' : ''}';
}
