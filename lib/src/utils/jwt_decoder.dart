import 'dart:convert';
import '../errors/relay_error.dart';

/// JWT token payload
class JwtPayload {
  /// Subject (developer ID)
  final String? sub;

  /// Scope (allowed resources)
  final List<String>? scope;

  /// Expiration timestamp (Unix seconds)
  final int? exp;

  /// Issued at timestamp (Unix seconds)
  final int? iat;

  /// JWT ID
  final String? jti;

  /// Issuer
  final String? iss;

  /// Audience
  final String? aud;

  /// All claims (including custom fields)
  final Map<String, dynamic> claims;

  /// Create JWT payload
  JwtPayload({
    this.sub,
    this.scope,
    this.exp,
    this.iat,
    this.jti,
    this.iss,
    this.aud,
    required this.claims,
  });

  /// Create from JSON
  factory JwtPayload.fromJson(Map<String, dynamic> json) {
    return JwtPayload(
      sub: json['sub'] as String?,
      scope: json['scope'] != null ? List<String>.from(json['scope'] as List) : null,
      exp: json['exp'] as int?,
      iat: json['iat'] as int?,
      jti: json['jti'] as String?,
      iss: json['iss'] as String?,
      aud: json['aud'] as String?,
      claims: json,
    );
  }

  @override
  String toString() => 'JwtPayload(sub: $sub, exp: $exp, scope: $scope)';
}

/// Parse JWT token without verification
///
/// **WARNING**: This function does NOT verify the token signature.
/// It only decodes the payload for reading claims like expiration.
/// Always validate tokens on your backend before trusting them.
///
/// Throws [TokenError] if the token format is invalid.
///
/// Example:
/// ```dart
/// final payload = parseJwt(token);
/// print('Expires at: ${DateTime.fromMillisecondsSinceEpoch(payload.exp! * 1000)}');
/// print('Scope: ${payload.scope}');
/// ```
JwtPayload parseJwt(String token) {
  try {
    final parts = token.split('.');
    if (parts.length != 3) {
      throw const TokenError('Invalid JWT format: expected 3 parts separated by dots');
    }

    final payload = parts[1];

    // Convert base64url to base64
    var base64 = payload.replaceAll('-', '+').replaceAll('_', '/');

    // Add padding if needed
    switch (base64.length % 4) {
      case 2:
        base64 += '==';
        break;
      case 3:
        base64 += '=';
        break;
    }

    // Decode base64
    final decoded = utf8.decode(base64Decode(base64));

    // Parse JSON
    final json = jsonDecode(decoded) as Map<String, dynamic>;

    return JwtPayload.fromJson(json);
  } catch (error) {
    if (error is TokenError) {
      rethrow;
    }
    throw TokenError('Failed to parse JWT token', error);
  }
}

/// Check if token is expired
///
/// Returns `true` if the token is expired or invalid.
/// Returns `false` if the token has no expiration or is still valid.
///
/// Example:
/// ```dart
/// if (isTokenExpired(token)) {
///   print('Token has expired, refresh needed');
/// }
/// ```
bool isTokenExpired(String token) {
  try {
    final payload = parseJwt(token);
    if (payload.exp == null) {
      return false; // No expiration
    }

    final expiresAt = DateTime.fromMillisecondsSinceEpoch(payload.exp! * 1000);
    return expiresAt.isBefore(DateTime.now());
  } catch (error) {
    return true; // Invalid token is considered expired
  }
}

/// Get time until token expiration
///
/// Returns the duration until the token expires, or `null` if:
/// - The token has no expiration
/// - The token is invalid
/// - The token is already expired (returns [Duration.zero])
///
/// Example:
/// ```dart
/// final timeLeft = getTimeUntilExpiration(token);
/// if (timeLeft != null && timeLeft.inMinutes < 5) {
///   print('Token expires in less than 5 minutes');
/// }
/// ```
Duration? getTimeUntilExpiration(String token) {
  try {
    final payload = parseJwt(token);
    if (payload.exp == null) {
      return null; // No expiration
    }

    final expiresAt = DateTime.fromMillisecondsSinceEpoch(payload.exp! * 1000);
    final now = DateTime.now();

    if (expiresAt.isBefore(now)) {
      return Duration.zero; // Already expired
    }

    return expiresAt.difference(now);
  } catch (error) {
    return null; // Invalid token
  }
}
