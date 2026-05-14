import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/auth_service.dart';
import '../services/cart_service.dart';
import '../services/order_service.dart';
import '../services/notification_service.dart';
import '../services/location_service.dart';
import '../theme/app_theme.dart';

class RegisterScreen extends StatefulWidget {
  final VoidCallback? onSuccess;

  const RegisterScreen({super.key, this.onSuccess});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _fullNameController = TextEditingController(text: '');
  final _phoneController = TextEditingController(text: '256');
  final _emailController = TextEditingController();
  final _ninController = TextEditingController();
  final _streetAddressController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  DateTime? _dateOfBirth;
  int? _selectedDistrictId;
  int? _selectedSubcountyId;
  int? _selectedParishId;
  int? _selectedVillageId;

  bool _isLoading = false;
  bool _obscurePassword = true;
  bool _obscureConfirm = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    // Ensure location data is loaded from Supabase
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final locService = Provider.of<LocationService>(context, listen: false);
      if (!locService.isLoaded) {
        locService.loadAll();
      }
    });
  }

  @override
  void dispose() {
    _fullNameController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _ninController.dispose();
    _streetAddressController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  int _calculateAge(DateTime dob) {
    final now = DateTime.now();
    int age = now.year - dob.year;
    if (now.month < dob.month ||
        (now.month == dob.month && now.day < dob.day)) {
      age--;
    }
    return age;
  }

  @override
  Widget build(BuildContext context) {
    final locationService = context.watch<LocationService>();

    final subcounties = _selectedDistrictId != null
        ? locationService.getSubcounties(_selectedDistrictId!)
        : <Subcounty>[];
    final parishes = _selectedSubcountyId != null
        ? locationService.getParishes(_selectedSubcountyId!)
        : <Parish>[];
    final villages = _selectedParishId != null
        ? locationService.getVillages(_selectedParishId!)
        : <Village>[];
    final isLoadingVillages = _selectedParishId != null &&
        locationService.isVillagesLoadingFor(_selectedParishId!);

    return Scaffold(
      appBar: AppBar(
        backgroundColor: AppTheme.trafordOrange,
        title: const Text('Create Account'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                margin: const EdgeInsets.only(bottom: 24),
                decoration: BoxDecoration(
                  color: AppTheme.softLeaf,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Column(
                  children: [
                    Icon(Icons.person_add, size: 40, color: AppTheme.growthGreen),
                    SizedBox(height: 8),
                    Text(
                      'Join Traford Farm Fresh',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.growthGreen,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      'Fill in your details to create an account',
                      style:
                          TextStyle(fontSize: 13, color: AppTheme.textMuted),
                    ),
                  ],
                ),
              ),

              if (_error != null) ...[
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: Colors.red.shade50,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.red.shade200),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.error_outline,
                          color: Colors.red, size: 20),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(_error!,
                            style: const TextStyle(
                                color: Colors.red, fontSize: 13)),
                      ),
                    ],
                  ),
                ),
              ],

              // --- PERSONAL INFO ---
              _sectionTitle('Personal Information'),
              const SizedBox(height: 12),
              _buildCard(
                child: Column(
                  children: [
                    TextFormField(
                      controller: _fullNameController,
                      textCapitalization: TextCapitalization.words,
                      decoration: const InputDecoration(
                        labelText: 'Full Name *',
                        hintText: 'Enter your full name',
                        prefixIcon: Icon(Icons.person_outline),
                      ),
                      validator: (v) {
                        if (v == null || v.trim().isEmpty) {
                          return 'Full name is required';
                        }
                        if (v.trim().split(' ').length < 2) {
                          return 'Enter at least first and last name';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),

                    // Date of Birth
                    GestureDetector(
                      onTap: _pickDateOfBirth,
                      child: AbsorbPointer(
                        child: TextFormField(
                          decoration: InputDecoration(
                            labelText: 'Date of Birth *',
                            hintText: 'Tap to select',
                            prefixIcon: const Icon(Icons.calendar_today),
                            suffixIcon: const Icon(Icons.arrow_drop_down),
                            hintStyle: TextStyle(color: Colors.grey[400]),
                          ),
                          controller: TextEditingController(
                            text: _dateOfBirth != null
                                ? '${_dateOfBirth!.day}/${_dateOfBirth!.month}/${_dateOfBirth!.year}'
                                : '',
                          ),
                          validator: (_) {
                            if (_dateOfBirth == null) {
                              return 'Date of birth is required';
                            }
                            if (_calculateAge(_dateOfBirth!) < 16) {
                              return 'Must be at least 16 years old';
                            }
                            return null;
                          },
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    TextFormField(
                      controller: _phoneController,
                      keyboardType: TextInputType.phone,
                      maxLength: 12,
                      decoration: const InputDecoration(
                        labelText: 'Phone Number *',
                        hintText: '256XXXXXXXXX',
                        prefixIcon: Icon(Icons.phone),
                        counterText: '',
                        helperText: 'Uganda number starting with 256',
                      ),
                      validator: (v) {
                        if (v == null || v.isEmpty) return 'Phone is required';
                        if (!v.startsWith('256')) {
                          return 'Must start with 256';
                        }
                        if (v.length < 12) {
                          return 'Enter complete 12-digit number';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),

                    // Email is OPTIONAL
                    TextFormField(
                      controller: _emailController,
                      keyboardType: TextInputType.emailAddress,
                      decoration: const InputDecoration(
                        labelText: 'Email (Optional)',
                        hintText: 'your@email.com',
                        prefixIcon: Icon(Icons.email_outlined),
                        helperText: 'Optional - you can add this later',
                      ),
                      validator: (v) {
                        if (v != null && v.trim().isNotEmpty) {
                          if (!v.contains('@') || !v.contains('.')) {
                            return 'Enter a valid email';
                          }
                        }
                        return null;
                      },
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              // --- LOCATION (from Supabase) ---
              _sectionTitle('Location'),
              const SizedBox(height: 4),
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Text(
                  locationService.isLoading
                      ? 'Loading locations...'
                      : 'Select your district, then subcounty, then parish/village',
                  style: const TextStyle(fontSize: 12, color: AppTheme.textMuted),
                ),
              ),
              _buildCard(
                child: locationService.isLoading
                    ? const Padding(
                        padding: EdgeInsets.all(24),
                        child: Center(
                          child: Column(
                            children: [
                              CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: AppTheme.trafordOrange),
                              SizedBox(height: 12),
                              Text('Loading locations from server...',
                                  style: TextStyle(
                                      fontSize: 13,
                                      color: AppTheme.textMuted)),
                            ],
                          ),
                        ),
                      )
                    : Column(
                        children: [
                          // District
                          DropdownButtonFormField<int>(
                            initialValue: _selectedDistrictId,
                            isExpanded: true,
                            menuMaxHeight: 350,
                            decoration: const InputDecoration(
                              labelText: 'District *',
                              prefixIcon: Icon(Icons.map),
                            ),
                            items: locationService.districts
                                .map((d) => DropdownMenuItem(
                                      value: d.id,
                                      child: Text(d.name,
                                          overflow: TextOverflow.ellipsis),
                                    ))
                                .toList(),
                            onChanged: (val) {
                              setState(() {
                                _selectedDistrictId = val;
                                _selectedSubcountyId = null;
                                _selectedParishId = null;
                              });
                            },
                            validator: (v) =>
                                v == null ? 'Select your district' : null,
                          ),
                          const SizedBox(height: 16),

                          // Subcounty
                          DropdownButtonFormField<int>(
                            initialValue: _selectedSubcountyId,
                            isExpanded: true,
                            menuMaxHeight: 350,
                            decoration: InputDecoration(
                              labelText: 'Subcounty *',
                              prefixIcon: const Icon(Icons.location_city),
                              hintText: _selectedDistrictId == null
                                  ? 'Select district first'
                                  : (subcounties.isEmpty
                                      ? 'No subcounties available'
                                      : 'Select subcounty'),
                            ),
                            items: subcounties
                                .map((s) => DropdownMenuItem(
                                      value: s.id,
                                      child: Text(s.name,
                                          overflow: TextOverflow.ellipsis),
                                    ))
                                .toList(),
                            onChanged: _selectedDistrictId == null
                                ? null
                                : (val) {
                                    setState(() {
                                      _selectedSubcountyId = val;
                                      _selectedParishId = null;
                                    });
                                  },
                            validator: (v) =>
                                v == null ? 'Select your subcounty' : null,
                          ),
                          const SizedBox(height: 16),

                          // Parish
                          DropdownButtonFormField<int>(
                            initialValue: _selectedParishId,
                            isExpanded: true,
                            menuMaxHeight: 350,
                            decoration: InputDecoration(
                              labelText: 'Parish *',
                              prefixIcon: const Icon(Icons.home_outlined),
                              hintText: _selectedSubcountyId == null
                                  ? 'Select subcounty first'
                                  : (parishes.isEmpty
                                      ? 'No parishes available'
                                      : 'Select parish'),
                            ),
                            items: parishes
                                .map((p) => DropdownMenuItem(
                                      value: p.id,
                                      child: Text(p.name,
                                          overflow: TextOverflow.ellipsis),
                                    ))
                                .toList(),
                            onChanged: _selectedSubcountyId == null
                                ? null
                                : (val) {
                                    setState(() {
                                      _selectedParishId = val;
                                      _selectedVillageId = null;
                                    });
                                    if (val != null) {
                                      locationService.loadVillagesFor(val);
                                    }
                                  },
                            validator: (v) =>
                                v == null ? 'Select your parish' : null,
                          ),
                          const SizedBox(height: 16),

                          // Village (lazy loaded)
                          DropdownButtonFormField<int>(
                            initialValue: _selectedVillageId,
                            isExpanded: true,
                            menuMaxHeight: 350,
                            decoration: InputDecoration(
                              labelText: 'Village *',
                              prefixIcon: const Icon(Icons.holiday_village),
                              hintText: _selectedParishId == null
                                  ? 'Select parish first'
                                  : (isLoadingVillages
                                      ? 'Loading villages...'
                                      : (villages.isEmpty
                                          ? 'No villages available'
                                          : 'Select village')),
                              suffixIcon: isLoadingVillages
                                  ? const Padding(
                                      padding: EdgeInsets.all(12),
                                      child: SizedBox(
                                        width: 16,
                                        height: 16,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          color: AppTheme.trafordOrange,
                                        ),
                                      ),
                                    )
                                  : null,
                            ),
                            items: villages
                                .map((v) => DropdownMenuItem(
                                      value: v.id,
                                      child: Text(v.name,
                                          overflow: TextOverflow.ellipsis),
                                    ))
                                .toList(),
                            onChanged: (_selectedParishId == null ||
                                    isLoadingVillages)
                                ? null
                                : (val) {
                                    setState(() => _selectedVillageId = val);
                                  },
                            validator: (v) =>
                                v == null ? 'Select your village' : null,
                          ),
                          const SizedBox(height: 16),

                          // Street / Plot Number / Building Name
                          TextFormField(
                            controller: _streetAddressController,
                            textCapitalization: TextCapitalization.words,
                            decoration: const InputDecoration(
                              labelText:
                                  'Street / Plot No. / Building / Road *',
                              hintText: 'e.g. Plot 12, Mukasa Bldg, Bombo Rd',
                              prefixIcon: Icon(Icons.signpost_outlined),
                              helperText:
                                  'So the rider can find your exact gate',
                            ),
                            maxLines: 2,
                            minLines: 1,
                            validator: (v) {
                              if (v == null || v.trim().isEmpty) {
                                return 'Enter your street / plot / building';
                              }
                              return null;
                            },
                          ),
                        ],
                      ),
              ),

              const SizedBox(height: 24),

              // --- PASSWORD ---
              _sectionTitle('Password'),
              const SizedBox(height: 4),
              const Padding(
                padding: EdgeInsets.only(bottom: 12),
                child: Text(
                  'Use this password to sign in next time with your phone number.',
                  style: TextStyle(fontSize: 12, color: AppTheme.textMuted),
                ),
              ),
              _buildCard(
                child: Column(
                  children: [
                    TextFormField(
                      controller: _passwordController,
                      obscureText: _obscurePassword,
                      decoration: InputDecoration(
                        labelText: 'Password *',
                        hintText: 'At least 6 characters',
                        prefixIcon: const Icon(Icons.lock_outline),
                        suffixIcon: IconButton(
                          icon: Icon(_obscurePassword
                              ? Icons.visibility_off
                              : Icons.visibility),
                          onPressed: () => setState(
                              () => _obscurePassword = !_obscurePassword),
                        ),
                      ),
                      validator: (v) {
                        if (v == null || v.isEmpty) return 'Password is required';
                        if (v.length < 6) return 'At least 6 characters';
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _confirmPasswordController,
                      obscureText: _obscureConfirm,
                      decoration: InputDecoration(
                        labelText: 'Confirm Password *',
                        hintText: 'Re-enter your password',
                        prefixIcon: const Icon(Icons.lock_reset),
                        suffixIcon: IconButton(
                          icon: Icon(_obscureConfirm
                              ? Icons.visibility_off
                              : Icons.visibility),
                          onPressed: () => setState(
                              () => _obscureConfirm = !_obscureConfirm),
                        ),
                      ),
                      validator: (v) {
                        if (v == null || v.isEmpty) return 'Confirm your password';
                        if (v != _passwordController.text) {
                          return 'Passwords do not match';
                        }
                        return null;
                      },
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              // --- OPTIONAL ---
              _sectionTitle('Optional Information'),
              const SizedBox(height: 12),
              _buildCard(
                child: Column(
                  children: [
                    TextFormField(
                      controller: _ninController,
                      textCapitalization: TextCapitalization.characters,
                      decoration: const InputDecoration(
                        labelText: 'NIN Number (Optional)',
                        hintText: 'National ID Number',
                        prefixIcon: Icon(Icons.badge_outlined),
                        helperText: 'This is optional for now',
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 32),

              // Register Button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _handleRegister,
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  child: _isLoading
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Text('Create Account',
                          style: TextStyle(fontSize: 16)),
                ),
              ),

              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }

  Widget _sectionTitle(String title) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.w700,
        color: AppTheme.textDark,
      ),
    );
  }

  Widget _buildCard({required Widget child}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.cardBorder),
      ),
      child: child,
    );
  }

  Future<void> _pickDateOfBirth() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime(now.year - 18, now.month, now.day),
      firstDate: DateTime(1930),
      lastDate: DateTime(now.year - 15, now.month, now.day),
      helpText: 'You must be at least 15 years old',
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: AppTheme.trafordOrange,
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      setState(() => _dateOfBirth = picked);
    }
  }

  Future<void> _handleRegister() async {
    if (!_formKey.currentState!.validate()) return;

    if (_dateOfBirth == null) {
      setState(() => _error = 'Please select your date of birth');
      return;
    }
    if (_calculateAge(_dateOfBirth!) < 16) {
      setState(() => _error = 'You must be at least 16 years old');
      return;
    }

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final auth = Provider.of<AuthService>(context, listen: false);
      final locService = Provider.of<LocationService>(context, listen: false);

      // Email is optional - pass null if empty
      final emailText = _emailController.text.trim();

      final success = await auth.register(
        fullName: _fullNameController.text.trim(),
        phone: _phoneController.text.trim(),
        email: emailText.isNotEmpty ? emailText : null,
        dateOfBirth: _dateOfBirth!,
        districtId: _selectedDistrictId!,
        subcountyId: _selectedSubcountyId!,
        parishId: _selectedParishId!,
        villageId: _selectedVillageId,
        streetAddress: _streetAddressController.text.trim(),
        districtName: locService.districtName(_selectedDistrictId) ?? '',
        subcountyName: locService.subcountyName(_selectedSubcountyId) ?? '',
        parishName: locService.parishName(_selectedParishId) ?? '',
        villageName: locService.villageName(_selectedVillageId),
        nin: _ninController.text.trim().isNotEmpty
            ? _ninController.text.trim()
            : null,
        password: _passwordController.text,
      );

      if (!mounted) return;

      if (success) {
        // Sync cart and orders with new user
        final cart = Provider.of<CartService>(context, listen: false);
        final orderService =
            Provider.of<OrderService>(context, listen: false);
        final notifService =
            Provider.of<NotificationService>(context, listen: false);

        cart.setUserId(auth.userId!);

        // Load orders and notifications safely (don't block registration success)
        try {
          await orderService.loadOrders(auth.userId!);
        } catch (_) {}
        try {
          await notifService.loadNotifications(auth.userId!);
        } catch (_) {}

        if (!mounted) return;

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content:
                Text('Welcome, ${auth.userName}! Account created.'),
            backgroundColor: AppTheme.trafordOrange,
          ),
        );

        widget.onSuccess?.call();
        // Pop back to main app
        Navigator.of(context).popUntil((route) => route.isFirst);
      }
    } catch (e) {
      final msg = e.toString();
      if (msg.contains('duplicate') || msg.contains('unique')) {
        setState(() => _error =
            'An account with this phone number already exists. Try signing in.');
      } else {
        setState(() => _error = 'Registration failed: ${msg.length > 100 ? msg.substring(0, 100) : msg}');
      }
    }

    if (mounted) {
      setState(() => _isLoading = false);
    }
  }
}
