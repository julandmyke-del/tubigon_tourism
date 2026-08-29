import 'package:flutter/material.dart';

class PortalCapabilityNoticePage extends StatelessWidget {
  const PortalCapabilityNoticePage({
    super.key,
    required this.title,
    required this.message,
  });

  final String title;
  final String message;

  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: const Color(0xFF0B132B),
        body: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.info_outline_rounded,
                      size: 52, color: Color(0xFFF59E0B)),
                  const SizedBox(height: 16),
                  Text(title,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 22,
                          fontWeight: FontWeight.w800)),
                  const SizedBox(height: 10),
                  Text(message,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                          color: Color(0xFFCBD5E1), height: 1.5)),
                ],
              ),
            ),
          ),
        ),
      );
}
