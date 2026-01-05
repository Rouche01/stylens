class SessionStreamingChunkData {
  final String chunkText;
  final String sessionId;

  SessionStreamingChunkData({required this.chunkText, required this.sessionId});
}

const String _prefix = '|||sessionId_';
const String _delimiter = '|||';

/// Buffers incoming stream chunks and parses complete delimiter patterns.
/// Handles fragmented chunks that may arrive across multiple stream events.
class SessionStreamBuffer {
  String _buffer = '';
  String? _currentSessionId;

  /// Parses incoming chunks and returns data when a complete pattern is found.
  /// Returns null if more data is needed to complete the pattern.
  List<SessionStreamingChunkData> parseChunk(
    String incomingChunk,
    String fallbackSessionId,
  ) {
    _buffer += incomingChunk;
    final List<SessionStreamingChunkData> results = [];

    while (_buffer.isNotEmpty) {
      // Check if buffer contains the prefix
      final prefixIndex = _buffer.indexOf(_prefix);

      if (prefixIndex == -1) {
        // No prefix found - check if buffer might end with partial prefix
        if (_mightEndWithPartialPrefix(_buffer)) {
          // Keep buffering, might be start of a new delimiter
          break;
        }

        // No delimiter, return buffer as plain text
        if (_buffer.isNotEmpty) {
          results.add(
            SessionStreamingChunkData(
              sessionId: _currentSessionId ?? fallbackSessionId,
              chunkText: _buffer,
            ),
          );
          _buffer = '';
        }
        break;
      }

      // There's text before the prefix - return it first
      if (prefixIndex > 0) {
        final textBeforePrefix = _buffer.substring(0, prefixIndex);
        results.add(
          SessionStreamingChunkData(
            sessionId: _currentSessionId ?? fallbackSessionId,
            chunkText: textBeforePrefix,
          ),
        );
        _buffer = _buffer.substring(prefixIndex);
        continue;
      }

      // Buffer starts with prefix - find closing delimiter
      final afterPrefixIndex = _prefix.length;
      if (_buffer.length <= afterPrefixIndex) {
        // Incomplete prefix, wait for more data
        break;
      }

      final closingDelimiterIndex = _buffer.indexOf(
        _delimiter,
        afterPrefixIndex,
      );
      if (closingDelimiterIndex == -1) {
        // No closing delimiter yet, wait for more data
        break;
      }

      // Extract sessionId and text after delimiter
      _currentSessionId = _buffer.substring(
        afterPrefixIndex,
        closingDelimiterIndex,
      );
      final afterClosingDelimiter = closingDelimiterIndex + _delimiter.length;

      // Find the next prefix to know where this chunk ends
      final nextPrefixIndex = _buffer.indexOf(_prefix, afterClosingDelimiter);

      String chunkText;
      if (nextPrefixIndex == -1) {
        // No next prefix - check if buffer might end with partial prefix
        if (_mightEndWithPartialPrefix(
          _buffer.substring(afterClosingDelimiter),
        )) {
          // Keep the potential partial prefix in buffer
          final potentialPartialLength = _getPartialPrefixLength(
            _buffer.substring(afterClosingDelimiter),
          );
          if (potentialPartialLength > 0) {
            chunkText = _buffer.substring(
              afterClosingDelimiter,
              _buffer.length - potentialPartialLength,
            );
            _buffer = _buffer.substring(
              _buffer.length - potentialPartialLength,
            );
          } else {
            chunkText = _buffer.substring(afterClosingDelimiter);
            _buffer = '';
          }
        } else {
          chunkText = _buffer.substring(afterClosingDelimiter);
          _buffer = '';
        }
      } else {
        chunkText = _buffer.substring(afterClosingDelimiter, nextPrefixIndex);
        _buffer = _buffer.substring(nextPrefixIndex);
      }

      if (chunkText.isNotEmpty) {
        results.add(
          SessionStreamingChunkData(
            sessionId: _currentSessionId!,
            chunkText: chunkText,
          ),
        );
      }
    }

    return results;
  }

  /// Checks if the string might end with a partial prefix
  bool _mightEndWithPartialPrefix(String text) {
    for (int i = 1; i < _prefix.length && i <= text.length; i++) {
      if (text.endsWith(_prefix.substring(0, i))) {
        return true;
      }
    }
    return false;
  }

  /// Gets the length of the partial prefix at the end of the string
  int _getPartialPrefixLength(String text) {
    for (int i = _prefix.length - 1; i >= 1; i--) {
      if (text.endsWith(_prefix.substring(0, i))) {
        return i;
      }
    }
    return 0;
  }

  void clear() {
    _buffer = '';
    _currentSessionId = null;
  }

  String? get currentSessionId => _currentSessionId;
}
