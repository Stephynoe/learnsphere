import 'dart:math';

import 'package:http/http.dart' as http;

import '../data/jsonbin_store.dart';
import '../data/jsonbin_stores.dart';
import '../data/user_record.dart';
import 'registration_data.dart';
import '../auth/sign_in_repository.dart';

class RegistrationException implements Exception {
  const RegistrationException(this.message, {this.fields = const {}});
  final String message;
  final Map<String, String> fields;
}

abstract interface class RegistrationRepository {
  Future<void> register(RegistrationData data);
}

class JsonBinRegistrationRepository implements RegistrationRepository {
  JsonBinRegistrationRepository({
    required http.Client client,
    String binId = JsonBinStores.usersBinId,
    String accessKey = const String.fromEnvironment(
      'JSONBIN_USERS_ACCESS_KEY',
      defaultValue: JsonBinStores.sharedAccessKey,
    ),
    String masterKey = const String.fromEnvironment(
      'JSONBIN_USERS_MASTER_KEY',
      defaultValue: JsonBinStores.sharedMasterKey,
    ),
    JsonBinStore? store,
    DateTime Function()? clock,
    this.administrator,
  }) : store =
           store ??
           JsonBinStore(
             client: client,
             binId: binId,
             accessKey: accessKey,
             masterKey: masterKey,
           ),
       clock = clock ?? DateTime.now;
  final JsonBinStore store;
  final DateTime Function() clock;
  final UserSession? administrator;
  static const uncertain =
      'The save could not be confirmed. Check whether your account exists before trying again.';

  @override
  Future<void> register(RegistrationData data) async {
    try {
      final record = await store.read(operation: 'Registration');
      final users = validatedUsers(record);
      if (administrator != null) {
        final matches = users
            .where((u) => u['id'] == administrator!.id)
            .toList();
        if (administrator!.role != AccountRole.admin ||
            matches.length != 1 ||
            matches.single['account_type'] != 'admin' ||
            matches.single['is_active'] != true) {
          throw const RegistrationException(
            'Administrator access is required. Please sign in again.',
          );
        }
        final errors = <String, String?>{
          'full_name': RegistrationValidation.requiredText(data.fullName),
          'email': RegistrationValidation.email(data.email),
          'username': RegistrationValidation.username(data.username),
          'password': RegistrationValidation.password(data.password),
          'question': RegistrationValidation.requiredText(data.question),
          'answer': RegistrationValidation.requiredText(data.answer),
        }..removeWhere((key, value) => value == null);
        if (errors.isNotEmpty) {
          throw RegistrationException(
            'Please update the highlighted fields.',
            fields: errors.map((key, value) => MapEntry(key, value!)),
          );
        }
      }
      final lastId = record['last_id'];
      if (lastId is! int || lastId < 0) {
        throw const RegistrationException(
          'The user record is invalid. No changes were saved. Contact the app administrator.',
        );
      }
      var highest = lastId;
      final fields = <String, String>{};
      for (final user in users) {
        highest = max(highest, user['id'] as int);
        if ((user['email'] as String).trim().toLowerCase() == data.email) {
          fields['email'] = 'This email is already registered.';
        }
        if (administrator != null &&
            (user['username'] as String).trim().toLowerCase() == data.email) {
          fields['email'] = 'This email is already used by another account.';
        }
        if ((user['username'] as String).trim().toLowerCase() ==
            data.username) {
          fields['username'] = 'This username is already taken.';
        }
      }
      if (fields.isNotEmpty) {
        throw RegistrationException(
          'Please update the highlighted fields.',
          fields: fields,
        );
      }
      final nextId = highest + 1;
      record['last_id'] = nextId;
      record['users'] = [...users, data.toUser(nextId, clock())];
      await store.write(
        record,
        operation: 'Registration',
        uncertainMessage: uncertain,
      );
    } on JsonBinException catch (e) {
      throw RegistrationException(e.message);
    }
  }
}
