import '../errors/relay_error.dart';

/// Default Relay WebSocket API path.
const String relayDefaultWebSocketPath = '/v1/realtime/ws';

/// Default Relay WebSocket API URL.
const String relayDefaultWebSocketUrl =
    'https://api.sendrelay.com.ng$relayDefaultWebSocketPath';

/// Build a Relay WebSocket URI with normalized protocol and safe query encoding.
///
/// Normalization rules:
/// - `https` -> `wss`
/// - `http` -> `ws`
/// - removes explicit `:0` port
/// - strips URL fragment (`#...`)
/// - preserves non-empty path (falls back to `/v1` when missing)
Uri buildRelayWebSocketUri({
  required String token,
  String baseUrl = relayDefaultWebSocketUrl,
  String connectionType = 'APP',
  String? deviceId,
  String defaultPath = relayDefaultWebSocketPath,
}) {
  final trimmedBaseUrl = baseUrl.trim();
  if (trimmedBaseUrl.isEmpty) {
    throw const ConnectionError('WebSocket URL cannot be empty');
  }

  final uriWithScheme = _ensureScheme(trimmedBaseUrl);
  final parsed = Uri.parse(uriWithScheme);

  if (parsed.host.isEmpty) {
    throw ConnectionError('Invalid WebSocket URL: missing host in "$baseUrl"');
  }

  final normalizedScheme = _normalizeScheme(parsed.scheme);
  final path = _normalizePath(parsed.path, defaultPath);
  final shouldDropPort = parsed.hasPort && parsed.port == 0;

  final queryParameters = <String, String>{
    ...parsed.queryParameters,
    'token': token,
    'type': connectionType,
    if (deviceId != null && deviceId.isNotEmpty) 'deviceId': deviceId,
  };

  return Uri(
    scheme: normalizedScheme,
    userInfo: parsed.userInfo.isEmpty ? null : parsed.userInfo,
    host: parsed.host,
    port: shouldDropPort ? null : (parsed.hasPort ? parsed.port : null),
    path: path,
    queryParameters: queryParameters,
    fragment: null,
  );
}

String _ensureScheme(String url) {
  if (url.contains('://')) {
    return url;
  }
  return 'wss://$url';
}

String _normalizeScheme(String scheme) {
  switch (scheme.toLowerCase()) {
    case 'wss':
    case 'ws':
      return scheme.toLowerCase();
    case 'https':
      return 'wss';
    case 'http':
      return 'ws';
    default:
      throw ConnectionError(
          'Unsupported URL scheme "$scheme". Use ws:// or wss://.');
  }
}

String _normalizePath(String path, String defaultPath) {
  if (path.isEmpty || path == '/') {
    if (defaultPath.isEmpty) {
      return '';
    }
    return defaultPath.startsWith('/') ? defaultPath : '/$defaultPath';
  }
  return path;
}
