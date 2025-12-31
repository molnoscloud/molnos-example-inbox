import { config } from './config.mjs';

export async function handler(request, context) {
  const { databases } = context.bindings;
  const { body } = request;
  const userEmail = body?.userEmail;

  if (!userEmail)
    return {
      statusCode: 400,
      body: 'User email not provided in request'
    };

  const result = await databases.get(config.tableName);

  // Filter messages to only show those sent to the authenticated user's email
  const messages =
    result
      ?.map((data) => {
        const [_key, value] = data;
        return value;
      })
      .filter((message) => message.to === userEmail) || [];

  return messages;
}
