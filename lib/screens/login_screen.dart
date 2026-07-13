import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../state/session.dart';

/// The sign-in screen — the first thing every user sees.
///
/// The design: a full-bleed brand gradient with soft glow circles, and a
/// floating white card holding the form. This is a [StatefulWidget]
/// because it holds things that change while you look at it: typed text,
/// password visibility, the in-flight spinner, and any error message.
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
    const brand = Color(0xFF1C7A5A);
    const brandDark = Color(0xFF0F3625);

    return Scaffold(
      body: Stack(
        children: [
          // Brand gradient backdrop with soft glow accents.
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [brand, brandDark],
              ),
            ),
          ),
          Positioned(
            top: -90,
            right: -70,
            child: _glow(220, Colors.white.withValues(alpha: .08)),
          ),
          Positioned(
            bottom: -110,
            left: -80,
            child: _glow(280, const Color(0xFFE0A63C).withValues(alpha: .16)),
          ),

          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 430),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Brand mark.
                      Container(
                        width: 76,
                        height: 76,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: .14),
                          borderRadius: BorderRadius.circular(24),
                          border: Border.all(
                            color: Colors.white.withValues(alpha: .25),
                          ),
                        ),
                        child: const Icon(Icons.school_rounded,
                            size: 40, color: Colors.white),
                      ),
                      const SizedBox(height: 18),
                      const Text(
                        'PrimeSchoolOS',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 28,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -.5,
                        ),
                      ),
                      Text(
                        'Students · Teachers · Parents',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: .75),
                          fontWeight: FontWeight.w600,
                          fontSize: 13.5,
                        ),
                      ),
                      const SizedBox(height: 28),

                      // The floating form card.
                      Container(
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(28),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: .22),
                              blurRadius: 40,
                              offset: const Offset(0, 18),
                            ),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            const Text(
                              'Welcome back',
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            const SizedBox(height: 4),
                            const Text(
                              'Sign in with your school account',
                              style: TextStyle(
                                color: Color(0xFF6B7686),
                                fontWeight: FontWeight.w600,
                                fontSize: 13,
                              ),
                            ),
                            const SizedBox(height: 20),

                            // Error banner — only present when a login failed.
                            if (_error != null) ...[
                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFFDECEC),
                                  borderRadius: BorderRadius.circular(14),
                                ),
                                child: Row(
                                  children: [
                                    const Icon(Icons.error_outline,
                                        color: Color(0xFFB91C1C), size: 20),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: Text(
                                        _error!,
                                        style: const TextStyle(
                                          color: Color(0xFFB91C1C),
                                          fontWeight: FontWeight.w600,
                                          fontSize: 12.5,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 14),
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
                                  onPressed: () => setState(
                                      () => _hidePassword = !_hidePassword),
                                ),
                              ),
                            ),
                            const SizedBox(height: 20),

                            FilledButton(
                              onPressed: _busy ? null : _submit,
                              child: _busy
                                  ? const SizedBox(
                                      width: 22,
                                      height: 22,
                                      child: CircularProgressIndicator(
                                          strokeWidth: 2.5),
                                    )
                                  : const Text('Sign in'),
                            ),

                            // Advanced: point the app at a different server
                            // (your computer's LAN IP on a real phone).
                            TextButton.icon(
                              onPressed: () => setState(
                                  () => _showServerField = !_showServerField),
                              icon: const Icon(Icons.dns_outlined, size: 17),
                              label: Text(
                                _showServerField
                                    ? 'Hide server settings'
                                    : 'Server settings',
                                style: const TextStyle(fontSize: 12.5),
                              ),
                            ),
                            if (_showServerField)
                              TextField(
                                controller: _server,
                                keyboardType: TextInputType.url,
                                autocorrect: false,
                                decoration: const InputDecoration(
                                  labelText: 'Server URL',
                                  helperText:
                                      'On a real phone use your computer\'s IP,\ne.g. http://192.168.1.20:8020',
                                  helperMaxLines: 2,
                                  prefixIcon: Icon(Icons.link),
                                ),
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
        ],
      ),
    );
  }

  Widget _glow(double size, Color color) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(shape: BoxShape.circle, color: color),
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
