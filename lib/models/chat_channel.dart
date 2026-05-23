enum ChannelType { general, private, group }

class ChatChannel {
  final String id;
  final String name;
  final String? description;
  final ChannelType type;
  final String createdBy;
  final DateTime createdAt;
  final String? lastMessage;
  final DateTime? lastMessageAt;
  final List<String> requiredRoles;
  final bool isPredefined;
  final int sortOrder;

  const ChatChannel({
    required this.id,
    required this.name,
    this.description,
    required this.type,
    required this.createdBy,
    required this.createdAt,
    this.lastMessage,
    this.lastMessageAt,
    this.requiredRoles = const [],
    this.isPredefined = false,
    this.sortOrder = 0,
  });

  factory ChatChannel.fromJson(Map<String, dynamic> json) {
    return ChatChannel(
      id: json['id'] as String,
      name: json['name'] as String,
      description: json['description'] as String?,
      type: ChannelType.values.firstWhere(
        (t) => t.name == json['type'],
        orElse: () => ChannelType.general,
      ),
      createdBy: json['created_by'] as String,
      createdAt: DateTime.parse(json['created_at'] as String),
      lastMessage: json['last_message'] as String?,
      lastMessageAt: json['last_message_at'] != null
          ? DateTime.parse(json['last_message_at'] as String)
          : null,
      requiredRoles: json['required_roles'] != null
          ? List<String>.from(json['required_roles'] as List)
          : const [],
      isPredefined: json['is_predefined'] as bool? ?? false,
      sortOrder: json['sort_order'] as int? ?? 0,
    );
  }

  Map<String, dynamic> toJson() => {
        'name': name,
        'type': type.name,
        'created_by': createdBy,
      };

  bool get isGeneral => type == ChannelType.general;

  bool isVisibleToRole(String roleDbValue) {
    if (requiredRoles.isEmpty) return true;
    return requiredRoles.contains(roleDbValue);
  }
}
