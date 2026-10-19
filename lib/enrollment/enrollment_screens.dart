import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../admin/admin_courses_repository.dart';
import '../admin/admin_bottom_bar.dart';
import '../auth/sign_in_repository.dart';
import '../data/jsonbin_store.dart';
import 'enrollment_repository.dart';

typedef VideoLauncher = Future<bool> Function(Uri uri);
Future<bool> launchLessonVideo(Uri uri) =>
    launchUrl(uri, mode: LaunchMode.externalApplication);
String enrollmentDate(dynamic value) {
  final date = DateTime.tryParse('$value')?.toLocal();
  return date == null ? '—' : '${date.day}/${date.month}/${date.year}';
}

String enrollmentError(Object e) => e is JsonBinException
    ? e.message
    : 'Unable to load or save enrollments. Please try again.';

Future<bool> confirmWithdrawal(BuildContext context) async =>
    await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Withdraw from this course?'),
        content: const Text(
          'Course access will end. Your progress will be kept if you enroll again.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c, false),
            child: const Text('Keep enrollment'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(c, true),
            child: const Text('Withdraw'),
          ),
        ],
      ),
    ) ??
    false;

/// Shared by My Learning, profiles, and administrator enrollment management.
class EnrollmentPanel extends StatefulWidget {
  const EnrollmentPanel({
    super.key,
    required this.repository,
    required this.actor,
    this.learnerId,
    this.compact = false,
    this.launcher = launchLessonVideo,
    this.onChanged,
  });
  final EnrollmentRepository repository;
  final UserSession actor;
  final int? learnerId;
  final bool compact;
  final VideoLauncher launcher;
  final Future<void> Function()? onChanged;
  @override
  State<EnrollmentPanel> createState() => _EnrollmentPanelState();
}

class _EnrollmentPanelState extends State<EnrollmentPanel> {
  EnrollmentSnapshot? snapshot;
  String? error;
  bool busy = false;
  String query = '', status = '', courseId = '';
  int page = 0;
  bool get admin => widget.actor.role == AccountRole.admin;
  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    setState(() {
      busy = true;
      error = null;
    });
    try {
      final result = await widget.repository.load(widget.actor);
      if (mounted) {
        setState(() {
          snapshot = result;
          if (!result.courses.any((c) => c.id == courseId)) courseId = '';
        });
      }
    } catch (e) {
      if (mounted) setState(() => error = enrollmentError(e));
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> change(Future<void> Function() action) async {
    setState(() {
      busy = true;
      error = null;
    });
    try {
      await action();
      await load();
      await widget.onChanged?.call();
    } catch (e) {
      if (mounted) {
        setState(() {
          error = enrollmentError(e);
          busy = false;
        });
      }
    }
  }

  Future<void> assign() async {
    final data = snapshot!;
    int? learner = widget.learnerId;
    String? course;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialog) => StatefulBuilder(
        builder: (c, update) => AlertDialog(
          title: const Text('Assign course'),
          content: SizedBox(
            width: 420,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (widget.learnerId == null)
                  DropdownButtonFormField<int>(
                    isExpanded: true,
                    decoration: const InputDecoration(labelText: 'Learner'),
                    items: data.learners.entries
                        .where((e) => data.activeLearnerIds.contains(e.key))
                        .map(
                          (e) => DropdownMenuItem(
                            value: e.key,
                            child: Text(e.value),
                          ),
                        )
                        .toList(),
                    onChanged: (v) => update(() => learner = v),
                  ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  isExpanded: true,
                  decoration: const InputDecoration(
                    labelText: 'Published course',
                  ),
                  items: data.courses
                      .where((c) => c.text('status') == 'Published')
                      .map(
                        (c) => DropdownMenuItem(
                          value: c.id,
                          child: Text(c.text('title')),
                        ),
                      )
                      .toList(),
                  onChanged: (v) => update(() => course = v),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialog, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: learner == null || course == null
                  ? null
                  : () => Navigator.pop(dialog, true),
              child: const Text('Assign'),
            ),
          ],
        ),
      ),
    );
    if (confirmed == true && mounted) {
      await change(
        () => widget.repository.enroll(widget.actor, learner!, course!),
      );
    }
  }

  Future<void> details(Course course) async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => EnrollmentCourseScreen(
          repository: widget.repository,
          actor: widget.actor,
          courseId: course.id,
          launcher: widget.launcher,
        ),
      ),
    );
    if (mounted) await load();
    if (mounted) await widget.onChanged?.call();
  }

  @override
  Widget build(BuildContext context) {
    final data = snapshot;
    final all =
        data?.enrollments
            .where(
              (e) =>
                  widget.learnerId == null || e.learnerId == widget.learnerId,
            )
            .toList() ??
        <Enrollment>[];
    final active = all.where((e) => !e.withdrawn).toList();
    final filtered =
        all
            .where(
              (e) =>
                  (!widget.compact || !e.withdrawn) &&
                  (status.isEmpty ||
                      e.status(data!.course(e.courseId)) == status) &&
                  (courseId.isEmpty || courseId == e.courseId) &&
                  '${data!.learners[e.learnerId]} ${data.course(e.courseId)?.text('title') ?? e.courseId}'
                      .toLowerCase()
                      .contains(query.toLowerCase()),
            )
            .toList()
          ..sort(
            (a, b) =>
                '${b.data['updated_at']}'.compareTo('${a.data['updated_at']}'),
          );
    final pages = (filtered.length / 10).ceil().clamp(1, 1000000);
    final current = page.clamp(0, pages - 1);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Wrap(
          alignment: WrapAlignment.spaceBetween,
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: 12,
          children: [
            Text(
              admin ? 'Enrollments' : 'My Learning',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            Wrap(
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                if (admin)
                  TextButton.icon(
                    onPressed: busy || data == null ? null : assign,
                    icon: const Icon(Icons.add),
                    label: const Text('Assign course'),
                  ),
                IconButton(
                  tooltip: 'Refresh enrollments',
                  onPressed: busy ? null : load,
                  icon: const Icon(Icons.refresh),
                ),
              ],
            ),
          ],
        ),
        if (busy) const LinearProgressIndicator(),
        if (error != null) ...[
          Text(
            error!,
            style: TextStyle(color: Theme.of(context).colorScheme.error),
          ),
          TextButton(onPressed: busy ? null : load, child: const Text('Retry')),
        ],
        if (data != null) ...[
          Text(
            '${active.length} enrolled • ${active.where((e) => e.status(data.course(e.courseId)) == 'In progress').length} in progress • ${active.where((e) => e.status(data.course(e.courseId)) == 'Completed').length} completed',
          ),
          const SizedBox(height: 12),
          if (!widget.compact)
            TextField(
              decoration: const InputDecoration(
                labelText: 'Search enrollments',
                prefixIcon: Icon(Icons.search),
              ),
              onChanged: (v) => setState(() {
                query = v;
                page = 0;
              }),
            ),
          const SizedBox(height: 12),
          if (!widget.compact)
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final s in [
                  '',
                  'Not started',
                  'In progress',
                  'Completed',
                  'Withdrawn',
                ])
                  ChoiceChip(
                    label: Text(s.isEmpty ? 'All' : s),
                    selected: status == s,
                    onSelected: (_) => setState(() {
                      status = s;
                      page = 0;
                    }),
                  ),
              ],
            ),
          if (admin) const SizedBox(height: 24),
          if (admin)
            DropdownButtonFormField<String>(
              key: ValueKey(
                'course-filter-$courseId-${data.courses.map((c) => c.id).join(',')}',
              ),
              initialValue: courseId,
              isExpanded: true,
              decoration: const InputDecoration(labelText: 'Filter by course'),
              items: [
                const DropdownMenuItem(value: '', child: Text('All courses')),
                ...data.courses.map(
                  (c) => DropdownMenuItem(
                    value: c.id,
                    child: Text(c.text('title')),
                  ),
                ),
              ],
              onChanged: (v) => setState(() {
                courseId = v!;
                page = 0;
              }),
            ),
          if (admin) const SizedBox(height: 12),
          if (filtered.isEmpty)
            const Padding(
              padding: EdgeInsets.all(24),
              child: Text(
                'No enrollments found. Explore courses or adjust your filters.',
              ),
            ),
          for (final e
              in filtered.skip(current * 10).take(widget.compact ? 3 : 10))
            Card(
              color: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      data.course(e.courseId)?.text('title') ??
                          'Course unavailable',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    if (admin)
                      Text(
                        data.learners[e.learnerId] ??
                            'Learner unavailable (#${e.learnerId})',
                      ),
                    Text(
                      '${e.status(data.course(e.courseId))} • ${(e.progress(data.course(e.courseId)) * 100).round()}%',
                    ),
                    LinearProgressIndicator(
                      value: e.progress(data.course(e.courseId)),
                    ),
                    Text(
                      'Enrolled ${enrollmentDate(e.data['enrolled_at'])} • Completed ${e.progress(data.course(e.courseId)) == 1 ? enrollmentDate(e.data['completed_at']) : '—'}',
                    ),
                    if (e.withdrawn)
                      Text(
                        'Withdrawn ${enrollmentDate(e.data['withdrawn_at'])}',
                      ),
                    if (admin && data.course(e.courseId) != null)
                      ExpansionTile(
                        title: const Text('Course details'),
                        children: [
                          ListTile(
                            title: Text(
                              data.course(e.courseId)!.text('headline'),
                            ),
                            subtitle: Text(
                              data.course(e.courseId)!.text('description'),
                            ),
                          ),
                          ListTile(
                            title: Text(
                              'Instructor: ${data.course(e.courseId)!.text('instructor')}',
                            ),
                            subtitle: Text(
                              '${data.course(e.courseId)!.lessonCount} lessons',
                            ),
                          ),
                        ],
                      ),
                    Wrap(
                      spacing: 12,
                      children: [
                        if (!admin && data.course(e.courseId) != null)
                          TextButton(
                            onPressed: busy
                                ? null
                                : () => details(data.course(e.courseId)!),
                            child: const Text('Course details'),
                          ),
                        if (admin || e.withdrawn)
                          TextButton(
                            onPressed: busy
                                ? null
                                : () async {
                                    if (e.withdrawn) {
                                      await change(
                                        () => widget.repository.enroll(
                                          widget.actor,
                                          e.learnerId,
                                          e.courseId,
                                        ),
                                      );
                                    } else if (await confirmWithdrawal(
                                          context,
                                        ) &&
                                        mounted) {
                                      await change(
                                        () => widget.repository.withdraw(
                                          widget.actor,
                                          e.id,
                                        ),
                                      );
                                    }
                                  },
                            child: Text(e.withdrawn ? 'Re-enroll' : 'Withdraw'),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          if (!widget.compact)
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                IconButton(
                  tooltip: 'Previous page',
                  onPressed: current == 0
                      ? null
                      : () => setState(() => page = current - 1),
                  icon: const Icon(Icons.chevron_left),
                ),
                Text('${current + 1} / $pages'),
                IconButton(
                  tooltip: 'Next page',
                  onPressed: current + 1 >= pages
                      ? null
                      : () => setState(() => page = current + 1),
                  icon: const Icon(Icons.chevron_right),
                ),
              ],
            ),
        ],
      ],
    );
  }
}

class EnrollmentScreen extends StatelessWidget {
  const EnrollmentScreen({
    super.key,
    required this.repository,
    required this.actor,
    this.learnerId,
    this.onNavigate,
  });
  final EnrollmentRepository repository;
  final UserSession actor;
  final int? learnerId;
  final ValueChanged<AdminDestination>? onNavigate;
  @override
  Widget build(BuildContext context) => Scaffold(
    bottomNavigationBar: onNavigate == null
        ? null
        : AdminBottomBar(
            selected: AdminDestination.enrollments,
            onSelected: onNavigate!,
          ),
    appBar: AppBar(
      title: Text(
        actor.role == AccountRole.admin ? 'Enrollments' : 'My Learning',
      ),
    ),
    body: Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 900),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: EnrollmentPanel(
            repository: repository,
            actor: actor,
            learnerId: learnerId,
          ),
        ),
      ),
    ),
  );
}

class EnrollmentCourseScreen extends StatefulWidget {
  const EnrollmentCourseScreen({
    super.key,
    required this.repository,
    required this.actor,
    required this.courseId,
    this.launcher = launchLessonVideo,
  });
  final EnrollmentRepository repository;
  final UserSession actor;
  final String courseId;
  final VideoLauncher launcher;
  @override
  State<EnrollmentCourseScreen> createState() => _EnrollmentCourseScreenState();
}

class _EnrollmentCourseScreenState extends State<EnrollmentCourseScreen> {
  EnrollmentSnapshot? snapshot;
  String? error;
  bool busy = false;
  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    setState(() {
      busy = true;
      error = null;
    });
    try {
      final s = await widget.repository.load(widget.actor);
      if (mounted) setState(() => snapshot = s);
    } catch (e) {
      if (mounted) setState(() => error = enrollmentError(e));
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> change(Future<void> Function() action) async {
    setState(() {
      busy = true;
      error = null;
    });
    try {
      await action();
      await load();
    } catch (e) {
      if (mounted) {
        setState(() {
          error = enrollmentError(e);
          busy = false;
        });
      }
    }
  }

  Future<void> lesson(Enrollment e, Course c, String id) async {
    setState(() {
      busy = true;
      error = null;
    });
    try {
      await widget.repository.openLesson(widget.actor, e.id, id);
      if (!mounted) return;
      setState(() => busy = false);
      await Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => LessonScreen(
            repository: widget.repository,
            actor: widget.actor,
            enrollmentId: e.id,
            course: c,
            initialLessonId: id,
            launcher: widget.launcher,
          ),
        ),
      );
      if (mounted) await load();
    } catch (e) {
      if (mounted) setState(() => error = enrollmentError(e));
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final course = snapshot?.course(widget.courseId);
    final e = snapshot?.enrollments
        .where(
          (e) =>
              e.courseId == widget.courseId && e.learnerId == widget.actor.id,
        )
        .firstOrNull;
    final access = e != null && !e.withdrawn;
    return Scaffold(
      appBar: AppBar(title: const Text('Course Details')),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 800),
          child: ListView(
            padding: const EdgeInsets.all(24),
            children: [
              if (busy) const LinearProgressIndicator(),
              if (error != null) ...[
                Text(error!),
                TextButton(
                  onPressed: busy ? null : load,
                  child: const Text('Retry'),
                ),
              ],
              if (!busy && course == null && error == null)
                const Text('Course unavailable.'),
              if (course != null) ...[
                Text(
                  course.text('title'),
                  style: Theme.of(context).textTheme.headlineMedium,
                ),
                Text(course.text('headline')),
                const SizedBox(height: 16),
                Text('Instructor: ${course.text('instructor')}'),
                Text(
                  '${course.text('category')} • ${course.text('difficulty')} • ${course.text('duration')} ${course.text('unit')}',
                ),
                const SizedBox(height: 20),
                Text(
                  'About this course',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                Text(course.text('description')),
                const SizedBox(height: 20),
                Text(
                  'What you will learn',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                for (final objective in course.data['objectives'] as List)
                  ListTile(
                    leading: const Icon(Icons.check_circle_outline),
                    title: Text('$objective'),
                  ),
                if (e != null) ...[
                  Text(
                    '${e.status(course)} • ${(e.progress(course) * 100).round()}%',
                  ),
                  LinearProgressIndicator(value: e.progress(course)),
                  Text('Enrolled ${enrollmentDate(e.data['enrolled_at'])}'),
                ],
                const SizedBox(height: 16),
                if (!access)
                  FilledButton(
                    onPressed: busy || course.text('status') != 'Published'
                        ? null
                        : () => change(
                            () => widget.repository.enroll(
                              widget.actor,
                              widget.actor.id,
                              course.id,
                            ),
                          ),
                    child: Text(e == null ? 'Enroll' : 'Re-enroll'),
                  ),
                if (access && course.lessons.isNotEmpty)
                  FilledButton(
                    onPressed: busy
                        ? null
                        : () {
                            final resume =
                                course.lessons
                                    .where(
                                      (l) =>
                                          l['id'] ==
                                          e.data['last_opened_lesson_id'],
                                    )
                                    .firstOrNull ??
                                course.lessons
                                    .where(
                                      (l) => !e.completed.contains(l['id']),
                                    )
                                    .firstOrNull ??
                                course.lessons.first;
                            lesson(e, course, resume['id'] as String);
                          },
                    child: Text(
                      e.data['last_opened_lesson_id'] == null
                          ? 'Start learning'
                          : 'Resume learning',
                    ),
                  ),
                if (access)
                  TextButton(
                    onPressed: busy
                        ? null
                        : () async {
                            if (await confirmWithdrawal(context) && mounted) {
                              await change(
                                () => widget.repository.withdraw(
                                  widget.actor,
                                  e.id,
                                ),
                              );
                            }
                          },
                    child: const Text('Withdraw'),
                  ),
                const SizedBox(height: 20),
                Text(
                  'Course curriculum',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                for (final module in course.modules)
                  ExpansionTile(
                    title: Text('${module['title']}'),
                    children: [
                      for (final l in module['lessons'] as List)
                        ListTile(
                          leading: Icon(
                            !access
                                ? Icons.lock_outline
                                : e.completed.contains(l['id'])
                                ? Icons.check_circle
                                : Icons.play_circle_outline,
                          ),
                          title: Text('${l['title']}'),
                          subtitle: Text(
                            '${l['format']} • ${l['minutes']} min',
                          ),
                          onTap: !access || busy
                              ? null
                              : () => lesson(e, course, l['id'] as String),
                        ),
                    ],
                  ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class LessonScreen extends StatefulWidget {
  const LessonScreen({
    super.key,
    required this.repository,
    required this.actor,
    required this.enrollmentId,
    required this.course,
    required this.initialLessonId,
    this.launcher = launchLessonVideo,
  });
  final EnrollmentRepository repository;
  final UserSession actor;
  final String enrollmentId, initialLessonId;
  final Course course;
  final VideoLauncher launcher;
  @override
  State<LessonScreen> createState() => _LessonScreenState();
}

class _LessonScreenState extends State<LessonScreen> {
  late Course course = widget.course;
  late int index = widget.course.lessons.indexWhere(
    (l) => l['id'] == widget.initialLessonId,
  );
  bool busy = true;
  bool verified = false;
  String? error;
  final completed = <String>{};
  @override
  void initState() {
    super.initState();
    refresh();
  }

  Future<void> refresh({String? lessonId}) async {
    setState(() {
      busy = true;
      error = null;
    });
    try {
      final snapshot = await widget.repository.load(widget.actor);
      final e = snapshot.enrollments
          .where((e) => e.id == widget.enrollmentId && !e.withdrawn)
          .firstOrNull;
      if (e == null) {
        throw const JsonBinException('An active enrollment is required.');
      }
      final latest = snapshot.course(e.courseId);
      if (latest == null || latest.lessons.isEmpty) {
        throw const JsonBinException('This course has no available lessons.');
      }
      final selected =
          lessonId ??
          (index >= 0 && index < course.lessons.length
              ? course.lessons[index]['id']
              : widget.initialLessonId);
      if (mounted) {
        setState(() {
          course = latest;
          index = course.lessons.indexWhere((l) => l['id'] == selected);
          if (index < 0) index = 0;
          verified = true;
          completed.clear();
          completed.addAll(e.completed);
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          verified = false;
          error = enrollmentError(e);
        });
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> save(int next, {bool complete = false}) async {
    setState(() {
      busy = true;
      error = null;
    });
    try {
      final id = course.lessons[next]['id'] as String;
      await widget.repository.openLesson(
        widget.actor,
        widget.enrollmentId,
        id,
        complete: complete,
      );
      if (mounted) await refresh(lessonId: id);
    } catch (e) {
      if (mounted) setState(() => error = enrollmentError(e));
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> video(String url) async {
    try {
      if (!validWebUrl(url) || !await widget.launcher(Uri.parse(url))) {
        throw const JsonBinException(
          'Unable to open this video. Please try again.',
        );
      }
    } catch (e) {
      if (mounted) {
        setState(
          () => error = e is JsonBinException
              ? e.message
              : 'Unable to open this video. Please try again.',
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!verified) {
      return Scaffold(
        appBar: AppBar(title: Text(course.text('title'))),
        body: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              if (busy) const LinearProgressIndicator(),
              if (error != null) ...[
                Text(error!),
                TextButton(
                  onPressed: busy ? null : refresh,
                  child: const Text('Refresh and retry'),
                ),
              ],
            ],
          ),
        ),
      );
    }
    final lessons = course.lessons;
    final l = lessons[index];
    return Scaffold(
      appBar: AppBar(title: Text(course.text('title'))),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 800),
          child: ListView(
            padding: const EdgeInsets.all(24),
            children: [
              if (busy) const LinearProgressIndicator(),
              if (error != null) ...[
                Text(
                  error!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
                TextButton(
                  onPressed: busy
                      ? null
                      : () async {
                          await refresh();
                          if (mounted && verified) await save(index);
                        },
                  child: const Text('Refresh and retry'),
                ),
              ],
              Text(
                '${index + 1} / ${lessons.length} • ${l['format']} • ${l['minutes']} min',
              ),
              Text(
                '${l['title']}',
                style: Theme.of(context).textTheme.headlineMedium,
              ),
              const SizedBox(height: 24),
              if (l['format'] == 'Video Lesson')
                FilledButton.icon(
                  onPressed: busy ? null : () => video('${l['content']}'),
                  icon: const Icon(Icons.open_in_new),
                  label: const Text('Open video'),
                )
              else
                SelectableText('${l['content']}'),
              const SizedBox(height: 24),
              FilledButton.icon(
                onPressed: busy || completed.contains(l['id'])
                    ? null
                    : () => save(index, complete: true),
                icon: const Icon(Icons.check),
                label: Text(
                  completed.contains(l['id'])
                      ? 'Lesson completed'
                      : 'Mark complete',
                ),
              ),
              if (lessons.every((l) => completed.contains(l['id'])))
                const Padding(
                  padding: EdgeInsets.all(16),
                  child: Text(
                    'Course completed! You have finished every lesson.',
                  ),
                ),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  TextButton(
                    onPressed: busy || index == 0
                        ? null
                        : () => save(index - 1),
                    child: const Text('Previous'),
                  ),
                  TextButton(
                    onPressed: busy || index + 1 == lessons.length
                        ? null
                        : () => save(index + 1),
                    child: const Text('Next'),
                  ),
                ],
              ),
              ExpansionTile(
                title: const Text('Course curriculum'),
                children: [
                  for (var i = 0; i < lessons.length; i++)
                    ListTile(
                      selected: i == index,
                      leading: Icon(
                        completed.contains(lessons[i]['id'])
                            ? Icons.check_circle
                            : Icons.circle_outlined,
                      ),
                      title: Text('${lessons[i]['title']}'),
                      onTap: busy ? null : () => save(i),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
