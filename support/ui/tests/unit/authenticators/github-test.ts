// import { module, test } from 'qunit';
// import { setupTest } from 'ember-qunit';

// import { calculatePKCECodeChallenge } from 'oauth4webapi';

// import { GithubAuthenticator } from '#/';

// module('Unit | Authenticator | Github', function (hooks) {
//   setupTest(hooks);

//   test('authorizeUrl is generated', async (assert) => {
//     const github = new GithubAuthenticator({
//       clientId: 'CLIENT_ID',
//       redirectURI: 'https://example.com/auth/github/callback'
//     });

//     const codeChallenge = await calculatePKCECodeChallenge(github.codeVerifier);
//     const authorizeURL = await github.generateAuthorizationURL();

//     assert.strictEqual(
//       authorizeURL.toString(),
//       `https://github.com/login/oauth/authorize?client_id=CLIENT_ID&code_challenge=${codeChallenge}&code_challenge_method=S256&redirect_uri=https%3A%2F%2Fexample.com%2Fauth%2Fgithub%2Fcallback&response_type=code&scope=read%3Auser+user%3Aemail`
//     );
//   });
// });
