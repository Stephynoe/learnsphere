import '../widgets/brand_logo.dart';

import 'package:flutter/material.dart';

import 'sign_in_controller.dart';
import 'sign_in_preferences.dart';
import 'sign_in_repository.dart';

class SignInScreen extends StatefulWidget {
  const SignInScreen({
    super.key,
    required this.repository,
    required this.preferences,
    required this.onRegister,
    required this.onSignedIn,
    required this.onForgotPassword,
  });
  final SignInRepository repository;
  final SignInPreferences preferences;
  final VoidCallback onRegister;
  final Future<void> Function() onForgotPassword;
  final void Function(UserSession session, String? warning) onSignedIn;
  @override
  State<SignInScreen> createState() => _SignInScreenState();
}

class _SignInScreenState extends State<SignInScreen> {
  final _form = GlobalKey<FormState>();
  final _identity = TextEditingController(),
      _password = TextEditingController();
  late final SignInController _controller;
  bool _hidden = true;
  bool _openingRecovery = false;
  bool get _disabled =>
      _controller.busy || _controller.initializing || _openingRecovery;
  @override
  void initState() {
    super.initState();
    _controller = SignInController(widget.repository, widget.preferences);
    _restore();
  }

  Future<void> _restore() async {
    await _controller.initialize();
    if (mounted) setState(() => _identity.text = _controller.identity);
  }

  @override
  void dispose() {
    _identity.dispose();
    _password.dispose();
    _controller.dispose();
    super.dispose();
  }

  void _comingSoon(String feature) =>
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('$feature: Coming soon')));

  Future<void> _submit() async {
    if (_disabled || !_form.currentState!.validate()) return;
    FocusScope.of(context).unfocus();
    final session = await _controller.submit(_identity.text, _password.text);
    if (!mounted || session == null) return;
    _password.clear();
    widget.onSignedIn(session, _controller.preferenceWarning);
  }

  Future<void> _forgotPassword() async {
    if (_disabled) return;
    FocusScope.of(context).unfocus();
    _password.clear();
    setState(() => _openingRecovery = true);
    try {
      await widget.onForgotPassword();
    } finally {
      if (mounted) {
        _password.clear();
        setState(() => _openingRecovery = false);
      }
    }
  }

  String? _required(String? value) =>
      value == null || value.isEmpty ? 'This field is required.' : null;

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: _controller,
    builder: (context, _) => Scaffold(
      appBar: AppBar(
        centerTitle: true,
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        title: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            BrandLogo(symbol: true, height: 28),
            SizedBox(width: 8),
            Text(
              'Sign In',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
            ),
          ],
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              child: AutofillGroup(
                child: Form(
                  key: _form,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Center(child: BrandLogo(height: 64)),
                      const SizedBox(height: 22),
                      const Text(
                        'Welcome to LearnSphere',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 26,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.7,
                        ),
                      ),
                      const SizedBox(height: 10),
                      const Text(
                        'Sign in to accelerate your career or manage your academy.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Color(0xFF584237), height: 1.6),
                      ),
                      const SizedBox(height: 28),
                      SegmentedButton<AccountRole>(
                        segments: const [
                          ButtonSegment(
                            value: AccountRole.learner,
                            label: Text('Learner'),
                            icon: Icon(Icons.school_outlined),
                          ),
                          ButtonSegment(
                            value: AccountRole.admin,
                            label: Text('Administrator'),
                            icon: Icon(Icons.admin_panel_settings_outlined),
                          ),
                        ],
                        selected: {_controller.role},
                        showSelectedIcon: false,
                        onSelectionChanged: _disabled
                            ? null
                            : (roles) => setState(
                                () => _controller.role = roles.single,
                              ),
                        style: SegmentedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(
                            vertical: 14,
                            horizontal: 8,
                          ),
                          selectedBackgroundColor: Colors.white,
                          backgroundColor: const Color(0xFFE7EEFF),
                          selectedForegroundColor: const Color(0xFF9D4300),
                          side: BorderSide.none,
                        ),
                      ),
                      const SizedBox(height: 26),
                      const Text(
                        'Email or username',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextFormField(
                        key: const ValueKey('signin_identity'),
                        controller: _identity,
                        enabled: !_disabled,
                        autocorrect: false,
                        enableSuggestions: false,
                        autofillHints: const [AutofillHints.username],
                        textInputAction: TextInputAction.next,
                        validator: (value) => _required(value?.trim()),
                        autovalidateMode: AutovalidateMode.onUserInteraction,
                        decoration: const InputDecoration(
                          hintText: 'Email address or username',
                          prefixIcon: Icon(
                            Icons.alternate_email,
                            color: Color(0xFF784312),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Wrap(
                        alignment: WrapAlignment.spaceBetween,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          const Text(
                            'Password',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          TextButton(
                            onPressed: _disabled ? null : _forgotPassword,
                            child: const Text('Forgot Password?'),
                          ),
                        ],
                      ),
                      TextFormField(
                        key: const ValueKey('signin_password'),
                        controller: _password,
                        enabled: !_disabled,
                        obscureText: _hidden,
                        autocorrect: false,
                        enableSuggestions: false,
                        autofillHints: const [AutofillHints.password],
                        textInputAction: TextInputAction.done,
                        validator: _required,
                        onFieldSubmitted: (_) => _submit(),
                        decoration: InputDecoration(
                          hintText: 'Enter your password',
                          prefixIcon: const Icon(
                            Icons.lock_outline,
                            color: Color(0xFF784312),
                          ),
                          suffixIcon: IconButton(
                            tooltip: _hidden
                                ? 'Show password'
                                : 'Hide password',
                            onPressed: _disabled
                                ? null
                                : () => setState(() => _hidden = !_hidden),
                            icon: Icon(
                              _hidden
                                  ? Icons.visibility_off_outlined
                                  : Icons.visibility_outlined,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Wrap(
                        alignment: WrapAlignment.spaceBetween,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Checkbox(
                                key: const ValueKey('remember'),
                                semanticLabel: 'Remember me',
                                value: _controller.remember,
                                onChanged: _disabled
                                    ? null
                                    : (value) => _controller.setRemember(
                                        value ?? false,
                                      ),
                              ),
                              const Text(
                                'Remember me',
                                style: TextStyle(fontSize: 13),
                              ),
                            ],
                          ),
                          TextButton.icon(
                            onPressed: _disabled
                                ? null
                                : () => _comingSoon('Biometric'),
                            icon: const Icon(Icons.fingerprint, size: 18),
                            label: const Text('Biometric'),
                          ),
                        ],
                      ),
                      const Text(
                        'Remember me saves your email or username, never your password.',
                        style: TextStyle(
                          fontSize: 11,
                          color: Color(0xFF64748B),
                        ),
                      ),
                      if (_controller.error != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 16),
                          child: Semantics(
                            liveRegion: true,
                            child: Text(
                              _controller.error!,
                              style: TextStyle(
                                color: Theme.of(context).colorScheme.error,
                              ),
                            ),
                          ),
                        ),
                      if (_controller.preferenceWarning != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 12),
                          child: Text(
                            _controller.preferenceWarning!,
                            style: const TextStyle(fontSize: 12),
                          ),
                        ),
                      const SizedBox(height: 22),
                      FilledButton(
                        key: const ValueKey('signin_submit'),
                        onPressed: _disabled ? null : _submit,
                        style: FilledButton.styleFrom(
                          minimumSize: const Size.fromHeight(54),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          child: _disabled
                              ? SizedBox(
                                  width: 22,
                                  height: 22,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    semanticsLabel: _controller.initializing
                                        ? 'Loading preferences'
                                        : 'Signing in',
                                  ),
                                )
                              : const Wrap(
                                  alignment: WrapAlignment.center,
                                  spacing: 8,
                                  children: [
                                    Text('Sign In to LearnSphere'),
                                    Icon(Icons.arrow_forward, size: 20),
                                  ],
                                ),
                        ),
                      ),
                      const SizedBox(height: 20),
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF0F3FF),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _controller.role == AccountRole.learner
                                  ? 'Learner Workspace'
                                  : 'Administrator Workspace',
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              _controller.role == AccountRole.learner
                                  ? 'Your place to learn, build skills, and follow your progress.'
                                  : 'Your place to manage your academy and support your learners.',
                              style: const TextStyle(
                                fontSize: 12,
                                height: 1.5,
                                color: Color(0xFF584237),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),
                      const Row(
                        children: [
                          Expanded(child: Divider()),
                          Padding(
                            padding: EdgeInsets.symmetric(horizontal: 12),
                            child: Text(
                              'OR CONTINUE WITH',
                              style: TextStyle(fontSize: 11),
                            ),
                          ),
                          Expanded(child: Divider()),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          _social('Google', Icons.g_mobiledata),
                          const SizedBox(width: 10),
                          _social('Apple', Icons.apple),
                          const SizedBox(width: 10),
                          _social('SSO', Icons.business_outlined),
                        ],
                      ),
                      const SizedBox(height: 24),
                      TextButton(
                        key: const ValueKey('create_account'),
                        onPressed: _disabled ? null : widget.onRegister,
                        child: const Text(
                          'Don’t have an account? Create Account',
                          textAlign: TextAlign.center,
                        ),
                      ),
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

  Widget _social(String label, IconData icon) => Expanded(
    child: OutlinedButton(
      onPressed: _disabled ? null : () => _comingSoon(label),
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
