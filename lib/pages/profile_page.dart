import 'package:material_ui/material_ui.dart';

import '../services/barangay_service.dart';
import '../widgets/konami.dart';

/// Profile tab: shows the barangays the user has marked as "seen"
/// along with their notes, plus a Konami-code unlock pad.
class ProfilePage extends StatefulWidget {
  final KonamiController konami;

  const ProfilePage({super.key, required this.konami});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  final BarangayService _service = BarangayService();
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    await _service.load();
    if (!mounted) return;
    setState(() => _loading = false);
  }

  @override
  void dispose() {
    _service.barangays.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SizedBox(width: 160, child: LinearProgressIndicator()),
            SizedBox(height: 16),
            Text('Loading profile...'),
          ],
        ),
      );
    }

    final seen = _service.seenList;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const Center(
          child: Icon(Icons.person_2_outlined, size: 48),
        ),
        const SizedBox(height: 8),
        const Center(
          child: Text(
            'John Doe',
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          ),
        ),
        const SizedBox(height: 24),
        Text(
          'Seen Barangays (${seen.length})',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 8),
        if (seen.isEmpty)
          const Card(
            child: Padding(
              padding: EdgeInsets.all(16),
              child: Text(
                'No barangays marked as seen yet. Open the Barangays tab '
                'and tap a highlighted barangay to mark it seen.',
                style: TextStyle(color: Colors.grey),
              ),
            ),
          )
        else
          ...seen.map((b) => Card(
                child: ListTile(
                  leading: const Icon(Icons.check_circle, color: Colors.green),
                  title: Text(b.name),
                  subtitle: b.note != null && b.note!.isNotEmpty
                      ? Text(b.note!)
                      : Text(b.city, style: const TextStyle(fontSize: 12)),
                ),
              )),
        const SizedBox(height: 24),
        // Konami unlock pad.
        const Text('Konami unlock', style: TextStyle(fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _padButton(Icons.arrow_upward, () => widget.konami.add('up')),
            const SizedBox(width: 8),
            _padButton(Icons.arrow_downward, () => widget.konami.add('down')),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _padButton(Icons.arrow_back, () => widget.konami.add('left')),
            const SizedBox(width: 8),
            _padButton(Icons.circle, () => widget.konami.add('start')),
            const SizedBox(width: 8),
            _padButton(Icons.arrow_forward, () => widget.konami.add('right')),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _padButton(Icons.refresh, () => widget.konami.add('a')),
            const SizedBox(width: 8),
            _padButton(Icons.refresh, () => widget.konami.add('b')),
          ],
        ),
      ],
    );
  }

  Widget _padButton(IconData icon, VoidCallback onPressed) {
    return SizedBox(
      width: 56,
      height: 56,
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          shape: const CircleBorder(),
          padding: EdgeInsets.zero,
        ),
        child: Icon(icon),
      ),
    );
  }
}
