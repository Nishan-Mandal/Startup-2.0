const {onCall, HttpsError} = require("firebase-functions/v2/https");
const {setGlobalOptions} = require("firebase-functions");
const {defineSecret} = require("firebase-functions/params");
const {GoogleGenAI} = require("@google/genai");
const {getStorage} = require("firebase-admin/storage");

const {initializeApp} = require("firebase-admin/app");

initializeApp();

const bucket = getStorage().bucket();

setGlobalOptions({
  maxInstances: 10,
  region: "us-central1",
});

const geminiApiKey = defineSecret("GEMINI_API_KEY");

const sleep = (ms) => new Promise((resolve) => setTimeout(resolve, ms));

const isRetryableGeminiError = (error) => {
  const status = error && error.status;
  const message = error && error.message ?
    String(error.message) :
    "";

  // gemini ka service unavailable hai temporarily error code -> 504.
  if (status === 503) {
    return true;
  }

  // rate limiting ka error ho skta hai ya daily qouta khtm error code -> 429
  if (status === 429) {
    const isDailyQuotaExceeded =
      message.includes("PerDayPerProject") ||
      message.includes("generate_content_free_tier_requests");

    return !isDailyQuotaExceeded;
  }

  return false;
};

exports.generateListingTags = onCall(
    {
      memory: "256MiB",
      invoker: "public",
      secrets: [geminiApiKey],
    },
    async (request) => {
      if (!request.auth) {
        throw new HttpsError(
            "unauthenticated",
            "Authentication is required.",
        );
      }

      const listingData = request.data && request.data.listingData;

      if (!listingData || typeof listingData !== "object") {
        throw new HttpsError(
            "invalid-argument",
            "Listing data is required.",
        );
      }

      console.log("Received listing data:", listingData);

      const [promptBuffer] = await bucket
          .file("ai_prompts/listing_tags/prompt.txt")
          .download();

      const promptTemplate = promptBuffer.toString("utf8");

      console.log("Prompt loaded from Storage successfully.");

      const ai = new GoogleGenAI({
        apiKey: geminiApiKey.value(),
      });

      const prompt = `
${promptTemplate}

LISTING DATA:
${JSON.stringify(listingData)}
`;
      let response;

      const maxRetries = 3;

      for (let attempt = 0; attempt <= maxRetries; attempt++) {
        try {
          console.log(
              `Gemini request attempt ${attempt + 1}/${maxRetries + 1}`,
          );

          response = await ai.models.generateContent({
            model: "gemini-3.6-flash",
            contents: prompt,
            config: {
              responseMimeType: "application/json",
              responseSchema: {
                type: "object",
                properties: {
                  tags: {
                    type: "array",
                    items: {
                      type: "string",
                    },
                  },
                },
                required: ["tags"],
              },
            },
          });

          break;
        } catch (error) {
          console.error(
              `Gemini request failed on attempt ${attempt + 1}:`,
              error,
          );

          if (!isRetryableGeminiError(error) || attempt === maxRetries) {
            throw new HttpsError(
                "internal",
                "Unable to generate tags right now.",
            );
          }

          const delay = 1000 * Math.pow(2, attempt);

          console.log(
              `Retrying Gemini request in ${delay}ms...`,
          );

          await sleep(delay);
        }
      }

      console.log("Gemini response:", response.text);

      let result;

      try {
        result = JSON.parse(response.text);
      } catch (error) {
        console.error("Failed to parse Gemini response:", error);

        throw new HttpsError(
            "internal",
            "Invalid response received from AI.",
        );
      }

      if (!result.tags || !Array.isArray(result.tags)) {
        throw new HttpsError(
            "internal",
            "AI response did not contain valid tags.",
        );
      }

      const tags = result.tags
          .filter((tag) => typeof tag === "string")
          .map((tag) => tag.trim())
          .filter((tag) => tag.length > 0)
          .slice(0, 10);

      return {
        tags: tags,
      };
    },
);
