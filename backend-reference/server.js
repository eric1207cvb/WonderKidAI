const express = require("express");
const cors = require("cors");
const axios = require("axios");
const crypto = require("crypto");
const fs = require("fs");
const path = require("path");
require("dotenv").config();

const app = express();
const PORT = Number(process.env.PORT || 8080);
const IS_PRODUCTION = process.env.NODE_ENV === "production";
const DEFAULT_SECRET = "change-me-in-production";
const OPENAI_API_KEY = process.env.OPENAI_API_KEY;
const SPEECH_TICKET_SECRET = process.env.SPEECH_TICKET_SECRET || DEFAULT_SECRET;
const ADMIN_SYNC_SECRET = process.env.ADMIN_SYNC_SECRET || DEFAULT_SECRET;

const DATA_DIR = path.join(__dirname, "data");
const STORE_PATH = path.join(DATA_DIR, "protection-store.json");
const SPEECH_CACHE_DIR = path.join(DATA_DIR, "speech-cache");

const CHAT_MODEL = "gpt-4o";
const CHAT_MAX_OUTPUT_TOKENS_STANDARD = 320;
const CHAT_MAX_OUTPUT_TOKENS_EXPANDED = 850;
const CHAT_MAX_OUTPUT_TOKENS_EXPANDED_ENGLISH = 560;
const MAX_MESSAGE_CHARS = 600;
const QUOTA_LANGUAGES = ["zh-TW", "en-US", "ja-JP"];
const FREE_DAILY_LIMIT_PER_LANGUAGE = 3;
const SPEECH_TICKET_TTL_MS = 30 * 24 * 60 * 60 * 1000;
const SPEECH_CACHE_MAX_BYTES = 200 * 1024 * 1024;
const SPEECH_CACHE_MAX_FILES = 500;
const SPEECH_CACHE_MAX_AGE_MS = 30 * 24 * 60 * 60 * 1000;
const PLAN_SYNC_MAX_CLOCK_SKEW_MS = 5 * 60 * 1000;
const MAX_INSTALLS_PER_APP_USER = Number(process.env.MAX_INSTALLS_PER_APP_USER || 8);

const PLAN_RULES = {
    free: {
        maxRequestsPerMinute: 12,
        perLanguageDailyLimit: FREE_DAILY_LIMIT_PER_LANGUAGE
    },
    pro: {
        maxRequestsPerMinute: 60,
        perLanguageDailyLimit: null
    }
};

const ZH_TW_DIGIT_TTS = {
    "0": "零",
    "1": "一",
    "2": "二",
    "3": "三",
    "4": "四",
    "5": "五",
    "6": "六",
    "7": "七",
    "8": "八",
    "9": "九",
    "０": "零",
    "１": "一",
    "２": "二",
    "３": "三",
    "４": "四",
    "５": "五",
    "６": "六",
    "７": "七",
    "８": "八",
    "９": "九"
};

const NATURAL_FEMALE_TTS_STYLE = "Use a natural, realistic adult female voice. Speak like a calm, friendly woman in a normal conversation, with relaxed pacing, subtle intonation, smooth vowel endings, and light natural pauses after punctuation. Keep the voice warm but not childlike, not theatrical, not a teacher character, and not an announcer. Prioritize lifelike, clean, non-metallic audio with soft consonants, stable volume, and no harsh high-frequency edges. Avoid robotic clipping, metallic compression, exaggerated cartoon acting, vocal fry, sibilance, overly bright sharp consonants, or emotional overacting.";

const TTS_BY_LANGUAGE = {
    "zh-TW": {
        model: "gpt-4o-mini-tts",
        voice: "nova",
        speed: 0.92,
        responseFormat: "wav",
        contentType: "audio/wav",
        cacheVersion: "natural-female-v1-zh-tw-nova-wav",
        instructions: `${NATURAL_FEMALE_TTS_STYLE} Use natural Taiwan Mandarin pronunciation and rhythm. Pronounce 一 as yi / ㄧ, never yao / 么. When Arabic digit sequences are present or already expanded into Chinese digit names, read every digit in the exact same order as written; never swap, drop, or reorder digits. For example, 747 is 七四七, not 四七四. Avoid Mainland Mandarin accent, erhua, and heavy retroflex sounds.`
    },
    "en-US": {
        model: "gpt-4o-mini-tts",
        voice: "nova",
        speed: 0.92,
        responseFormat: "wav",
        contentType: "audio/wav",
        cacheVersion: "natural-female-v1-en-us-nova-wav",
        instructions: `${NATURAL_FEMALE_TTS_STYLE} Use natural American English pronunciation and rhythm.`
    },
    "ja-JP": {
        model: "gpt-4o-mini-tts",
        voice: "nova",
        speed: 0.92,
        responseFormat: "wav",
        contentType: "audio/wav",
        cacheVersion: "natural-female-v1-ja-jp-nova-wav",
        instructions: `${NATURAL_FEMALE_TTS_STYLE} Use natural Japanese pronunciation and rhythm. Avoid anime-style acting or exaggerated cute character voice.`
    }
};

const INTRO_TTS_INPUT_BY_LANGUAGE = {
    "zh-TW": "嗨！我是安安老師，你的第一本 AI 百科全書。如果有自然、數學、地理、天文、語文、歷史，或是日常生活的問題，都可以問我喔！",
    "en-US": "Hello! I am Teacher An-An, your first AI encyclopedia. You can ask me about nature, math, geography, space, history, or anything in your daily life. I am here to help you!",
    "ja-JP": "やっほー！あんあん先生だよ。みんなの最初のAI百科事典なんだ。自然、算数、地理、宇宙、言葉、歴史、毎日のこと、なんでも聞いてね！"
};

const rateLimitBuckets = new Map();

fs.mkdirSync(DATA_DIR, { recursive: true });
fs.mkdirSync(SPEECH_CACHE_DIR, { recursive: true });

app.use(cors());
app.use(express.json({ limit: "256kb" }));

validateRuntimeConfiguration();

app.get("/", (req, res) => {
    res.json({ status: "ok", message: "WonderKid protected backend is online." });
});

app.get("/api/session", resolveUserContext, (req, res) => {
    res.json({
        plan: req.userRecord.plan,
        planExpiresAt: req.userRecord.planExpiresAt || null,
        quota: buildQuotaSummary(req.userRecord)
    });
});

app.post("/api/chat", resolveUserContext, enforceRateLimit, async (req, res) => {
    try {
        const body = req.body || {};
        const language = normalizeLanguage(body.language);
        const message = sanitizeMessage(body.message);

        if (!language) {
            return res.status(400).json({ error: "Unsupported language" });
        }
        if (!message) {
            return res.status(400).json({ error: "Message is required" });
        }

        if (!canConsumeQuota(req.userRecord, language)) {
            return res.status(402).json({
                error: "Free quota exhausted",
                plan: req.userRecord.plan,
                quota: buildQuotaSummary(req.userRecord)
            });
        }

        const answerDepth = req.userRecord.plan === "pro" ? "expanded" : "standard";

        const completion = await axios.post(
            "https://api.openai.com/v1/chat/completions",
            {
                model: CHAT_MODEL,
                temperature: 0.7,
                max_tokens: chatMaxOutputTokens(language, answerDepth),
                messages: [
                    {
                        role: "system",
                        content: buildSystemPrompt(language, answerDepth)
                    },
                    {
                        role: "user",
                        content: message
                    }
                ]
            },
            {
                headers: {
                    "Content-Type": "application/json",
                    Authorization: `Bearer ${OPENAI_API_KEY}`
                }
            }
        );

        const answer = completion.data?.choices?.[0]?.message?.content?.trim();
        if (!answer) {
            return res.status(502).json({ error: "OpenAI returned an empty answer" });
        }

        const ttsInput = normalizeTTSInput(answer, language);
        consumeQuota(req.userRecord, language);
        saveStore(req.store);

        const speechTicket = signSpeechTicket({
            userKey: req.userKey,
            language,
            textHash: speechTextHash(language, ttsInput),
            expiresAt: Date.now() + SPEECH_TICKET_TTL_MS
        });

        res.json({
            answer,
            ttsInput,
            speechTicket,
            plan: req.userRecord.plan,
            quota: quotaForLanguage(req.userRecord, language)
        });
    } catch (error) {
        const errorMsg = error.response ? error.response.data : error.message;
        console.error("Chat Error:", errorMsg);
        res.status(500).json({ error: "Chat failed" });
    }
});

app.post("/api/intro-speech", resolveUserContext, enforceRateLimit, async (req, res) => {
    try {
        const language = normalizeLanguage(req.body?.language);
        if (!language) {
            return res.status(400).json({ error: "Unsupported language" });
        }

        const ttsInput = normalizeTTSInput(INTRO_TTS_INPUT_BY_LANGUAGE[language], language);
        if (!ttsInput) {
            return res.status(500).json({ error: "Intro speech text is not configured" });
        }

        await sendSpeechAudio(res, language, ttsInput);
    } catch (error) {
        const errorMsg = error.response ? error.response.data : error.message;
        console.error("Intro Speech Error:", errorMsg);
        res.status(500).json({ error: "Intro speech failed" });
    }
});

app.post("/api/speech", resolveUserContext, enforceRateLimit, async (req, res) => {
    try {
        const body = req.body || {};
        const language = normalizeLanguage(body.language);
        const ttsInput = normalizeTTSInput(body.ttsInput, language);
        const speechTicket = typeof body.speechTicket === "string" ? body.speechTicket : "";

        if (!language || !ttsInput || !speechTicket) {
            return res.status(400).json({ error: "language, ttsInput and speechTicket are required" });
        }

        const verified = verifySpeechTicket(speechTicket);
        const expectedHash = speechTextHash(language, ttsInput);
        if (
            !verified ||
            verified.userKey !== req.userKey ||
            verified.language !== language ||
            verified.textHash !== expectedHash ||
            verified.expiresAt < Date.now()
        ) {
            return res.status(403).json({ error: "Invalid or expired speech ticket" });
        }

        await sendSpeechAudio(res, language, ttsInput);
    } catch (error) {
        const errorMsg = error.response ? error.response.data : error.message;
        console.error("Speech Error:", errorMsg);
        res.status(500).json({ error: "Speech failed" });
    }
});

app.post("/internal/plan-sync", (req, res) => {
    const auth = req.header("x-admin-secret");
    if (auth !== ADMIN_SYNC_SECRET) {
        return res.status(403).json({ error: "Forbidden" });
    }

    const body = req.body || {};
    const appUserId = sanitizeIdentifier(body.appUserId);
    const plan = body.plan === "pro" ? "pro" : "free";
    const planExpiresAt = parsePlanExpiresAt(body.expiresAt || body.planExpiresAt);

    if (!appUserId) {
        return res.status(400).json({ error: "appUserId is required" });
    }

    if (plan === "pro" && planExpiresAt && Date.parse(planExpiresAt) <= Date.now() - PLAN_SYNC_MAX_CLOCK_SKEW_MS) {
        return res.status(400).json({ error: "pro plan expiresAt is already expired" });
    }

    const userKey = `rc:${appUserId}`;
    const store = loadStore();
    store.users[userKey] = store.users[userKey] || createUserRecord();
    store.users[userKey].plan = plan;
    store.users[userKey].planExpiresAt = plan === "pro" ? planExpiresAt : null;
    store.users[userKey].updatedAt = new Date().toISOString();
    saveStore(store);

    res.json({ ok: true, userKey, plan, planExpiresAt: store.users[userKey].planExpiresAt });
});

app.listen(PORT, "0.0.0.0", () => {
    console.log("==================================================");
    console.log(`🚀 Protected backend running on port ${PORT}`);
    console.log(`✅ Chat model locked to ${CHAT_MODEL}`);
    console.log("✅ TTS model / voice / speed locked on server");
    console.log("✅ Free quota: 3 per language per day");
    console.log("==================================================");
});

function validateRuntimeConfiguration() {
    const problems = [];

    if (!OPENAI_API_KEY) {
        problems.push("OPENAI_API_KEY is required");
    }
    if (SPEECH_TICKET_SECRET === DEFAULT_SECRET) {
        problems.push("SPEECH_TICKET_SECRET must be set to a private random value");
    }
    if (ADMIN_SYNC_SECRET === DEFAULT_SECRET) {
        problems.push("ADMIN_SYNC_SECRET must be set to a private random value");
    }
    if (!Number.isFinite(MAX_INSTALLS_PER_APP_USER) || MAX_INSTALLS_PER_APP_USER < 1) {
        problems.push("MAX_INSTALLS_PER_APP_USER must be a positive number");
    }

    if (problems.length === 0) {
        return;
    }

    const prefix = IS_PRODUCTION ? "❌ Production config error:" : "⚠️ Development config warning:";
    for (const problem of problems) {
        console.error(`${prefix} ${problem}`);
    }

    if (IS_PRODUCTION) {
        process.exit(1);
    }
}

function resolveUserContext(req, res, next) {
    const body = req.body || {};
    const installId = sanitizeIdentifier(req.header("x-install-id") || body.installId);
    const appUserId = sanitizeIdentifier(req.header("x-app-user-id") || body.appUserId);

    if (!installId) {
        return res.status(400).json({ error: "x-install-id is required" });
    }

    const userKey = appUserId ? `rc:${appUserId}` : `install:${installId}`;
    const store = loadStore();
    store.users[userKey] = store.users[userKey] || createUserRecord();

    if (appUserId && !bindInstallToAppUser(store.users[userKey], installId)) {
        return res.status(403).json({ error: "Too many devices linked to this account" });
    }

    store.users[userKey].updatedAt = new Date().toISOString();
    ensureQuotaWindow(store.users[userKey]);
    enforcePlanExpiry(store.users[userKey]);
    saveStore(store);

    req.userKey = userKey;
    req.store = store;
    req.userRecord = store.users[userKey];
    next();
}

function enforceRateLimit(req, res, next) {
    const plan = req.userRecord.plan === "pro" ? "pro" : "free";
    const maxRequests = PLAN_RULES[plan].maxRequestsPerMinute;
    const now = Date.now();
    const windowStart = now - 60_000;
    const bucket = rateLimitBuckets.get(req.userKey) || [];
    const recent = bucket.filter((timestamp) => timestamp >= windowStart);

    if (recent.length >= maxRequests) {
        return res.status(429).json({ error: "Too many requests, please slow down." });
    }

    recent.push(now);
    rateLimitBuckets.set(req.userKey, recent);
    next();
}

function buildSystemPrompt(language, answerDepth = "standard") {
    const lengthInstruction = answerLengthInstruction(language, answerDepth);

    switch (language) {
        case "zh-TW":
            return `你是安安老師，對象是 4 到 10 歲小朋友。請用溫柔、簡單、適合語音朗讀的自然段落回答，不要用 Markdown。${lengthInstruction}`;
        case "ja-JP":
            return `あなたはあんあん先生です。4〜10歳の子ども向けに、やさしく、音声で聞きやすい自然な文で答えてください。Markdown は使わないでください。漢字を使う時は、表示用に必ず 漢字(ひらがな) の形でふりがなを付けてください。例：火山(かざん)、自然(しぜん)、理由(りゆう)。${lengthInstruction}`;
        case "en-US":
        default:
            return `You are Teacher An-An for children aged 4 to 10. Answer gently in simple natural paragraphs suitable for TTS. Do not use Markdown. ${lengthInstruction}`;
    }
}

function answerLengthInstruction(language, answerDepth) {
    if (answerDepth === "expanded") {
        switch (language) {
            case "zh-TW":
                return "付費深度模式：請先直接回答孩子問的核心問題，再補充必要原因、例子或常見誤解。內容要更好懂，但不要為了變長而加入無關聯想、延伸故事、冷知識或空泛總結。簡單問題用 2 到 3 個短段落即可；複雜問題最多 4 到 5 個短段落。保持口語、溫柔、適合一次語音播放。";
            case "ja-JP":
                return "プレミアム深ぼりモード：最初に質問の核心へまっすぐ答えて、そのあと必要な理由、例、まちがえやすい点だけを足してください。長くするための関係ない連想、豆知識、物語、ふわっとしたまとめは入れないでください。簡単な質問は 2〜3 段落、複雑な質問でも 4〜5 段落までにしてください。漢字を使う時は、子どもが読めるように必ず 漢字(ひらがな) の形でふりがなを付けてください。";
            case "en-US":
            default:
                return "Premium deep mode: answer the child's exact question first, then add only the necessary reason, example, or common misunderstanding. Make it easier to understand, but do not pad with unrelated associations, side stories, trivia, or generic recaps. Use 2 to 3 short paragraphs for simple questions and at most 4 to 5 for complex ones. Keep it natural for one audio playback.";
        }
    }

    switch (language) {
        case "zh-TW":
            return "回答請控制在 180 個中文字以內，最多 2 個短段落。";
        case "ja-JP":
            return "答えは 180 字くらい、短い段落は 2 つまでにしてください。漢字を使う時は、子どもが読めるように必ず 漢字(ひらがな) の形でふりがなを付けてください。";
        case "en-US":
        default:
            return "Keep the answer under 80 words, with at most 2 short paragraphs.";
    }
}

function chatMaxOutputTokens(language, answerDepth) {
    if (answerDepth !== "expanded") {
        return language === "en-US" ? 180 : CHAT_MAX_OUTPUT_TOKENS_STANDARD;
    }

    return language === "en-US" ? CHAT_MAX_OUTPUT_TOKENS_EXPANDED_ENGLISH : CHAT_MAX_OUTPUT_TOKENS_EXPANDED;
}

function sanitizeIdentifier(value) {
    if (typeof value !== "string") {
        return "";
    }
    const trimmed = value.trim();
    if (!trimmed) {
        return "";
    }
    return trimmed.replace(/[^a-zA-Z0-9:_-]/g, "").slice(0, 120);
}

function sanitizeMessage(value) {
    if (typeof value !== "string") {
        return "";
    }
    return value.trim().slice(0, MAX_MESSAGE_CHARS);
}

function parsePlanExpiresAt(value) {
    if (!value) {
        return null;
    }

    const date = new Date(value);
    if (Number.isNaN(date.getTime())) {
        return null;
    }

    return date.toISOString();
}

function normalizeLanguage(value) {
    return QUOTA_LANGUAGES.includes(value) ? value : null;
}

function normalizeTTSInput(value, language) {
    if (typeof value !== "string") {
        return "";
    }
    let normalized = value
        .replace(/\*\*/g, "")
        .replace(/#/g, "")
        .replace(/`/g, "")
        .replace(/…/g, "。 ")
        .replace(/\.\.\./g, ". ")
        .replace(/——/g, " ")
        .replace(/—/g, " ")
        .replace(/[•●◆★]/g, " ")
        .replace(/!!+/g, "!")
        .replace(/\?\?+/g, "?")
        .replace(/！！+/g, "！")
        .replace(/？？+/g, "？")
        .replace(/。。+/g, "。")
        .replace(/，，+/g, "，")
        .replace(/\s+/g, " ")
        .trim()
        .slice(0, 4000);

    if (language === "zh-TW") {
        normalized = normalized.replace(/[0-9０-９]+/g, (digits) =>
            Array.from(digits).map((digit) => ZH_TW_DIGIT_TTS[digit] || digit).join("")
        );
    }

    if (language === "ja-JP") {
        normalized = normalized
            .replace(/<ruby>(.*?)<rt>.*?<\/rt><\/ruby>/gis, "$1")
            .replace(/<\/?ruby>|<\/?rt>/gi, "")
            .replace(/[\(（][ぁ-んァ-ヴー]+[\)）]/g, "")
            .replace(/[〜～]/g, "")
            .replace(/([。、？！])/g, "$1 ")
            .replace(/\s+/g, " ")
            .trim();
    }

    return normalized;
}

async function sendSpeechAudio(res, language, ttsInput) {
    const ttsConfig = TTS_BY_LANGUAGE[language];
    const cacheKey = speechTextHash(language, ttsInput);
    const cached = readSpeechCache(cacheKey, ttsConfig);
    if (cached) {
        res.setHeader("Content-Type", ttsConfig.contentType);
        res.setHeader("X-Speech-Cache", "hit");
        return res.send(cached);
    }

    const audioBuffer = await synthesizeSpeech(ttsInput, ttsConfig);
    writeSpeechCache(cacheKey, audioBuffer, ttsConfig);
    pruneSpeechCache();

    res.setHeader("Content-Type", ttsConfig.contentType);
    res.setHeader("X-Speech-Cache", "miss");
    return res.send(audioBuffer);
}

async function synthesizeSpeech(ttsInput, ttsConfig) {
    const response = await axios.post(
        "https://api.openai.com/v1/audio/speech",
        {
            model: ttsConfig.model,
            input: ttsInput,
            voice: ttsConfig.voice,
            speed: ttsConfig.speed,
            response_format: ttsConfig.responseFormat,
            instructions: ttsConfig.instructions
        },
        {
            headers: {
                "Content-Type": "application/json",
                Authorization: `Bearer ${OPENAI_API_KEY}`
            },
            responseType: "arraybuffer"
        }
    );

    return Buffer.from(response.data);
}

function speechTextHash(language, ttsInput) {
    const ttsConfig = TTS_BY_LANGUAGE[language];
    const voiceVersion = ttsConfig?.cacheVersion || "default";
    return sha256(`${language}|${voiceVersion}|${ttsInput}`);
}

function createUserRecord() {
    return {
        plan: "free",
        planExpiresAt: null,
        installIds: [],
        quotaDateKey: currentDateKey(),
        usageByLanguage: {
            "zh-TW": 0,
            "en-US": 0,
            "ja-JP": 0
        },
        updatedAt: new Date().toISOString()
    };
}

function bindInstallToAppUser(userRecord, installId) {
    userRecord.installIds = Array.isArray(userRecord.installIds) ? userRecord.installIds : [];

    if (userRecord.installIds.includes(installId)) {
        return true;
    }

    if (userRecord.installIds.length >= maxInstallsPerAppUser()) {
        return false;
    }

    userRecord.installIds.push(installId);
    return true;
}

function maxInstallsPerAppUser() {
    if (!Number.isFinite(MAX_INSTALLS_PER_APP_USER) || MAX_INSTALLS_PER_APP_USER < 1) {
        return 8;
    }

    return Math.floor(MAX_INSTALLS_PER_APP_USER);
}

function enforcePlanExpiry(userRecord) {
    if (userRecord.plan !== "pro" || !userRecord.planExpiresAt) {
        return;
    }

    const expiresAt = Date.parse(userRecord.planExpiresAt);
    if (Number.isNaN(expiresAt) || expiresAt > Date.now()) {
        return;
    }

    userRecord.plan = "free";
    userRecord.planExpiresAt = null;
    userRecord.updatedAt = new Date().toISOString();
}

function ensureQuotaWindow(userRecord) {
    const today = currentDateKey();
    if (userRecord.quotaDateKey === today) {
        return;
    }

    userRecord.quotaDateKey = today;
    userRecord.usageByLanguage = {
        "zh-TW": 0,
        "en-US": 0,
        "ja-JP": 0
    };
}

function canConsumeQuota(userRecord, language) {
    if (userRecord.plan === "pro") {
        return true;
    }

    ensureQuotaWindow(userRecord);
    const used = userRecord.usageByLanguage[language] || 0;
    return used < FREE_DAILY_LIMIT_PER_LANGUAGE;
}

function consumeQuota(userRecord, language) {
    if (userRecord.plan === "pro") {
        return;
    }

    ensureQuotaWindow(userRecord);
    userRecord.usageByLanguage[language] = Math.min(
        FREE_DAILY_LIMIT_PER_LANGUAGE,
        (userRecord.usageByLanguage[language] || 0) + 1
    );
}

function buildQuotaSummary(userRecord) {
    const summary = {};
    for (const language of QUOTA_LANGUAGES) {
        summary[language] = quotaForLanguage(userRecord, language);
    }
    return summary;
}

function quotaForLanguage(userRecord, language) {
    if (userRecord.plan === "pro") {
        return { remaining: null, limit: null };
    }

    ensureQuotaWindow(userRecord);
    const used = userRecord.usageByLanguage[language] || 0;
    return {
        remaining: Math.max(FREE_DAILY_LIMIT_PER_LANGUAGE - used, 0),
        limit: FREE_DAILY_LIMIT_PER_LANGUAGE
    };
}

function currentDateKey() {
    return new Date().toISOString().slice(0, 10);
}

function loadStore() {
    if (!fs.existsSync(STORE_PATH)) {
        return { users: {} };
    }

    try {
        return JSON.parse(fs.readFileSync(STORE_PATH, "utf8"));
    } catch (error) {
        console.error("Failed to read store, recreating:", error.message);
        return { users: {} };
    }
}

function saveStore(store) {
    fs.writeFileSync(STORE_PATH, JSON.stringify(store, null, 2));
}

function sha256(input) {
    return crypto.createHash("sha256").update(input).digest("hex");
}

function signSpeechTicket(payload) {
    const encodedPayload = base64UrlEncode(JSON.stringify(payload));
    const signature = crypto
        .createHmac("sha256", SPEECH_TICKET_SECRET)
        .update(encodedPayload)
        .digest("hex");
    return `${encodedPayload}.${signature}`;
}

function verifySpeechTicket(ticket) {
    const [encodedPayload, signature] = String(ticket).split(".");
    if (!encodedPayload || !signature) {
        return null;
    }

    const expected = crypto
        .createHmac("sha256", SPEECH_TICKET_SECRET)
        .update(encodedPayload)
        .digest("hex");

    if (!safeEqual(signature, expected)) {
        return null;
    }

    try {
        return JSON.parse(base64UrlDecode(encodedPayload));
    } catch (error) {
        return null;
    }
}

function safeEqual(left, right) {
    const a = Buffer.from(String(left));
    const b = Buffer.from(String(right));
    if (a.length !== b.length) {
        return false;
    }
    return crypto.timingSafeEqual(a, b);
}

function base64UrlEncode(input) {
    return Buffer.from(input)
        .toString("base64")
        .replace(/\+/g, "-")
        .replace(/\//g, "_")
        .replace(/=+$/g, "");
}

function base64UrlDecode(input) {
    const normalized = input.replace(/-/g, "+").replace(/_/g, "/");
    const padding = normalized.length % 4 === 0 ? "" : "=".repeat(4 - (normalized.length % 4));
    return Buffer.from(normalized + padding, "base64").toString("utf8");
}

function speechCachePath(cacheKey, ttsConfig) {
    const extension = ttsConfig?.responseFormat || "mp3";
    return path.join(SPEECH_CACHE_DIR, `${cacheKey}.${extension}`);
}

function readSpeechCache(cacheKey, ttsConfig) {
    const filePath = speechCachePath(cacheKey, ttsConfig);
    if (!fs.existsSync(filePath)) {
        return null;
    }

    try {
        const now = new Date();
        fs.utimesSync(filePath, now, now);
        return fs.readFileSync(filePath);
    } catch (error) {
        return null;
    }
}

function writeSpeechCache(cacheKey, audioBuffer, ttsConfig) {
    fs.writeFileSync(speechCachePath(cacheKey, ttsConfig), audioBuffer);
}

function pruneSpeechCache() {
    const audioCacheExtensions = new Set([".mp3", ".wav", ".aac", ".opus", ".flac"]);
    const files = fs
        .readdirSync(SPEECH_CACHE_DIR)
        .filter((filename) => audioCacheExtensions.has(path.extname(filename)))
        .map((filename) => {
            const filePath = path.join(SPEECH_CACHE_DIR, filename);
            const stats = fs.statSync(filePath);
            return {
                filePath,
                size: stats.size,
                lastUsedAt: stats.mtimeMs
            };
        })
        .sort((a, b) => a.lastUsedAt - b.lastUsedAt);

    const now = Date.now();
    let totalSize = files.reduce((sum, file) => sum + file.size, 0);
    let totalFiles = files.length;

    for (const file of files) {
        const expired = now - file.lastUsedAt > SPEECH_CACHE_MAX_AGE_MS;
        const tooLarge = totalSize > SPEECH_CACHE_MAX_BYTES;
        const tooMany = totalFiles > SPEECH_CACHE_MAX_FILES;
        if (!expired && !tooLarge && !tooMany) {
            continue;
        }

        try {
            fs.unlinkSync(file.filePath);
            totalSize -= file.size;
            totalFiles -= 1;
        } catch (error) {
            console.error("Failed to prune speech cache:", error.message);
        }
    }
}
