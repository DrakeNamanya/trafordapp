import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/auth_service.dart';
import '../services/cart_service.dart';
import '../services/order_service.dart';
import '../services/notification_service.dart';
import '../services/location_service.dart';
import '../theme/app_theme.dart';
import '../widgets/product_card.dart';
import 'login_screen.dart';

class CheckoutScreen extends StatefulWidget {
  const CheckoutScreen({super.key});

  @override
  State<CheckoutScreen> createState() => _CheckoutScreenState();
}

class _CheckoutScreenState extends State<CheckoutScreen> {
  final _formKey = GlobalKey<FormState>();
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
    _addressController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  /// Check if user has a complete profile. If not, redirect to login/register.
  void _checkUserProfile() {
    final auth = Provider.of<AuthService>(context, listen: false);

    if (!auth.hasProfile) {
      // User doesn't have a complete profile -> show login/register
      _showAccountRequiredDialog();
    } else {
      // Pre-fill phone from profile
      final locService = Provider.of<LocationService>(context, listen: false);
      final profile = auth.profile;
      if (profile != null) {
        _phoneController.text = profile['phone'] ?? '';
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
  }

  void _showAccountRequiredDialog() {
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
                Icons.person_outline,
                color: AppTheme.trafordOrange,
                size: 48,
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'Account Required',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 8),
            const Text(
              'To complete your order, you need to sign in or create an account.\n\nThis helps us deliver your fresh products to you!',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppTheme.textMuted, height: 1.4),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  Navigator.pop(ctx);
                  _openLoginScreen();
                },
                child: const Text('Sign In / Create Account'),
              ),
            ),
            const SizedBox(height: 8),
            TextButton(
              onPressed: () {
                Navigator.pop(ctx);
                Navigator.pop(context); // Go back to cart
              },
              child: const Text('Cancel'),
            ),
          ],
        ),
      ),
    );
  }

  void _openLoginScreen() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => LoginScreen(
          onSuccess: () {
            // After successful login/register, re-check profile
            if (mounted) {
              setState(() => _checkedAuth = false);
              WidgetsBinding.instance.addPostFrameCallback((_) {
                _checkUserProfile();
              });
            }
          },
        ),
      ),
    );
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
                                validator: (v) => v == null || v.isEmpty
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
    final orderService = context.read<OrderService>();
    final auth = context.read<AuthService>();
    final notifService = context.read<NotificationService>();

    try {
      final order = await orderService.placeOrder(
        userId: auth.userId ?? cart.userId!,
        items: cart.items,
        subtotal: cart.subtotal,
        tax: cart.tax,
        total: cart.total,
        shippingAddress: _addressController.text,
        shippingCity: 'Uganda',
        shippingPhone: _phoneController.text,
        paymentMethod: _paymentMethod,
      );

      // Clear cart locally after successful order
      await cart.loadCart();

      // Reload notifications
      if (auth.userId != null) {
        await notifService.loadNotifications(auth.userId!);
      }

      if (!mounted) return;

      setState(() => _isProcessing = false);

      if (order != null) {
        _showSuccessDialog(order.orderNumber);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to place order. Please try again.'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _isProcessing = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _showSuccessDialog(String orderNumber) {
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
            const SizedBox(height: 8),
            Text(
              'Your order $orderNumber has been sent to admin for processing.\n\nYou will receive notifications on the status of your order!',
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppTheme.textMuted, height: 1.4),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  Navigator.pop(ctx);
                  Navigator.pop(context);
                },
                child: const Text('View Orders'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
