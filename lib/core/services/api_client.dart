/// api_client.dart — Central HTTP client for all EduShare REST calls
///
/// Responsibilities:
///  - Attach BASE_URL from [AppConfig] (single source of truth)
///  - Attach Authorization: Bearer <token> to every authenticated request
///  - Parse the standard {success, data, message} JSON envelope
///  - Map HTTP error codes to typed [AppException] subclasses
///  - Detect 401 globally and trigger session clear + token removal

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:edushare/core/app_config.dart';
import 'package:edushare/core/exceptions/app_exception.dart';
import 'package:edushare/core/services/session_service.dart';

class ApiClient {
  ApiClient._();
  static final ApiClient instance = ApiClient._();

  final _session = SessionService.instance;

  // ─── Header builders ─────────────────────────────────────────────────

  Future<Map<String, String>> _authHeaders() async {
    final token = await _session.getToken();
    return {
      HttpHeaders.contentTypeHeader: 'application/json',
      if (token != null) HttpHeaders.authorizationHeader: 'Bearer $token',
    };
  }

  Map<String, String> get _jsonHeaders => {
        HttpHeaders.contentTypeHeader: 'application/json',
      };

  // ─── Response parser ─────────────────────────────────────────────────

  /// Parses the standard {success, data, message} envelope.
  /// Returns the `data` field on success.
  /// Throws a typed [AppException] on any non-2xx status.
  dynamic _parse(http.Response response) {
    final Map<String, dynamic> body;

    try {
      body = jsonDecode(response.body) as Map<String, dynamic>;
    } catch (_) {
      throw const ServerException('Unexpected server response. Please try again.');
    }

    final statusCode = response.statusCode;

    if (statusCode >= 200 && statusCode < 300) {
      return body['data'];
    }

    final message = body['message'] as String? ?? 'Unknown error';

    switch (statusCode) {
      case 400:
      case 409:
        throw ValidationException(message);
      case 401:
        // Clear session so the app returns to the login screen
        _session.clearAll();
        throw UnauthorizedException(message);
      case 403:
        throw ForbiddenException(message);
      case 404:
        throw NotFoundException(message);
      default:
        throw ServerException(message);
    }
  }

  // ─── HTTP verbs ───────────────────────────────────────────────────────

  Future<dynamic> get(String path, {bool auth = true}) async {
    final headers = auth ? await _authHeaders() : _jsonHeaders;
    try {
      final response = await http
          .get(Uri.parse('${AppConfig.baseUrl}$path'), headers: headers)
          .timeout(AppConfig.requestTimeout);
      return _parse(response);
    } on SocketException {
      throw const NetworkException();
    } on TimeoutException {
      throw const NetworkException('Request timed out. Please try again.');
    } on HttpException {
      throw const NetworkException();
    }
  }

  Future<dynamic> post(String path, Map<String, dynamic> body,
      {bool auth = true}) async {
    final headers = auth ? await _authHeaders() : _jsonHeaders;
    try {
      final response = await http
          .post(
            Uri.parse('${AppConfig.baseUrl}$path'),
            headers: headers,
            body: jsonEncode(body),
          )
          .timeout(AppConfig.requestTimeout);
      return _parse(response);
    } on SocketException {
      throw const NetworkException();
    } on TimeoutException {
      throw const NetworkException('Request timed out. Please try again.');
    } on HttpException {
      throw const NetworkException();
    }
  }

  Future<dynamic> put(String path, Map<String, dynamic> body,
      {bool auth = true}) async {
    final headers = auth ? await _authHeaders() : _jsonHeaders;
    try {
      final response = await http
          .put(
            Uri.parse('${AppConfig.baseUrl}$path'),
            headers: headers,
            body: jsonEncode(body),
          )
          .timeout(AppConfig.requestTimeout);
      return _parse(response);
    } on SocketException {
      throw const NetworkException();
    } on TimeoutException {
      throw const NetworkException('Request timed out. Please try again.');
    } on HttpException {
      throw const NetworkException();
    }
  }

  Future<dynamic> delete(String path, {bool auth = true}) async {
    final headers = auth ? await _authHeaders() : _jsonHeaders;
    try {
      final response = await http
          .delete(Uri.parse('${AppConfig.baseUrl}$path'), headers: headers)
          .timeout(AppConfig.requestTimeout);
      return _parse(response);
    } on SocketException {
      throw const NetworkException();
    } on TimeoutException {
      throw const NetworkException('Request timed out. Please try again.');
    } on HttpException {
      throw const NetworkException();
    }
  }

  Future<dynamic> patch(String path, Map<String, dynamic> body,
      {bool auth = true}) async {
    final headers = auth ? await _authHeaders() : _jsonHeaders;
    try {
      final response = await http
          .patch(
            Uri.parse('${AppConfig.baseUrl}$path'),
            headers: headers,
            body: jsonEncode(body),
          )
          .timeout(AppConfig.requestTimeout);
      return _parse(response);
    } on SocketException {
      throw const NetworkException();
    } on TimeoutException {
      throw const NetworkException('Request timed out. Please try again.');
    } on HttpException {
      throw const NetworkException();
    }
  }

  /// Multipart POST for file uploads using raw bytes.
  /// [bytes] — the file content as Uint8List (always available via FilePicker withData:true).
  /// [fileName] — the original file name (used as Content-Disposition filename).
  /// [fileField] — the multipart field name expected by the server (e.g. 'file').
  /// [fields] — additional text form fields sent alongside the file.
  Future<dynamic> postMultipartBytes(
    String path, {
    required Uint8List bytes,
    required String fileName,
    required String fileField,
    Map<String, String>? fields,
  }) async {
    final token = await _session.getToken();
    final request =
        http.MultipartRequest('POST', Uri.parse('${AppConfig.baseUrl}$path'));

    if (token != null) {
      request.headers[HttpHeaders.authorizationHeader] = 'Bearer $token';
    }

    if (fields != null) request.fields.addAll(fields);

    try {
      request.files.add(
        http.MultipartFile.fromBytes(
          fileField,
          bytes,
          filename: fileName,
          contentType: _getContentType(fileName),
        ),
      );

      final streamedResponse =
          await request.send().timeout(AppConfig.uploadTimeout);
      final response = await http.Response.fromStream(streamedResponse);
      return _parse(response);
    } on SocketException {
      throw const NetworkException();
    } on TimeoutException {
      throw const NetworkException('Upload timed out. Please try again.');
    } catch (e) {
      throw UploadException('Upload failed: ${e.toString()}');
    }
  }

  static MediaType? _getContentType(String fileName) {
    final ext = fileName.toLowerCase().split('.').last;
    switch (ext) {
      case 'pdf':
        return MediaType('application', 'pdf');
      case 'doc':
        return MediaType('application', 'msword');
      case 'docx':
        return MediaType(
          'application',
          'vnd.openxmlformats-officedocument.wordprocessingml.document',
        );
      case 'jpg':
      case 'jpeg':
        return MediaType('image', 'jpeg');
      case 'png':
        return MediaType('image', 'png');
      case 'webp':
        return MediaType('image', 'webp');
      // ─── Video formats ───────────────────────────────────────────────
      case 'mp4':
        return MediaType('video', 'mp4');
      case 'mkv':
        return MediaType('video', 'x-matroska');
      case 'mov':
        return MediaType('video', 'quicktime');
      case 'avi':
        return MediaType('video', 'x-msvideo');
      case 'webm':
        return MediaType('video', 'webm');
      case 'mpeg':
      case 'mpg':
        return MediaType('video', 'mpeg');
      case '3gp':
        return MediaType('video', '3gpp');
      default:
        return MediaType('application', 'octet-stream');
    }
  }
}
