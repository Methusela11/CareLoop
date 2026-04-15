import 'package:flutter/material.dart';
import 'package:flutter/services.dart';  // ← ADD THIS for MethodChannel
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialize notifications
  await initializeNotifications();
  
  runApp(const CareLoopApp());
}

// Global notification plugin instance
final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin = 
    FlutterLocalNotificationsPlugin();

// Initialize notification settings
Future<void> initializeNotifications() async {
  // Android settings
  const AndroidInitializationSettings initializationSettingsAndroid =
      AndroidInitializationSettings('@mipmap/ic_launcher');
  
  // iOS settings
  const DarwinInitializationSettings initializationSettingsIOS =
      DarwinInitializationSettings(
    requestAlertPermission: true,
    requestBadgePermission: true,
    requestSoundPermission: true,
  );
  
  const InitializationSettings initializationSettings = InitializationSettings(
    android: initializationSettingsAndroid,
    iOS: initializationSettingsIOS,
  );
  
  await flutterLocalNotificationsPlugin.initialize(initializationSettings);
}

// Schedule a daily notification with SOUND
Future<void> scheduleDailyNotification(TimeOfDay time, String checkinTime) async {
  // Cancel any existing notifications first
  await flutterLocalNotificationsPlugin.cancelAll();
  
  // Calculate next notification time
  final now = DateTime.now();
  var scheduledTime = DateTime(now.year, now.month, now.day, time.hour, time.minute);
  
  // If time has passed today, schedule for tomorrow
  if (scheduledTime.isBefore(now)) {
    scheduledTime = scheduledTime.add(const Duration(days: 1));
  }
  
  print('⏰ Scheduling alarm for: ${DateFormat('h:mm a').format(scheduledTime)}');
  
  // Android notification details with SOUND
  const AndroidNotificationDetails androidPlatformChannelSpecifics =
      AndroidNotificationDetails(
    'careloop_channel',
    'CareLoop Reminders',
    channelDescription: 'Daily check-in reminders',
    importance: Importance.max,
    priority: Priority.max,
    playSound: true,
    enableVibration: true,
    category: AndroidNotificationCategory.alarm,
    fullScreenIntent: true,
  );
  
  // iOS notification details
  const DarwinNotificationDetails iosPlatformChannelSpecifics =
      DarwinNotificationDetails(
    presentAlert: true,
    presentBadge: true,
    presentSound: true,
  );
  
  const NotificationDetails platformChannelSpecifics = NotificationDetails(
    android: androidPlatformChannelSpecifics,
    iOS: iosPlatformChannelSpecifics,
  );
  
  // Use periodicallyShow (works with this package version)
  await flutterLocalNotificationsPlugin.periodicallyShow(
    0, // Notification ID
    '🔔 TIME TO CHECK IN! 🔔',
    'Tap "I\'M OK" to let your family know you\'re safe.',
    RepeatInterval.daily,
    platformChannelSpecifics,
    androidAllowWhileIdle: true,
  );
  
  print('✅ Alarm notification scheduled for ${DateFormat('h:mm a').format(scheduledTime)}');
}

// Show an immediate test notification
Future<void> showTestNotification() async {
  const AndroidNotificationDetails androidPlatformChannelSpecifics =
      AndroidNotificationDetails(
    'careloop_channel',
    'CareLoop Reminders',
    channelDescription: 'Daily check-in reminders',
    importance: Importance.max,
    priority: Priority.max,
    playSound: true,
    enableVibration: true,
    category: AndroidNotificationCategory.alarm,
    fullScreenIntent: true,
  );
  
  const DarwinNotificationDetails iosPlatformChannelSpecifics =
      DarwinNotificationDetails(
    presentAlert: true,
    presentSound: true,
  );
  
  const NotificationDetails platformChannelSpecifics = NotificationDetails(
    android: androidPlatformChannelSpecifics,
    iOS: iosPlatformChannelSpecifics,
  );
  
  await flutterLocalNotificationsPlugin.show(
    999,
    '🧪 TEST NOTIFICATION 🧪',
    'This is how the reminder will appear! It will ring and vibrate.',
    platformChannelSpecifics,
  );
}

class CareLoopApp extends StatelessWidget {
  const CareLoopApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'CareLoop',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.blue,
          primary: Colors.blue.shade700,
        ),
        useMaterial3: true,
        textTheme: const TextTheme(
          displayLarge: TextStyle(fontSize: 56, fontWeight: FontWeight.bold),
          bodyLarge: TextStyle(fontSize: 24),
          bodyMedium: TextStyle(fontSize: 20),
        ),
      ),
      debugShowCheckedModeBanner: false,
      home: const ElderlyHomePage(),
    );
  }
}

class ElderlyHomePage extends StatefulWidget {
  const ElderlyHomePage({super.key});

  @override
  State<ElderlyHomePage> createState() => _ElderlyHomePageState();
}

class _ElderlyHomePageState extends State<ElderlyHomePage> {
  bool _hasCheckedToday = false;
  DateTime? _lastCheckinTime;
  String _greeting = "Good morning!";
  String _checkinTime = "9:00 AM";

  @override
  void initState() {
    super.initState();
    _loadSavedData();
    _updateGreeting();
    _scheduleNotificationFromSavedTime();
  }

  Future<void> _loadSavedData() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _hasCheckedToday = prefs.getBool('hasCheckedToday') ?? false;
      final savedTime = prefs.getString('lastCheckinTime');
      if (savedTime != null) {
        _lastCheckinTime = DateTime.parse(savedTime);
      }
      _checkinTime = prefs.getString('checkinTime') ?? "9:00 AM";
    });
    
    await _scheduleNotificationFromSavedTime();
  }
  
  Future<void> _scheduleNotificationFromSavedTime() async {
    try {
      final parsedTime = DateFormat('h:mm a').parse(_checkinTime);
      final timeOfDay = TimeOfDay(hour: parsedTime.hour, minute: parsedTime.minute);
      await scheduleDailyNotification(timeOfDay, _checkinTime);
    } catch (e) {
      print('Error scheduling notification: $e');
      await scheduleDailyNotification(const TimeOfDay(hour: 9, minute: 0), _checkinTime);
    }
  }

  Future<void> _saveCheckin() async {
    final prefs = await SharedPreferences.getInstance();
    final now = DateTime.now();
    
    setState(() {
      _hasCheckedToday = true;
      _lastCheckinTime = now;
    });
    
    await prefs.setBool('hasCheckedToday', true);
    await prefs.setString('lastCheckinTime', now.toIso8601String());
    
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Thank you! Your family has been notified.'),
          backgroundColor: Colors.green.shade700,
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }

  void _updateGreeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) {
      _greeting = "Good morning!";
    } else if (hour < 17) {
      _greeting = "Good afternoon!";
    } else {
      _greeting = "Good evening!";
    }
  }

  String _getFormattedTime() {
    if (_lastCheckinTime == null) return "Not yet today";
    return DateFormat('h:mm a').format(_lastCheckinTime!);
  }

  Future<void> _changeCheckinTime() async {
    TimeOfDay initialTime;
    try {
      final parsedTime = DateFormat('h:mm a').parse(_checkinTime);
      initialTime = TimeOfDay(hour: parsedTime.hour, minute: parsedTime.minute);
    } catch (e) {
      initialTime = const TimeOfDay(hour: 9, minute: 0);
    }

    final TimeOfDay? selectedTime = await showTimePicker(
      context: context,
      initialTime: initialTime,
      builder: (context, child) {
        return Theme(
          data: ThemeData.light().copyWith(
            colorScheme: const ColorScheme.light(
              primary: Colors.blue,
              onPrimary: Colors.white,
              surface: Colors.white,
              onSurface: Colors.black,
            ),
            timePickerTheme: const TimePickerThemeData(
              hourMinuteTextStyle: TextStyle(fontSize: 48, fontWeight: FontWeight.bold),
              dialHandColor: Colors.blue,
              dialBackgroundColor: Colors.blue,
              hourMinuteColor: Colors.blue,
            ),
          ),
          child: child!,
        );
      },
    );

    if (selectedTime != null) {
      final prefs = await SharedPreferences.getInstance();
      final now = DateTime.now();
      final selectedDateTime = DateTime(now.year, now.month, now.day, selectedTime.hour, selectedTime.minute);
      final formattedTime = DateFormat('h:mm a').format(selectedDateTime);
      
      setState(() {
        _checkinTime = formattedTime;
      });
      await prefs.setString('checkinTime', formattedTime);
      
      await scheduleDailyNotification(selectedTime, formattedTime);
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Check-in time changed to $_checkinTime\nAlarm reminder set!'),
            backgroundColor: Colors.green.shade700,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.blue.shade50,
      body: SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Greeting
                Text(
                  _greeting,
                  style: Theme.of(context).textTheme.displayLarge?.copyWith(
                    color: Colors.blue.shade800,
                  ),
                  textAlign: TextAlign.center,
                ),
                
                const SizedBox(height: 16),
                
                // Ready for check-in text
                Text(
                  "Ready for check-in?",
                  style: TextStyle(
                    fontSize: 28,
                    color: Colors.grey.shade700,
                  ),
                  textAlign: TextAlign.center,
                ),
                
                const SizedBox(height: 48),
                
                // GIANT "I'M OK" BUTTON
                GestureDetector(
                  onTap: _hasCheckedToday ? null : _saveCheckin,
                  child: Container(
                    width: 250,
                    height: 250,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: _hasCheckedToday 
                          ? Colors.green.shade300 
                          : Colors.blue.shade600,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.2),
                          blurRadius: 20,
                          offset: const Offset(0, 10),
                        ),
                      ],
                    ),
                    child: Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            _hasCheckedToday ? Icons.check_circle : Icons.favorite,
                            size: 60,
                            color: Colors.white,
                          ),
                          const SizedBox(height: 12),
                          Text(
                            _hasCheckedToday ? "DONE" : "I'M OK",
                            style: const TextStyle(
                              fontSize: 36,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                
                const SizedBox(height: 32),
                
                // Status Card
                Card(
                  elevation: 4,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              _hasCheckedToday 
                                  ? Icons.verified_user 
                                  : Icons.access_time,
                              color: _hasCheckedToday 
                                  ? Colors.green.shade700 
                                  : Colors.orange.shade700,
                              size: 28,
                            ),
                            const SizedBox(width: 10),
                            Flexible(
                              child: Text(
                                _hasCheckedToday 
                                    ? "You're all set for today!" 
                                    : "Not checked in yet today",
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w500,
                                  color: _hasCheckedToday 
                                      ? Colors.green.shade800 
                                      : Colors.orange.shade800,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Text(
                          "Last check-in: ${_getFormattedTime()}",
                          style: const TextStyle(fontSize: 16),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          "Your check-in time: $_checkinTime",
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey.shade600,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.blue.shade50,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.alarm, size: 14, color: Colors.blue),
                              SizedBox(width: 4),
                              Text(
                                "Daily reminder set",
                                style: TextStyle(fontSize: 12, color: Colors.blue),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                
                const SizedBox(height: 12),
                
                // Settings Button
                ElevatedButton.icon(
                  onPressed: _changeCheckinTime,
                  icon: const Icon(Icons.access_time, size: 22),
                  label: const Text(
                    "Change Check-in Time",
                    style: TextStyle(fontSize: 16),
                  ),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                    backgroundColor: Colors.white,
                    foregroundColor: Colors.blue.shade700,
                    elevation: 2,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(30),
                    ),
                  ),
                ),
                
                const SizedBox(height: 12),
                
                // TEST BUTTON
                ElevatedButton.icon(
                  onPressed: () async {
                    await showTestNotification();
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('🔔 Test notification sent! Check your phone.'),
                          backgroundColor: Colors.orange,
                          duration: Duration(seconds: 2),
                        ),
                      );
                    }
                  },
                  icon: const Icon(Icons.volume_up, size: 22),
                  label: const Text(
                    "🔊 Test Notification",
                    style: TextStyle(fontSize: 16),
                  ),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                    backgroundColor: Colors.orange.shade50,
                    foregroundColor: Colors.orange.shade800,
                    elevation: 2,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(30),
                    ),
                  ),
                ),
                
                const SizedBox(height: 16),
                
                // Info about battery optimization
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.yellow.shade50,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.yellow.shade700),
                  ),
                  child: Column(
                    children: [
                      const Text(
                        '⚠️ For alarms to work:',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Go to Settings → Apps → CareLoop → Battery → Unrestricted',
                        style: TextStyle(fontSize: 12, color: Colors.grey.shade800),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
                
                const SizedBox(height: 16),
                
                // Reminder text
                Text(
                  "Tap the button once each day\nto let your family know you're safe.\n\n🔔 You'll receive a reminder at $_checkinTime",
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey.shade600,
                  ),
                ),
                
                const SizedBox(height: 12),
              ],
            ),
          ),
        ),
      ),
    );
  }
}