import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/responsive/responsive.dart';
import '../../../../core/router/routes.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/widgets/nestap_logo.dart';
import '../../onboarding_providers.dart';

typedef _Slide = ({IconData icon, List<IconData> orbit, String title, String body});

const _slides = <_Slide>[
  (
    icon: Icons.power_settings_new_rounded,
    orbit: [Icons.lightbulb_outline_rounded, Icons.power_outlined, Icons.curtains_outlined],
    title: 'Control every switch',
    body: 'Lights, sockets and curtains. From the sofa or the other side of the world.',
  ),
  (
    icon: Icons.auto_awesome_rounded,
    orbit: [Icons.wb_sunny_rounded, Icons.nightlight_round, Icons.movie_rounded],
    title: 'Scenes that set the mood',
    body: 'One tap for "Good Morning". Automations that run on time or when something changes.',
  ),
  (
    icon: Icons.bolt_rounded,
    orbit: [Icons.bar_chart_rounded, Icons.water_drop_outlined, Icons.savings_outlined],
    title: 'Know your energy',
    body: 'See what every socket and heater uses, by the hour, day and month.',
  ),
];

/// First-launch introduction. Shown once, before sign-in.
class WelcomePage extends ConsumerStatefulWidget {
  const WelcomePage({super.key});

  @override
  ConsumerState<WelcomePage> createState() => _WelcomePageState();
}

class _WelcomePageState extends ConsumerState<WelcomePage> {
  final _pages = PageController();
  int _index = 0;

  bool get _last => _index == _slides.length - 1;

  @override
  void dispose() {
    _pages.dispose();
    super.dispose();
  }

  void _finish() {
    ref.read(onboardingSeenProvider.notifier).markSeen();
    context.go(Routes.signIn);
  }

  void _next() {
    if (_last) {
      _finish();
    } else {
      _pages.nextPage(duration: const Duration(milliseconds: 350), curve: Curves.easeOutCubic);
    }
  }

  @override
  Widget build(BuildContext context) {
    final wide = !context.isCompact;
    return Scaffold(
      body: DecoratedBox(
        decoration: const BoxDecoration(gradient: AppColors.heroGradient),
        child: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(AppSpacing.xl, AppSpacing.lg, AppSpacing.md, 0),
                child: Row(
                  children: [
                    const NestapLogo(height: 32),
                    const Spacer(),
                    if (!_last)
                      TextButton(
                        onPressed: _finish,
                        style: TextButton.styleFrom(foregroundColor: AppColors.gray300),
                        child: const Text('Skip'),
                      ),
                  ],
                ),
              ),
              Expanded(
                child: PageView.builder(
                  controller: _pages,
                  itemCount: _slides.length,
                  onPageChanged: (i) => setState(() => _index = i),
                  itemBuilder: (context, i) => _SlideView(slide: _slides[i], wide: wide),
                ),
              ),
              _Dots(count: _slides.length, index: _index),
              Padding(
                padding: const EdgeInsets.all(AppSpacing.xl),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 420),
                  child: SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: _next,
                      child: Text(_last ? 'Get started' : 'Next'),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SlideView extends StatelessWidget {
  const _SlideView({required this.slide, required this.wide});

  final _Slide slide;
  final bool wide;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final copy = Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: wide ? CrossAxisAlignment.start : CrossAxisAlignment.center,
      children: [
        Text(
          slide.title,
          textAlign: wide ? TextAlign.start : TextAlign.center,
          style: text.headlineMedium?.copyWith(color: Colors.white, fontWeight: FontWeight.w900),
        ),
        const SizedBox(height: AppSpacing.md),
        Text(
          slide.body,
          textAlign: wide ? TextAlign.start : TextAlign.center,
          style: text.bodyLarge?.copyWith(color: AppColors.gray300, height: 1.5),
        ),
      ],
    );

    if (wide) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xxxl),
        child: Row(
          children: [
            Expanded(child: Center(child: _SlideArt(slide: slide, size: 320))),
            const SizedBox(width: AppSpacing.xxxl),
            Expanded(child: Center(child: SingleChildScrollView(child: copy))),
          ],
        ),
      );
    }
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Flexible(child: _SlideArt(slide: slide, size: 260)),
          const SizedBox(height: AppSpacing.xxl),
          copy,
        ],
      ),
    );
  }
}

/// Concentric glowing discs with the slide's main icon and three orbiting chips.
class _SlideArt extends StatelessWidget {
  const _SlideArt({required this.slide, required this.size});

  final _Slide slide;
  final double size;

  @override
  Widget build(BuildContext context) {
    final orbitPositions = [
      const Alignment(-0.95, -0.55),
      const Alignment(0.95, -0.2),
      const Alignment(-0.45, 0.95),
    ];
    return ConstrainedBox(
      constraints: BoxConstraints(maxWidth: size, maxHeight: size),
      child: AspectRatio(
        aspectRatio: 1,
        child: Stack(
          alignment: Alignment.center,
          children: [
            FractionallySizedBox(
              widthFactor: 1,
              heightFactor: 1,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [AppColors.cyan400.withValues(alpha: 0.28), Colors.transparent],
                  ),
                ),
              ),
            ),
            FractionallySizedBox(
              widthFactor: 0.62,
              heightFactor: 0.62,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.navy800,
                  border: Border.all(color: AppColors.brand.withValues(alpha: 0.4), width: 2),
                ),
              ),
            ),
            FractionallySizedBox(
              widthFactor: 0.36,
              heightFactor: 0.36,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: AppColors.activeGradient,
                  boxShadow: [
                    BoxShadow(color: AppColors.cyan400.withValues(alpha: 0.5), blurRadius: 40),
                  ],
                ),
                child: FittedBox(
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Icon(slide.icon, color: AppColors.navy),
                  ),
                ),
              ),
            ),
            for (final (i, icon) in slide.orbit.indexed)
              Align(
                alignment: orbitPositions[i % orbitPositions.length],
                child: Container(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  decoration: BoxDecoration(
                    color: AppColors.navy,
                    shape: BoxShape.circle,
                    border: Border.all(color: AppColors.navy700),
                  ),
                  child: Icon(icon, color: AppColors.brand, size: 26),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _Dots extends StatelessWidget {
  const _Dots({required this.count, required this.index});

  final int count;
  final int index;

  @override
  Widget build(BuildContext context) => Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          for (var i = 0; i < count; i++)
            AnimatedContainer(
              duration: const Duration(milliseconds: 250),
              margin: const EdgeInsets.symmetric(horizontal: 4),
              width: i == index ? 24 : 8,
              height: 8,
              decoration: BoxDecoration(
                color: i == index ? AppColors.cyan400 : AppColors.navy700,
                borderRadius: BorderRadius.circular(4),
              ),
            ),
        ],
      );
}
