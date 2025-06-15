import 'package:amplify_flutter/amplify_flutter.dart';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import '../models/User.dart';
import '../models/Group.dart';
import '../models/GroupInvitation.dart';
import '../models/InvitationStatus.dart';
import '../services/notification_service.dart';

class GroupService {
  static Future<Group?> getSelectedGroup() async {
    final groups = await getUserGroups();
    return groups.isNotEmpty ? groups.first : null;
  }

  static Future<List<Group>> getUserGroups() async {
    final userId = (await Amplify.Auth.getCurrentUser()).userId;
    final request = GraphQLRequest<String>(
      document: '''
        query GetUserGroups(\$userId: ID!) {
          listGroupUsers(filter: {userId: {eq: \$userId}}) {
            items {
              group {
                id
                name
              }
            }
          }
        }
      ''',
      variables: {'userId': userId},
    );
    final response = await Amplify.API.query(request: request).response;
    final items = jsonDecode(response.data!)['listGroupUsers']['items'];
    return items.map<Group>((item) => Group.fromJson(item['group'])).toList();
  }

  static Future<void> createGroup({
    required String name,
    String? description,
  }) async {
    try {
      final userId = (await Amplify.Auth.getCurrentUser()).userId;

      // Step 1: Create the group
      final groupRequest = GraphQLRequest<String>(
        document: '''
        mutation CreateGroup(\$input: CreateGroupInput!) {
          createGroup(input: \$input) {
            id
            name
            description
            ownerId
          }
        }
      ''',
        variables: {
          'input': {
            'name': name,
            'description': description,
            'ownerId': userId,
          }
        },
      );

      final groupResponse =
          await Amplify.API.mutate(request: groupRequest).response;
      final groupData = jsonDecode(groupResponse.data!)['createGroup'];
      final groupId = groupData['id'];

      debugPrint('✅ Group created with ID: $groupId');

      // Step 2: Add creator as a GroupUser (member)
      final memberRequest = GraphQLRequest<String>(
        document: '''
        mutation CreateGroupUser(\$input: CreateGroupUserInput!) {
          createGroupUser(input: \$input) {
            id
            userId
            groupId
            isAdmin
          }
        }
      ''',
        variables: {
          'input': {
            'userId': userId,
            'groupId': groupId,
            'isAdmin': true,
          }
        },
      );

      final memberResponse =
          await Amplify.API.mutate(request: memberRequest).response;
      debugPrint('✅ GroupUser created: ${memberResponse.data}');
    } catch (e) {
      debugPrint('❌ Failed to create group or member: $e');
      rethrow;
    }
  }

  static Future<List<User>> getGroupMembers(String groupId) async {
    try {
      final request = GraphQLRequest<String>(
        document: '''
        query GetGroupMembers(\$groupId: ID!) {
          listGroupUsers(filter: {groupId: {eq: \$groupId}}) {
            items {
              user {
                id
                name
                email
              }
            }
          }
        }
      ''',
        variables: {'groupId': groupId},
      );

      final response = await Amplify.API.query(request: request).response;
      final rawData = response.data;

      if (rawData == null) {
        throw Exception('API response data is null');
      }

      final decoded = jsonDecode(rawData);
      final items = decoded['listGroupUsers']?['items'];

      if (items == null) {
        throw Exception('listGroupUsers.items is null');
      }

      return items
          .where((item) => item['user'] != null)
          .map<User>((item) => User.fromJson(item['user']))
          .toList();
    } catch (e) {
      debugPrint('❌ Failed to fetch group members: $e');
      rethrow;
    }
  }

  // Create a group invitation
  static Future<GroupInvitation> createGroupInvitation({
    required String groupId,
    required String invitedUserId,
    bool isAdmin = false,
  }) async {
    try {
      final currentUser = await Amplify.Auth.getCurrentUser();
      final invitedByUserId = currentUser.userId;

      final request = GraphQLRequest<String>(
        document: '''
        mutation CreateGroupInvitation(\$input: CreateGroupInvitationInput!) {
          createGroupInvitation(input: \$input) {
            id
            groupId
            invitedUserId
            invitedByUserId
            status
            isAdmin
            createdAt
            group {
              id
              name
            }
            invitedUser {
              id
              name
              email
            }
            invitedByUser {
              id
              name
            }
          }
        }
      ''',
        variables: {
          'input': {
            'groupId': groupId,
            'invitedUserId': invitedUserId,
            'invitedByUserId': invitedByUserId,
            'status': InvitationStatus.PENDING.name,
            'isAdmin': isAdmin,
            'createdAt': TemporalDateTime.now().format(),
          }
        },
      );

      final response = await Amplify.API.mutate(request: request).response;

      if (response.hasErrors) {
        throw Exception('Failed to create invitation: ${response.errors.first.message}');
      }

      final invitationData = jsonDecode(response.data!)['createGroupInvitation'];
      final invitation = GroupInvitation.fromJson(invitationData);

      debugPrint('✅ Group invitation created: ${invitation.id}');

      // Create notification for the invitation
      await NotificationService.addGroupInvitationNotification(invitation);

      return invitation;
    } catch (e) {
      debugPrint('❌ Failed to create group invitation: $e');
      rethrow;
    }
  }

  // Accept a group invitation
  static Future<void> acceptGroupInvitation(String invitationId) async {
    try {
      // First, get the invitation details with raw GraphQL response
      final invitationRequest = GraphQLRequest<String>(
        document: '''
        query GetGroupInvitation(\$id: ID!) {
          getGroupInvitation(id: \$id) {
            id
            groupId
            invitedUserId
            invitedByUserId
            status
            isAdmin
            createdAt
          }
        }
      ''',
        variables: {'id': invitationId},
      );

      final invitationResponse = await Amplify.API.query(request: invitationRequest).response;

      if (invitationResponse.hasErrors) {
        throw Exception('Failed to get invitation: ${invitationResponse.errors.first.message}');
      }

      final invitationData = jsonDecode(invitationResponse.data!)['getGroupInvitation'];
      final groupId = invitationData['groupId'];
      final invitedUserId = invitationData['invitedUserId'];
      final isAdmin = invitationData['isAdmin'];

      // Update invitation status to ACCEPTED
      await _updateInvitationStatus(invitationId, InvitationStatus.ACCEPTED);

      // Add user to the group as a member
      final memberRequest = GraphQLRequest<String>(
        document: '''
        mutation CreateGroupUser(\$input: CreateGroupUserInput!) {
          createGroupUser(input: \$input) {
            id
            userId
            groupId
            isAdmin
          }
        }
      ''',
        variables: {
          'input': {
            'userId': invitedUserId,
            'groupId': groupId,
            'isAdmin': isAdmin,
          }
        },
      );

      final memberResponse = await Amplify.API.mutate(request: memberRequest).response;

      if (memberResponse.hasErrors) {
        throw Exception('Failed to add user to group: ${memberResponse.errors.first.message}');
      }

      debugPrint('✅ Group invitation accepted and user added to group');
    } catch (e) {
      debugPrint('❌ Failed to accept group invitation: $e');
      rethrow;
    }
  }

  // Decline a group invitation
  static Future<void> declineGroupInvitation(String invitationId) async {
    try {
      await _updateInvitationStatus(invitationId, InvitationStatus.DECLINED);
      debugPrint('✅ Group invitation declined');
    } catch (e) {
      debugPrint('❌ Failed to decline group invitation: $e');
      rethrow;
    }
  }

  // Remove a member from a group
  static Future<void> removeMemberFromGroup({
    required String groupId,
    required String userId,
  }) async {
    try {
      // First, find the GroupUser record
      final request = GraphQLRequest<String>(
        document: '''
        query GetGroupUser(\$userId: ID!, \$groupId: ID!) {
          listGroupUsers(filter: {
            and: {
              userId: {eq: \$userId},
              groupId: {eq: \$groupId}
            }
          }) {
            items {
              id
            }
          }
        }
      ''',
        variables: {'userId': userId, 'groupId': groupId},
      );

      final response = await Amplify.API.query(request: request).response;
      final data = jsonDecode(response.data ?? '{}');
      final items = data['listGroupUsers']?['items'] ?? [];

      if (items.isEmpty) {
        throw Exception('User is not a member of this group');
      }

      final groupUserId = items[0]['id'];

      // Delete the GroupUser record
      final deleteRequest = GraphQLRequest<String>(
        document: '''
        mutation DeleteGroupUser(\$input: DeleteGroupUserInput!) {
          deleteGroupUser(input: \$input) {
            id
          }
        }
      ''',
        variables: {
          'input': {
            'id': groupUserId,
          }
        },
      );

      final deleteResponse = await Amplify.API.mutate(request: deleteRequest).response;

      if (deleteResponse.hasErrors) {
        throw Exception('Failed to remove member: ${deleteResponse.errors.first.message}');
      }

      debugPrint('✅ Member removed from group');
    } catch (e) {
      debugPrint('❌ Failed to remove member from group: $e');
      rethrow;
    }
  }



  // Update group information (name and description)
  static Future<bool> updateGroup(String groupId, String name, String? description) async {
    try {
      final request = GraphQLRequest<String>(
        document: '''
        mutation UpdateGroup(\$input: UpdateGroupInput!) {
          updateGroup(input: \$input) {
            id
            name
            description
            ownerId
            createdAt
            updatedAt
          }
        }
        ''',
        variables: {
          'input': {
            'id': groupId,
            'name': name,
            'description': description,
          }
        },
      );

      final response = await Amplify.API.mutate(request: request).response;

      if (response.hasErrors) {
        debugPrint('Error updating group: ${response.errors.first.message}');
        return false;
      }

      debugPrint('✅ Group updated successfully');
      return true;
    } catch (e) {
      debugPrint('❌ Error updating group: $e');
      return false;
    }
  }

  // Delete group (only for group owners)
  static Future<bool> deleteGroup(String groupId) async {
    try {
      final request = GraphQLRequest<String>(
        document: '''
        mutation DeleteGroup(\$input: DeleteGroupInput!) {
          deleteGroup(input: \$input) {
            id
          }
        }
        ''',
        variables: {
          'input': {
            'id': groupId,
          }
        },
      );

      final response = await Amplify.API.mutate(request: request).response;

      if (response.hasErrors) {
        debugPrint('Error deleting group: ${response.errors.first.message}');
        return false;
      }

      debugPrint('✅ Group deleted successfully');
      return true;
    } catch (e) {
      debugPrint('❌ Error deleting group: $e');
      return false;
    }
  }

  // Helper method to update invitation status
  static Future<void> _updateInvitationStatus(String invitationId, InvitationStatus status) async {
    final request = GraphQLRequest<String>(
      document: '''
      mutation UpdateGroupInvitation(\$input: UpdateGroupInvitationInput!) {
        updateGroupInvitation(input: \$input) {
          id
          status
        }
      }
    ''',
      variables: {
        'input': {
          'id': invitationId,
          'status': status.name,
        }
      },
    );

    final response = await Amplify.API.mutate(request: request).response;

    if (response.hasErrors) {
      throw Exception('Failed to update invitation status: ${response.errors.first.message}');
    }
  }
}
