import 'profile_avatar.dart';

import 'package:flutter/material.dart';

import '../auth/sign_in_repository.dart';
import 'profile_controller.dart';
import 'profile_repository.dart';
import 'enrollment_unavailable.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({
    super.key,
    required this.repository,
    required this.session,
    required this.onSaved,
    required this.onSecurity,
    this.learnerAccountDetails,
    this.enrollmentContent,
  });
  final Widget? enrollmentContent;
  final ProfileRepository repository;
  final UserSession session;
  final ValueChanged<UserSession> onSaved;
  final VoidCallback onSecurity;
  final Map<String, String> Function()? learnerAccountDetails;
  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  late final ProfileController controller = ProfileController(
    widget.repository,
    widget.session,
  )..load();
  bool leaving = false;
  final Map<String, TextEditingController> fields = {};
  @override
  void dispose() {
    controller.dispose();
    for (final field in fields.values) {
      field.dispose();
    }
    super.dispose();
  }

  Future<void> leave() async {
    if (controller.saving) return;
    if (controller.dirty) {
      final discard = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Discard changes?'),
          content: const Text('Your unsaved profile changes will be lost.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Keep Editing'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Discard'),
            ),
          ],
        ),
      );
      if (discard != true) return;
    }
    if (!mounted) return;
    setState(() => leaving = true);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) Navigator.pop(context);
    });
  }

  Future<void> save() async {
    if (await controller.save() && mounted) {
      for (final key in fields.keys) {
        fields[key]!.text = controller.profile!.text(key);
      }
      widget.onSaved(controller.session);
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Profile saved')));
    }
  }

  Widget field(String key, String label, {int lines = 1, String? prefix}) {
    final editing = fields.putIfAbsent(
      key,
      () => TextEditingController(text: controller.profile!.text(key)),
    );
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: TextField(
        controller: editing,
        enabled: !controller.saving,
        onChanged: (v) => controller.change(key, v),
        maxLines: lines,
        maxLength: key == 'bio' ? 300 : null,
        keyboardType: key == 'email'
            ? TextInputType.emailAddress
            : ['portfolio', 'linkedin', 'github'].contains(key)
            ? TextInputType.url
            : null,
        decoration: InputDecoration(
          labelText: label,
          hintText: widget.learnerAccountDetails == null
              ? null
              : 'Not provided',
          prefixText: prefix,
          errorText: controller.errors[key],
          fillColor: const Color(0xFFF0F2FF),
        ),
      ),
    );
  }

  Widget card(String title, List<Widget> children) => Container(
    margin: const EdgeInsets.only(bottom: 20),
    padding: const EdgeInsets.all(20),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(20),
    ),
    child: Material(
      color: Colors.transparent,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                width: 5,
                height: 20,
                decoration: BoxDecoration(
                  color: const Color(0xFFF97316),
                  borderRadius: BorderRadius.circular(5),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          ...children,
        ],
      ),
    ),
  );
  Future<void> addTopic() async {
    final input = TextEditingController();
    String? error;
    final topic = await showDialog<String>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, update) => AlertDialog(
          title: const Text('Add Topic'),
          content: TextField(
            controller: input,
            autofocus: true,
            decoration: InputDecoration(labelText: 'Topic', errorText: error),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                final value = input.text.trim();
                if (value.isEmpty ||
                    controller.profile!.topics.any(
                      (e) => e.toLowerCase() == value.toLowerCase(),
                    )) {
                  update(() => error = 'Enter a new, nonblank topic.');
                  return;
                }
                Navigator.pop(context, value);
              },
              child: const Text('Add'),
            ),
          ],
        ),
      ),
    );
    // The dialog route may still be animating; release its controller afterward.
    Future<void>.delayed(const Duration(seconds: 1), input.dispose);
    if (topic != null && mounted) {
      controller.change('topics', [...controller.profile!.topics, topic]);
    }
  }

  Widget avatar(String? id, {double radius = 42}) {
    final index = UserProfile.avatars.indexOf(id ?? '');
    final name = controller.profile?.fullName ?? '';
    return CircleAvatar(
      radius: radius,
      backgroundColor: const Color(0xFFFFE5D5),
      child: index < 0
          ? Text(
              name.isEmpty ? '?' : name.characters.first.toUpperCase(),
              style: TextStyle(fontSize: radius),
            )
          : ClipOval(
              child: ProfileAvatar(style: index, size: radius * 2),
            ),
    );
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: controller,
    builder: (context, _) => PopScope(
      canPop: leaving,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) leave();
      },
      child: Scaffold(
        appBar: AppBar(
          leading: IconButton(
            onPressed: controller.saving ? null : leave,
            icon: const Icon(Icons.arrow_back),
          ),
          title: Text(
            widget.learnerAccountDetails == null
                ? 'Edit Profile'
                : 'Edit Learner Profile',
          ),
          actions: [
            TextButton(
              onPressed: controller.profile == null || controller.saving
                  ? null
                  : save,
              child: Text(controller.saving ? 'Saving…' : 'Save'),
            ),
            const SizedBox(width: 12),
          ],
        ),
        body: SafeArea(
          child: controller.loading
              ? const Center(child: CircularProgressIndicator())
              : controller.profile == null
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        controller.error ?? 'Profile unavailable',
                        textAlign: TextAlign.center,
                      ),
                      FilledButton(
                        onPressed: controller.load,
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                )
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 640),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          if (controller.error != null)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 16),
                              child: Text(
                                controller.error!,
                                style: TextStyle(
                                  color: Theme.of(context).colorScheme.error,
                                ),
                              ),
                            ),
                          if (widget.learnerAccountDetails != null)
                            card('Learner Account', [
                              Text(
                                controller.profile!.fullName,
                                style: const TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const SizedBox(height: 12),
                              for (final entry
                                  in widget.learnerAccountDetails!().entries)
                                Padding(
                                  padding: const EdgeInsets.only(bottom: 8),
                                  child: Text(
                                    '${entry.key}: ${entry.value.isEmpty ? 'Not provided' : entry.value}',
                                  ),
                                ),
                            ]),
                          card('Profile Avatar', [
                            Center(
                              child: avatar(
                                controller.profile!.values['avatar'] as String?,
                              ),
                            ),
                            if (widget.learnerAccountDetails == null) ...[
                              TextButton(
                                onPressed: controller.saving
                                    ? null
                                    : () => controller.change('avatar', null),
                                child: const Text('Remove'),
                              ),
                              const Text(
                                'CHOOSE AN ILLUSTRATED AVATAR',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const SizedBox(height: 16),
                              Wrap(
                                spacing: 10,
                                runSpacing: 10,
                                children: [
                                  for (final id in UserProfile.avatars)
                                    Semantics(
                                      selected:
                                          controller
                                              .profile!
                                              .values['avatar'] ==
                                          id,
                                      child: InkWell(
                                        key: ValueKey('avatar_$id'),
                                        borderRadius: BorderRadius.circular(40),
                                        onTap: controller.saving
                                            ? null
                                            : () => controller.change(
                                                'avatar',
                                                id,
                                              ),
                                        child: Tooltip(
                                          message: id,
                                          child: Container(
                                            padding: const EdgeInsets.all(3),
                                            decoration: BoxDecoration(
                                              shape: BoxShape.circle,
                                              border: Border.all(
                                                width: 2,
                                                color:
                                                    controller
                                                            .profile!
                                                            .values['avatar'] ==
                                                        id
                                                    ? const Color(0xFFF97316)
                                                    : Colors.transparent,
                                              ),
                                            ),
                                            child: avatar(id, radius: 23),
                                          ),
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                            ],
                          ]),
                          card('Personal Information', [
                            field('first_name', 'First Name'),
                            field('last_name', 'Last Name'),
                            field('email', 'Account Email'),
                            field('headline', 'Headline / Professional Title'),
                            field(
                              'organization',
                              'Current Organization / Company',
                            ),
                            field('bio', 'Bio & Learning Goals', lines: 4),
                          ]),
                          card('Learning Focus Topics', [
                            Text('${controller.profile!.topics.length} Active'),
                            const SizedBox(height: 8),
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: [
                                for (final topic in controller.profile!.topics)
                                  InputChip(
                                    label: Text(topic),
                                    onDeleted: controller.saving
                                        ? null
                                        : () => controller.change(
                                            'topics',
                                            controller.profile!.topics
                                                .where((e) => e != topic)
                                                .toList(),
                                          ),
                                  ),
                                ActionChip(
                                  label: const Text('+ Add Topic'),
                                  onPressed: controller.saving
                                      ? null
                                      : addTopic,
                                ),
                              ],
                            ),
                            if (controller.errors['topics'] != null)
                              Text(controller.errors['topics']!),
                          ]),
                          card('Professional Links', [
                            field(
                              'linkedin',
                              'LinkedIn Profile',
                              prefix: 'linkedin.com/in/',
                            ),
                            field(
                              'github',
                              'GitHub Profile',
                              prefix: 'github.com/',
                            ),
                            field('portfolio', 'Portfolio / Website'),
                          ]),
                          card('Account & Privacy', [
                            SwitchListTile(
                              contentPadding: EdgeInsets.zero,
                              title: const Text('Public Learning Profile'),
                              value: controller.profile!.flag('public_profile'),
                              onChanged:
                                  controller.saving ||
                                      widget.learnerAccountDetails != null
                                  ? null
                                  : (v) =>
                                        controller.change('public_profile', v),
                            ),
                            SwitchListTile(
                              contentPadding: EdgeInsets.zero,
                              title: const Text(
                                'Weekly Progress & Cohort Reminders',
                              ),
                              value: controller.profile!.flag(
                                'weekly_reminders',
                              ),
                              onChanged:
                                  controller.saving ||
                                      widget.learnerAccountDetails != null
                                  ? null
                                  : (v) => controller.change(
                                      'weekly_reminders',
                                      v,
                                    ),
                            ),
                            const Text(
                              'Preferences are saved. Public profiles and reminder delivery are coming soon.',
                            ),
                            const SizedBox(height: 12),
                            if (widget.learnerAccountDetails == null)
                              ListTile(
                                contentPadding: EdgeInsets.zero,
                                leading: const Icon(Icons.lock_reset),
                                title: const Text('Password & Security'),
                                subtitle: const Text(
                                  'Reset your password using account recovery',
                                ),
                                trailing: const Icon(Icons.chevron_right),
                                onTap: controller.saving
                                    ? null
                                    : widget.onSecurity,
                              ),
                          ]),
                          Row(
                            children: [
                              Expanded(
                                child: OutlinedButton(
                                  onPressed: controller.saving ? null : leave,
                                  child: const Text('Cancel'),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                flex: 2,
                                child: FilledButton(
                                  onPressed: controller.saving ? null : save,
                                  child: Text(
                                    controller.saving
                                        ? 'Saving…'
                                        : 'Save Changes',
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 24),
                          if (widget.session.role == AccountRole.learner)
                            widget.enrollmentContent ??
                                const EnrollmentUnavailable(),
                        ],
                      ),
                    ),
                  ),
                ),
        ),
      ),
    ),
  );
}
