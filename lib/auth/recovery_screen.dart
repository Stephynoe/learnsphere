import 'package:flutter/material.dart';

import '../registration/registration_data.dart';
import 'recovery_controller.dart';
import 'recovery_repository.dart';

class RecoveryScreen extends StatefulWidget {
  const RecoveryScreen({super.key, required this.repository});
  final RecoveryRepository repository;
  @override
  State<RecoveryScreen> createState() => _RecoveryScreenState();
}

class _RecoveryScreenState extends State<RecoveryScreen> {
  late final RecoveryController _controller;
  final _identity = TextEditingController(),
      _answer = TextEditingController(),
      _password = TextEditingController(),
      _confirmation = TextEditingController();
  final _form = GlobalKey<FormState>();
  bool _hidePassword = true, _hideConfirmation = true;
  @override
  void initState() {
    super.initState();
    _controller = RecoveryController(widget.repository);
  }

  @override
  void dispose() {
    _controller.dispose();
    for (final field in [_identity, _answer, _password, _confirmation]) {
      field.clear();
      field.dispose();
    }
    super.dispose();
  }

  void _clearSensitive() {
    _answer.clear();
    _password.clear();
    _confirmation.clear();
  }

  void _restart() {
    if (_controller.busy) return;
    FocusScope.of(context).unfocus();
    _identity.clear();
    _clearSensitive();
    _controller.restart();
  }

  Future<void> _submit() async {
    if (_controller.busy || !(_form.currentState?.validate() ?? false)) return;
    FocusScope.of(context).unfocus();
    switch (_controller.step) {
      case RecoveryStep.identity:
        await _controller.lookup(_identity.text);
      case RecoveryStep.answer:
        await _controller.verifyAnswer(_answer.text);
      case RecoveryStep.password:
        await _controller.resetPassword(_password.text, _confirmation.text);
      case RecoveryStep.success:
        return;
    }
    if (!mounted) return;
    if (_controller.step == RecoveryStep.password) _answer.clear();
    if (_controller.step == RecoveryStep.identity ||
        _controller.step == RecoveryStep.success) {
      _clearSensitive();
    }
  }

  Widget _field(
    String id,
    String label,
    TextEditingController controller,
    String? Function(String?) validator, {
    bool secret = false,
    bool hidden = false,
    VoidCallback? toggle,
  }) => Padding(
    padding: const EdgeInsets.only(bottom: 18),
    child: TextFormField(
      key: ValueKey('recovery_$id'),
      controller: controller,
      enabled: !_controller.busy,
      validator: validator,
      autovalidateMode: AutovalidateMode.onUserInteraction,
      autocorrect: false,
      enableSuggestions: false,
      obscureText: secret && hidden,
      textInputAction: id == 'password'
          ? TextInputAction.next
          : TextInputAction.done,
      onFieldSubmitted: id == 'password' ? null : (_) => _submit(),
      autofillHints: secret ? const [AutofillHints.newPassword] : null,
      onChanged: (_) {
        _controller.clearFieldError(id);
        if (id == 'password') setState(() {});
      },
      decoration: InputDecoration(
        labelText: label,
        errorText: _controller.errorField == id ? _controller.error : null,
        prefixIcon: Icon(
          secret
              ? Icons.lock_outline
              : id == 'identity'
              ? Icons.alternate_email
              : Icons.key_outlined,
        ),
        suffixIcon: toggle == null
            ? null
            : IconButton(
                tooltip: hidden ? 'Show $label' : 'Hide $label',
                onPressed: _controller.busy ? null : toggle,
                icon: Icon(
                  hidden
                      ? Icons.visibility_off_outlined
                      : Icons.visibility_outlined,
                ),
              ),
      ),
    ),
  );

  Widget _requirements() {
    final rules = RegistrationValidation.passwordRules(_password.text);
    const labels = ['8+ characters', '1 number', '1 symbol'];
    return Padding(
      padding: const EdgeInsets.only(bottom: 18),
      child: Wrap(
        spacing: 12,
        runSpacing: 8,
        children: List.generate(
          3,
          (i) => Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                rules[i] ? Icons.check_circle : Icons.radio_button_unchecked,
                size: 16,
                color: rules[i]
                    ? const Color(0xFF087F5B)
                    : const Color(0xFF64748B),
              ),
              const SizedBox(width: 4),
              Text(labels[i], style: const TextStyle(fontSize: 12)),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: _controller,
    builder: (context, _) {
      final step = _controller.step;
      final titles = [
        'Find your account',
        'Answer your recovery question',
        'Choose a new password',
        'Password updated!',
      ];
      return PopScope(
        canPop: !_controller.busy,
        child: Scaffold(
          appBar: AppBar(
            title: const Text('Reset Password', style: TextStyle(fontSize: 18)),
            leading: IconButton(
              tooltip: 'Back to Sign In',
              icon: const Icon(Icons.arrow_back),
              onPressed: _controller.busy
                  ? null
                  : () => Navigator.of(context).pop(),
            ),
          ),
          body: SafeArea(
            child: SingleChildScrollView(
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              padding: const EdgeInsets.all(20),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 480),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const SizedBox(height: 20),
                      Icon(
                        step == RecoveryStep.success
                            ? Icons.check_circle_rounded
                            : Icons.lock_reset,
                        size: 64,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                      const SizedBox(height: 20),
                      Text(
                        titles[step.index],
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 16),
                      if (step != RecoveryStep.success) ...[
                        Text(
                          'Step ${step.index + 1} of 3',
                          textAlign: TextAlign.center,
                          style: const TextStyle(color: Color(0xFF64748B)),
                        ),
                        const SizedBox(height: 12),
                        LinearProgressIndicator(
                          value: (step.index + 1) / 3,
                          semanticsLabel: 'Password recovery progress',
                        ),
                        const SizedBox(height: 28),
                        Form(
                          key: _form,
                          child: Column(
                            key: ValueKey(step),
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              if (step == RecoveryStep.identity) ...[
                                const Text(
                                  'Enter the email address or username linked to your account.',
                                ),
                                const SizedBox(height: 20),
                                _field(
                                  'identity',
                                  'Email or username',
                                  _identity,
                                  RegistrationValidation.requiredText,
                                ),
                              ],
                              if (step == RecoveryStep.answer) ...[
                                Text(
                                  _controller.account!.question,
                                  style: const TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                const SizedBox(height: 10),
                                const Text(
                                  'Answers are not case sensitive. Spaces within your answer and punctuation must match.',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Color(0xFF64748B),
                                  ),
                                ),
                                const SizedBox(height: 20),
                                _field(
                                  'answer',
                                  'Recovery answer',
                                  _answer,
                                  RegistrationValidation.requiredText,
                                ),
                              ],
                              if (step == RecoveryStep.password) ...[
                                _field(
                                  'password',
                                  'New password',
                                  _password,
                                  RegistrationValidation.password,
                                  secret: true,
                                  hidden: _hidePassword,
                                  toggle: () => setState(
                                    () => _hidePassword = !_hidePassword,
                                  ),
                                ),
                                _requirements(),
                                _field(
                                  'confirmation',
                                  'Confirm new password',
                                  _confirmation,
                                  (value) =>
                                      RegistrationValidation.confirmation(
                                        value,
                                        _password.text,
                                      ),
                                  secret: true,
                                  hidden: _hideConfirmation,
                                  toggle: () => setState(
                                    () =>
                                        _hideConfirmation = !_hideConfirmation,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                        if (_controller.error != null &&
                            _controller.errorField == null)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 18),
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
                        FilledButton(
                          key: const ValueKey('recovery_submit'),
                          onPressed: _controller.busy ? null : _submit,
                          style: FilledButton.styleFrom(
                            minimumSize: const Size.fromHeight(54),
                          ),
                          child: _controller.busy
                              ? const SizedBox(
                                  width: 22,
                                  height: 22,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    semanticsLabel:
                                        'Processing password recovery',
                                  ),
                                )
                              : Text(switch (step) {
                                  RecoveryStep.identity => 'Find Account',
                                  RecoveryStep.answer => 'Verify Answer',
                                  _ => 'Update Password',
                                }),
                        ),
                        if (step != RecoveryStep.identity)
                          TextButton(
                            onPressed: _controller.busy ? null : _restart,
                            child: const Text('Use a different account'),
                          ),
                      ] else ...[
                        const Text(
                          'Your password has been updated. Sign in with your new password.',
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 24),
                        FilledButton(
                          onPressed: () => Navigator.of(context).pop(),
                          child: const Text('Back to Sign In'),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      );
    },
  );
}
