import 'package:flutter/material.dart';

/// Pastel canvas with a quiet HomeShare wordmark behind admin page content.
class AdminPageBackdrop extends StatelessWidget {
  final Widget child;

  const AdminPageBackdrop({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        const ColoredBox(color: Color(0xFFF4F9FF)),
        const Positioned(
          right: 22,
          bottom: 18,
          child: IgnorePointer(
            child: Opacity(
              opacity: .5,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.home_work_rounded,
                    size: 72,
                    color: Color(0xFFD6EDF9),
                  ),
                  SizedBox(width: 7),
                  Text(
                    'HomeShare',
                    style: TextStyle(
                      color: Color(0xFFD6EDF9),
                      fontSize: 23,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -.5,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1500),
            child: child,
          ),
        ),
      ],
    );
  }
}
