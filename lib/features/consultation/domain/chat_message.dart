import 'package:equatable/equatable.dart';

enum MessageSender { user, astrologer, system }

enum DeliveryState { sending, sent, failed }

class ChatMessage extends Equatable {
  const ChatMessage({
    required this.id,
    required this.sessionId,
    required this.sender,
    required this.text,
    required this.sentAt,
    this.clientId,
    this.delivery = DeliveryState.sent,
  });

  /// Server id, or the clientId while the message is still pending.
  final String id;
  final String sessionId;
  final MessageSender sender;
  final String text;
  final DateTime sentAt;
  final String? clientId;
  final DeliveryState delivery;

  ChatMessage withDelivery(DeliveryState d) => ChatMessage(
        id: id,
        sessionId: sessionId,
        sender: sender,
        text: text,
        sentAt: sentAt,
        clientId: clientId,
        delivery: d,
      );

  factory ChatMessage.fromJson(Map<String, dynamic> j) => ChatMessage(
        id: j['id'] as String,
        sessionId: j['sessionId'] as String,
        sender: MessageSender.values.byName(j['sender'] as String),
        text: j['text'] as String,
        sentAt: DateTime.parse(j['sentAt'] as String),
        clientId: j['clientId'] as String?,
      );

  @override
  List<Object?> get props => [id, clientId, text, delivery];
}
