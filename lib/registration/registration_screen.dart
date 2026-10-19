import '../widgets/brand_logo.dart';

import 'package:flutter/material.dart';

import 'registration_controller.dart';
import 'registration_data.dart';
import 'registration_repository.dart';

class RegistrationScreen extends StatefulWidget {
  const RegistrationScreen({
    super.key,
    required this.repository,
    this.onSignIn,
    this.adminMode = false,
    this.onCreated,
  });
  final RegistrationRepository repository;
  final VoidCallback? onSignIn;
  final bool adminMode;
  final VoidCallback? onCreated;
  @override
  State<RegistrationScreen> createState() => _RegistrationScreenState();
}

class _RegistrationScreenState extends State<RegistrationScreen> {
  final _form = GlobalKey<FormState>();
  final _fields = {
    for (final id in [
      'full_name',
      'email',
      'username',
      'password',
      'confirm',
      'question',
      'answer',
    ])
      id: TextEditingController(),
  };
  late final RegistrationController _controller;
  bool _terms = false, _termsError = false;
  final _hidden = {'password': true, 'confirm': true};
  String _text(String id) => _fields[id]!.text;

  @override
  void initState() {
    super.initState();
    _controller = RegistrationController(widget.repository);
  }

  @override
  void dispose() {
    for (final field in _fields.values) {
      field.dispose();
    }
    _controller.dispose();
    super.dispose();
  }

  void _notice(String title, String message) {
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Got it'),
          ),
        ],
      ),
    );
  }

  Future<void> _submit() async {
    if (_controller.busy || _controller.succeeded) return;
    final valid = _form.currentState!.validate();
    setState(() => _termsError = !widget.adminMode && !_terms);
    if (!valid || (!widget.adminMode && !_terms)) return;
    FocusScope.of(context).unfocus();
    await _controller.submit(
      RegistrationData(
        fullName: _text('full_name'),
        email: _text('email'),
        username: _text('username'),
        password: _text('password'),
        question: _text('question'),
        answer: _text('answer'),
      ),
    );
    if (!mounted) return;
    if (_controller.succeeded) {
      for (final field in _fields.values) {
        field.clear();
      }
      if (widget.adminMode) widget.onCreated?.call();
    }
  }

  Widget _field(
    String id,
    String label,
    IconData icon,
    String hint, {
    String? Function(String?)? validator,
    String? helper,
  }) {
    final secret = _hidden.containsKey(id);
    return Padding(
      padding: const EdgeInsets.only(bottom: 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
          ),
          if (helper != null)
            Text(
              helper,
              style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
            ),
          const SizedBox(height: 8),
          TextFormField(
            key: ValueKey(id),
            controller: _fields[id],
            enabled: !_controller.busy,
            validator: validator ?? RegistrationValidation.requiredText,
            autovalidateMode: AutovalidateMode.onUserInteraction,
            obscureText: secret && _hidden[id]!,
            autocorrect: id == 'full_name',
            enableSuggestions: !secret,
            keyboardType: id == 'email'
                ? TextInputType.emailAddress
                : TextInputType.text,
            textInputAction: id == 'answer'
                ? TextInputAction.done
                : TextInputAction.next,
            onFieldSubmitted: id == 'answer' ? (_) => _submit() : null,
            autofillHints: switch (id) {
              'full_name' => [AutofillHints.name],
              'email' => [AutofillHints.email],
              'username' => [AutofillHints.newUsername],
              'password' || 'confirm' => [AutofillHints.newPassword],
              _ => null,
            },
            onChanged: (_) {
              if (id == 'email' || id == 'username') {
                _controller.clearFieldError(id);
              }
              if (secret) setState(() {});
            },
            decoration: InputDecoration(
              hintText: hint,
              hintStyle: const TextStyle(
                color: Color(0xFF9B8B83),
                fontSize: 14,
              ),
              prefixIcon: Icon(icon, color: const Color(0xFF784312), size: 21),
              errorText: _controller.fieldErrors[id],
              suffixIcon: !secret
                  ? null
                  : IconButton(
                      tooltip: _hidden[id]! ? 'Show $label' : 'Hide $label',
                      onPressed: _controller.busy
                          ? null
                          : () => setState(() => _hidden[id] = !_hidden[id]!),
                      icon: Icon(
                        _hidden[id]!
                            ? Icons.visibility_off_outlined
                            : Icons.visibility_outlined,
                        size: 21,
                      ),
                    ),
            ),
          ),
          if (id == 'password') _strength(),
          if (id == 'confirm' &&
              _text(id).isNotEmpty &&
              _text(id) == _text('password'))
            const Padding(
              padding: EdgeInsets.only(top: 6),
              child: Text(
                'Passwords match',
                style: TextStyle(color: Color(0xFF087F5B), fontSize: 12),
              ),
            ),
        ],
      ),
    );
  }

  Widget _strength() {
    final rules = RegistrationValidation.passwordRules(_text('password'));
    final count = rules.where((rule) => rule).length;
    const labels = ['8+ chars', '1 number', '1 symbol'];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 10),
        Semantics(
          label: 'Password strength: $count of 3 requirements met',
          child: Row(
            children: List.generate(
              3,
              (i) => Expanded(
                child: Container(
                  height: 5,
                  margin: EdgeInsets.only(right: i == 2 ? 0 : 4),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(8),
                    color: i < count
                        ? const Color(0xFFF97316)
                        : const Color(0xFFD8E3FB),
                  ),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 6,
          children: List.generate(
            3,
            (i) => Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: const Color(0xFFF0F3FF),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    rules[i]
                        ? Icons.check_circle
                        : Icons.radio_button_unchecked,
                    size: 13,
                    color: rules[i]
                        ? const Color(0xFF087F5B)
                        : const Color(0xFF584237),
                  ),
                  const SizedBox(width: 4),
                  Text(labels[i], style: const TextStyle(fontSize: 11)),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _success() => SingleChildScrollView(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          const SizedBox(height: 60),
          const Icon(
            Icons.check_circle_rounded,
            size: 80,
            color: Color(0xFFF97316),
          ),
          const SizedBox(height: 24),
          Text(
            'Account created!',
            style: Theme.of(context).textTheme.headlineMedium,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 12),
          const Text(
            'Welcome to LearnSphere. Your learner account is ready.',
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 12),
          FilledButton(
            onPressed: widget.onSignIn,
            child: const Text('Go to Sign In'),
          ),
        ],
      ),
    ),
  );

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: _controller,
    builder: (context, _) => PopScope(
      canPop: !widget.adminMode || !_controller.busy,
      child: Scaffold(
        appBar: AppBar(
          backgroundColor: Theme.of(context).scaffoldBackgroundColor,
          centerTitle: true,
          title: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const BrandLogo(symbol: true, height: 28),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  widget.adminMode ? 'Add Learner' : 'Create Account',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ),
        ),
        body: SafeArea(
          child: _controller.succeeded
              ? _success()
              : SingleChildScrollView(
                  keyboardDismissBehavior:
                      ScrollViewKeyboardDismissBehavior.onDrag,
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 480),
                      child: AutofillGroup(
                        child: Form(
                          key: _form,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Wrap(
                                alignment: WrapAlignment.spaceBetween,
                                crossAxisAlignment: WrapCrossAlignment.center,
                                spacing: 8,
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 7,
                                    ),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFFFDBCA),
                                      borderRadius: BorderRadius.circular(24),
                                    ),
                                    child: const Text(
                                      'LEARNER ACCOUNT',
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ),
                                  if (!widget.adminMode)
                                    TextButton.icon(
                                      onPressed: () => _notice(
                                        'Need an admin account?',
                                        'Administrator and instructor accounts are provided by your organization’s manager. Learner registration cannot create an admin account.',
                                      ),
                                      icon: const Icon(
                                        Icons.help_outline,
                                        size: 18,
                                      ),
                                      label: const Text('Need Admin?'),
                                      style: TextButton.styleFrom(
                                        foregroundColor: const Color(
                                          0xFF584237,
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                              const SizedBox(height: 22),
                              const Center(child: BrandLogo(height: 64)),
                              const SizedBox(height: 20),
                              Text(
                                widget.adminMode
                                    ? 'Create Learner Account'
                                    : 'Start Learning Journey',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 26,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: -0.7,
                                ),
                              ),
                              const SizedBox(height: 10),
                              Text(
                                widget.adminMode
                                    ? 'Create an active learner account. Set an initial password and recovery details for the learner. Your administrator account will stay signed in.'
                                    : 'Build your skills and take your next step with LearnSphere.',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: Color(0xFF584237),
                                  height: 1.6,
                                ),
                              ),
                              const SizedBox(height: 30),
                              _field(
                                'full_name',
                                'Full Legal Name',
                                Icons.person_outline,
                                'e.g. Alex Morgan',
                                helper: 'For certificates',
                              ),
                              _field(
                                'email',
                                'Email Address',
                                Icons.alternate_email,
                                'alex.morgan@company.com',
                                validator: RegistrationValidation.email,
                              ),
                              _field(
                                'username',
                                'Username',
                                Icons.account_circle_outlined,
                                'e.g. alex.morgan',
                                validator: RegistrationValidation.username,
                              ),
                              _field(
                                'password',
                                'Password',
                                Icons.lock_outline,
                                'At least 8 characters',
                                validator: RegistrationValidation.password,
                              ),
                              _field(
                                'confirm',
                                'Confirm Password',
                                Icons.shield_outlined,
                                'Repeat your password',
                                validator: (value) =>
                                    RegistrationValidation.confirmation(
                                      value,
                                      _text('password'),
                                    ),
                              ),
                              _field(
                                'question',
                                'Recovery Question',
                                Icons.help_outline,
                                'Write a question you can remember',
                              ),
                              _field(
                                'answer',
                                'Recovery Answer',
                                Icons.key_outlined,
                                'Enter your answer',
                              ),
                              if (!widget.adminMode)
                                Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Checkbox(
                                      key: const ValueKey('terms'),
                                      value: _terms,
                                      onChanged: _controller.busy
                                          ? null
                                          : (value) => setState(() {
                                              _terms = value ?? false;
                                              _termsError = !_terms;
                                            }),
                                    ),
                                    Expanded(
                                      child: Padding(
                                        padding: const EdgeInsets.only(top: 12),
                                        child: Wrap(
                                          crossAxisAlignment:
                                              WrapCrossAlignment.center,
                                          children: [
                                            const Text(
                                              'I agree to LearnSphere’s ',
                                              style: TextStyle(fontSize: 12),
                                            ),
                                            _policyLink('Terms of Service'),
                                            const Text(
                                              ' and ',
                                              style: TextStyle(fontSize: 12),
                                            ),
                                            _policyLink('Privacy Policy'),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              if (_termsError)
                                Text(
                                  'Accept the terms to create your account.',
                                  style: TextStyle(
                                    color: Theme.of(context).colorScheme.error,
                                    fontSize: 12,
                                  ),
                                ),
                              if (_controller.error != null)
                                Padding(
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 12,
                                  ),
                                  child: Semantics(
                                    liveRegion: true,
                                    child: Text(
                                      _controller.error!,
                                      style: TextStyle(
                                        color: Theme.of(context)
                                            .colorScheme
                                            .error,
                                      ),
                                    ),
                                  ),
                                ),
                              const SizedBox(height: 18),
                              FilledButton(
                                key: const ValueKey('submit'),
                                onPressed: _controller.busy ? null : _submit,
                                style: FilledButton.styleFrom(
                                  minimumSize: const Size.fromHeight(54),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                ),
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 12,
                                  ),
                                  child: _controller.busy
                                      ? const SizedBox(
                                          width: 22,
                                          height: 22,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                            semanticsLabel: 'Creating account',
                                          ),
                                        )
                                      : const Wrap(
                                          alignment: WrapAlignment.center,
                                          crossAxisAlignment:
                                              WrapCrossAlignment.center,
                                          spacing: 12,
                                          children: [
                                            Text(
                                              'Create Learner Account',
                                              style: TextStyle(
                                                fontWeight: FontWeight.w700,
                                              ),
                                            ),
                                            Icon(Icons.arrow_forward, size: 20),
                                          ],
                                        ),
                                ),
                              ),
                              if (widget.adminMode)
                                TextButton(
                                  onPressed: _controller.busy
                                      ? null
                                      : () => Navigator.of(context).maybePop(),
                                  child: const Text('Cancel'),
                                ),
                              if (!widget.adminMode) ...[
                                const SizedBox(height: 26),
                                const Row(
                                  children: [
                                    Expanded(child: Divider()),
                                    Padding(
                                      padding: EdgeInsets.symmetric(
                                        horizontal: 12,
                                      ),
                                      child: Text(
                                        'OR SIGN UP WITH',
                                        style: TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ),
                                    Expanded(child: Divider()),
                                  ],
                                ),
                                const SizedBox(height: 18),
                                Row(
                                  children: [
                                    _social('Google', Icons.g_mobiledata),
                                    const SizedBox(width: 10),
                                    _social('Apple', Icons.apple),
                                    const SizedBox(width: 10),
                                    _social('SSO', Icons.business_outlined),
                                  ],
                                ),
                                const SizedBox(height: 20),
                                TextButton(
                                  onPressed: _controller.busy
                                      ? null
                                      : widget.onSignIn,
                                  child: const Text(
                                    'Already have an account? Sign In',
                                    textAlign: TextAlign.center,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
        ),
      ),
    ),
  );

  Widget _policyLink(String title) => InkWell(
    onTap: () => _notice(
      '$title — placeholder',
      'The $title content has not been supplied yet. This is a placeholder for the final policy.',
    ),
    child: Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 12,
          color: Color(0xFF9D4300),
          fontWeight: FontWeight.w600,
        ),
      ),
    ),
  );

  Widget _social(String label, IconData icon) => Expanded(
    child: OutlinedButton(
      onPressed: _controller.busy
          ? null
          : () => ScaffoldMessenger.of(context)
                .showSnackBar(SnackBar(content: Text('$label: Coming soon'))),
      style: OutlinedButton.styleFrom(
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF584237),
        side: BorderSide.none,
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 24),
          const SizedBox(height: 4),
          Text(label, style: const TextStyle(fontSize: 12)),
        ],
      ),
    ),
  );
}
