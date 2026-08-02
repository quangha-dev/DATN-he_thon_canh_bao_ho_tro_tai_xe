import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:geolocator/geolocator.dart';
import 'package:speech_to_text/speech_to_text.dart';
import 'package:speech_to_text/speech_recognition_result.dart';

import '../../app.dart';
import '../../core/widgets/ui.dart';

class AgentVoiceSheet extends ConsumerStatefulWidget {
  const AgentVoiceSheet({this.tripId, super.key});

  final int? tripId;

  @override
  ConsumerState<AgentVoiceSheet> createState() => _AgentVoiceSheetState();
}

class _AgentVoiceSheetState extends ConsumerState<AgentVoiceSheet> {
  final _controller = TextEditingController();
  final _speech = SpeechToText();
  final _tts = FlutterTts();
  bool _busy = false;
  bool _listening = false;
  String? _speechError;

  @override
  void dispose() {
    _speech.cancel();
    _tts.stop();
    _controller.dispose();
    super.dispose();
  }

  Future<void> _toggleListening() async {
    if (_listening) {
      await _speech.stop();
      if (mounted) setState(() => _listening = false);
      return;
    }
    final available = await _speech.initialize(
      onStatus: (status) {
        if (!mounted) return;
        setState(() => _listening = status == 'listening');
      },
      onError: (error) {
        if (!mounted) return;
        setState(() {
          _speechError = error.errorMsg;
          _listening = false;
        });
      },
    );
    if (!available) {
      if (mounted) {
        setState(
          () => _speechError = 'Thiết bị chưa hỗ trợ nhận dạng giọng nói.',
        );
      }
      return;
    }
    setState(() {
      _speechError = null;
      _listening = true;
    });
    await _speech.listen(
      onResult: _onSpeechResult,
      listenOptions: SpeechListenOptions(
        localeId: 'vi_VN',
        listenFor: const Duration(seconds: 15),
        pauseFor: const Duration(seconds: 3),
        listenMode: ListenMode.confirmation,
        partialResults: true,
        cancelOnError: true,
      ),
    );
  }

  void _onSpeechResult(SpeechRecognitionResult result) {
    if (!mounted) return;
    setState(() {
      _controller.text = result.recognizedWords;
      _controller.selection = TextSelection.collapsed(
        offset: _controller.text.length,
      );
    });
    if (result.finalResult && result.recognizedWords.trim().isNotEmpty) {
      _submit();
    }
  }

  Future<void> _speak(String text) async {
    await _tts.setLanguage('vi-VN');
    await _tts.setSpeechRate(0.48);
    await _tts.speak(text);
  }

  Future<void> _submit() async {
    final transcript = _controller.text.trim();
    if (transcript.isEmpty || _busy) return;
    await _speech.stop();
    setState(() {
      _busy = true;
      _listening = false;
    });
    try {
      final response = await ref
          .read(driverRepositoryProvider)
          .agentCommand(transcript, tripId: widget.tripId);
      if (!mounted) return;
      await _speak(_message(response));
      if (response['requiresConfirmation'] == true) {
        await _confirm(response);
      } else {
        _showResult(response);
      }
    } catch (error) {
      if (mounted) showError(context, error);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _confirm(Map<String, dynamic> command) async {
    final accepted = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        icon: Icon(
          command['intent'] == 'SEND_SOS' ? Icons.sos : Icons.security,
          color: command['intent'] == 'SEND_SOS'
              ? SfColors.danger
              : SfColors.teal,
        ),
        title: const Text('Xác nhận trước khi thực hiện'),
        content: Text(_confirmationText(command['intent']?.toString())),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Hủy lệnh'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Xác nhận'),
          ),
        ],
      ),
    );
    final id = (command['id'] as num).toInt();
    if (accepted != true) {
      await ref.read(driverRepositoryProvider).cancelAgentCommand(id);
      if (mounted) Navigator.pop(context);
      return;
    }

    Position? position;
    final intent = command['intent']?.toString();
    if (intent == 'SEND_SOS' || intent == 'REPORT_FLOOD') {
      position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.best,
        ),
      );
    }
    final response = await ref
        .read(driverRepositoryProvider)
        .confirmAgentCommand(
          id,
          latitude: position?.latitude,
          longitude: position?.longitude,
          floodSeverity: intent == 'REPORT_FLOOD' ? 'MEDIUM' : null,
          description: _controller.text.trim(),
        );
    if (!mounted) return;
    await _speak(_message(response));
    _showResult(response);
  }

  String _message(Map<String, dynamic> response) =>
      response['responseText']?.toString() ??
      response['status']?.toString() ??
      'Đã xử lý yêu cầu';

  String _confirmationText(String? intent) => switch (intent) {
    'SEND_SOS' =>
      'Gửi SOS cùng vị trí hiện tại tới trung tâm điều phối ngay bây giờ?',
    'REPORT_FLOOD' =>
      'Gửi báo cáo ngập cùng vị trí hiện tại tới trung tâm điều phối?',
    'START_TRIP' => 'Bắt đầu chuyến đi hiện tại?',
    'PAUSE_TRIP' => 'Tạm dừng chuyến đi đang chạy?',
    'RESUME_TRIP' => 'Tiếp tục chuyến đi đang tạm dừng?',
    'COMPLETE_TRIP' => 'Hoàn thành chuyến đi hiện tại?',
    _ => 'Thực hiện thao tác vừa nhận dạng?',
  };

  void _showResult(Map<String, dynamic> response) {
    if (!mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    Navigator.pop(context);
    messenger.showSnackBar(SnackBar(content: Text(_message(response))));
  }

  @override
  Widget build(BuildContext context) => Padding(
    padding: EdgeInsets.fromLTRB(
      20,
      8,
      20,
      MediaQuery.viewInsetsOf(context).bottom + 24,
    ),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Trợ lý SafeFleet',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900),
        ),
        const SizedBox(height: 6),
        Text(
          _listening
              ? 'Đang nghe… Hãy nói ngắn gọn yêu cầu của bạn.'
              : 'Nói hoặc nhập: SOS, báo ngập, bắt đầu/tạm dừng chuyến, đọc cảnh báo.',
          style: const TextStyle(color: SfColors.textSecondary),
        ),
        const SizedBox(height: 16),
        TextField(
          controller: _controller,
          autofocus: false,
          minLines: 1,
          maxLines: 3,
          textInputAction: TextInputAction.send,
          onSubmitted: (_) => _submit(),
          decoration: InputDecoration(
            hintText: 'Ví dụ: Tôi cần SOS cứu hộ',
            prefixIcon: IconButton(
              tooltip: _listening ? 'Dừng nghe' : 'Ra lệnh bằng giọng nói',
              onPressed: _busy ? null : _toggleListening,
              icon: Icon(_listening ? Icons.stop_circle : Icons.mic),
              color: _listening ? SfColors.danger : null,
            ),
          ),
        ),
        if (_speechError != null) ...[
          const SizedBox(height: 8),
          Text(
            _speechError!,
            style: const TextStyle(color: SfColors.danger, fontSize: 12),
          ),
        ],
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          child: FilledButton.icon(
            onPressed: _busy ? null : _submit,
            icon: _busy
                ? const SizedBox.square(
                    dimension: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.arrow_upward),
            label: Text(_busy ? 'Đang xử lý…' : 'Gửi lệnh'),
          ),
        ),
      ],
    ),
  );
}
