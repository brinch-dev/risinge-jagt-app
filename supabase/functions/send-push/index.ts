const FIREBASE_PROJECT_ID = "risinge-jagt";

Deno.serve(async (req) => {
  try {
    const { type, ...payload } = await req.json();

    const supabaseUrl = Deno.env.get("SUPABASE_URL")!;
    const supabaseKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;

    let tokens: string[] = [];
    let title = "";
    let body = "";
    let data: Record<string, string> = {};

    if (type === "chat_message") {
      const { channel_id, sender_id, content } = payload;

      const [senderRes, channelRes, membersRes] = await Promise.all([
        supabaseQuery(supabaseUrl, supabaseKey, "profiles", `id=eq.${sender_id}&select=display_name`),
        supabaseQuery(supabaseUrl, supabaseKey, "chat_channels", `id=eq.${channel_id}&select=name`),
        supabaseQuery(supabaseUrl, supabaseKey, "channel_members", `channel_id=eq.${channel_id}&user_id=neq.${sender_id}&select=user_id`),
      ]);

      const senderName = senderRes[0]?.display_name || "Ukendt";
      const channelName = channelRes[0]?.name || "Chat";

      if (membersRes.length > 0) {
        const userIds = membersRes.map((m: { user_id: string }) => m.user_id);
        const tokenQuery = `user_id=in.(${userIds.join(",")})&select=token`;
        const tokenRows = await supabaseQuery(supabaseUrl, supabaseKey, "fcm_tokens", tokenQuery);
        tokens = tokenRows.map((t: { token: string }) => t.token);
      }

      title = channelName;
      body = `${senderName}: ${(content || "").substring(0, 120)}`;
      data = { type: "chat", channel_id };

    } else if (type === "broadcast") {
      const { title: t, message, sender_id } = payload;

      let query = "select=token,user_id";
      if (sender_id) query += `&user_id=neq.${sender_id}`;
      const tokenRows = await supabaseQuery(supabaseUrl, supabaseKey, "fcm_tokens", query);
      tokens = tokenRows.map((t: { token: string }) => t.token);

      title = t || "Meddelelse";
      body = message || "";
      data = { type: "broadcast" };

    } else if (type === "event_notification") {
      const { title: t, message, exclude_user_id } = payload;

      let query = "select=token,user_id";
      if (exclude_user_id) query += `&user_id=neq.${exclude_user_id}`;
      const tokenRows = await supabaseQuery(supabaseUrl, supabaseKey, "fcm_tokens", query);
      tokens = tokenRows.map((t: { token: string }) => t.token);

      title = t || "Begivenhed";
      body = message || "";
      data = { type: "event" };
    }

    if (tokens.length === 0) {
      return jsonResponse({ sent: 0, reason: "no tokens" });
    }

    const accessToken = await getFirebaseAccessToken();

    let sent = 0;
    const errors: string[] = [];

    for (const token of tokens) {
      try {
        const res = await fetch(
          `https://fcm.googleapis.com/v1/projects/${FIREBASE_PROJECT_ID}/messages:send`,
          {
            method: "POST",
            headers: {
              Authorization: `Bearer ${accessToken}`,
              "Content-Type": "application/json",
            },
            body: JSON.stringify({
              message: {
                token,
                notification: { title, body },
                data,
                android: {
                  priority: "high",
                  notification: { sound: "default", channel_id: "default" },
                },
              },
            }),
          }
        );
        if (res.ok) {
          sent++;
        } else {
          const errText = await res.text();
          errors.push(errText);
          if (errText.includes("UNREGISTERED") || errText.includes("NOT_FOUND")) {
            await supabaseDelete(supabaseUrl, supabaseKey, "fcm_tokens", `token=eq.${token}`);
          }
        }
      } catch (e) {
        errors.push(String(e));
      }
    }

    return jsonResponse({ sent, total: tokens.length, errors: errors.slice(0, 3) });
  } catch (e) {
    return jsonResponse({ error: String(e) }, 500);
  }
});

async function supabaseQuery(url: string, key: string, table: string, query: string): Promise<any[]> {
  const res = await fetch(`${url}/rest/v1/${table}?${query}`, {
    headers: {
      apikey: key,
      Authorization: `Bearer ${key}`,
    },
  });
  return await res.json();
}

async function supabaseDelete(url: string, key: string, table: string, query: string): Promise<void> {
  await fetch(`${url}/rest/v1/${table}?${query}`, {
    method: "DELETE",
    headers: {
      apikey: key,
      Authorization: `Bearer ${key}`,
    },
  });
}

function jsonResponse(data: unknown, status = 200): Response {
  return new Response(JSON.stringify(data), {
    status,
    headers: { "Content-Type": "application/json" },
  });
}

async function getFirebaseAccessToken(): Promise<string> {
  const serviceAccount = JSON.parse(Deno.env.get("FIREBASE_SERVICE_ACCOUNT")!);
  const now = Math.floor(Date.now() / 1000);

  const header = base64url(JSON.stringify({ alg: "RS256", typ: "JWT" }));
  const claimSet = base64url(
    JSON.stringify({
      iss: serviceAccount.client_email,
      scope: "https://www.googleapis.com/auth/firebase.messaging",
      aud: "https://oauth2.googleapis.com/token",
      iat: now,
      exp: now + 3600,
    })
  );

  const encoder = new TextEncoder();
  const input = encoder.encode(`${header}.${claimSet}`);

  const privateKey = await crypto.subtle.importKey(
    "pkcs8",
    pemToBuffer(serviceAccount.private_key),
    { name: "RSASSA-PKCS1-v1_5", hash: "SHA-256" },
    false,
    ["sign"]
  );

  const signature = await crypto.subtle.sign("RSASSA-PKCS1-v1_5", privateKey, input);
  const jwt = `${header}.${claimSet}.${base64url(signature)}`;

  const tokenRes = await fetch("https://oauth2.googleapis.com/token", {
    method: "POST",
    headers: { "Content-Type": "application/x-www-form-urlencoded" },
    body: `grant_type=urn:ietf:params:oauth:grant-type:jwt-bearer&assertion=${jwt}`,
  });

  const tokenData = await tokenRes.json();
  if (!tokenData.access_token) {
    throw new Error(`Firebase auth failed: ${JSON.stringify(tokenData)}`);
  }
  return tokenData.access_token;
}

function base64url(input: string | ArrayBuffer): string {
  let b64: string;
  if (typeof input === "string") {
    b64 = btoa(input);
  } else {
    const bytes = new Uint8Array(input);
    let binary = "";
    for (let i = 0; i < bytes.length; i++) {
      binary += String.fromCharCode(bytes[i]);
    }
    b64 = btoa(binary);
  }
  return b64.replace(/\+/g, "-").replace(/\//g, "_").replace(/=+$/, "");
}

function pemToBuffer(pem: string): ArrayBuffer {
  const b64 = pem
    .replace(/-----BEGIN PRIVATE KEY-----/, "")
    .replace(/-----END PRIVATE KEY-----/, "")
    .replace(/\n/g, "");
  const binary = atob(b64);
  const buffer = new ArrayBuffer(binary.length);
  const view = new Uint8Array(buffer);
  for (let i = 0; i < binary.length; i++) {
    view[i] = binary.charCodeAt(i);
  }
  return buffer;
}
