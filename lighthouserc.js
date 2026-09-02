module.exports = {
  ci: {
    collect: {
      url: [
        'http://localhost:3000/',
        'http://localhost:3000/login',
        'http://localhost:3000/gallery',
      ],
      startServerCommand: 'flutter run -d chrome --web-port=3000 --web-hostname=localhost',
      startServerReadyPattern: 'Flutter run key commands.',
      startServerTimeout: 120,
      numberOfRuns: 1,
      chromeFlags: ['--headless', '--no-sandbox', '--disable-gpu'],
    },
    assert: {
      assertions: {
        // Categories — thresholds based on current baseline
        'categories:performance': ['warn', { minScore: 0.55 }],
        'categories:accessibility': ['error', { minScore: 0.95 }],
        'categories:best-practices': ['warn', { minScore: 0.70 }],
        'categories:seo': ['error', { minScore: 0.95 }],

        // Core Web Vitals
        'first-contentful-paint': ['warn', { maxNumericValue: 3000 }],
        'largest-contentful-paint': ['warn', { maxNumericValue: 4000 }],
        'total-blocking-time': ['warn', { maxNumericValue: 7000 }],
        'cumulative-layout-shift': ['error', { maxNumericValue: 0.1 }],
        'speed-index': ['warn', { maxNumericValue: 18000 }],

        // Accessibility: color contrast (WCAG AA)
        'color-contrast': ['error', { minScore: 1 }],

        // Accessibility: critical interactive element checks
        'image-alt': ['error', { minScore: 1 }],
        'label': ['error', { minScore: 1 }],
        'link-name': ['error', { minScore: 1 }],
        'button-name': ['error', { minScore: 1 }],
        'html-has-lang': ['error', { minScore: 1 }],
        'meta-viewport': ['error', { minScore: 1 }],
      },
    },
    upload: {
      target: 'filesystem',
      outputDir: './lighthouse-reports',
    },
  },
};
