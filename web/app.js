// ArtVault browser-side bootstrap helpers.
// Consolidated from inline <script> blocks so the Content-Security-Policy
// served by firebase.json can drop 'unsafe-inline' from script-src.
// Loaded as a blocking script in <head> (same semantics as the inline code).

// Session timeout: auto-logout after 30 minutes of inactivity
(function() {
  var TIMEOUT_MS = 30 * 60 * 1000; // 30 minutes
  var timer;
  function resetTimer() {
    clearTimeout(timer);
    timer = setTimeout(function() {
      // Clear Firebase auth persistence
      try {
        localStorage.removeItem('firebase:authUser:AIzaSyAlEmaqwhaF9X49NX56Z5CtgznjYsa3r-Q:[DEFAULT]');
        sessionStorage.clear();
      } catch(e) {}
      // Reload to trigger auth state check
      window.location.reload();
    }, TIMEOUT_MS);
  }
  // Reset on any user activity
  ['mousedown', 'mousemove', 'keydown', 'scroll', 'touchstart'].forEach(function(evt) {
    document.addEventListener(evt, resetTimer, { passive: true });
  });
  resetTimer();
})();

// Input sanitization helper — strips HTML tags from user input
window.artvaultSanitize = function(str) {
  if (!str) return str;
  var div = document.createElement('div');
  div.appendChild(document.createTextNode(str));
  return div.innerHTML;
};

// Register service worker for offline support + push notifications
if ('serviceWorker' in navigator) {
  window.addEventListener('load', function() {
    navigator.serviceWorker.register('/sw.js').then(function(reg) {
      console.log('[ArtVault] Service worker registered, scope:', reg.scope);
    }).catch(function(err) {
      console.warn('[ArtVault] SW registration failed:', err);
    });
  });
}

// Override Flutter's default viewport meta that blocks pinch-to-zoom.
// Flutter injects maximum-scale=1.0, user-scalable=no which is a WCAG
// accessibility violation. We reset it after Flutter's bootstrap runs.
window.addEventListener('flutter-first-frame', function() {
  var vp = document.querySelector('meta[name="viewport"]');
  if (vp) {
    vp.setAttribute('content', 'width=device-width, initial-scale=1.0, maximum-scale=5.0, user-scalable=yes');
  }
});
// Also try immediately in case flutter-first-frame is delayed
setTimeout(function() {
  var vp = document.querySelector('meta[name="viewport"]');
  if (vp && vp.getAttribute('content') && vp.getAttribute('content').indexOf('user-scalable=no') !== -1) {
    vp.setAttribute('content', 'width=device-width, initial-scale=1.0, maximum-scale=5.0, user-scalable=yes');
  }
}, 3000);

// Hide HTML splash once Flutter renders first frame
window.addEventListener('flutter-first-frame', function() {
  var el = document.getElementById('av-html-splash');
  if (el) { el.style.opacity = '0'; setTimeout(function(){ el.remove(); }, 500); }
});
// Fallback: hide after 8s even if event missed
setTimeout(function(){ var el=document.getElementById('av-html-splash'); if(el) el.style.display='none'; }, 8000);
