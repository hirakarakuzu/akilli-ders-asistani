import 'package:flutter/material.dart';
import '../auth.dart';
import '../core/theme/app_colors.dart';
import '../core/widgets/brand.dart';
import '../widgets.dart';

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
    final tt = Theme.of(context).textTheme;
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(gradient: dark ? AppColors.heroGradientDark : AppColors.heroGradient),
        child: Stack(children: [
          const Positioned.fill(child: SoftBlobs(intensity: 1.3)),
          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 420),
                  child: FadeSlideIn(
                    child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                      const Center(child: BrandMark(size: 64, showName: false)),
                      const SizedBox(height: 18),
                      Text('Bilge', textAlign: TextAlign.center, style: tt.displaySmall),
                      const SizedBox(height: 6),
                      Text('Notların, senin kişisel öğretmenin 🎓',
                          textAlign: TextAlign.center,
                          style: tt.bodyLarge?.copyWith(color: cs.onSurfaceVariant, fontWeight: FontWeight.w600)),
                      const SizedBox(height: 14),
                      const Center(child: SoftBadge(text: 'Yapay zekâ kendi bilgisayarında çalışır', color: AppColors.sage)),
                      const SizedBox(height: 24),
                      Container(
                        padding: const EdgeInsets.all(22),
                        decoration: BoxDecoration(
                          color: cs.surfaceContainerLow,
                          borderRadius: BorderRadius.circular(28),
                          border: Border.all(color: cs.outlineVariant),
                          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: .08), blurRadius: 40, offset: const Offset(0, 12))],
                        ),
                        child: Form(
                          key: _form,
                          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                            Text(register ? 'Hesap oluştur ✨' : 'Tekrar hoş geldin 👋', style: tt.titleLarge),
                            const SizedBox(height: 4),
                            Text(register ? 'Birkaç saniyede başla.' : 'Kaldığın yerden devam edelim.',
                                style: TextStyle(color: cs.onSurfaceVariant)),
                            const SizedBox(height: 18),
                            if (register) ...[
                              TextFormField(
                                controller: _name,
                                decoration: const InputDecoration(labelText: 'Ad Soyad', prefixIcon: Icon(Icons.person_outline)),
                                validator: (v) => (v == null || v.trim().length < 2) ? 'Adınızı girin' : null,
                              ),
                              const SizedBox(height: 12),
                            ],
                            TextFormField(
                              controller: _email,
                              keyboardType: TextInputType.emailAddress,
                              decoration: const InputDecoration(labelText: 'E-posta', prefixIcon: Icon(Icons.mail_outline)),
                              validator: (v) {
                                final t = v?.trim() ?? '';
                                if (t.isEmpty) return 'E-posta girin';
                                if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(t)) return 'Geçerli bir e-posta girin';
                                return null;
                              },
                            ),
                            const SizedBox(height: 12),
                            TextFormField(
                              controller: _pw,
                              obscureText: hide,
                              decoration: InputDecoration(
                                labelText: 'Şifre',
                                prefixIcon: const Icon(Icons.lock_outline),
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
                            const SizedBox(height: 18),
                            GradientButton(
                              onPressed: loading ? null : _submit,
                              child: loading
                                  ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.white))
                                  : Text(register ? 'Kayıt ol' : 'Giriş yap'),
                            ),
                          ]),
                        ),
                      ),
                      const SizedBox(height: 10),
                      TextButton(
                        onPressed: loading
                            ? null
                            : () => setState(() {
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
        ]),
      ),
    );
  }
}
