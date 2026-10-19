import 'package:flutter/foundation.dart';

import 'registration_data.dart';
import 'registration_repository.dart';

class RegistrationController extends ChangeNotifier {
  RegistrationController(this.repository);
  final RegistrationRepository repository;
  bool busy = false, succeeded = false, _disposed = false;
  String? error;
  Map<String, String> fieldErrors = {};

  void clearFieldError(String field) {
    if (fieldErrors.remove(field) != null) notifyListeners();
  }

  Future<void> submit(RegistrationData data) async {
    if (busy || succeeded) return;
    busy = true;
    error = null;
    fieldErrors = {};
    notifyListeners();
    try {
      await repository.register(data);
      succeeded = true;
    } on RegistrationException catch (e) {
      error = e.message;
      fieldErrors = Map.of(e.fields);
    } catch (_) {
      error = JsonBinRegistrationRepository.uncertain;
    } finally {
      busy = false;
      if (!_disposed) notifyListeners();
    }
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
