import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shorebird_code_push/shorebird_code_push.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Demo',
      theme: ThemeData(
        // This is the theme of your application.
        //
        // TRY THIS: Try running your application with "flutter run". You'll see
        // the application has a purple toolbar. Then, without quitting the app,
        // try changing the seedColor in the colorScheme below to Colors.blueAccent
        // and then invoke "hot reload" (save your changes or press the "hot
        // reload" button in a Flutter-supported IDE, or press "r" if you used
        // the command line to start the app).
        //
        // Notice that the counter didn't reset back to zero; the application
        // state is not lost during the reload. To reset the state, use hot
        // restart instead.
        //
        // This works for code too, not just values: Most code changes can be
        // tested with just a hot reload.
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.redAccent),
      ),
      home: const MyHomePage(title: 'Flutter Demo shorebird'),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key, required this.title});

  // This widget is the home page of your application. It is stateful, meaning
  // that it has a State object (defined below) that contains fields that affect
  // how it looks.

  // This class is the configuration for the state. It holds the values (in this
  // case the title) provided by the parent (in this case the App widget) and
  // used by the build method of the State. Fields in a Widget subclass are
  // always marked "final".

  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  // Create an instance of the updater class
  final updater = ShorebirdUpdater();

  @override
  void initState() {
    super.initState();

    // Get the current patch number and print it to the console.
    // It will be `null` if no patches are installed.
    updater.readCurrentPatch().then((currentPatch) {
      print('The current patch number is: ${currentPatch?.number}');
    });
  }

  Future<void> _checkForUpdates(BuildContext context) async {
    final status = await updater.checkForUpdate();

    switch (status) {
      case UpdateStatus.upToDate:
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text("✅ Aplikasi sudah versi terbaru.")));
        break;

      case UpdateStatus.outdated:
        showDialog(
          context: context,
          builder:
              (context) => AlertDialog(
                title: Text("🔔 Pembaruan Tersedia"),
                content: Text("Versi terbaru aplikasi tersedia. Ingin memperbarui sekarang?"),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(context), // Tutup dialog
                    child: Text("Nanti"),
                  ),
                  ElevatedButton(
                    onPressed: () async {
                      Navigator.pop(context); // Tutup dialog konfirmasi

                      // Tampilkan dialog loading

                      try {
                        await updater.update();
                        Navigator.pop(context); // Tutup dialog loading

                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            action: SnackBarAction(
                              label: "restart",
                              onPressed: () async {
                                await Restart.restartApp(notificationTitle: 'Restarting App');
                              },
                            ),
                            content: Text("✅ Update berhasil diinstal. Merestart..."),
                          ),
                        );

                        // Restart aplikasi
                      } on UpdateException catch (error) {
                        Navigator.pop(context); // Tutup dialog loading jika gagal
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text("❌ Gagal update: ${error.toString()}")),
                        );
                      }
                    },
                    child: Text("Update Sekarang"),
                  ),
                ],
              ),
        );
        break;

      case UpdateStatus.restartRequired:
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text("♻️ Restart aplikasi diperlukan...")));
        // Restart aplikasi
        await Restart.restartApp(notificationTitle: 'Restarting App');
        break;

      default:
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text("⚠️ Status tidak dikenali: $status")));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Pembaruan Aplikasi"),
        centerTitle: true,
        backgroundColor: Colors.blueAccent,
      ),
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.system_update, color: Colors.blueAccent, size: 80),
            SizedBox(height: 16),
            Text("Cek Pembaruan", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            SizedBox(height: 8),
            Text(
              "versi aplikasi ${updater.readCurrentPatch().then((currentPatch) {
                print('The current patch number is: ${currentPatch?.number}');
              })}",
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey[700]),
            ),
            SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () => _checkForUpdates(context),
              icon: Icon(Icons.update),
              label: Text("Cek untuk Update"),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blueAccent,
                padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                textStyle: TextStyle(fontSize: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class Restart {
  /// A private constant `MethodChannel`. This channel is used to communicate with the
  /// platform-specific code to perform the restart operation.
  static const MethodChannel _channel = const MethodChannel('restart');

  /// Restarts the Flutter application.
  ///
  /// The `webOrigin` parameter is optional. If it's null, the method uses the `window.origin`
  /// to get the site origin. This parameter should only be filled when your current origin
  /// is different than the app's origin. It defaults to null.
  ///
  /// The `customMessage` parameter is optional. It allows customization of the notification
  /// message displayed on iOS when restarting the app. If not provided, a default message
  /// will be used.
  ///
  /// This method communicates with the platform-specific code to perform the restart operation,
  /// and then checks the response. If the response is "ok", it returns true, signifying that
  /// the restart operation was successful. Otherwise, it returns false.
  static Future<bool> restartApp({
    String? webOrigin,
    String? notificationTitle,
    String? notificationBody,
  }) async {
    final Map<String, dynamic> args = {
      'webOrigin': webOrigin,
      'notificationTitle': notificationTitle,
      'notificationBody': notificationBody,
    };
    return (await _channel.invokeMethod('restartApp', args)) == "ok";
  }
}
