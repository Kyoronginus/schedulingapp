/* Amplify Params - DO NOT EDIT
	AUTH_SCHEDULINGAPP30672A99_USERPOOLID
	ENV
	REGION
Amplify Params - DO NOT EDIT */

const AWS = require('aws-sdk');

// Initialize AWS services
const dynamodb = new AWS.DynamoDB.DocumentClient();
const cognito = new AWS.CognitoIdentityServiceProvider();

/**
 * Post Confirmation Lambda Trigger for Cognito Account Linking
 * 
 * This function handles:
 * 1. Creating new user records for first-time users
 * 2. Linking authentication methods to existing accounts
 * 3. Setting up proper session mapping for account linking
 * 4. Maintaining primary account profile data
 */
exports.handler = async (event) => {
  console.log('🔍 PostConfirmation trigger event:', JSON.stringify(event, null, 2));

  try {
    const { userPoolId, userName, request } = event;
    const { userAttributes } = request;
    const email = userAttributes.email;
    const name = userAttributes.name || userAttributes.given_name || email.split('@')[0];
    const authProvider = getAuthProvider(event);

    console.log(`📧 Processing confirmation for email: ${email}, provider: ${authProvider}, user: ${userName}`);

    // Check if this is a linked account
    const primaryUserId = userAttributes['custom:primary_user_id'];
    const isLinkedAccount = userAttributes['custom:linked_account'] === 'true';
    const isPrimaryAccount = userAttributes['custom:primary_account'] === 'true';

    if (isLinkedAccount && primaryUserId) {
      console.log(`🔗 Processing linked account: ${authProvider} -> Primary User: ${primaryUserId}`);
      await linkAuthMethodToUser(primaryUserId, authProvider, userName, userPoolId);
    } else {
      console.log(`👤 Creating new primary user record for: ${email}`);
      await createUserRecord(userName, email, name, authProvider);
    }

    console.log('✅ PostConfirmation processing completed successfully');
    return event;

  } catch (error) {
    console.error('❌ PostConfirmation error:', error);
    // Don't throw error to avoid blocking user confirmation
    // Log the error and continue
    return event;
  }
};

/**
 * Determine the authentication provider from the event
 */
function getAuthProvider(event) {
  const { triggerSource, request } = event;
  
  // Check if it's an external provider (OAuth)
  if (triggerSource === 'PostConfirmation_ConfirmSignUp_ExternalProvider' || 
      triggerSource === 'PostConfirmation_ConfirmForgotPassword_ExternalProvider') {
    
    const userAttributes = request.userAttributes;
    
    // Check for Google provider indicators
    if (event.userName.includes('Google') ||
        userAttributes['cognito:user_status'] ||
        request.clientMetadata?.provider === 'Google') {
      return 'Google';
    }
    
    // Check for Facebook provider indicators  
    if (event.userName.includes('Facebook') ||
        request.clientMetadata?.provider === 'Facebook') {
      return 'Facebook';
    }
    
    return 'OAuth'; // Generic OAuth if we can't determine specific provider
  }
  
  // Default to email/password
  return 'Email';
}

/**
 * Create a new user record in DynamoDB
 */
async function createUserRecord(cognitoUserId, email, name, authProvider) {
  try {
    const tableName = await getUserTableName();
    
    const userRecord = {
      id: cognitoUserId,
      email: email,
      name: name,
      primaryAuthMethod: authProvider,
      linkedAuthMethods: [authProvider],
      createdAt: new Date().toISOString(),
      updatedAt: new Date().toISOString()
    };

    const params = {
      TableName: tableName,
      Item: userRecord,
      ConditionExpression: 'attribute_not_exists(id)' // Prevent overwriting existing records
    };

    console.log(`📝 Creating user record:`, JSON.stringify(userRecord, null, 2));
    
    await dynamodb.put(params).promise();
    console.log(`✅ User record created successfully for: ${email}`);
    
  } catch (error) {
    if (error.code === 'ConditionalCheckFailedException') {
      console.log(`ℹ️ User record already exists for: ${email}`);
    } else {
      console.error('❌ Error creating user record:', error);
      throw error;
    }
  }
}

/**
 * Link authentication method to existing user
 */
async function linkAuthMethodToUser(primaryUserId, authProvider, cognitoUserId, userPoolId) {
  try {
    const tableName = await getUserTableName();
    
    // First, get the existing user record
    const existingUser = await getUserById(primaryUserId);
    if (!existingUser) {
      throw new Error(`Primary user not found: ${primaryUserId}`);
    }

    // Update the linked auth methods
    const updatedLinkedMethods = [...new Set([...existingUser.linkedAuthMethods, authProvider])];
    
    const params = {
      TableName: tableName,
      Key: { id: primaryUserId },
      UpdateExpression: 'SET linkedAuthMethods = :linkedMethods, updatedAt = :updatedAt',
      ExpressionAttributeValues: {
        ':linkedMethods': updatedLinkedMethods,
        ':updatedAt': new Date().toISOString()
      }
    };

    console.log(`🔗 Linking ${authProvider} to user ${primaryUserId}`);
    await dynamodb.update(params).promise();
    
    // Update Cognito user attributes to maintain session mapping
    await updateCognitoUserAttributes(userPoolId, cognitoUserId, {
      'custom:primary_user_id': primaryUserId,
      'custom:auth_provider': authProvider,
      'custom:linked_account': 'true'
    });
    
    console.log(`✅ Successfully linked ${authProvider} to primary user: ${primaryUserId}`);
    
  } catch (error) {
    console.error('❌ Error linking auth method to user:', error);
    throw error;
  }
}

/**
 * Get user by ID from DynamoDB
 */
async function getUserById(userId) {
  try {
    const tableName = await getUserTableName();
    
    const params = {
      TableName: tableName,
      Key: { id: userId }
    };

    const result = await dynamodb.get(params).promise();
    return result.Item || null;
    
  } catch (error) {
    console.error('❌ Error getting user by ID:', error);
    throw error;
  }
}

/**
 * Update Cognito user attributes
 */
async function updateCognitoUserAttributes(userPoolId, userName, attributes) {
  try {
    const userAttributes = Object.entries(attributes).map(([name, value]) => ({
      Name: name,
      Value: value
    }));

    const params = {
      UserPoolId: userPoolId,
      Username: userName,
      UserAttributes: userAttributes
    };

    await cognito.adminUpdateUserAttributes(params).promise();
    console.log(`✅ Updated Cognito attributes for user: ${userName}`);
    
  } catch (error) {
    console.error('❌ Error updating Cognito user attributes:', error);
    throw error;
  }
}

/**
 * Get the User table name dynamically
 */
async function getUserTableName() {
  try {
    const dynamodbService = new AWS.DynamoDB();
    const tables = await dynamodbService.listTables().promise();
    
    // Find the User table (should contain 'User' and the environment)
    const userTable = tables.TableNames.find(name => 
      name.startsWith('User-') && 
      (name.includes(process.env.ENV) || name.includes('dev') || name.includes('prod'))
    );
    
    if (!userTable) {
      throw new Error('User table not found');
    }
    
    console.log(`📋 Using User table: ${userTable}`);
    return userTable;
    
  } catch (error) {
    console.error('❌ Error getting User table name:', error);
    throw error;
  }
}

