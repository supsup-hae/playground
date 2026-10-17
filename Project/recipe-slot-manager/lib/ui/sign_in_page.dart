import 'package:flutter/material.dart';
import 'package:recipe_slot_manager/design/tokens.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// 이메일과 비밀번호로 로그인하거나 가입한다. 로그인하면 true 를 돌려주며 닫힌다.
class SignInPage extends StatefulWidget {
  const SignInPage({super.key, required this.auth});

  final GoTrueClient auth;

  @override
  State<SignInPage> createState() => _SignInPageState();
}

class _SignInPageState extends State<SignInPage> {
  var _email = '';
  var _password = '';
  var _busy = false;
  String? _message;

  Future<void> _submit({required bool signUp}) async {
    final email = _email.trim();
    if (email.isEmpty || _password.isEmpty) {
      setState(() => _message = '이메일과 비밀번호를 입력한다');
      return;
    }
    setState(() {
      _busy = true;
      _message = null;
    });
    try {
      final response = signUp
          ? await widget.auth.signUp(email: email, password: _password)
          : await widget.auth.signInWithPassword(
              email: email,
              password: _password,
            );
      if (!mounted) return;
      if (response.session != null) {
        Navigator.of(context).pop(true);
      } else {
        setState(() => _message = '확인 메일을 보냈다. 메일의 링크를 누른 뒤 로그인한다');
      }
    } on AuthException catch (e) {
      if (mounted) setState(() => _message = e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Supabase 로그인')),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 360),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextField(
                decoration: const InputDecoration(labelText: '이메일'),
                keyboardType: TextInputType.emailAddress,
                autofillHints: const [AutofillHints.email],
                onChanged: (v) => _email = v,
              ),
              const SizedBox(height: AppSpacing.md),
              TextField(
                decoration: const InputDecoration(labelText: '비밀번호'),
                obscureText: true,
                autofillHints: const [AutofillHints.password],
                onChanged: (v) => _password = v,
                onSubmitted: (_) => _submit(signUp: false),
              ),
              const SizedBox(height: AppSpacing.lg),
              FilledButton(
                onPressed: _busy ? null : () => _submit(signUp: false),
                child: const Text('로그인'),
              ),
              const SizedBox(height: AppSpacing.sm),
              OutlinedButton(
                onPressed: _busy ? null : () => _submit(signUp: true),
                child: const Text('가입'),
              ),
              if (_message case final message?)
                Padding(
                  padding: const EdgeInsets.only(top: AppSpacing.lg),
                  child: Text(
                    message,
                    style: const TextStyle(color: AppColors.textMuted),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
