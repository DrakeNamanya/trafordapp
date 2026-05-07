import 'dart:async';
import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class HeroCarousel extends StatefulWidget {
  final void Function(int)? onNavigate;

  const HeroCarousel({super.key, this.onNavigate});

  @override
  State<HeroCarousel> createState() => _HeroCarouselState();
}

class _HeroCarouselState extends State<HeroCarousel> {
  final PageController _pageController = PageController();
  int _currentPage = 0;
  Timer? _timer;

  final List<Map<String, String>> _slides = [
    {
      'image': 'https://images.pexels.com/photos/2255935/pexels-photo-2255935.jpeg?auto=compress&cs=tinysrgb&w=1260&h=750&dpr=1', // Vegetables
      'title': 'Fresh Organic\nVegetables',
      'subtitle': 'Hand-picked from local\ngardens for you',
    },
    {
      'image': 'https://images.pexels.com/photos/5945655/pexels-photo-5945655.jpeg?auto=compress&cs=tinysrgb&w=1260&h=750&dpr=1',
      'title': 'Premium Quality\nMatooke',
      'subtitle': 'Direct from the farm\nto your kitchen',
    },
    {
      'image': 'https://images.pexels.com/photos/2985167/pexels-photo-2985167.jpeg?auto=compress&cs=tinysrgb&w=1260&h=750&dpr=1', // Eggs
      'title': 'Farm Fresh\nTray Eggs',
      'subtitle': 'Rich in protein,\nnaturally sourced',
    },
  ];

  @override
  void initState() {
    super.initState();
    // Use the long URL for Matooke if the direct one fails, but let's try a Pexels one for safety:
    // Actually, Matooke is specific. Let's use the Pexels green banana one I found manually:
    // https://images.pexels.com/photos/5963539/pexels-photo-5963539.jpeg (Green bananas)
    _slides[1]['image'] = 'https://images.pexels.com/photos/5963539/pexels-photo-5963539.jpeg?auto=compress&cs=tinysrgb&w=1260&h=750&dpr=1';

    _startAutoScroll();
  }

  void _startAutoScroll() {
    _timer = Timer.periodic(const Duration(seconds: 5), (timer) {
      if (_currentPage < _slides.length - 1) {
        _currentPage++;
      } else {
        _currentPage = 0;
      }

      if (_pageController.hasClients) {
        _pageController.animateToPage(
          _currentPage,
          duration: const Duration(milliseconds: 500),
          curve: Curves.easeInOut,
        );
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 220, // Adjust height as needed
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: PageView.builder(
        controller: _pageController,
        onPageChanged: (index) {
          setState(() {
            _currentPage = index;
          });
        },
        itemCount: _slides.length,
        itemBuilder: (context, index) {
          final slide = _slides[index];
          return _buildCard(
            image: slide['image']!,
            title: slide['title']!,
            subtitle: slide['subtitle']!,
          );
        },
      ),
    );
  }

  Widget _buildCard({
    required String image,
    required String title,
    required String subtitle,
  }) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 4), // Spacing between slides
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        image: DecorationImage(
          image: NetworkImage(image),
          fit: BoxFit.cover,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          gradient: LinearGradient(
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
            colors: [
              Colors.black.withValues(alpha: 0.8),
              Colors.black.withValues(alpha: 0.3),
              Colors.transparent,
            ],
          ),
        ),
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              title,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 24,
                fontWeight: FontWeight.w800,
                height: 1.2,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              subtitle,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.9),
                fontSize: 14,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () => widget.onNavigate?.call(1), // Navigate to Shop
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: AppTheme.trafordOrange,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(30),
                ),
                elevation: 0,
              ),
              child: const Text(
                'Shop Now',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
