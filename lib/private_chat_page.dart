import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:traveltest_app/services/database.dart';
import 'package:traveltest_app/services/shared_pref.dart';

class PrivateChatPage extends StatefulWidget {
  final String otherUserId;
  final String otherUserName;
  final String otherUserImage;

  const PrivateChatPage({
    super.key,
    required this.otherUserId,
    required this.otherUserName,
    required this.otherUserImage,
  });

  @override
  State<PrivateChatPage> createState() => _PrivateChatPageState();
}

class _PrivateChatPageState extends State<PrivateChatPage>
    with WidgetsBindingObserver {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final FocusNode _messageFocusNode = FocusNode();

  String? currentUserId;
  String? currentUserName;
  String? currentUserImage;
  String? chatId;
  Stream<QuerySnapshot>? messagesStream;

  bool _isTyping = false;
  bool _isOnline = true;
  bool _showScrollToBottom = false;
  String? _replyToMessageId;
  String? _replyToMessage;
  String? _replyToSender;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initializeChat();
    _setupScrollListener();
    _setupMessageListener();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _messageController.dispose();
    _scrollController.dispose();
    _messageFocusNode.dispose();
    _markMessagesAsRead();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    setState(() {
      _isOnline = state == AppLifecycleState.resumed;
    });

    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached) {
      _markMessagesAsRead();
    }
  }

  void _setupScrollListener() {
    _scrollController.addListener(() {
      if (_scrollController.hasClients) {
        bool shouldShow = _scrollController.offset > 200;
        if (shouldShow != _showScrollToBottom) {
          setState(() {
            _showScrollToBottom = shouldShow;
          });
        }
      }
    });
  }

  void _setupMessageListener() {
    _messageController.addListener(() {
      bool currentlyTyping = _messageController.text.isNotEmpty;
      if (currentlyTyping != _isTyping) {
        setState(() {
          _isTyping = currentlyTyping;
        });
        _updateTypingStatus(currentlyTyping);
      }
    });
  }

  Future<void> _updateTypingStatus(bool isTyping) async {
    if (chatId != null && currentUserId != null) {
      try {
        await FirebaseFirestore.instance
            .collection('private_chats')
            .doc(chatId)
            .update({
          '${currentUserId}_typing': isTyping,
          '${currentUserId}_lastSeen': FieldValue.serverTimestamp(),
        });
      } catch (e) {
        print("Error updating typing status: $e");
      }
    }
  }

  Future<void> _initializeChat() async {
    // Get current user data
    currentUserId = await SharedpreferenceHelper().getUserId();
    currentUserName = await SharedpreferenceHelper().getUserName();
    currentUserImage = await SharedpreferenceHelper().getUserImage();

    // Create chat ID (consistent ordering)
    List<String> userIds = [currentUserId!, widget.otherUserId];
    userIds.sort();
    chatId = userIds.join('_');

    // Initialize chat document if it doesn't exist
    await _initializeChatDocument();

    // Get messages stream
    messagesStream = DatabaseMethods().getPrivateMessages(chatId!);

    // Mark messages as read when opening chat
    await _markMessagesAsRead();

    setState(() {});

    // Auto-scroll to bottom after a short delay
    Future.delayed(Duration(milliseconds: 500), () {
      _scrollToBottom();
    });
  }

  Future<void> _initializeChatDocument() async {
    try {
      DocumentSnapshot chatDoc = await FirebaseFirestore.instance
          .collection('private_chats')
          .doc(chatId)
          .get();

      if (!chatDoc.exists) {
        await FirebaseFirestore.instance
            .collection('private_chats')
            .doc(chatId)
            .set({
          'participants': [currentUserId, widget.otherUserId],
          'participantNames': [currentUserName, widget.otherUserName],
          'participantImages': [currentUserImage, widget.otherUserImage],
          'lastMessage': '',
          'lastMessageTime': FieldValue.serverTimestamp(),
          'createdAt': FieldValue.serverTimestamp(),
          '${currentUserId}_typing': false,
          '${widget.otherUserId}_typing': false,
          '${currentUserId}_lastSeen': FieldValue.serverTimestamp(),
          '${widget.otherUserId}_lastSeen': FieldValue.serverTimestamp(),
        });
      }
    } catch (e) {
      print("Error initializing chat: $e");
    }
  }

  Future<void> _sendMessage() async {
    if (_messageController.text.trim().isEmpty) return;

    String message = _messageController.text.trim();
    _messageController.clear();

    // Clear reply if set
    String? replyToId = _replyToMessageId;
    String? replyMessage = _replyToMessage;
    String? replySender = _replyToSender;
    _clearReply();

    try {
      // Add message with reply information if applicable
      Map<String, dynamic> messageData = {
        'senderId': currentUserId!,
        'senderName': currentUserName!,
        'senderImage': currentUserImage ?? '',
        'receiverId': widget.otherUserId,
        'message': message,
        'timestamp': FieldValue.serverTimestamp(),
        'isRead': false,
        'messageType': 'text',
      };

      // Add reply data if this is a reply
      if (replyToId != null) {
        messageData.addAll({
          'replyToMessageId': replyToId,
          'replyToMessage': replyMessage,
          'replyToSender': replySender,
          'isReply': true,
        });
      }

      await FirebaseFirestore.instance
          .collection('private_chats')
          .doc(chatId!)
          .collection('messages')
          .add(messageData);

      // Update chat document
      await FirebaseFirestore.instance
          .collection('private_chats')
          .doc(chatId!)
          .update({
        'lastMessage': message,
        'lastMessageTime': FieldValue.serverTimestamp(),
        'lastMessageSender': currentUserId,
        '${currentUserId}_typing': false,
      });

      // Update unread count for receiver
      await DatabaseMethods().updateUnreadCount(widget.otherUserId, chatId!);

      // Scroll to bottom and provide haptic feedback
      _scrollToBottom();
      HapticFeedback.lightImpact();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Failed to send message: $e"),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _markMessagesAsRead() async {
    if (chatId != null && currentUserId != null) {
      await DatabaseMethods().markMessagesAsRead(chatId!, currentUserId!);
    }
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  void _setReplyToMessage(String messageId, String message, String sender) {
    setState(() {
      _replyToMessageId = messageId;
      _replyToMessage = message;
      _replyToSender = sender;
    });
    _messageFocusNode.requestFocus();
  }

  void _clearReply() {
    setState(() {
      _replyToMessageId = null;
      _replyToMessage = null;
      _replyToSender = null;
    });
  }

  String _formatMessageTime(Timestamp? timestamp) {
    if (timestamp == null) return 'Sending...';

    DateTime messageTime = timestamp.toDate();
    DateTime now = DateTime.now();
    Duration difference = now.difference(messageTime);

    if (difference.inDays > 0) {
      return '${difference.inDays}d ago';
    } else if (difference.inHours > 0) {
      return '${difference.inHours}h ago';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes}m ago';
    } else {
      return 'Just now';
    }
  }

  Widget _buildReplyPreview() {
    if (_replyToMessageId == null) return SizedBox.shrink();

    return Container(
      margin: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(8),
        border: Border(
          left: BorderSide(color: Colors.blue, width: 4),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Replying to $_replyToSender',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Colors.blue,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  _replyToMessage ?? '',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey.shade700,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            icon: Icon(Icons.close, size: 20),
            onPressed: _clearReply,
            color: Colors.grey.shade600,
          ),
        ],
      ),
    );
  }

  Widget _buildMessageBubble(DocumentSnapshot message, bool isCurrentUser) {
    Map<String, dynamic> data = message.data() as Map<String, dynamic>;
    bool isReply = data['isReply'] ?? false;
    bool isRead = data['isRead'] ?? false;

    return GestureDetector(
      onLongPress: () => _showMessageOptions(message, isCurrentUser),
      child: Container(
        margin: EdgeInsets.only(bottom: 12),
        child: Row(
          mainAxisAlignment:
              isCurrentUser ? MainAxisAlignment.end : MainAxisAlignment.start,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            if (!isCurrentUser) ...[
              ClipRRect(
                borderRadius: BorderRadius.circular(15),
                child: _buildUserAvatar(data['senderImage']),
              ),
              SizedBox(width: 8),
            ],
            Flexible(
              child: Column(
                crossAxisAlignment: isCurrentUser
                    ? CrossAxisAlignment.end
                    : CrossAxisAlignment.start,
                children: [
                  // Reply preview if this is a reply
                  if (isReply) _buildReplyBubble(data, isCurrentUser),

                  // Main message bubble
                  Container(
                    constraints: BoxConstraints(
                      maxWidth: MediaQuery.of(context).size.width * 0.7,
                    ),
                    padding: EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    decoration: BoxDecoration(
                      color:
                          isCurrentUser ? Colors.blue.shade500 : Colors.white,
                      borderRadius: BorderRadius.only(
                        topLeft: Radius.circular(18),
                        topRight: Radius.circular(18),
                        bottomLeft: Radius.circular(isCurrentUser ? 18 : 4),
                        bottomRight: Radius.circular(isCurrentUser ? 4 : 18),
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.grey.shade200,
                          blurRadius: 3,
                          offset: Offset(0, 1),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          data['message'] ?? '',
                          style: TextStyle(
                            color:
                                isCurrentUser ? Colors.white : Colors.black87,
                            fontSize: 15,
                          ),
                        ),
                        SizedBox(height: 4),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              _formatMessageTime(data['timestamp']),
                              style: TextStyle(
                                color: isCurrentUser
                                    ? Colors.white70
                                    : Colors.grey.shade500,
                                fontSize: 11,
                              ),
                            ),
                            if (isCurrentUser) ...[
                              SizedBox(width: 4),
                              Icon(
                                isRead ? Icons.done_all : Icons.done,
                                color: isRead
                                    ? Colors.blue.shade200
                                    : Colors.white70,
                                size: 14,
                              ),
                            ],
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            if (isCurrentUser) ...[
              SizedBox(width: 8),
              ClipRRect(
                borderRadius: BorderRadius.circular(15),
                child: _buildUserAvatar(currentUserImage),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildReplyBubble(Map<String, dynamic> data, bool isCurrentUser) {
    return Container(
      margin: EdgeInsets.only(bottom: 4),
      padding: EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: isCurrentUser
            ? Colors.blue.shade400.withOpacity(0.3)
            : Colors.grey.shade200,
        borderRadius: BorderRadius.circular(8),
        border: Border(
          left: BorderSide(
            color: isCurrentUser ? Colors.white : Colors.blue,
            width: 3,
          ),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            data['replyToSender'] ?? '',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: isCurrentUser ? Colors.white : Colors.blue,
            ),
          ),
          SizedBox(height: 2),
          Text(
            data['replyToMessage'] ?? '',
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 12,
              color: isCurrentUser ? Colors.white70 : Colors.grey.shade700,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUserAvatar(String? imageUrl) {
    return Container(
      height: 30,
      width: 30,
      child: imageUrl != null && imageUrl.isNotEmpty
          ? Image.network(
              imageUrl,
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) {
                return Container(
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(15),
                  ),
                  child: Icon(Icons.person, size: 18),
                );
              },
            )
          : Container(
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(15),
              ),
              child: Icon(Icons.person, size: 18),
            ),
    );
  }

  void _showMessageOptions(DocumentSnapshot message, bool isCurrentUser) {
    Map<String, dynamic> data = message.data() as Map<String, dynamic>;

    showModalBottomSheet(
      context: context,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Container(
        padding: EdgeInsets.symmetric(vertical: 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: Icon(Icons.reply, color: Colors.blue),
              title: Text('Reply'),
              onTap: () {
                Navigator.pop(context);
                _setReplyToMessage(
                  message.id,
                  data['message'] ?? '',
                  data['senderName'] ?? 'Unknown',
                );
              },
            ),
            ListTile(
              leading: Icon(Icons.copy, color: Colors.grey),
              title: Text('Copy'),
              onTap: () {
                Navigator.pop(context);
                Clipboard.setData(ClipboardData(text: data['message'] ?? ''));
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Message copied to clipboard')),
                );
              },
            ),
            if (isCurrentUser)
              ListTile(
                leading: Icon(Icons.delete, color: Colors.red),
                title: Text('Delete'),
                onTap: () {
                  Navigator.pop(context);
                  _deleteMessage(message.id);
                },
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _deleteMessage(String messageId) async {
    try {
      await FirebaseFirestore.instance
          .collection('private_chats')
          .doc(chatId!)
          .collection('messages')
          .doc(messageId)
          .delete();

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Message deleted')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to delete message')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 1,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () {
            _markMessagesAsRead();
            Navigator.pop(context);
          },
        ),
        title: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: _buildUserAvatar(widget.otherUserImage),
            ),
            SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.otherUserName,
                    style: TextStyle(
                      color: Colors.black,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  StreamBuilder<DocumentSnapshot>(
                    stream: FirebaseFirestore.instance
                        .collection('private_chats')
                        .doc(chatId)
                        .snapshots(),
                    builder: (context, snapshot) {
                      if (snapshot.hasData && snapshot.data!.exists) {
                        Map<String, dynamic> data =
                            snapshot.data!.data() as Map<String, dynamic>;
                        bool isOtherUserTyping =
                            data['${widget.otherUserId}_typing'] ?? false;

                        if (isOtherUserTyping) {
                          return Text(
                            'typing...',
                            style: TextStyle(
                              color: Colors.green,
                              fontSize: 12,
                              fontStyle: FontStyle.italic,
                            ),
                          );
                        }
                      }

                      return Text(
                        _isOnline ? 'Online' : 'Last seen recently',
                        style: TextStyle(
                          color: _isOnline ? Colors.green : Colors.grey,
                          fontSize: 12,
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          // Messages List
          Expanded(
            child: Stack(
              children: [
                messagesStream == null
                    ? Center(child: CircularProgressIndicator())
                    : StreamBuilder<QuerySnapshot>(
                        stream: messagesStream,
                        builder: (context, snapshot) {
                          if (snapshot.connectionState ==
                              ConnectionState.waiting) {
                            return Center(child: CircularProgressIndicator());
                          }

                          if (!snapshot.hasData ||
                              snapshot.data!.docs.isEmpty) {
                            return Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.chat_bubble_outline,
                                      size: 60, color: Colors.grey.shade400),
                                  SizedBox(height: 16),
                                  Text(
                                    'No messages yet',
                                    style: TextStyle(
                                      fontSize: 18,
                                      color: Colors.grey.shade600,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                  SizedBox(height: 8),
                                  Text(
                                    'Start a conversation with ${widget.otherUserName}!',
                                    style: TextStyle(
                                      fontSize: 14,
                                      color: Colors.grey.shade500,
                                    ),
                                  ),
                                ],
                              ),
                            );
                          }

                          List<DocumentSnapshot> messages = snapshot.data!.docs;

                          // Mark messages as read when they're displayed
                          WidgetsBinding.instance.addPostFrameCallback((_) {
                            _markMessagesAsRead();
                          });

                          return ListView.builder(
                            controller: _scrollController,
                            padding: EdgeInsets.symmetric(
                                horizontal: 16, vertical: 8),
                            itemCount: messages.length,
                            itemBuilder: (context, index) {
                              DocumentSnapshot message = messages[index];
                              bool isCurrentUser =
                                  message['senderId'] == currentUserId;
                              return _buildMessageBubble(
                                  message, isCurrentUser);
                            },
                          );
                        },
                      ),

                // Scroll to bottom button
                if (_showScrollToBottom)
                  Positioned(
                    bottom: 16,
                    right: 16,
                    child: FloatingActionButton.small(
                      onPressed: _scrollToBottom,
                      backgroundColor: Colors.blue,
                      child:
                          Icon(Icons.keyboard_arrow_down, color: Colors.white),
                    ),
                  ),
              ],
            ),
          ),

          // Reply Preview
          _buildReplyPreview(),

          // Message Input
          Container(
            padding: EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.grey.shade200,
                  blurRadius: 5,
                  offset: Offset(0, -2),
                ),
              ],
            ),
            child: Row(
              children: [
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(25),
                    ),
                    child: TextField(
                      controller: _messageController,
                      focusNode: _messageFocusNode,
                      decoration: InputDecoration(
                        hintText: 'Type a message...',
                        hintStyle: TextStyle(color: Colors.grey.shade500),
                        border: InputBorder.none,
                        contentPadding:
                            EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                        prefixIcon: Icon(Icons.emoji_emotions_outlined,
                            color: Colors.grey.shade500),
                        suffixIcon: IconButton(
                          icon: Icon(Icons.attach_file,
                              color: Colors.grey.shade500),
                          onPressed: () {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                  content:
                                      Text('File attachment coming soon!')),
                            );
                          },
                        ),
                      ),
                      maxLines: null,
                      textCapitalization: TextCapitalization.sentences,
                      onSubmitted: (_) => _sendMessage(),
                    ),
                  ),
                ),
                SizedBox(width: 12),
                GestureDetector(
                  onTap: _sendMessage,
                  child: Container(
                    height: 48,
                    width: 48,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [Colors.blue.shade400, Colors.blue.shade600],
                      ),
                      borderRadius: BorderRadius.circular(24),
                    ),
                    child: Icon(Icons.send, color: Colors.white, size: 20),
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
