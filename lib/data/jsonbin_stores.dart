import 'package:http/http.dart' as http;

import 'jsonbin_store.dart';

/// Named stores share transport, but each targets its own bin.
class JsonBinStores {
  JsonBinStores({required http.Client client})
    : users = JsonBinStore(
        client: client,
        binId: usersBinId,
        accessKey: const String.fromEnvironment(
          'JSONBIN_USERS_ACCESS_KEY',
          defaultValue: sharedAccessKey,
        ),
        masterKey: const String.fromEnvironment(
          'JSONBIN_USERS_MASTER_KEY',
          defaultValue: sharedMasterKey,
        ),
      ),
      courses = JsonBinStore(
        client: client,
        binId: const String.fromEnvironment('JSONBIN_COURSES_BIN_ID'),
        accessKey: const String.fromEnvironment(
          'JSONBIN_COURSES_ACCESS_KEY',
          defaultValue: sharedAccessKey,
        ),
        masterKey: const String.fromEnvironment(
          'JSONBIN_COURSES_MASTER_KEY',
          defaultValue: sharedMasterKey,
        ),
      ),
      enrollments = JsonBinStore(
        client: client,
        binId: const String.fromEnvironment('JSONBIN_ENROLLMENTS_BIN_ID'),
        accessKey: const String.fromEnvironment(
          'JSONBIN_ENROLLMENTS_ACCESS_KEY',
          defaultValue: sharedAccessKey,
        ),
        masterKey: const String.fromEnvironment(
          'JSONBIN_ENROLLMENTS_MASTER_KEY',
          defaultValue: sharedMasterKey,
        ),
      );

  static const sharedAccessKey = String.fromEnvironment('JSONBIN_ACCESS_KEY');
  static const sharedMasterKey = String.fromEnvironment('JSONBIN_MASTER_KEY');
  static const usersBinId = String.fromEnvironment(
    'JSONBIN_USERS_BIN_ID',
    defaultValue: String.fromEnvironment(
      'JSONBIN_BIN_ID',
      defaultValue: '6ad47a60ac6210605a3b7e6e',
    ),
  );

  final JsonBinStore users, courses, enrollments;
}
