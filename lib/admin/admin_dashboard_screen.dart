import '../widgets/brand_logo.dart';
import '../enrollment/enrollment_repository.dart';
import '../enrollment/enrollment_screens.dart';
import 'admin_courses_repository.dart';
import 'admin_courses_screen.dart';

import 'package:flutter/material.dart';

import '../auth/sign_in_repository.dart';
import 'admin_dashboard_controller.dart';
import 'admin_dashboard_repository.dart';
import 'admin_bottom_bar.dart';
import 'admin_learners_repository.dart';
import 'admin_learners_screen.dart';

const _ink = Color(0xFF111C2D);
const _muted = Color(0xFF584237);
const _brown = Color(0xFF9D4300);
const _orange = Color(0xFFF97316);
const _blue = Color(0xFFE7EEFF);

class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({
    super.key,
    required this.repository,
    required this.session,
    required this.onSignOut,
    this.onEditProfile,
    this.enrollmentsRepository,
    this.learnersRepository,
    this.coursesRepository,
    this.onAddLearner,
    this.warning,
  });
  final EnrollmentRepository? enrollmentsRepository;
  final AdminDashboardRepository repository;
  final UserSession session;
  final Future<UserSession> Function(UserSession)? onEditProfile;
  final AdminLearnersRepository? learnersRepository;
  final AdminCoursesRepository? coursesRepository;
  final Future<bool> Function(UserSession)? onAddLearner;
  final VoidCallback onSignOut;
  final String? warning;

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> {
  late UserSession _session = widget.session;
  late final _controller = AdminDashboardController(
    widget.repository,
    enrollmentsRepository: widget.enrollmentsRepository,
    coursesRepository: widget.coursesRepository,
    session: widget.session,
  )..load();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _soon(String feature) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text('$feature: Coming soon')));
  }

  Future<void> _addLearner() async {
    final created = await widget.onAddLearner!(_session);
    if (!mounted || !created) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Learner added successfully')));
    await _controller.load();
  }

  Future<void> _courses({bool create = false, Course? course}) async {
    final repository = widget.coursesRepository;
    if (repository == null) {
      _soon(create ? 'Create Course' : 'Courses');
      return;
    }
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => create || course != null
            ? CourseEditorScreen(
                repository: repository,
                session: _session,
                course: course,
              )
            : AdminCoursesScreen(
                enrollmentsRepository: widget.enrollmentsRepository,
                repository: repository,
                session: _session,
                onNavigate: (destination) {
                  if (destination == AdminDestination.courses) return;
                  Navigator.of(context).pop();
                  if (destination == AdminDestination.more) _account();
                  if (destination == AdminDestination.learners) _learners();
                  if (destination == AdminDestination.enrollments) {
                    _enrollments();
                  }
                },
              ),
      ),
    );
    if (mounted) {
      await Future.wait([
        _controller.loadCourses(),
        _controller.loadEnrollments(),
      ]);
    }
  }

  Future<void> _enrollments() async {
    final repo = widget.enrollmentsRepository;
    if (repo == null) {
      _soon('Enrollments');
      return;
    }
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => EnrollmentScreen(
          repository: repo,
          actor: _session,
          onNavigate: (destination) {
            if (destination == AdminDestination.enrollments) return;
            Navigator.of(context).pop();
            if (destination == AdminDestination.courses) _courses();
            if (destination == AdminDestination.learners) _learners();
            if (destination == AdminDestination.more) _account();
          },
        ),
      ),
    );
    if (mounted) await _controller.loadEnrollments();
  }

  Future<void> _learners() async {
    if (widget.learnersRepository == null) {
      _soon('Learners');
      return;
    }
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => AdminLearnersScreen(
          enrollmentsRepository: widget.enrollmentsRepository,
          onEnrollments: () {
            Navigator.of(context).pop();
            _enrollments();
          },
          repository: widget.learnersRepository!,
          session: _session,
          onAccount: _account,
          onCourses: () {
            Navigator.of(context).pop();
            _courses();
          },
        ),
      ),
    );
    if (mounted) await _controller.loadEnrollments();
  }

  void _account() {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (sheetContext) => SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                _session.fullName,
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 8),
              Text(_session.email),
              const SizedBox(height: 8),
              const Text('Administrator', style: TextStyle(color: _muted)),
              const SizedBox(height: 24),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  if (widget.onEditProfile != null)
                    FilledButton.tonalIcon(
                      style: FilledButton.styleFrom(
                        shape: const StadiumBorder(),
                      ),
                      onPressed: () async {
                        Navigator.of(sheetContext).pop();
                        final updated = await widget.onEditProfile!(_session);
                        if (mounted) setState(() => _session = updated);
                      },
                      icon: const Icon(Icons.edit_outlined),
                      label: const Text('Edit Profile'),
                    ),
                  FilledButton.icon(
                    style: FilledButton.styleFrom(shape: const StadiumBorder()),
                    key: const ValueKey('signout'),
                    onPressed: () {
                      Navigator.of(sheetContext).pop();
                      widget.onSignOut();
                    },
                    icon: const Icon(Icons.logout),
                    label: const Text('Sign Out'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      automaticallyImplyLeading: false,
      toolbarHeight: 72,
      titleSpacing: 16,
      title: Wrap(
        spacing: 8,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              BrandLogo(height: 30),
              Text(
                'LEARNING',
                style: TextStyle(fontSize: 10, letterSpacing: 1),
              ),
            ],
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: const Color(0xFFFFDBCA),
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Text(
              '● Admin Portal',
              style: TextStyle(fontSize: 10, color: _brown),
            ),
          ),
        ],
      ),
      actions: [
        IconButton(
          onPressed: () => _soon('Notifications'),
          tooltip: 'Notifications',
          icon: const Icon(Icons.notifications_outlined),
        ),
        IconButton(
          onPressed: _account,
          tooltip: 'Account',
          icon: const CircleAvatar(
            backgroundColor: _brown,
            radius: 17,
            child: Icon(Icons.person_outline, color: Colors.white, size: 20),
          ),
        ),
        const SizedBox(width: 8),
      ],
    ),
    bottomNavigationBar: AdminBottomBar(
      selected: AdminDestination.dashboard,
      onSelected: (destination) {
        if (destination == AdminDestination.more) {
          _account();
        } else if (destination == AdminDestination.courses) {
          _courses();
        } else if (destination == AdminDestination.learners) {
          _learners();
        } else if (destination == AdminDestination.enrollments) {
          _enrollments();
        } else if (destination != AdminDestination.dashboard) {
          _soon(destination.label);
        }
      },
    ),
    body: SafeArea(
      child: ListenableBuilder(
        listenable: _controller,
        builder: (context, _) => RefreshIndicator(
          onRefresh: _controller.load,
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1100),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.circle, size: 8, color: _orange),
                          const SizedBox(width: 6),
                          const Expanded(
                            child: Text(
                              'PLATFORM PULSE',
                              style: TextStyle(
                                fontSize: 10,
                                color: _muted,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 1,
                              ),
                            ),
                          ),
                          IconButton(
                            key: const ValueKey('dashboard_refresh'),
                            tooltip: 'Refresh dashboard',
                            onPressed: _controller.loading
                                ? null
                                : _controller.load,
                            icon: const Icon(Icons.refresh),
                          ),
                        ],
                      ),
                      const Text(
                        'Admin Workspace',
                        style: TextStyle(
                          fontSize: 26,
                          fontWeight: FontWeight.w800,
                          color: _ink,
                        ),
                      ),
                      const SizedBox(height: 6),
                      const Text(
                        'Overview & platform pulse for Excelerate Learning',
                        style: TextStyle(color: _muted),
                      ),
                      if (widget.warning != null) ...[
                        const SizedBox(height: 12),
                        Text(
                          widget.warning!,
                          style: const TextStyle(color: _muted),
                        ),
                      ],
                      const SizedBox(height: 24),
                      if (_controller.loading) ...[
                        const LinearProgressIndicator(
                          semanticsLabel: 'Loading dashboard',
                        ),
                        const SizedBox(height: 12),
                      ],
                      if (_controller.error != null) ...[
                        _card(
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _controller.error!,
                                style: TextStyle(
                                  color: Theme.of(context).colorScheme.error,
                                ),
                              ),
                              if (_controller.summary != null)
                                const Text(
                                  'Showing the last loaded learner count.',
                                ),
                              TextButton(
                                onPressed: _controller.busy
                                    ? null
                                    : _controller.loadLearners,
                                child: const Text('Retry'),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 12),
                      ],
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: _metric(
                              Icons.menu_book,
                              'Total Courses',
                              _controller.courses?.length.toString() ??
                                  (_controller.coursesBusy
                                      ? 'Loading…'
                                      : 'Unavailable'),
                              warm: true,
                              detail: _controller.courses == null
                                  ? null
                                  : '${_controller.courseCount('Published')} Published · '
                                        '${_controller.courseCount('Draft')} Draft · '
                                        '${_controller.courseCount('Archived')} Archived',
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: _metric(
                              Icons.groups,
                              'Learners',
                              _controller.summary?.learnerCount.toString() ??
                                  (_controller.busy
                                      ? 'Loading…'
                                      : 'Unavailable'),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: _metric(
                              Icons.school,
                              'Enrollments',
                              _controller.enrollmentSnapshot == null
                                  ? 'Not available yet'
                                  : '${_controller.activeEnrollments.length}',
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: _metric(
                              Icons.verified,
                              'Avg Completion',
                              _controller.enrollmentSnapshot == null
                                  ? 'Not available yet'
                                  : _controller.averageCompletion,
                              warm: true,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),
                      const Text(
                        'Quick Actions',
                        style: TextStyle(
                          color: _muted,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 8),
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: [
                            FilledButton.icon(
                              onPressed: () => _courses(create: true),
                              icon: const Icon(Icons.add_circle_outline),
                              label: const Text('Create Course'),
                            ),
                            const SizedBox(width: 8),
                            _action('Add Learner', Icons.person_add_outlined),
                            _action('Review', Icons.pending_actions_outlined),
                            _action('Export', Icons.ios_share),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),
                      _enrollmentTrends(),
                      if (_controller.enrollmentError != null) ...[
                        Text(_controller.enrollmentError!),
                        TextButton(
                          onPressed: _controller.loadEnrollments,
                          child: const Text('Retry enrollments'),
                        ),
                      ],
                      const SizedBox(height: 24),
                      Row(
                        children: [
                          const Expanded(
                            child: Text(
                              'Recent Courses',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                          TextButton(
                            onPressed: () => widget.coursesRepository == null
                                ? _soon('View All')
                                : _courses(),
                            child: const Text('View All'),
                          ),
                        ],
                      ),
                      ..._courseContent(),
                      const SizedBox(height: 24),
                      const Text(
                        'Live Activity',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 12),
                      _enrollmentActivity(),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    ),
  );

  Widget _enrollmentTrends() {
    final data = _controller.enrollmentSnapshot;
    if (data == null) {
      return _empty(
        'Enrollment Trends',
        Icons.bar_chart,
        _controller.enrollmentError ?? 'Enrollment data is unavailable.',
      );
    }
    final now = DateTime.now();
    return _card(
      Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Enrollment Trends • last 6 months',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          for (var i = 5; i >= 0; i--)
            Builder(
              builder: (_) {
                final month = DateTime(now.year, now.month - i);
                final count = data.enrollments.where((e) {
                  final date = DateTime.parse(e.data['enrolled_at'] as String)
                      .toLocal();
                  return date.year == month.year && date.month == month.month;
                }).length;
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    children: [
                      SizedBox(
                        width: 80,
                        child: Text('${month.month}/${month.year}'),
                      ),
                      Expanded(
                        child: LinearProgressIndicator(
                          value:
                              count /
                              (data.enrollments.isEmpty
                                  ? 1
                                  : data.enrollments.length),
                        ),
                      ),
                      SizedBox(
                        width: 40,
                        child: Text('$count', textAlign: TextAlign.end),
                      ),
                    ],
                  ),
                );
              },
            ),
        ],
      ),
    );
  }

  Widget _enrollmentActivity() {
    final data = _controller.enrollmentSnapshot;
    if (data == null) {
      return _empty(
        null,
        Icons.history,
        _controller.enrollmentError ?? 'Enrollment data is unavailable.',
      );
    }
    final entries = [...data.enrollments]
      ..sort(
        (a, b) =>
            '${b.data['updated_at']}'.compareTo('${a.data['updated_at']}'),
      );
    return _card(
      Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (entries.isEmpty) const Text('No enrollment activity yet.'),
          for (final e in entries.take(5))
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(
                '${data.learners[e.learnerId] ?? 'Learner unavailable'} • ${data.course(e.courseId)?.text('title') ?? 'Course unavailable'}',
              ),
              subtitle: Text(
                '${e.status(data.course(e.courseId))} • ${enrollmentDate(e.data['updated_at'])}',
              ),
            ),
        ],
      ),
    );
  }

  Widget _action(String label, IconData icon) => Padding(
    padding: const EdgeInsets.only(right: 8),
    child: TextButton.icon(
      onPressed: label == 'Add Learner' && widget.onAddLearner != null
          ? _addLearner
          : () => _soon(label),
      style: TextButton.styleFrom(
        backgroundColor: Colors.white,
        foregroundColor: _ink,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
      icon: Icon(icon, size: 20),
      label: Text(label),
    ),
  );

  Widget _card(Widget child) => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      boxShadow: const [
        BoxShadow(
          color: Color(0x08000000),
          blurRadius: 8,
          offset: Offset(0, 2),
        ),
      ],
    ),
    child: child,
  );

  List<Widget> _courseContent() => [
    if (_controller.courseError != null)
      _card(
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _controller.courseError!,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
            if (_controller.courses != null)
              const Text('Showing the last loaded course data.'),
            TextButton(
              onPressed: _controller.coursesBusy
                  ? null
                  : _controller.loadCourses,
              child: const Text('Retry courses'),
            ),
          ],
        ),
      ),
    if (_controller.courses == null && _controller.courseError == null)
      _empty(
        null,
        Icons.menu_book_outlined,
        _controller.coursesBusy
            ? 'Loading recent courses…'
            : 'Course data is unavailable.',
      ),
    if (_controller.courses != null && _controller.recentCourses.isEmpty)
      _card(
        Column(
          children: [
            const Icon(Icons.menu_book_outlined, color: _brown, size: 32),
            const SizedBox(height: 12),
            const Text(
              'No recent courses yet. Create a course to get started.',
              textAlign: TextAlign.center,
            ),
            TextButton(
              onPressed: () => _courses(create: true),
              child: const Text('Create Course'),
            ),
          ],
        ),
      ),
    for (final course in _controller.recentCourses)
      Padding(
        padding: const EdgeInsets.only(top: 8),
        child: Semantics(
          button: true,
          child: InkWell(
            key: ValueKey('recent_course_${course.id}'),
            onTap: () => _courses(course: course),
            borderRadius: BorderRadius.circular(16),
            child: _card(
              Row(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: SizedBox(
                      width: 64,
                      height: 64,
                      child: validWebUrl(course.text('thumbnail'))
                          ? Image.network(
                              course.text('thumbnail'),
                              fit: BoxFit.cover,
                              errorBuilder: (_, _, _) => _courseImageFallback(),
                            )
                          : _courseImageFallback(),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          course.text('category'),
                          style: const TextStyle(fontSize: 11, color: _brown),
                        ),
                        if (_controller.enrollmentSnapshot != null)
                          Text(
                            '${_controller.activeEnrollments.where((e) => e.courseId == course.id).length} enrolled',
                          ),
                        const SizedBox(height: 4),
                        Text(
                          course.text('title'),
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          course.text('status'),
                          style: const TextStyle(fontSize: 12, color: _muted),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
  ];

  Widget _courseImageFallback() => const ColoredBox(
    color: _blue,
    child: Icon(Icons.menu_book_outlined, color: _brown),
  );

  Widget _metric(
    IconData icon,
    String label,
    String value, {
    bool warm = false,
    String? detail,
  }) => _card(
    Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        CircleAvatar(
          radius: 18,
          backgroundColor: warm ? const Color(0xFFFFE6D4) : _blue,
          child: Icon(icon, size: 20, color: warm ? _orange : _ink),
        ),
        const SizedBox(height: 16),
        Text(
          value,
          style: TextStyle(
            fontSize: label == 'Learners' ? 24 : 16,
            fontWeight: FontWeight.w800,
            color: _ink,
          ),
        ),
        const SizedBox(height: 4),
        Text(label, style: const TextStyle(fontSize: 12, color: _muted)),
        if (detail != null) ...[
          const SizedBox(height: 8),
          Text(detail, style: const TextStyle(fontSize: 11, color: _muted)),
        ],
      ],
    ),
  );

  Widget _empty(String? title, IconData icon, String message) => _card(
    Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (title != null) ...[
          Text(
            title,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 20),
        ],
        Icon(icon, size: 32, color: _brown),
        const SizedBox(height: 12),
        Text(
          message,
          textAlign: TextAlign.center,
          style: const TextStyle(color: _muted),
        ),
      ],
    ),
  );
}
