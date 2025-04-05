const amplifyconfig = '''{
  "UserAgent": "aws-amplify-cli/2.0",
  "Version": "1.0",
  "auth": {
    "plugins": {
      "awsCognitoAuthPlugin": {
        "UserAgent": "aws-amplify/cli",
        "Version": "0.1.0",
        "IdentityManager": {"Default": {}},
        "CognitoUserPool": {
          "Default": {
            "PoolId": "us-east-1_tC6894ltu",
            "AppClientId": "7p2ic1flkf7dlhf2fbm3g3uce6",
            "Region": "us-east-1"
          }
        }
      }
    }
  }
}''';
