/* Amplify Params - DO NOT EDIT
	AUTH_SCHEDULINGAPP30672A99_USERPOOLID
	ENV
	REGION
Amplify Params - DO NOT EDIT */

const AWS = require('aws-sdk');

// Initialize DynamoDB client
const dynamodb = new AWS.DynamoDB.DocumentClient();

/**
 * Pre Sign-up Lambda Trigger for Cognito Account Linking
 * 
 * This function implements the account linking logic:
 * 1. Email-first accounts (primary): Allow OAuth linking to existing email account
 * 2. OAuth-first accounts (primary): Block email/password registration for this email
 * 3. Cross-OAuth linking: Allow linking between Google and Facebook with same email
 */
exports.handler = async (event) => {
  console.log('🔍 PreSignUp trigger event:', JSON.stringify(event, null, 2));

  try {
    const { userPoolId, userName, request } = event;
    const { userAttributes, validationData } = request;
    const email = userAttributes.email;
    const authProvider = getAuthProvider(event);

    console.log(`📧 Processing signup for email: ${email}, provider: ${authProvider}`);

    // Find existing user by email
    const existingUser = await findUserByEmail(email);
    
    if (!existingUser) {
      console.log('✅ No existing user found, allowing signup');
      return event;
    }

    console.log(`🔍 Found existing user: ${JSON.stringify(existingUser, null, 2)}`);

    // Apply account linking rules
    const linkingDecision = await applyLinkingRules(existingUser, authProvider);
    
    if (linkingDecision.allow) {
      console.log(`✅ Signup allowed: ${linkingDecision.reason}`);
      
      // Set custom attributes for linking
      event.response.userAttributes = {
        ...event.response.userAttributes,
        'custom:primary_user_id': existingUser.id,
        'custom:auth_provider': authProvider,
        'custom:linked_account': 'true',
        'custom:primary_account': existingUser.primaryAuthMethod === authProvider ? 'true' : 'false'
      };
      
      return event;
    } else {
      console.log(`❌ Signup blocked: ${linkingDecision.reason}`);
      throw new Error(linkingDecision.reason);
    }

  } catch (error) {
    console.error('❌ PreSignUp error:', error);
    throw error;
  }
};

/**
 * Determine the authentication provider from the event
 */
function getAuthProvider(event) {
  const { triggerSource, request, userName } = event;

  console.log(`🔍 Detecting auth provider - triggerSource: ${triggerSource}, userName: ${userName}`);

  // Check if it's an external provider (OAuth)
  if (triggerSource === 'PreSignUp_ExternalProvider') {
    const userAttributes = request.userAttributes;

    // Check for Google provider indicators
    if (userName.includes('Google_') ||
        userName.includes('google_') ||
        userAttributes['cognito:username']?.includes('Google') ||
        request.clientMetadata?.provider === 'Google') {
      console.log('✅ Detected Google OAuth provider');
      return 'Google';
    }

    // Check for Facebook provider indicators
    if (userName.includes('Facebook_') ||
        userName.includes('facebook_') ||
        userAttributes['cognito:username']?.includes('Facebook') ||
        request.clientMetadata?.provider === 'Facebook') {
      console.log('✅ Detected Facebook OAuth provider');
      return 'Facebook';
    }

    console.log('⚠️ Generic OAuth provider detected');
    return 'OAuth'; // Generic OAuth if we can't determine specific provider
  }

  // Default to email/password
  console.log('✅ Detected Email/Password provider');
  return 'Email';
}

/**
 * Find existing user by email in DynamoDB
 */
async function findUserByEmail(email) {
  try {
    // Get the User table name dynamically
    const tableName = await getUserTableName();
    
    const params = {
      TableName: tableName,
      IndexName: 'byEmail', // GSI on email field
      KeyConditionExpression: 'email = :email',
      ExpressionAttributeValues: {
        ':email': email
      }
    };

    console.log(`🔍 Querying DynamoDB with params:`, JSON.stringify(params, null, 2));
    
    const result = await dynamodb.query(params).promise();
    
    if (result.Items && result.Items.length > 0) {
      console.log(`✅ Found ${result.Items.length} user(s) with email: ${email}`);
      return result.Items[0]; // Return the first (primary) user
    }
    
    console.log(`ℹ️ No user found with email: ${email}`);
    return null;
    
  } catch (error) {
    console.error('❌ Error finding user by email:', error);
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

    // Find the User table (should start with 'User-' and contain the environment)
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

/**
 * Apply account linking rules based on existing user and new auth provider
 */
async function applyLinkingRules(existingUser, newAuthProvider) {
  const { primaryAuthMethod, linkedAuthMethods = [] } = existingUser;
  
  console.log(`🔍 Applying linking rules:
    - Existing primary auth: ${primaryAuthMethod}
    - Existing linked methods: ${JSON.stringify(linkedAuthMethods)}
    - New auth provider: ${newAuthProvider}`);

  // Rule 1: Email-first accounts (primary) - Allow OAuth linking
  if (primaryAuthMethod === 'Email') {
    if (newAuthProvider === 'Google' || newAuthProvider === 'Facebook') {
      return {
        allow: true,
        reason: `OAuth linking allowed to email-first account (${newAuthProvider} -> Email)`
      };
    }
    
    if (newAuthProvider === 'Email') {
      return {
        allow: false,
        reason: 'Email/password account already exists for this email address'
      };
    }
  }

  // Rule 2: OAuth-first accounts (primary) - Block email/password registration
  if (primaryAuthMethod === 'Google' || primaryAuthMethod === 'Facebook') {
    if (newAuthProvider === 'Email') {
      return {
        allow: false,
        reason: `Email/password registration disabled for OAuth-first account (primary: ${primaryAuthMethod})`
      };
    }
    
    // Rule 3: Cross-OAuth linking (Google <-> Facebook)
    if ((primaryAuthMethod === 'Google' && newAuthProvider === 'Facebook') ||
        (primaryAuthMethod === 'Facebook' && newAuthProvider === 'Google')) {
      return {
        allow: true,
        reason: `Cross-OAuth linking allowed (${newAuthProvider} -> ${primaryAuthMethod})`
      };
    }
    
    // Same provider attempting to register again
    if (primaryAuthMethod === newAuthProvider) {
      return {
        allow: false,
        reason: `${newAuthProvider} account already exists for this email address`
      };
    }
  }

  // Default: Block unknown scenarios
  return {
    allow: false,
    reason: `Unknown linking scenario: ${newAuthProvider} -> ${primaryAuthMethod}`
  };
}
