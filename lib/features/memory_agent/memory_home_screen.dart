import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../auth/auth_bloc.dart';
import 'bloc/memory_agent_bloc.dart';

/// Memory Agent chat screen. This is the actual product: a chat interface
/// backed by MemoryAgentBloc, whose every turn is permanently saved to the
/// signed-in user's Firestore-backed knowledge bank (see MemoryRepository)
/// and reloaded the next time they open the app.
class MemoryHomeScreen extends StatefulWidget {
  const MemoryHomeScreen({super.key});

  @override
  State<MemoryHomeScreen> createState() => _MemoryHomeScreenState();
}

class _MemoryHomeScreenState extends State<MemoryHomeScreen> {
  final _inputController = TextEditingController();
  final _scrollController = ScrollController();
  String? _userId;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // The router only ever lets an authenticated user reach '/home' (see
    // app.dart's redirect logic), so AuthAuthenticated is the expected
    // state here. Load this user's existing knowledge bank exactly once
    // per session.
    final authState = context.read<AuthBloc>().state;
    if (authState is AuthAuthenticated && _userId != authState.user.id) {
      _userId = authState.user.id;
      context.read<MemoryAgentBloc>().add(LoadMemoryRequested(userId: _userId!));
    }
  }

  @override
  void dispose() {
    _inputController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _send() {
    final text = _inputController.text.trim();
    if (text.isEmpty || _userId == null) return;
    context.read<MemoryAgentBloc>().add(SendMessageEvent(userId: _userId!, message: text));
    _inputController.clear();
    // Let the new bubble render before scrolling to it.
    WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());
  }

  void _scrollToBottom() {
    if (!_scrollController.hasClients) return;
    _scrollController.animateTo(
      _scrollController.position.maxScrollExtent,
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeOut,
    );
  }

  Future<void> _confirmClearMemory() async {
    if (_userId == null) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Clear knowledge bank?'),
        content: const Text(
          'This permanently deletes everything Memory Agent has learned '
          'from your conversations. This cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Clear'),
          ),
        ],
      ),
    );
    if (confirmed == true && mounted) {
      context.read<MemoryAgentBloc>().add(ClearMemoryRequested(userId: _userId!));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Memory Agent'),
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_outline),
            tooltip: 'Clear knowledge bank',
            onPressed: _confirmClearMemory,
          ),
        ],
      ),
      body: BlocConsumer<MemoryAgentBloc, MemoryAgentState>(
        listener: (context, state) {
          if (state.errorMessage != null) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(state.errorMessage!)),
            );
          }
        },
        builder: (context, state) {
          return Column(
            children: [
              if (!state.isMemoryPersisted && !state.isLoadingHistory)
                Container(
                  width: double.infinity,
                  color: Colors.amber.shade100,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: const Text(
                    'Memory storage is unavailable right now - this '
                    'conversation will not be saved after you leave.',
                    style: TextStyle(fontSize: 12),
                  ),
                ),
              Expanded(
                child: state.isLoadingHistory
                    ? const Center(child: CircularProgressIndicator())
                    : state.history.isEmpty
                        ? _EmptyState()
                        : ListView.builder(
                            controller: _scrollController,
                            padding: const EdgeInsets.all(16),
                            itemCount: state.history.length,
                            itemBuilder: (context, index) {
                              final entry = state.history[index];
                              return _ChatBubble(
                                content: entry.content,
                                isUser: entry.role == 'user',
                              );
                            },
                          ),
              ),
              if (state.isSending)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 4),
                  child: _TypingIndicator(),
                ),
              _MessageInputBar(
                controller: _inputController,
                enabled: !state.isSending,
                onSend: _send,
              ),
            ],
          );
        },
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.psychology_outlined, size: 80, color: Colors.grey.shade400),
            const SizedBox(height: 24),
            Text(
              'Your knowledge bank is empty',
              style: Theme.of(context).textTheme.headlineSmall,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'Everything you teach Memory Agent here is saved permanently '
              'and remembered next time you open the app.',
              style: Theme.of(context)
                  .textTheme
                  .bodyLarge
                  ?.copyWith(color: Colors.grey),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

class _ChatBubble extends StatelessWidget {
  final String content;
  final bool isUser;

  const _ChatBubble({required this.content, required this.isUser});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.78),
        margin: const EdgeInsets.symmetric(vertical: 6),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: isUser ? colorScheme.primary : colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(16),
            topRight: const Radius.circular(16),
            bottomLeft: Radius.circular(isUser ? 16 : 4),
            bottomRight: Radius.circular(isUser ? 4 : 16),
          ),
        ),
        child: Text(
          content,
          style: TextStyle(
            color: isUser ? colorScheme.onPrimary : colorScheme.onSurfaceVariant,
          ),
        ),
      ),
    );
  }
}

class _TypingIndicator extends StatelessWidget {
  const _TypingIndicator();

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.start,
      children: [
        const SizedBox(width: 16),
        SizedBox(
          width: 16,
          height: 16,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
        const SizedBox(width: 12),
        Text('Memory Agent is thinking...', style: Theme.of(context).textTheme.bodySmall),
      ],
    );
  }
}

class _MessageInputBar extends StatelessWidget {
  final TextEditingController controller;
  final bool enabled;
  final VoidCallback onSend;

  const _MessageInputBar({
    required this.controller,
    required this.enabled,
    required this.onSend,
  });

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            Expanded(
              child: TextField(
                controller: controller,
                enabled: enabled,
                minLines: 1,
                maxLines: 5,
                textInputAction: TextInputAction.send,
                onSubmitted: (_) => onSend(),
                decoration: InputDecoration(
                  hintText: 'Teach Memory Agent something, or ask a question...',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(24)),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                ),
              ),
            ),
            const SizedBox(width: 8),
            IconButton.filled(
              onPressed: enabled ? onSend : null,
              icon: const Icon(Icons.send),
            ),
          ],
        ),
      ),
    );
  }
}
