import 'package:flutter/material.dart';
import 'services/socket_service.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SocketService.instance.connect();
  runApp(const ElectricoApp());
}

class ElectricoApp extends StatelessWidget {
  const ElectricoApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Electrico',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFFF5A623)),
        useMaterial3: true,
      ),
      home: const _HomePage(),
    );
  }
}

class _HomePage extends StatelessWidget {
  const _HomePage();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Electrico'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: const Center(
        child: Text(
          'Bienvenido a Electrico',
          style: TextStyle(fontSize: 24),
        ),
      ),
    );
  }
}
