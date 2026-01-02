import 'dart:async';
import 'dart:convert';
import 'dart:ui';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:vibration/vibration.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_contacts/flutter_contacts.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:share_plus/share_plus.dart';
import 'package:intl/intl.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'dart:io';
import 'package:dio/dio.dart';
import 'package:open_filex/open_filex.dart';

void main() {
  runApp(const MyApp());
}

// --- CONSTANTS & THEME ---
class AppColors {
  static const Color background = Color(0xFF050505);
  static const Color neonCyan = Color(0xFF00FFCC);
  static const Color neonPurple = Color(0xFFBD00FF);
  static const Color neonBlue = Color(0xFF00C2FF);
  static const Color glassWhite = Color(0x1FFFFFFF);
  static const Color textMain = Colors.white;
  static const Color textDim = Colors.white54;
}

// --- UPDATE MANAGER ---
class UpdateManager {
  static final UpdateManager _instance = UpdateManager._internal();
  factory UpdateManager() => _instance;
  UpdateManager._internal();

  // 🔥 STEP 1: GitHub/Server URL for version.json
  // TODO: Update YOUR_GITHUB_USERNAME with your actual GitHub username after creating repository
  static const String versionUrl = 'https://raw.githubusercontent.com/rakeshsingh157/TouchOne/main/version.json';
  
  final ValueNotifier<double> downloadProgress = ValueNotifier(0.0);
  final ValueNotifier<bool> isDownloading = ValueNotifier(false);
  
  String? _latestVersion;
  String? _downloadUrl;
  String? _changelog;
  
  String? get latestVersion => _latestVersion;
  String? get downloadUrl => _downloadUrl;
  String? get changelog => _changelog;

  // 🔥 STEP 2: Check for updates with improved error handling
  Future<Map<String, dynamic>?> checkForUpdates() async {
    try {
      // Get current app version
      final packageInfo = await PackageInfo.fromPlatform();
      final currentVersion = packageInfo.version;
      
      print('📱 Current version: $currentVersion');
      print('🔍 Checking for updates at: $versionUrl');
      
      // Fetch version.json from server/GitHub
      final response = await http.get(Uri.parse(versionUrl)).timeout(
        const Duration(seconds: 15),
        onTimeout: () {
          throw TimeoutException('Update check timed out');
        },
      );
      
      print('📡 Response status: ${response.statusCode}');
      
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        _latestVersion = data['version'];
        _downloadUrl = data['download_url'];
        _changelog = data['changelog'] ?? 'Bug fixes and improvements';
        
        print('✅ Latest version: $_latestVersion');
        
        // Compare versions
        if (_isNewerVersion(currentVersion, _latestVersion!)) {
          print('🆕 Update available: $currentVersion → $_latestVersion');
          return {
            'hasUpdate': true,
            'currentVersion': currentVersion,
            'latestVersion': _latestVersion,
            'downloadUrl': _downloadUrl,
            'changelog': _changelog,
          };
        } else {
          print('✓ App is up to date');
        }
      } else if (response.statusCode == 404) {
        print('⚠️ version.json not found (404)');
        return {'hasUpdate': false, 'error': 'Version file not found'};
      } else {
        print('⚠️ Server error: ${response.statusCode}');
        return {'hasUpdate': false, 'error': 'Server error: ${response.statusCode}'};
      }
      return {'hasUpdate': false};
    } on TimeoutException catch (e) {
      print('⏱️ Update check timeout: $e');
      return {'hasUpdate': false, 'error': 'Connection timeout'};
    } on SocketException catch (e) {
      print('🌐 No internet connection: $e');
      return {'hasUpdate': false, 'error': 'No internet connection'};
    } on FormatException catch (e) {
      print('📄 Invalid JSON format: $e');
      return {'hasUpdate': false, 'error': 'Invalid response format'};
    } catch (e) {
      print('❌ Update check failed: $e');
      return {'hasUpdate': false, 'error': e.toString()};
    }
  }

  // Version comparison logic
  bool _isNewerVersion(String current, String latest) {
    try {
      final currentParts = current.split('.').map(int.parse).toList();
      final latestParts = latest.split('.').map(int.parse).toList();
      
      // Ensure we have at least 3 parts
      while (currentParts.length < 3) currentParts.add(0);
      while (latestParts.length < 3) latestParts.add(0);
      
      for (int i = 0; i < 3; i++) {
        if (latestParts[i] > currentParts[i]) return true;
        if (latestParts[i] < currentParts[i]) return false;
      }
      return false;
    } catch (e) {
      print('Version comparison error: $e');
      return false;
    }
  }

  // 🔥 STEP 3: Download APK with progress and comprehensive error handling
  Future<String?> downloadApk() async {
    if (_downloadUrl == null) {
      print('❌ Download URL is null');
      return null;
    }
    
    try {
      isDownloading.value = true;
      downloadProgress.value = 0.0;
      
      // Use Downloads directory for better compatibility
      Directory? dir;
      if (Platform.isAndroid) {
        dir = Directory('/storage/emulated/0/Download');
        if (!await dir.exists()) {
          print('⚠️ Download folder not found, using external storage');
          dir = await getExternalStorageDirectory();
        }
      } else {
        dir = await getExternalStorageDirectory();
      }
      
      if (dir == null) {
        print('❌ Could not access storage directory');
        isDownloading.value = false;
        return null;
      }
      
      final filePath = '${dir.path}/TouchOne-update.apk';
      print('📥 Downloading to: $filePath');
      print('🔗 Download URL: $_downloadUrl');
      
      // Delete old APK if exists
      final file = File(filePath);
      if (await file.exists()) {
        await file.delete();
        print('🗑️ Deleted old APK');
      }
      
      // Download with progress tracking using Dio
      final dio = Dio(
        BaseOptions(
          connectTimeout: Duration(seconds: 30),
          receiveTimeout: Duration(seconds: 300), // 5 minutes for large files
        ),
      );
      
      await dio.download(
        _downloadUrl!,
        filePath,
        onReceiveProgress: (received, total) {
          if (total != -1) {
            downloadProgress.value = received / total;
            if (received % (1024 * 1024) == 0) { // Log every 1MB
              print('📊 Downloaded: ${(received / 1024 / 1024).toStringAsFixed(2)} MB / ${(total / 1024 / 1024).toStringAsFixed(2)} MB');
            }
          }
        },
        options: Options(
          responseType: ResponseType.bytes,
          followRedirects: true,
          validateStatus: (status) => status! < 500,
        ),
      );
      
      // Verify file exists and has content
      if (await file.exists()) {
        final fileSize = await file.length();
        print('✅ Download complete: ${(fileSize / 1024 / 1024).toStringAsFixed(2)} MB');
        
        if (fileSize < 1000000) { // Less than 1MB is suspicious
          print('❌ Downloaded file is too small (${fileSize} bytes), might be corrupted');
          await file.delete();
          isDownloading.value = false;
          return null;
        }
        
        isDownloading.value = false;
        return filePath;
      } else {
        print('❌ Downloaded file not found after download');
        isDownloading.value = false;
        return null;
      }
    } on DioException catch (e) {
      print('❌ Dio error: ${e.type} - ${e.message}');
      if (e.type == DioExceptionType.connectionTimeout) {
        print('⏱️ Connection timeout');
      } else if (e.type == DioExceptionType.receiveTimeout) {
        print('⏱️ Receive timeout');
      } else if (e.type == DioExceptionType.badResponse) {
        print('📡 Bad response: ${e.response?.statusCode}');
      } else if (e.type == DioExceptionType.connectionError) {
        print('🌐 Connection error - check internet');
      }
      isDownloading.value = false;
      return null;
    } on SocketException catch (e) {
      print('🌐 Network error: $e');
      isDownloading.value = false;
      return null;
    } on FileSystemException catch (e) {
      print('💾 File system error: $e');
      isDownloading.value = false;
      return null;
    } catch (e) {
      print('❌ Download failed: $e');
      isDownloading.value = false;
      return null;
    }
  }

  // 🔥 STEP 4: Install APK (opens Android installer)
  Future<bool> installApk(String filePath) async {
    try {
      final file = File(filePath);
      if (await file.exists()) {
        final fileSize = await file.length();
        print('📦 Opening APK installer: $filePath (${fileSize} bytes)');
        
        // Give a small delay to ensure file is fully written
        await Future.delayed(Duration(milliseconds: 500));
        
        // Open APK file using open_filex
        final result = await OpenFilex.open(
          filePath,
          type: 'application/vnd.android.package-archive',
        );
        print('📱 Install result: ${result.message}');
        
        // Don't delete immediately - let user complete installation
        // Delete after a delay
        Future.delayed(Duration(seconds: 3), () async {
          try {
            if (await file.exists()) {
              await file.delete();
              print('🗑️ APK file deleted');
            }
          } catch (e) {
            print('⚠️ Could not delete APK: $e');
          }
        });
        
        return result.type == ResultType.done;
      }
      print('❌ APK file not found: $filePath');
      return false;
    } catch (e) {
      print('❌ Install failed: $e');
      return false;
    }
  }
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'TouchOne',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: AppColors.background,
        textTheme: GoogleFonts.outfitTextTheme(ThemeData.dark().textTheme),
        colorScheme: const ColorScheme.dark(
          primary: AppColors.neonCyan,
          secondary: AppColors.neonPurple,
          surface: AppColors.background,
        ),
        useMaterial3: true,
      ),
      home: const SplashScreen(),
    );
  }
}

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    Future.delayed(const Duration(seconds: 3), () {
      if (mounted) {
        Navigator.pushReplacement(
            context, MaterialPageRoute(builder: (c) => const NfcHomePage()));
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          const MeshGradientBackground(),
          Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Stack(
                   alignment: Alignment.center,
                   children: [
                     Icon(Icons.fingerprint, size: 100, color: AppColors.neonCyan)
                     .animate()
                     .fadeIn(duration: 800.ms)
                     .scale(begin: Offset(0.5,0.5), end: Offset(1,1), curve: Curves.elasticOut, duration: 1200.ms)
                     .then()
                     .shimmer(duration: 1500.ms, color: Colors.white),
                     
                     Container(
                       width: 120, height: 120,
                       decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: AppColors.neonPurple.withOpacity(0.5), width: 2))
                     ).animate(onPlay: (c)=>c.repeat()).scale(begin: Offset(0.8,0.8), end: Offset(1.3,1.3), duration: 2.seconds).fadeOut(delay: 1.seconds),
                   ]
                ),
                const SizedBox(height: 30),
                Text("TouchOne", style: GoogleFonts.orbitron(fontSize: 40, fontWeight: FontWeight.bold, color: Colors.white, letterSpacing: 5))
                .animate().fadeIn(delay: 500.ms).slideY(begin: 0.5, end: 0),
                
                const SizedBox(height: 10),
                Text("Future of Sharing", style: GoogleFonts.outfit(color: AppColors.textDim, letterSpacing: 3))
                .animate().fadeIn(delay: 1000.ms),
              ],
            ),
          ),
          Positioned(
             bottom: 50, left: 0, right: 0, 
             child: Center(
               child: CircularProgressIndicator(color: AppColors.neonCyan, strokeWidth: 2)
               .animate().fadeIn(delay: 1500.ms)
             )
          )
        ],
      ),
    );
  }
}

// --- NFC MANAGER ---
enum NfcState { idle, waiting, success, error }

class NfcManager {
  static final NfcManager _instance = NfcManager._internal();
  factory NfcManager() => _instance;
  NfcManager._internal();

  static const platform = MethodChannel('com.example.nfc_sender/nfc');
  
  final _statusController = StreamController<NfcState>.broadcast();
  Stream<NfcState> get statusStream => _statusController.stream;
  
  final ValueNotifier<String> availabilityNotifier = ValueNotifier("Checking...");
  String get availability => availabilityNotifier.value;
  
  String _lastError = "";
  String get lastError => _lastError;
  Timer? _pollTimer;

  void init() {
    platform.setMethodCallHandler(_handleMethod);
    startMonitoring();
  }
  
  void startMonitoring() {
    _pollTimer?.cancel();
    // Check immediately then every 1 second
    checkAvailability();
    _pollTimer = Timer.periodic(const Duration(seconds: 1), (_) => checkAvailability());
  }
  
  void stopMonitoring() {
    _pollTimer?.cancel();
  }
  
  Future<void> checkAvailability() async {
    try {
      final String result = await platform.invokeMethod('checkNfcAvailability');
      if (result != availabilityNotifier.value) {
         availabilityNotifier.value = result;
      }
    } on PlatformException catch (_) {
      if (availabilityNotifier.value != "NOT_SUPPORTED") {
         availabilityNotifier.value = "NOT_SUPPORTED";
      }
    }
  }
  
  Future<void> openSettings() async {
    try { await platform.invokeMethod('openNfcSettings'); } catch (_) {}
  }

  Future<void> startNfc(String data, {String? explicitMode}) async {
    if (availability != "AVAILABLE") {
        await checkAvailability(); // Re-check
        if (availability != "AVAILABLE") {
           _lastError = availability == "DISABLED" ? "NFC is Disabled" : "NFC Not Supported";
           _statusController.add(NfcState.error);
           return;
        }
    }
    
    _statusController.add(NfcState.waiting);
    
    String mode = "TEXT";
    if (explicitMode != null) {
      mode = explicitMode;
    } else if (data.startsWith("http") || data.startsWith("upi://") || data.contains("://")) {
      mode = "URL";
    }

    try {
      await platform.invokeMethod('startNfc', {"mode": mode, "data": data});
      await markSent();
    } on PlatformException catch (e) {
      _lastError = e.message ?? "Unknown Error";
      _statusController.add(NfcState.error);
    }
  }

  Future<void> stopNfc() async {
    try { 
      await platform.invokeMethod('stopNfc'); 
    } catch (_) {}
    _statusController.add(NfcState.idle);
  }

  Future<dynamic> _handleMethod(MethodCall call) async {
    if (call.method == "onNfcStatus") {
      final String message = call.arguments;
      if (message.contains("Success")) {
        _statusController.add(NfcState.success);
      } else if (message.contains("Error")) {
        _lastError = message;
        _statusController.add(NfcState.error);
      }
    } else if (call.method == "nfcReceived") {
      // Handle received NFC data
      final Map<dynamic, dynamic> data = call.arguments;
      final String type = data["type"] ?? "UNKNOWN";
      final String receivedData = data["data"] ?? "";
      
      print("📩 NFC Received: $type -> $receivedData");
      
      // Save to history
      await ReceivedHistoryStorage.saveReceived(type, receivedData);
      
      _statusController.add(NfcState.success);
    }
  }
  
  Future<void> markSent() async {
    await ReceivedHistoryStorage.incrementSent();
  }
}

// --- RECEIVED HISTORY STORAGE ---
class ReceivedHistoryStorage {
  static const String _key = 'received_nfc_history';
  static const String _statsKey = 'nfc_statistics';

  static Future<List<Map<String, dynamic>>> getHistory() async {
    final prefs = await SharedPreferences.getInstance();
    final List<String> rawList = prefs.getStringList(_key) ?? [];
    
    return rawList.map((item) {
      final decoded = jsonDecode(item) as Map<String, dynamic>;
      return {
        "type": decoded["type"] ?? "UNKNOWN",
        "data": decoded["data"] ?? "",
        "timestamp": decoded["timestamp"] ?? DateTime.now().toIso8601String(),
      };
    }).toList();
  }

  static Future<void> saveReceived(String type, String data) async {
    final prefs = await SharedPreferences.getInstance();
    final rawList = prefs.getStringList(_key) ?? [];
    
    final newItem = jsonEncode({
      "type": type,
      "data": data,
      "timestamp": DateTime.now().toIso8601String(),
    });
    
    rawList.insert(0, newItem);
    if (rawList.length > 100) rawList.removeRange(100, rawList.length); // Keep last 100
    
    await prefs.setStringList(_key, rawList);
    await _updateStats('received');
  }

  static Future<void> clearHistory() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_key);
  }

  static Future<Map<String, int>> getStatistics() async {
    final prefs = await SharedPreferences.getInstance();
    final stats = prefs.getString(_statsKey);
    if (stats == null) {
      return {'sent': 0, 'received': 0, 'total': 0};
    }
    final decoded = jsonDecode(stats) as Map<String, dynamic>;
    return {
      'sent': decoded['sent'] ?? 0,
      'received': decoded['received'] ?? 0,
      'total': (decoded['sent'] ?? 0) + (decoded['received'] ?? 0),
    };
  }

  static Future<void> _updateStats(String type) async {
    final prefs = await SharedPreferences.getInstance();
    final stats = await getStatistics();
    
    if (type == 'sent') {
      stats['sent'] = (stats['sent'] ?? 0) + 1;
    } else {
      stats['received'] = (stats['received'] ?? 0) + 1;
    }
    stats['total'] = (stats['sent'] ?? 0) + (stats['received'] ?? 0);
    
    await prefs.setString(_statsKey, jsonEncode(stats));
  }

  static Future<void> incrementSent() async {
    await _updateStats('sent');
  }
}

// --- STORAGE HELPER ---
class StorageService {
  static const String _key = 'saved_nfc_items';

  static Future<List<Map<String, String>>> getItems() async {
    final prefs = await SharedPreferences.getInstance();
    final List<String> rawList = prefs.getStringList(_key) ?? [];
    
    return rawList.map((item) {
      try {
        final decoded = jsonDecode(item) as Map<String, dynamic>;
        return {
          "name": decoded["name"]?.toString() ?? "Untitled", 
          "data": decoded["data"]?.toString() ?? decoded["value"]?.toString() ?? ""
        };
      } catch (e) {
        // Fallback for legacy simple strings
        return {"name": item, "data": item};
      }
    }).toList();
  }

  static Future<void> saveItem(String name, String data) async {
    final prefs = await SharedPreferences.getInstance();
    final rawList = prefs.getStringList(_key) ?? [];
    
    final newItem = jsonEncode({"name": name, "data": data});
    rawList.insert(0, newItem);
    
    await prefs.setStringList(_key, rawList);
  }

  static Future<void> deleteItem(String dataContent) async {
    final prefs = await SharedPreferences.getInstance();
    final rawList = prefs.getStringList(_key) ?? [];
    
    rawList.removeWhere((item) {
       try {
         final decoded = jsonDecode(item);
         return decoded["data"] == dataContent || item == dataContent;
       } catch (_) {
         return item == dataContent;
       }
    });
    
    await prefs.setStringList(_key, rawList);
  }

  static Future<void> updateItem(String oldData, String newName, String newData) async {
    final prefs = await SharedPreferences.getInstance();
    final rawList = prefs.getStringList(_key) ?? [];
    
    final index = rawList.indexWhere((item) {
        try {
          final decoded = jsonDecode(item);
          return decoded["data"] == oldData;
        } catch (_) {
          return item == oldData;
        }
    });
    
    if (index != -1) {
      rawList[index] = jsonEncode({"name": newName, "data": newData});
      await prefs.setStringList(_key, rawList);
    }
  }
}

// --- MAIN PAGE ---
class NfcHomePage extends StatefulWidget {
  const NfcHomePage({super.key});

  @override
  State<NfcHomePage> createState() => _NfcHomePageState();
}

class _NfcHomePageState extends State<NfcHomePage> with WidgetsBindingObserver {
  final TextEditingController _controller = TextEditingController();
  final NfcManager _nfcManager = NfcManager();
  StreamSubscription? _subscription;
  
  NfcState _viewState = NfcState.idle;
  String _detectedType = "TEXT";

  @override
  void initState() {
    super.initState();
    // WidgetsBinding.instance.addObserver(this); // Polling handles updates now
    _nfcManager.init();
    
    // Check for updates on app start
    _checkForUpdates();
    
    _subscription = _nfcManager.statusStream.listen((state) {
      setState(() => _viewState = state);
      
      if (state == NfcState.success) {
         _triggerHaptic(feedBackType: FeedbackType.success);
         Future.delayed(const Duration(seconds: 3), () {
           if (mounted && _viewState == NfcState.success) {
             _nfcManager.stopNfc();
             setState(() => _viewState = NfcState.idle);
           }
         });
      } else if (state == NfcState.error) {
         _triggerHaptic(feedBackType: FeedbackType.error);
         if (_nfcManager.lastError.contains("Disabled")) {
            _showDisabledSnackBar();
         }
         Future.delayed(const Duration(seconds: 3), () {
            if (mounted && _viewState == NfcState.error) setState(() => _viewState = NfcState.idle);
         });
      } else if (state == NfcState.waiting) {
         _triggerHaptic(feedBackType: FeedbackType.medium);
      }
    });

    _controller.addListener(_detectType);
  }

  @override
  void dispose() {
    // WidgetsBinding.instance.removeObserver(this);
    _subscription?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _detectType() {
    final text = _controller.text;
    String newType = "TEXT";
    if (text.startsWith("http") || text.startsWith("upi://") || text.contains("://")) {
      newType = "LINK";
    }
    if (newType != _detectedType) {
      setState(() => _detectedType = newType);
      _triggerHaptic(feedBackType: FeedbackType.light);
    }
  }

  Future<void> _triggerHaptic({FeedbackType feedBackType = FeedbackType.medium}) async {
    if (await Vibration.hasVibrator() ?? false) {
       Vibration.vibrate(
         duration: feedBackType == FeedbackType.success ? 100 
                 : feedBackType == FeedbackType.error ? 500 : 20
       );
    }
  }
  
  void _showDisabledSnackBar() {
     ScaffoldMessenger.of(context).showSnackBar(
       SnackBar(
         content: const Text("NFC is disabled. Tap to open settings."),
         action: SnackBarAction(label: "Settings", onPressed: _nfcManager.openSettings, textColor: AppColors.neonCyan),
       )
     );
  }
  
  // 🔥 Check for app updates (AUTOMATIC)
  Future<void> _checkForUpdates() async {
    await Future.delayed(const Duration(seconds: 2)); // Wait for app to settle
    
    try {
      final updateManager = UpdateManager();
      final updateInfo = await updateManager.checkForUpdates();
      
      // Debug: Show current version
      final packageInfo = await PackageInfo.fromPlatform();
      print('🔍 Current version: ${packageInfo.version}');
      print('🔍 Latest version: ${updateInfo?['latestVersion'] ?? 'unknown'}');
      print('🔍 Has update: ${updateInfo?['hasUpdate'] ?? false}');
      
      if (updateInfo != null && updateInfo['hasUpdate'] == true && mounted) {
        // 🚀 AUTO UPDATE: Download and install automatically
        print('🚀 Auto-update started...');
        
        // Show downloading notification
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(AppColors.neonCyan),
                    ),
                  ),
                  SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Downloading update v${updateInfo['latestVersion']}...',
                      style: GoogleFonts.outfit(fontSize: 14, color: Colors.white),
                    ),
                  ),
                ],
              ),
              backgroundColor: AppColors.neonPurple.withOpacity(0.9),
              duration: Duration(seconds: 60), // Long duration for download
            ),
          );
        }
        
        // Download APK
        final apkPath = await updateManager.downloadApk();
        
        if (apkPath != null && mounted) {
          print('✅ Download complete, installing...');
          
          // Hide downloading snackbar
          ScaffoldMessenger.of(context).hideCurrentSnackBar();
          
          // Show installing notification
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  Icon(Icons.system_update, color: AppColors.neonCyan, size: 20),
                  SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Installing update...',
                      style: GoogleFonts.outfit(fontSize: 14, color: Colors.white),
                    ),
                  ),
                ],
              ),
              backgroundColor: AppColors.neonCyan.withOpacity(0.9),
              duration: Duration(seconds: 5),
            ),
          );
          
          // Install APK automatically
          await Future.delayed(Duration(milliseconds: 500));
          await updateManager.installApk(apkPath);
          
          print('📱 Update installer opened');
        } else if (mounted) {
          // Download failed
          print('❌ Download failed');
          ScaffoldMessenger.of(context).hideCurrentSnackBar();
          showBeautifulError(
            context,
            title: "Update Failed",
            message: "Unable to download the latest version. Please check your internet connection and try again later.",
            icon: Icons.cloud_download,
            iconColor: Colors.orange,
          );
        }
      }
    } catch (e) {
      print('❌ Update check error: $e');
      // Silent fail - don't disturb user if update check fails
    }
  }
  
  // 🔥 Update dialog removed - updates are now automatic

  void _startNfc() {
    if (_controller.text.isEmpty) {
        setState(() => _viewState = NfcState.error);
        _triggerHaptic(feedBackType: FeedbackType.error);
        showBeautifulError(
          context,
          title: "Empty Input",
          message: "Please enter a URL or text message before initiating NFC transfer.",
          icon: Icons.text_fields,
          iconColor: Colors.orange,
        );
        Future.delayed(const Duration(seconds: 2), () { 
          if(mounted) setState(() => _viewState = NfcState.idle); 
        });
        return;
    }
    
    try {
      _nfcManager.startNfc(_controller.text);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.neonCyan),
              ),
              SizedBox(width: 12),
              Text("Hold device near NFC tag...", style: GoogleFonts.outfit()),
            ],
          ),
          backgroundColor: AppColors.neonCyan.withOpacity(0.2),
          duration: Duration(seconds: 2),
        )
      );
    } catch (e) {
      print('❌ NFC start error: $e');
      setState(() => _viewState = NfcState.error);
      _triggerHaptic(feedBackType: FeedbackType.error);
      showBeautifulError(
        context,
        title: "NFC Error",
        message: "Failed to start NFC transfer. Please ensure NFC is enabled and try again.\n\nError: ${e.toString()}",
        icon: Icons.nfc,
        actionText: "Open Settings",
        onAction: () => _nfcManager.openSettings(),
      );
      Future.delayed(const Duration(seconds: 2), () { 
        if(mounted) setState(() => _viewState = NfcState.idle); 
      });
    }
  }

  // Copy to clipboard with feedback
  void _copyToClipboard(String text) async {
    try {
      await Clipboard.setData(ClipboardData(text: text));
      _triggerHaptic(feedBackType: FeedbackType.success);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                Icon(Icons.check_circle, color: AppColors.neonCyan),
                SizedBox(width: 8),
                Text("Copied to clipboard!", style: GoogleFonts.outfit()),
              ],
            ),
            backgroundColor: AppColors.neonCyan.withOpacity(0.2),
            duration: Duration(seconds: 2),
          )
        );
      }
    } catch (e) {
      print('❌ Copy failed: $e');
      if (mounted) {
        showBeautifulError(
          context,
          title: "Copy Failed",
          message: "Unable to copy text to clipboard. Please try again.\n\nError: ${e.toString()}",
          icon: Icons.content_copy_outlined,
        );
      }
    }
  }

  void _saveItem() async {
    if (_controller.text.isEmpty) {
      showBeautifulWarning(
        context,
        title: "Nothing to Save",
        message: "Please enter some text or URL before saving.",
      );
      return;
    }
    
    try {
      // Show Name Dialog
      final TextEditingController nameController = TextEditingController(text: "My Tag");
      await showDialog(
        context: context,
        builder: (context) => Dialog(
          backgroundColor: Colors.transparent,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(24),
            child: BackdropFilter(
               filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
               child: Container(
                 padding: const EdgeInsets.all(24),
                 decoration: BoxDecoration(color: AppColors.background.withOpacity(0.9), border: Border.all(color: Colors.white24), borderRadius: BorderRadius.circular(24)),
                 child: Column(
                   mainAxisSize: MainAxisSize.min,
                   children: [
                     Text("NAME YOUR TAG", style: GoogleFonts.orbitron(fontSize: 18, color: AppColors.neonCyan)),
                     SizedBox(height: 16),
                     TextField(controller: nameController, style: GoogleFonts.outfit(color: Colors.white), decoration: InputDecoration(filled: true, fillColor: Colors.white10, hintText: "Enter Name", hintStyle: TextStyle(color: Colors.white30), border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)))),
                     SizedBox(height: 24),
                     ElevatedButton(
                       onPressed: () { Navigator.pop(context); },
                       style: ElevatedButton.styleFrom(backgroundColor: AppColors.neonCyan, foregroundColor: Colors.black),
                       child: Text("SAVE", style: GoogleFonts.orbitron(fontWeight: FontWeight.bold))
                     )
                   ]
                 )
               )
            )
          )
        )
      );
      
      if (nameController.text.isNotEmpty) {
        try {
          await StorageService.saveItem(nameController.text, _controller.text);
          _triggerHaptic(feedBackType: FeedbackType.success);
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Row(
                  children: [
                    Icon(Icons.bookmark_added, color: AppColors.neonPurple),
                    SizedBox(width: 8),
                    Expanded(child: Text("Saved as ${nameController.text}", style: GoogleFonts.outfit())),
                  ],
                ),
                backgroundColor: AppColors.neonPurple.withOpacity(0.8),
                action: SnackBarAction(
                  label: 'VIEW',
                  textColor: Colors.white,
                  onPressed: () => _openSavedPage(),
                ),
              )
            );
          }
        } catch (e) {
          print('❌ Save failed: $e');
          if (mounted) {
            showBeautifulError(
              context,
              title: "Save Failed",
              message: "Unable to save item. Please check storage permissions and try again.\n\nError: ${e.toString()}",
              icon: Icons.bookmark_border,
            );
          }
        }
      }
    } catch (e) {
      print('❌ Save dialog error: $e');
      if (mounted) {
        showBeautifulError(
          context,
          title: "Dialog Error",
          message: "Unable to open save dialog. Please try again.\n\nError: ${e.toString()}",
          icon: Icons.error_outline,
        );
      }
    }
  }

  Future<void> _pickContact() async {
    try {
      final status = await Permission.contacts.request();
      
      if (status.isDenied) {
        if (mounted) {
          showBeautifulWarning(
            context,
            title: "Permission Required",
            message: "TouchOne needs access to your contacts to import contact information for NFC transfer.",
            actionText: "Open Settings",
            onAction: () => openAppSettings(),
          );
        }
        return;
      }
      
      if (status.isPermanentlyDenied) {
        if (mounted) {
          showBeautifulError(
            context,
            title: "Permission Denied",
            message: "Contacts permission is permanently denied. Please enable it manually in app settings to import contacts.",
            actionText: "Open Settings",
            onAction: () => openAppSettings(),
          );
        }
        return;
      }
      
      if (status.isGranted) {
        final contact = await FlutterContacts.openExternalPick();
        if (contact != null) {
          final fullContact = await FlutterContacts.getContact(contact.id);
          if (fullContact != null) {
            // Basic vCard Manual Generation to ensure compatibility
            final name = fullContact.displayName;
            final phone = fullContact.phones.isNotEmpty ? fullContact.phones.first.number : "";
            final email = fullContact.emails.isNotEmpty ? fullContact.emails.first.address : "";
            
            final vCard = "BEGIN:VCARD\n"
                          "VERSION:3.0\n"
                          "FN:$name\n"
                          "TEL:$phone\n"
                          "EMAIL:$email\n"
                          "END:VCARD";
                          
            _nfcManager.startNfc(vCard, explicitMode: "CONTACT");
            
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text("Contact loaded: $name", style: GoogleFonts.outfit()),
                  backgroundColor: AppColors.neonCyan.withOpacity(0.8),
                )
              );
            }
          } else {
            throw Exception("Could not load contact details");
          }
        }
      }
    } catch (e) {
      print('❌ Contact picker error: $e');
      if (mounted) {
        showBeautifulError(
          context,
          title: "Contact Loading Failed",
          message: "Unable to load contact information. Please ensure the contact has complete details and try again.\\n\\nError: ${e.toString()}",
          icon: Icons.contact_phone,
        );
      }
    }
  }

  void _openSavedPage() async {
    await Navigator.push(context, MaterialPageRoute(builder: (context) => const SavedItemsPage()));
  }
  
  void _openAboutPage() {
    Navigator.push(context, MaterialPageRoute(builder: (c) => const AboutPage()));
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<String>(
      valueListenable: _nfcManager.availabilityNotifier,
      builder: (context, availability, _) {
        if (availability == "NOT_SUPPORTED") return _buildNotSupportedScreen();

        final bool isWaiting = _viewState == NfcState.waiting;
        final bool isSuccess = _viewState == NfcState.success;
        final bool isError = _viewState == NfcState.error;

        return Scaffold(
          resizeToAvoidBottomInset: false,
          body: Stack(
            children: [
              const MeshGradientBackground(),
              if (isWaiting) const RadarOverlay(),
              if (isSuccess) const ParticleExplosion(),
              
              SafeArea(
                child: Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                       _buildHeader(),
                       const Spacer(),
                       
                       if (availability == "DISABLED") _buildDisabledWarning(),
                       
                       AnimatedSwitcher(
                        duration: const Duration(milliseconds: 500),
                        child: isWaiting ? _buildRadarStatus() 
                             : isSuccess ? _buildSuccessStatus() 
                             : isError ? _buildErrorStatus() 
                             : _buildInputSection(),
                       ),
                       const Spacer(flex: 2),
                    ],
                  ),
                ),
              ),
              
              if (!isWaiting && !isSuccess)
                 Positioned(bottom: 40, left: 24, right: 24, child: _buildSendButton(availability))
                 .animate().slideY(begin: 1, end: 0, duration: 600.ms, curve: Curves.easeOutBack),
                
               if (isWaiting)
                  Positioned(
                   bottom: 40,
                   left: 24,
                   right: 24,
                   child: Center(
                     child: TextButton(
                       onPressed: () { _nfcManager.stopNfc(); },
                       child: Text("CANCEL", style: GoogleFonts.orbitron(color: Colors.white54, letterSpacing: 2)),
                     ),
                   ),
                 ).animate().fadeIn(delay: 500.ms),
            ],
          ),
        );
      }
    );
  }
  
  // Reusable UI builders
  Widget _buildNotSupportedScreen() => Scaffold(body: Stack(children: [const MeshGradientBackground(), Center(child: Column(mainAxisSize: MainAxisSize.min, children: [Icon(Icons.no_cell, size: 80, color: Colors.white24), SizedBox(height: 20), Text("NFC NOT SUPPORTED", style: GoogleFonts.orbitron(fontSize: 20, color: Colors.redAccent))]))]));

  Widget _buildHeader() => Column(
    children: [
      SizedBox(height: 10),
      // Navigation buttons row - evenly distributed
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24.0),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            // Info button
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.05),
                borderRadius: BorderRadius.circular(12),
              ),
              child: IconButton(
                onPressed: _openAboutPage,
                icon: Icon(Icons.info_outline, color: Colors.white60, size: 24),
                tooltip: 'About',
                padding: EdgeInsets.zero,
              ),
            ),
            // Saved Items button
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: AppColors.neonCyan.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.neonCyan.withOpacity(0.3)),
              ),
              child: IconButton(
                onPressed: _openSavedPage,
                icon: Icon(Icons.bookmark_rounded, color: AppColors.neonCyan, size: 24),
                tooltip: 'Saved Items',
                padding: EdgeInsets.zero,
              ),
            ),
            // Donate button
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: AppColors.neonPurple.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.neonPurple.withOpacity(0.3)),
              ),
              child: IconButton(
                onPressed: () async {
                  final upiUrl = 'upi://pay?pa=rakeshsingh157@oksbi&pn=TouchOne%20NFC&cu=INR';
                  final uri = Uri.parse(upiUrl);
                  if (await canLaunchUrl(uri)) {
                    await launchUrl(uri);
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Unable to open UPI app', style: GoogleFonts.outfit()))
                    );
                  }
                },
                icon: Icon(Icons.volunteer_activism, color: AppColors.neonPurple, size: 24),
                tooltip: 'Donate',
                padding: EdgeInsets.zero,
              ),
            ),
            // History button
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.05),
                borderRadius: BorderRadius.circular(12),
              ),
              child: IconButton(
                onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (c) => const ReceivedHistoryPage())),
                icon: Icon(Icons.history, color: Colors.white60, size: 24),
                tooltip: 'History',
                padding: EdgeInsets.zero,
              ),
            ),
          ],
        ),
      ),
      SizedBox(height: 20),
      // App title
      Text("TouchOne", style: GoogleFonts.orbitron(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.white, letterSpacing: 4, shadows: [Shadow(color: AppColors.neonCyan, blurRadius: 20)])),
      SizedBox(height: 8),
      Text("NFC DATA BEAM", style: GoogleFonts.outfit(fontSize: 11, color: AppColors.textDim, letterSpacing: 6)),
      SizedBox(height: 16),
      _buildQuickStats(),
    ]
  );
  
  Widget _buildQuickStats() {
    return FutureBuilder<Map<String, int>>(
      future: ReceivedHistoryStorage.getStatistics(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return SizedBox.shrink();
        final stats = snapshot.data!;
        return Container(
          padding: EdgeInsets.symmetric(horizontal: 20, vertical: 8),
          decoration: BoxDecoration(
            color: AppColors.glassWhite,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.white12),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _statItem(Icons.arrow_upward, stats['sent']!.toString(), AppColors.neonPurple),
              SizedBox(width: 16),
              _statItem(Icons.arrow_downward, stats['received']!.toString(), AppColors.neonCyan),
              SizedBox(width: 16),
              _statItem(Icons.sync_alt, stats['total']!.toString(), AppColors.neonBlue),
            ],
          ),
        ).animate().fadeIn(delay: 300.ms);
      },
    );
  }
  
  Widget _statItem(IconData icon, String value, Color color) {
    return Row(
      children: [
        Icon(icon, size: 14, color: color),
        SizedBox(width: 4),
        Text(value, style: GoogleFonts.orbitron(fontSize: 12, color: Colors.white, fontWeight: FontWeight.bold)),
      ],
    );
  }
  
  Widget _buildDisabledWarning() {
     return Container(
       margin: const EdgeInsets.only(bottom: 20),
       padding: const EdgeInsets.all(12),
       decoration: BoxDecoration(color: Colors.red.withOpacity(0.1), border: Border.all(color: Colors.redAccent), borderRadius: BorderRadius.circular(12)),
       child: Row(children: [Icon(Icons.warning_amber_rounded, color: Colors.redAccent), SizedBox(width: 12), Expanded(child: Text("NFC is disabled.", style: GoogleFonts.outfit(color: Colors.white))), TextButton(onPressed: _nfcManager.openSettings, child: Text("ENABLE", style: GoogleFonts.orbitron(color: AppColors.neonCyan)))]),
     );
  }

  Widget _buildInputSection() {
     // ... [Same implementation]
     return Column(
      key: const ValueKey("INPUT_MODE"),
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          decoration: BoxDecoration(color: _detectedType == "LINK" ? AppColors.neonPurple.withOpacity(0.2) : AppColors.neonBlue.withOpacity(0.2), borderRadius: BorderRadius.circular(20), border: Border.all(color: _detectedType == "LINK" ? AppColors.neonPurple : AppColors.neonBlue)),
          child: Text(_detectedType, style: GoogleFonts.orbitron(fontSize: 12, color: Colors.white, fontWeight: FontWeight.bold)),
        ).animate().scale(duration: 300.ms),
        const SizedBox(height: 30),
         Stack(
           children: [
             ClipRRect(
               borderRadius: BorderRadius.circular(24), 
               child: BackdropFilter(
                 filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10), 
                 child: Container(
                   padding: const EdgeInsets.fromLTRB(24, 8, 90, 8), 
                   decoration: BoxDecoration(
                     color: AppColors.glassWhite, 
                     borderRadius: BorderRadius.circular(24), 
                     border: Border.all(color: Colors.white12)
                   ), 
                   child: TextField(
                     controller: _controller, 
                     style: GoogleFonts.outfit(fontSize: 22, color: Colors.white), 
                     cursorColor: AppColors.neonCyan, 
                     textAlign: TextAlign.center, 
                     decoration: InputDecoration(
                       border: InputBorder.none, 
                       hintText: "Type URL or Text...", 
                       hintStyle: GoogleFonts.outfit(color: Colors.white30)
                     )
                   )
                 )
               )
             ), 
             Positioned(
               right: 48, 
               top: 8, 
               bottom: 8, 
               child: IconButton(
                 icon: Icon(Icons.content_copy, color: Colors.white38),
                 tooltip: 'Copy',
                 onPressed: () {
                   if (_controller.text.isNotEmpty) {
                     _copyToClipboard(_controller.text);
                   }
                 },
               )
             ),
             Positioned(
               right: 8, 
               top: 8, 
               bottom: 8, 
               child: IconButton(
                 icon: Icon(Icons.save, color: Colors.white38), 
                 tooltip: 'Save',
                 onPressed: _saveItem
               )
             )
           ]
         ).animate().fadeIn().slideY(begin: 0.2, end: 0),
         const SizedBox(height: 16),
         TextButton.icon(
            onPressed: _pickContact,
            icon: const Icon(Icons.contacts, color: AppColors.neonCyan),
            label: Text("SHARE CONTACT", style: GoogleFonts.orbitron(color: Colors.white54, letterSpacing: 2)),
            style: TextButton.styleFrom(
              backgroundColor: AppColors.glassWhite,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20))
            ),
         ).animate().fadeIn(delay: 200.ms)
       ],
     );
  }
  
  Widget _buildRadarStatus() => Column(
    key: const ValueKey("RADAR"), 
    children: [
      Icon(Icons.nfc, size: 60, color: AppColors.neonCyan)
        .animate(onPlay: (c)=>c.repeat(reverse: true))
        .scale(begin: Offset(0.8,0.8), end: Offset(1.2,1.2), duration: 1.seconds)
        .then()
        .shimmer(color: Colors.white), 
      SizedBox(height: 20), 
      Text("READY TO SEND", style: GoogleFonts.orbitron(fontSize: 18, color: AppColors.neonCyan)), 
      SizedBox(height: 10), 
      Text("Touch phones together", style: GoogleFonts.outfit(color: Colors.white54, fontSize: 14)),
      SizedBox(height: 6),
      Text("Back to back (NFC areas)", style: GoogleFonts.outfit(color: Colors.white30, fontSize: 12, fontStyle: FontStyle.italic))
    ]
  );
  Widget _buildSuccessStatus() => Column(key: const ValueKey("SUCCESS"), children: [Icon(Icons.check_circle_outline, size: 80, color: AppColors.neonCyan).animate().scale(curve: Curves.elasticOut, duration: 800.ms).then().boxShadow(end: BoxShadow(color: AppColors.neonCyan, blurRadius: 40)), SizedBox(height: 20), Text("SENT!", style: GoogleFonts.orbitron(fontSize: 18, color: AppColors.neonCyan))]);
  Widget _buildErrorStatus() => Column(key: const ValueKey("ERROR"), children: [Icon(Icons.error_outline, size: 60, color: Colors.redAccent).animate().shake(), SizedBox(height: 20), Text("FAILED", style: GoogleFonts.orbitron(fontSize: 18, color: Colors.redAccent)), SizedBox(height: 10), Text(_nfcManager.lastError.isEmpty ? "Unknown Error" : _nfcManager.lastError, style: GoogleFonts.outfit(color: Colors.white54), textAlign: TextAlign.center)]);
  
  Widget _buildSendButton(String availability) => GestureDetector(onTap: _startNfc, child: Container(height: 60, decoration: BoxDecoration(borderRadius: BorderRadius.circular(30), gradient: LinearGradient(colors: (availability != "AVAILABLE") ? [Colors.grey, Colors.grey] : [AppColors.neonBlue, AppColors.neonPurple]), boxShadow: (availability != "AVAILABLE") ? [] : [BoxShadow(color: AppColors.neonBlue.withOpacity(0.5), blurRadius: 20, offset: Offset(0,5))]), child: Center(child: Text("INITIATE TRANSFER", style: GoogleFonts.orbitron(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)))));
}

// --- SAVED ITEMS PAGE WITH DIRECT SEND ---
class SavedItemsPage extends StatefulWidget {
  const SavedItemsPage({super.key});

  @override
  State<SavedItemsPage> createState() => _SavedItemsPageState();
}

class _SavedItemsPageState extends State<SavedItemsPage> {
  List<Map<String, String>> _items = [];
  final NfcManager _nfcManager = NfcManager();

  @override
  void initState() {
    super.initState();
    _loadItems();
  }

  Future<void> _loadItems() async {
    final items = await StorageService.getItems();
    setState(() => _items = items);
  }

  Future<void> _delete(String data) async {
    await StorageService.deleteItem(data);
    _loadItems();
  }

  Future<void> _edit(Map<String, String> item) async {
    final TextEditingController nameController = TextEditingController(text: item["name"]);
    final TextEditingController dataController = TextEditingController(text: item["data"]);
    
    await showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(24),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
            child: Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                 color: AppColors.background.withOpacity(0.9),
                 border: Border.all(color: Colors.white24),
                 borderRadius: BorderRadius.circular(24)
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text("EDIT ITEM", style: GoogleFonts.orbitron(fontSize: 18, color: AppColors.neonCyan)),
                  const SizedBox(height: 16),
                  TextField(
                    controller: nameController,
                    style: GoogleFonts.outfit(color: Colors.white),
                    decoration: InputDecoration(
                      labelText: "Name",
                      labelStyle: TextStyle(color: AppColors.neonBlue),
                      filled: true,
                      fillColor: Colors.white10,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                    ),
                  ),
                  const SizedBox(height: 10),
                   TextField(
                    controller: dataController,
                    style: GoogleFonts.outfit(color: Colors.white),
                    decoration: InputDecoration(
                      labelText: "Data",
                      labelStyle: TextStyle(color: AppColors.neonPurple),
                      filled: true,
                      fillColor: Colors.white10,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                    ),
                  ),
                  const SizedBox(height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(onPressed: () => Navigator.pop(context), child: Text("CANCEL", style: GoogleFonts.orbitron(color: Colors.white54))),
                      const SizedBox(width: 8),
                      TextButton(
                        onPressed: () async {
                          if (dataController.text.isNotEmpty) {
                             await StorageService.updateItem(item["data"]!, nameController.text, dataController.text);
                             if (mounted) Navigator.pop(context);
                             _loadItems();
                          }
                        },
                        child: Text("SAVE", style: GoogleFonts.orbitron(color: AppColors.neonCyan))
                      ),
                    ],
                  )
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
  
  void _onItemTap(String item) {
    // Show Modal with NFC flow
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => NfcTransmissionModal(data: item),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Stack(
        children: [
          const MeshGradientBackground(),
          SafeArea(
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Row(
                    children: [
                      IconButton(icon: Icon(Icons.arrow_back, color: Colors.white), onPressed: () => Navigator.pop(context)),
                      const SizedBox(width: 10),
                      Text("SAVED DATA", style: GoogleFonts.orbitron(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white)),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                  child: Text("Tap an item to transmit via NFC immediately.", style: GoogleFonts.outfit(color: Colors.white30, fontSize: 12)),
                ),
                Expanded(
                  child: _items.isEmpty 
                  ? Center(child: Text("No saved items", style: GoogleFonts.outfit(color: Colors.white30)))
                  : ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      itemCount: _items.length,
                      itemBuilder: (context, index) {
                        final itemMap = _items[index];
                        final name = itemMap["name"] ?? "Unknown";
                        final data = itemMap["data"] ?? "";
                        
                        final isLink = data.startsWith("http") || data.startsWith("upi://");
                        return Dismissible(
                          key: Key(data), // Using data as key might not be unique but ok for simple list
                          onDismissed: (_) => _delete(data),
                          background: Container(color: Colors.red.withOpacity(0.5), alignment: Alignment.centerRight, padding: const EdgeInsets.only(right: 20), child: Icon(Icons.delete, color: Colors.white)),
                          child: GestureDetector(
                            onTap: () => _onItemTap(data),
                            child: Container(
                              margin: const EdgeInsets.only(bottom: 12),
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: AppColors.glassWhite,
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(color: Colors.white12)
                              ),
                              child: Row(
                                children: [
                                  Icon(isLink ? Icons.link : Icons.text_fields, color: isLink ? AppColors.neonPurple : AppColors.neonBlue),
                                  const SizedBox(width: 16),
                                  Expanded(child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(name, style: GoogleFonts.outfit(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold), maxLines: 1, overflow: TextOverflow.ellipsis),
                                      Text(data, style: GoogleFonts.outfit(color: Colors.white54, fontSize: 12), maxLines: 1, overflow: TextOverflow.ellipsis),
                                    ],
                                  )),
                                  // Copy button
                                  IconButton(
                                    icon: Icon(Icons.copy, size: 18, color: Colors.white30),
                                    tooltip: 'Copy',
                                    onPressed: () async {
                                      try {
                                        await Clipboard.setData(ClipboardData(text: data));
                                        if (mounted) {
                                          ScaffoldMessenger.of(context).showSnackBar(
                                            SnackBar(
                                              content: Row(
                                                children: [
                                                  Icon(Icons.check_circle, color: AppColors.neonCyan, size: 20),
                                                  SizedBox(width: 8),
                                                  Text("Copied!", style: GoogleFonts.outfit()),
                                                ],
                                              ),
                                              backgroundColor: AppColors.neonCyan.withOpacity(0.2),
                                              duration: Duration(seconds: 1),
                                            )
                                          );
                                        }
                                      } catch (e) {
                                        print('Copy failed: $e');
                                      }
                                    },
                                  ),
                                  // Share button
                                  IconButton(
                                    icon: Icon(Icons.share, size: 18, color: Colors.white30),
                                    tooltip: 'Share',
                                    onPressed: () async {
                                      try {
                                        await Share.share(data, subject: name);
                                      } catch (e) {
                                        print('Share failed: $e');
                                        if (mounted) {
                                          ScaffoldMessenger.of(context).showSnackBar(
                                            SnackBar(
                                              content: Text("Share failed", style: GoogleFonts.outfit()),
                                              backgroundColor: Colors.red.withOpacity(0.8),
                                            )
                                          );
                                        }
                                      }
                                    },
                                  ),
                                  // Edit button
                                  IconButton(
                                    icon: Icon(Icons.edit, size: 18, color: Colors.white30),
                                    tooltip: 'Edit',
                                    onPressed: () => _edit(itemMap),
                                  ),
                                  Icon(Icons.nfc, color: AppColors.neonCyan.withOpacity(0.5))
                                ],
                              ),
                            ),
                          ).animate().fadeIn(delay: (index * 50).ms).slideX(),
                        );
                      },
                    ),
                )
              ],
            ),
          )
        ],
      ),
    );
  }
}

// --- NFC TRANSMISSION MODAL ---
// Handles the sending process independently when triggered from list
class NfcTransmissionModal extends StatefulWidget {
  final String data;
  const NfcTransmissionModal({super.key, required this.data});

  @override
  State<NfcTransmissionModal> createState() => _NfcTransmissionModalState();
}

class _NfcTransmissionModalState extends State<NfcTransmissionModal> {
  final NfcManager _nfcManager = NfcManager();
  StreamSubscription? _subscription;
  NfcState _state = NfcState.idle;

  @override
  void initState() {
    super.initState();
    _subscription = _nfcManager.statusStream.listen((state) {
      if (!mounted) return;
      setState(() => _state = state);
      
      if (state == NfcState.success) {
         Vibration.vibrate(duration: 100);
         Future.delayed(const Duration(seconds: 2), () {
            if (mounted) Navigator.pop(context);
         });
      } else if (state == NfcState.error) {
         Vibration.vibrate(duration: 500);
         // Don't auto pop on error, let user see it
      }
    });
    
    // Start automatically
    _nfcManager.startNfc(widget.data);
  }

  @override
  void dispose() {
    _nfcManager.stopNfc();
    _subscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Glassmorphic Dialog
    return Dialog(
        backgroundColor: Colors.transparent,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(24),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
            child: Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                 color: AppColors.background.withOpacity(0.8),
                 border: Border.all(color: Colors.white24),
                 borderRadius: BorderRadius.circular(24)
              ),
              child: Column(
                 mainAxisSize: MainAxisSize.min,
                 children: [
                    if (_state == NfcState.waiting || _state == NfcState.idle)
                       Column(children: [
                          Icon(Icons.nfc, size: 60, color: AppColors.neonCyan).animate(onPlay: (c)=>c.repeat(reverse: true)).scale(begin: Offset(0.8,0.8), end: Offset(1.2,1.2), duration: 1.seconds).then().shimmer(color: Colors.white),
                          const SizedBox(height: 20),
                          Text("TRANSMITTING...", style: GoogleFonts.orbitron(fontSize: 18, color: AppColors.neonCyan)),
                          const SizedBox(height: 10),
                          Text("Hold near device", style: GoogleFonts.outfit(color: Colors.white54)),
                          const SizedBox(height: 20),
                          TextButton(onPressed: () => Navigator.pop(context), child: Text("CANCEL", style: GoogleFonts.orbitron(color: Colors.white54)))
                       ]),
                    
                    if (_state == NfcState.success)
                       Column(children: [
                          Icon(Icons.check_circle, size: 60, color: AppColors.neonCyan).animate().scale(curve: Curves.elasticOut),
                          const SizedBox(height: 20),
                          Text("SENT!", style: GoogleFonts.orbitron(fontSize: 18, color: AppColors.neonCyan)),
                       ]),
                       
                    if (_state == NfcState.error)
                       Column(children: [
                          Icon(Icons.error, size: 60, color: Colors.redAccent).animate().shake(),
                          const SizedBox(height: 20),
                          Text("FAILED", style: GoogleFonts.orbitron(fontSize: 18, color: Colors.redAccent)),
                          const SizedBox(height: 10),
                          Text(_nfcManager.lastError, style: GoogleFonts.outfit(color: Colors.white54), textAlign: TextAlign.center),
                          const SizedBox(height: 20),
                          TextButton(onPressed: () => Navigator.pop(context), child: Text("CLOSE", style: GoogleFonts.orbitron(color: Colors.white54)))
                       ]),
                 ],
              ),
            ),
          ),
        ),
    );
  }
}

// --- RECEIVED HISTORY PAGE ---
class ReceivedHistoryPage extends StatefulWidget {
  const ReceivedHistoryPage({super.key});

  @override
  State<ReceivedHistoryPage> createState() => _ReceivedHistoryPageState();
}

class _ReceivedHistoryPageState extends State<ReceivedHistoryPage> {
  List<Map<String, dynamic>> _history = [];
  Map<String, int> _stats = {};

  @override
  void initState() {
    super.initState();
    _loadHistory();
    _loadStats();
  }

  Future<void> _loadHistory() async {
    final history = await ReceivedHistoryStorage.getHistory();
    setState(() => _history = history);
  }

  Future<void> _loadStats() async {
    final stats = await ReceivedHistoryStorage.getStatistics();
    setState(() => _stats = stats);
  }

  Future<void> _clearHistory() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.background,
        title: Text("Clear History?", style: GoogleFonts.orbitron(color: AppColors.neonCyan)),
        content: Text("This will delete all received NFC data.", style: GoogleFonts.outfit(color: Colors.white70)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: Text("CANCEL", style: GoogleFonts.orbitron(color: Colors.white54))),
          TextButton(onPressed: () => Navigator.pop(context, true), child: Text("CLEAR", style: GoogleFonts.orbitron(color: Colors.redAccent))),
        ],
      ),
    );
    
    if (confirm == true) {
      await ReceivedHistoryStorage.clearHistory();
      _loadHistory();
    }
  }

  void _copyToClipboard(String text) {
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text("Copied to clipboard", style: GoogleFonts.outfit()), backgroundColor: AppColors.neonPurple)
    );
  }

  void _shareData(String text) {
    Share.share(text, subject: 'NFC Data');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          const MeshGradientBackground(),
          SafeArea(
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Row(
                    children: [
                      IconButton(
                        icon: Icon(Icons.arrow_back, color: Colors.white),
                        onPressed: () => Navigator.pop(context)
                      ),
                      const SizedBox(width: 10),
                      Text("RECEIVED HISTORY", style: GoogleFonts.orbitron(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
                      Spacer(),
                      if (_history.isNotEmpty)
                        IconButton(
                          icon: Icon(Icons.delete_outline, color: Colors.redAccent),
                          onPressed: _clearHistory,
                        ),
                    ],
                  ),
                ),
                
                // Statistics Cards
                if (_stats.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24.0),
                    child: Row(
                      children: [
                        Expanded(child: _buildStatCard("Sent", _stats['sent']!.toString(), Icons.arrow_upward, AppColors.neonPurple)),
                        SizedBox(width: 12),
                        Expanded(child: _buildStatCard("Received", _stats['received']!.toString(), Icons.arrow_downward, AppColors.neonCyan)),
                        SizedBox(width: 12),
                        Expanded(child: _buildStatCard("Total", _stats['total']!.toString(), Icons.sync_alt, AppColors.neonBlue)),
                      ],
                    ),
                  ),
                
                const SizedBox(height: 20),
                
                Expanded(
                  child: _history.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.inbox_outlined, size: 80, color: Colors.white24),
                              SizedBox(height: 16),
                              Text("No received data yet", style: GoogleFonts.outfit(color: Colors.white38, fontSize: 16)),
                            ],
                          ),
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.symmetric(horizontal: 24),
                          itemCount: _history.length,
                          itemBuilder: (context, index) {
                            final item = _history[index];
                            return _buildHistoryCard(item);
                          },
                        ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard(String label, String value, IconData icon, Color color) {
    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.glassWhite,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 24),
          SizedBox(height: 8),
          Text(value, style: GoogleFonts.orbitron(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white)),
          Text(label, style: GoogleFonts.outfit(fontSize: 10, color: Colors.white54)),
        ],
      ),
    ).animate().fadeIn().scale();
  }

  Widget _buildHistoryCard(Map<String, dynamic> item) {
    final type = item['type'] ?? 'UNKNOWN';
    final data = item['data'] ?? '';
    final timestamp = DateTime.parse(item['timestamp']);
    final timeAgo = _formatTimeAgo(timestamp);
    
    IconData icon;
    Color color;
    
    switch (type) {
      case 'URL':
        icon = Icons.link;
        color = AppColors.neonPurple;
        break;
      case 'TEXT':
        icon = Icons.text_fields;
        color = AppColors.neonBlue;
        break;
      case 'TAG':
        icon = Icons.nfc;
        color = AppColors.neonCyan;
        break;
      default:
        icon = Icons.help_outline;
        color = Colors.white54;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: AppColors.glassWhite,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white12),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: color.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(icon, color: color, size: 20),
                    ),
                    SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(type, style: GoogleFonts.orbitron(color: color, fontSize: 12, fontWeight: FontWeight.bold)),
                          Text(timeAgo, style: GoogleFonts.outfit(color: Colors.white38, fontSize: 10)),
                        ],
                      ),
                    ),
                    PopupMenuButton<String>(
                      icon: Icon(Icons.more_vert, color: Colors.white54),
                      color: AppColors.background,
                      onSelected: (value) {
                        if (value == 'copy') _copyToClipboard(data);
                        if (value == 'share') _shareData(data);
                      },
                      itemBuilder: (context) => [
                        PopupMenuItem(value: 'copy', child: Row(children: [Icon(Icons.copy, size: 18, color: AppColors.neonCyan), SizedBox(width: 8), Text("Copy", style: GoogleFonts.outfit(color: Colors.white))])),
                        PopupMenuItem(value: 'share', child: Row(children: [Icon(Icons.share, size: 18, color: AppColors.neonPurple), SizedBox(width: 8), Text("Share", style: GoogleFonts.outfit(color: Colors.white))])),
                      ],
                    ),
                  ],
                ),
                SizedBox(height: 12),
                Text(
                  data,
                  style: GoogleFonts.outfit(color: Colors.white, fontSize: 14),
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ),
      ),
    ).animate().fadeIn().slideX(begin: 0.2, end: 0);
  }

  String _formatTimeAgo(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inSeconds < 60) return 'Just now';
    if (difference.inMinutes < 60) return '${difference.inMinutes}m ago';
    if (difference.inHours < 24) return '${difference.inHours}h ago';
    if (difference.inDays < 7) return '${difference.inDays}d ago';
    
    return DateFormat('MMM dd, yyyy').format(dateTime);
  }
}

// --- UPDATE DIALOG ---
class UpdateDialog extends StatefulWidget {
  final Map<String, dynamic> updateInfo;
  const UpdateDialog({super.key, required this.updateInfo});

  @override
  State<UpdateDialog> createState() => _UpdateDialogState();
}

class _UpdateDialogState extends State<UpdateDialog> {
  final UpdateManager _updateManager = UpdateManager();
  bool _isDownloading = false;
  double _progress = 0.0;
  
  @override
  void initState() {
    super.initState();
    _updateManager.downloadProgress.addListener(_onProgressUpdate);
    _updateManager.isDownloading.addListener(_onDownloadingUpdate);
  }
  
  @override
  void dispose() {
    _updateManager.downloadProgress.removeListener(_onProgressUpdate);
    _updateManager.isDownloading.removeListener(_onDownloadingUpdate);
    super.dispose();
  }
  
  void _onProgressUpdate() {
    if (mounted) setState(() => _progress = _updateManager.downloadProgress.value);
  }
  
  void _onDownloadingUpdate() {
    if (mounted) setState(() => _isDownloading = _updateManager.isDownloading.value);
  }
  
  Future<void> _downloadAndInstall() async {
    setState(() => _isDownloading = true);
    
    final apkPath = await _updateManager.downloadApk();
    
    if (apkPath != null && mounted) {
      // Show install prompt
      await _updateManager.installApk(apkPath);
      Navigator.pop(context);
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Download failed. Please try again.', style: GoogleFonts.outfit()),
          backgroundColor: Colors.redAccent,
        ),
      );
      setState(() => _isDownloading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
          child: Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: AppColors.background.withOpacity(0.95),
              border: Border.all(color: AppColors.neonCyan.withOpacity(0.5), width: 2),
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: AppColors.neonCyan.withOpacity(0.3),
                  blurRadius: 20,
                  spreadRadius: 2,
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Icon
                Container(
                  padding: EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.neonCyan.withOpacity(0.2),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(Icons.system_update, size: 48, color: AppColors.neonCyan),
                ).animate().scale(curve: Curves.elasticOut),
                
                SizedBox(height: 20),
                
                // Title
                Text(
                  "UPDATE AVAILABLE",
                  style: GoogleFonts.orbitron(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: AppColors.neonCyan,
                    letterSpacing: 2,
                  ),
                ),
                
                SizedBox(height: 16),
                
                // Version info
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: AppColors.glassWhite,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.white12),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        widget.updateInfo['currentVersion'] ?? '1.0.0',
                        style: GoogleFonts.orbitron(color: Colors.white54, fontSize: 14),
                      ),
                      SizedBox(width: 8),
                      Icon(Icons.arrow_forward, color: AppColors.neonPurple, size: 16),
                      SizedBox(width: 8),
                      Text(
                        widget.updateInfo['latestVersion'] ?? '1.0.1',
                        style: GoogleFonts.orbitron(
                          color: AppColors.neonCyan,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
                
                SizedBox(height: 20),
                
                // Changelog
                Container(
                  constraints: BoxConstraints(maxHeight: 300),
                  padding: EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.glassWhite,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.white12),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        "WHAT'S NEW",
                        style: GoogleFonts.orbitron(
                          color: AppColors.neonPurple,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      SizedBox(height: 8),
                      Flexible(
                        child: SingleChildScrollView(
                          child: Text(
                            widget.updateInfo['changelog'] ?? 'Bug fixes and improvements',
                            style: GoogleFonts.outfit(color: Colors.white70, fontSize: 14, height: 1.5),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                
                SizedBox(height: 24),
                
                // Download progress
                if (_isDownloading) ...[
                  Column(
                    children: [
                      LinearProgressIndicator(
                        value: _progress,
                        backgroundColor: Colors.white10,
                        valueColor: AlwaysStoppedAnimation<Color>(AppColors.neonCyan),
                        minHeight: 8,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      SizedBox(height: 8),
                      Text(
                        '${(_progress * 100).toInt()}%',
                        style: GoogleFonts.orbitron(
                          color: AppColors.neonCyan,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 16),
                ],
                
                // Buttons
                if (!_isDownloading)
                  Row(
                    children: [
                      Expanded(
                        child: TextButton(
                          onPressed: () => Navigator.pop(context),
                          style: TextButton.styleFrom(
                            padding: EdgeInsets.symmetric(vertical: 12),
                            backgroundColor: Colors.white10,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: Text(
                            "LATER",
                            style: GoogleFonts.orbitron(
                              color: Colors.white54,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                      SizedBox(width: 12),
                      Expanded(
                        flex: 2,
                        child: ElevatedButton(
                          onPressed: _downloadAndInstall,
                          style: ElevatedButton.styleFrom(
                            padding: EdgeInsets.symmetric(vertical: 12),
                            backgroundColor: AppColors.neonCyan,
                            foregroundColor: Colors.black,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            elevation: 0,
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.download, size: 20),
                              SizedBox(width: 8),
                              Text(
                                "UPDATE NOW",
                                style: GoogleFonts.orbitron(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
              ],
            ).animate().fadeIn().scale(),
          ),
        ),
      ),
    );
  }
}

// --- ABOUT PAGE ---
class AboutPage extends StatefulWidget {
  const AboutPage({super.key});

  @override
  State<AboutPage> createState() => _AboutPageState();
}

class _AboutPageState extends State<AboutPage> {
  String _version = 'Loading...';
  String _buildNumber = '';

  @override
  void initState() {
    super.initState();
    _loadVersion();
  }

  Future<void> _loadVersion() async {
    final packageInfo = await PackageInfo.fromPlatform();
    setState(() {
      _version = packageInfo.version;
      _buildNumber = packageInfo.buildNumber;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          const MeshGradientBackground(),
          SafeArea(
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Row(
                    children: [
                      IconButton(icon: Icon(Icons.arrow_back, color: Colors.white), onPressed: () => Navigator.pop(context)),
                      const SizedBox(width: 10),
                      Text("ABOUT", style: GoogleFonts.orbitron(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white)),
                    ],
                  ),
                ),
                Expanded(
                  child: Center(
                    child: Container(
                      margin: const EdgeInsets.all(24),
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: AppColors.glassWhite,
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(color: Colors.white24)
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.fingerprint, size: 80, color: AppColors.neonCyan).animate().shimmer(duration: 2.seconds),
                          const SizedBox(height: 20),
                          Text("TouchOne", style: GoogleFonts.orbitron(fontSize: 32, fontWeight: FontWeight.bold, color: Colors.white)),
                          const SizedBox(height: 10),
                          Text("v$_version", style: GoogleFonts.outfit(color: Colors.white54, fontSize: 16)),
                          const SizedBox(height: 10),
                          Text("NFC Data Transfer App", style: GoogleFonts.outfit(color: AppColors.neonCyan, fontSize: 12)),
                          const SizedBox(height: 40),
                          _buildInfoRow(Icons.person, "Dev: Rakesh Kumar Singh"),
                          const SizedBox(height: 16),
                          _buildInfoRow(Icons.email, "kumarpatelrakesh222@gmail.com"),
                          const SizedBox(height: 16),
                          _buildInfoRow(Icons.currency_rupee, "UPI: rakeshsingh157@oksbi", isCopyable: true),
                        ],
                      ).animate().scale(curve: Curves.easeOutBack),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Text("Designed for the Future", style: GoogleFonts.orbitron(color: Colors.white24, fontSize: 10)),
                )
              ],
            ),
          )
        ],
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String text, {bool isCopyable = false}) {
    return GestureDetector(
      onTap: isCopyable ? () {
        final upiId = text.replaceAll("UPI: ", "");
        Clipboard.setData(ClipboardData(text: upiId));
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("UPI ID copied: $upiId", style: GoogleFonts.outfit()), backgroundColor: AppColors.neonPurple));
      } : null,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: AppColors.neonBlue, size: 18),
          const SizedBox(width: 10),
          Flexible(child: Text(text, style: GoogleFonts.outfit(color: Colors.white, fontSize: 14), textAlign: TextAlign.center)),
          if (isCopyable) ...[
             const SizedBox(width: 8),
             Icon(Icons.copy, color: Colors.white24, size: 14)
          ]
        ],
      ),
    );
  }
}

// ... Shared Widgets ...
class MeshGradientBackground extends StatelessWidget {
  const MeshGradientBackground({super.key});
  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(color: AppColors.background),
      child: Stack(
        children: [
          Positioned(top: -100, left: -50, child: Container(width: 300, height: 300, decoration: BoxDecoration(shape: BoxShape.circle, color: AppColors.neonPurple.withOpacity(0.2))).animate(onPlay: (c) => c.repeat(reverse: true)).move(begin: Offset(0,0), end: Offset(50, 50), duration: 5.seconds).blur(begin: Offset(40,40), end: Offset(60,60), duration: 4.seconds)),
          Positioned(bottom: -50, right: -50, child: Container(width: 400, height: 400, decoration: BoxDecoration(shape: BoxShape.circle, color: AppColors.neonCyan.withOpacity(0.15))).animate(onPlay: (c) => c.repeat(reverse: true)).move(begin: Offset(0,0), end: Offset(-40, -60), duration: 7.seconds)),
          BackdropFilter(filter: ImageFilter.blur(sigmaX: 50, sigmaY: 50), child: Container(color: Colors.transparent))
        ],
      ),
    );
  }
}

class RadarOverlay extends StatelessWidget {
  const RadarOverlay({super.key});
  @override
  Widget build(BuildContext context) => Stack(children: [Positioned.fill(child: CustomPaint(painter: RadarPainter()))]).animate().fadeIn();
}

class RadarPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) => canvas.drawRect(Rect.fromLTWH(0,0,size.width,size.height), Paint()..color=Colors.black54);
  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class ParticleExplosion extends StatelessWidget {
  const ParticleExplosion({super.key});
  @override
  Widget build(BuildContext context) => Stack(children: List.generate(20, (index) {final rnd = math.Random(); return Positioned(left: MediaQuery.of(context).size.width/2, top: MediaQuery.of(context).size.height/2, child: Icon(Icons.star, size: 10, color: AppColors.neonCyan)).animate().move(end: Offset(rnd.nextDouble()*300-150, rnd.nextDouble()*300-150), duration: 1.seconds).fadeOut();}));
}

enum FeedbackType { light, medium, success, error }

// --- BEAUTIFUL ERROR DIALOG ---
class BeautifulErrorDialog extends StatelessWidget {
  final String title;
  final String message;
  final IconData icon;
  final Color iconColor;
  final String? actionText;
  final VoidCallback? onAction;

  const BeautifulErrorDialog({
    super.key,
    required this.title,
    required this.message,
    this.icon = Icons.error_outline,
    this.iconColor = Colors.red,
    this.actionText,
    this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      child: Container(
        constraints: BoxConstraints(maxWidth: 340),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              AppColors.background.withOpacity(0.95),
              Color(0xFF1A1A2E).withOpacity(0.95),
            ],
          ),
          borderRadius: BorderRadius.circular(28),
          border: Border.all(
            color: iconColor.withOpacity(0.3),
            width: 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: iconColor.withOpacity(0.2),
              blurRadius: 30,
              spreadRadius: 5,
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(28),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
            child: Padding(
              padding: const EdgeInsets.all(28.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Icon with animated background
                  Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: RadialGradient(
                        colors: [
                          iconColor.withOpacity(0.3),
                          iconColor.withOpacity(0.1),
                        ],
                      ),
                    ),
                    child: Icon(
                      icon,
                      size: 45,
                      color: iconColor,
                    ),
                  ).animate().scale(curve: Curves.elasticOut, duration: 600.ms).fadeIn(),
                  
                  SizedBox(height: 24),
                  
                  // Title
                  Text(
                    title,
                    style: GoogleFonts.orbitron(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                    textAlign: TextAlign.center,
                  ).animate().fadeIn(delay: 100.ms).slideY(begin: -0.3, end: 0),
                  
                  SizedBox(height: 16),
                  
                  // Message
                  Container(
                    padding: EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppColors.glassWhite,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.white12),
                    ),
                    child: Text(
                      message,
                      style: GoogleFonts.outfit(
                        fontSize: 14,
                        color: Colors.white.withOpacity(0.9),
                        height: 1.5,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ).animate().fadeIn(delay: 200.ms).scale(begin: Offset(0.9, 0.9)),
                  
                  SizedBox(height: 28),
                  
                  // Action Buttons
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      if (actionText != null && onAction != null) ...[
                        Expanded(
                          child: _buildButton(
                            context,
                            text: actionText!,
                            onPressed: () {
                              Navigator.of(context).pop();
                              onAction!();
                            },
                            gradient: LinearGradient(
                              colors: [iconColor, iconColor.withOpacity(0.7)],
                            ),
                          ),
                        ),
                        SizedBox(width: 12),
                      ],
                      Expanded(
                        child: _buildButton(
                          context,
                          text: actionText != null ? "Cancel" : "OK",
                          onPressed: () => Navigator.of(context).pop(),
                          gradient: LinearGradient(
                            colors: [Colors.grey[800]!, Colors.grey[700]!],
                          ),
                        ),
                      ),
                    ],
                  ).animate().fadeIn(delay: 300.ms).slideY(begin: 0.3, end: 0),
                ],
              ),
            ),
          ),
        ),
      ),
    ).animate().scale(begin: Offset(0.8, 0.8), curve: Curves.elasticOut);
  }

  Widget _buildButton(
    BuildContext context, {
    required String text,
    required VoidCallback onPressed,
    required Gradient gradient,
  }) {
    return Container(
      decoration: BoxDecoration(
        gradient: gradient,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: gradient.colors.first.withOpacity(0.3),
            blurRadius: 12,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(16),
          child: Container(
            padding: EdgeInsets.symmetric(vertical: 14, horizontal: 24),
            child: Text(
              text,
              style: GoogleFonts.outfit(
                color: Colors.white,
                fontSize: 15,
                fontWeight: FontWeight.w600,
              ),
              textAlign: TextAlign.center,
            ),
          ),
        ),
      ),
    );
  }
}

// --- ERROR HELPER FUNCTION ---
void showBeautifulError(
  BuildContext context, {
  required String title,
  required String message,
  IconData? icon,
  Color? iconColor,
  String? actionText,
  VoidCallback? onAction,
}) {
  showDialog(
    context: context,
    barrierDismissible: false,
    barrierColor: Colors.black54,
    builder: (context) => BeautifulErrorDialog(
      title: title,
      message: message,
      icon: icon ?? Icons.error_outline,
      iconColor: iconColor ?? Colors.red,
      actionText: actionText,
      onAction: onAction,
    ),
  );
}

// Success notification
void showBeautifulSuccess(
  BuildContext context, {
  required String title,
  required String message,
}) {
  showDialog(
    context: context,
    barrierDismissible: true,
    barrierColor: Colors.black38,
    builder: (context) => BeautifulErrorDialog(
      title: title,
      message: message,
      icon: Icons.check_circle_outline,
      iconColor: AppColors.neonCyan,
    ),
  );
}

// Warning notification  
void showBeautifulWarning(
  BuildContext context, {
  required String title,
  required String message,
  String? actionText,
  VoidCallback? onAction,
}) {
  showDialog(
    context: context,
    barrierDismissible: false,
    barrierColor: Colors.black54,
    builder: (context) => BeautifulErrorDialog(
      title: title,
      message: message,
      icon: Icons.warning_amber_rounded,
      iconColor: Colors.orange,
      actionText: actionText,
      onAction: onAction,
    ),
  );
}

// Info notification
void showBeautifulInfo(
  BuildContext context, {
  required String title,
  required String message,
  String? actionText,
  VoidCallback? onAction,
}) {
  showDialog(
    context: context,
    barrierDismissible: true,
    barrierColor: Colors.black38,
    builder: (context) => BeautifulErrorDialog(
      title: title,
      message: message,
      icon: Icons.info_outline,
      iconColor: AppColors.neonBlue,
      actionText: actionText,
      onAction: onAction,
    ),
  );
}

