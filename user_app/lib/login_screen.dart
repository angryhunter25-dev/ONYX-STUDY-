import 'dart:ui';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'wire_background.dart';

enum Method { email, phone }

const _violet = Color(0xFF7C5CFF);
const _cyan = Color(0xFF00E0FF);

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});
  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final email = TextEditingController(), pass = TextEditingController();
  final phone = TextEditingController(), otp = TextEditingController();
  final auth = FirebaseAuth.instance;
  Method method = Method.email;
  bool signup = false, show = false, remember = true, loading = false;
  String? verId;

  @override
  void initState() {
    super.initState();
    SharedPreferences.getInstance().then((p) {
      final e = p.getString('email');
      if (e != null && mounted) setState(() => email.text = e);
    });
  }

  void msg(String m) => ScaffoldMessenger.of(context)
      .showSnackBar(SnackBar(content: Text(m)));

  Future<void> _saveEmail() async {
    final p = await SharedPreferences.getInstance();
    remember ? p.setString('email', email.text.trim()) : p.remove('email');
  }

  Future<void> emailAuth() async {
    if (email.text.trim().isEmpty || pass.text.isEmpty) {
      msg('Enter email and password');
      return;
    }
    setState(() => loading = true);
    try {
      if (signup) {
        await auth.createUserWithEmailAndPassword(
            email: email.text.trim(), password: pass.text);
      } else {
        await auth.signInWithEmailAndPassword(
            email: email.text.trim(), password: pass.text);
      }
      await _saveEmail();
    } on FirebaseAuthException catch (e) {
      msg(e.message ?? 'Something went wrong');
    }
    if (mounted) setState(() => loading = false);
  }

  Future<void> forgot() async {
    if (email.text.trim().isEmpty) {
      msg('Type your email first');
      return;
    }
    try {
      await auth.sendPasswordResetEmail(email: email.text.trim());
      msg('Password reset link sent to your email');
    } on FirebaseAuthException catch (e) {
      msg(e.message ?? 'Could not send reset email');
    }
  }

  Future<void> sendOtp() async {
    if (phone.text.trim().length != 10) {
      msg('Enter a valid 10-digit number');
      return;
    }
    setState(() => loading = true);
    await auth.verifyPhoneNumber(
      phoneNumber: '+91${phone.text.trim()}',
      verificationCompleted: (cred) => auth.signInWithCredential(cred),
      verificationFailed: (e) {
        msg(e.message ?? 'Verification failed');
        if (mounted) setState(() => loading = false);
      },
      codeSent: (id, _) => setState(() {
        verId = id;
        loading = false;
      }),
      codeAutoRetrievalTimeout: (id) => verId = id,
    );
  }

  Future<void> verifyOtp() async {
    setState(() => loading = true);
    try {
      await auth.signInWithCredential(PhoneAuthProvider.credential(
          verificationId: verId!, smsCode: otp.text.trim()));
    } on FirebaseAuthException {
      msg('Wrong OTP');
    }
    if (mounted) setState(() => loading = false);
  }

  Widget field(TextEditingController c, String hint, IconData icon,
      {bool obscure = false, TextInputType? type, Widget? suffix, int? max}) {
    OutlineInputBorder b(Color col) => OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: col));
    return TextField(
      controller: c,
      obscureText: obscure,
      keyboardType: type,
      maxLength: max,
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        counterText: '',
        hintText: hint,
        hintStyle: const TextStyle(color: Colors.white38),
        prefixIcon: Icon(icon, size: 20, color: Colors.white54),
        suffixIcon: suffix,
        filled: true,
        fillColor: Colors.white.withOpacity(.06),
        enabledBorder: b(Colors.white12),
        focusedBorder: b(_violet),
      ),
    );
  }

  Widget gradientButton(String text, VoidCallback? onTap) {
    return SizedBox(
      width: double.infinity,
      child: Ink(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          gradient: const LinearGradient(colors: [_violet, _cyan]),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 15),
            child: Center(
              child: loading
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white))
                  : Text(text,
                      style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                          fontSize: 16)),
            ),
          ),
        ),
      ),
    );
  }

  Widget methodTab(String label, Method m) {
    final on = method == m;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => method = m),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            color: on ? Colors.white.withOpacity(.12) : Colors.transparent,
          ),
          child: Center(
              child: Text(label,
                  style: TextStyle(
                      color: on ? Colors.white : Colors.white54,
                      fontWeight: FontWeight.w600))),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final emailMode = method == Method.email;
    return Scaffold(
      resizeToAvoidBottomInset: true,
      body: Stack(children: [
        const Positioned.fill(child: WireBackground()),
        SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(22),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(28),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
                  child: Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(.06),
                      borderRadius: BorderRadius.circular(28),
                      border: Border.all(color: Colors.white.withOpacity(.12)),
                    ),
                    child: Column(mainAxisSize: MainAxisSize.min, children: [
                      Container(
                        height: 64,
                        width: 64,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(18),
                          boxShadow: [
                            BoxShadow(
                                color: _violet.withOpacity(.5), blurRadius: 24)
                          ],
                        ),
                        child: ClipRRect(
                            borderRadius: BorderRadius.circular(18),
                            child: Image.asset('assets/icon.png',
                                fit: BoxFit.cover)),
                      ),
                      const SizedBox(height: 16),
                      Text.rich(TextSpan(children: [
                        const TextSpan(text: 'Welcome to '),
                        TextSpan(
                            text: 'ONYX',
                            style: TextStyle(color: Colors.blue.shade200)),
                      ]),
                          style: const TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.w800,
                              color: Colors.white)),
                      const SizedBox(height: 4),
                      Text(
                          signup
                              ? 'Create your account'
                              : 'Sign in to continue your journey',
                          style: const TextStyle(
                              color: Colors.white54, fontSize: 13)),
                      const SizedBox(height: 18),
                      Row(children: [
                        methodTab('Email', Method.email),
                        methodTab('Phone', Method.phone),
                      ]),
                      const SizedBox(height: 14),
                      if (emailMode) ...[
                        field(email, 'Email address', Icons.mail_outline,
                            type: TextInputType.emailAddress),
                        const SizedBox(height: 12),
                        field(pass, 'Password', Icons.lock_outline,
                            obscure: !show,
                            suffix: TextButton(
                                onPressed: () => setState(() => show = !show),
                                child: Text(show ? 'HIDE' : 'SHOW',
                                    style: const TextStyle(
                                        fontSize: 11, color: Colors.white54)))),
                        Row(children: [
                          Checkbox(
                              value: remember,
                              activeColor: _violet,
                              onChanged: (v) =>
                                  setState(() => remember = v ?? true)),
                          const Text('Remember me',
                              style: TextStyle(
                                  color: Colors.white60, fontSize: 12)),
                          const Spacer(),
                          TextButton(
                              onPressed: forgot,
                              child: const Text('Forgot password?',
                                  style: TextStyle(
                                      color: _cyan, fontSize: 12))),
                        ]),
                        gradientButton(signup ? 'Create account' : 'Sign In',
                            loading ? null : emailAuth),
                        const SizedBox(height: 10),
                        TextButton(
                            onPressed: () => setState(() => signup = !signup),
                            child: Text.rich(TextSpan(children: [
                              TextSpan(
                                  text: signup
                                      ? 'Already have an account? '
                                      : 'New here? ',
                                  style: const TextStyle(
                                      color: Colors.white54, fontSize: 12)),
                              TextSpan(
                                  text: signup ? 'Sign in' : 'Create an account',
                                  style: const TextStyle(
                                      color: _cyan,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w700)),
                            ]))),
                      ] else ...[
                        field(phone, 'Mobile number', Icons.phone_outlined,
                            type: TextInputType.phone, max: 10),
                        if (verId != null) ...[
                          const SizedBox(height: 12),
                          field(otp, '6-digit OTP', Icons.sms_outlined,
                              type: TextInputType.number, max: 6),
                        ],
                        const SizedBox(height: 16),
                        gradientButton(verId == null ? 'Send OTP' : 'Verify',
                            loading ? null : (verId == null ? sendOtp : verifyOtp)),
                      ],
                    ]),
                  ),
                ),
              ),
            ),
          ),
        ),
      ]),
    );
  }
}
