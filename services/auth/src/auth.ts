import { betterAuth } from 'better-auth';
import { admin, bearer, jwt, openAPI } from 'better-auth/plugins';
import { Pool } from 'pg';

import { sendEmail } from './email';

export const auth = betterAuth({
  appName: 'Sportipedia',
  basePath: '/',
  database: new Pool({
    host: process.env.AUTH_DB_HOSTNAME,
    database: process.env.AUTH_DB_DATABASE,
    user: process.env.AUTH_DB_USERNAME,
    password: process.env.AUTH_DB_PASSWORD,
    options: '-c search_path=auth'
  }),
  trustedOrigins: [process.env.ADMIN_URL as string, process.env.CATALOG_URL as string],
  emailAndPassword: {
    enabled: true,
    // requireEmailVerification: true,
    sendResetPassword: async ({ url, user }) => {
      await sendEmail('password-reset', {
        email: user.email,
        name: user.name,
        url
      });
    }
  },
  emailVerification: {
    sendVerificationEmail: async ({ url, user }) => {
      await sendEmail('confirm-email', {
        email: user.email,
        name: user.name,
        url
      });
    }
  },
  socialProviders: {
    github: {
      clientId: process.env.GITHUB_CLIENT_ID as string,
      clientSecret: process.env.GITHUB_CLIENT_SECRET as string,
      redirectURI: `${process.env.AUTH_URL}/callback/github`,
      mapProfileToUser: (profile) => {
        const names = profile.name.split(' ');

        return {
          givenName: names[0],
          familyName: names.at(-1)
        };
      }
    },
    google: {
      clientId: process.env.GOOGLE_CLIENT_ID as string,
      clientSecret: process.env.GOOGLE_CLIENT_SECRET as string,
      redirectURI: `${process.env.AUTH_URL}/callback/google`
    }
  },
  user: {
    changeEmail: {
      enabled: true
    },
    additionalFields: {
      givenName: {
        type: 'string',
        required: true
      },
      familyName: {
        type: 'string',
        required: true
      },
      lang: {
        type: 'string',
        required: false,
        defaultValue: 'en'
      }
    }
  },
  plugins: [openAPI(), admin(), jwt(), bearer()]
});
