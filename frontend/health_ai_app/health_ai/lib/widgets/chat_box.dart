import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class ChatBox extends StatelessWidget {
  final VoidCallback onTap;
  final VoidCallback onVoiceChat;

  const ChatBox({super.key, required this.onTap, required this.onVoiceChat});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(13), // 0.05 opacity
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor: AppTheme.primaryColor.withAlpha(26), // 0.1 opacity
            radius: 20,
            child: Icon(Icons.person, color: AppTheme.primaryColor, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: GestureDetector(
              onTap: onTap,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  color: AppTheme.backgroundColor,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  'Chat with your coach...',
                  style: AppTheme.captionStyle.copyWith(
                    color: AppTheme.textSecondaryColor,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          GestureDetector(
            onTap: onVoiceChat,
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                gradient: AppTheme.primaryGradient,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: AppTheme.primaryColor.withAlpha(77), // 0.3 opacity
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: const Icon(Icons.mic, color: Colors.white, size: 24),
            ),
          ),
        ],
      ),
    );
  }
}
