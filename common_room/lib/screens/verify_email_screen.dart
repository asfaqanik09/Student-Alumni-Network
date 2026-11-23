
import 'package:flutter/material.dart';
import 'login_screen.dart';

class VerifyEmailScreen extends StatelessWidget {
  final String email;
  final String userId;

  const VerifyEmailScreen({
    super.key,
    required this.email,
    required this.userId,
  });

  void continueToLogin(BuildContext context) {
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(
        builder: (_) => const LoginScreen(),
      ),
          (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 28),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 68,
                height: 68,
                decoration: const BoxDecoration(
                  color: Color(0xFFE6ECE2),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.mark_email_unread_outlined,
                  size: 30,
                  color: Color(0xFF172B3A),
                ),
              ),
              const SizedBox(height: 20),
              const Text(
                'Check your inbox',
                style: TextStyle(
                  fontSize: 25,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF172B3A),
                ),
              ),
              const SizedBox(height: 10),
              Text.rich(
                TextSpan(
                  style: const TextStyle(
                    fontSize: 15,
                    color: Color(0xFF52606D),
                    height: 1.5,
                  ),
                  children: [
                    const TextSpan(
                      text: 'We sent a real verification link to ',
                    ),
                    TextSpan(
                      text: email,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF172B3A),
                      ),
                    ),
                    const TextSpan(
                      text:
                      '. Open the email and click the verification button to activate your account.',
                    ),
                  ],
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 18),
              const Text(
                'The verification link expires after one hour. Check your spam folder if you cannot find the email.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 13,
                  height: 1.5,
                  color: Color(0xFF7B8794),
                ),
              ),
              const SizedBox(height: 28),
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: () => continueToLogin(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF172B3A),
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  child: const Text(
                    "I've verified my email — Go to Login",
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              TextButton(
                onPressed: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text(
                        'If you did not receive the email, check your spam folder. Email resend will be added next.',
                      ),
                    ),
                  );
                },
                child: const Text(
                  'Did not receive the email?',
                  style: TextStyle(
                    color: Color(0xFFB47B00),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
