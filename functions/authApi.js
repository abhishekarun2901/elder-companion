const crypto = require("crypto");
const express = require("express");
const cors = require("cors");
const nodemailer = require("nodemailer");
const {onRequest} = require("firebase-functions/v2/https");
const admin = require("firebase-admin");

const app = express();
const db = admin.firestore();

const OTP_COLLECTION = "auth_otps";
const OTP_LENGTH = 6;
const OTP_EXPIRY_SECONDS = 300;
const MAX_ATTEMPTS = 3;
const MAX_REQUESTS_PER_WINDOW = 3;
const RATE_LIMIT_WINDOW_MS = 60 * 1000;
const REGION = process.env.AUTH_API_REGION || "us-central1";
const DEFAULT_WHATSAPP_DEMO_NUMBER = "+916238049108";
const DEFAULT_WHATSAPP_DEMO_OTP = "567456";

app.use(cors({origin: true}));
app.use(express.json());

app.get("/health", (req, res) => {
  res.status(200).json({
    success: true,
    service: "authApi",
    timestamp: Date.now(),
  });
});

app.post("/auth/whatsapp/send", async (req, res) => {
  try {
    const phone = normalizePhone(req.body.phone);
    const result = await createAndSendOtp({
      channel: "whatsapp",
      identifier: phone,
      sender: (otp) => sendWhatsappOtp(phone, otp),
    });

    res.status(200).json({
      success: true,
      channel: "whatsapp",
      destinationHint: maskPhone(phone),
      expiresInSeconds: OTP_EXPIRY_SECONDS,
      devOtpHint: result.devOtpHint,
      deliveryMode: result.deliveryMode,
    });
  } catch (error) {
    handleError(res, error);
  }
});

app.post("/auth/whatsapp/verify", async (req, res) => {
  try {
    const phone = normalizePhone(req.body.phone);
    const otp = normalizeOtp(req.body.otp);
    const token = await verifyOtpAndCreateToken({
      channel: "whatsapp",
      identifier: phone,
      otp,
    });

    res.status(200).json({
      success: true,
      channel: "whatsapp",
      customToken: token.customToken,
      uid: token.uid,
    });
  } catch (error) {
    handleError(res, error);
  }
});

app.post("/auth/email/send", async (req, res) => {
  try {
    const email = normalizeEmail(req.body.email);
    const result = await createAndSendOtp({
      channel: "email",
      identifier: email,
      sender: (otp) => sendEmailOtp(email, otp),
    });

    res.status(200).json({
      success: true,
      channel: "email",
      destinationHint: maskEmail(email),
      expiresInSeconds: OTP_EXPIRY_SECONDS,
      devOtpHint: result.devOtpHint,
      deliveryMode: result.deliveryMode,
    });
  } catch (error) {
    handleError(res, error);
  }
});

app.post("/auth/email/verify", async (req, res) => {
  try {
    const email = normalizeEmail(req.body.email);
    const otp = normalizeOtp(req.body.otp);
    const token = await verifyOtpAndCreateToken({
      channel: "email",
      identifier: email,
      otp,
    });

    res.status(200).json({
      success: true,
      channel: "email",
      customToken: token.customToken,
      uid: token.uid,
    });
  } catch (error) {
    handleError(res, error);
  }
});

async function createAndSendOtp({channel, identifier, sender}) {
  const docRef = db.collection(OTP_COLLECTION).doc(docIdFor(channel, identifier));
  const snapshot = await docRef.get();
  const now = Date.now();
  const currentData = snapshot.exists ? snapshot.data() : {};
  const requestHistory = Array.isArray(currentData.requestHistory) ?
    currentData.requestHistory.filter((value) => typeof value === "number") :
    [];
  const recentRequests = requestHistory.filter((timestamp) => now - timestamp < RATE_LIMIT_WINDOW_MS);

  if (recentRequests.length >= MAX_REQUESTS_PER_WINDOW) {
    throw createHttpError(429, "Too many OTP requests. Try again in a minute.");
  }

  const otp = resolveOtpForChannel(channel, identifier);
  const expiresAt = admin.firestore.Timestamp.fromMillis(
      now + OTP_EXPIRY_SECONDS * 1000,
  );

  await docRef.set({
    id: identifier,
    channel,
    otp,
    expires: expiresAt,
    attempts: 0,
    requestHistory: [...recentRequests, now],
    createdAt: admin.firestore.FieldValue.serverTimestamp(),
    updatedAt: admin.firestore.FieldValue.serverTimestamp(),
  });

  let deliveryResult = {
    deliveryMode: "live",
  };

  try {
    const result = await sender(otp);
    if (result && typeof result === "object") {
      deliveryResult = {
        ...deliveryResult,
        ...result,
      };
    }
  } catch (error) {
    await docRef.delete();
    throw error;
  }

  return {
    deliveryMode: deliveryResult.deliveryMode || "live",
  };
}

async function verifyOtpAndCreateToken({channel, identifier, otp}) {
  const docRef = db.collection(OTP_COLLECTION).doc(docIdFor(channel, identifier));
  const snapshot = await docRef.get();

  if (!snapshot.exists) {
    throw createHttpError(404, "OTP not found. Request a new code.");
  }

  const data = snapshot.data();
  const expiresAt = data.expires && typeof data.expires.toMillis === "function" ?
    data.expires.toMillis() :
    0;

  if (Date.now() > expiresAt) {
    await docRef.delete();
    throw createHttpError(410, "OTP expired. Request a new code.");
  }

  if ((data.attempts || 0) >= MAX_ATTEMPTS) {
    await docRef.delete();
    throw createHttpError(429, "Too many attempts. Request a new OTP.");
  }

  if (data.otp !== otp) {
    const nextAttempts = (data.attempts || 0) + 1;
    await docRef.update({
      attempts: nextAttempts,
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    });

    if (nextAttempts >= MAX_ATTEMPTS) {
      throw createHttpError(429, "Too many attempts. Request a new OTP.");
    }

    throw createHttpError(401, "Invalid OTP. Please try again.");
  }

  const uid = await findOrCreateUser(channel, identifier);
  const customToken = await admin.auth().createCustomToken(uid, {
    loginChannel: channel,
  });

  await docRef.delete();
  return {uid, customToken};
}

async function findOrCreateUser(channel, identifier) {
  if (channel === "email") {
    try {
      const user = await admin.auth().getUserByEmail(identifier);
      return user.uid;
    } catch (error) {
      if (error.code !== "auth/user-not-found") {
        throw error;
      }
    }

    const createdUser = await admin.auth().createUser({
      email: identifier,
      emailVerified: false,
    });
    return createdUser.uid;
  }

  try {
    const user = await admin.auth().getUserByPhoneNumber(identifier);
    return user.uid;
  } catch (error) {
    if (error.code !== "auth/user-not-found") {
      throw error;
    }
  }

  const createdUser = await admin.auth().createUser({
    phoneNumber: identifier,
  });
  return createdUser.uid;
}

async function sendWhatsappOtp(phone, otp) {
  const token = process.env.WHATSAPP_ACCESS_TOKEN;
  const phoneNumberId = process.env.WHATSAPP_PHONE_NUMBER_ID;
  const templateName = process.env.WHATSAPP_TEMPLATE_NAME;
  const languageCode = process.env.WHATSAPP_TEMPLATE_LANGUAGE || "en";
  const allowDemoFallback = isWhatsappDemoModeEnabled();

  if (!token || !phoneNumberId || !templateName) {
    if (allowDemoFallback) {
      return {
        deliveryMode: "demo",
      };
    }

    throw createHttpError(
        500,
        "WhatsApp delivery is not configured. Add the WhatsApp Cloud API env vars in functions/.env or enable WHATSAPP_DEMO_MODE.",
    );
  }

  const response = await fetch(
      `https://graph.facebook.com/v22.0/${phoneNumberId}/messages`,
      {
        method: "POST",
        headers: {
          "Authorization": `Bearer ${token}`,
          "Content-Type": "application/json",
        },
        body: JSON.stringify({
          messaging_product: "whatsapp",
          to: phone,
          type: "template",
          template: {
            name: templateName,
            language: {code: languageCode},
            components: [
              {
                type: "body",
                parameters: [
                  {
                    type: "text",
                    text: otp,
                  },
                ],
              },
            ],
          },
        }),
      },
  );

  if (!response.ok) {
    const errorBody = await response.text();
    throw createHttpError(
        502,
        `Failed to deliver WhatsApp OTP: ${errorBody || response.statusText}`,
    );
  }

  return {
    deliveryMode: "live",
  };
}

async function sendEmailOtp(email, otp) {
  const host = process.env.SMTP_HOST;
  const port = Number(process.env.SMTP_PORT || "587");
  const secure = (process.env.SMTP_SECURE || "false") === "true";
  const user = process.env.SMTP_USER;
  const pass = process.env.SMTP_PASS;
  const from = process.env.SMTP_FROM || user;

  if (!host || !user || !pass || !from) {
    throw createHttpError(
        500,
        "SMTP delivery is not configured. Add the SMTP env vars in functions/.env.",
    );
  }

  const transporter = nodemailer.createTransport({
    host,
    port,
    secure,
    auth: {
      user,
      pass,
    },
  });

  await transporter.sendMail({
    from,
    to: email,
    subject: "Your Mitra verification code",
    text: `Your OTP is ${otp}. It expires in 5 minutes.`,
    html: `<p>Your OTP is <strong>${otp}</strong>.</p><p>It expires in 5 minutes.</p>`,
  });
}

function normalizePhone(value) {
  const input = String(value || "").trim();
  const digits = input.replace(/\D/g, "");

  if (digits.startsWith("91") && digits.length === 12) {
    return `+${digits}`;
  }

  if (digits.length === 10) {
    return `+91${digits}`;
  }

  if (input.startsWith("+") && digits.length >= 10) {
    return `+${digits}`;
  }

  throw createHttpError(400, "Provide a valid phone number.");
}

function normalizeEmail(value) {
  const email = String(value || "").trim().toLowerCase();
  const pattern = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;

  if (!pattern.test(email)) {
    throw createHttpError(400, "Provide a valid email address.");
  }

  return email;
}

function normalizeOtp(value) {
  const otp = String(value || "").replace(/\D/g, "");
  if (otp.length !== OTP_LENGTH) {
    throw createHttpError(400, "OTP must be 6 digits.");
  }
  return otp;
}

function resolveOtpForChannel(channel, identifier) {
  if (channel === "whatsapp" && shouldUseWhatsappDemoFor(identifier)) {
    return getWhatsappDemoOtp();
  }

  return generateOtp();
}

function shouldUseWhatsappDemoFor(identifier) {
  if (!isWhatsappDemoModeEnabled()) {
    return false;
  }

  const normalizedIdentifier = normalizePhone(identifier);
  const demoNumber = getWhatsappDemoNumber();
  if (normalizedIdentifier !== demoNumber) {
    throw createHttpError(
        400,
        `Demo WhatsApp login is enabled only for ${demoNumber}.`,
    );
  }

  return true;
}

function isWhatsappDemoModeEnabled() {
  const token = process.env.WHATSAPP_ACCESS_TOKEN;
  const phoneNumberId = process.env.WHATSAPP_PHONE_NUMBER_ID;
  const templateName = process.env.WHATSAPP_TEMPLATE_NAME;
  const envValue = process.env.WHATSAPP_DEMO_MODE;

  if (envValue != null && envValue.trim()) {
    return envValue === "true";
  }

  return !token || !phoneNumberId || !templateName;
}

function getWhatsappDemoNumber() {
  return normalizePhone(
      process.env.WHATSAPP_DEMO_NUMBER || DEFAULT_WHATSAPP_DEMO_NUMBER,
  );
}

function getWhatsappDemoOtp() {
  return normalizeOtp(process.env.WHATSAPP_DEMO_OTP || DEFAULT_WHATSAPP_DEMO_OTP);
}

function generateOtp() {
  return Math.floor(100000 + Math.random() * 900000).toString();
}

function docIdFor(channel, identifier) {
  return `${channel}_${crypto.createHash("sha256").update(identifier).digest("hex")}`;
}

function maskPhone(phone) {
  return `${phone.slice(0, 4)}******${phone.slice(-2)}`;
}

function maskEmail(email) {
  const [local, domain] = email.split("@");
  if (!local || !domain) return email;

  const visibleLocal = local.length <= 2 ? local[0] || "*" : `${local[0]}${"*".repeat(Math.max(local.length - 2, 1))}${local.slice(-1)}`;
  return `${visibleLocal}@${domain}`;
}

function createHttpError(status, message) {
  const error = new Error(message);
  error.status = status;
  return error;
}

function handleError(res, error) {
  const status = error.status || 500;
  const message = error.message || "Internal server error.";
  console.error("authApi error:", error);
  res.status(status).json({
    success: false,
    message,
  });
}

exports.authApi = onRequest({region: REGION}, app);
