import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/auth_service.dart';
import '../services/cart_service.dart';
import '../services/order_service.dart';
import '../services/notification_service.dart';
import '../theme/app_theme.dart';
import 'register_screen.dart';

class LoginScreen extends StatefulWidget {
  final VoidCallback? onSuccess;

  const LoginScreen({super.key, this.onSuccess});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _phoneController = TextEditingController(text: '256');
  final _passwordController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  bool _isLoading = false;
  bool _isCheckingPhone = false;
  bool _obscurePassword = true;
  String? _error;

  // Account status detected from user_has_password RPC:
  //   null            - not checked yet, show "Continue" button
  //   'has_password'  - prompt for password input
  //   'no_password'   - existing user without a password, prompt to set one
  //   'not_found'     - no such account, suggest creating
  String? _accountStatus;

  @override
  void dispose() {
    _phoneController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  bool _isValidPhone(String v) {
    return v.startsWith('256') && v.length >= 12;
  }

  Future<void> _checkPhone() async {
    final phone = _phoneController.text.trim();
    if (!_isValidPhone(phone)) {
      setState(() => _error = 'Enter a complete 12-digit number starting with 256');
      return;
    }
    setState(() {
      _isCheckingPhone = true;
      _error = null;
    });

    final auth = Provider.of<AuthService>(context, listen: false);
    final status = await auth.userHasPasswordStatus(phone);

    if (!mounted) return;
    setState(() {
      _isCheckingPhone = false;
      _accountStatus = status;
      _passwordController.clear();
      if (status == 'error') {
        _error =
            'Could not check this number right now. Please check your connection and try again.';
        _accountStatus = null;
      } else if (status == 'not_found') {
        _error =
            'No account found for $phone. If you registered on the website with a different number, please use that one — or tap "Create New Account" below.';
      }
    });
  }

  Future<void> _afterLoginSync(AuthService auth) async {
    final cart = Provider.of<CartService>(context, listen: false);
    final orderService = Provider.of<OrderService>(context, listen: false);
    final notifService =
        Provider.of<NotificationService>(context, listen: false);

    cart.setUserId(auth.userId!);
    try {
      await orderService.loadOrders(auth.userId!);
    } catch (_) {}
    try {
      await notifService.loadNotifications(auth.userId!);
    } catch (_) {}
  }

  /// Existing flow: account already has a password -> verify it.
  Future<void> _loginWithPassword() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _isLoading = true;
      _error = null;
    });

    final auth = Provider.of<AuthService>(context, listen: false);
    final success = await auth.loginWithPhonePassword(
      _phoneController.text.trim(),
      _passwordController.text,
    );

    if (!mounted) return;
    if (success) {
      await _afterLoginSync(auth);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Welcome back, ${auth.userName ?? 'Customer'}!'),
          backgroundColor: AppTheme.trafordOrange,
        ),
      );
      widget.onSuccess?.call();
      Navigator.pop(context);
    } else {
      setState(() {
        _isLoading = false;
        _error = 'Incorrect password. Try again.';
      });
    }
  }

  /// First-time flow: account exists, no password yet.
  /// Login by phone, then set the password they just typed.
  Future<void> _firstTimeSetPasswordAndLogin() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _isLoading = true;
      _error = null;
    });

    final auth = Provider.of<AuthService>(context, listen: false);
    final loggedIn = await auth.loginWithPhone(_phoneController.text.trim());

    if (!mounted) return;
    if (!loggedIn) {
      setState(() {
        _isLoading = false;
        _error = 'Could not find your account. Please create one.';
      });
      return;
    }

    final passwordOk = await auth.setPassword(_passwordController.text);
    if (!mounted) return;

    if (!passwordOk) {
      // We're still logged in, but password didn't save - warn but continue
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
              'Signed in, but we could not save your password. Try again from your profile.'),
          backgroundColor: Colors.orange,
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Password set. Next time, sign in with phone + password.'),
          backgroundColor: AppTheme.growthGreen,
        ),
      );
    }

    await _afterLoginSync(auth);
    if (!mounted) return;
    widget.onSuccess?.call();
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: AppTheme.trafordOrange,
        title: const Text('Sign In'),
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            // Header
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(32),
              decoration: const BoxDecoration(
                color: Colors.white,
                border: Border(bottom: BorderSide(color: AppTheme.cardBorder)),
              ),
              child: Column(
                children: [
                  Image.asset(
                    'assets/images/traford_logo.png',
                    height: 60,
                    fit: BoxFit.contain,
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Welcome to Traford',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w800,
                      color: AppTheme.textDark,
                    ),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'Sign in with your phone number',
                    style: TextStyle(
                      fontSize: 14,
                      color: AppTheme.textMuted,
                    ),
                  ),
                ],
              ),
            ),

            Padding(
              padding: const EdgeInsets.all(24),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Phone Number',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.textDark,
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: _phoneController,
                      keyboardType: TextInputType.phone,
                      maxLength: 12,
                      enabled: !_isLoading,
                      decoration: InputDecoration(
                        hintText: '256XXXXXXXXX',
                        prefixIcon: const Icon(Icons.phone),
                        counterText: '',
                        helperText:
                            'Enter your Uganda phone number starting with 256',
                        helperStyle: const TextStyle(fontSize: 12),
                      ),
                      onChanged: (_) {
                        // If user edits phone, reset detected status
                        if (_accountStatus != null) {
                          setState(() {
                            _accountStatus = null;
                            _error = null;
                            _passwordController.clear();
                          });
                        }
                      },
                      validator: (v) {
                        if (v == null || v.isEmpty) return 'Phone is required';
                        if (!v.startsWith('256')) {
                          return 'Phone must start with 256';
                        }
                        if (v.length < 12) return 'Enter complete phone number';
                        return null;
                      },
                    ),

                    if (_accountStatus == 'has_password' ||
                        _accountStatus == 'no_password') ...[
                      const SizedBox(height: 16),
                      Text(
                        _accountStatus == 'has_password'
                            ? 'Password'
                            : 'Set a password (first time)',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.textDark,
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextFormField(
                        controller: _passwordController,
                        obscureText: _obscurePassword,
                        enabled: !_isLoading,
                        decoration: InputDecoration(
                          hintText: _accountStatus == 'has_password'
                              ? 'Enter your password'
                              : 'Choose a new password (min 6 chars)',
                          prefixIcon: const Icon(Icons.lock_outline),
                          helperText: _accountStatus == 'has_password'
                              ? null
                              : 'We did not have a password for you yet — set one now.',
                          helperStyle: const TextStyle(fontSize: 12),
                          suffixIcon: IconButton(
                            icon: Icon(_obscurePassword
                                ? Icons.visibility_off
                                : Icons.visibility),
                            onPressed: () => setState(
                                () => _obscurePassword = !_obscurePassword),
                          ),
                        ),
                        validator: (v) {
                          if (v == null || v.isEmpty) {
                            return 'Password is required';
                          }
                          if (_accountStatus == 'no_password' && v.length < 6) {
                            return 'At least 6 characters';
                          }
                          return null;
                        },
                      ),
                    ],

                    if (_error != null) ...[
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.red.shade50,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: Colors.red.shade200),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.error_outline,
                                color: Colors.red, size: 18),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                _error!,
                                style: const TextStyle(
                                    color: Colors.red, fontSize: 13),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],

                    const SizedBox(height: 24),

                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _isLoading
                            ? null
                            : () {
                                if (_accountStatus == null ||
                                    _accountStatus == 'not_found' ||
                                    _accountStatus == 'error') {
                                  _checkPhone();
                                } else if (_accountStatus == 'has_password') {
                                  _loginWithPassword();
                                } else if (_accountStatus == 'no_password') {
                                  _firstTimeSetPasswordAndLogin();
                                }
                              },
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                        ),
                        child: (_isLoading || _isCheckingPhone)
                            ? const SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : Text(
                                _accountStatus == 'has_password'
                                    ? 'Sign In'
                                    : _accountStatus == 'no_password'
                                        ? 'Set Password & Sign In'
                                        : 'Continue',
                                style: const TextStyle(fontSize: 16),
                              ),
                      ),
                    ),

                    const SizedBox(height: 20),

                    Row(
                      children: [
                        const Expanded(child: Divider()),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          child: Text(
                            'OR',
                            style: TextStyle(
                              color: Colors.grey[500],
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        const Expanded(child: Divider()),
                      ],
                    ),

                    const SizedBox(height: 20),

                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton(
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => RegisterScreen(
                                onSuccess: widget.onSuccess,
                              ),
                            ),
                          );
                        },
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                        ),
                        child: const Text('Create New Account',
                            style: TextStyle(fontSize: 16)),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
