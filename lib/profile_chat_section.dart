import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:traveltest_app/services/database.dart';
import 'package:traveltest_app/services/shared_pref.dart';
import 'package:traveltest_app/private_chat_page.dart';
import 'package:traveltest_app/all_users_section.dart';

// Simple widget that can be added to any profile page
class ProfileChatSection extends StatefulWidget {
  const ProfileChatSection({super.key});

  @override
  State<ProfileChatSection> createState() => _ProfileChatSectionState();
}

class _ProfileChatSectionState extends State<ProfileChatSection> {
  String? currentUserId;
  int totalUnreadMessages = 0;

  @override
  void initState() {
    super.initState();
    _loadCurrentUser();
  }

  Future<void> _loadCurrentUser() async {
    currentUserId = await SharedpreferenceHelper().getUserId();
    if (currentUserId != null) {
      _loadUnreadCount();
    }
  }

  Future<void> _loadUnreadCount() async {
    try {
      int count =
          await DatabaseMethods().getTotalUnreadMessageCount(currentUserId!);
      if (mounted) {
        setState(() {
          totalUnreadMessages = count;
        });
      }
    } catch (e) {
      print('Error loading unread count: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.shade200,
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Colors.blue.shade400, Colors.blue.shade600],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(15),
                topRight: Radius.circular(15),
              ),
            ),
            child: Row(
              children: [
                const Icon(Icons.chat_bubble, color: Colors.white, size: 24),
                const SizedBox(width: 12),
                const Text(
                  'Connect & Chat',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const Spacer(),
                if (totalUnreadMessages > 0)
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.red,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      totalUnreadMessages.toString(),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
              ],
            ),
          ),

          // Quick Stats
          Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                Expanded(
                  child: _buildStatCard(
                    icon: Icons.people,
                    title: 'All Users',
                    subtitle: 'Find & Connect',
                    color: Colors.blue,
                    onTap: () => _navigateToUsersSection(0),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildStatCard(
                    icon: Icons.chat,
                    title: 'My Chats',
                    subtitle: totalUnreadMessages > 0
                        ? '$totalUnreadMessages new'
                        : 'Messages',
                    color: Colors.green,
                    onTap: () => _navigateToUsersSection(1),
                  ),
                ),
              ],
            ),
          ),

          // Recent Chats
          Padding(
            padding: const EdgeInsets.only(left: 20, right: 20, bottom: 10),
            child: Text(
              'Recent Chats',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Colors.grey.shade800,
              ),
            ),
          ),

          // Recent chats list
          currentUserId == null
              ? const SizedBox(
                  height: 120,
                  child: Center(child: CircularProgressIndicator()),
                )
              : StreamBuilder<QuerySnapshot>(
                  // Use the same fixed query as in AllUsersSection
                  stream: FirebaseFirestore.instance
                      .collection('private_chats')
                      .where('participants', arrayContains: currentUserId!)
                      .snapshots(), // Remove orderBy to avoid index requirement
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const SizedBox(
                        height: 80,
                        child: Center(child: CircularProgressIndicator()),
                      );
                    }

                    if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                      return Container(
                        height: 80,
                        margin: const EdgeInsets.symmetric(horizontal: 20),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade50,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Center(
                          child: Text(
                            'No chats yet. Start a conversation',
                            style: TextStyle(
                              color: Colors.grey.shade600,
                              fontSize: 14,
                            ),
                          ),
                        ),
                      );
                    }

                    // Sort the documents manually by lastMessageTime
                    List<DocumentSnapshot> sortedChats =
                        snapshot.data!.docs.toList();
                    sortedChats.sort((a, b) {
                      Map<String, dynamic> dataA =
                          a.data() as Map<String, dynamic>;
                      Map<String, dynamic> dataB =
                          b.data() as Map<String, dynamic>;

                      Timestamp? timeA = dataA['lastMessageTime'] as Timestamp?;
                      Timestamp? timeB = dataB['lastMessageTime'] as Timestamp?;

                      if (timeA == null && timeB == null) return 0;
                      if (timeA == null) return 1;
                      if (timeB == null) return -1;

                      return timeB.compareTo(timeA); // Descending order
                    });

                    // Show only first 3 recent chats
                    List<DocumentSnapshot> recentChats =
                        sortedChats.take(3).toList();

                    return Column(
                      children: recentChats.map((chatDoc) {
                        return _buildRecentChatItem(chatDoc);
                      }).toList(),
                    );
                  },
                ),

          // View All Button
          Padding(
            padding: const EdgeInsets.all(20),
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => _navigateToUsersSection(1),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue.shade50,
                  foregroundColor: Colors.blue.shade700,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  elevation: 0,
                ),
                child: const Text(
                  'View All Chats & Users',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 28),
            const SizedBox(height: 8),
            Text(
              title,
              style: TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 14,
                color: Colors.grey.shade800,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              subtitle,
              style: TextStyle(
                fontSize: 12,
                color: color,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRecentChatItem(DocumentSnapshot chatDoc) {
    Map<String, dynamic> chatData = chatDoc.data() as Map<String, dynamic>;

    // Get other participant details with proper null safety
    List<dynamic> participants =
        chatData['participants'] as List<dynamic>? ?? [];
    List<dynamic> participantNames =
        chatData['participantNames'] as List<dynamic>? ?? [];
    List<dynamic> participantImages =
        chatData['participantImages'] as List<dynamic>? ?? [];

    // Find the other participant safely
    String otherUserId = '';
    String otherUserName = 'Unknown';
    String otherUserImage = '';

    if (participants.isNotEmpty && currentUserId != null) {
      int currentUserIndex = participants.indexOf(currentUserId);
      if (currentUserIndex != -1) {
        // Find the other participant index
        int otherIndex = currentUserIndex == 0 ? 1 : 0;

        // Safely get other user details
        if (participants.length > otherIndex) {
          otherUserId = participants[otherIndex]?.toString() ?? '';
        }
        if (participantNames.length > otherIndex) {
          otherUserName = participantNames[otherIndex]?.toString() ?? 'Unknown';
        }
        if (participantImages.length > otherIndex) {
          otherUserImage = participantImages[otherIndex]?.toString() ?? '';
        }
      }
    }

    String lastMessage = chatData['lastMessage']?.toString() ?? '';
    String lastMessageSender = chatData['lastMessageSender']?.toString() ?? '';

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        leading: CircleAvatar(
          radius: 20,
          backgroundColor: Colors.grey.shade300,
          backgroundImage:
              otherUserImage.isNotEmpty ? NetworkImage(otherUserImage) : null,
          child: otherUserImage.isEmpty
              ? Icon(Icons.person, size: 20, color: Colors.grey.shade600)
              : null,
        ),
        title: Text(
          otherUserName,
          style: const TextStyle(
            fontWeight: FontWeight.w500,
            fontSize: 14,
          ),
        ),
        subtitle: Text(
          lastMessage.isNotEmpty
              ? (lastMessageSender == currentUserId
                  ? 'You: $lastMessage'
                  : lastMessage)
              : 'No messages yet',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey.shade600,
          ),
        ),
        trailing: FutureBuilder<int>(
          future: _getChatUnreadCount(chatDoc.id),
          builder: (context, snapshot) {
            int unreadCount = snapshot.data ?? 0;
            if (unreadCount > 0) {
              return Container(
                padding: const EdgeInsets.all(6),
                decoration: const BoxDecoration(
                  color: Colors.red,
                  shape: BoxShape.circle,
                ),
                child: Text(
                  unreadCount.toString(),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              );
            }
            return const SizedBox.shrink();
          },
        ),
        onTap: () => _openChat(otherUserId, otherUserName, otherUserImage),
      ),
    );
  }

  // Helper method to get unread count for a chat
  Future<int> _getChatUnreadCount(String chatId) async {
    try {
      if (currentUserId == null) return 0;

      QuerySnapshot unreadMessages = await FirebaseFirestore.instance
          .collection('private_chats')
          .doc(chatId)
          .collection('messages')
          .where('receiverId', isEqualTo: currentUserId!)
          .where('isRead', isEqualTo: false)
          .get();

      return unreadMessages.docs.length;
    } catch (e) {
      print('Error getting chat unread count: $e');
      return 0;
    }
  }

  void _navigateToUsersSection(int tabIndex) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => AllUsersSection(initialTabIndex: tabIndex),
      ),
    ).then((_) {
      // Refresh unread count when coming back
      if (currentUserId != null) {
        _loadUnreadCount();
      }
    });
  }

  void _openChat(
      String otherUserId, String otherUserName, String otherUserImage) {
    if (otherUserId.isEmpty) {
      // Handle case where otherUserId is empty
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Unable to open chat - user not found')),
      );
      return;
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => PrivateChatPage(
          otherUserId: otherUserId,
          otherUserName: otherUserName,
          otherUserImage: otherUserImage,
        ),
      ),
    ).then((_) {
      // Refresh unread count when coming back
      if (currentUserId != null) {
        _loadUnreadCount();
      }
    });
  }
}
