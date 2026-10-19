import '../widgets/brand_logo.dart';
import '../enrollment/enrollment_repository.dart';
import '../enrollment/enrollment_screens.dart';

import 'package:flutter/material.dart';

import '../admin/admin_courses_repository.dart';
import '../auth/sign_in_repository.dart';
import '../data/jsonbin_store.dart';
import '../profile/profile_avatar.dart';
import '../profile/profile_repository.dart';
import 'learner_courses_repository.dart';

const _ink = Color(0xFF30251F);
const _orange = Color(0xFFAC4800);

class LearnerDashboardScreen extends StatefulWidget {
  const LearnerDashboardScreen({
    super.key,
    this.repository,
    this.enrollmentsRepository,
    this.profileRepository,
    required this.session,
    required this.onSignOut,
    this.onEditProfile,
    this.warning,
  });
  final EnrollmentRepository? enrollmentsRepository;
  final LearnerCoursesRepository? repository;
  final ProfileRepository? profileRepository;
  final UserSession session;
  final VoidCallback onSignOut;
  final Future<UserSession> Function(UserSession)? onEditProfile;
  final String? warning;
  @override
  State<LearnerDashboardScreen> createState() => _LearnerDashboardScreenState();
}

class _LearnerDashboardScreenState extends State<LearnerDashboardScreen> {
  late UserSession session = widget.session;
  List<Course>? courses;
  EnrollmentSnapshot? enrollments;
  int enrollmentRevision = 0;
  String? enrollmentLoadError;
  String? error;
  bool loading = false;
  int tab = 0, avatar = 0;
  final queries = ['', ''];
  final categories = ['', ''];
  final difficulties = ['', ''];
  @override
  void initState() {
    super.initState();
    load();
    loadAvatar();
  }

  Future<void> loadAvatar() async {
    try {
      final profile = await widget.profileRepository?.load(session);
      final index = UserProfile.avatars.indexOf(profile?.text('avatar') ?? '');
      if (mounted) setState(() => avatar = index < 0 ? 0 : index);
    } catch (_) {
      /* Profile availability does not block discovery. */
    }
  }

  Future<void> load() async {
    if (loading) return;
    setState(() {
      loading = true;
      error = null;
    });
    try {
      final repo = widget.repository;
      if (repo == null) {
        throw const JsonBinException('Course discovery is not configured.');
      }
      final values = publishedCourses(await repo.list(session));
      if (mounted) setState(() => courses = values);
    } catch (e) {
      if (mounted) {
        setState(
          () => error = e is JsonBinException
              ? e.message
              : 'Unable to load courses. Please try again.',
        );
      }
    } finally {
      if (mounted) setState(() => loading = false);
    }
    if (widget.enrollmentsRepository != null) {
      try {
        final data = await widget.enrollmentsRepository!.load(session);
        if (mounted) {
          setState(() {
            enrollments = data;
            enrollmentRevision++;
            enrollmentLoadError = null;
          });
        }
      } catch (e) {
        if (mounted) setState(() => enrollmentLoadError = enrollmentError(e));
      }
    }
  }

  void notice(String feature) =>
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('$feature coming soon')));
  Future<void> editProfile() async {
    if (widget.onEditProfile == null) return;
    final updated = await widget.onEditProfile!(session);
    if (!mounted) return;
    setState(() => session = updated);
    await loadAvatar();
    if (mounted) await load();
  }

  void account() => showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    builder: (sheet) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              session.fullName,
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),
            Text(session.email),
            const Text('Learner'),
            const SizedBox(height: 16),
            TextButton(
              onPressed: () {
                Navigator.pop(sheet);
                editProfile();
              },
              child: const Text('Edit Profile'),
            ),
            FilledButton(
              key: const ValueKey('signout'),
              onPressed: () {
                Navigator.pop(sheet);
                widget.onSignOut();
              },
              child: const Text('Sign Out'),
            ),
          ],
        ),
      ),
    ),
  );
  List<String> options(String key) =>
      (courses ?? [])
          .map((c) => c.text(key))
          .where((s) => s.isNotEmpty)
          .toSet()
          .toList()
        ..sort();
  Future<void> filters() async {
    var category = categories[tab], difficulty = difficulties[tab];
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (sheet) => StatefulBuilder(
        builder: (context, update) => SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  'Filter courses',
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                ),
                DropdownButtonFormField<String>(
                  initialValue: options('category').contains(category)
                      ? category
                      : '',
                  decoration: const InputDecoration(labelText: 'Category'),
                  items: [
                    const DropdownMenuItem(
                      value: '',
                      child: Text('All categories'),
                    ),
                    ...options('category')
                        .map((s) => DropdownMenuItem(value: s, child: Text(s))),
                  ],
                  onChanged: (v) => update(() => category = v!),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: options('difficulty').contains(difficulty)
                      ? difficulty
                      : '',
                  decoration: const InputDecoration(labelText: 'Difficulty'),
                  items: [
                    const DropdownMenuItem(
                      value: '',
                      child: Text('All levels'),
                    ),
                    ...options('difficulty')
                        .map((s) => DropdownMenuItem(value: s, child: Text(s))),
                  ],
                  onChanged: (v) => update(() => difficulty = v!),
                ),
                const SizedBox(height: 16),
                FilledButton(
                  onPressed: () {
                    setState(() {
                      categories[tab] = category;
                      difficulties[tab] = difficulty;
                    });
                    Navigator.pop(sheet);
                  },
                  child: const Text('Apply filters'),
                ),
                TextButton(
                  onPressed: () {
                    setState(() {
                      categories[tab] = '';
                      difficulties[tab] = '';
                    });
                    Navigator.pop(sheet);
                  },
                  child: const Text('Clear filters'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> details(Course course) async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => widget.enrollmentsRepository == null
            ? LearnerCourseDetails(course: course)
            : EnrollmentCourseScreen(
                repository: widget.enrollmentsRepository!,
                actor: session,
                courseId: course.id,
              ),
      ),
    );
    if (mounted) await load();
  }

  Widget heading(String title, [Widget? action]) => Padding(
    padding: const EdgeInsets.only(top: 22, bottom: 12),
    child: Row(
      children: [
        Expanded(
          child: Text(
            title,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: _ink,
            ),
          ),
        ),
        ?action,
      ],
    ),
  );
  Widget panel(Widget child) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(18),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(20),
    ),
    child: child,
  );
  Widget empty(String title, String description) => panel(
    Column(
      children: [
        const Icon(Icons.menu_book_outlined, size: 32, color: _orange),
        const SizedBox(height: 10),
        Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
        const SizedBox(height: 6),
        Text(description, textAlign: TextAlign.center),
      ],
    ),
  );
  Widget catalog(int index) {
    final query = queries[index].trim().toLowerCase();
    final filtered = (courses ?? [])
        .where(
          (c) =>
              (categories[index].isEmpty ||
                  categories[index] == c.text('category')) &&
              (difficulties[index].isEmpty ||
                  difficulties[index] == c.text('difficulty')) &&
              [
                'title',
                'headline',
                'category',
                'instructor',
              ].map(c.text).join(' ').toLowerCase().contains(query),
        )
        .toList();
    return RefreshIndicator(
      onRefresh: load,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        key: PageStorageKey('learner-tab-$index'),
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
        children: [
          if (index == 0) ...[
            heading(
              'Welcome back, ${session.fullName.trim().split(' ').first}',
            ),
            const Text('Continue your learning journey today'),
          ] else
            heading('Explore Courses'),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: TextFormField(
                  key: ValueKey('search-$index'),
                  initialValue: queries[index],
                  onChanged: (v) => setState(() => queries[index] = v),
                  decoration: InputDecoration(
                    hintText: 'Search courses, topics, skills...',
                    prefixIcon: const Icon(Icons.search),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(28),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              IconButton.filledTonal(
                tooltip: 'Filter courses',
                onPressed: filters,
                icon: const Icon(Icons.tune),
              ),
            ],
          ),
          if (widget.warning != null)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Text(widget.warning!),
            ),
          if (index == 0) ...[
            const SizedBox(height: 20),
            panel(
              Row(
                children: [
                  for (final label in [
                    'In Progress',
                    'Completed',
                    'Logged',
                    'Day Streak',
                  ])
                    Expanded(
                      child: Column(
                        children: [
                          Text(
                            enrollments == null
                                ? '—'
                                : label == 'In Progress'
                                ? '${enrollments!.enrollments.where((e) => e.status(enrollments!.course(e.courseId)) == 'In progress').length}'
                                : label == 'Completed'
                                ? '${enrollments!.enrollments.where((e) => e.status(enrollments!.course(e.courseId)) == 'Completed').length}'
                                : '—',
                            style: const TextStyle(
                              fontSize: 24,
                              color: _orange,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            label,
                            textAlign: TextAlign.center,
                            style: const TextStyle(fontSize: 11),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
            heading('Continue Learning'),
            if (widget.enrollmentsRepository != null) ...[
              if (enrollmentLoadError != null) Text(enrollmentLoadError!),
              EnrollmentPanel(
                key: ValueKey(enrollmentRevision),
                repository: widget.enrollmentsRepository!,
                actor: session,
                compact: true,
                onChanged: load,
              ),
            ] else
              empty(
                'Your learning journey starts here',
                'Enrollment services are unavailable. You can still explore the catalog below.',
              ),
            if (courses != null && courses!.isNotEmpty) ...[
              heading('Course Spotlight'),
              Container(
                padding: const EdgeInsets.all(22),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFFA13D00), Color(0xFF74452D)],
                  ),
                  borderRadius: BorderRadius.circular(22),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'DISCOVER SOMETHING NEW',
                      style: TextStyle(color: Colors.white70, fontSize: 12),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      courses!.first.text('title'),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      courses!.first.text('instructor'),
                      style: const TextStyle(color: Colors.white),
                    ),
                    const SizedBox(height: 16),
                    FilledButton.tonal(
                      onPressed: () => details(courses!.first),
                      child: const Text('Explore Course'),
                    ),
                  ],
                ),
              ),
            ],
          ],
          heading('Browse Categories'),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                for (final value in ['', ...options('category')])
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      label: Text(value.isEmpty ? 'All categories' : value),
                      selected: categories[index] == value,
                      onSelected: (_) =>
                          setState(() => categories[index] = value),
                    ),
                  ),
              ],
            ),
          ),
          heading(
            index == 0 ? 'Discover Courses' : 'Published Courses',
            IconButton(
              tooltip: 'Refresh courses',
              onPressed: loading ? null : load,
              icon: const Icon(Icons.refresh),
            ),
          ),
          if (loading)
            const Padding(
              padding: EdgeInsets.all(20),
              child: Center(child: CircularProgressIndicator()),
            ),
          if (error != null)
            panel(
              Column(
                children: [
                  Text(error!),
                  TextButton(onPressed: load, child: const Text('Retry')),
                ],
              ),
            ),
          if (!loading && courses != null && courses!.isEmpty)
            empty(
              'No published courses yet',
              'Check back soon for new learning opportunities.',
            ),
          if (courses != null && courses!.isNotEmpty && filtered.isEmpty)
            empty(
              'No matching courses',
              'Try another search or clear your category and difficulty filters.',
            ),
          for (final course in filtered)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Card(
                color: Colors.white,
                elevation: 0,
                clipBehavior: Clip.antiAlias,
                child: InkWell(
                  onTap: () => details(course),
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        CourseThumbnail(course: course, size: 76),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                course.text('category'),
                                style: const TextStyle(
                                  color: _orange,
                                  fontSize: 12,
                                ),
                              ),
                              const SizedBox(height: 5),
                              Text(
                                course.text('title'),
                                style: const TextStyle(
                                  fontWeight: FontWeight.w800,
                                  fontSize: 16,
                                ),
                              ),
                              const SizedBox(height: 5),
                              Text(course.text('instructor')),
                              Text(
                                '${course.text('difficulty')} · ${course.text('duration')} ${course.text('unit')}',
                                style: const TextStyle(fontSize: 12),
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
          if (index == 0) ...[
            heading('Your Weekly Goal'),
            empty(
              'Build your learning habit',
              'Study goals and learning time tracking are coming soon.',
            ),
          ],
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: const Color(0xFFFFF8F3),
    appBar: AppBar(
      automaticallyImplyLeading: false,
      backgroundColor: const Color(0xFFFFF8F3),
      title: const BrandLogo(height: 36),
      actions: [
        IconButton(
          tooltip: 'Notifications',
          onPressed: () => notice('Notifications'),
          icon: const Icon(Icons.notifications_outlined),
        ),
        IconButton(
          tooltip: 'Account profile',
          onPressed: account,
          icon: ProfileAvatar(style: avatar, size: 32),
        ),
      ],
    ),
    body: Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 960),
        child: IndexedStack(index: tab, children: [catalog(0), catalog(1)]),
      ),
    ),
    bottomNavigationBar: NavigationBar(
      selectedIndex: tab,
      onDestinationSelected: (value) async {
        if (value < 2) {
          setState(() => tab = value);
        } else if (value == 2 && widget.enrollmentsRepository != null) {
          await Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (_) => EnrollmentScreen(
                repository: widget.enrollmentsRepository!,
                actor: session,
              ),
            ),
          );
          if (mounted) await load();
        } else if (value == 4) {
          editProfile();
        } else {
          notice(value == 2 ? 'My Learning' : 'Saved courses');
        }
      },
      destinations: const [
        NavigationDestination(icon: Icon(Icons.home_outlined), label: 'Home'),
        NavigationDestination(
          icon: Icon(Icons.explore_outlined),
          label: 'Explore',
        ),
        NavigationDestination(
          icon: Icon(Icons.menu_book_outlined),
          label: 'Learning',
        ),
        NavigationDestination(
          icon: Icon(Icons.bookmark_border),
          label: 'Saved',
        ),
        NavigationDestination(
          icon: Icon(Icons.person_outline),
          label: 'Profile',
        ),
      ],
    ),
  );
}

class CourseThumbnail extends StatelessWidget {
  const CourseThumbnail({super.key, required this.course, required this.size});
  final Course course;
  final double size;
  @override
  Widget build(BuildContext context) {
    final fallback = Container(
      width: size,
      height: size,
      color: const Color(0xFFFFE6D4),
      child: const Icon(Icons.school_outlined, color: _orange, size: 32),
    );
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: validWebUrl(course.text('thumbnail'))
          ? Image.network(
              course.text('thumbnail'),
              width: size,
              height: size,
              fit: BoxFit.cover,
              errorBuilder: (_, _, _) => fallback,
            )
          : fallback,
    );
  }
}

class LearnerCourseDetails extends StatelessWidget {
  const LearnerCourseDetails({super.key, required this.course});
  final Course course;
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Course Details')),
    body: Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 800),
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            Align(
              alignment: Alignment.centerLeft,
              child: CourseThumbnail(course: course, size: 140),
            ),
            const SizedBox(height: 20),
            Text(
              course.text('title'),
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            Text(course.text('headline')),
            const SizedBox(height: 16),
            Text('Instructor: ${course.text('instructor')}'),
            Text('${course.text('category')} · ${course.text('difficulty')}'),
            Text('${course.text('duration')} ${course.text('unit')}'),
            const SizedBox(height: 24),
            Text(
              'About this course',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            Text(course.text('description')),
            const SizedBox(height: 24),
            Text(
              'What you will learn',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            for (final objective in course.data['objectives'] as List)
              ListTile(
                leading: const Icon(Icons.check_circle_outline),
                title: Text('$objective'),
              ),
            const SizedBox(height: 16),
            Text(
              'Course curriculum',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            for (final module in course.modules)
              ExpansionTile(
                title: Text(module['title'] as String),
                children: [
                  for (final lesson in module['lessons'] as List)
                    ListTile(
                      leading: const Icon(Icons.lock_outline),
                      title: Text(lesson['title'] as String),
                    ),
                ],
              ),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: null,
              child: const Text('Enrollment unavailable'),
            ),
          ],
        ),
      ),
    ),
  );
}
