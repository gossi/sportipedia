import { createHmac } from 'node:crypto';

function signRequest(secret: string, body: string, timestamp: string) {
  const payload = `${timestamp}.${body}`;

  console.log('HMAC payload', payload);

  return createHmac('sha256', secret).update(payload, 'utf8').digest('hex');
}

type Email = 'confirm-email' | 'password-reset';

export async function sendEmail(email: Email, data: Record<string, unknown>) {
  const body = JSON.stringify({ data });
  const timestamp = Math.floor(Date.now() / 1000).toString();

  const signature = signRequest(process.env.AUTH_API_SECRET as string, body, timestamp);

  console.log('Send Email', {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
      'X-Timestamp': timestamp,
      'X-Signature': signature
    },
    body
  });

  await fetch(`${process.env.API_URL}/accounts/mailer/${email}`, {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
      'X-Timestamp': timestamp,
      'X-Signature': signature
    },
    body
  });
}
