import { randomUUID } from 'node:crypto';

import { config } from './config.mjs';

export async function handler(request, context) {
  const { databases } = context.bindings;
  const { body } = request;

  const { from, to, subject, body: messageBody, images } = body;

  if (!to) return { statusCode: 400, body: "Missing 'to' property in body!" };
  if (!subject)
    return { statusCode: 400, body: "Missing 'subject' property in body!" };
  if (!messageBody)
    return { statusCode: 400, body: "Missing 'body' property in body!" };

  try {
    const messageId = randomUUID();
    const message = {
      id: messageId,
      from: from || 'Anonymous',
      to,
      subject,
      body: messageBody,
      images: images || [],
      date: new Date().toISOString()
    };

    await databases.write(config.tableName, messageId, message);

    return {
      statusCode: 200,
      body: {
        message: 'Message posted',
        id: messageId
      }
    };
  } catch (error) {
    return {
      statusCode: 500,
      body: {
        error: 'Failed to post message',
        message: error.message
      }
    };
  }
}
