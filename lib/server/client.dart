import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';

import 'config.dart';
import 'dto/billing.dart';
import 'dto/json.dart';
import 'errors.dart';
import 'tokens.dart';

// Every authenticated call to ghostkey-server goes through here.
//
// Each request mints a request id (rid), sends it as `x-request-id`, and logs
// one human-readable line in debug builds with status + duration:
//   [apiFetch] PUT /api/projects/… → 200 in 120ms (rid=k3f9a2)
// The server's request log carries the same rid, so grepping one rid across
// the phone's log and the server's reconstructs the full path of an action.
// A retry after a refresh reuses the rid so both attempts group.

final http.Client _client = http.Client();
final Random _random = Random();

String _newRid() {
  const alphabet = 'abcdefghijklmnopqrstuvwxyz0123456789';
  return List.generate(8, (_) => alphabet[_random.nextInt(alphabet.length)]).join();
}

/// A buffered response: status, headers, and the body decoded on demand.
class ApiResponse {
  const ApiResponse(this.status, this.headers, this.bodyBytes);
  final int status;
  final Map<String, String> headers;
  final Uint8List bodyBytes;

  String get text => utf8.decode(bodyBytes);
  dynamic json() => jsonDecode(text);
  Json jsonObject() => asJson(json());
}

/// One multipart file part.
class ApiFilePart {
  const ApiFilePart({required this.field, required this.filename, required this.bytes, required this.contentType});
  final String field;
  final String filename;
  final Uint8List bytes;
  final String contentType;
}

http.BaseRequest _buildRequest({
  required String method,
  required String path,
  Object? body,
  Map<String, String>? headers,
  Map<String, String>? fields,
  List<ApiFilePart>? files,
  required bool auth,
  required String rid,
}) {
  final url = Uri.parse(path.startsWith('http') ? path : '$serverBaseUrl$path');
  http.BaseRequest request;

  if (files != null || fields != null) {
    final multipart = http.MultipartRequest(method, url);
    if (fields != null) multipart.fields.addAll(fields);
    for (final file in files ?? const <ApiFilePart>[]) {
      multipart.files.add(http.MultipartFile.fromBytes(
        file.field,
        file.bytes,
        filename: file.filename,
        contentType: _mediaType(file.contentType),
      ));
    }
    request = multipart;
  } else {
    final plain = http.Request(method, url);
    if (body != null) {
      if (body is String) {
        plain.body = body;
      } else if (body is Uint8List || body is List<int>) {
        plain.bodyBytes = body is Uint8List ? body : Uint8List.fromList(body as List<int>);
      } else {
        plain.body = jsonEncode(body);
        if (headers == null || !headers.keys.any((k) => k.toLowerCase() == 'content-type')) {
          plain.headers['Content-Type'] = 'application/json';
        }
      }
    }
    request = plain;
  }

  if (headers != null) request.headers.addAll(headers);
  if (auth) {
    final token = getAccessToken();
    if (token != null) request.headers['Authorization'] = 'Bearer $token';
  }
  request.headers['x-request-id'] = rid;
  return request;
}

MediaType? _mediaType(String contentType) {
  try {
    return MediaType.parse(contentType);
  } catch (_) {
    return null;
  }
}

String _pathOf(Uri url) => url.path;

Future<ServerError> _parseError(http.StreamedResponse res, Uri url, String rid) async {
  var code = 'unknown';
  PlanDenial? denial;
  QuotaExceeded? quota;
  var retryAfter = int.tryParse(res.headers['retry-after'] ?? '');
  final rawBody = await res.stream.bytesToString().catchError((_) => '');
  if (rawBody.isNotEmpty) {
    try {
      final data = jsonDecode(rawBody);
      if (data is Map<String, dynamic>) {
        if (data['error'] is String) code = data['error'] as String;
        // A plan refusal names the surface and the plan that opens it; both
        // server-owned strings, carried through so the message can say
        // "Dictation is part of Standard" rather than a generic failure.
        if (code == 'plan_insufficient') denial = PlanDenial.fromJson(data);
        // A spent counter's refusal names the counter and its reset.
        if (code == 'quota_exceeded' && data['feature'] is String) {
          quota = QuotaExceeded.fromJson(data);
        }
        if (data['retry_after'] is num) retryAfter = (data['retry_after'] as num).toInt();
      }
    } catch (_) {
      // body wasn't JSON; keep "unknown"
    }
  }
  if (res.statusCode == 401 && code == 'unknown') code = 'unauthorized';
  if (res.statusCode == 429 && code == 'unknown') code = 'rate_limited';

  final snippet = rawBody.length > 200 ? rawBody.substring(0, 200) : rawBody;
  final detail = '${res.statusCode} ${_pathOf(url)}${snippet.isNotEmpty ? ' — $snippet' : ''}';
  if (kDebugMode) debugPrint('[apiFetch] Request failed with $code: $detail (rid=$rid)');
  return ServerError(code, res.statusCode, detail, denial, retryAfter, quota);
}

Future<http.StreamedResponse> _send(http.BaseRequest request, String rid, {Duration? timeout}) async {
  final started = DateTime.now();
  final method = request.method;
  final path = _pathOf(request.url);
  try {
    var future = _client.send(request);
    if (timeout != null) future = future.timeout(timeout);
    final res = await future;
    if (kDebugMode) {
      final ms = DateTime.now().difference(started).inMilliseconds;
      debugPrint('[apiFetch] $method $path → ${res.statusCode} in ${ms}ms (rid=$rid)');
    }
    return res;
  } on ServerError {
    rethrow;
  } catch (e) {
    if (kDebugMode) {
      final ms = DateTime.now().difference(started).inMilliseconds;
      debugPrint('[apiFetch] $method $path failed after ${ms}ms — $e (rid=$rid)');
    }
    throw ServerError('network_error', 0, '${request.url} — $e');
  }
}

/// The request, sent, with the session's refresh-on-401 retry. Returns the
/// raw streamed response so a caller that reads a body incrementally (the
/// chat turn) can; everyone else goes through [apiFetch].
Future<http.StreamedResponse> apiStream(
  String path, {
  String method = 'GET',
  Object? body,
  Map<String, String>? headers,
  Map<String, String>? fields,
  List<ApiFilePart>? files,
  bool auth = true,
  Duration? timeout,
}) async {
  final rid = _newRid();
  http.BaseRequest build() => _buildRequest(
        method: method,
        path: path,
        body: body,
        headers: headers,
        fields: fields,
        files: files,
        auth: auth,
        rid: rid,
      );

  final first = build();
  final res = await _send(first, rid, timeout: timeout);

  if (res.statusCode != 401 || !auth) {
    if (res.statusCode < 200 || res.statusCode >= 300) throw await _parseError(res, first.url, rid);
    return res;
  }

  // Drain the refused body so the connection is reusable.
  unawaited(res.stream.drain<void>().catchError((_) {}));
  final refreshed = await refreshAccessToken();
  if (refreshed == null) {
    notifyAuthLost();
    throw ServerError('unauthorized', 401, '401 ${_pathOf(first.url)} (rid=$rid)');
  }

  final retry = build();
  final retryRes = await _send(retry, rid, timeout: timeout);
  if (retryRes.statusCode == 401) notifyAuthLost();
  if (retryRes.statusCode < 200 || retryRes.statusCode >= 300) {
    throw await _parseError(retryRes, retry.url, rid);
  }
  return retryRes;
}

/// One buffered call. Throws [ServerError] for anything but a 2xx.
Future<ApiResponse> apiFetch(
  String path, {
  String method = 'GET',
  Object? body,
  Map<String, String>? headers,
  Map<String, String>? fields,
  List<ApiFilePart>? files,
  bool auth = true,
  Duration? timeout,
}) async {
  final res = await apiStream(
    path,
    method: method,
    body: body,
    headers: headers,
    fields: fields,
    files: files,
    auth: auth,
    timeout: timeout,
  );
  final bytes = await res.stream.toBytes();
  return ApiResponse(res.statusCode, res.headers, bytes);
}
