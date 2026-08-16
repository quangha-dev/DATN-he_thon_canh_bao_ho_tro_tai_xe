import 'dart:io';

import 'package:flutter/material.dart';

import '../../core/design/tokens.dart';
import 'driving_log_entry.dart';

class DocumentImageScreen extends StatefulWidget {
  const DocumentImageScreen({required this.entry, super.key});

  final DrivingLogEntry entry;

  @override
  State<DocumentImageScreen> createState() => _DocumentImageScreenState();
}

class _DocumentImageScreenState extends State<DocumentImageScreen> {
  var _showOriginal = false;

  @override
  Widget build(BuildContext context) {
    final path = _showOriginal
        ? widget.entry.originalImagePath
        : widget.entry.imagePath;
    return Scaffold(
      backgroundColor: SfColors.darkBg,
      appBar: AppBar(
        backgroundColor: SfColors.darkBg,
        foregroundColor: SfColors.darkTextPrimary,
        title: Text(_showOriginal ? 'Ảnh chụp ban đầu' : 'Phiếu đã scan'),
        actions: [
          TextButton.icon(
            onPressed: () => setState(() => _showOriginal = !_showOriginal),
            icon: Icon(
              _showOriginal ? Icons.document_scanner_outlined : Icons.photo,
              color: SfColors.mint,
            ),
            label: Text(
              _showOriginal ? 'Xem bản scan' : 'Xem ảnh gốc',
              style: SfType.meta.copyWith(color: SfColors.mint),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: InteractiveViewer(
          minScale: 0.5,
          maxScale: 5,
          child: Center(
            child: File(path).existsSync()
                ? Image.file(File(path), fit: BoxFit.contain)
                : Text(
                    'Không tìm thấy ảnh phiếu trên thiết bị.',
                    style: SfType.body.copyWith(
                      color: SfColors.darkTextSecondary,
                    ),
                  ),
          ),
        ),
      ),
    );
  }
}
