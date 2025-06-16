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
 * Post Authentication Lambda Trigger for Cognito Account Linking
 * 
 * This function ensures proper session mapping after successful authentication:
 * 1. Detects linked accounts and ensures session attributes are properly set
 * 2. Updates user attributes to reflect primary account mapping
 * 3. Logs successful authentication events for linked accounts
 * 4. Ensures consistent session data for the application layer
 */
exports.handler = async (event) => {
  console.log('🔍 PostAuthentication trigger event:', JSON.stringify(event, null, 2));

  try {
    const { userPoolId, userName, request } = event;
    const { userAttributes } = request;
    const email = userAttributes.email;
    const authProvider = getAuthProvider(event);

    console.log(`✅ User authenticated - email: ${email}, provider: ${authProvider}, user: ${userName}`);

    // Check if this is a linked account that needs session mapping
    const primaryAccount = await findPrimaryAccountByEmail(email);
    
    if (!primaryAccount) {
      console.log('ℹ️ No primary account found, this is a standalone account');
      return event;
    }

    // Determine if this authentication needs session mapping
    const sessionMapping = await determineSessionMapping(primaryAccount, authProvider, userName);
    
    if (sessionMapping.needsMapping) {
      console.log(`🔗 Setting up session mapping for linked account`);
      
      // Update user attributes to ensure proper session mapping
      await updateSessionAttributes(userPoolId, userName, sessionMapping);
      
      // Log the successful account linking authentication
      console.log(`✅ Successfully mapped ${authProvider} authentication to primary account: ${sessionMapping.primaryUserId}`);
    }

    return event;

  } catch (error) {
    console.error('❌ PostAuthentication error:', error);
    // Don't throw error to avoid disrupting user session
    return event;
  }
};

/**
 * Determine the authentication provider from the event
 */
function getAuthProvider(event) {
  const { triggerSource, userName } = event;
  
  console.log(`🔍 Detecting auth provider - triggerSource: ${triggerSource}, userName: ${userName}`);
  
  // Check if it's an external provider (OAuth)
  if (triggerSource === 'PostAuthentication_Authentication_ExternalProvider') {
    // Check for Google provider indicators
    if (userName.includes('Google_') || userName.includes('google_')) {
      console.log('✅ Detected Google OAuth provider');
      return 'Google';
    }
    
    // Check for Facebook provider indicators  
    if (userName.includes('Facebook_') || userName.includes('facebook_')) {
      console.log('✅ Detected Facebook OAuth provider');
      return 'Facebook';
    }
    
    console.log('⚠️ Generic OAuth provider detected');
    return 'OAuth';
  }
  
  // Default to email/password
  console.log('✅ Detected Email/Password provider');
  return 'Email';
}

/**
 * Find the primary account by email in DynamoDB
 */
async function findPrimaryAccountByEmail(email) {
  try {
    const tableName = await getUserTableName();
    
    const params = {
      TableName: tableName,
      IndexName: 'byEmail', // GSI on email field
      KeyConditionExpression: 'email = :email',
      ExpressionAttributeValues: {
        ':email': email
      }
    };

    console.log(`🔍 Querying DynamoDB for primary account:`, JSON.stringify(params, null, 2));
    
    const result = await dynamodb.query(params).promise();
    
    if (result.Items && result.Items.length > 0) {
      console.log(`✅ Found ${result.Items.length} account(s) with email: ${email}`);
      return result.Items[0]; // Return the primary account
    }
    
    console.log(`ℹ️ No account found with email: ${email}`);
    return null;
    
  } catch (error) {
    console.error('❌ Error finding primary account by email:', error);
    throw error;
  }
}

/**
 * Determine if session mapping is needed and what attributes to set
 */
async function determineSessionMapping(primaryAccount, authProvider, cognitoUserName) {
  const { id: primaryUserId, primaryAuthMethod, linkedAuthMethods = [] } = primaryAccount;
  
  console.log(`🔍 Determining session mapping:
    - Primary account ID: ${primaryUserId}
    - Primary auth method: ${primaryAuthMethod}
    - Linked methods: ${JSON.stringify(linkedAuthMethods)}
    - Current auth provider: ${authProvider}
    - Cognito user name: ${cognitoUserName}`);

  // Case 1: User authenticated with primary method
  if (primaryAuthMethod === authProvider) {
    return {
      needsMapping: true,
      primaryUserId: primaryUserId,
      isPrimaryAccount: true,
      authProvider: authProvider,
      reason: 'Primary account authentication'
    };
  }

  // Case 2: User authenticated with linked method
  if (linkedAuthMethods.includes(authProvider)) {
    return {
      needsMapping: true,
      primaryUserId: primaryUserId,
      isPrimaryAccount: false,
      authProvider: authProvider,
      reason: `Linked ${authProvider} account authentication`
    };
  }

  // Case 3: New OAuth method for email-first account (auto-link)
  if (primaryAuthMethod === 'Email' && (authProvider === 'Google' || authProvider === 'Facebook')) {
    // Add this method to linked methods
    await addLinkedAuthMethod(primaryUserId, authProvider);
    
    return {
      needsMapping: true,
      primaryUserId: primaryUserId,
      isPrimaryAccount: false,
      authProvider: authProvider,
      reason: `Auto-linked ${authProvider} to email-first account`
    };
  }

  // Case 4: Cross-OAuth authentication (auto-link)
  if ((primaryAuthMethod === 'Google' || primaryAuthMethod === 'Facebook') && 
      (authProvider === 'Google' || authProvider === 'Facebook') &&
      primaryAuthMethod !== authProvider) {
    
    // Add this method to linked methods
    await addLinkedAuthMethod(primaryUserId, authProvider);
    
    return {
      needsMapping: true,
      primaryUserId: primaryUserId,
      isPrimaryAccount: false,
      authProvider: authProvider,
      reason: `Auto-linked ${authProvider} to ${primaryAuthMethod} account`
    };
  }

  // Default: No mapping needed
  return {
    needsMapping: false,
    reason: 'No session mapping required'
  };
}

/**
 * Update session attributes for proper account linking
 */
async function updateSessionAttributes(userPoolId, userName, sessionMapping) {
  try {
    const attributes = {
      'custom:primary_user_id': sessionMapping.primaryUserId,
      'custom:auth_provider': sessionMapping.authProvider,
      'custom:linked_account': sessionMapping.isPrimaryAccount ? 'false' : 'true',
      'custom:primary_account': sessionMapping.isPrimaryAccount ? 'true' : 'false'
    };

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
    console.log(`✅ Updated session attributes for user: ${userName}`);
    console.log(`📋 Session mapping: ${JSON.stringify(attributes, null, 2)}`);
    
  } catch (error) {
    console.error('❌ Error updating session attributes:', error);
    // Don't throw error to avoid disrupting user session
  }
}

/**
 * Add a linked authentication method to the user account
 */
async function addLinkedAuthMethod(primaryUserId, authMethod) {
  try {
    const tableName = await getUserTableName();
    
    const params = {
      TableName: tableName,
      Key: { id: primaryUserId },
      UpdateExpression: 'ADD linkedAuthMethods :authMethod SET updatedAt = :updatedAt',
      ExpressionAttributeValues: {
        ':authMethod': dynamodb.createSet([authMethod]),
        ':updatedAt': new Date().toISOString()
      }
    };

    console.log(`🔗 Adding linked auth method ${authMethod} to user ${primaryUserId}`);
    await dynamodb.update(params).promise();
    console.log(`✅ Successfully added ${authMethod} to linked methods`);
    
  } catch (error) {
    console.error('❌ Error adding linked auth method:', error);
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
