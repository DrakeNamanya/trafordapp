import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/auth_service.dart';
import '../services/cart_service.dart';
import '../services/notification_service.dart';
import '../services/location_service.dart';
import '../services/api_client.dart';
import '../theme/app_theme.dart';
import '../widgets/product_card.dart';

class CheckoutScreen extends StatefulWidget {
  const CheckoutScreen({super.key});

  @override
  State<CheckoutScreen> createState() => _CheckoutScreenState();
}

class _CheckoutScreenState extends State<CheckoutScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _addressController = TextEditingController();
  final _phoneController = TextEditingController();
  String _paymentMethod = 'cash';
  bool _isProcessing = false;
  bool _checkedAuth = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkUserProfile();
    });
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _addressController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  /// Phase 5: guest checkout is allowed by default. We pre-fill the form
  /// from any existing profile data, but no login is required — the server
  /// will create an auth user + profile automatically based on the phone
  /// (or synthesized email if none is supplied).
  void _checkUserProfile() {
    final auth = Provider.of<AuthService>(context, listen: false);
    final locService = Provider.of<LocationService>(context, listen: false);
    final profile = auth.profile;
    if (profile != null) {
      _nameController.text = (profile['full_name'] as String?) ?? '';
      _phoneController.text = (profile['phone'] as String?) ?? '';
      _emailController.text = (profile['email'] as String?) ?? '';
      final districtName = profile['district_name'] ??
          locService.districtName(profile['district_id'] as int?) ??
          '';
      final subcountyName = profile['subcounty_name'] ??
          locService.subcountyName(profile['subcounty_id'] as int?) ??
          '';
      final parishName = profile['parish_name'] ??
          locService.parishName(profile['parish_id'] as int?) ??
          '';
      if (districtName.isNotEmpty) {
        _addressController.text = '$parishName, $subcountyName, $districtName';
      }
    }
    setState(() => _checkedAuth = true);
  }

  @override
  Widget build(BuildContext context) {
    final cart = context.watch<CartService>();
    final auth = context.watch<AuthService>();

    return Scaffold(
      appBar: AppBar(
        backgroundColor: AppTheme.trafordOrange,
        title: const Text('Checkout'),
      ),
      body: cart.items.isEmpty
          ? const Center(child: Text('Your cart is empty'))
          : !_checkedAuth
              ? const Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      CircularProgressIndicator(color: AppTheme.trafordOrange),
                      SizedBox(height: 16),
                      Text('Checking your account...',
                          style: TextStyle(color: AppTheme.textMuted)),
                    ],
                  ),
                )
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // User info banner
                        if (auth.hasProfile)
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(14),
                            margin: const EdgeInsets.only(bottom: 16),
                            decoration: BoxDecoration(
                              color: AppTheme.softLeaf,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.check_circle,
                                    color: AppTheme.trafordOrange, size: 20),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Ordering as ${auth.userName}',
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w600,
                                          fontSize: 14,
                                          color: AppTheme.growthGreen,
                                        ),
                                      ),
                                      if (auth.userPhone != null)
                                        Text(
                                          auth.userPhone!,
                                          style: const TextStyle(
                                            fontSize: 12,
                                            color: AppTheme.textMuted,
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),

                        // Shipping Information
                        _sectionTitle('Shipping Information'),
                        const SizedBox(height: 12),
                        _buildCard(
                          child: Column(
                            children: [
                              TextFormField(
                                controller: _nameController,
                                textCapitalization: TextCapitalization.words,
                                decoration: const InputDecoration(
                                  labelText: 'Full Name',
                                  hintText: 'e.g. Jane Doe',
                                  prefixIcon: Icon(Icons.person_outline),
                                ),
                                validator: (v) => v == null || v.trim().isEmpty
                                    ? 'Full name is required'
                                    : null,
                              ),
                              const SizedBox(height: 16),
                              TextFormField(
                                controller: _emailController,
                                keyboardType: TextInputType.emailAddress,
                                decoration: const InputDecoration(
                                  labelText: 'Email (optional)',
                                  hintText: 'you@example.com',
                                  prefixIcon: Icon(Icons.email_outlined),
                                ),
                                validator: (v) {
                                  if (v == null || v.trim().isEmpty) {
                                    return null; // optional
                                  }
                                  final email = v.trim();
                                  final ok = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$')
                                      .hasMatch(email);
                                  return ok ? null : 'Enter a valid email';
                                },
                              ),
                              const SizedBox(height: 16),
                              TextFormField(
                                controller: _addressController,
                                decoration: const InputDecoration(
                                  labelText: 'Delivery Address',
                                  hintText: 'Enter your delivery address',
                                  prefixIcon:
                                      Icon(Icons.location_on_outlined),
                                ),
                                validator: (v) => v == null || v.isEmpty
                                    ? 'Address is required'
                                    : null,
                              ),
                              const SizedBox(height: 16),
                              Row(
                                children: [
                                  Expanded(
                                    child: TextFormField(
                                      initialValue: 'Uganda',
                                      enabled: false,
                                      decoration: const InputDecoration(
                                        labelText: 'Country',
                                        prefixIcon: Icon(Icons.flag),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 16),
                              TextFormField(
                                controller: _phoneController,
                                keyboardType: TextInputType.phone,
                                decoration: const InputDecoration(
                                  labelText: 'Phone Number',
                                  hintText: '256XXXXXXXXX',
                                  prefixIcon: Icon(Icons.phone),
                                ),
                                validator: (v) => v == null || v.trim().isEmpty
                                    ? 'Phone is required'
                                    : null,
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 24),

                        // Payment Method
                        _sectionTitle('Payment Method'),
                        const SizedBox(height: 12),
                        _buildCard(
                          child: Column(
                            children: [
                              _paymentOption(
                                'cash',
                                'Cash on Delivery',
                                Icons.money,
                                'Pay when your order arrives',
                              ),
                              const Divider(height: 1),
                              _paymentOption(
                                'mobile',
                                'Mobile Money',
                                Icons.phone_android,
                                'MTN or Airtel Mobile Money',
                              ),
                              const Divider(height: 1),
                              _paymentOption(
                                'card',
                                'Credit/Debit Card',
                                Icons.credit_card,
                                'Visa, Mastercard accepted',
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 24),

                        // Order Summary
                        _sectionTitle('Order Summary'),
                        const SizedBox(height: 12),
                        _buildCard(
                          child: Column(
                            children: [
                              ...cart.items.map(
                                (item) => Padding(
                                  padding:
                                      const EdgeInsets.symmetric(vertical: 6),
                                  child: Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      Expanded(
                                        child: Text(
                                          '${item.product.name} x${item.quantity}',
                                          style:
                                              const TextStyle(fontSize: 14),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                      Text(
                                        'UGX ${formatUGX(item.subtotal)}',
                                        style: const TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              const Divider(height: 20),
                              _totalRow('Subtotal', cart.subtotal),
                              const SizedBox(height: 6),
                              _totalRow('Tax (10%)', cart.tax),
                              const Divider(height: 20),
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  const Text(
                                    'Total',
                                    style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                  Text(
                                    'UGX ${formatUGX(cart.total)}',
                                    style: const TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.w800,
                                      color: AppTheme.trafordOrange,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 24),

                        // Place Order Button
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed:
                                _isProcessing ? null : _placeOrder,
                            style: ElevatedButton.styleFrom(
                              padding:
                                  const EdgeInsets.symmetric(vertical: 16),
                            ),
                            child: _isProcessing
                                ? const SizedBox(
                                    height: 20,
                                    width: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white,
                                    ),
                                  )
                                : const Text(
                                    'Place Order',
                                    style: TextStyle(fontSize: 16),
                                  ),
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

  Widget _paymentOption(
      String value, String title, IconData icon, String subtitle) {
    final selected = _paymentMethod == value;
    return InkWell(
      onTap: () => setState(() => _paymentMethod = value),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Row(
          children: [
            Container(
              width: 22,
              height: 22,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color:
                      selected ? AppTheme.trafordOrange : AppTheme.textMuted,
                  width: 2,
                ),
              ),
              child: selected
                  ? Center(
                      child: Container(
                        width: 12,
                        height: 12,
                        decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                          color: AppTheme.trafordOrange,
                        ),
                      ),
                    )
                  : null,
            ),
            const SizedBox(width: 14),
            Icon(icon, color: AppTheme.trafordOrange, size: 22),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: const TextStyle(
                        fontWeight: FontWeight.w600, fontSize: 14)),
                Text(subtitle,
                    style: const TextStyle(
                        fontSize: 12, color: AppTheme.textMuted)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _totalRow(String label, double amount) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label,
            style: const TextStyle(fontSize: 14, color: AppTheme.textMuted)),
        Text(
          'UGX ${formatUGX(amount)}',
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
        ),
      ],
    );
  }

  void _placeOrder() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isProcessing = true);

    final cart = context.read<CartService>();
    final auth = context.read<AuthService>();
    final notifService = context.read<NotificationService>();

    try {
      // Build the items payload from the cart for the public guest-checkout
      // endpoint. Server will compute totals, generate TFF-YYYY-NNNNNN, and
      // create the auth.users + profile shell if no account exists.
      final items = cart.items
          .map((it) => {
                'product_id': it.productId,
                'quantity': it.quantity,
              })
          .toList();

      final emailText = _emailController.text.trim();
      final response = await ApiClient.guestCheckout(
        fullName: _nameController.text.trim(),
        phone: _phoneController.text.trim(),
        email: emailText.isEmpty ? null : emailText,
        deliveryAddress: _addressController.text.trim(),
        deliveryCity: 'Uganda',
        notes: 'Payment method: $_paymentMethod',
        items: items,
      );

      // Server has accepted the order. Clear the cart:
      //  - For logged-in users we drop server-side cart_items.
      //  - For guests (no userId) we just clear local state.
      if (cart.userId != null) {
        await cart.clearCart();
      } else {
        cart.clearCartLocal();
      }

      // Refresh notifications for logged-in users (guests have no userId).
      if (auth.userId != null) {
        await notifService.loadNotifications(auth.userId!);
      }

      if (!mounted) return;
      setState(() => _isProcessing = false);

      _showSuccessDialog(response);
    } catch (e) {
      if (!mounted) return;
      setState(() => _isProcessing = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Could not place order: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _showSuccessDialog(Map<String, dynamic> response) {
    // The public API returns { order: {...} } OR the order fields at the top
    // level — accept either shape.
    final order = (response['order'] is Map<String, dynamic>)
          ? response['order'] as Map<String, dynamic>
          : response;

    final orderNumber = (order['order_number'] as String?) ?? 'TFF-PENDING';
    final status = (order['status'] as String?) ?? 'pending';
    final totalRaw = order['total'] ?? order['total_amount'];
    final double totalAmount = totalRaw is num
        ? totalRaw.toDouble()
        : double.tryParse('${totalRaw ?? ''}') ?? 0.0;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: const BoxDecoration(
                color: AppTheme.softLeaf,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.check_circle,
                color: AppTheme.trafordOrange,
                size: 48,
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'Order Placed!',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 12),
            // Highlighted order number pill
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: AppTheme.softLeaf,
                borderRadius: BorderRadius.circular(30),
                border: Border.all(color: AppTheme.trafordOrange, width: 1),
              ),
              child: Text(
                orderNumber,
                style: const TextStyle(
                  fontFamily: 'monospace',
                  fontWeight: FontWeight.w800,
                  color: AppTheme.trafordOrange,
                  letterSpacing: 1.1,
                  fontSize: 16,
                ),
              ),
            ),
            const SizedBox(height: 12),
            // Total + status mini row
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  'UGX ${formatUGX(totalAmount)}',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(width: 10),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: AppTheme.trafordOrange.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    status.toUpperCase(),
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      color: AppTheme.trafordOrange,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            const Text(
              "Thank you! We've received your order and will be in touch shortly with delivery details.",
              textAlign: TextAlign.center,
              style: TextStyle(color: AppTheme.textMuted, height: 1.4),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  Navigator.pop(ctx);
                  Navigator.pop(context);
                },
                child: const Text('Done'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
