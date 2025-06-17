/* Amplify Params - DO NOT EDIT
  API_SCHEDULINGAPP_GRAPHQLAPIIDOUTPUT
  API_SCHEDULINGAPP_USERTABLE_ARN
  API_SCHEDULINGAPP_USERTABLE_NAME
  AUTH_SCHEDULINGAPP30672A99_USERPOOLID
  ENV
  REGION
Amplify Params - DO NOT EDIT */

const { DynamoDBDocumentClient, PutCommand } = require('@aws-sdk/lib-dynamodb');
const { DynamoDBClient } = require('@aws-sdk/client-dynamodb');

const region = process.env.REGION;
const dynamoDbClient = new DynamoDBClient({ region });
const ddbDocClient = DynamoDBDocumentClient.from(dynamoDbClient);

/**
 * Post Confirmation Lambda Trigger for DynamoDB User Profile Creation.
 * This function's ONLY job is to create the user profile in DynamoDB after
 * Cognito has successfully created and confirmed a new user.
 */
exports.handler = async (event) => {
  console.log('🔍 PostConfirmation trigger event:', JSON.stringify(event, null, 2));

  // A user is only confirmed once, so we create their profile record here.
  const { sub, email, name } = event.request.userAttributes;
  const authProvider = event.userName.includes('_') ? event.userName.split('_')[0].toUpperCase() : 'EMAIL';
  
  const tableName = process.env.API_SCHEDULINGAPP_USERTABLE_NAME;
  if (!tableName) {
    console.error('USER_TABLE_NAME environment variable not set! Cannot create user profile.');
    return event;
  }

  const userRecord = {
    id: sub, // The Cognito User ID is the primary key
    email: email,
    name: name || email.split('@')[0],
    primaryAuthMethod: authProvider,
    // The linkedAuthMethods must be created as a DynamoDB Set
    linkedAuthMethods: new Set([authProvider]),
    createdAt: new Date().toISOString(),
    updatedAt: new Date().toISOString(),
  };

  const params = new PutCommand({
    TableName: tableName,
    Item: userRecord,
    ConditionExpression: 'attribute_not_exists(id)' // Prevents accidental overwrites
  });

  try {
    console.log(`📝 Creating user profile in DynamoDB:`, JSON.stringify(userRecord, null, 2));
    await ddbDocClient.send(params);
    console.log(`✅ User profile created successfully for ${email}`);
  } catch (error) {
    if (error.name === 'ConditionalCheckFailedException') {
      console.log(`ℹ️ User profile for ${email} already exists. No action taken.`);
    } else {
      console.error('❌ Error creating user profile:', error);
      // We don't re-throw the error, as we don't want to fail the user's login.
    }
  }

  return event;
};
