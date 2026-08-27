import 'dart:io';

import 'package:flutter/material.dart';

import '../../core/widgets/ui.dart';
import 'driving_log_entry.dart';

/// Xem ảnh phiếu / ảnh hiện trường.
///
/// Nền gần như đen để ảnh là thứ duy nhất sáng trên màn; watermark góc dưới
/// ghi lại bối cảnh chụp để ảnh vẫn có giá trị đối chứng khi tách khỏi app.
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

    return SfTheme.darkWrap(
      child: Scaffold(
        backgroundColor: SfColors.photoBg,
        body: SafeArea(
          child: Column(
            children: [
              _header(),
              Expanded(
                child: Stack(
                  children: [
                    Positioned.fill(
                      child: InteractiveViewer(
                        minScale: 0.5,
                        maxScale: 5,
                        child: Center(
                          child: File(path).existsSync()
                              ? Image.file(File(path), fit: BoxFit.contain)
                              : Text(
                                  'Không tìm thấy ảnh phiếu trên thiết bị.',
                                  style: SfType.bodySm.copyWith(
                                    color: SfColors.darkTextMuted,
                                  ),
                                ),
                        ),
                      ),
                    ),
                    Positioned(
                      left: SfSpace.x16,
                      right: SfSpace.x16,
                      bottom: SfSpace.x16,
                      child: _watermark(),
                    ),
                  ],
                ),
              ),
              _bottomBar(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _header() => Padding(
    padding: const EdgeInsets.all(SfSpace.x12),
    child: Row(
      children: [
        SfIconButton(
          icon: Icons.arrow_back_rounded,
          onDark: true,
          tooltip: 'Quay lại',
          onTap: () => Navigator.of(context).maybePop(),
        ),
        const SizedBox(width: SfSpace.x12),
        Expanded(
          child: Text(
            _showOriginal ? 'Ảnh chụp ban đầu' : 'Phiếu đã scan',
            style: SfType.titleSub.copyWith(color: SfColors.darkTextPrimary),
          ),
        ),
      ],
    ),
  );

  /// Watermark bối cảnh chụp ở góc dưới ảnh.
  Widget _watermark() {
    final captured = widget.entry.createdAt;
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: SfSpace.x12,
        vertical: SfSpace.x10,
      ),
      decoration: BoxDecoration(
        color: SfColors.photoBg.withValues(alpha: 0.72),
        borderRadius: SfRadius.cardSmR,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            widget.entry.projectAddress.isEmpty
                ? 'Phiếu ${widget.entry.voucherNumber}'
                : widget.entry.projectAddress,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: SfType.titleRow.copyWith(color: SfColors.darkTextPrimary),
          ),
          const SizedBox(height: 2),
          Text(
            '${captured.day.toString().padLeft(2, '0')}/'
            '${captured.month.toString().padLeft(2, '0')}/${captured.year} · '
            '${captured.hour.toString().padLeft(2, '0')}:'
            '${captured.minute.toString().padLeft(2, '0')}',
            style: SfType.caption.copyWith(color: SfColors.green400),
          ),
        ],
      ),
    );
  }

  Widget _bottomBar() => Padding(
    padding: const EdgeInsets.fromLTRB(
      SfSpace.x16,
      SfSpace.x8,
      SfSpace.x16,
      SfSpace.x16,
    ),
    child: Row(
      children: [
        Expanded(
          child: SfPressable(
            onTap: () => setState(() => _showOriginal = !_showOriginal),
            child: Container(
              height: SfTouch.primaryHeight,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: SfColors.darkSurface,
                borderRadius: SfRadius.controlLgR,
                border: Border.all(color: SfColors.darkBorder),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    _showOriginal
                        ? Icons.document_scanner_rounded
                        : Icons.photo_rounded,
                    size: 20,
                    color: SfColors.green400,
                  ),
                  const SizedBox(width: SfSpace.x8),
                  Text(
                    _showOriginal ? 'Xem bản scan' : 'Xem ảnh gốc',
                    style: SfType.titleCardSm.copyWith(
                      color: SfColors.darkTextPrimary,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    ),
  );
}
