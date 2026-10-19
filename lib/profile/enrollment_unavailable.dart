import 'package:flutter/material.dart';

/// Shown when enrollment services are unavailable; counts remain unknown.
class EnrollmentSummaryUnavailable extends StatelessWidget {
  const EnrollmentSummaryUnavailable({super.key});

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Wrap(
        spacing: 12,
        runSpacing: 8,
        children: [
          for (final label in ['Courses Enrolled', 'In Progress', 'Completed'])
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: const Color(0xFFF0F3FF),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                '$label: —',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
        ],
      ),
      const SizedBox(height: 8),
      const Text(
        'Enrollment data is unavailable.',
        style: TextStyle(fontSize: 12, color: Color(0xFF584237)),
      ),
    ],
  );
}

class EnrollmentUnavailable extends StatelessWidget {
  const EnrollmentUnavailable({super.key});

  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.only(top: 24),
    padding: const EdgeInsets.all(20),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(20),
    ),
    child: const Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Enrolled Courses',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
        ),
        SizedBox(height: 16),
        EnrollmentSummaryUnavailable(),
        SizedBox(height: 24),
        Icon(Icons.menu_book_outlined, size: 40, color: Color(0xFF9D4300)),
        SizedBox(height: 12),
        Text(
          'Enrolled courses unavailable',
          textAlign: TextAlign.center,
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
        SizedBox(height: 8),
        Text(
          'Enrollment services are not connected in this view. Your course progress cannot be loaded.',
          textAlign: TextAlign.center,
          style: TextStyle(color: Color(0xFF584237), height: 1.5),
        ),
      ],
    ),
  );
}
