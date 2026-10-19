import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../../../core/constants/app_colors.dart';

class UserAvatar extends StatelessWidget {
  const UserAvatar({
    super.key,
    required this.name,
    this.imageUrl = '',
    this.localBytes,
    this.radius = 32,
  });

  final String name;
  final String imageUrl;
  final Uint8List? localBytes;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final initial = name.trim().isEmpty ? 'U' : name.trim()[0].toUpperCase();
    final provider = _imageProvider();

    return CircleAvatar(
      radius: radius,
      backgroundColor: AppColors.primaryContainer,
      backgroundImage: provider,
      child: provider == null
          ? Text(
              initial,
              style: TextStyle(
                fontSize: radius * 0.7,
                fontWeight: FontWeight.bold,
                color: AppColors.primary,
              ),
            )
          : null,
    );
  }

  ImageProvider? _imageProvider() {
    if (localBytes != null && localBytes!.isNotEmpty) {
      return MemoryImage(localBytes!);
    }
    final url = imageUrl.trim();
    if (url.startsWith('http://') || url.startsWith('https://')) return NetworkImage(url);
    return null;
  }
}
