import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/agro_service.dart';
import '../services/auth_service.dart';
import '../services/api_client.dart';
import '../theme/app_theme.dart';

/// Staff agro-order checkout. POSTs to /api/public/agro-orders.
/// The backend trigger auto-routes the order:
///   total <= app_settings.agro_approval_threshold_ugx => status='confirmed'
///   total >  threshold                                 => status='pending'
class AgroCheckoutScreen extends StatefulWidget {
  const AgroCheckoutScreen({super.key});

  @override
  State<AgroCheckoutScreen> createState() => _AgroCheckoutScreenState();
}

class _AgroCheckoutScreenState extends State<AgroCheckoutScreen> {
  final _formKey = GlobalKey<FormState>();
  final _addressCtrl = TextEditingController();
  final _cityCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();
  bool _processing = false;

  @override
  void dispose() {
    _addressCtrl.dispose();
    _cityCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _processing = true);

    final auth = context.read<AuthService>();
    final agro = context.read<AgroService>();
    ApiClient.bearerToken = auth.accessToken;

    try {
      final result = await agro.placeOrder(
        deliveryAddress: _addressCtrl.text.trim(),
        deliveryCity: _cityCtrl.text.trim(),
        notes: _notesCtrl.text.trim().isEmpty ? null : _notesCtrl.text.trim(),
      );
      if (!mounted) return;
      _showSuccess(result);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Order failed: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) setState(() => _processing = false);
    }
  }

  void _showSuccess(Map<String, dynamic> result) {
    final orderNumber = result['order_number'] as String? ?? 'TAI-?';
    final status = result['status'] as String? ?? 'pending';
    final total = (result['total'] as num?)?.toDouble() ?? 0;
    final autoApproved = status == 'confirmed';

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              autoApproved ? Icons.check_circle : Icons.hourglass_top,
              size: 56,
              color: autoApproved
                  ? AppTheme.trafordOrange
                  : Colors.amber[700],
            ),
            const SizedBox(height: 16),
            Text(
              autoApproved
                  ? 'Order auto-approved'
                  : 'Order submitted for review',
              style: const TextStyle(
                  fontSize: 18, fontWeight: FontWeight.w800),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(orderNumber,
                style: const TextStyle(
                    color: AppTheme.trafordOrange,
                    fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            Text('Total: UGX ${_fmt(total)}',
                style: const TextStyle(color: AppTheme.textMuted)),
            const SizedBox(height: 12),
            Text(
              autoApproved
                  ? 'Below the approval threshold — you can collect immediately.'
                  : 'Above the approval threshold — admin must approve before fulfilment.',
              style: const TextStyle(
                  fontSize: 12, color: AppTheme.textMuted),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  Navigator.pop(ctx);
                  Navigator.pop(context); // back to AgroShop
                },
                child: const Text('Done'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final agro = context.watch<AgroService>();

    return Scaffold(
      appBar: AppBar(
        backgroundColor: AppTheme.trafordOrange,
        title: const Text('Agro Checkout'),
      ),
      body: agro.cart.isEmpty
          ? const Center(child: Text('Your agro cart is empty'))
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _section('Delivery Information'),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: _addressCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Delivery Address',
                        hintText: 'e.g. Plot 12, Mukono',
                        prefixIcon: Icon(Icons.location_on_outlined),
                      ),
                      validator: (v) =>
                          v == null || v.trim().isEmpty ? 'Required' : null,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _cityCtrl,
                      decoration: const InputDecoration(
                        labelText: 'City / District (optional)',
                        prefixIcon: Icon(Icons.location_city_outlined),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _notesCtrl,
                      maxLines: 2,
                      decoration: const InputDecoration(
                        labelText: 'Notes (optional)',
                        prefixIcon: Icon(Icons.note_outlined),
                      ),
                    ),
                    const SizedBox(height: 24),
                    _section('Order Summary'),
                    const SizedBox(height: 8),
                    ...agro.cart.entries.map((e) {
                      final p = agro.products.firstWhere(
                        (x) => x.id == e.key,
                        orElse: () => agro.products.first,
                      );
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: Row(
                          children: [
                            Expanded(
                              child: Text('${p.name} x${e.value}',
                                  overflow: TextOverflow.ellipsis),
                            ),
                            Text(
                              'UGX ${_fmt(p.price * e.value)}',
                              style: const TextStyle(
                                  fontWeight: FontWeight.w600),
                            ),
                          ],
                        ),
                      );
                    }),
                    const Divider(height: 24),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Subtotal',
                            style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w700)),
                        Text('UGX ${_fmt(agro.cartSubtotal())}',
                            style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w800,
                                color: AppTheme.trafordOrange)),
                      ],
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Final price (incl. shipping) is calculated by the server '
                      'and routed for approval if it exceeds the agro threshold.',
                      style: TextStyle(
                          fontSize: 12, color: AppTheme.textMuted),
                    ),
                    const SizedBox(height: 24),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _processing ? null : _submit,
                        style: ElevatedButton.styleFrom(
                          padding:
                              const EdgeInsets.symmetric(vertical: 16),
                        ),
                        child: _processing
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white))
                            : const Text('Submit Agro Order'),
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _section(String s) => Text(s,
      style: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w800,
          color: AppTheme.textDark));

  String _fmt(num n) {
    final s = n.toStringAsFixed(0);
    final buf = StringBuffer();
    for (int i = 0; i < s.length; i++) {
      if (i > 0 && (s.length - i) % 3 == 0) buf.write(',');
      buf.write(s[i]);
    }
    return buf.toString();
  }
}
