/* Amplify Params - DO NOT EDIT
  API_SCHEDULINGAPP_GRAPHQLAPIIDOUTPUT
  API_SCHEDULINGAPP_USERTABLE_ARN
  API_SCHEDULINGAPP_USERTABLE_NAME
  AUTH_SCHEDULINGAPP30672A99_USERPOOLID
  ENV
  REGION
Amplify Params - DO NOT EDIT */

const AWS = require('aws-sdk');
const dynamodb = new AWS.DynamoDB.DocumentClient();

/**
 * Post Confirmation Lambda Trigger for DynamoDB User Profile Creation.
 * This is the definitive version.
 */
exports.handler = async (event) => {
  console.log('🔍 PostConfirmation trigger event:', JSON.stringify(event, null, 2));

  const id = event.userName;
  const { email, name } = event.request.userAttributes;

  const authProvider = event.userName.includes('_') ? event.userName.split('_')[0].toUpperCase() : 'EMAIL';
  
  const tableName = process.env.API_SCHEDULINGAPP_USERTABLE_NAME;
  if (!tableName) {
    console.error('USER_TABLE_NAME environment variable not set! Cannot create user profile.');
    return event;
  }

  const userRecord = {
    id: id, // Use the reliable ID from event.userName
    email: email,
    name: name || email.split('@')[0],
    primaryAuthMethod: authProvider,
    linkedAuthMethods: dynamodb.createSet([authProvider]), // Must be created as a DynamoDB Set
    createdAt: new Date().toISOString(),
    updatedAt: new Date().toISOString(),
  };

  const params = {
    TableName: tableName,
    Item: userRecord,
    ConditionExpression: 'attribute_not_exists(id)' // Prevents accidental overwrites
  };

  try {
    console.log(`📝 Creating user profile in DynamoDB:`, JSON.stringify(userRecord, null, 2));
    await dynamodb.put(params).promise();
    console.log(`✅ User profile created successfully for ${email}`);
  } catch (error) {
    if (error.code === 'ConditionalCheckFailedException') {
      console.log(`ℹ️ User profile for ${email} already exists. No action taken.`);
    } else {
      console.error('❌ Error creating user profile:', error);
    }
  }

  return event;
};
