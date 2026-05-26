import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme.dart';
import 'auth_service.dart';

/// 이메일 매직링크 발송 화면. Supabase 가 enabled 일 때만 노출 (_AuthGate 가 분기).
class SignInScreen extends ConsumerStatefulWidget {
  const SignInScreen({super.key});

  @override
  ConsumerState<SignInScreen> createState() => _SignInScreenState();
}

class _SignInScreenState extends ConsumerState<SignInScreen> {
  final _ctrl = TextEditingController();
  bool _sending = false;
  bool _sent = false;
  String? _error;

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  bool get _canSubmit {
    final v = _ctrl.text.trim();
    return v.contains('@') && v.length >= 5 && !_sending;
  }

  Future<void> _submit() async {
    final auth = ref.read(authServiceProvider);
    if (auth == null || !_canSubmit) return;
    setState(() {
      _sending = true;
      _error = null;
    });
    try {
      await auth.signInWithEmailOtp(_ctrl.text);
      if (!mounted) return;
      setState(() {
        _sending = false;
        _sent = true;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _sending = false;
        _error = '메일 전송에 실패했어요. 잠시 후 다시 시도해 주십시오.\n($e)';
      });
    }
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
                    '이메일로 로그인 링크를 보내드릴게요.',
                    style: theme.textTheme.bodyMedium,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: AppTokens.space24),
                  if (_sent) ...[
                    Container(
                      padding: const EdgeInsets.all(AppTokens.space16),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.primary.withValues(
                          alpha: 0.08,
                        ),
                        borderRadius: BorderRadius.circular(AppTokens.radiusM),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.mark_email_read_outlined,
                            color: theme.colorScheme.primary,
                          ),
                          const SizedBox(width: AppTokens.space12),
                          const Expanded(
                            child: Text('메일을 확인해 주십시오. 링크를 누르면 자동으로 로그인됩니다.'),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: AppTokens.space12),
                    TextButton(
                      onPressed: () => setState(() => _sent = false),
                      child: const Text('다른 이메일로 다시 보내기'),
                    ),
                  ] else ...[
                    TextField(
                      controller: _ctrl,
                      keyboardType: TextInputType.emailAddress,
                      autofillHints: const [AutofillHints.email],
                      autofocus: true,
                      enabled: !_sending,
                      onChanged: (_) => setState(() {}),
                      onSubmitted: (_) => _submit(),
                      decoration: const InputDecoration(
                        hintText: 'you@example.com',
                        prefixIcon: Icon(Icons.email_outlined),
                      ),
                    ),
                    const SizedBox(height: AppTokens.space12),
                    FilledButton(
                      onPressed: _canSubmit ? _submit : null,
                      style: FilledButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                          vertical: AppTokens.space12,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(
                            AppTokens.radiusM,
                          ),
                        ),
                      ),
                      child: _sending
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Text('로그인 링크 보내기'),
                    ),
                  ],
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
}
