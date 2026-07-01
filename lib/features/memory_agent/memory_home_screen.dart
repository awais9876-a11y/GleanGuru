import 'package:flutter/material.dart';

/// Memory Agent Home Screen
/// Main interface for the Multimodal Memory Agent
class MemoryHomeScreen extends StatelessWidget {
  const MemoryHomeScreen({super.key});
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Memory Agent'),
        actions: [
          IconButton(
            icon: const Icon(Icons.search),
            onPressed: () {
              // Open search
            },
          ),
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () {
              // Add new memory node
            },
          ),
        ],
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.psychology, size: 100, color: Colors.grey),
            const SizedBox(height: 24),
            Text(
              'Your Memory Graph',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 8),
            Text(
              'Create and connect your thoughts',
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                color: Colors.grey,
              ),
            ),
            const SizedBox(height: 32),
            ElevatedButton.icon(
              onPressed: () {
                // Create new memory
              },
              icon: const Icon(Icons.add_circle_outline),
              label: const Text('Create New Memory'),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          // Quick add memory
        },
        icon: const Icon(Icons.quickreply),
        label: const Text('Quick Add'),
      ),
    );
  }
}
