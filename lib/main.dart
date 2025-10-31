import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  // Configure transparent status bar
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent, // Transparent status bar
      statusBarIconBrightness:
          Brightness.dark, // Dark icons on light background
      statusBarBrightness: Brightness.light, // For iOS
      systemNavigationBarColor:
          Colors.transparent, // Transparent navigation bar
      systemNavigationBarIconBrightness: Brightness.dark,
    ),
  );

  runApp(const OperatorUnionApp());
}

class OperatorUnionApp extends StatelessWidget {
  const OperatorUnionApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Operator Union',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        useMaterial3: true,
        // Ensure AppBar uses transparent status bar
        appBarTheme: const AppBarTheme(
          systemOverlayStyle: SystemUiOverlayStyle(
            statusBarColor: Colors.transparent,
            statusBarIconBrightness: Brightness.dark,
            statusBarBrightness: Brightness.light,
          ),
        ),
      ),
      home: const SplashScreen(),
      debugShowCheckedModeBanner: false,
    );
  }
}

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();

    // Initialize fade animation
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );
    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _fadeController, curve: Curves.easeIn));

    // Start fade in animation
    _fadeController.forward();

    // Navigate to WebView after exactly 4 seconds
    Future.delayed(const Duration(seconds: 4), () {
      if (mounted) {
        _navigateToWebView();
      }
    });
  }

  void _navigateToWebView() {
    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) =>
            const WebViewScreen(),
        transitionDuration: const Duration(milliseconds: 500),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(opacity: animation, child: child);
        },
      ),
    );
  }

  @override
  void dispose() {
    _fadeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      extendBodyBehindAppBar: true, // Allow body to extend behind status bar
      body: SafeArea(
        child: FadeTransition(
          opacity: _fadeAnimation,
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Logo image - using a fallback icon if image doesn't exist
                Container(
                  width: 200,
                  height: 200,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.grey.withValues(alpha: 0.3),
                        spreadRadius: 5,
                        blurRadius: 7,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(20),
                    child: Image.asset(
                      'assets/logo.png',
                      fit: BoxFit.contain,
                      errorBuilder: (context, error, stackTrace) {
                        // Fallback widget if logo.png doesn't exist
                        return Container(
                          color: Colors.blue.shade50,
                          child: Icon(
                            Icons.business,
                            size: 100,
                            color: Colors.blue.shade600,
                          ),
                        );
                      },
                    ),
                  ),
                ),
                const SizedBox(height: 30),
                // App name or tagline
                Text(
                  'Operator Union',
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey.shade800,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  'Loading...',
                  style: TextStyle(fontSize: 16, color: Colors.grey.shade600),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class WebViewScreen extends StatefulWidget {
  const WebViewScreen({super.key});

  @override
  State<WebViewScreen> createState() => _WebViewScreenState();
}

class _WebViewScreenState extends State<WebViewScreen> {
  late final WebViewController _controller;
  bool _isLoading = true;
  bool _isLoggedOut = false; // Flag to prevent redirect after logout
  bool _hasAttemptedRestore = false; // Track if we've tried session restore

  @override
  void initState() {
    super.initState();
    _initializeWebView();
  }

  // Save session cookies when user successfully logs in
  Future<void> _saveSessionCookies() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      // Get cookies using JavaScript
      final cookieResult = await _controller.runJavaScriptReturningResult(
        'document.cookie',
      );
      final cookieString = cookieResult.toString().replaceAll('"', '');

      if (cookieString.isNotEmpty && cookieString != 'null') {
        await prefs.setString('session_cookies', cookieString);
        print('Session cookies saved: $cookieString');
      }
    } catch (e) {
      print('Failed to save session cookies: $e');
    }
  }

  // Restore session cookies on app start
  Future<void> _restoreSessionCookies() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cookieString = prefs.getString('session_cookies');

      if (cookieString != null && cookieString.isNotEmpty) {
        // Set cookies using JavaScript
        await _controller.runJavaScript('document.cookie = "$cookieString"');
        print('Session cookies restored: $cookieString');
      }
    } catch (e) {
      print('Failed to restore session cookies: $e');
    }
  }

  // Check if user has saved session
  Future<bool> _hasValidSession() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cookieString = prefs.getString('session_cookies');
      return cookieString != null && cookieString.isNotEmpty;
    } catch (e) {
      return false;
    }
  }

  // Clear saved session (when user logs out)
  Future<void> _clearSavedSession() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('session_cookies');
      print('Saved session cleared');
    } catch (e) {
      print('Failed to clear saved session: $e');
    }
  }

  void _initializeWebView() async {
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageStarted: (String url) {
            setState(() {
              _isLoading = true;
            });
          },
          onPageFinished: (String url) async {
            setState(() {
              _isLoading = false;
            });

            // If we're on the dashboard page, save the session cookies
            if (url.contains('dashboard') && !url.contains('login')) {
              await _saveSessionCookies();
            }

            // If logout detected, clear saved session and set logout flag
            if (url.contains('logout') || url.contains('login?logout')) {
              await _clearSavedSession();
              _isLoggedOut = true;
              print('Logout detected, session cleared');
            }

            // Reset logout flag when we reach dashboard (successful login)
            if (url.contains('dashboard') && !url.contains('login')) {
              _isLoggedOut = false;
            }

            // Only try to restore session ONCE on first login page visit
            // and only if we haven't attempted restore yet
            if (url.contains('login') &&
                !url.contains('logout') &&
                !url.contains('login?logout') &&
                !_isLoggedOut &&
                !_hasAttemptedRestore &&
                await _hasValidSession()) {
              _hasAttemptedRestore = true; // Prevent multiple attempts
              print('First login page visit - attempting session restore');
              await _restoreSessionCookies();
              await Future.delayed(const Duration(milliseconds: 500));
              await _controller.loadRequest(
                Uri.parse('https://testdemo.co.in/dashboard'),
              );
            }
          },
          onNavigationRequest: (NavigationRequest request) {
            // Allow all navigation within the same domain
            if (request.url.contains('testdemo.co.in')) {
              return NavigationDecision.navigate;
            }
            // Block external links
            return NavigationDecision.prevent;
          },
          onWebResourceError: (WebResourceError error) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Error loading page: ${error.description}'),
                backgroundColor: Colors.red,
              ),
            );
          },
        ),
      );

    // Smart loading: check for saved session first
    await _loadInitialPage();
  }

  Future<void> _loadInitialPage() async {
    if (!_isLoggedOut && await _hasValidSession()) {
      // User has a saved session and hasn't just logged out
      print('Loading dashboard with saved session');
      await _restoreSessionCookies();
      await Future.delayed(
        const Duration(milliseconds: 300),
      ); // Let cookies set
      await _controller.loadRequest(
        Uri.parse('https://testdemo.co.in/dashboard'),
      );
    } else {
      // No saved session or just logged out, go to login
      print('Loading login page');
      await _controller.loadRequest(Uri.parse('https://testdemo.co.in/login'));
    }
  }

  Future<bool> _onWillPop() async {
    // Check if WebView can go back
    if (await _controller.canGoBack()) {
      await _controller.goBack();
      return false; // Don't exit the app
    } else {
      // Show exit confirmation dialog
      return await _showExitDialog();
    }
  }

  Future<bool> _showExitDialog() async {
    return await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Exit App'),
            content: const Text('Are you sure you want to exit?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () {
                  Navigator.of(context).pop(true);
                  SystemNavigator.pop();
                },
                child: const Text('Exit'),
              ),
            ],
          ),
        ) ??
        false;
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      onPopInvokedWithResult: (didPop, result) async {
        if (!didPop) {
          await _onWillPop();
        }
      },
      child: Scaffold(
        extendBodyBehindAppBar: true, // Allow body to extend behind status bar
        body: Stack(
          children: [
            SafeArea(child: WebViewWidget(controller: _controller)),
            if (_isLoading)
              Container(
                color: Colors.white,
                child: const Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      CircularProgressIndicator(),
                      SizedBox(height: 16),
                      Text(
                        'Loading...',
                        style: TextStyle(fontSize: 16, color: Colors.grey),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
