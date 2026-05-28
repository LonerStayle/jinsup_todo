import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme.dart';
import 'auth_service.dart';

/// 이메일 OTP 6자리 코드 흐름. 두 단계:
///   1) 이메일 입력 → "코드 받기" → 코드 발송
///   2) 6자리 코드 입력 → "확인" → 세션 생성
///
/// 매직링크가 아니라 OTP — Supabase Site URL 이 다른 앱과 공유 불가능한 제약을 우회.
class SignInScreen extends ConsumerStatefulWidget {
  const SignInScreen({super.key});

  @override
  ConsumerState<SignInScreen> createState() => _SignInScreenState();
}

enum _Step { email, otp }

class _SignInScreenState extends ConsumerState<SignInScreen> {
  final _emailCtrl = TextEditingController();
  final _otpCtrl = TextEditingController();
  _Step _step = _Step.email;
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _emailCtrl.dispose();
    _otpCtrl.dispose();
    super.dispose();
  }

  bool get _canSendEmail {
    final v = _emailCtrl.text.trim();
    return v.contains('@') && v.length >= 5 && !_busy;
  }

  bool get _canVerify => _otpCtrl.text.trim().length == 6 && !_busy;

  Future<void> _sendCode() async {
    final auth = ref.read(authServiceProvider);
    if (auth == null || !_canSendEmail) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await auth.sendEmailOtp(_emailCtrl.text);
      if (!mounted) return;
      setState(() {
        _busy = false;
        _step = _Step.otp;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = '코드 발송에 실패했어요. 잠시 후 다시 시도해 주십시오.\n($e)';
      });
    }
  }

  Future<void> _verify() async {
    final auth = ref.read(authServiceProvider);
    if (auth == null || !_canVerify) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await auth.verifyEmailOtp(email: _emailCtrl.text, token: _otpCtrl.text);
      // 성공 시 authStateProvider 가 signedIn emit → _AuthGate 가 AppShell 로 전환.
      // 별도 navigation 불필요.
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = '코드가 일치하지 않거나 만료됐어요. 다시 입력하거나 새 코드를 받아주십시오.\n($e)';
      });
    }
  }

  void _backToEmail() {
    setState(() {
      _step = _Step.email;
      _otpCtrl.clear();
      _error = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 360),
            child: Padding(
              padding: const EdgeInsets.all(AppTokens.space24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Icon(
                    Icons.check_circle_outline_rounded,
                    size: 48,
                    color: theme.colorScheme.primary,
                  ),
                  const SizedBox(height: AppTokens.space16),
                  Text(
                    'Solo Todo',
                    style: theme.textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: AppTokens.space8),
                  Text(
                    _step == _Step.email
                        ? '이메일로 6자리 코드를 보내드릴게요.'
                        : '메일로 받은 6자리 코드를 입력해 주십시오.',
                    style: theme.textTheme.bodyMedium,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: AppTokens.space24),
                  if (_step == _Step.email)
                    ..._emailFields(theme)
                  else
                    ..._otpFields(theme),
                  if (_error != null) ...[
                    const SizedBox(height: AppTokens.space12),
                    Text(
                      _error!,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.error,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  List<Widget> _emailFields(ThemeData theme) {
    return [
      TextField(
        controller: _emailCtrl,
        keyboardType: TextInputType.emailAddress,
        autofillHints: const [AutofillHints.email],
        autofocus: true,
        enabled: !_busy,
        onChanged: (_) => setState(() {}),
        onSubmitted: (_) => _sendCode(),
        decoration: const InputDecoration(
          hintText: 'you@example.com',
          prefixIcon: Icon(Icons.email_outlined),
        ),
      ),
      const SizedBox(height: AppTokens.space12),
      FilledButton(
        onPressed: _canSendEmail ? _sendCode : null,
        style: FilledButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: AppTokens.space12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppTokens.radiusM),
          ),
        ),
        child: _busy
            ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              )
            : const Text('코드 받기'),
      ),
    ];
  }

  List<Widget> _otpFields(ThemeData theme) {
    return [
      Container(
        padding: const EdgeInsets.all(AppTokens.space12),
        decoration: BoxDecoration(
          color: theme.colorScheme.primary.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(AppTokens.radiusM),
        ),
        child: Row(
          children: [
            Icon(
              Icons.mark_email_read_outlined,
              color: theme.colorScheme.primary,
            ),
            const SizedBox(width: AppTokens.space12),
            Expanded(
              child: Text(
                '${_emailCtrl.text.trim()} 으로 코드를 보냈어요',
                style: theme.textTheme.bodyMedium,
              ),
            ),
          ],
        ),
      ),
      const SizedBox(height: AppTokens.space12),
      TextField(
        controller: _otpCtrl,
        keyboardType: TextInputType.number,
        autofillHints: const [AutofillHints.oneTimeCode],
        autofocus: true,
        enabled: !_busy,
        maxLength: 6,
        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
        onChanged: (_) => setState(() {}),
        onSubmitted: (_) => _verify(),
        textAlign: TextAlign.center,
        style: theme.textTheme.headlineMedium?.copyWith(
          letterSpacing: 8,
          fontWeight: FontWeight.w700,
        ),
        decoration: const InputDecoration(hintText: '000000', counterText: ''),
      ),
      const SizedBox(height: AppTokens.space12),
      FilledButton(
        onPressed: _canVerify ? _verify : null,
        style: FilledButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: AppTokens.space12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppTokens.radiusM),
          ),
        ),
        child: _busy
            ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              )
            : const Text('확인'),
      ),
      const SizedBox(height: AppTokens.space8),
      TextButton(
        onPressed: _busy ? null : _backToEmail,
        child: const Text('다른 이메일로 다시'),
      ),
    ];
  }
}
