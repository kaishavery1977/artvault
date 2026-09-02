
module.exports = {
  ci: {
    collect: {
      // Lighthouse will audit these URLs
      url: [
        'http://localhost:3000/',
        'http://localhost:3000/login',
        'http://localhost:3000/gallery',
      ],
      // Start the web server before running Lighthouse
      startServerCommand: 'flutter run -d chrome --web-port=3000 --web-hostname=localhost',
      startServerReadyPattern: 'Flutter run key commands.',
      startServerTimeout: 120,
      // Number of runs per URL (average out variance)
      numberOfRuns: 1,
      // Chrome flags for headless mode
      chromeFlags: ['--headless', '--no-sandbox', '--disable-gpu'],
    },
    assert: {
      // Performance budget - these are the minimum scores
      assertions: {
        'categories:performance': ['error', { minScore: 0.5 }],
        'categories:accessibility': ['warn', { minScore: 0.7 }],
        'categories:best-practices': ['warn', { minScore: 0.7 }],
        'categories:seo': ['warn', { minScore: 0.5 }],
        // Specific metric budgets
        'first-contentful-paint': ['warn', { maxNumericValue: 3000 }],
        'largest-contentful-paint': ['warn', { maxNumericValue: 4000 }],
        'total-blocking-time': ['warn', { maxNumericValue: 300 }],
        'cumulative-layout-shift': ['warn', { maxNumericValue: 0.1 }],
        'speed-index': ['warn', { maxNumericValue: 4000 }],
      },
    },
    upload: {
      // Store results in GitHub Actions
      target: 'filesystem',
      outputDir: './lighthouse-reports',
    },
  },
};
