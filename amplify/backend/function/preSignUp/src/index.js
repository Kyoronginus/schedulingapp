/* Amplify Params - DO NOT EDIT
  API_SCHEDULINGAPP_GRAPHQLAPIIDOUTPUT
  API_SCHEDULINGAPP_USERTABLE_ARN
  API_SCHEDULINGAPP_USERTABLE_NAME
  AUTH_SCHEDULINGAPP30672A99_USERPOOLID
  ENV
  REGION
Amplify Params - DO NOT EDIT */

const AWS = require('aws-sdk');
const cognito = new AWS.CognitoIdentityServiceProvider();
const dynamodb = new AWS.DynamoDB.DocumentClient();

/**
 * Pre SignUp Lambda Trigger for Cognito Identity Linking.
 * This is the definitive, architecturally correct version using the stable AWS SDK v2.
 */
exports.handler = async (event) => {
  console.log('🔍 PreSignUp trigger event:', JSON.stringify(event, null, 2));

  const { userPoolId, userName, request } = event;
  const userEmail = request.userAttributes.email;

  if (!userEmail) { throw new Error('Email not found in request.'); }

  try {
    const { Users } = await cognito.listUsers({
      UserPoolId: userPoolId,
      Filter: `email = "${userEmail}"`,
      Limit: 1,
    }).promise();

    if (Users && Users.length > 0) {
      const existingUser = Users[0];
      if (event.triggerSource.startsWith('PreSignUp_ExternalProvider')) {
        console.log(`✅ Existing user ${existingUser.Username} found. Linking new provider.`);
        const [providerName, providerUserId] = userName.split('_');

        await cognito.adminLinkProviderForUser({
          UserPoolId: userPoolId,
          DestinationUser: { ProviderName: 'Cognito', ProviderAttributeValue: existingUser.Username },
          SourceUser: {
            ProviderName: providerName.charAt(0).toUpperCase() + providerName.slice(1),
            ProviderAttributeName: 'Cognito_Subject',
            ProviderAttributeValue: providerUserId,
          },
        }).promise();

        await updateLinkedAuthMethods(existingUser.Username, providerName);
        throw new Error('Successfully linked new provider to existing account.');
      } else {
        throw new Error('An account with this email already exists. Please sign in with your original method.');
      }
    }

    console.log('ℹ️ No existing user found. Allowing new user creation.');
    return event;

  } catch (error) {
    if (error.message.includes('Successfully linked') || error.message.includes('Please sign in')) {
      throw error;
    }
    console.error('❌ An unexpected error occurred in PreSignUp:', error);
    throw error;
  }
};

async function updateLinkedAuthMethods(userId, newProvider) {
  const tableName = process.env.API_SCHEDULINGAPP_USERTABLE_NAME;
  if (!tableName) {
    console.error('USER_TABLE_NAME env var not set!');
    return;
  }
  console.log(`🔗 Updating linked methods for user ${userId} with new provider ${newProvider}`);
  try {
    const { Item } = await dynamodb.get({ TableName: tableName, Key: { id: userId } }).promise();
    if (!Item) {
      console.error(`❌ Could not find user ${userId} in DynamoDB to update.`);
      return;
    }
    const existingMethods = Item.linkedAuthMethods ? Array.from(Item.linkedAuthMethods.values) : [];
    const updatedMethods = new Set([...existingMethods, newProvider.toUpperCase()]);

    await dynamodb.update({
      TableName: tableName,
      Key: { id: userId },
      UpdateExpression: 'SET linkedAuthMethods = :methods, updatedAt = :now',
      ExpressionAttributeValues: {
        ':methods': dynamodb.createSet(Array.from(updatedMethods)),
        ':now': new Date().toISOString(),
      },
    }).promise();
    console.log(`✅ Successfully updated linked methods for user ${userId}`);
  } catch (error) {
    console.error(`❌ Error updating linked auth methods for user ${userId}:`, error);
  }
}
