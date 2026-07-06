
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';
import '../../../core/network/qwen_service.dart';

// --- Events ---
abstract class MemoryAgentEvent extends Equatable {
  @override
  List<Object?> get props => [];
}

class SendMessageEvent extends MemoryAgentEvent {
  final String message;
  final List<Map<String, dynamic>> history;

  SendMessageEvent({required this.message, required this.history});

  @override
  List<Object?> get props => [message, history];
}

// --- States ---
abstract class MemoryAgentState extends Equatable {
  @override
  List<Object?> get props => [];
}

class MemoryAgentInitial extends MemoryAgentState {}

class MemoryAgentLoading extends MemoryAgentState {}

class MemoryAgentSuccess extends MemoryAgentState {
  final String response;
  final List<Map<String, dynamic>> updatedHistory;

  MemoryAgentSuccess({required this.response, required this.updatedHistory});

  @override
  List<Object?> get props => [response, updatedHistory];
}

class MemoryAgentError extends MemoryAgentState {
  final String errorMessage;

  MemoryAgentError({required this.errorMessage});

  @override
  List<Object?> get props => [errorMessage];
}

// --- BLoC ---
class MemoryAgentBloc extends Bloc<MemoryAgentEvent, MemoryAgentState> {
  final QwenService _qwenService;

  MemoryAgentBloc({required QwenService qwenService}) 
      : _qwenService = qwenService, 
        super(MemoryAgentInitial()) {
    on<SendMessageEvent>(_onSendMessage);
  }

  Future<void> _onSendMessage(
    SendMessageEvent event,
    Emitter<MemoryAgentState> emit,
  ) async {
    emit(MemoryAgentLoading());

    try {
      final assistantMessage = await _qwenService.sendMessage(
        prompt: event.message,
        history: event.history,
      );

      final updatedHistory = [
        ...event.history,
        {'role': 'user', 'content': event.message},
        {'role': 'assistant', 'content': assistantMessage},
      ];

      emit(MemoryAgentSuccess(
        response: assistantMessage,
        updatedHistory: updatedHistory,
      ));
    } catch (e) {
      emit(MemoryAgentError(errorMessage: e.toString()));
    }
  }
}
