import 'package:flutter/material.dart';
class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }
  void _loadData() {
    setState(() => _loading = true);
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) setState(() => _loading = false);
    });
  }
  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            SizedBox(
              width: 160,
              child: LinearProgressIndicator(),
            ),
            SizedBox(height: 16),
            Text('Loading profile...'),
          ],
        ),
      );
    }
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.person_2_outlined, size: 48),
          const SizedBox(height: 8),
          const Text(
            'John Doe',
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          OutlinedButton(
            onPressed: _loadData,
            child: const Text('Reload'),
          ),
        ],
      ),
    );
  }
}