import 'package:flutter/material.dart';

import '../enrollment/enrollment_repository.dart';

import '../auth/sign_in_repository.dart';
import '../data/jsonbin_store.dart';
import 'admin_bottom_bar.dart';
import 'admin_courses_repository.dart';

Widget coursePanel(String title, List<Widget> children) => Card(
  color: Colors.white,
  margin: const EdgeInsets.only(bottom: 16),
  child: Padding(
    padding: const EdgeInsets.all(20),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          title,
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 16),
        ...children,
      ],
    ),
  ),
);
Widget courseBody(List<Widget> children) => Center(
  child: ConstrainedBox(
    constraints: const BoxConstraints(maxWidth: 900),
    child: ListView(padding: const EdgeInsets.all(16), children: children),
  ),
);
void courseMessage(BuildContext context, Object error) =>
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          error is JsonBinException
              ? error.message
              : 'Unable to complete the request. Please try again.',
        ),
      ),
    );

class AdminCoursesScreen extends StatefulWidget {
  const AdminCoursesScreen({
    super.key,
    required this.repository,
    required this.session,
    required this.onNavigate,
    this.enrollmentsRepository,
  });
  final AdminCoursesRepository repository;
  final EnrollmentRepository? enrollmentsRepository;
  final UserSession session;
  final ValueChanged<AdminDestination> onNavigate;
  @override
  State<AdminCoursesScreen> createState() => _AdminCoursesScreenState();
}

class _AdminCoursesScreenState extends State<AdminCoursesScreen> {
  List<Course>? courses;
  EnrollmentSnapshot? enrollments;
  String? enrollmentError;
  String query = '', filter = 'All';
  String? error;
  bool loading = false;
  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    setState(() {
      loading = true;
      error = null;
    });
    try {
      final result = await widget.repository.list(widget.session);
      if (mounted) setState(() => courses = result);
    } catch (e) {
      if (mounted) {
        setState(
          () => error = e is JsonBinException
              ? e.message
              : 'Unable to load courses.',
        );
      }
    } finally {
      if (mounted) setState(() => loading = false);
    }
    if (widget.enrollmentsRepository != null) {
      try {
        final result = await widget.enrollmentsRepository!.load(widget.session);
        if (mounted) {
          setState(() {
            enrollments = result;
            enrollmentError = null;
          });
        }
      } catch (_) {
        if (mounted) {
          setState(
            () => enrollmentError =
                'Enrollment counts unavailable. Refresh to retry.',
          );
        }
      }
    }
  }

  Future<void> edit([Course? course]) async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => CourseEditorScreen(
          repository: widget.repository,
          session: widget.session,
          course: course,
        ),
      ),
    );
    if (mounted) await load();
  }

  Future<void> status(Course course, String value) async {
    final copy = course.copy()..data['status'] = value;
    if (value == 'Published' && copy.publishErrors.isNotEmpty) {
      await edit(copy);
      return;
    }
    setState(() => loading = true);
    try {
      await widget.repository.save(widget.session, copy);
      await load();
    } catch (e) {
      if (mounted) courseMessage(context, e);
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final visible = (courses ?? <Course>[])
        .where(
          (c) =>
              (filter == 'All' || c.text('status') == filter) &&
              '${c.text('title')} ${c.text('category')}'.toLowerCase().contains(
                query.toLowerCase(),
              ),
        )
        .toList();
    return Scaffold(
      appBar: AppBar(
        title: const Text('Course Management'),
        actions: [
          IconButton(
            onPressed: loading ? null : load,
            tooltip: 'Refresh courses',
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      bottomNavigationBar: AdminBottomBar(
        selected: AdminDestination.courses,
        onSelected: widget.onNavigate,
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: loading ? null : () => edit(),
        tooltip: 'Create Course',
        child: const Icon(Icons.add),
      ),
      body: courseBody([
        const Text(
          'Your course library',
          style: TextStyle(fontSize: 28, fontWeight: FontWeight.w800),
        ),
        const Text(
          'Build, organize and publish meaningful learning experiences.',
        ),
        const SizedBox(height: 20),
        FilledButton.icon(
          onPressed: loading ? null : () => edit(),
          icon: const Icon(Icons.add),
          label: const Text('Create Course'),
        ),
        const SizedBox(height: 16),
        TextField(
          decoration: const InputDecoration(
            hintText: 'Search courses or categories',
            prefixIcon: Icon(Icons.search),
          ),
          onChanged: (v) => setState(() => query = v),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          children: [
            for (final value in ['All', 'Published', 'Draft', 'Archived'])
              ChoiceChip(
                label: Text(
                  '$value${courses == null ? '' : ' (${value == 'All' ? courses!.length : courses!.where((c) => c.text('status') == value).length})'}',
                ),
                selected: filter == value,
                onSelected: (_) => setState(() => filter = value),
              ),
          ],
        ),
        if (loading) const LinearProgressIndicator(),
        if (enrollmentError != null) Text(enrollmentError!),
        if (error != null)
          coursePanel('Courses unavailable', [
            Text(error!),
            TextButton(
              onPressed: loading ? null : load,
              child: const Text('Retry'),
            ),
          ]),
        const SizedBox(height: 16),
        Text('Showing ${visible.length} courses'),
        const SizedBox(height: 12),
        if (!loading && courses != null && visible.isEmpty)
          coursePanel('No courses found', [
            Text(
              courses!.isEmpty
                  ? 'Create your first course to get started.'
                  : 'Try another search or filter.',
            ),
          ]),
        for (final course in visible)
          coursePanel(course.text('title'), [
            if (widget.enrollmentsRepository != null)
              Text(
                enrollments == null
                    ? 'Enrollment count unavailable'
                    : '${enrollments!.enrollments.where((e) => e.courseId == course.id && !e.withdrawn).length} enrolled',
              ),
            Wrap(
              spacing: 8,
              children: [
                Chip(
                  label: Text(
                    course.text('category').isEmpty
                        ? 'Uncategorized'
                        : course.text('category'),
                  ),
                ),
                Chip(label: Text(course.text('status'))),
              ],
            ),
            Text(
              '${course.modules.length} modules • ${course.lessonCount} lessons',
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              children: [
                FilledButton.tonalIcon(
                  onPressed: loading ? null : () => edit(course),
                  icon: const Icon(Icons.edit_outlined),
                  label: Text(
                    course.text('status') == 'Draft'
                        ? 'Continue Editing'
                        : 'Edit',
                  ),
                ),
                TextButton(
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => CourseDetailsScreen(course: course),
                    ),
                  ),
                  child: const Text('View Details'),
                ),
                PopupMenuButton<String>(
                  enabled: !loading,
                  onSelected: (value) async {
                    if (value == 'Duplicate') {
                      final copy = course.copy()..data.remove('id');
                      copy.data['title'] = '${course.text('title')} (copy)';
                      copy.data['status'] = 'Draft';
                      await edit(copy);
                    } else {
                      await status(course, value);
                    }
                  },
                  itemBuilder: (_) => [
                    const PopupMenuItem(
                      value: 'Duplicate',
                      child: Text('Duplicate'),
                    ),
                    PopupMenuItem(
                      value: course.text('status') == 'Published'
                          ? 'Draft'
                          : 'Published',
                      child: Text(
                        course.text('status') == 'Published'
                            ? 'Unpublish'
                            : 'Publish',
                      ),
                    ),
                    PopupMenuItem(
                      value: course.text('status') == 'Archived'
                          ? 'Draft'
                          : 'Archived',
                      child: Text(
                        course.text('status') == 'Archived'
                            ? 'Restore to Draft'
                            : 'Archive',
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ]),
        const SizedBox(height: 80),
      ]),
    );
  }
}

class CourseEditorScreen extends StatefulWidget {
  const CourseEditorScreen({
    super.key,
    required this.repository,
    required this.session,
    this.course,
  });
  final AdminCoursesRepository repository;
  final UserSession session;
  final Course? course;
  @override
  State<CourseEditorScreen> createState() => _CourseEditorScreenState();
}

class _CourseEditorScreenState extends State<CourseEditorScreen> {
  late Course course = (widget.course?.copy() ?? Course.empty())
    ..ensureLessonIds();
  int step = 0;
  bool busy = false, dirty = false;
  final form = GlobalKey<FormState>();
  final objective = TextEditingController();
  @override
  void dispose() {
    objective.dispose();
    super.dispose();
  }

  Future<bool> leave() async =>
      !dirty ||
      await showDialog<bool>(
            context: context,
            builder: (c) => AlertDialog(
              title: const Text('Discard unsaved changes?'),
              content: const Text(
                'Save a draft to keep your work before leaving.',
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(c, false),
                  child: const Text('Keep Editing'),
                ),
                TextButton(
                  onPressed: () => Navigator.pop(c, true),
                  child: const Text('Discard'),
                ),
              ],
            ),
          ) ==
          true;
  Future<void> save(bool publish) async {
    if (course.text('title').trim().isEmpty) {
      setState(() => step = 0);
      courseMessage(
        context,
        const JsonBinException('Enter a course title before saving.'),
      );
      return;
    }
    if (publish && course.publishErrors.isNotEmpty) {
      courseMessage(context, JsonBinException(course.publishErrors.join('\n')));
      return;
    }
    setState(() => busy = true);
    final candidate = course.copy()
      ..data['status'] = publish ? 'Published' : 'Draft';
    try {
      final saved = await widget.repository.save(widget.session, candidate);
      if (!mounted) return;
      setState(() {
        course = saved;
        dirty = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            publish ? 'Course published successfully' : 'Draft saved',
          ),
        ),
      );
      if (publish) {
        setState(() => busy = false);
        await WidgetsBinding.instance.endOfFrame;
        if (mounted) Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) courseMessage(context, e);
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Widget field(
    String key,
    String label, {
    int lines = 1,
    bool required = false,
    int? maxLength,
  }) => Padding(
    padding: const EdgeInsets.only(bottom: 16),
    child: TextFormField(
      key: ValueKey(key),
      initialValue: course.text(key),
      maxLines: lines,
      maxLength: maxLength,
      decoration: InputDecoration(labelText: label),
      onChanged: (v) {
        course.data[key] = v;
        dirty = true;
      },
      validator: (v) {
        if (required && (v ?? '').trim().isEmpty) {
          return 'This field is required';
        }
        if (key == 'duration' &&
            ((double.tryParse(v ?? '') ?? 0) <= 0 ||
                !(double.tryParse(v ?? '') ?? 0).isFinite)) {
          return 'Enter a positive duration';
        }
        if (key == 'thumbnail' && (v ?? '').isNotEmpty && !validWebUrl(v!)) {
          return 'Enter a valid HTTPS image URL';
        }
        return null;
      },
    ),
  );
  Widget select(String key, String label, List<String> options) => Padding(
    padding: const EdgeInsets.only(bottom: 16),
    child: DropdownButtonFormField<String>(
      isExpanded: true,
      initialValue: options.contains(course.text(key))
          ? course.text(key)
          : options.first,
      decoration: InputDecoration(labelText: label),
      items: [
        for (final v in options) DropdownMenuItem(value: v, child: Text(v)),
      ],
      onChanged: (v) => setState(() {
        course.data[key] = v;
        dirty = true;
      }),
    ),
  );
  Future<void> moduleName([int? index]) async {
    final input = TextEditingController(
      text: index == null ? '' : course.modules[index]['title'] as String,
    );
    final name = await showDialog<String>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text(index == null ? 'Add Module' : 'Rename Module'),
        content: TextField(
          controller: input,
          autofocus: true,
          decoration: const InputDecoration(labelText: 'Module title'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              if (input.text.trim().isNotEmpty) {
                Navigator.pop(c, input.text.trim());
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
    if (name != null && mounted) {
      setState(() {
        if (index == null) {
          course.modules.add({'title': name, 'lessons': <dynamic>[]});
        } else {
          course.modules[index]['title'] = name;
        }
        dirty = true;
      });
    }
    // Dialog controllers are disposed after their closing animation.
    await Future<void>.delayed(const Duration(milliseconds: 300));
    input.dispose();
  }

  Future<void> lesson(int module, [int? index]) async {
    final result = await Navigator.of(context).push<Map<String, dynamic>>(
      MaterialPageRoute(
        builder: (_) => LessonEditorScreen(
          lesson: index == null
              ? null
              : Map<String, dynamic>.from(
                  course.modules[module]['lessons'][index] as Map,
                ),
        ),
      ),
    );
    if (result != null && mounted) {
      setState(() {
        final lessons = course.modules[module]['lessons'] as List;
        if (index == null) {
          lessons.add(result);
        } else {
          lessons[index] = result;
        }
        dirty = true;
      });
    }
  }

  Future<void> remove(String title, VoidCallback action) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text('Remove $title?'),
        content: const Text('This removes its content from this course draft.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(c, true),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
    if (confirmed == true && mounted) {
      setState(() {
        action();
        dirty = true;
      });
    }
  }

  void move(List list, int index, int direction) => setState(() {
    final item = list.removeAt(index);
    list.insert(index + direction, item);
    dirty = true;
  });
  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !dirty && !busy,
    onPopInvokedWithResult: (popped, _) async {
      if (!popped && !busy && await leave() && mounted) {
        setState(() => dirty = false);
        await WidgetsBinding.instance.endOfFrame;
        if (context.mounted) Navigator.pop(context);
      }
    },
    child: Scaffold(
      appBar: AppBar(
        title: Text(
          ['Create Course', 'Curriculum Builder', 'Review & Publish'][step],
        ),
        actions: [
          TextButton(
            onPressed: busy ? null : () => save(false),
            child: const Text('Save Draft'),
          ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              if (step > 0)
                TextButton(
                  onPressed: busy ? null : () => setState(() => step--),
                  child: const Text('Back'),
                ),
              Expanded(
                child: FilledButton.icon(
                  onPressed: busy
                      ? null
                      : () {
                          if (step == 0 && !form.currentState!.validate()) {
                            return;
                          }
                          if (step < 2) {
                            setState(() => step++);
                          } else {
                            save(true);
                          }
                        },
                  icon: Icon(step == 2 ? Icons.publish : Icons.arrow_forward),
                  label: Text(
                    step == 0
                        ? 'Next: Curriculum'
                        : step == 1
                        ? 'Review Course'
                        : 'Publish Course',
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
      body: AbsorbPointer(
        absorbing: busy,
        child: courseBody([
          if (busy) const LinearProgressIndicator(),
          Wrap(
            spacing: 8,
            children: [
              for (var i = 0; i < 3; i++)
                Chip(
                  avatar: CircleAvatar(child: Text('${i + 1}')),
                  backgroundColor: step == i ? const Color(0xFFFFDBCA) : null,
                  label: Text(['Basics', 'Curriculum', 'Publish'][i]),
                ),
            ],
          ),
          const SizedBox(height: 16),
          if (step == 0)
            Form(
              key: form,
              child: Column(
                children: [
                  coursePanel('Course Essentials', [
                    field(
                      'title',
                      'Course Title *',
                      required: true,
                      maxLength: 100,
                    ),
                    field(
                      'headline',
                      'Short Headline *',
                      required: true,
                      maxLength: 120,
                    ),
                    field(
                      'description',
                      'Course Description *',
                      lines: 5,
                      required: true,
                    ),
                  ]),
                  coursePanel('Classification & Commitment', [
                    field('category', 'Category *', required: true),
                    select('difficulty', 'Difficulty Level', [
                      'Beginner',
                      'Intermediate',
                      'Advanced',
                    ]),
                    field('duration', 'Expected Commitment *'),
                    select('unit', 'Duration Unit', [
                      'Hours',
                      'Weeks',
                      'Modules',
                    ]),
                    field('instructor', 'Lead Instructor *', required: true),
                  ]),
                  coursePanel('Course Thumbnail', [
                    field('thumbnail', 'HTTPS image URL (optional)'),
                    const Text(
                      'Use an image hosted on your media service. Recommended aspect ratio: 16:9.',
                    ),
                  ]),
                  coursePanel('What Learners Will Gain', [
                    for (
                      var i = 0;
                      i < (course.data['objectives'] as List).length;
                      i++
                    )
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: const Icon(Icons.check_circle_outline),
                        title: Text('${course.data['objectives'][i]}'),
                        trailing: IconButton(
                          tooltip: 'Remove objective',
                          icon: const Icon(Icons.close),
                          onPressed: () => setState(() {
                            (course.data['objectives'] as List).removeAt(i);
                            dirty = true;
                          }),
                        ),
                      ),
                    TextField(
                      controller: objective,
                      decoration: const InputDecoration(
                        labelText: 'Learning objective',
                      ),
                    ),
                    TextButton.icon(
                      onPressed: () {
                        if (objective.text.trim().isNotEmpty) {
                          setState(() {
                            (course.data['objectives'] as List).add(
                              objective.text.trim(),
                            );
                            objective.clear();
                            dirty = true;
                          });
                        }
                      },
                      icon: const Icon(Icons.add),
                      label: const Text('Add Objective'),
                    ),
                  ]),
                ],
              ),
            ),
          if (step == 1) ...[
            const Text(
              'Shape the learning journey',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800),
            ),
            Text(
              '${course.modules.length} modules • ${course.lessonCount} lessons',
            ),
            const SizedBox(height: 16),
            if (course.modules.isEmpty)
              coursePanel('Start with a module', [
                const Text(
                  'Group related lessons into modules, then add your lesson content.',
                ),
              ]),
            for (var i = 0; i < course.modules.length; i++)
              coursePanel('${i + 1}. ${course.modules[i]['title']}', [
                Wrap(
                  children: [
                    TextButton(
                      onPressed: () => moduleName(i),
                      child: const Text('Rename'),
                    ),
                    IconButton(
                      tooltip: 'Move module up',
                      onPressed: i == 0
                          ? null
                          : () => move(course.modules, i, -1),
                      icon: const Icon(Icons.arrow_upward),
                    ),
                    IconButton(
                      tooltip: 'Move module down',
                      onPressed: i == course.modules.length - 1
                          ? null
                          : () => move(course.modules, i, 1),
                      icon: const Icon(Icons.arrow_downward),
                    ),
                    IconButton(
                      tooltip: 'Remove module',
                      onPressed: () =>
                          remove('module', () => course.modules.removeAt(i)),
                      icon: const Icon(Icons.delete_outline),
                    ),
                  ],
                ),
                for (
                  var j = 0;
                  j < (course.modules[i]['lessons'] as List).length;
                  j++
                )
                  Column(
                    children: [
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: const Icon(Icons.article_outlined),
                        title: Text(
                          '${course.modules[i]['lessons'][j]['title']}',
                        ),
                        subtitle: Text(
                          '${course.modules[i]['lessons'][j]['format']} • ${course.modules[i]['lessons'][j]['minutes']} min',
                        ),
                        onTap: () => lesson(i, j),
                        trailing: IconButton(
                          tooltip: 'Remove lesson',
                          onPressed: () => remove(
                            'lesson',
                            () => (course.modules[i]['lessons'] as List)
                                .removeAt(j),
                          ),
                          icon: const Icon(Icons.close),
                        ),
                      ),
                      Row(
                        children: [
                          TextButton(
                            onPressed: j == 0
                                ? null
                                : () => move(
                                    course.modules[i]['lessons'] as List,
                                    j,
                                    -1,
                                  ),
                            child: const Text('Move up'),
                          ),
                          TextButton(
                            onPressed:
                                j ==
                                    (course.modules[i]['lessons'] as List)
                                            .length -
                                        1
                                ? null
                                : () => move(
                                    course.modules[i]['lessons'] as List,
                                    j,
                                    1,
                                  ),
                            child: const Text('Move down'),
                          ),
                        ],
                      ),
                    ],
                  ),
                OutlinedButton.icon(
                  onPressed: () => lesson(i),
                  icon: const Icon(Icons.add),
                  label: const Text('Add Lesson'),
                ),
              ]),
            OutlinedButton.icon(
              onPressed: () => moduleName(),
              icon: const Icon(Icons.add),
              label: const Text('Add Module'),
            ),
          ],
          if (step == 2) ...[
            coursePanel(course.text('title'), [
              Text(course.text('headline')),
              const SizedBox(height: 12),
              Text(
                '${course.modules.length} modules • ${course.lessonCount} lessons',
              ),
              TextButton.icon(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => CourseDetailsScreen(course: course.copy()),
                  ),
                ),
                icon: const Icon(Icons.visibility_outlined),
                label: const Text('Preview Course'),
              ),
            ]),
            coursePanel(
              course.publishErrors.isEmpty
                  ? 'Ready to publish'
                  : 'Complete before publishing',
              [
                if (course.publishErrors.isEmpty)
                  const Text('Your course is complete and ready for learners.'),
                for (final error in course.publishErrors)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Text('• $error'),
                  ),
              ],
            ),
            const Text(
              'Publishing makes this course available in the course catalog. Save Draft to continue working later.',
            ),
          ],
        ]),
      ),
    ),
  );
}

class LessonEditorScreen extends StatefulWidget {
  const LessonEditorScreen({super.key, this.lesson});
  final Map<String, dynamic>? lesson;
  @override
  State<LessonEditorScreen> createState() => _LessonEditorScreenState();
}

class _LessonEditorScreenState extends State<LessonEditorScreen> {
  late final title = TextEditingController(
    text: widget.lesson?['title'] as String? ?? '',
  );
  late final content = TextEditingController(
    text: widget.lesson?['content'] as String? ?? '',
  );
  late final minutes = TextEditingController(
    text: '${widget.lesson?['minutes'] ?? 10}',
  );
  late String format = widget.lesson?['format'] as String? ?? 'Article / Text';
  bool dirty = false;
  final form = GlobalKey<FormState>();
  @override
  void dispose() {
    title.dispose();
    content.dispose();
    minutes.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !dirty,
    onPopInvokedWithResult: (popped, _) async {
      if (popped) return;
      final discard = await showDialog<bool>(
        context: context,
        builder: (c) => AlertDialog(
          title: const Text('Discard lesson changes?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(c, false),
              child: const Text('Keep Editing'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(c, true),
              child: const Text('Discard'),
            ),
          ],
        ),
      );
      if (discard == true && mounted) {
        setState(() => dirty = false);
        await WidgetsBinding.instance.endOfFrame;
        if (context.mounted) Navigator.pop(context);
      }
    },
    child: Scaffold(
      appBar: AppBar(title: const Text('Lesson Content Editor')),
      body: Form(
        key: form,
        onChanged: () => dirty = true,
        child: courseBody([
          coursePanel('Lesson Details', [
            TextFormField(
              controller: title,
              decoration: const InputDecoration(labelText: 'Lesson Title'),
              validator: (v) =>
                  v!.trim().isEmpty ? 'Enter a lesson title' : null,
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              initialValue: format,
              decoration: const InputDecoration(labelText: 'Lesson Format'),
              items: [
                for (final v in [
                  'Video Lesson',
                  'Article / Text',
                  'Interactive Lab',
                  'Assessment',
                ])
                  DropdownMenuItem(value: v, child: Text(v)),
              ],
              onChanged: (v) => setState(() {
                format = v!;
                dirty = true;
              }),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: minutes,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Estimated Duration (minutes)',
              ),
              validator: (v) => (int.tryParse(v ?? '') ?? 0) <= 0
                  ? 'Enter a positive whole number'
                  : null,
            ),
          ]),
          coursePanel('Lesson Content', [
            TextFormField(
              controller: content,
              maxLines: format == 'Video Lesson' ? 3 : 14,
              decoration: InputDecoration(
                labelText: format == 'Video Lesson'
                    ? 'HTTPS video URL'
                    : format == 'Assessment'
                    ? 'Questions and assessment instructions'
                    : format == 'Interactive Lab'
                    ? 'Lab instructions and resources'
                    : 'Article text',
                alignLabelWithHint: true,
              ),
              validator: (v) => v!.trim().isEmpty
                  ? 'Add lesson content'
                  : format == 'Video Lesson' && !validWebUrl(v)
                  ? 'Enter a valid HTTPS video URL'
                  : null,
            ),
          ]),
          FilledButton.icon(
            onPressed: () async {
              if (form.currentState!.validate()) {
                setState(() => dirty = false);
                await WidgetsBinding.instance.endOfFrame;
                if (!context.mounted) return;
                Navigator.of(context).pop({
                  ...?widget.lesson,
                  'id':
                      widget.lesson?['id'] ??
                      'lesson-${DateTime.now().microsecondsSinceEpoch}',
                  'title': title.text.trim(),
                  'format': format,
                  'minutes': int.parse(minutes.text),
                  'content': content.text.trim(),
                });
              }
            },
            icon: const Icon(Icons.check),
            label: const Text('Save Lesson to Course'),
          ),
          const SizedBox(height: 8),
          const Text('Save the course draft to store your lesson changes.'),
        ]),
      ),
    ),
  );
}

class CourseDetailsScreen extends StatelessWidget {
  const CourseDetailsScreen({super.key, required this.course});
  final Course course;
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Course Details')),
    body: courseBody([
      if (validWebUrl(course.text('thumbnail')))
        ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: AspectRatio(
            aspectRatio: 16 / 9,
            child: Image.network(
              course.text('thumbnail'),
              fit: BoxFit.cover,
              errorBuilder: (_, _, _) => const ColoredBox(
                color: Color(0xFFE7EEFF),
                child: Center(child: Icon(Icons.menu_book, size: 64)),
              ),
            ),
          ),
        ),
      const SizedBox(height: 20),
      Wrap(
        spacing: 8,
        children: [
          Chip(label: Text(course.text('category'))),
          Chip(label: Text(course.text('status'))),
        ],
      ),
      Text(
        course.text('title'),
        style: const TextStyle(fontSize: 30, fontWeight: FontWeight.w800),
      ),
      Text(course.text('headline')),
      const SizedBox(height: 16),
      Text(
        '${course.text('difficulty')} • ${course.text('duration')} ${course.text('unit')}',
      ),
      Text('Instructor: ${course.text('instructor')}'),
      const SizedBox(height: 24),
      coursePanel('About this course', [Text(course.text('description'))]),
      coursePanel('What you will learn', [
        for (final objective in course.data['objectives'] as List)
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(
              Icons.check_circle_outline,
              color: Color(0xFFF97316),
            ),
            title: Text('$objective'),
          ),
      ]),
      coursePanel('Curriculum • ${course.lessonCount} lessons', [
        for (final module in course.modules)
          ExpansionTile(
            title: Text('${module['title']}'),
            children: [
              for (final lesson in module['lessons'] as List)
                ListTile(
                  leading: Icon(
                    lesson['format'] == 'Video Lesson'
                        ? Icons.play_circle_outline
                        : Icons.article_outlined,
                  ),
                  title: Text('${lesson['title']}'),
                  subtitle: Text(
                    '${lesson['format']} • ${lesson['minutes']} min',
                  ),
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => Scaffold(
                        appBar: AppBar(title: Text('${lesson['title']}')),
                        body: courseBody([
                          SelectableText('${lesson['content']}'),
                        ]),
                      ),
                    ),
                  ),
                ),
            ],
          ),
      ]),
    ]),
  );
}
