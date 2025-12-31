import { config } from './config.mjs';

export async function handler(request, context) {
  const { body } = request;
  const { databases } = context.bindings;
  const userEmail = body?.userEmail;
  const messageId = body?.id;

  if (!userEmail)
    return {
      statusCode: 400,
      body: 'User email not provided in request'
    };

  if (!messageId)
    return { statusCode: 400, body: "Missing 'id' property in body!" };

  const result = await databases.get(config.tableName, messageId);

  const message = result;

  // Verify the message is addressed to the authenticated user
  if (message.to !== userEmail) {
    return {
      statusCode: 403,
      body: 'You do not have permission to view this message'
    };
  }

  return { statusCode: 200, body: message };
}
