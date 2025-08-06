import 'package:cloud_firestore/cloud_firestore.dart';

class DatabaseMethods {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // User Management Methods
  Future<void> addUserDetails(
      Map<String, dynamic> userInfoMap, String id) async {
    try {
      await _firestore.collection("users").doc(id).set(userInfoMap);
    } catch (e) {
      print("Error adding user details: $e");
    }
  }

  Future<QuerySnapshot> getUserByEmail(String email) async {
    return await _firestore
        .collection("users")
        .where("email", isEqualTo: email)
        .get();
  }

  Future<void> updateUserDetails(
      Map<String, dynamic> userInfoMap, String id) async {
    try {
      await _firestore.collection("users").doc(id).update(userInfoMap);
      print("User details updated successfully");
    } catch (e) {
      print("Error updating user details: $e");
      throw e; // Re-throw to handle in calling function
    }
  }

  Future<Map<String, dynamic>?> getUserDetails(String id) async {
    try {
      DocumentSnapshot snapshot =
          await _firestore.collection("users").doc(id).get();

      if (snapshot.exists) {
        return snapshot.data() as Map<String, dynamic>?;
      }
      return null;
    } catch (e) {
      print("Error getting user details: $e");
      return null;
    }
  }

  // Post Management Methods
  Future<void> addPost(Map<String, dynamic> postInfo, String id) async {
    try {
      // Add timestamp if not provided
      if (!postInfo.containsKey('Timestamp')) {
        postInfo['Timestamp'] = DateTime.now().millisecondsSinceEpoch;
      }
      await _firestore.collection("Posts").doc(id).set(postInfo);
    } catch (e) {
      print("Error adding post: $e");
    }
  }

  Stream<QuerySnapshot> getPosts() {
    return _firestore
        .collection("Posts")
        .orderBy("Timestamp", descending: true)
        .snapshots();
  }

  Stream<QuerySnapshot> getPostsPlace(String place) {
    return _firestore
        .collection("Posts")
        .where("CityName", isEqualTo: place)
        .snapshots();
  }

  // Method to get posts by user ID
  Stream<QuerySnapshot> getPostsByUser(String userId) {
    return _firestore
        .collection("Posts")
        .where("UserId", isEqualTo: userId)
        .orderBy("Timestamp", descending: true)
        .snapshots();
  }

  // Method to delete post
  Future<void> deletePost(String postId) async {
    try {
      // First delete all comments in the post
      QuerySnapshot comments = await _firestore
          .collection("Posts")
          .doc(postId)
          .collection("Comment")
          .get();

      WriteBatch batch = _firestore.batch();

      // Delete all comments
      for (DocumentSnapshot comment in comments.docs) {
        batch.delete(comment.reference);
      }

      // Delete the post
      batch.delete(_firestore.collection("Posts").doc(postId));

      await batch.commit();
      print("Post and all comments deleted successfully");
    } catch (e) {
      print("Error deleting post: $e");
      throw e;
    }
  }

  // Method to update post
  Future<void> updatePost(
      String postId, Map<String, dynamic> updatedData) async {
    try {
      // Add update timestamp
      updatedData['UpdatedAt'] = DateTime.now().millisecondsSinceEpoch;
      await _firestore.collection("Posts").doc(postId).update(updatedData);
      print("Post updated successfully");
    } catch (e) {
      print("Error updating post: $e");
      throw e;
    }
  }

  // Like Management Methods
  Future<void> addLike(String postId, String userId) async {
    try {
      await _firestore.collection("Posts").doc(postId).update({
        'Like': FieldValue.arrayUnion([userId])
      });
    } catch (e) {
      print("Error adding like: $e");
    }
  }

  Future<void> removeLike(String postId, String userId) async {
    try {
      await _firestore.collection("Posts").doc(postId).update({
        'Like': FieldValue.arrayRemove([userId])
      });
    } catch (e) {
      print("Error removing like: $e");
    }
  }

  // Method to get posts liked by user
  Stream<QuerySnapshot> getLikedPostsByUser(String userId) {
    return _firestore
        .collection("Posts")
        .where("Like", arrayContains: userId)
        .orderBy("Timestamp", descending: true)
        .snapshots();
  }

  // Enhanced Comment Management Methods
  Future<void> addComment(
      Map<String, dynamic> commentData, String postId) async {
    try {
      // Add timestamp if not provided
      if (!commentData.containsKey('Timestamp')) {
        commentData['Timestamp'] = DateTime.now().millisecondsSinceEpoch;
      }

      await _firestore
          .collection("Posts")
          .doc(postId)
          .collection("Comment")
          .add(commentData);
      print("Comment added successfully");
    } catch (e) {
      print("Error adding comment: $e");
      throw e;
    }
  }

  Stream<QuerySnapshot> getComments(String postId) {
    return _firestore
        .collection("Posts")
        .doc(postId)
        .collection("Comment")
        .orderBy("Timestamp", descending: false)
        .snapshots();
  }

  // Method to delete comment
  Future<void> deleteComment(String postId, String commentId) async {
    try {
      await _firestore
          .collection("Posts")
          .doc(postId)
          .collection("Comment")
          .doc(commentId)
          .delete();
      print("Comment deleted successfully");
    } catch (e) {
      print("Error deleting comment: $e");
      throw e;
    }
  }

  // Method to update comment
  Future<void> updateComment(
      String postId, String commentId, Map<String, dynamic> updatedData) async {
    try {
      // Add update timestamp
      updatedData['UpdatedAt'] = DateTime.now().millisecondsSinceEpoch;

      await _firestore
          .collection("Posts")
          .doc(postId)
          .collection("Comment")
          .doc(commentId)
          .update(updatedData);
      print("Comment updated successfully");
    } catch (e) {
      print("Error updating comment: $e");
      throw e;
    }
  }

  // Method to get comment count for a post
  Future<int> getCommentCount(String postId) async {
    try {
      QuerySnapshot snapshot = await _firestore
          .collection("Posts")
          .doc(postId)
          .collection("Comment")
          .get();
      return snapshot.docs.length;
    } catch (e) {
      print("Error getting comment count: $e");
      return 0;
    }
  }

  // Method to get comments by user
  Stream<QuerySnapshot> getCommentsByUser(String userId) {
    return _firestore
        .collectionGroup("Comment") // Search across all comment subcollections
        .where("UserId", isEqualTo: userId)
        .orderBy("Timestamp", descending: true)
        .snapshots();
  }

  // Search Methods
  Future<QuerySnapshot> search(String updatedName) async {
    return await _firestore
        .collection("Location")
        .where("SearchKey",
            isEqualTo: updatedName.substring(0, 1).toUpperCase())
        .get();
  }

  // Method to search posts by place name
  Future<QuerySnapshot> searchPosts(String searchTerm) async {
    return await _firestore
        .collection("Posts")
        .where("PlaceName", isGreaterThanOrEqualTo: searchTerm)
        .where("PlaceName", isLessThanOrEqualTo: '$searchTerm\uf8ff')
        .get();
  }

  // Method to search posts by city name
  Future<QuerySnapshot> searchPostsByCity(String cityName) async {
    return await _firestore
        .collection("Posts")
        .where("CityName", isGreaterThanOrEqualTo: cityName)
        .where("CityName", isLessThanOrEqualTo: '$cityName\uf8ff')
        .get();
  }

  // Advanced search method
  Future<QuerySnapshot> searchPostsAdvanced({
    String? placeName,
    String? cityName,
    String? userName,
    int? limit,
  }) async {
    Query query = _firestore.collection("Posts");

    if (placeName != null && placeName.isNotEmpty) {
      query = query
          .where("PlaceName", isGreaterThanOrEqualTo: placeName)
          .where("PlaceName", isLessThanOrEqualTo: '$placeName\uf8ff');
    }

    if (cityName != null && cityName.isNotEmpty) {
      query = query
          .where("CityName", isGreaterThanOrEqualTo: cityName)
          .where("CityName", isLessThanOrEqualTo: '$cityName\uf8ff');
    }

    if (userName != null && userName.isNotEmpty) {
      query = query
          .where("Name", isGreaterThanOrEqualTo: userName)
          .where("Name", isLessThanOrEqualTo: '$userName\uf8ff');
    }

    query = query.orderBy("Timestamp", descending: true);

    if (limit != null) {
      query = query.limit(limit);
    }

    return await query.get();
  }

  // Location Management Methods
  Future<void> addLocation(Map<String, dynamic> locationInfo, String id) async {
    try {
      await _firestore.collection("Location").doc(id).set(locationInfo);
    } catch (e) {
      print("Error adding location: $e");
    }
  }

  Stream<QuerySnapshot> getLocations() {
    return _firestore.collection("Location").snapshots();
  }

  // Method to get popular locations (most posted about)
  Future<QuerySnapshot> getPopularLocations() async {
    return await _firestore
        .collection("Location")
        .orderBy("PostCount", descending: true)
        .limit(10)
        .get();
  }

  // Method to increment location post count
  Future<void> incrementLocationPostCount(String locationName) async {
    try {
      QuerySnapshot locationQuery = await _firestore
          .collection("Location")
          .where("Name", isEqualTo: locationName)
          .get();

      if (locationQuery.docs.isNotEmpty) {
        // Location exists, increment count
        DocumentReference locationRef = locationQuery.docs.first.reference;
        await locationRef.update({
          'PostCount': FieldValue.increment(1),
        });
      } else {
        // Location doesn't exist, create new with count 1
        await _firestore.collection("Location").add({
          'Name': locationName,
          'PostCount': 1,
          'SearchKey': locationName.substring(0, 1).toUpperCase(),
          'CreatedAt': DateTime.now().millisecondsSinceEpoch,
        });
      }
    } catch (e) {
      print("Error updating location post count: $e");
    }
  }

  // Follow/Following System
  Future<void> followUser(String currentUserId, String targetUserId) async {
    try {
      // Add to following list
      await _firestore.collection("users").doc(currentUserId).update({
        'Following': FieldValue.arrayUnion([targetUserId])
      });

      // Add to followers list
      await _firestore.collection("users").doc(targetUserId).update({
        'Followers': FieldValue.arrayUnion([currentUserId])
      });

      // Create notification for followed user
      await addNotification({
        'Type': 'follow',
        'Message': 'started following you',
        'FromUserId': currentUserId,
        'Timestamp': DateTime.now().millisecondsSinceEpoch,
        'IsRead': false,
      }, targetUserId);
    } catch (e) {
      print("Error following user: $e");
    }
  }

  Future<void> unfollowUser(String currentUserId, String targetUserId) async {
    try {
      // Remove from following list
      await _firestore.collection("users").doc(currentUserId).update({
        'Following': FieldValue.arrayRemove([targetUserId])
      });

      // Remove from followers list
      await _firestore.collection("users").doc(targetUserId).update({
        'Followers': FieldValue.arrayRemove([currentUserId])
      });
    } catch (e) {
      print("Error unfollowing user: $e");
    }
  }

  // Method to get following users' posts
  Stream<QuerySnapshot> getFollowingPosts(List<String> followingList) {
    if (followingList.isEmpty) {
      // Return empty stream if not following anyone
      return Stream.empty();
    }

    return _firestore
        .collection("Posts")
        .where("UserId", whereIn: followingList)
        .orderBy("Timestamp", descending: true)
        .snapshots();
  }

  // Method to check if user is following another user
  Future<bool> isFollowing(String currentUserId, String targetUserId) async {
    try {
      DocumentSnapshot userDoc =
          await _firestore.collection("users").doc(currentUserId).get();

      if (userDoc.exists) {
        List following = userDoc.get('Following') ?? [];
        return following.contains(targetUserId);
      }
      return false;
    } catch (e) {
      print("Error checking follow status: $e");
      return false;
    }
  }

  // Analytics Methods
  Future<int> getUserPostCount(String userId) async {
    try {
      QuerySnapshot snapshot = await _firestore
          .collection("Posts")
          .where("UserId", isEqualTo: userId)
          .get();
      return snapshot.docs.length;
    } catch (e) {
      print("Error getting post count: $e");
      return 0;
    }
  }

  Future<int> getUserLikeCount(String userId) async {
    try {
      QuerySnapshot snapshot = await _firestore
          .collection("Posts")
          .where("UserId", isEqualTo: userId)
          .get();

      int totalLikes = 0;
      for (DocumentSnapshot doc in snapshot.docs) {
        List likes = doc.get('Like') ?? [];
        totalLikes += likes.length;
      }
      return totalLikes;
    } catch (e) {
      print("Error getting like count: $e");
      return 0;
    }
  }

  // Method to get user's follower count
  Future<int> getFollowerCount(String userId) async {
    try {
      DocumentSnapshot userDoc =
          await _firestore.collection("users").doc(userId).get();

      if (userDoc.exists) {
        List followers = userDoc.get('Followers') ?? [];
        return followers.length;
      }
      return 0;
    } catch (e) {
      print("Error getting follower count: $e");
      return 0;
    }
  }

  // Method to get user's following count
  Future<int> getFollowingCount(String userId) async {
    try {
      DocumentSnapshot userDoc =
          await _firestore.collection("users").doc(userId).get();

      if (userDoc.exists) {
        List following = userDoc.get('Following') ?? [];
        return following.length;
      }
      return 0;
    } catch (e) {
      print("Error getting following count: $e");
      return 0;
    }
  }

  // Notification Methods
  Future<void> addNotification(
      Map<String, dynamic> notificationData, String userId) async {
    try {
      await _firestore
          .collection("users")
          .doc(userId)
          .collection("Notifications")
          .add(notificationData);
    } catch (e) {
      print("Error adding notification: $e");
    }
  }

  Stream<QuerySnapshot> getNotifications(String userId) {
    return _firestore
        .collection("users")
        .doc(userId)
        .collection("Notifications")
        .orderBy("Timestamp", descending: true)
        .snapshots();
  }

  // Method to mark notification as read
  Future<void> markNotificationAsRead(
      String userId, String notificationId) async {
    try {
      await _firestore
          .collection("users")
          .doc(userId)
          .collection("Notifications")
          .doc(notificationId)
          .update({"IsRead": true});
    } catch (e) {
      print("Error marking notification as read: $e");
    }
  }

  // Method to get unread notification count
  Future<int> getUnreadNotificationCount(String userId) async {
    try {
      QuerySnapshot snapshot = await _firestore
          .collection("users")
          .doc(userId)
          .collection("Notifications")
          .where("IsRead", isEqualTo: false)
          .get();
      return snapshot.docs.length;
    } catch (e) {
      print("Error getting unread notification count: $e");
      return 0;
    }
  }

  // ========== ENHANCED PRIVATE MESSAGING METHODS ==========

  // Send a private message between users
  Future<void> sendPrivateMessage({
    required String chatId,
    required String senderId,
    required String senderName,
    required String senderImage,
    required String message,
    required String receiverId,
  }) async {
    try {
      // Add message to messages subcollection
      await _firestore
          .collection('private_chats')
          .doc(chatId)
          .collection('messages')
          .add({
        'senderId': senderId,
        'senderName': senderName,
        'senderImage': senderImage,
        'receiverId': receiverId,
        'message': message,
        'timestamp': FieldValue.serverTimestamp(),
        'isRead': false,
        'messageType': 'text',
      });

      // Update chat document with last message info
      await _firestore.collection('private_chats').doc(chatId).update({
        'lastMessage': message,
        'lastMessageTime': FieldValue.serverTimestamp(),
        'lastMessageSender': senderId,
        '${senderId}_typing': false,
      });

      // Update unread count for receiver
      await updateUnreadCount(receiverId, chatId);
    } catch (e) {
      throw Exception('Failed to send message: $e');
    }
  }

  // Enhanced method for updating unread count
  Future<void> updateUnreadCount(String userId, String chatId) async {
    try {
      DocumentReference userRef = _firestore.collection('users').doc(userId);

      await _firestore.runTransaction((transaction) async {
        DocumentSnapshot userDoc = await transaction.get(userRef);

        Map<String, dynamic> unreadChats = {};
        if (userDoc.exists && userDoc.data() != null) {
          Map<String, dynamic> userData =
              userDoc.data() as Map<String, dynamic>;
          unreadChats = userData['unreadChats'] ?? {};
        }

        unreadChats[chatId] = (unreadChats[chatId] ?? 0) + 1;

        transaction.update(userRef, {'unreadChats': unreadChats});
      });
    } catch (e) {
      print('Error updating unread count: $e');
    }
  }

  // Method to update typing status
  Future<void> updateTypingStatus(
      String chatId, String userId, bool isTyping) async {
    try {
      await _firestore.collection('private_chats').doc(chatId).update({
        '${userId}_typing': isTyping,
        '${userId}_lastSeen': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      print('Error updating typing status: $e');
    }
  }

  // Method to get chat typing status
  Stream<DocumentSnapshot> getChatStatus(String chatId) {
    return _firestore.collection('private_chats').doc(chatId).snapshots();
  }

  // Method to send reply message
  Future<void> sendReplyMessage({
    required String chatId,
    required String senderId,
    required String senderName,
    required String senderImage,
    required String message,
    required String receiverId,
    required String replyToMessageId,
    required String replyToMessage,
    required String replyToSender,
  }) async {
    try {
      // Add reply message to messages subcollection
      await _firestore
          .collection('private_chats')
          .doc(chatId)
          .collection('messages')
          .add({
        'senderId': senderId,
        'senderName': senderName,
        'senderImage': senderImage,
        'receiverId': receiverId,
        'message': message,
        'timestamp': FieldValue.serverTimestamp(),
        'isRead': false,
        'isReply': true,
        'replyToMessageId': replyToMessageId,
        'replyToMessage': replyToMessage,
        'replyToSender': replyToSender,
        'messageType': 'text',
      });

      // Update chat document with last message info
      await _firestore.collection('private_chats').doc(chatId).update({
        'lastMessage': message,
        'lastMessageTime': FieldValue.serverTimestamp(),
        'lastMessageSender': senderId,
        '${senderId}_typing': false,
      });

      // Update unread count for receiver
      await updateUnreadCount(receiverId, chatId);
    } catch (e) {
      throw Exception('Failed to send reply message: $e');
    }
  }

  // Method to delete a message
  Future<void> deleteMessage(String chatId, String messageId) async {
    try {
      await _firestore
          .collection('private_chats')
          .doc(chatId)
          .collection('messages')
          .doc(messageId)
          .delete();
    } catch (e) {
      print('Error deleting message: $e');
      throw e;
    }
  }

  // Method to mark specific message as read
  Future<void> markMessageAsRead(String chatId, String messageId) async {
    try {
      await _firestore
          .collection('private_chats')
          .doc(chatId)
          .collection('messages')
          .doc(messageId)
          .update({'isRead': true});
    } catch (e) {
      print('Error marking message as read: $e');
    }
  }

  // Method to get unread messages count for a specific chat
  Future<int> getUnreadMessagesCount(String chatId, String userId) async {
    try {
      QuerySnapshot unreadMessages = await _firestore
          .collection('private_chats')
          .doc(chatId)
          .collection('messages')
          .where('receiverId', isEqualTo: userId)
          .where('isRead', isEqualTo: false)
          .get();

      return unreadMessages.docs.length;
    } catch (e) {
      print('Error getting unread messages count: $e');
      return 0;
    }
  }

  // Method to update user's last seen timestamp
  Future<void> updateLastSeen(String userId) async {
    try {
      await _firestore.collection('users').doc(userId).update({
        'lastSeen': FieldValue.serverTimestamp(),
        'isOnline': true,
      });
    } catch (e) {
      print('Error updating last seen: $e');
    }
  }

  // Method to set user offline
  Future<void> setUserOffline(String userId) async {
    try {
      await _firestore.collection('users').doc(userId).update({
        'lastSeen': FieldValue.serverTimestamp(),
        'isOnline': false,
      });
    } catch (e) {
      print('Error setting user offline: $e');
    }
  }

  // Method to get user's online status
  Stream<DocumentSnapshot> getUserOnlineStatus(String userId) {
    return _firestore.collection('users').doc(userId).snapshots();
  }

  // Method to create notification for new message
  Future<void> createMessageNotification({
    required String receiverId,
    required String senderName,
    required String message,
    required String chatId,
  }) async {
    try {
      await addNotification({
        'Type': 'message',
        'Message': '$senderName sent you a message',
        'MessagePreview': message,
        'FromUserId': receiverId,
        'ChatId': chatId,
        'Timestamp': DateTime.now().millisecondsSinceEpoch,
        'IsRead': false,
      }, receiverId);
    } catch (e) {
      print('Error creating message notification: $e');
    }
  }

  // Method to send media message (for future enhancement)
  Future<void> sendMediaMessage({
    required String chatId,
    required String senderId,
    required String senderName,
    required String senderImage,
    required String receiverId,
    required String mediaUrl,
    required String mediaType, // 'image', 'video', 'audio', 'file'
    String? caption,
  }) async {
    try {
      await _firestore
          .collection('private_chats')
          .doc(chatId)
          .collection('messages')
          .add({
        'senderId': senderId,
        'senderName': senderName,
        'senderImage': senderImage,
        'receiverId': receiverId,
        'mediaUrl': mediaUrl,
        'messageType': mediaType,
        'caption': caption,
        'timestamp': FieldValue.serverTimestamp(),
        'isRead': false,
      });

      // Update chat document
      String lastMessage = caption ??
          (mediaType == 'image'
              ? '📷 Photo'
              : mediaType == 'video'
                  ? '🎥 Video'
                  : mediaType == 'audio'
                      ? '🎵 Audio'
                      : '📎 File');

      await _firestore.collection('private_chats').doc(chatId).update({
        'lastMessage': lastMessage,
        'lastMessageTime': FieldValue.serverTimestamp(),
        'lastMessageSender': senderId,
      });

      // Update unread count for receiver
      await updateUnreadCount(receiverId, chatId);
    } catch (e) {
      throw Exception('Failed to send media message: $e');
    }
  }

  // Method to search messages in a chat (enhanced version)
  Future<List<DocumentSnapshot>> searchChatMessages(
      String chatId, String searchQuery) async {
    try {
      QuerySnapshot querySnapshot = await _firestore
          .collection('private_chats')
          .doc(chatId)
          .collection('messages')
          .where('message', isGreaterThanOrEqualTo: searchQuery)
          .where('message', isLessThanOrEqualTo: '$searchQuery\uf8ff')
          .orderBy('message')
          .orderBy('timestamp', descending: true)
          .get();

      return querySnapshot.docs;
    } catch (e) {
      print('Error searching messages: $e');
      return [];
    }
  }

  // Method to get message by ID
  Future<DocumentSnapshot?> getMessageById(
      String chatId, String messageId) async {
    try {
      DocumentSnapshot messageDoc = await _firestore
          .collection('private_chats')
          .doc(chatId)
          .collection('messages')
          .doc(messageId)
          .get();

      return messageDoc.exists ? messageDoc : null;
    } catch (e) {
      print('Error getting message by ID: $e');
      return null;
    }
  }

  // Method to update message (for editing - future enhancement)
  Future<void> updateMessage(
      String chatId, String messageId, Map<String, dynamic> updateData) async {
    try {
      updateData['editedAt'] = FieldValue.serverTimestamp();
      updateData['isEdited'] = true;

      await _firestore
          .collection('private_chats')
          .doc(chatId)
          .collection('messages')
          .doc(messageId)
          .update(updateData);
    } catch (e) {
      print('Error updating message: $e');
      throw e;
    }
  }

  // Get real-time stream of messages for a specific chat
  Stream<QuerySnapshot> getPrivateMessages(String chatId) {
    return _firestore
        .collection('private_chats')
        .doc(chatId)
        .collection('messages')
        .orderBy('timestamp', descending: false)
        .snapshots();
  }

  // Get all chats for a user
  Stream<QuerySnapshot> getUserChats(String userId) {
    return _firestore
        .collection('private_chats')
        .where('participants', arrayContains: userId)
        .orderBy('lastMessageTime', descending: true)
        .snapshots();
  }

  // Mark messages as read when user opens a chat
  Future<void> markMessagesAsRead(String chatId, String userId) async {
    try {
      // Mark messages as read
      QuerySnapshot unreadMessages = await _firestore
          .collection('private_chats')
          .doc(chatId)
          .collection('messages')
          .where('receiverId', isEqualTo: userId)
          .where('isRead', isEqualTo: false)
          .get();

      WriteBatch batch = _firestore.batch();

      for (DocumentSnapshot doc in unreadMessages.docs) {
        batch.update(doc.reference, {'isRead': true});
      }

      await batch.commit();

      // Reset unread count for this chat
      DocumentReference userRef = _firestore.collection('users').doc(userId);

      await _firestore.runTransaction((transaction) async {
        DocumentSnapshot userDoc = await transaction.get(userRef);

        if (userDoc.exists && userDoc.data() != null) {
          Map<String, dynamic> userData =
              userDoc.data() as Map<String, dynamic>;
          Map<String, dynamic> unreadChats = userData['unreadChats'] ?? {};
          unreadChats.remove(chatId);
          transaction.update(userRef, {'unreadChats': unreadChats});
        }
      });
    } catch (e) {
      print('Error marking messages as read: $e');
    }
  }

  // Get total unread message count for notification badge
  Future<int> getTotalUnreadMessageCount(String userId) async {
    try {
      DocumentSnapshot userDoc =
          await _firestore.collection('users').doc(userId).get();

      if (userDoc.exists && userDoc.data() != null) {
        Map<String, dynamic> userData = userDoc.data() as Map<String, dynamic>;
        Map<String, dynamic> unreadChats = userData['unreadChats'] ?? {};

        int totalUnread = 0;
        unreadChats.values.forEach((count) {
          totalUnread += count as int;
        });

        return totalUnread;
      }

      return 0;
    } catch (e) {
      print('Error getting unread count: $e');
      return 0;
    }
  }

  // Initialize a new chat between two users
  Future<void> initializePrivateChat({
    required String chatId,
    required String currentUserId,
    required String currentUserName,
    required String currentUserImage,
    required String otherUserId,
    required String otherUserName,
    required String otherUserImage,
  }) async {
    try {
      DocumentSnapshot chatDoc =
          await _firestore.collection('private_chats').doc(chatId).get();

      if (!chatDoc.exists) {
        await _firestore.collection('private_chats').doc(chatId).set({
          'participants': [currentUserId, otherUserId],
          'participantNames': [currentUserName, otherUserName],
          'participantImages': [currentUserImage, otherUserImage],
          'lastMessage': '',
          'lastMessageTime': FieldValue.serverTimestamp(),
          'createdAt': FieldValue.serverTimestamp(),
          '${currentUserId}_typing': false,
          '${otherUserId}_typing': false,
          '${currentUserId}_lastSeen': FieldValue.serverTimestamp(),
          '${otherUserId}_lastSeen': FieldValue.serverTimestamp(),
        });
      }
    } catch (e) {
      print("Error initializing chat: $e");
    }
  }

  // Delete a chat and all its messages
  Future<void> deleteChat(String chatId) async {
    try {
      WriteBatch batch = _firestore.batch();

      // Delete all messages in the chat
      QuerySnapshot messages = await _firestore
          .collection('private_chats')
          .doc(chatId)
          .collection('messages')
          .get();

      for (DocumentSnapshot message in messages.docs) {
        batch.delete(message.reference);
      }

      // Delete the chat document
      batch.delete(_firestore.collection('private_chats').doc(chatId));

      await batch.commit();
      print("Chat deleted successfully");
    } catch (e) {
      print("Error deleting chat: $e");
      throw e;
    }
  }

  // Get unread message count for a specific chat
  Future<int> getChatUnreadCount(String chatId, String userId) async {
    try {
      QuerySnapshot unreadMessages = await _firestore
          .collection('private_chats')
          .doc(chatId)
          .collection('messages')
          .where('receiverId', isEqualTo: userId)
          .where('isRead', isEqualTo: false)
          .get();

      return unreadMessages.docs.length;
    } catch (e) {
      print('Error getting chat unread count: $e');
      return 0;
    }
  }

  // Search messages within a chat (legacy method - now uses searchChatMessages)
  Future<QuerySnapshot> searchMessagesInChat(
      String chatId, String searchTerm) async {
    return await _firestore
        .collection('private_chats')
        .doc(chatId)
        .collection('messages')
        .where('message', isGreaterThanOrEqualTo: searchTerm)
        .where('message', isLessThanOrEqualTo: '$searchTerm\uf8ff')
        .orderBy('message')
        .orderBy('timestamp', descending: true)
        .get();
  }

  // Block user from messaging
  Future<void> blockUserFromMessaging(
      String currentUserId, String blockedUserId) async {
    try {
      await _firestore.collection("users").doc(currentUserId).update({
        'BlockedFromMessaging': FieldValue.arrayUnion([blockedUserId])
      });
    } catch (e) {
      print("Error blocking user from messaging: $e");
    }
  }

  // Unblock user from messaging
  Future<void> unblockUserFromMessaging(
      String currentUserId, String unblockedUserId) async {
    try {
      await _firestore.collection("users").doc(currentUserId).update({
        'BlockedFromMessaging': FieldValue.arrayRemove([unblockedUserId])
      });
    } catch (e) {
      print("Error unblocking user from messaging: $e");
    }
  }

  // Check if user is blocked from messaging
  Future<bool> isUserBlockedFromMessaging(
      String currentUserId, String otherUserId) async {
    try {
      DocumentSnapshot userDoc =
          await _firestore.collection("users").doc(currentUserId).get();

      if (userDoc.exists) {
        List blockedUsers = userDoc.get('BlockedFromMessaging') ?? [];
        return blockedUsers.contains(otherUserId);
      }
      return false;
    } catch (e) {
      print("Error checking message block status: $e");
      return false;
    }
  }

  // ========== END ENHANCED PRIVATE MESSAGING METHODS ==========

  // Report/Block Methods
  Future<void> reportPost(
      String postId, String reporterId, String reason) async {
    try {
      Map<String, dynamic> reportData = {
        "PostId": postId,
        "ReporterId": reporterId,
        "Reason": reason,
        "Timestamp": DateTime.now().millisecondsSinceEpoch,
        "Status": "Pending"
      };

      await _firestore.collection("Reports").add(reportData);
    } catch (e) {
      print("Error reporting post: $e");
    }
  }

  Future<void> blockUser(String currentUserId, String blockedUserId) async {
    try {
      await _firestore.collection("users").doc(currentUserId).update({
        'BlockedUsers': FieldValue.arrayUnion([blockedUserId])
      });
    } catch (e) {
      print("Error blocking user: $e");
    }
  }

  Future<void> unblockUser(String currentUserId, String unblockedUserId) async {
    try {
      await _firestore.collection("users").doc(currentUserId).update({
        'BlockedUsers': FieldValue.arrayRemove([unblockedUserId])
      });
    } catch (e) {
      print("Error unblocking user: $e");
    }
  }

  // Method to get blocked users list
  Future<List<String>> getBlockedUsers(String userId) async {
    try {
      DocumentSnapshot userDoc =
          await _firestore.collection("users").doc(userId).get();

      if (userDoc.exists) {
        List<dynamic> blocked = userDoc.get('BlockedUsers') ?? [];
        return blocked.cast<String>();
      }
      return [];
    } catch (e) {
      print("Error getting blocked users: $e");
      return [];
    }
  }

  // Method to get posts excluding blocked users
  Stream<QuerySnapshot> getPostsExcludingBlocked(List<String> blockedUsers) {
    if (blockedUsers.isEmpty) {
      return getPosts();
    }

    return _firestore
        .collection("Posts")
        .where("UserId", whereNotIn: blockedUsers)
        .orderBy("Timestamp", descending: true)
        .snapshots();
  }

  // Trending and Discovery Methods
  Future<QuerySnapshot> getTrendingPosts(int days) async {
    int timestamp =
        DateTime.now().subtract(Duration(days: days)).millisecondsSinceEpoch;

    return await _firestore
        .collection("Posts")
        .where("Timestamp", isGreaterThan: timestamp)
        .orderBy("Timestamp", descending: false)
        .orderBy("Like", descending: true)
        .limit(20)
        .get();
  }

  // Batch Operations
  Future<void> batchUpdatePosts(
      List<String> postIds, Map<String, dynamic> updateData) async {
    try {
      WriteBatch batch = _firestore.batch();

      for (String postId in postIds) {
        DocumentReference postRef = _firestore.collection("Posts").doc(postId);
        batch.update(postRef, updateData);
      }

      await batch.commit();
      print("Batch update completed successfully");
    } catch (e) {
      print("Error in batch update: $e");
      throw e;
    }
  }

  // Clean up methods
  Future<void> deleteUserAccount(String userId) async {
    try {
      WriteBatch batch = _firestore.batch();

      // Delete user's posts and their comments
      QuerySnapshot userPosts = await _firestore
          .collection("Posts")
          .where("UserId", isEqualTo: userId)
          .get();

      for (DocumentSnapshot post in userPosts.docs) {
        // Delete all comments in each post
        QuerySnapshot comments =
            await post.reference.collection("Comment").get();
        for (DocumentSnapshot comment in comments.docs) {
          batch.delete(comment.reference);
        }
        // Delete the post
        batch.delete(post.reference);
      }

      // Delete user's comments on other posts
      QuerySnapshot userComments = await _firestore
          .collectionGroup("Comment")
          .where("UserId", isEqualTo: userId)
          .get();

      for (DocumentSnapshot comment in userComments.docs) {
        batch.delete(comment.reference);
      }

      // Delete user's notifications
      QuerySnapshot notifications = await _firestore
          .collection("users")
          .doc(userId)
          .collection("Notifications")
          .get();

      for (DocumentSnapshot notification in notifications.docs) {
        batch.delete(notification.reference);
      }

      // Delete user's private chats and messages
      QuerySnapshot userChats = await _firestore
          .collection("private_chats")
          .where("participants", arrayContains: userId)
          .get();

      for (DocumentSnapshot chat in userChats.docs) {
        // Delete all messages in the chat
        QuerySnapshot messages =
            await chat.reference.collection("messages").get();
        for (DocumentSnapshot message in messages.docs) {
          batch.delete(message.reference);
        }
        // Delete the chat document
        batch.delete(chat.reference);
      }

      // Delete user document
      batch.delete(_firestore.collection("users").doc(userId));

      await batch.commit();
      print("User account deleted successfully");
    } catch (e) {
      print("Error deleting user account: $e");
      throw e;
    }
  }

  // Activity Feed Methods
  Future<void> createActivityLog(
      String userId, String action, Map<String, dynamic> details) async {
    try {
      await _firestore
          .collection("users")
          .doc(userId)
          .collection("ActivityLog")
          .add({
        'Action': action,
        'Details': details,
        'Timestamp': DateTime.now().millisecondsSinceEpoch,
      });
    } catch (e) {
      print("Error creating activity log: $e");
    }
  }

  Stream<QuerySnapshot> getActivityFeed(String userId, {int limit = 50}) {
    return _firestore
        .collection("users")
        .doc(userId)
        .collection("ActivityLog")
        .orderBy("Timestamp", descending: true)
        .limit(limit)
        .snapshots();
  }

  // ========== ADDITIONAL HELPER METHODS FOR MESSAGING UI ==========

  // Helper method to generate chat ID between two users
  static String generateChatId(String userId1, String userId2) {
    List<String> userIds = [userId1, userId2]..sort();
    return "${userIds[0]}_${userIds[1]}";
  }

  // Helper method to get other participant details from chat
  Map<String, String> getOtherParticipant(
      Map<String, dynamic> chatData, String currentUserId) {
    List<dynamic> participants = chatData['participants'] ?? [];
    List<dynamic> participantNames = chatData['participantNames'] ?? [];
    List<dynamic> participantImages = chatData['participantImages'] ?? [];

    int otherIndex = participants.indexOf(currentUserId) == 0 ? 1 : 0;

    return {
      'id': participants.length > otherIndex ? participants[otherIndex] : '',
      'name': participantNames.length > otherIndex
          ? participantNames[otherIndex]
          : 'Unknown',
      'image': participantImages.length > otherIndex
          ? participantImages[otherIndex]
          : '',
    };
  }

  // Helper method to format timestamp for chat messages
  static String formatMessageTime(DateTime timestamp) {
    final now = DateTime.now();
    final difference = now.difference(timestamp);

    if (difference.inDays > 0) {
      return '${timestamp.day}/${timestamp.month}/${timestamp.year}';
    } else if (difference.inHours > 0) {
      return '${difference.inHours}h ago';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes}m ago';
    } else {
      return 'Just now';
    }
  }

  // Helper method to check if message is from current user
  static bool isMessageFromCurrentUser(
      Map<String, dynamic> messageData, String currentUserId) {
    return messageData['senderId'] == currentUserId;
  }
}
