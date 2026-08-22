import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';
import 'package:provider/provider.dart';
import '../../providers/active_view_provider.dart';
import '../../core/services/ai_service.dart';

class AskAiModal extends StatefulWidget {
  final VoidCallback? onClose;

  const AskAiModal({super.key, this.onClose});

  @override
  State<AskAiModal> createState() => _AskAiModalState();
}

class _AskAiModalState extends State<AskAiModal> {
  final TextEditingController _promptController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  
  final List<Map<String, String>> _messages = [];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    // In a real implementation, we would greet the user based on the context
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final activeResource = context.read<ActiveViewProvider>().activeResource;
      
      setState(() {
        if (activeResource != null) {
          _messages.add({
            'role': 'assistant',
            'content': 'I see you are looking at "${activeResource.title}". How can I help you with this material?',
          });
        } else {
          _messages.add({
            'role': 'assistant',
            'content': 'Hello! I am your AI Tutor. How can I help you study today?',
          });
        }
      });
    });
  }

  @override
  void dispose() {
    _promptController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _sendMessage(String text) async {
    if (text.trim().isEmpty) return;
    
    setState(() {
      _messages.add({'role': 'user', 'content': text});
      _isLoading = true;
    });
    
    _promptController.clear();
    _scrollToBottom();
    
    try {
      final activeResource = context.read<ActiveViewProvider>().activeResource;
      
      final response = await AIService().chat(
        history: _messages,
        contextText: activeResource?.contextText,
      );
      
      if (mounted) {
        setState(() {
          _messages.add({
            'role': 'assistant',
            'content': response,
          });
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _messages.add({
            'role': 'assistant',
            'content': 'Error: $e',
          });
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        _scrollToBottom();
      }
    }
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      Future.delayed(const Duration(milliseconds: 100), () {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final activeResource = context.watch<ActiveViewProvider>().activeResource;

    return Container(
      width: 450,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(20),
          bottomLeft: Radius.circular(20),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black12,
            blurRadius: 10,
            offset: Offset(-5, 0),
          ),
        ],
      ),
      child: Column(
        children: [
          // Header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            decoration: const BoxDecoration(
              border: Border(bottom: BorderSide(color: AppColors.border)),
              gradient: LinearGradient(
                colors: [Color(0xFF1E293B), Color(0xFF0F172A)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: Row(
              children: [
                const Icon(Icons.psychology, color: Colors.white),
                const SizedBox(width: 12),
                const Text(
                  'Tutor AI',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const Spacer(),
                IconButton(
                  onPressed: () {
                    if (widget.onClose != null) {
                      widget.onClose!();
                    } else {
                      Navigator.of(context).maybePop();
                    }
                  },
                  icon: const Icon(Icons.close, color: Colors.white70),
                ),
              ],
            ),
          ),
          
          // Context indicator
          if (activeResource != null)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              color: AppColors.primaryLight.withValues(alpha: 0.2),
              child: Row(
                children: [
                  const Icon(Icons.info_outline, size: 16, color: AppColors.primary),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Context: ${activeResource.title}',
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.primaryDark,
                        fontWeight: FontWeight.w600,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
            
          // Chat Messages
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.all(16),
              itemCount: _messages.length + (_isLoading ? 1 : 0),
              itemBuilder: (context, index) {
                if (index == _messages.length) {
                  return const Padding(
                    padding: EdgeInsets.all(16.0),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
                        ),
                      ),
                    ),
                  );
                }
                
                final msg = _messages[index];
                final isUser = msg['role'] == 'user';
                
                return Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: Row(
                    mainAxisAlignment: isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (!isUser)
                        Container(
                          margin: const EdgeInsets.only(right: 12),
                          padding: const EdgeInsets.all(8),
                          decoration: const BoxDecoration(
                            color: Color(0xFF1E293B),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.psychology, size: 16, color: Colors.white),
                        ),
                        
                      Flexible(
                        child: Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: isUser ? AppColors.primary : AppColors.background,
                            borderRadius: BorderRadius.only(
                              topLeft: const Radius.circular(16),
                              topRight: const Radius.circular(16),
                              bottomLeft: Radius.circular(isUser ? 16 : 4),
                              bottomRight: Radius.circular(isUser ? 4 : 16),
                            ),
                          ),
                          child: Text(
                            msg['content'] ?? '',
                            style: TextStyle(
                              color: isUser ? Colors.white : AppColors.textPrimary,
                            ),
                          ),
                        ),
                      ),
                      
                      if (isUser)
                        Container(
                          margin: const EdgeInsets.only(left: 12),
                          padding: const EdgeInsets.all(8),
                          decoration: const BoxDecoration(
                            color: AppColors.background,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.person, size: 16, color: AppColors.textSecondary),
                        ),
                    ],
                  ),
                );
              },
            ),
          ),
          
          // Suggestions
          if (activeResource != null && _messages.length == 1)
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                children: activeResource.suggestedPrompts.map((prompt) {
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ActionChip(
                      label: Text(prompt),
                      labelStyle: const TextStyle(fontSize: 12, color: AppColors.primaryDark),
                      backgroundColor: AppColors.primaryLight.withValues(alpha: 0.2),
                      side: BorderSide(color: AppColors.primary.withValues(alpha: 0.2)),
                      onPressed: () => _sendMessage(prompt),
                    ),
                  );
                }).toList(),
              ),
            ),
          
          // Input Area
          Container(
            padding: const EdgeInsets.all(16),
            decoration: const BoxDecoration(
              color: Colors.white,
              border: Border(top: BorderSide(color: AppColors.border)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _promptController,
                    decoration: InputDecoration(
                      hintText: 'Ask your AI tutor...',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(24),
                        borderSide: BorderSide.none,
                      ),
                      filled: true,
                      fillColor: AppColors.background,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                    ),
                    onSubmitted: _sendMessage,
                  ),
                ),
                const SizedBox(width: 12),
                Container(
                  decoration: const BoxDecoration(
                    color: AppColors.primary,
                    shape: BoxShape.circle,
                  ),
                  child: IconButton(
                    icon: const Icon(Icons.send, color: Colors.white, size: 20),
                    onPressed: () => _sendMessage(_promptController.text),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
