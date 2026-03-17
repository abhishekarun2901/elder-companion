const crypto = require("crypto");
const admin = require("firebase-admin");
const twilio = require("twilio");

if (!admin.apps.length) {
  admin.initializeApp();
}

const SMS_LOGS_COLLECTION = "sms_logs";
const PHONE_PATTERN = /^\+[1-9]\d{9,14}$/;

function getDb() {
  return admin.firestore();
}

function getTwilioClient() {
  const sid = getRequiredEnv("TWILIO_ACCOUNT_SID");
  const token = getRequiredEnv("TWILIO_AUTH_TOKEN");
  return twilio(sid, token);
}

function getRequiredEnv(key) {
  const value = process.env[key];
  if (!value || !value.trim()) {
    throw new Error(`Missing required env value: ${key}`);
  }
  return value.trim();
}

function normalizePhone(value) {
  const input = String(value || "").trim();
  const digits = input.replace(/\D/g, "");

  if (!digits) {
    return null;
  }

  if (input.startsWith("+") && PHONE_PATTERN.test(`+${digits}`)) {
    return `+${digits}`;
  }

  if (digits.length === 10) {
    return `+91${digits}`;
  }

  if (digits.length >= 11 && digits.length <= 15) {
    return `+${digits}`;
  }

  return null;
}

function collectAlertRecipients(elderData = {}) {
  const candidates = [
    elderData.caregiverPhone,
    elderData.caregiverNumber,
    elderData.emergencyContact && elderData.emergencyContact.phone,
  ];

  return [...new Set(
      candidates
          .map((value) => normalizePhone(value))
          .filter(Boolean),
  )];
}

async function sendAlertSms({
  elderId,
  elderName,
  alertType,
  messageBody,
  recipients,
  metadata = {},
}) {
  if (!Array.isArray(recipients) || recipients.length === 0) {
    return [];
  }

  const client = getTwilioClient();
  const from = getRequiredEnv("TWILIO_PHONE_NUMBER");
  const results = [];

  for (const recipient of recipients) {
    try {
      const response = await client.messages.create({
        body: messageBody,
        from,
        to: recipient,
      });

      await writeSmsLog({
        elderId,
        elderName,
        recipientNumber: recipient,
        status: "sent",
        messageBody,
        alertType,
        providerMessageId: response.sid,
        providerStatus: response.status || "queued",
        metadata,
      });

      results.push({
        to: recipient,
        status: "sent",
        sid: response.sid,
      });
    } catch (error) {
      await writeSmsLog({
        elderId,
        elderName,
        recipientNumber: recipient,
        status: "failed",
        messageBody,
        alertType,
        errorMessage: formatTwilioError(error),
        metadata,
      });

      results.push({
        to: recipient,
        status: "failed",
        error: formatTwilioError(error),
      });
    }
  }

  return results;
}

async function writeSmsLog({
  elderId,
  elderName,
  recipientNumber,
  status,
  messageBody,
  alertType,
  providerMessageId,
  providerStatus,
  errorMessage,
  metadata,
}) {
  await getDb().collection(SMS_LOGS_COLLECTION).add({
    elderId: elderId || null,
    name: elderName || null,
    caregiverNumber: recipientNumber,
    recipientNumber,
    status,
    messageBody,
    alertType: alertType || null,
    provider: "twilio",
    providerMessageId: providerMessageId || null,
    providerStatus: providerStatus || null,
    errorMessage: errorMessage || null,
    metadata: metadata || {},
    lastSentAt: admin.firestore.FieldValue.serverTimestamp(),
    updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    dedupeKey: crypto
        .createHash("sha256")
        .update(`${elderId || ""}:${recipientNumber}:${alertType || ""}:${messageBody}`)
        .digest("hex"),
  });
}

function formatTwilioError(error) {
  if (!error) {
    return "Unknown Twilio error.";
  }

  const code = error.code ? `Code ${error.code}: ` : "";
  return `${code}${error.message || String(error)}`;
}

module.exports = {
  normalizePhone,
  collectAlertRecipients,
  sendAlertSms,
};
