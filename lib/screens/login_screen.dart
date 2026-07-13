import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../state/session.dart';

/// The sign-in screen — the first thing every user sees.
///
/// This is a [StatefulWidget] because it holds things that change while
/// you look at it: what's typed in the fields, whether the password is
/// hidden, whether a login is in flight, and any error message.
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  // Controllers read what the user typed into each TextField.
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _server = TextEditingController(text: Session.defaultBaseUrl);

  bool _busy = false;
  bool _hidePassword = true;
  bool _showServerField = false;
  String? _error;

  Future<void> _submit() async {
    // setState tells Flutter "state changed — repaint this screen".
    setState(() {
      _busy = true;
      _error = null;
    });

    try {
      // context.read = grab the Session once, without subscribing.
      await context.read<Session>().login(
            baseUrl: _server.text.trim().replaceAll(RegExp(r'/+$'), ''),
            email: _email.text.trim(),
            password: _password.text,
          );
      // Nothing else to do! main.dart watches the Session and swaps
      // this screen for the dashboard the moment login succeeds.
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(28),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Icon(Icons.school_rounded, size: 64, color: colors.primary),
                  const SizedBox(height: 12),
                  Text(
                    'PrimeSchoolOS',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                          fontWeight: FontWeight.w800,
                          color: colors.primary,
                        ),
                  ),
                  Text(
                    'Students · Teachers · Parents',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: colors.onSurfaceVariant,
                        ),
                  ),
                  const SizedBox(height: 32),

                  // Error banner — only present when a login failed.
                  if (_error != null) ...[
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: colors.errorContainer,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        _error!,
                        style: TextStyle(color: colors.onErrorContainer),
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],

                  TextField(
                    controller: _email,
                    keyboardType: TextInputType.emailAddress,
                    autocorrect: false,
                    decoration: const InputDecoration(
                      labelText: 'Email',
                      prefixIcon: Icon(Icons.mail_outline),
                    ),
                  ),
                  const SizedBox(height: 14),
                  TextField(
                    controller: _password,
                    obscureText: _hidePassword,
                    onSubmitted: (_) => _busy ? null : _submit(),
                    decoration: InputDecoration(
                      labelText: 'Password',
                      prefixIcon: const Icon(Icons.lock_outline),
                      suffixIcon: IconButton(
                        icon: Icon(_hidePassword
                            ? Icons.visibility_outlined
                            : Icons.visibility_off_outlined),
                        onPressed: () =>
                            setState(() => _hidePassword = !_hidePassword),
                      ),
                    ),
                  ),
                  const SizedBox(height: 22),

                  FilledButton(
                    onPressed: _busy ? null : _submit,
                    child: _busy
                        ? const SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(strokeWidth: 2.5),
                          )
                        : const Text('Sign in'),
                  ),

                  const SizedBox(height: 18),

                  // Advanced: point the app at a different server (your
                  // computer's LAN IP when testing on a real phone).
                  TextButton.icon(
                    onPressed: () =>
                        setState(() => _showServerField = !_showServerField),
                    icon: const Icon(Icons.dns_outlined, size: 18),
                    label: Text(_showServerField
                        ? 'Hide server settings'
                        : 'Server settings'),
                  ),
                  if (_showServerField)
                    TextField(
                      controller: _server,
                      keyboardType: TextInputType.url,
                      autocorrect: false,
                      decoration: const InputDecoration(
                        labelText: 'Server URL',
                        helperText:
                            'On a real phone use your computer\'s IP, e.g. http://192.168.1.20:8020',
                        prefixIcon: Icon(Icons.link),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    // Controllers hold native resources — always release them.
    _email.dispose();
    _password.dispose();
    _server.dispose();
    super.dispose();
  }
}
