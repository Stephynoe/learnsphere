import 'package:flutter/foundation.dart';

import '../auth/sign_in_repository.dart';
import '../data/jsonbin_store.dart';
import '../profile/profile_repository.dart';
import 'admin_learners_repository.dart';

enum LearnerFilter { all, active, inactive }

class AdminLearnersController extends ChangeNotifier {
  AdminLearnersController(this.repository, this.session);
  final AdminLearnersRepository repository;
  final UserSession session;
  List<LearnerSummary>? learners;
  bool busy = false, _disposed = false;
  String? error;
  String query = '';
  LearnerFilter filter = LearnerFilter.all;
  static const pageSizes = [10, 25, 50, 0];
  int _pageSize = 10;
  int _page = 1;
  int get pageSize => _pageSize;
  int get page => _page;
  int get matchingCount => visible.length;
  int get pageCount => matchingCount == 0
      ? 0
      : _pageSize == 0
      ? 1
      : (matchingCount / _pageSize).ceil();
  int get rangeStart => matchingCount == 0
      ? 0
      : _pageSize == 0
      ? 1
      : (_page - 1) * _pageSize + 1;
  int get rangeEnd => matchingCount == 0
      ? 0
      : _pageSize == 0
      ? matchingCount
      : (_page * _pageSize).clamp(0, matchingCount);
  List<LearnerSummary> get pageLearners => _pageSize == 0
      ? visible
      : visible.skip((_page - 1) * _pageSize).take(_pageSize).toList();
  void _clampPage() {
    _page = _page.clamp(1, pageCount == 0 ? 1 : pageCount);
  }

  void setPageSize(int value) {
    if (!pageSizes.contains(value)) return;
    _pageSize = value;
    _page = 1;
    notifyListeners();
  }

  void goToPage(int value) {
    _page = value;
    _clampPage();
    notifyListeners();
  }

  List<LearnerSummary> get visible => (learners ?? []).where((u) {
    final text = query.trim().toLowerCase();
    return (filter == LearnerFilter.all ||
            u.active == (filter == LearnerFilter.active)) &&
        [
          u.name,
          u.email,
          u.username,
          u.organization,
        ].any((v) => v.toLowerCase().contains(text));
  }).toList();
  void search(String value) {
    query = value;
    _page = 1;
    notifyListeners();
  }

  void select(LearnerFilter value) {
    filter = value;
    _page = 1;
    notifyListeners();
  }

  void update(LearnerSummary value) {
    if (_disposed || learners == null) return;
    learners = [
      for (final u in learners!)
        if (u.id == value.id) value else u,
    ];
    learners!.sort((a, b) {
      final order = a.name.toLowerCase().compareTo(b.name.toLowerCase());
      return order == 0 ? a.id.compareTo(b.id) : order;
    });
    _clampPage();
    notifyListeners();
  }

  Future<void> load() async {
    if (busy || _disposed) return;
    busy = true;
    error = null;
    notifyListeners();
    try {
      final result = await repository.listLearners(session);
      if (!_disposed) {
        learners = [...result]
          ..sort((a, b) {
            final order = a.name.toLowerCase().compareTo(b.name.toLowerCase());
            return order == 0 ? a.id.compareTo(b.id) : order;
          });
        _clampPage();
      }
    } catch (e) {
      if (!_disposed) {
        error = e is ProfileException
            ? e.message
            : e is JsonBinException
            ? e.message
            : 'Unable to load learners. Please try again.';
      }
    } finally {
      if (!_disposed) {
        busy = false;
        notifyListeners();
      }
    }
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
