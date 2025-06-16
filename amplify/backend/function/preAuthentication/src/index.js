/* Amplify Params - DO NOT EDIT
	AUTH_SCHEDULINGAPP30672A99_USERPOOLID
	ENV
	REGION
Amplify Params - DO NOT EDIT */

const AWS = require('aws-sdk');

// Initialize AWS services
const dynamodb = new AWS.DynamoDB.DocumentClient();

/**
 * Pre Authentication Lambda Trigger for Cognito Account Linking
 * 
 * This function is the MOST CRUCIAL for account linking as it handles login scenarios:
 * 1. Ensures users always access the same account regardless of login method
 * 2. Maps OAuth logins to existing email-based accounts
 * 3. Maps cross-OAuth logins to the primary OAuth account
 * 4. Maintains session consistency across different authentication providers
 */
exports.handler = async (event) => {
  console.log('🔍 PreAuthentication trigger event:', JSON.stringify(event, null, 2));

  try {
    const { userName, request } = event;
    const { userAttributes } = request;
    const email = userAttributes.email;
    const authProvider = getAuthProvider(event);

    console.log(`🔐 Processing login for email: ${email}, provider: ${authProvider}, user: ${userName}`);

    // Find the primary account for this email
    const primaryAccount = await findPrimaryAccountByEmail(email);
    
    if (!primaryAccount) {
      console.log('ℹ️ No existing account found, allowing normal authentication');
      return event;
    }

    console.log(`🔍 Found primary account: ${JSON.stringify(primaryAccount, null, 2)}`);

    // Apply account linking logic for login
    const linkingResult = await applyLoginLinkingLogic(primaryAccount, authProvider, userName);
    
    if (linkingResult.requiresMapping) {
      console.log(`🔗 Setting up session mapping to primary account: ${linkingResult.primaryUserId}`);

      // Set custom attributes for session mapping (will be used by postAuthentication and app)
      event.response.userAttributes = {
        ...event.response.userAttributes,
        'custom:primary_user_id': linkingResult.primaryUserId,
        'custom:auth_provider': authProvider,
        'custom:linked_account': 'true',
        'custom:primary_account': 'false'
      };
    }

    console.log('✅ PreAuthentication processing completed successfully');
    return event;

  } catch (error) {
    console.error('❌ PreAuthentication error:', error);
    // Don't throw error to avoid blocking authentication
    // Log the error and continue with normal authentication
    return event;
  }
};

/**
 * Determine the authentication provider from the event
 */
function getAuthProvider(event) {
  const { triggerSource, request } = event;
  
  // Check if it's an external provider (OAuth)
  if (triggerSource === 'PreAuthentication_Authentication_ExternalProvider') {
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
 * Apply account linking logic for login scenarios
 */
async function applyLoginLinkingLogic(primaryAccount, loginAuthProvider, loginUserName) {
  const { id: primaryUserId, primaryAuthMethod, linkedAuthMethods = [] } = primaryAccount;
  
  console.log(`🔍 Applying login linking logic:
    - Primary account ID: ${primaryUserId}
    - Primary auth method: ${primaryAuthMethod}
    - Linked methods: ${JSON.stringify(linkedAuthMethods)}
    - Login auth provider: ${loginAuthProvider}
    - Login user name: ${loginUserName}`);

  // Case 1: User is logging in with the same method they registered with
  if (primaryAuthMethod === loginAuthProvider) {
    console.log('✅ Login method matches primary auth method');
    return {
      requiresMapping: false,
      primaryUserId: primaryUserId,
      reason: 'Login method matches primary authentication method'
    };
  }

  // Case 2: User is logging in with a linked authentication method
  if (linkedAuthMethods.includes(loginAuthProvider)) {
    console.log('🔗 Login method is a linked authentication method');
    return {
      requiresMapping: true,
      primaryUserId: primaryUserId,
      reason: `Login with linked ${loginAuthProvider} method mapped to primary ${primaryAuthMethod} account`
    };
  }

  // Case 3: Email-first account, user logging in with OAuth
  if (primaryAuthMethod === 'Email' && (loginAuthProvider === 'Google' || loginAuthProvider === 'Facebook')) {
    console.log('🔗 OAuth login to email-first account - auto-linking');
    
    // Add this OAuth method to linked methods
    await addLinkedAuthMethod(primaryUserId, loginAuthProvider);
    
    return {
      requiresMapping: true,
      primaryUserId: primaryUserId,
      reason: `OAuth ${loginAuthProvider} login auto-linked to email-first account`
    };
  }

  // Case 4: OAuth-first account, user logging in with different OAuth provider
  if ((primaryAuthMethod === 'Google' || primaryAuthMethod === 'Facebook') && 
      (loginAuthProvider === 'Google' || loginAuthProvider === 'Facebook') &&
      primaryAuthMethod !== loginAuthProvider) {
    console.log('🔗 Cross-OAuth login - auto-linking');
    
    // Add this OAuth method to linked methods
    await addLinkedAuthMethod(primaryUserId, loginAuthProvider);
    
    return {
      requiresMapping: true,
      primaryUserId: primaryUserId,
      reason: `Cross-OAuth ${loginAuthProvider} login auto-linked to ${primaryAuthMethod} account`
    };
  }

  // Case 5: OAuth-first account, user trying to login with email/password
  if ((primaryAuthMethod === 'Google' || primaryAuthMethod === 'Facebook') && loginAuthProvider === 'Email') {
    console.log('❌ Email/password login blocked for OAuth-first account');
    throw new Error(`Email/password login is disabled for this account. Please sign in with ${primaryAuthMethod}.`);
  }

  // Default case: Allow normal authentication
  console.log('ℹ️ No special linking required, allowing normal authentication');
  return {
    requiresMapping: false,
    primaryUserId: primaryUserId,
    reason: 'No account linking required'
  };
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
