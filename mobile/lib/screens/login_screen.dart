import 'package:flutter/material.dart';
import '../auth.dart';

class LoginScreen extends StatefulWidget {
  final VoidCallback onLoggedIn;
  const LoginScreen({super.key, required this.onLoggedIn});
  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _form = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _pw = TextEditingController();
  bool register = false;
  bool loading = false;
  bool hide = true;
  String? error;

  Future<void> _submit() async {
    if (!_form.currentState!.validate()) return;
    setState(() {
      loading = true;
      error = null;
    });
    final err = register
        ? await AuthService.register(_name.text.trim(), _email.text.trim(), _pw.text)
        : await AuthService.login(_email.text.trim(), _pw.text);
    if (!mounted) return;
    if (err != null) {
      setState(() {
        error = err;
        loading = false;
      });
    } else {
      widget.onLoggedIn();
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Form(
                key: _form,
                child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                  Icon(Icons.school_rounded, size: 72, color: cs.primary),
                  const SizedBox(height: 12),
                  Text('Akıllı Ders Asistanı',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700)),
                  const SizedBox(height: 4),
                  Text(register ? 'Yeni hesap oluştur' : 'Hesabınla giriş yap',
                      textAlign: TextAlign.center, style: TextStyle(color: cs.outline)),
                  const SizedBox(height: 28),
                  if (register) ...[
                    TextFormField(
                      controller: _name,
                      decoration: const InputDecoration(labelText: 'Ad Soyad', prefixIcon: Icon(Icons.person_outline), border: OutlineInputBorder()),
                      validator: (v) => (v == null || v.trim().length < 2) ? 'Adınızı girin' : null,
                    ),
                    const SizedBox(height: 14),
                  ],
                  TextFormField(
                    controller: _email,
                    keyboardType: TextInputType.emailAddress,
                    decoration: const InputDecoration(labelText: 'E-posta', prefixIcon: Icon(Icons.mail_outline), border: OutlineInputBorder()),
                    validator: (v) {
                      final t = v?.trim() ?? '';
                      if (t.isEmpty) return 'E-posta girin';
                      if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(t)) return 'Geçerli bir e-posta girin';
                      return null;
                    },
                  ),
                  const SizedBox(height: 14),
                  TextFormField(
                    controller: _pw,
                    obscureText: hide,
                    decoration: InputDecoration(
                      labelText: 'Şifre',
                      prefixIcon: const Icon(Icons.lock_outline),
                      border: const OutlineInputBorder(),
                      suffixIcon: IconButton(
                        icon: Icon(hide ? Icons.visibility_off : Icons.visibility),
                        onPressed: () => setState(() => hide = !hide),
                      ),
                    ),
                    validator: (v) => (v == null || v.length < 6) ? 'Şifre en az 6 karakter olmalı' : null,
                  ),
                  if (error != null) ...[
                    const SizedBox(height: 12),
                    Text(error!, style: TextStyle(color: cs.error), textAlign: TextAlign.center),
                  ],
                  const SizedBox(height: 20),
                  FilledButton(
                    onPressed: loading ? null : _submit,
                    style: FilledButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 16)),
                    child: loading
                        ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2))
                        : Text(register ? 'Kayıt ol' : 'Giriş yap'),
                  ),
                  TextButton(
                    onPressed: loading ? null : () => setState(() {
                      register = !register;
                      error = null;
                    }),
                    child: Text(register ? 'Zaten hesabım var' : 'Hesabın yok mu? Kayıt ol'),
                  ),
                ]),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
