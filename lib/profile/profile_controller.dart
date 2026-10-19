import 'dart:convert';

import 'package:flutter/foundation.dart';

import '../auth/sign_in_repository.dart';
import '../data/jsonbin_store.dart';
import 'profile_repository.dart';

class ProfileController extends ChangeNotifier {
  ProfileController(this.repository, this.session);
  final ProfileRepository repository;
  UserSession session;
  UserProfile? profile;
  String? error;
  Map<String, String> errors = {};
  bool loading = false, saving = false, _disposed = false;
  String? _baseline;
  bool get dirty => profile != null && jsonEncode(profile!.values) != _baseline;
  void _notify() {
    if (!_disposed) notifyListeners();
  }

  void change(String key, dynamic value) {
    if (saving || profile == null) return;
    profile = UserProfile({...profile!.values, key: value});
    errors = {...errors}..remove(key);
    _notify();
  }

  Future<void> load() async {
    if (loading || saving) return;
    loading = true;
    error = null;
    _notify();
    try {
      final result = await repository.load(session);
      if (_disposed) return;
      profile = result;
      _baseline = jsonEncode(result.values);
    } catch (e) {
      error = _message(e);
    } finally {
      loading = false;
      _notify();
    }
  }

  Future<bool> save() async {
    if (saving || loading || profile == null) return false;
    errors = profile!.validate();
    if (errors.isNotEmpty) {
      error = 'Please update the highlighted fields.';
      _notify();
      return false;
    }
    saving = true;
    error = null;
    _notify();
    try {
      final result = await repository.save(session, profile!);
      if (_disposed) return false;
      profile = result;
      session = result.session(session);
      _baseline = jsonEncode(result.values);
      return true;
    } catch (e) {
      error = _message(e);
      if (e is ProfileException) errors = e.fields;
      return false;
    } finally {
      saving = false;
      _notify();
    }
  }

  String _message(Object e) => e is ProfileException
      ? e.message
      : e is JsonBinException
      ? e.message
      : 'Unable to load or save your profile. Please try again.';
  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
