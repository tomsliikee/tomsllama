import 'package:flutter/scheduler.dart';

class SmoothStreamer {
  final StringBuffer _buffer = StringBuffer();
  String _displayedText = '';
  Ticker? _ticker;
  final void Function(String) onUpdate;
  
  SmoothStreamer({required this.onUpdate});

  void addText(String text) {
    _buffer.write(text);
    if (_ticker == null || !_ticker!.isTicking) {
      _startTicker();
    }
  }

  void setFullText(String text) {
    _buffer.clear();
    _buffer.write(text);
    _displayedText = text;
    onUpdate(_displayedText);
  }

  void _startTicker() {
    _ticker ??= Ticker((elapsed) {
      final target = _buffer.toString();
      if (_displayedText.length < target.length) {
        final backlog = target.length - _displayedText.length;
        // Dynamically adjust speed based on backlog to avoid falling too far behind
        final charsToTake = (backlog / 8).ceil().clamp(1, 50);
        
        final nextLen = (_displayedText.length + charsToTake).clamp(0, target.length);
        _displayedText = target.substring(0, nextLen);
        onUpdate(_displayedText);
      } else {
        _ticker?.stop();
      }
    });
    _ticker?.start();
  }

  void dispose() {
    _ticker?.dispose();
    _ticker = null;
  }
}
