import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/auth_service.dart';
import '../services/location_service.dart';
import '../services/supplier_service.dart';
import '../theme/app_theme.dart';

class BecomeSupplierScreen extends StatefulWidget {
  const BecomeSupplierScreen({super.key});

  @override
  State<BecomeSupplierScreen> createState() => _BecomeSupplierScreenState();
}

class _BecomeSupplierScreenState extends State<BecomeSupplierScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _emailController = TextEditingController();
  final _productController = TextEditingController();
  final _quantityController = TextEditingController();
  final _notesController = TextEditingController();

  String? _frequency;
  bool _submitting = false;
  String? _error;

  static const _frequencies = <String>[
    'Daily',
    'Weekly',
    'Bi-weekly',
    'Monthly',
    'Seasonal',
    'One-off',
  ];

  @override
  void initState() {
    super.initState();
    // Prefill from logged-in profile
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final auth = Provider.of<AuthService>(context, listen: false);
      _nameController.text = auth.userName ?? '';
      _phoneController.text = auth.userPhone ?? '';
      _emailController.text = (auth.profile?['email'] as String?) ?? '';
      setState(() {});
    });
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _productController.dispose();
    _quantityController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_frequency == null) {
      setState(() => _error = 'Please choose how often you can supply');
      return;
    }

    setState(() {
      _submitting = true;
      _error = null;
    });

    final auth = Provider.of<AuthService>(context, listen: false);
    final supplierService =
        Provider.of<SupplierService>(context, listen: false);
    final profile = auth.profile ?? {};

    try {
      await supplierService.submitApplication(
        userId: auth.userId,
        fullName: _nameController.text.trim(),
        phone: _phoneController.text.trim(),
        email: _emailController.text.trim().isNotEmpty
            ? _emailController.text.trim()
            : null,
        product: _productController.text.trim(),
        quantity: _quantityController.text.trim(),
        frequency: _frequency,
        notes: _notesController.text.trim(),
        districtId: profile['district_id'] as int?,
        subcountyId: profile['subcounty_id'] as int?,
        parishId: profile['parish_id'] as int?,
        villageId: profile['village_id'] as int?,
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
              'Application submitted! Our team will reach out soon.'),
          backgroundColor: AppTheme.growthGreen,
        ),
      );
      Navigator.pop(context);
    } catch (e) {
      setState(() {
        _submitting = false;
        _error = 'Could not submit: ${e.toString().length > 120 ? e.toString().substring(0, 120) : e}';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final locService = context.watch<LocationService>();
    final auth = context.watch<AuthService>();
    final profile = auth.profile ?? {};

    final districtName = locService.districtName(profile['district_id'] as int?);
    final subcountyName =
        locService.subcountyName(profile['subcounty_id'] as int?);
    final parishName = locService.parishName(profile['parish_id'] as int?);
    final villageName = locService.villageName(profile['village_id'] as int?);
    final addressLine = [
      villageName,
      parishName,
      subcountyName,
      districtName,
    ].where((s) => s != null && s.isNotEmpty).join(', ');

    return Scaffold(
      appBar: AppBar(
        backgroundColor: AppTheme.trafordOrange,
        title: const Text('Become Our Supplier'),
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
                decoration: BoxDecoration(
                  color: AppTheme.softLeaf,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Column(
                  children: [
                    Icon(Icons.agriculture,
                        size: 40, color: AppTheme.growthGreen),
                    SizedBox(height: 8),
                    Text(
                      'Supply to Traford Farm Fresh',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: AppTheme.growthGreen,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      'Tell us what you grow or produce, how much, and how often. '
                      'Our team will review and contact you.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                          fontSize: 13, color: AppTheme.textMuted, height: 1.4),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

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

              _sectionTitle('Your contact'),
              const SizedBox(height: 12),
              _buildCard(
                child: Column(
                  children: [
                    TextFormField(
                      controller: _nameController,
                      textCapitalization: TextCapitalization.words,
                      decoration: const InputDecoration(
                        labelText: 'Full Name *',
                        prefixIcon: Icon(Icons.person_outline),
                      ),
                      validator: (v) => (v == null || v.trim().isEmpty)
                          ? 'Full name is required'
                          : null,
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _phoneController,
                      keyboardType: TextInputType.phone,
                      maxLength: 12,
                      decoration: const InputDecoration(
                        labelText: 'Phone *',
                        hintText: '256XXXXXXXXX',
                        counterText: '',
                        prefixIcon: Icon(Icons.phone),
                      ),
                      validator: (v) {
                        if (v == null || v.isEmpty) return 'Phone is required';
                        if (!v.startsWith('256')) return 'Must start with 256';
                        if (v.length < 12) return 'Enter 12-digit number';
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _emailController,
                      keyboardType: TextInputType.emailAddress,
                      decoration: const InputDecoration(
                        labelText: 'Email (Optional)',
                        prefixIcon: Icon(Icons.email_outlined),
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
                    if (addressLine.isNotEmpty) ...[
                      const SizedBox(height: 16),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade50,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: AppTheme.cardBorder),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.location_on,
                                size: 18, color: AppTheme.trafordOrange),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'From your profile',
                                    style: TextStyle(
                                        fontSize: 11,
                                        color: AppTheme.textMuted),
                                  ),
                                  Text(
                                    addressLine,
                                    style: const TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w500),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),

              const SizedBox(height: 20),
              _sectionTitle('What you can supply'),
              const SizedBox(height: 12),
              _buildCard(
                child: Column(
                  children: [
                    TextFormField(
                      controller: _productController,
                      textCapitalization: TextCapitalization.words,
                      decoration: const InputDecoration(
                        labelText: 'Product *',
                        hintText: 'e.g. Tomatoes, Eggs, Maize, Milk',
                        prefixIcon: Icon(Icons.eco_outlined),
                      ),
                      validator: (v) => (v == null || v.trim().isEmpty)
                          ? 'What do you want to supply?'
                          : null,
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _quantityController,
                      decoration: const InputDecoration(
                        labelText: 'Quantity (Optional)',
                        hintText: 'e.g. 100 kg, 30 trays, 50 L',
                        prefixIcon: Icon(Icons.scale_outlined),
                      ),
                    ),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<String>(
                      initialValue: _frequency,
                      isExpanded: true,
                      decoration: const InputDecoration(
                        labelText: 'How often? *',
                        prefixIcon: Icon(Icons.schedule),
                      ),
                      items: _frequencies
                          .map((f) => DropdownMenuItem(value: f, child: Text(f)))
                          .toList(),
                      onChanged: (v) => setState(() => _frequency = v),
                      validator: (v) => v == null ? 'Choose frequency' : null,
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _notesController,
                      maxLines: 4,
                      minLines: 3,
                      decoration: const InputDecoration(
                        labelText: 'Notes (Optional)',
                        hintText:
                            'Anything else we should know (variety, quality, pricing, etc.)',
                        prefixIcon: Icon(Icons.notes),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _submitting ? null : _submit,
                  icon: _submitting
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.send),
                  label: Text(
                    _submitting ? 'Submitting...' : 'Submit Application',
                    style: const TextStyle(fontSize: 16),
                  ),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                ),
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  Widget _sectionTitle(String title) => Text(
        title,
        style: const TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.w700,
          color: AppTheme.textDark,
        ),
      );

  Widget _buildCard({required Widget child}) => Container(
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
