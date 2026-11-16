p = "lib/pages/admin_page.dart"
src = open(p, encoding="utf8").read()

# Add import after the first line
src = src.replace(
    "import 'package:flutter/material.dart';\n",
    "import 'package:flutter/material.dart';\n\nimport 'researcher_page.dart';\n",
    1,
)

# Insert a researcher button before the closing of the ListView children.
# Find the last occurrence of "const SizedBox(height: 16)," before the App info section
marker = "        const SizedBox(height: 16),\n\n        // ---- App info ----"
button = """        const SizedBox(height: 16),

        // ---- Researcher tools ----
        const Text('Researcher tools', style: TextStyle(fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        Card(
          child: ListTile(
            leading: const Icon(Icons.route),
            title: const Text('Record jeepney route'),
            subtitle: const Text(
              'Select a jeepney code and record GPS movement to build the '
              'route polyline for jeepney_routes.json.',
            ),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => const ResearcherPage(),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 16),

        // ---- App info ----"""
assert marker in src, "marker not found"
src = src.replace(marker, button, 1)

open(p, "w", encoding="utf8").write(src)
print("OK")