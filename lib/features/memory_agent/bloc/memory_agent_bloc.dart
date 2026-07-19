import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';
import '../../../core/database/memory_repository.dart';
import '../../../core/network/qwen_service.dart';

// --- Events ---
abstract class MemoryAgentEvent extends Equatable {
  const MemoryAgentEvent();

  @override
  List<Object?> get props => [];
}

/// Loads this device's existing knowledge bank from local storage.
/// Dispatched once when the chat screen first opens.
class LoadMemoryRequested extends MemoryAgentEvent {
  const LoadMemoryRequested();
}

class SendMessageEvent extends MemoryAgentEvent {
  final String message;

  const SendMessageEvent({required this.message});

  @override
  List<Object?> get props => [message];
}

/// Permanently deletes this device's entire knowledge bank.
class ClearMemoryRequested extends MemoryAgentEvent {
  const ClearMemoryRequested();
}

// --- State ---
/// A single immutable snapshot of the conversation. One state class (not a
/// hierarchy) so the UI always has `history` + `isSending` to render, no
/// matter what just happened.
class MemoryAgentState extends Equatable {
  final List<MemoryEntry> history;
  final bool isLoadingHistory;
  final bool isSending;
  final String? errorMessage;

  const MemoryAgentState({
    this.history = const [],
    this.isLoadingHistory = false,
    this.isSending = false,
    this.errorMessage,
  });

  MemoryAgentState copyWith({
    List<MemoryEntry>? history,
    bool? isLoadingHistory,
    bool? isSending,
    String? errorMessage,
    bool clearError = false,
  }) {
    return MemoryAgentState(
      history: history ?? this.history,
      isLoadingHistory: isLoadingHistory ?? this.isLoadingHistory,
      isSending: isSending ?? this.isSending,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    );
  }

  @override
  List<Object?> get props => [history, isLoadingHistory, isSending, errorMessage];
}

// --- BLoC ---
class MemoryAgentBloc extends Bloc<MemoryAgentEvent, MemoryAgentState> {
  final QwenService _qwenService;
  final MemoryRepository _memoryRepository;

  /// How many recent turns are sent back to the model as context. Keeps the
  /// request payload/latency bounded as the local knowledge bank grows -
  /// the model still gets recent conversational context, but every entry is
  /// still saved permanently and reloaded in full next time the app opens.
  static const int _contextWindowSize = 30;

  MemoryAgentBloc({
    required QwenService qwenService,
    required MemoryRepository memoryRepository,
  })  : _qwenService = qwenService,
        _memoryRepository = memoryRepository,
        super(const MemoryAgentState()) {
    on<LoadMemoryRequested>(_onLoadMemory);
    on<SendMessageEvent>(_onSendMessage);
    on<ClearMemoryRequested>(_onClearMemory);
  }

  Future<void> _onLoadMemory(
    LoadMemoryRequested event,
    Emitter<MemoryAgentState> emit,
  ) async {
    emit(state.copyWith(isLoadingHistory: true, clearError: true));
    final history = await _memoryRepository.loadRecentHistory();
    emit(state.copyWith(history: history, isLoadingHistory: false));
  }

  Future<void> _onSendMessage(
    SendMessageEvent event,
    Emitter<MemoryAgentState> emit,
  ) async {
    final priorHistory = state.history;
    final userEntry = MemoryEntry(
      id: _memoryRepository.newId(),
      role: 'user',
      content: event.message,
      createdAt: DateTime.now(),
    );

    // Optimistic update: show the user's message immediately, before the
    // model has replied.
    final historyWithUserMessage = [...priorHistory, userEntry];
    emit(state.copyWith(history: historyWithUserMessage, isSending: true, clearError: true));

    try {
      // priorHistory excludes the just-added userEntry - QwenService.
      // sendMessage appends {role: user, content: prompt} itself, so
      // passing historyWithUserMessage here would duplicate the current
      // message.
      final startIndex = priorHistory.length > _contextWindowSize
          ? priorHistory.length - _contextWindowSize
          : 0;
      final contextMessages = priorHistory
          .skip(startIndex)
          .map((e) => e.toApiMessage())
          .toList();

      final assistantText = await _qwenService.sendMessage(
        prompt: event.message,
        history: contextMessages,
      );

      final assistantEntry = MemoryEntry(
        id: _memoryRepository.newId(),
        role: 'assistant',
        content: assistantText,
        createdAt: DateTime.now(),
      );

      final finalHistory = [...historyWithUserMessage, assistantEntry];
      emit(state.copyWith(history: finalHistory, isSending: false));

      // Persist both turns permanently. This happens after the UI already
      // updated, so a slow/failed write never blocks or breaks the chat
      // experience.
      await _memoryRepository.addEntries([userEntry, assistantEntry]);
    } catch (e) {
      emit(state.copyWith(
        isSending: false,
        errorMessage: 'Message failed to send: $e',
      ));
    }
  }

  Future<void> _onClearMemory(
    ClearMemoryRequested event,
    Emitter<MemoryAgentState> emit,
  ) async {
    await _memoryRepository.clearHistory();
    emit(state.copyWith(history: []));
  }
}
