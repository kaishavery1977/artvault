import 'package:flutter/widgets.dart';

/// Lightweight app-wide localization.
///
/// Keys are the English strings themselves — the source of truth lives at
/// each call site — so a missing translation simply renders the English
/// text (and the entire 245-test suite, which asserts English copy, keeps
/// passing unchanged under the default 'en' locale). Adding a language is
/// one extra map entry per string.
///
/// The active language comes from [L10n], an InheritedWidget installed
/// above `MaterialApp` from the persisted locale provider, so every
/// converted widget rebuilds the moment the language changes.
class L10n extends InheritedWidget {
  /// 'en', 'hi', …
  final String languageCode;

  const L10n({super.key, required this.languageCode, required super.child});

  /// The nearest language scope; registers a dependency so this widget
  /// rebuilds when the language changes.
  static L10n? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<L10n>();

  /// Translates [text] (English) into the active language. Falls back to
  /// the source text when the context is null or no translation exists.
  static String t(BuildContext? context, String text) {
    final active = context == null ? null : maybeOf(context);
    if (active == null || active.languageCode == 'en') return text;
    return _translations[active.languageCode]?[text] ?? text;
  }

  @override
  bool updateShouldNotify(L10n oldWidget) =>
      oldWidget.languageCode != languageCode;

  /// languageCode → (English key → translation).
  static const Map<String, Map<String, String>> _translations = {
    'hi': {
      // Shell navigation
      'Home': 'होम',
      'Gallery': 'गैलरी',
      'Artists': 'कलाकार',
      'Documents': 'दस्तावेज़',
      'Settings': 'सेटिंग्स',
      'Private Gallery': 'निजी गैलरी',
      'Main navigation': 'मुख्य नेविगेशन',
      'current page': 'वर्तमान पृष्ठ',
      'Search': 'खोजें',
      'Notifications': 'सूचनाएँ',
      'Add artwork': 'कलाकृति जोड़ें',
      'Upload': 'अपलोड',

      // Settings groups
      'Appearance': 'दिखावट',
      'Dark mode': 'डार्क मोड',
      'Language': 'भाषा',
      'Choose the language used across the app':
          'पूरे ऐप में इस्तेमाल होने वाली भाषा चुनें',
      'English': 'English',
      'Hindi': 'हिन्दी',
      'Preferences': 'प्राथमिकताएँ',
      'Preferred currency': 'पसंदीदा मुद्रा',
      'Library location': 'लाइब्रेरी स्थान',
      'Notifications & backup': 'सूचनाएँ और बैकअप',
      'Uploads, backups, duplicates': 'अपलोड, बैकअप, डुप्लीकेट',
      'Auto cloud backup': 'ऑटो क्लाउड बैकअप',
      'Backup after each change': 'हर बदलाव के बाद बैकअप',
      'Back up now': 'अभी बैकअप लें',
      'Local file + cloud (if connected)': 'लोकल फ़ाइल + क्लाउड (यदि कनेक्टेड)',
      'Security': 'सुरक्षा',
      'Account': 'खाता',
      'Profile': 'प्रोफ़ाइल',
      'User & role management': 'यूज़र और रोल प्रबंधन',
      'Activity log': 'एक्टिविटी लॉग',
      'View all user actions across the vault':
          'वॉल्ट में सभी यूज़र गतिविधियाँ देखें',
      'ArtVault Pro': 'आर्टवॉल्ट प्रो',
      'Backup & restore': 'बैकअप और रिस्टोर',
      'Restore from cloud': 'क्लाउड से रिस्टोर',
      'Re-download your whole vault from the cloud':
          'क्लाउड से पूरा वॉल्ट दोबारा डाउनलोड करें',
      'Storage & data': 'स्टोरेज और डेटा',
      'Repair images': 'इमेज रिपेयर करें',
      'Recently deleted': 'हाल ही में हटाए गए',
      'About ArtVault': 'आर्टवॉल्ट के बारे में',
      'Sign out': 'साइन आउट',
      'Free': 'फ़्री',
      'Guest': 'अतिथि',
      'Local session': 'लोकल सत्र',
      'Curator': 'क्यूरेटर',
      'Admin': 'एडमिन',
      'Viewer': 'व्यूअर',
      'Password, sign-in & session security':
          'पासवर्ड, साइन-इन और सत्र सुरक्षा',
      'App lock, passcode, face & fingerprint':
          'ऐप लॉक, पासकोड, फेस और फिंगरप्रिंट',
      'Auto': 'ऑटो',
      'System': 'सिस्टम',
      'Light': 'लाइट',
      'Dark': 'डार्क',
      'Cancel': 'रद्द करें',
      'Save': 'सेव करें',
      'Nothing in trash': 'ट्रैश में कुछ नहीं',
      'All files present': 'सभी फ़ाइलें मौजूद हैं',

      // Account / plan row copy
      'Active — unlimited capacity & premium gallery features':
          'सक्रिय — असीमित क्षमता और प्रीमियम गैलरी सुविधाएँ',
      'Free plan — unlock unlimited capacity, analytics & watermarking':
          'फ्री प्लान — असीमित क्षमता, एनालिटिक्स और वॉटरमार्क अनलॉक करें',

      // Security screen
      'App lock': 'ऐप लॉक',
      'Lock the app on launch': 'ऐप खुलने पर लॉक करें',
      'Show a lock screen before ArtVault opens':
          'आर्टवॉल्ट खुलने से पहले लॉक स्क्रीन दिखाएँ',
      'Unlock with Face lock': 'फेस लॉक से अनलॉक करें',
      'Unlock with Fingerprint': 'फिंगरप्रिंट से अनलॉक करें',
      'Passcode lock': 'पासकोड लॉक',
      'Web security': 'वेब सुरक्षा',
      'Change password': 'पासवर्ड बदलें',
      'Send reset email': 'रीसेट ईमेल भेजें',
      'Set a new password right here, no email needed':
          'यहीं नया पासवर्ड सेट करें, ईमेल की ज़रूरत नहीं',
      'Update your ArtVault sign-in password':
          'अपना आर्टवॉल्ट साइन-इन पासवर्ड अपडेट करें',
      'Get a reset link by email if you forgot it':
          'भूल गए हों तो ईमेल से रीसेट लिंक पाएँ',

      // Security screen
      'Scan your face with the camera to unlock':
          'अनलॉक करने के लिए कैमरे से अपना चेहरा स्कैन करें',
      'No camera available for face unlock':
          'फेस अनलॉक के लिए कोई कैमरा उपलब्ध नहीं',
      'Use the fingerprint sensor to unlock':
          'अनलॉक करने के लिए फिंगरप्रिंट सेंसर का उपयोग करें',
      'Not set up — add a fingerprint in your device settings':
          'सेट नहीं है — डिवाइस सेटिंग्स में फिंगरप्रिंट जोड़ें',
      'On — tap to test it. New prints are added in your phone settings':
          'चालू — परीक्षण के लिए टैप करें। नए प्रिंट फ़ोन सेटिंग्स में जोड़े जाते हैं',
      'On — tap to re-scan or remove your face':
          'चालू — फिर से स्कैन या चेहरा हटाने के लिए टैप करें',
      'ArtVault for the web protects your vault with your '
              'ArtVault sign-in (email + password) and Firebase '
              'Authentication. There is no local app to lock: close '
              'the tab or sign out to end the session, and use the '
              'account options below to change your password or send '
              'a reset email.':
          'आर्टवॉल्ट वेब पर आपके वॉल्ट को आपके आर्टवॉल्ट साइन-इन '
          '(ईमेल + पासवर्ड) और फायरबेस ऑथेंटिकेशन से सुरक्षित रखता '
          'है। लॉक करने के लिए कोई लोकल ऐप नहीं है: सेशन खत्म करने '
          'के लिए टैब बंद करें या साइन आउट करें, और नीचे दिए गए '
          'खाता विकल्पों से पासवर्ड बदलें या रीसेट ईमेल भेजें।',
      'Reset password': 'पासवर्ड रीसेट करें',
      'Current password': 'वर्तमान पासवर्ड',
      'New password': 'नया पासवर्ड',
      'Confirm new password': 'नया पासवर्ड दोबारा दर्ज करें',
      'Update password': 'पासवर्ड अपडेट करें',
      'Email': 'ईमेल',
      'Send reset link': 'रीसेट लिंक भेजें',

      // Common states / actions
      'painting': 'पेंटिंग',
      'paintings': 'पेंटिंग्स',
    },
  };
}
