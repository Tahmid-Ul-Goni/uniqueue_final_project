import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../../../app/app_colors.dart';
import '../../../models/queue_entry.dart';
import '../../../services/queue_service.dart';

class QrScanScreen extends StatefulWidget {
  const QrScanScreen({
    required this.departmentId,
    required this.serviceId,
    required this.staffId,
    required this.queueRepository,
    super.key,
  });

  final String departmentId;
  final String serviceId;
  final String staffId;
  final QueueServiceRepository queueRepository;

  @override
  State<QrScanScreen> createState() => _QrScanScreenState();
}

class _QrScanScreenState extends State<QrScanScreen> {
  final _controller = MobileScannerController();
  bool _processing = false;
  String? _error;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _onDetect(BarcodeCapture capture) async {
    if (_processing) return;
    final value = capture.barcodes.firstOrNull?.rawValue;
    if (value == null || value.isEmpty) return;
    setState(() {
      _processing = true;
      _error = null;
    });
    await _controller.stop();

    try {
      final entry = await widget.queueRepository.validateQrPayload(
        value,
        departmentId: widget.departmentId,
        serviceId: widget.serviceId,
      );
      if (!mounted) return;
      await _showValidToken(entry);
    } on QueueFailure catch (error) {
      if (!mounted) return;
      await _showScanIssue(error.message);
      if (!mounted) return;
      setState(() => _processing = false);
      await _controller.start();
    } catch (_) {
      if (!mounted) return;
      await _showScanIssue(
        'Could not read the token. Ask the student to open their latest QR code.',
      );
      if (!mounted) return;
      setState(() => _processing = false);
      await _controller.start();
    }
  }

  Future<void> _showScanIssue(String reason) async {
    final lower = reason.toLowerCase();
    final title = lower.contains('different counter')
        ? 'Wrong department'
        : lower.contains('already been used')
            ? 'Already used'
            : lower.contains('expired') || lower.contains('grace period')
                ? 'Expired'
                : 'Invalid token';
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.surface,
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Icon(Icons.error_outline_rounded,
                  color: AppColors.error, size: 40),
              const SizedBox(height: 12),
              Text(title,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                      fontSize: 20, fontWeight: FontWeight.w700)),
              const SizedBox(height: 8),
              Text(reason,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: AppColors.textSecondary)),
              const SizedBox(height: 20),
              FilledButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Scan again'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _showValidToken(QueueEntry entry) async {
    final start = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Icon(Icons.check_circle_outline_rounded,
                  color: AppColors.success, size: 40),
              const SizedBox(height: 12),
              const Text('Valid token',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
              const SizedBox(height: 8),
              Text(entry.tokenCode,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                      color: AppColors.primary,
                      fontSize: 28,
                      fontWeight: FontWeight.w800)),
              const SizedBox(height: 4),
              Text(entry.studentFirstName,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: AppColors.textSecondary)),
              const SizedBox(height: 20),
              SizedBox(
                height: 52,
                child: FilledButton(
                  onPressed: () => Navigator.pop(context, true),
                  style: FilledButton.styleFrom(
                      backgroundColor: AppColors.primary),
                  child: const Text('Start Service'),
                ),
              ),
              TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: const Text('Scan another')),
            ],
          ),
        ),
      ),
    );
    if (start == true) {
      try {
        await widget.queueRepository
            .transition(entry.id, QueueStatus.serving, staffId: widget.staffId);
        if (mounted) Navigator.pop(context, true);
      } on QueueFailure catch (error) {
        if (mounted) setState(() => _error = error.message);
      }
    }
    if (mounted) {
      setState(() => _processing = false);
      await _controller.start();
    }
  }

  Future<void> _scanAgain() async {
    setState(() {
      _error = null;
      _processing = false;
    });
    await _controller.start();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(
          title: const Text('Scan token'),
          actions: [
            IconButton(
              tooltip: 'Toggle flashlight',
              onPressed: () => _controller.toggleTorch(),
              icon: const Icon(Icons.flashlight_on_outlined),
            ),
          ],
        ),
        body: Stack(
          fit: StackFit.expand,
          children: [
            MobileScanner(
              controller: _controller,
              onDetect: _onDetect,
              errorBuilder: (context, error) => Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text(
                    error.errorCode == MobileScannerErrorCode.permissionDenied
                        ? 'Camera permission is needed to scan queue tokens.'
                        : 'Camera is unavailable. Check permissions and try again.',
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
            ),
            IgnorePointer(
              child: Center(
                child: Container(
                  width: 260,
                  height: 260,
                  decoration: BoxDecoration(
                    border: Border.all(color: AppColors.surface, width: 3),
                    borderRadius: BorderRadius.circular(24),
                  ),
                ),
              ),
            ),
            Positioned(
              left: 20,
              right: 20,
              bottom: 28,
              child: Column(
                children: [
                  if (_error != null)
                    Container(
                      padding: const EdgeInsets.all(14),
                      margin: const EdgeInsets.only(bottom: 12),
                      decoration: BoxDecoration(
                          color: AppColors.surface,
                          borderRadius: BorderRadius.circular(12)),
                      child: Column(
                        children: [
                          Text(_error!,
                              textAlign: TextAlign.center,
                              style: const TextStyle(color: AppColors.error)),
                          const SizedBox(height: 8),
                          TextButton(
                              onPressed: _scanAgain,
                              child: const Text('Scan again')),
                        ],
                      ),
                    )
                  else
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 12),
                      decoration: BoxDecoration(
                          color: AppColors.textPrimary.withValues(alpha: 0.85),
                          borderRadius: BorderRadius.circular(999)),
                      child: const Text('Align QR inside the frame',
                          style: TextStyle(color: AppColors.surface)),
                    ),
                ],
              ),
            ),
          ],
        ),
      );
}
