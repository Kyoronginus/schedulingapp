import { AmplifyS3ResourceTemplate } from '@aws-amplify/cli-extensibility-helper';

export function override(resources: AmplifyS3ResourceTemplate) {
    // Get the IAM policy that Amplify creates for logged-in users
    const authRolePolicy = resources.s3AuthPublicPolicy;

    // This is the new permission rule we are adding.
    // It allows any logged-in user to read files from the 'protected' folder.
    const allowReadOnProtectedStatement = {
        "Sid": "AllowReadOnProtected",
        "Effect": "Allow",
        "Action": [
            "s3:GetObject"
        ],
        "Resource": [
            `arn:aws:s3:::${resources.s3Bucket.bucketName}/protected/*`
        ]
    };

    // Add permission for public folder access (for profile pictures)
    const allowReadOnPublicStatement = {
        "Sid": "AllowReadOnPublic",
        "Effect": "Allow",
        "Action": [
            "s3:GetObject"
        ],
        "Resource": [
            `arn:aws:s3:::${resources.s3Bucket.bucketName}/public/*`
        ]
    };

    // Add the new rules to the policy
    (authRolePolicy.policyDocument.Statement as any[]).push(allowReadOnProtectedStatement);
    (authRolePolicy.policyDocument.Statement as any[]).push(allowReadOnPublicStatement);
}