import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'menu_design.dart';

/// The same bundled text is used to generate the public policy page.
class PrivacyPolicyPage extends StatefulWidget {
  const PrivacyPolicyPage({super.key});

  @override
  State<PrivacyPolicyPage> createState() => _PrivacyPolicyPageState();
}

class _PrivacyPolicyPageState extends State<PrivacyPolicyPage> {
  late final Future<Map<String, dynamic>> policy = rootBundle
      .loadString('assets/privacy/policy.json')
      .then((text) => jsonDecode(text) as Map<String, dynamic>);

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: menuBackground,
    body: SafeArea(
      child: MenuSurface(
        child: FutureBuilder<Map<String, dynamic>>(
          future: policy,
          builder: (context, snapshot) => SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(22, 10, 22, 24),
            child: SelectionArea(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  MenuHeading(
                    'Privacy Policy',
                    trailing: MenuIconButton(
                      icon: Icons.close,
                      tooltip: 'Close privacy policy',
                      onPressed: () => Navigator.pop(context),
                    ),
                  ),
                  if (snapshot.hasError)
                    const Text(
                      'The privacy policy could not be loaded. Please reopen this page.',
                    )
                  else if (!snapshot.hasData)
                    const Center(child: CircularProgressIndicator())
                  else ...[
                    Text(
                      'Updated ${snapshot.data!['updated']}',
                      style: const TextStyle(color: menuMuted, fontSize: 12),
                    ),
                    if ((snapshot.data!['publisher'] as String).isNotEmpty)
                      Text('Publisher: ${snapshot.data!['publisher']}'),
                    for (final section in snapshot.data!['sections'] as List)
                      Padding(
                        padding: const EdgeInsets.only(top: 22),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              section['title'] as String,
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(section['body'] as String),
                          ],
                        ),
                      ),
                    if ((snapshot.data!['contactEmail'] as String)
                        .isNotEmpty) ...[
                      const SizedBox(height: 22),
                      const Text(
                        'Privacy contact',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      Text(snapshot.data!['contactEmail'] as String),
                    ],
                    const SizedBox(height: 22),
                    const Text(
                      'Learn more',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    for (final reference
                        in snapshot.data!['references'] as List)
                      Padding(
                        padding: const EdgeInsets.only(top: 12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(reference['title'] as String),
                            Text(
                              reference['url'] as String,
                              style: const TextStyle(color: menuMint),
                            ),
                            TextButton.icon(
                              onPressed: () async {
                                try {
                                  await Clipboard.setData(
                                    ClipboardData(
                                      text: reference['url'] as String,
                                    ),
                                  );
                                  if (context.mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text('Link copied'),
                                      ),
                                    );
                                  }
                                } catch (_) {
                                  if (context.mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text(
                                          'Could not copy the link. You can select the address above.',
                                        ),
                                      ),
                                    );
                                  }
                                }
                              },
                              icon: const Icon(Icons.copy_outlined, size: 16),
                              label: const Text('Copy link'),
                            ),
                          ],
                        ),
                      ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    ),
  );
}
