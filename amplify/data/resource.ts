import { type ClientSchema, a, defineData } from "@aws-amplify/backend";

/*== STEP 1 ===============================================================
The section below creates a Todo database table with a "content" field. Try
adding a new "isDone" field as a boolean. The authorization rule below
specifies that any user authenticated via an API key can "create", "read",
"update", and "delete" any "Todo" records.
=========================================================================*/
const schema = a.schema({
  Comment: a.customType({
    author: a.string(),
    content: a.string()
  }),
  Location: a
    .model({
      date: a.date().required(), 
      time: a.time(), 
      track: a.integer().required(),
      type: a.string(), 
      diameter: a.float().required(),
      length: a.float().required(), 
      lat: a.float().required(),
      lng: a.float().required(),
      username: a.string(),
      description: a.string(),
      photos: a.string().array(),
      comments: a.ref('Comment').array(),
      joint: a.boolean()
    })
    .authorization((allow) => [allow.publicApiKey()]),
});

export type Schema = ClientSchema<typeof schema>;

export const data = defineData({
  schema,
  authorizationModes: {
    defaultAuthorizationMode: "apiKey",
    // API Key is used for a.allow.public() rules
    apiKeyAuthorizationMode: {
      expiresInDays: 30,
    },
  },
});


