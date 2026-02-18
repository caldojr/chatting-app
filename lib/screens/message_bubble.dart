import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:g11chat_app/theme/app_colors.dart';
import 'package:g11chat_app/theme/app_text_styles.dart';

enum MessageDeliveryStatus { sent, delivered, read }

class MessageBubble extends StatelessWidget {
  const MessageBubble({
    super.key,
    required this.text,
    required this.isMe,
    required this.timeLabel,
    required this.status,
    this.onLongPress,
    this.imageBase64 = "",
  });

  final String text;
  final bool isMe;
  final String timeLabel;
  final MessageDeliveryStatus status;
  final VoidCallback? onLongPress;
  final String imageBase64;

  Widget _statusIcon() {
    switch (status) {
      case MessageDeliveryStatus.read:
        return const Icon(Icons.done_all, size: 14, color: Color(0xFF1E88E5));
      case MessageDeliveryStatus.delivered:
        return const Icon(Icons.done_all, size: 14, color: Colors.black38);
      case MessageDeliveryStatus.sent:
        return const Icon(Icons.done, size: 14, color: Colors.black38);
    }
  }

  @override
  Widget build(BuildContext context) {
    Uint8List? imageBytes;
    if (imageBase64.isNotEmpty) {
      try {
        imageBytes = base64Decode(imageBase64);
      } catch (_) {
        imageBytes = null;
      }
    }
    final hasImage = imageBytes != null;
    final bubbleColor =
        isMe ? const Color(0xFFBCE8F3) : const Color(0xFFEAF6FB);
    final align = isMe ? Alignment.centerRight : Alignment.centerLeft;
    final radius = BorderRadius.only(
      topLeft: const Radius.circular(22),
      topRight: const Radius.circular(22),
      bottomLeft: Radius.circular(isMe ? 22 : 6),
      bottomRight: Radius.circular(isMe ? 6 : 22),
    );

    return Align(
      alignment: align,
      child: GestureDetector(
        onLongPress: onLongPress,
        child: Container(
          margin: const EdgeInsets.symmetric(vertical: 6),
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 7),
          constraints: const BoxConstraints(maxWidth: 290),
          decoration: BoxDecoration(
            color: bubbleColor,
            borderRadius: radius,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (hasImage)
                ClipRRect(
                  borderRadius: BorderRadius.circular(14),
                  child: Image.memory(
                    imageBytes,
                    width: 220,
                    fit: BoxFit.cover,
                  ),
                ),
              if (text.trim().isNotEmpty) ...[
                if (hasImage) const SizedBox(height: 6),
                Text(
                  text,
                  style: TextStyle(
                    color: AppColors.primaryDarkBlue,
                    fontSize: AppTextStyles.body.fontSize,
                    height: 1.2,
                  ),
                ),
              ],
              const SizedBox(height: 4),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (!isMe) ...[
                    const Icon(Icons.person, size: 14, color: Color(0xFF50545C)),
                    const SizedBox(width: 4),
                  ],
                  Text(timeLabel, style: AppTextStyles.caption),
                  if (isMe) ...[
                    const SizedBox(width: 4),
                    _statusIcon(),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
