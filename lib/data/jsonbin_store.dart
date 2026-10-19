import 'dart:convert';

import 'package:http/http.dart' as http;

class JsonBinException implements Exception {
  const JsonBinException(this.message);
  final String message;
}

class JsonBinStore {
  JsonBinStore({
    required this.client,
    this.binId = const String.fromEnvironment(
      'JSONBIN_BIN_ID',
      defaultValue: '6ad47a60ac6210605a3b7e6e',
    ),
    this.accessKey = const String.fromEnvironment('JSONBIN_ACCESS_KEY'),
    this.masterKey = const String.fromEnvironment('JSONBIN_MASTER_KEY'),
  });
  final http.Client client;
  final String binId, accessKey, masterKey;
  static const timeout = Duration(seconds: 20);
  static const uncertain =
      'The save could not be confirmed. Check the latest account state before trying again.';

  Map<String, String> _headers(String operation) {
    final master = masterKey.trim().isNotEmpty;
    final key = (master ? masterKey : accessKey).trim();
    if (key.isEmpty || binId.trim().isEmpty) {
      throw JsonBinException(
        '$operation is not configured. Please contact the app administrator.',
      );
    }
    return {
      if (master) 'X-Master-Key': key else 'X-Access-Key': key,
      'Content-Type': 'application/json',
    };
  }

  Future<Map<String, dynamic>> read({required String operation}) async {
    final headers = _headers(operation);
    try {
      final response = await client
          .get(
            Uri.https('api.jsonbin.io', '/v3/b/$binId/latest'),
            headers: headers,
          )
          .timeout(timeout);
      _check(response.statusCode, operation, false);
      final decoded = jsonDecode(response.body);
      if (decoded is! Map<String, dynamic> ||
          decoded['record'] is! Map<String, dynamic>) {
        throw const FormatException();
      }
      final record = Map<String, dynamic>.from(decoded['record'] as Map);
      return record;
    } on JsonBinException {
      rethrow;
    } on FormatException {
      throw const JsonBinException(
        'The bin record is invalid. No changes were saved. Contact the app administrator.',
      );
    } catch (_) {
      throw const JsonBinException(
        'Unable to connect. Check your connection and try again.',
      );
    }
  }

  Future<void> write(
    Map<String, dynamic> record, {
    required String operation,
    String uncertainMessage = uncertain,
  }) async {
    final headers = _headers(operation);
    final body = jsonEncode(record);
    try {
      final response = await client
          .put(
            Uri.https('api.jsonbin.io', '/v3/b/$binId'),
            headers: headers,
            body: body,
          )
          .timeout(timeout);
      _check(response.statusCode, operation, true, uncertainMessage);
    } on JsonBinException {
      rethrow;
    } catch (_) {
      throw JsonBinException(uncertainMessage);
    }
  }

  void _check(
    int status,
    String operation,
    bool writing, [
    String uncertainMessage = uncertain,
  ]) {
    if (status >= 200 && status < 300) return;
    throw JsonBinException(switch (status) {
      401 ||
      403 => '$operation access was denied. Contact the app administrator.',
      429 => '$operation is busy. Please try again later.',
      404 => '$operation store was not found. Contact the app administrator.',
      _ =>
        writing
            ? uncertainMessage
            : 'Unable to load $operation data. Please try again later.',
    });
  }
}
