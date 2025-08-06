import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:traveltest_app/services/database.dart';
import 'package:traveltest_app/services/shared_pref.dart';
import 'package:traveltest_app/private_chat_page.dart';

class AllUsersSection extends StatefulWidget {
  final int initialTabIndex;

  const AllUsersSection({super.key, this.initialTabIndex = 0});

  @override
  State<AllUsersSection> createState() => _AllUsersSectionState();
}

class _AllUsersSectionState extends State<AllUsersSection>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  String? currentUserId;
  TextEditingController searchController = TextEditingController();
  String searchQuery = "";

  @override
  void initState() {
    super.initState();
    _tabController = TabController(
      length: 2,
      vsync: this,
      initialIndex: widget.initialTabIndex,
    );
    _getCurrentUserId();
  }

  @override
  void dispose() {
    _tabController.dispose();
    searchController.dispose();
    super.dispose();
  }

  Future<void> _getCurrentUserId() async {
    currentUserId = await SharedpreferenceHelper().getUserId();
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 1,
        title: Text(
          'Connect & Chat',
          style: TextStyle(
            color: Colors.black,
            fontWeight: FontWeight.w600,
          ),
        ),
        bottom: TabBar(
          controller: _tabController,
          labelColor: Colors.blue,
          unselectedLabelColor: Colors.grey,
          indicatorColor: Colors.blue,
          tabs: [
            Tab(
              icon: Icon(Icons.people),
              text: 'All Users',
            ),
            Tab(
              icon: Icon(Icons.chat),
              text: 'My Chats',
            ),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildAllUsersTab(),
          _buildMyChatsTab(),
        ],
      ),
    );
  }

  Widget _buildAllUsersTab() {
    return Column(
      children: [
        // Search Bar
        Container(
          margin: EdgeInsets.all(16),
          padding: EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(25),
            boxShadow: [
              BoxShadow(
                color: Colors.grey.shade200,
                blurRadius: 5,
                offset: Offset(0, 2),
              ),
            ],
          ),
          child: TextField(
            controller: searchController,
            decoration: InputDecoration(
              hintText: 'Search users...',
              border: InputBorder.none,
              prefixIcon: Icon(Icons.search, color: Colors.grey),
              suffixIcon: searchQuery.isNotEmpty
                  ? IconButton(
                      icon: Icon(Icons.clear),
                      onPressed: () {
                        searchController.clear();
                        setState(() {
                          searchQuery = "";
                        });
                      },
                    )
                  : null,
            ),
            onChanged: (value) {
              setState(() {
                searchQuery = value;
              });
            },
          ),
        ),

        // Users List
        Expanded(
          child: StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance.collection('users').snapshots(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return Center(child: CircularProgressIndicator());
              }

              if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.people_outline, size: 60, color: Colors.grey),
                      SizedBox(height: 16),
                      Text(
                        'No users found',
                        style: TextStyle(
                          fontSize: 18,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                );
              }

              Map<String, DocumentSnapshot> uniqueUsers = {};
              List<DocumentSnapshot> allDocs = snapshot.data!.docs;

              for (DocumentSnapshot doc in allDocs) {
                Map<String, dynamic> userData =
                    doc.data() as Map<String, dynamic>;
                String userEmail =
                    userData['Email']?.toString().toLowerCase().trim() ?? '';
                String userId = userData['Id'] ?? '';

                // current user
                if (userId == currentUserId) continue;

                // Skip  without email
                if (userEmail.isEmpty) continue;

                // email already exists
                if (uniqueUsers.containsKey(userEmail)) {
                  Map<String, dynamic> existingUserData =
                      uniqueUsers[userEmail]!.data() as Map<String, dynamic>;

                  Timestamp? existingTime = existingUserData['lastUpdated'] ??
                      existingUserData['createdAt'];
                  Timestamp? currentTime =
                      userData['lastUpdated'] ?? userData['createdAt'];

                  // Keep the user with latest timestamp
                  if (currentTime != null &&
                      (existingTime == null ||
                          currentTime.compareTo(existingTime) > 0)) {
                    uniqueUsers[userEmail] = doc;
                  }
                } else {
                  // First user with this email
                  uniqueUsers[userEmail] = doc;
                }
              }

              // Convert back to list and apply search filter
              List<DocumentSnapshot> filteredUsers =
                  uniqueUsers.values.where((doc) {
                Map<String, dynamic> userData =
                    doc.data() as Map<String, dynamic>;
                String userName =
                    userData['UserName']?.toString().toLowerCase() ?? '';
                String userEmail =
                    userData['Email']?.toString().toLowerCase() ?? '';

                // Apply search filter
                if (searchQuery.isNotEmpty) {
                  return userName.contains(searchQuery.toLowerCase()) ||
                      userEmail.contains(searchQuery.toLowerCase());
                }
                return true;
              }).toList();

              // Show empty state if no users found
              if (filteredUsers.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.search_off, size: 60, color: Colors.grey),
                      SizedBox(height: 16),
                      Text(
                        searchQuery.isNotEmpty
                            ? 'No users found for "$searchQuery"'
                            : 'No other users available',
                        style: TextStyle(
                          fontSize: 16,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                );
              }

              //
              filteredUsers.sort((a, b) {
                Map<String, dynamic> dataA = a.data() as Map<String, dynamic>;
                Map<String, dynamic> dataB = b.data() as Map<String, dynamic>;
                String nameA = dataA['UserName']?.toString() ?? '';
                String nameB = dataB['UserName']?.toString() ?? '';
                return nameA.toLowerCase().compareTo(nameB.toLowerCase());
              });

              return ListView.builder(
                padding: EdgeInsets.symmetric(horizontal: 16),
                itemCount: filteredUsers.length,
                itemBuilder: (context, index) {
                  return _buildUserCard(filteredUsers[index]);
                },
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildUserCard(DocumentSnapshot userDoc) {
    Map<String, dynamic> userData = userDoc.data() as Map<String, dynamic>;
    String userName = userData['UserName'] ?? 'Unknown User';
    String userEmail = userData['Email'] ?? '';
    String userImage = userData['Image'] ?? '';
    String userId = userData['Id'] ?? '';

    return Container(
      margin: EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.shade200,
            blurRadius: 5,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: ListTile(
        contentPadding: EdgeInsets.all(16),
        leading: CircleAvatar(
          radius: 25,
          backgroundColor: Colors.grey.shade300,
          // Fixed image loading with cache buster
          backgroundImage: userImage.isNotEmpty
              ? NetworkImage(userImage.contains('?')
                  ? userImage
                  : '$userImage?v=${DateTime.now().millisecondsSinceEpoch}')
              : null,
          child: userImage.isEmpty
              ? Icon(Icons.person, color: Colors.grey.shade600)
              : null,
        ),
        title: Text(
          userName,
          style: TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 16,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(height: 4),
            Text(
              userEmail,
              style: TextStyle(
                color: Colors.grey.shade600,
                fontSize: 14,
              ),
            ),
            SizedBox(height: 8),
            // Online status with real-time updates
            StreamBuilder<DocumentSnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('users')
                  .doc(userId)
                  .snapshots(),
              builder: (context, snapshot) {
                bool isOnline = false;
                if (snapshot.hasData && snapshot.data!.exists) {
                  Map<String, dynamic> data =
                      snapshot.data!.data() as Map<String, dynamic>;
                  isOnline = data['isOnline'] ?? false;
                }

                return Row(
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: isOnline ? Colors.green : Colors.grey,
                        shape: BoxShape.circle,
                      ),
                    ),
                    SizedBox(width: 6),
                    Text(
                      isOnline ? 'Online' : 'Offline',
                      style: TextStyle(
                        color: isOnline ? Colors.green : Colors.grey,
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                );
              },
            ),
          ],
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Follow/Unfollow Button
            FutureBuilder<bool>(
              future:
                  DatabaseMethods().isFollowing(currentUserId ?? '', userId),
              builder: (context, snapshot) {
                bool isFollowing = snapshot.data ?? false;

                return IconButton(
                  icon: Icon(
                    isFollowing ? Icons.person_remove : Icons.person_add,
                    color: isFollowing ? Colors.red : Colors.blue,
                  ),
                  onPressed: () => _toggleFollow(userId, isFollowing),
                );
              },
            ),

            // Chat Button
            IconButton(
              icon: Icon(Icons.chat_bubble, color: Colors.green),
              onPressed: () => _startChat(userId, userName, userImage),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMyChatsTab() {
    if (currentUserId == null) {
      return Center(child: CircularProgressIndicator());
    }

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('private_chats')
          .where('participants', arrayContains: currentUserId!)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Center(child: CircularProgressIndicator());
        }

        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.chat_bubble_outline, size: 60, color: Colors.grey),
                SizedBox(height: 16),
                Text(
                  'No chats yet',
                  style: TextStyle(
                    fontSize: 18,
                    color: Colors.grey.shade600,
                  ),
                ),
                SizedBox(height: 8),
                Text(
                  'Start a conversation from the Users tab!',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey.shade500,
                  ),
                ),
              ],
            ),
          );
        }

        // Sort chats by last message time
        List<DocumentSnapshot> sortedChats = snapshot.data!.docs.toList();
        sortedChats.sort((a, b) {
          Map<String, dynamic> dataA = a.data() as Map<String, dynamic>;
          Map<String, dynamic> dataB = b.data() as Map<String, dynamic>;

          Timestamp? timeA = dataA['lastMessageTime'];
          Timestamp? timeB = dataB['lastMessageTime'];

          if (timeA == null && timeB == null) return 0;
          if (timeA == null) return 1;
          if (timeB == null) return -1;

          return timeB.compareTo(timeA); // Newest first
        });

        return ListView.builder(
          padding: EdgeInsets.all(16),
          itemCount: sortedChats.length,
          itemBuilder: (context, index) {
            return _buildChatCard(sortedChats[index]);
          },
        );
      },
    );
  }

  Widget _buildChatCard(DocumentSnapshot chatDoc) {
    Map<String, dynamic> chatData = chatDoc.data() as Map<String, dynamic>;

    // Get other participant details
    Map<String, String> otherUser =
        DatabaseMethods().getOtherParticipant(chatData, currentUserId!);

    String lastMessage = chatData['lastMessage'] ?? '';
    Timestamp? lastMessageTime = chatData['lastMessageTime'];
    String lastMessageSender = chatData['lastMessageSender'] ?? '';

    return Container(
      margin: EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.shade200,
            blurRadius: 5,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: ListTile(
        contentPadding: EdgeInsets.all(16),
        leading: Stack(
          children: [
            CircleAvatar(
              radius: 25,
              backgroundColor: Colors.grey.shade300,
              backgroundImage: otherUser['image']!.isNotEmpty
                  ? NetworkImage(otherUser['image']!.contains('?')
                      ? otherUser['image']!
                      : '${otherUser['image']!}?v=${DateTime.now().millisecondsSinceEpoch}')
                  : null,
              child: otherUser['image']!.isEmpty
                  ? Icon(Icons.person, color: Colors.grey.shade600)
                  : null,
            ),
            // Unread indicator
            FutureBuilder<int>(
              future: DatabaseMethods()
                  .getChatUnreadCount(chatDoc.id, currentUserId!),
              builder: (context, snapshot) {
                int unreadCount = snapshot.data ?? 0;
                if (unreadCount > 0) {
                  return Positioned(
                    right: 0,
                    top: 0,
                    child: Container(
                      padding: EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: Colors.red,
                        shape: BoxShape.circle,
                      ),
                      child: Text(
                        unreadCount > 99 ? '99+' : unreadCount.toString(),
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  );
                }
                return SizedBox.shrink();
              },
            ),
          ],
        ),
        title: Text(
          otherUser['name']!,
          style: TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 16,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(height: 4),
            Text(
              lastMessage.isNotEmpty
                  ? (lastMessageSender == currentUserId
                      ? 'You: $lastMessage'
                      : lastMessage)
                  : 'No messages yet',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: Colors.grey.shade600,
                fontSize: 14,
              ),
            ),
            SizedBox(height: 4),
            Text(
              _formatChatTime(lastMessageTime),
              style: TextStyle(
                color: Colors.grey.shade500,
                fontSize: 12,
              ),
            ),
          ],
        ),
        trailing: Icon(
          Icons.arrow_forward_ios,
          size: 16,
          color: Colors.grey.shade400,
        ),
        onTap: () => _openChat(
            otherUser['id']!, otherUser['name']!, otherUser['image']!),
      ),
    );
  }

  String _formatChatTime(Timestamp? timestamp) {
    if (timestamp == null) return '';

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

  Future<void> _toggleFollow(
      String targetUserId, bool isCurrentlyFollowing) async {
    try {
      if (isCurrentlyFollowing) {
        await DatabaseMethods().unfollowUser(currentUserId!, targetUserId);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Unfollowed successfully')),
        );
      } else {
        await DatabaseMethods().followUser(currentUserId!, targetUserId);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Following successfully')),
        );
      }
      setState(() {}); // Refresh the UI
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    }
  }

  Future<void> _startChat(
      String otherUserId, String otherUserName, String otherUserImage) async {
    try {
      // Initialize chat if it doesn't exist
      String chatId =
          DatabaseMethods.generateChatId(currentUserId!, otherUserId);

      String? currentUserName = await SharedpreferenceHelper().getUserName();
      String? currentUserImage = await SharedpreferenceHelper().getUserImage();

      await DatabaseMethods().initializePrivateChat(
        chatId: chatId,
        currentUserId: currentUserId!,
        currentUserName: currentUserName ?? 'User',
        currentUserImage: currentUserImage ?? '',
        otherUserId: otherUserId,
        otherUserName: otherUserName,
        otherUserImage: otherUserImage,
      );

      _openChat(otherUserId, otherUserName, otherUserImage);
    } catch (e) {
      print('Error starting chat: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error starting chat. Please try again.')),
      );
    }
  }

  void _openChat(
      String otherUserId, String otherUserName, String otherUserImage) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => PrivateChatPage(
          otherUserId: otherUserId,
          otherUserName: otherUserName,
          otherUserImage: otherUserImage,
        ),
      ),
    );
  }
}
