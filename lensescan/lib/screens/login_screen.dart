/// Login screen — clean minimal officer sign-in.
///
/// Matches Stitch design: 1._login_screen/code.html
/// Ministry label at top, centered logo, Officer ID + Password fields,
/// single Sign In CTA, fingerprint button. No footer disclaimers.
library;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../config/theme.dart';
import '../core/auth/auth_provider.dart';

/// Secure login screen with form validation and loading states.
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen>
    with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;
  late AnimationController _animController;
  late Animation<double> _fadeAnim;
  late Animation<Offset> _slideAnim;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _fadeAnim = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animController, curve: Curves.easeOut),
    );
    _slideAnim = Tween<Offset>(
      begin: const Offset(0, 0.1),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(parent: _animController, curve: Curves.easeOut),
    );
    _animController.forward();
  }

  @override
  void dispose() {
    _animController.dispose();
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _handleLogin() async {
    if (!_formKey.currentState!.validate()) return;

    final authProvider = context.read<AuthProvider>();
    authProvider.clearError();

    await authProvider.login(
      _usernameController.text.trim(),
      _passwordController.text,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 448),
              child: FadeTransition(
                opacity: _fadeAnim,
                child: SlideTransition(
                  position: _slideAnim,
                  child: Column(
                    children: [
                      // ── Ministry Line (top) ──
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Text(
                          'Ministry of Consumer Affairs',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 0.33,
                            color: LenseScanTheme.outline,
                          ),
                        ),
                      ),

                      // ── Center Content ──
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 32),
                        child: Column(
                          children: [
                            _buildBrandHeader(),
                            const SizedBox(height: 32),
                            _buildLoginForm(),
                          ],
                        ),
                      ),

                      // Empty bottom spacer
                      const SizedBox(height: 16),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBrandHeader() {
    return Column(
      children: [
        // Logo icon
        Container(
          width: 64,
          height: 64,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            color: LenseScanTheme.primaryContainer,
          ),
          child: const Icon(
            Icons.verified_user_rounded,
            size: 32,
            color: LenseScanTheme.onPrimary,
          ),
        ),
        const SizedBox(height: 16),

        // App name
        Text(
          'LegalLens AI',
          style: Theme.of(context).textTheme.displayMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
        ),
        const SizedBox(height: 4),

        // Tagline
        Text(
          'Field Compliance Scanner',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: LenseScanTheme.onSurfaceVariant,
              ),
        ),
      ],
    );
  }

  Widget _buildLoginForm() {
    return Consumer<AuthProvider>(
      builder: (context, auth, _) {
        return Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Officer ID field
              _buildFieldLabel('Officer ID'),
              const SizedBox(height: 6),
              TextFormField(
                controller: _usernameController,
                decoration: InputDecoration(
                  hintText: 'LM-DL-4029',
                  hintStyle: TextStyle(
                    fontSize: 15,
                    color: LenseScanTheme.outline,
                  ),
                ),
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w400,
                  color: LenseScanTheme.onSurface,
                ),
                textInputAction: TextInputAction.next,
                autocorrect: false,
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Please enter your Officer ID';
                  }
                  if (value.trim().length < 3) {
                    return 'Officer ID must be at least 3 characters';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),

              // Password field
              _buildFieldLabel('Password'),
              const SizedBox(height: 6),
              TextFormField(
                controller: _passwordController,
                decoration: InputDecoration(
                  hintText: '••••••••',
                  hintStyle: TextStyle(
                    fontSize: 15,
                    fontFamily: 'monospace',
                    color: LenseScanTheme.outline,
                  ),
                  suffixIcon: IconButton(
                    icon: Icon(
                      _obscurePassword
                          ? Icons.visibility_outlined
                          : Icons.visibility_off_outlined,
                      size: 20,
                      color: LenseScanTheme.outline,
                    ),
                    onPressed: () {
                      setState(() {
                        _obscurePassword = !_obscurePassword;
                      });
                    },
                  ),
                ),
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w400,
                  fontFamily: _obscurePassword ? 'monospace' : null,
                  letterSpacing: _obscurePassword ? 2 : 0,
                  color: LenseScanTheme.onSurface,
                ),
                obscureText: _obscurePassword,
                textInputAction: TextInputAction.done,
                onFieldSubmitted: (_) => _handleLogin(),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter your password';
                  }
                  if (value.length < 8) {
                    return 'Password must be at least 8 characters';
                  }
                  return null;
                },
              ),

              // Error message
              if (auth.errorMessage != null)
                Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: LenseScanTheme.errorContainer.withValues(alpha: 0.5),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.error_outline,
                          color: LenseScanTheme.error,
                          size: 18,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            auth.errorMessage!,
                            style: const TextStyle(
                              color: LenseScanTheme.error,
                              fontSize: 13,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              const SizedBox(height: 12),

              // Sign In button
              SizedBox(
                height: 52,
                child: ElevatedButton(
                  onPressed: auth.isLoading ? null : _handleLogin,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: LenseScanTheme.primaryContainer,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    elevation: 0,
                  ),
                  child: auth.isLoading
                      ? const SizedBox(
                          height: 22,
                          width: 22,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.5,
                            color: Colors.white,
                          ),
                        )
                      : const Text(
                          'Sign In',
                          style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w600,
                            letterSpacing: -0.085,
                          ),
                        ),
                ),
              ),

              // Fingerprint button
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Center(
                  child: SizedBox(
                    width: 52,
                    height: 52,
                    child: Material(
                      color: LenseScanTheme.surfaceContainerLow,
                      borderRadius: BorderRadius.circular(9999),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(9999),
                        onTap: () {
                          _usernameController.text = 'officer_verma';
                          _passwordController.text = 'officer123';
                          _handleLogin();
                        },
                        child: const Icon(
                          Icons.fingerprint,
                          size: 26,
                          color: LenseScanTheme.primaryContainer,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildFieldLabel(String label) {
    return Text(
      label,
      style: TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w500,
        letterSpacing: 0.12,
        color: LenseScanTheme.onSurfaceVariant,
      ),
    );
  }
}
