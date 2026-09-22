import 'package:flutter/material.dart';
import '../core/theme/app_colors.dart';

/// Static awareness content about elder rights and family responsibilities.
class AwarenessScreen extends StatelessWidget {
  const AwarenessScreen({super.key});

  @override
  Widget build(BuildContext context) {
    const items = [
      (
      Icons.gavel_outlined,
      'Children have a duty to care for their parents',
      'Under the Parents Maintenance Act, 2013 (পিতা-মাতার ভরণপোষণ আইন), children are legally responsible '
          'for supporting their parents. Neglect is not just a family matter - it is a legal responsibility.'
      ),
      (
      Icons.report_gmailerrorred_outlined,
      'What counts as neglect?',
      'Not providing food, shelter, medicine or medical care, refusing financial support, abandoning a parent, '
          'or causing physical or emotional harm.'
      ),
      (
      Icons.shield_outlined,
      'You are not alone',
      'Many elderly people stay silent to protect their family\'s reputation. Shomman lets you ask for help '
          'privately, and reports can be submitted anonymously.'
      ),
      (
      Icons.groups_outlined,
      'Neighbors and relatives can help',
      'If you notice an elderly person who looks unwell, hungry or lonely, you can report on their behalf. '
          'A welfare officer will verify the case and follow up respectfully.'
      ),
      (
      Icons.sos,
      'In an emergency',
      'If someone is in immediate danger, use the SOS button and call 999.'
      ),
    ];
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('Know your rights')),
      body: SafeArea(
        child: Center(
          child: ListView(
            padding: const EdgeInsets.all(14),
            children: [
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 640),
                child: Column(children: [
                  for (final i in items)
                    Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                                color: AppColors.primary.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(10)),
                            child: Icon(i.$1, color: AppColors.primary, size: 22),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                              Text(i.$2, style: Theme.of(context).textTheme.titleMedium),
                              const SizedBox(height: 6),
                              Text(i.$3, style: const TextStyle(color: AppColors.textSecondary, height: 1.45)),
                            ]),
                          ),
                        ]),
                      ),
                    ),
                  const Padding(
                    padding: EdgeInsets.all(8),
                    child: Text(
                      'This is general information, not legal advice.',
                      style: TextStyle(color: AppColors.textTertiary, fontSize: 12),
                    ),
                  ),
                ]),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
