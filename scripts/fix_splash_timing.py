import pathlib

p = pathlib.Path(r'lib/features/splash/splash_screen.dart')
content = p.read_text(encoding='utf-8')

# Slow down the total intro duration
content = content.replace(
    "static const Duration _introFull = Duration(milliseconds: 2200);",
    "static const Duration _introFull = Duration(milliseconds: 3000);"
)

# Slow down shockwave ring animation in cold start
content = content.replace(
    """.animate(delay: 80.ms)
                    .scaleXY(
                      begin: 0.45,
                      end: 1.65,
                      duration: 350.ms,
                      curve: Curves.easeOutCubic,
                    )
                    .then()
                    .fadeOut(duration: 300.ms),""",
    """.animate(delay: 120.ms)
                    .scaleXY(
                      begin: 0.45,
                      end: 1.65,
                      duration: 500.ms,
                      curve: Curves.easeOutCubic,
                    )
                    .then()
                    .fadeOut(duration: 400.ms),"""
)

# Slow down logo mark animation in cold start
content = content.replace(
    """_LogoMark()
                    .animate(delay: 50.ms)
                    .scaleXY(
                      begin: 0.4,
                      end: 1,
                      duration: 450.ms,
                      curve: Curves.easeOutBack,
                    )
                    .rotate(
                      begin: -0.12,
                      end: 0,
                      duration: 450.ms,
                      curve: Curves.easeOutCubic,
                    )
                    .fadeIn(duration: 500.ms),""",
    """_LogoMark()
                    .animate(delay: 80.ms)
                    .scaleXY(
                      begin: 0.4,
                      end: 1,
                      duration: 600.ms,
                      curve: Curves.easeOutBack,
                    )
                    .rotate(
                      begin: -0.12,
                      end: 0,
                      duration: 600.ms,
                      curve: Curves.easeOutCubic,
                    )
                    .fadeIn(duration: 600.ms),"""
)

# Slow down wordmark reveal
content = content.replace(
    """_StaggeredWordmark(color: fg)
              .animate(delay: 700.ms)
              .shimmer(
                duration: 800.ms,
                color: AppColors.accent.withValues(alpha: 0.45),
              ),""",
    """_StaggeredWordmark(color: fg)
              .animate(delay: 1000.ms)
              .shimmer(
                duration: 1000.ms,
                color: AppColors.accent.withValues(alpha: 0.45),
              ),"""
)

# Slow down tagline drift
content = content.replace(
    """.animate(delay: 1000.ms)
              .slideY(begin: 0.25)
              .fadeIn(duration: 500.ms),""",
    """.animate(delay: 1400.ms)
              .slideY(begin: 0.25)
              .fadeIn(duration: 600.ms),"""
)

# Slow down pulsing dots fade-in
content = content.replace(
    """.animate(delay: 1200.ms)
              .fadeIn(duration: 250.ms),""",
    """.animate(delay: 1700.ms)
              .fadeIn(duration: 400.ms),"""
)

p.write_text(content, encoding='utf-8')
print("Splash: slowed all animation timings")
