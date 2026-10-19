import 'package:flutter/material.dart';

import '../enrollment/enrollment_repository.dart';
import '../enrollment/enrollment_screens.dart';

import '../auth/sign_in_repository.dart';
import '../profile/profile_avatar.dart';
import '../profile/profile_repository.dart';
import '../profile/profile_screen.dart';
import '../profile/enrollment_unavailable.dart';
import 'admin_bottom_bar.dart';
import 'admin_learners_controller.dart';
import 'admin_learners_repository.dart';

class AdminLearnersScreen extends StatefulWidget {
  const AdminLearnersScreen({
    super.key,
    required this.repository,
    required this.session,
    required this.onAccount,
    this.onCourses,
    this.onEnrollments,
    this.enrollmentsRepository,
  });
  final AdminLearnersRepository repository;
  final UserSession session;
  final VoidCallback onAccount;
  final VoidCallback? onCourses;
  final VoidCallback? onEnrollments;
  final EnrollmentRepository? enrollmentsRepository;
  @override
  State<AdminLearnersScreen> createState() => _AdminLearnersScreenState();
}

class _AdminLearnersScreenState extends State<AdminLearnersScreen> {
  late final controller = AdminLearnersController(
    widget.repository,
    widget.session,
  )..load();
  final scroll = ScrollController();
  final search = TextEditingController();
  void scrollToTop() {
    if (scroll.hasClients) scroll.jumpTo(0);
  }

  @override
  void dispose() {
    controller.dispose();
    scroll.dispose();
    search.dispose();
    super.dispose();
  }

  Future<void> edit(LearnerSummary learner) async {
    LearnerDetails? details;
    final adapter = AdminLearnerProfileAdapter(
      widget.repository,
      widget.session,
      learner.id,
      (value) {
        details = value;
      },
    );
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => ProfileScreen(
          repository: adapter,
          enrollmentContent: widget.enrollmentsRepository == null
              ? null
              : EnrollmentPanel(
                  repository: widget.enrollmentsRepository!,
                  actor: widget.session,
                  learnerId: learner.id,
                ),
          session: UserSession(
            id: learner.id,
            fullName: learner.name,
            email: learner.email,
            username: learner.username,
            role: AccountRole.learner,
          ),
          onSaved: (_) {
            if (details != null) controller.update(details!.summary);
          },
          onSecurity: () {},
          learnerAccountDetails: () {
            final account = details?.summary ?? learner;
            final date = DateTime.tryParse(account.registeredAt ?? '');
            return {
              'User ID': '${account.id}',
              'Username': account.username,
              'Role': 'Learner',
              'Status': account.active ? 'Active' : 'Inactive',
              'Registered': date == null
                  ? 'Not provided'
                  : '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}',
            };
          },
        ),
      ),
    );
  }

  void soon(String label) =>
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('$label: Coming soon')));
  Widget learnerCard(LearnerSummary learner) {
    final style = UserProfile.avatars.indexOf(learner.avatar ?? '');
    return Card(
      color: Colors.white,
      margin: const EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: () => edit(learner),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  CircleAvatar(
                    radius: 25,
                    backgroundColor: const Color(0xFFFFE5D5),
                    child: style < 0
                        ? Text(
                            learner.name.isEmpty
                                ? '?'
                                : learner.name.characters.first.toUpperCase(),
                          )
                        : ClipOval(
                            child: ProfileAvatar(style: style, size: 50),
                          ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          learner.name,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        Text(learner.email),
                        Text('@${learner.username}'),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                learner.organization.isEmpty
                    ? 'Organization: Not provided'
                    : learner.organization,
              ),
              const SizedBox(height: 16),
              if (widget.enrollmentsRepository == null)
                const EnrollmentSummaryUnavailable()
              else
                TextButton(
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => EnrollmentScreen(
                        repository: widget.enrollmentsRepository!,
                        actor: widget.session,
                        learnerId: learner.id,
                      ),
                    ),
                  ),
                  child: const Text('View courses and assign enrollment'),
                ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 12,
                runSpacing: 8,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Chip(
                    label: Text(learner.active ? 'Active' : 'Inactive'),
                    backgroundColor: learner.active
                        ? const Color(0xFFE1F3E9)
                        : const Color(0xFFE7EEFF),
                  ),
                  FilledButton.tonalIcon(
                    onPressed: () => edit(learner),
                    icon: const Icon(Icons.edit_outlined),
                    label: const Text('Edit Profile'),
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
      title: const Text('Learner Management'),
      actions: [
        IconButton(
          onPressed: widget.onAccount,
          tooltip: 'Account',
          icon: const Icon(Icons.account_circle_outlined),
        ),
      ],
    ),
    bottomNavigationBar: AdminBottomBar(
      selected: AdminDestination.learners,
      onSelected: (destination) {
        if (destination == AdminDestination.dashboard) {
          Navigator.pop(context);
        } else if (destination == AdminDestination.more) {
          widget.onAccount();
        } else if (destination == AdminDestination.courses &&
            widget.onCourses != null) {
          widget.onCourses!();
        } else if (destination == AdminDestination.enrollments &&
            widget.onEnrollments != null) {
          widget.onEnrollments!();
        } else if (destination != AdminDestination.learners) {
          soon(destination.label);
        }
      },
    ),
    body: SafeArea(
      child: ListenableBuilder(
        listenable: controller,
        builder: (context, _) => RefreshIndicator(
          onRefresh: controller.load,
          child: ListView(
            controller: scroll,
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(16),
            children: [
              Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 800),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        'Learners${controller.learners == null ? '' : ' (${controller.learners!.length})'}',
                        style: const TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        controller: search,
                        onChanged: controller.search,
                        decoration: const InputDecoration(
                          prefixIcon: Icon(Icons.search),
                          hintText: 'Search name, email, username or company',
                        ),
                      ),
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 8,
                        children: [
                          for (final filter in LearnerFilter.values)
                            ChoiceChip(
                              label: Text(switch (filter) {
                                LearnerFilter.all => 'All Learners',
                                LearnerFilter.active => 'Active',
                                LearnerFilter.inactive => 'Inactive',
                              }),
                              selected: controller.filter == filter,
                              onSelected: (_) => controller.select(filter),
                            ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      if (controller.busy) const LinearProgressIndicator(),
                      if (controller.learners != null) ...[
                        Wrap(
                          spacing: 12,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            const Text('Items per page'),
                            DropdownButton<int>(
                              key: const ValueKey('learner_page_size'),
                              value: controller.pageSize,
                              items: [
                                for (final size
                                    in AdminLearnersController.pageSizes)
                                  DropdownMenuItem(
                                    value: size,
                                    child: Text(size == 0 ? 'All' : '$size'),
                                  ),
                              ],
                              onChanged: (value) {
                                if (value != null) {
                                  controller.setPageSize(value);
                                  scrollToTop();
                                }
                              },
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                      ],
                      if (controller.error != null) ...[
                        Text(
                          controller.error!,
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.error,
                          ),
                        ),
                        Align(
                          alignment: Alignment.centerLeft,
                          child: TextButton(
                            onPressed: controller.busy ? null : controller.load,
                            child: const Text('Retry'),
                          ),
                        ),
                      ],
                      if (controller.learners != null &&
                          controller.visible.isEmpty) ...[
                        Text(
                          controller.learners!.isEmpty
                              ? 'No learners registered yet.'
                              : 'No learners match your search or filter.',
                        ),
                        TextButton(
                          onPressed: () {
                            search.clear();
                            controller.search('');
                            controller.select(LearnerFilter.all);
                          },
                          child: const Text('Clear Search & Filters'),
                        ),
                      ],
                      for (final learner in controller.pageLearners)
                        learnerCard(learner),
                      if (controller.learners != null) ...[
                        Text(
                          controller.matchingCount == 0
                              ? 'Showing 0 of 0'
                              : 'Showing ${controller.rangeStart}–${controller.rangeEnd} of ${controller.matchingCount}',
                        ),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 12,
                          runSpacing: 8,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            OutlinedButton(
                              onPressed: controller.page <= 1
                                  ? null
                                  : () {
                                      controller.goToPage(controller.page - 1);
                                      scrollToTop();
                                    },
                              child: const Text('Previous'),
                            ),
                            Text(
                              'Page ${controller.pageCount == 0 ? 0 : controller.page} of ${controller.pageCount}',
                            ),
                            OutlinedButton(
                              onPressed: controller.page >= controller.pageCount
                                  ? null
                                  : () {
                                      controller.goToPage(controller.page + 1);
                                      scrollToTop();
                                    },
                              child: const Text('Next'),
                            ),
                          ],
                        ),
                      ],
                      if (controller.learners != null)
                        TextButton.icon(
                          onPressed: controller.busy ? null : controller.load,
                          icon: const Icon(Icons.refresh),
                          label: const Text('Refresh'),
                        ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}
