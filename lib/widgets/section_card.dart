import 'package:flutter/material.dart';

/// A catalog card: title + description + live demo + code sample.
class SectionCard extends StatelessWidget {
  final String title;
  final String description;
  final String code;
  final Widget child;

  const SectionCard({
    super.key,
    required this.title,
    required this.description,
    required this.code,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title,
                style:
                    const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            Text(description, style: const TextStyle(fontSize: 13)),
            const SizedBox(height: 8),
            child,
            const SizedBox(height: 8),
            const Text('How to use:',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            CodeBlock(code: code),
          ],
        ),
      ),
    );
  }
}

/// Dark monospace box for showing a short usage example.
class CodeBlock extends StatelessWidget {
  final String code;

  const CodeBlock({super.key, required this.code});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.grey.shade900,
        borderRadius: BorderRadius.circular(8),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Text(code,
            style: const TextStyle(fontSize: 12, color: Colors.white)),
      ),
    );
  }
}
