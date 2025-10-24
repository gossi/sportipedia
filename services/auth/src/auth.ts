import { betterAuth } from "better-auth";
import { openAPI, admin, jwt, bearer } from "better-auth/plugins"
import { Pool } from 'pg'

export const auth = betterAuth({
  appName: 'Sportipedia',
  basePath: "/",
  database: new Pool({
    host: process.env.DB_HOSTNAME,
    database: process.env.DB_DATABASE,
    user: process.env.DB_USERNAME,
    password: process.env.DB_PASSWORD,
    options: '-c search_path=auth'
  }),
  trustedOrigins: [
    'http://localhost:4200'
  ],
  emailAndPassword: {
    enabled: true
  },
  socialProviders: {
    github: {
      clientId: process.env.GITHUB_CLIENT_ID as string,
      clientSecret: process.env.GITHUB_CLIENT_SECRET as string,
      redirectURI: 'http://localhost:3000/callback/github',
      mapProfileToUser: (profile) => {
        const names = profile.name.split(' ');
        return {
          givenName: names[0],
          familyName: names[names.length - 1]
        };
      },
    }
  },
  user: {
    additionalFields: {
      givenName: {
        type: 'string',
        required: true,
      },
      familyName: {
        type: 'string',
        required: true,
      },
      lang: {
        type: "string",
        required: false,
        defaultValue: "en",
      },
    },
  },
  plugins: [
    openAPI(),
    admin(),
    jwt(),
    bearer()
  ]
})
