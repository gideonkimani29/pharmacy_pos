import 'dart:async';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import 'api_session.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key, required this.session});

  final ApiSession session;

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _formKey = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _invitationToken = TextEditingController();
  final _confirmPassword = TextEditingController();
  bool _submitting = false;
  bool _acceptingInvitation = false;
  String? _error;
  String? _message;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    _invitationToken.dispose();
    _confirmPassword.dispose();
    super.dispose();
  }

  Future<void> _signIn() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _submitting = true;
      _error = null;
      _message = null;
    });
    try {
      if (_acceptingInvitation) {
        await widget.session.acceptInvitation(token: _invitationToken.text, password: _password.text);
        if (mounted) {
          setState(() {
            _acceptingInvitation = false;
            _password.clear();
            _confirmPassword.clear();
            _invitationToken.clear();
            _message = 'Password set. You can now sign in.';
          });
        }
      } else {
        await widget.session.login(email: _email.text, password: _password.text);
      }
    } on ApiException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } on http.ClientException {
      if (mounted) setState(() => _error = 'Cannot reach the Go API. Check the URL and connection.');
    } on TimeoutException {
      if (mounted) setState(() => _error = 'The Go API did not respond in time. Try again.');
    } on FormatException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } on Exception catch (error) {
      if (mounted) setState(() => _error = 'Could not sign in: $error');
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Card(
            margin: const EdgeInsets.all(24),
            child: Padding(
              padding: const EdgeInsets.all(28),
              child: Form(
                key: _formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Icon(Icons.local_pharmacy, size: 44, color: theme.colorScheme.primary),
                    const SizedBox(height: 12),
                    Text(
                      _acceptingInvitation ? 'Set your password' : 'Sign in to Pharmacy POS',
                      textAlign: TextAlign.center,
                      style: theme.textTheme.headlineSmall,
                    ),
                    const SizedBox(height: 24),
                    if (_acceptingInvitation)
                      TextFormField(
                        controller: _invitationToken,
                        autofocus: true,
                        decoration: const InputDecoration(labelText: 'One-time invitation token'),
                        validator: (value) => value == null || value.trim().isEmpty ? 'Enter your invitation token.' : null,
                      )
                    else
                      TextFormField(
                        controller: _email,
                        autofocus: true,
                        keyboardType: TextInputType.emailAddress,
                        autofillHints: const [AutofillHints.username],
                        decoration: const InputDecoration(labelText: 'Email'),
                        validator: (value) => value == null || !value.contains('@') ? 'Enter a valid email.' : null,
                        onFieldSubmitted: (_) => _signIn(),
                      ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _password,
                      obscureText: true,
                      autofillHints: const [AutofillHints.password],
                      decoration: const InputDecoration(labelText: 'Password'),
                      validator: (value) => value == null ||
                              (_acceptingInvitation ? value.length < 12 : value.isEmpty)
                          ? _acceptingInvitation
                              ? 'Use at least 12 characters.'
                              : 'Enter your password.'
                          : null,
                      onFieldSubmitted: (_) => _signIn(),
                    ),
                    if (_acceptingInvitation) ...[
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _confirmPassword,
                        obscureText: true,
                        decoration: const InputDecoration(labelText: 'Confirm password'),
                        validator: (value) => value != _password.text ? 'Passwords do not match.' : null,
                        onFieldSubmitted: (_) => _signIn(),
                      ),
                    ],
                    if (_error != null) ...[
                      const SizedBox(height: 12),
                      Text(_error!, style: TextStyle(color: theme.colorScheme.error)),
                    ],
                    if (_message != null) ...[
                      const SizedBox(height: 12),
                      Text(_message!, style: TextStyle(color: theme.colorScheme.primary)),
                    ],
                    const SizedBox(height: 20),
                    FilledButton(
                      onPressed: _submitting ? null : _signIn,
                      child: _submitting
                          ? const SizedBox.square(
                              dimension: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : Text(_acceptingInvitation ? 'Set password' : 'Sign in'),
                    ),
                    TextButton(
                      onPressed: _submitting
                          ? null
                          : () => setState(() {
                                _acceptingInvitation = !_acceptingInvitation;
                                _error = null;
                                _message = null;
                                _formKey.currentState?.reset();
                              }),
                      child: Text(_acceptingInvitation ? 'Back to sign in' : 'Have an invitation token?'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
