/*
* Copyright 2021 Amazon.com, Inc. or its affiliates. All Rights Reserved.
*
* Licensed under the Apache License, Version 2.0 (the "License").
* You may not use this file except in compliance with the License.
* A copy of the License is located at
*
*  http://aws.amazon.com/apache2.0
*
* or in the "license" file accompanying this file. This file is distributed
* on an "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either
* express or implied. See the License for the specific language governing
* permissions and limitations under the License.
*/

// NOTE: This file is generated and may not follow lint rules defined in your app
// Generated files can be excluded from analysis in analysis_options.yaml
// For more info, see: https://dart.dev/guides/language/analysis-options#excluding-code-from-analysis

// ignore_for_file: public_member_api_docs, annotate_overrides, dead_code, dead_codepublic_member_api_docs, depend_on_referenced_packages, file_names, library_private_types_in_public_api, no_leading_underscores_for_library_prefixes, no_leading_underscores_for_local_identifiers, non_constant_identifier_names, null_check_on_nullable_type_parameter, override_on_non_overriding_member, prefer_adjacent_string_concatenation, prefer_const_constructors, prefer_if_null_operators, prefer_interpolation_to_compose_strings, slash_for_doc_comments, sort_child_properties_last, unnecessary_const, unnecessary_constructor_name, unnecessary_late, unnecessary_new, unnecessary_null_aware_assignments, unnecessary_nullable_for_final_variable_declarations, unnecessary_string_interpolations, use_build_context_synchronously

import 'ModelProvider.dart';
import 'package:amplify_core/amplify_core.dart' as amplify_core;
import 'package:collection/collection.dart';


/** This is an auto generated class representing the Group type in your schema. */
class Group extends amplify_core.Model {
  static const classType = const _GroupModelType();
  final String id;
  final String? _name;
  final String? _description;
  final String? _ownerId;
  final List<GroupUser>? _members;
  final List<Schedule>? _schedules;
  final amplify_core.TemporalDateTime? _createdAt;
  final amplify_core.TemporalDateTime? _updatedAt;

  @override
  getInstanceType() => classType;
  
  @Deprecated('[getId] is being deprecated in favor of custom primary key feature. Use getter [modelIdentifier] to get model identifier.')
  @override
  String getId() => id;
  
  GroupModelIdentifier get modelIdentifier {
      return GroupModelIdentifier(
        id: id
      );
  }
  
  String get name {
    try {
      return _name!;
    } catch(e) {
      throw amplify_core.AmplifyCodeGenModelException(
          amplify_core.AmplifyExceptionMessages.codeGenRequiredFieldForceCastExceptionMessage,
          recoverySuggestion:
            amplify_core.AmplifyExceptionMessages.codeGenRequiredFieldForceCastRecoverySuggestion,
          underlyingException: e.toString()
          );
    }
  }
  
  String? get description {
    return _description;
  }
  
  String get ownerId {
    try {
      return _ownerId!;
    } catch(e) {
      throw amplify_core.AmplifyCodeGenModelException(
          amplify_core.AmplifyExceptionMessages.codeGenRequiredFieldForceCastExceptionMessage,
          recoverySuggestion:
            amplify_core.AmplifyExceptionMessages.codeGenRequiredFieldForceCastRecoverySuggestion,
          underlyingException: e.toString()
          );
    }
  }
  
  List<GroupUser>? get members {
    return _members;
  }
  
  List<Schedule>? get schedules {
    return _schedules;
  }
  
  amplify_core.TemporalDateTime? get createdAt {
    return _createdAt;
  }
  
  amplify_core.TemporalDateTime? get updatedAt {
    return _updatedAt;
  }
  
  const Group._internal({required this.id, required name, description, required ownerId, members, schedules, createdAt, updatedAt}): _name = name, _description = description, _ownerId = ownerId, _members = members, _schedules = schedules, _createdAt = createdAt, _updatedAt = updatedAt;
  
  factory Group({String? id, required String name, String? description, required String ownerId, List<GroupUser>? members, List<Schedule>? schedules}) {
    return Group._internal(
      id: id == null ? amplify_core.UUID.getUUID() : id,
      name: name,
      description: description,
      ownerId: ownerId,
      members: members != null ? List<GroupUser>.unmodifiable(members) : members,
      schedules: schedules != null ? List<Schedule>.unmodifiable(schedules) : schedules);
  }
  
  bool equals(Object other) {
    return this == other;
  }
  
  @override
  bool operator ==(Object other) {
    if (identical(other, this)) return true;
    return other is Group &&
      id == other.id &&
      _name == other._name &&
      _description == other._description &&
      _ownerId == other._ownerId &&
      DeepCollectionEquality().equals(_members, other._members) &&
      DeepCollectionEquality().equals(_schedules, other._schedules);
  }
  
  @override
  int get hashCode => toString().hashCode;
  
  @override
  String toString() {
    var buffer = new StringBuffer();
    
    buffer.write("Group {");
    buffer.write("id=" + "$id" + ", ");
    buffer.write("name=" + "$_name" + ", ");
    buffer.write("description=" + "$_description" + ", ");
    buffer.write("ownerId=" + "$_ownerId" + ", ");
    buffer.write("createdAt=" + (_createdAt != null ? _createdAt!.format() : "null") + ", ");
    buffer.write("updatedAt=" + (_updatedAt != null ? _updatedAt!.format() : "null"));
    buffer.write("}");
    
    return buffer.toString();
  }
  
  Group copyWith({String? name, String? description, String? ownerId, List<GroupUser>? members, List<Schedule>? schedules}) {
    return Group._internal(
      id: id,
      name: name ?? this.name,
      description: description ?? this.description,
      ownerId: ownerId ?? this.ownerId,
      members: members ?? this.members,
      schedules: schedules ?? this.schedules);
  }
  
  Group copyWithModelFieldValues({
    ModelFieldValue<String>? name,
    ModelFieldValue<String?>? description,
    ModelFieldValue<String>? ownerId,
    ModelFieldValue<List<GroupUser>?>? members,
    ModelFieldValue<List<Schedule>?>? schedules
  }) {
    return Group._internal(
      id: id,
      name: name == null ? this.name : name.value,
      description: description == null ? this.description : description.value,
      ownerId: ownerId == null ? this.ownerId : ownerId.value,
      members: members == null ? this.members : members.value,
      schedules: schedules == null ? this.schedules : schedules.value
    );
  }
  
  Group.fromJson(Map<String, dynamic> json)  
    : id = json['id'],
      _name = json['name'],
      _description = json['description'],
      _ownerId = json['ownerId'],
      _members = json['members']  is Map
        ? (json['members']['items'] is List
          ? (json['members']['items'] as List)
              .where((e) => e != null)
              .map((e) => GroupUser.fromJson(new Map<String, dynamic>.from(e)))
              .toList()
          : null)
        : (json['members'] is List
          ? (json['members'] as List)
              .where((e) => e?['serializedData'] != null)
              .map((e) => GroupUser.fromJson(new Map<String, dynamic>.from(e?['serializedData'])))
              .toList()
          : null),
      _schedules = json['schedules']  is Map
        ? (json['schedules']['items'] is List
          ? (json['schedules']['items'] as List)
              .where((e) => e != null)
              .map((e) => Schedule.fromJson(new Map<String, dynamic>.from(e)))
              .toList()
          : null)
        : (json['schedules'] is List
          ? (json['schedules'] as List)
              .where((e) => e?['serializedData'] != null)
              .map((e) => Schedule.fromJson(new Map<String, dynamic>.from(e?['serializedData'])))
              .toList()
          : null),
      _createdAt = json['createdAt'] != null ? amplify_core.TemporalDateTime.fromString(json['createdAt']) : null,
      _updatedAt = json['updatedAt'] != null ? amplify_core.TemporalDateTime.fromString(json['updatedAt']) : null;
  
  Map<String, dynamic> toJson() => {
    'id': id, 'name': _name, 'description': _description, 'ownerId': _ownerId, 'members': _members?.map((GroupUser? e) => e?.toJson()).toList(), 'schedules': _schedules?.map((Schedule? e) => e?.toJson()).toList(), 'createdAt': _createdAt?.format(), 'updatedAt': _updatedAt?.format()
  };
  
  Map<String, Object?> toMap() => {
    'id': id,
    'name': _name,
    'description': _description,
    'ownerId': _ownerId,
    'members': _members,
    'schedules': _schedules,
    'createdAt': _createdAt,
    'updatedAt': _updatedAt
  };

  static final amplify_core.QueryModelIdentifier<GroupModelIdentifier> MODEL_IDENTIFIER = amplify_core.QueryModelIdentifier<GroupModelIdentifier>();
  static final ID = amplify_core.QueryField(fieldName: "id");
  static final NAME = amplify_core.QueryField(fieldName: "name");
  static final DESCRIPTION = amplify_core.QueryField(fieldName: "description");
  static final OWNERID = amplify_core.QueryField(fieldName: "ownerId");
  static final MEMBERS = amplify_core.QueryField(
    fieldName: "members",
    fieldType: amplify_core.ModelFieldType(amplify_core.ModelFieldTypeEnum.model, ofModelName: 'GroupUser'));
  static final SCHEDULES = amplify_core.QueryField(
    fieldName: "schedules",
    fieldType: amplify_core.ModelFieldType(amplify_core.ModelFieldTypeEnum.model, ofModelName: 'Schedule'));
  static var schema = amplify_core.Model.defineSchema(define: (amplify_core.ModelSchemaDefinition modelSchemaDefinition) {
    modelSchemaDefinition.name = "Group";
    modelSchemaDefinition.pluralName = "Groups";
    
    modelSchemaDefinition.indexes = [
      amplify_core.ModelIndex(fields: const ["ownerId", "name"], name: "byOwner")
    ];
    
    modelSchemaDefinition.addField(amplify_core.ModelFieldDefinition.id());
    
    modelSchemaDefinition.addField(amplify_core.ModelFieldDefinition.field(
      key: Group.NAME,
      isRequired: true,
      ofType: amplify_core.ModelFieldType(amplify_core.ModelFieldTypeEnum.string)
    ));
    
    modelSchemaDefinition.addField(amplify_core.ModelFieldDefinition.field(
      key: Group.DESCRIPTION,
      isRequired: false,
      ofType: amplify_core.ModelFieldType(amplify_core.ModelFieldTypeEnum.string)
    ));
    
    modelSchemaDefinition.addField(amplify_core.ModelFieldDefinition.field(
      key: Group.OWNERID,
      isRequired: true,
      ofType: amplify_core.ModelFieldType(amplify_core.ModelFieldTypeEnum.string)
    ));
    
    modelSchemaDefinition.addField(amplify_core.ModelFieldDefinition.hasMany(
      key: Group.MEMBERS,
      isRequired: false,
      ofModelName: 'GroupUser',
      associatedKey: GroupUser.GROUP
    ));
    
    modelSchemaDefinition.addField(amplify_core.ModelFieldDefinition.hasMany(
      key: Group.SCHEDULES,
      isRequired: false,
      ofModelName: 'Schedule',
      associatedKey: Schedule.GROUP
    ));
    
    modelSchemaDefinition.addField(amplify_core.ModelFieldDefinition.nonQueryField(
      fieldName: 'createdAt',
      isRequired: false,
      isReadOnly: true,
      ofType: amplify_core.ModelFieldType(amplify_core.ModelFieldTypeEnum.dateTime)
    ));
    
    modelSchemaDefinition.addField(amplify_core.ModelFieldDefinition.nonQueryField(
      fieldName: 'updatedAt',
      isRequired: false,
      isReadOnly: true,
      ofType: amplify_core.ModelFieldType(amplify_core.ModelFieldTypeEnum.dateTime)
    ));
  });
}

class _GroupModelType extends amplify_core.ModelType<Group> {
  const _GroupModelType();
  
  @override
  Group fromJson(Map<String, dynamic> jsonData) {
    return Group.fromJson(jsonData);
  }
  
  @override
  String modelName() {
    return 'Group';
  }
}

/**
 * This is an auto generated class representing the model identifier
 * of [Group] in your schema.
 */
class GroupModelIdentifier implements amplify_core.ModelIdentifier<Group> {
  final String id;

  /** Create an instance of GroupModelIdentifier using [id] the primary key. */
  const GroupModelIdentifier({
    required this.id});
  
  @override
  Map<String, dynamic> serializeAsMap() => (<String, dynamic>{
    'id': id
  });
  
  @override
  List<Map<String, dynamic>> serializeAsList() => serializeAsMap()
    .entries
    .map((entry) => (<String, dynamic>{ entry.key: entry.value }))
    .toList();
  
  @override
  String serializeAsString() => serializeAsMap().values.join('#');
  
  @override
  String toString() => 'GroupModelIdentifier(id: $id)';
  
  @override
  bool operator ==(Object other) {
    if (identical(this, other)) {
      return true;
    }
    
    return other is GroupModelIdentifier &&
      id == other.id;
  }
  
  @override
  int get hashCode =>
    id.hashCode;
}