module.exports = {
  ci: {
    collect: {
      url: [
        'http://localhost:3000/',
        'http://localhost:3000/login',
        'http://localhost:3000/gallery',
      ],
      // Audit the production artifact (release build), not the dev server.
      // `serve -s` rewrites unknown paths to index.html so the SPA routes
      // (/login, /gallery) resolve; LHCI starts and stops this server itself.
      // `serve` is pre-installed (pinned) in the workflow — never resolve it
      // through bare `npx serve`, which fetches the package at audit time and
      // can race the server-start window (CHROME_INTERSTITIAL_ERROR).
      // Run locally with:
      //   flutter build web --release && npx --yes @lhci/cli autorun
      // (bare `npx lhci` resolves an impostor placeholder package — see the
      // Lighthouse CI workflow for the full warning.)
      startServerCommand: 'serve -s build/web -l 3000',
      startServerReadyPattern: 'Serving',
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
