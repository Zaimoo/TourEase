import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class OnboardingScreen extends StatefulWidget {
  final VoidCallback onComplete;

  const OnboardingScreen({super.key, required this.onComplete});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen>
    with TickerProviderStateMixin {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  late AnimationController _fadeController;
  late AnimationController _slideController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  final List<OnboardingPage> _pages = [
    OnboardingPage(
      icon: Icons.compass_calibration_rounded,
      title: 'Welcome to TourEase',
      subtitle: 'Your Tourism Wayfinding Companion',
      description:
          'TourEase helps you discover and navigate to the best tourist spots in Iligan City using local transportation.',
      color: const Color(0xFF4FC3F7),
      features: [
        FeatureItem(Icons.explore, 'Discover amazing tourist destinations'),
        FeatureItem(Icons.map_rounded, 'Navigate with ease'),
        FeatureItem(Icons.star_rounded, 'Rate and review places'),
      ],
    ),
    OnboardingPage(
      icon: Icons.location_on_rounded,
      title: 'Nearby Tourist Spots',
      subtitle: 'Find Places Around You',
      description:
          'See all nearby tourist destinations sorted by distance. Browse by category and find the perfect spot for your adventure.',
      color: const Color(0xFF81C784),
      features: [
        FeatureItem(Icons.near_me, 'Places sorted by distance'),
        FeatureItem(Icons.category_rounded, 'Browse by category'),
        FeatureItem(Icons.info_outline, 'Detailed info, hours & fees'),
      ],
    ),
    OnboardingPage(
      icon: Icons.directions_bus_rounded,
      title: 'Local Transportation',
      subtitle: 'Jeepney, Habal-Habal, Sikad & More',
      description:
          'Get directions using local transport modes. We show you which Jeepney to ride, where to find a Habal-Habal, and estimated fares.',
      color: const Color(0xFFFFB74D),
      features: [
        FeatureItem(Icons.directions_bus, 'Jeepney routes & stops'),
        FeatureItem(Icons.motorcycle, 'Habal-Habal (motorcycle taxi)'),
        FeatureItem(Icons.pedal_bike, 'Sikad (pedicab) options'),
      ],
    ),
    OnboardingPage(
      icon: Icons.alt_route_rounded,
      title: 'Smart Route Planning',
      subtitle: 'Cheapest vs Most Convenient',
      description:
          'Compare route options and estimated fares before you go. Choose multimodal routes combining walking, jeepney, and habal-habal.',
      color: const Color(0xFF9575CD),
      features: [
        FeatureItem(Icons.payments_outlined, 'Estimated fare breakdown'),
        FeatureItem(Icons.swap_horiz, 'Compare route options'),
        FeatureItem(Icons.navigation_rounded, 'Real-time task tracking'),
      ],
    ),
    OnboardingPage(
      icon: Icons.favorite_rounded,
      title: 'Personalize Your Experience',
      subtitle: 'Favorites, Reviews & Trip History',
      description:
          'Save your favorite spots, leave reviews for places you\'ve visited, and track your travel history throughout Iligan City.',
      color: const Color(0xFFE57373),
      features: [
        FeatureItem(Icons.favorite_border, 'Save favorite destinations'),
        FeatureItem(
            Icons.rate_review_outlined, 'Review places you\'ve visited'),
        FeatureItem(Icons.history, 'View your trip history'),
      ],
    ),
  ];

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _slideController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _fadeAnimation = CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeIn,
    );
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.3),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _slideController,
      curve: Curves.easeOut,
    ));
    _fadeController.forward();
    _slideController.forward();
  }

  @override
  void dispose() {
    _pageController.dispose();
    _fadeController.dispose();
    _slideController.dispose();
    super.dispose();
  }

  void _nextPage() {
    if (_currentPage < _pages.length - 1) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeInOut,
      );
    } else {
      _completeOnboarding();
    }
  }

  void _skipOnboarding() {
    _completeOnboarding();
  }

  Future<void> _completeOnboarding() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('hasSeenOnboarding', true);
    widget.onComplete();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // Animated background
          AnimatedContainer(
            duration: const Duration(milliseconds: 500),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  _pages[_currentPage].color.withOpacity(0.15),
                  _pages[_currentPage].color.withOpacity(0.05),
                  Colors.white,
                ],
              ),
            ),
          ),

          SafeArea(
            child: Column(
              children: [
                // Skip button
                Align(
                  alignment: Alignment.topRight,
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: TextButton(
                      onPressed: _skipOnboarding,
                      child: Text(
                        _currentPage == _pages.length - 1 ? '' : 'Skip',
                        style: TextStyle(
                          color: Colors.grey[600],
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ),
                ),

                // Page content
                Expanded(
                  child: PageView.builder(
                    controller: _pageController,
                    itemCount: _pages.length,
                    onPageChanged: (index) {
                      setState(() {
                        _currentPage = index;
                      });
                      _fadeController.reset();
                      _slideController.reset();
                      _fadeController.forward();
                      _slideController.forward();
                    },
                    itemBuilder: (context, index) {
                      return _buildPage(_pages[index]);
                    },
                  ),
                ),

                // Page indicators
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 20),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(
                      _pages.length,
                      (index) => AnimatedContainer(
                        duration: const Duration(milliseconds: 300),
                        margin: const EdgeInsets.symmetric(horizontal: 4),
                        width: _currentPage == index ? 32 : 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: _currentPage == index
                              ? _pages[_currentPage].color
                              : Colors.grey[300],
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                    ),
                  ),
                ),

                // Action buttons
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 0, 24, 32),
                  child: SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: ElevatedButton(
                      onPressed: _nextPage,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _pages[_currentPage].color,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        elevation: 4,
                        shadowColor:
                            _pages[_currentPage].color.withOpacity(0.4),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            _currentPage == _pages.length - 1
                                ? 'Get Started'
                                : 'Next',
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Icon(
                            _currentPage == _pages.length - 1
                                ? Icons.check_circle_outline
                                : Icons.arrow_forward_rounded,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPage(OnboardingPage page) {
    return FadeTransition(
      opacity: _fadeAnimation,
      child: SlideTransition(
        position: _slideAnimation,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Animated icon
              TweenAnimationBuilder<double>(
                tween: Tween(begin: 0.0, end: 1.0),
                duration: const Duration(milliseconds: 800),
                curve: Curves.elasticOut,
                builder: (context, value, child) {
                  return Transform.scale(
                    scale: value,
                    child: child,
                  );
                },
                child: Container(
                  width: 120,
                  height: 120,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        page.color,
                        page.color.withOpacity(0.7),
                      ],
                    ),
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: page.color.withOpacity(0.3),
                        blurRadius: 20,
                        spreadRadius: 5,
                      ),
                    ],
                  ),
                  child: Icon(
                    page.icon,
                    color: Colors.white,
                    size: 56,
                  ),
                ),
              ),

              const SizedBox(height: 32),

              // Title
              Text(
                page.title,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                  letterSpacing: -0.5,
                ),
              ),

              const SizedBox(height: 8),

              // Subtitle
              Text(
                page.subtitle,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: page.color,
                ),
              ),

              const SizedBox(height: 16),

              // Description
              Text(
                page.description,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 15,
                  color: Colors.grey[600],
                  height: 1.5,
                ),
              ),

              const SizedBox(height: 32),

              // Feature items
              ...page.features.map((feature) => Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: page.color.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Icon(
                            feature.icon,
                            color: page.color,
                            size: 22,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Text(
                            feature.label,
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w500,
                              color: Colors.black87,
                            ),
                          ),
                        ),
                      ],
                    ),
                  )),
            ],
          ),
        ),
      ),
    );
  }
}

class OnboardingPage {
  final IconData icon;
  final String title;
  final String subtitle;
  final String description;
  final Color color;
  final List<FeatureItem> features;

  OnboardingPage({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.description,
    required this.color,
    required this.features,
  });
}

class FeatureItem {
  final IconData icon;
  final String label;

  FeatureItem(this.icon, this.label);
}
