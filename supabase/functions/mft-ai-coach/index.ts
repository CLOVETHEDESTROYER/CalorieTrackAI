type AIAction = "health" | "mealAnalysis" | "dailyMealPlan" | "foodRecognition" | "foodImageAnalysis";

type AIRequest = {
  action?: AIAction;
  description?: string;
  imageBase64?: string;
  userProfile?: {
    daily_calorie_goal?: number;
    goal_type?: string;
    activity_level?: string;
    age?: number;
    weight?: number;
    height?: number;
  };
  preferences?: {
    dietaryRestrictions?: string[];
    cuisinePreferences?: string[];
    complexity?: string;
    budgetLevel?: string;
  };
};

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

const model = Deno.env.get("OPENAI_MODEL") ?? "gpt-4o-2024-08-06";
// Keep the canonical name first, while accepting the existing dashboard secret
// until it can be renamed there. The key never reaches the iOS app.
const openAIAPIKey = () => Deno.env.get("OPENAI_API_KEY") ?? Deno.env.get("Openai_API_Key");

Deno.serve(async (req: Request) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  if (req.method !== "POST") {
    return json({ error: "Use POST for AI coach requests." }, 405);
  }

  try {
    const body = await req.json() as AIRequest;

    switch (body.action) {
      case "health":
        return json({
          data: {
            ok: Boolean(openAIAPIKey()),
          },
        });
      case "mealAnalysis":
        return json({
          data: await analyzeMealDescription(body.description),
        });
      case "dailyMealPlan":
        return json({
          data: await suggestDailyMeals(body.userProfile, body.preferences),
        });
      case "foodRecognition":
        return json({
          data: await recognizeFoodFromDescription(body.description),
        });
      case "foodImageAnalysis":
        return json({
          data: await analyzeFoodImage(body.imageBase64),
        });
      default:
        return json({ error: "Unknown AI action." }, 400);
    }
  } catch (error) {
    const message = error instanceof Error ? error.message : "Unknown AI proxy error.";
    return json({ error: message }, 500);
  }
});

async function analyzeMealDescription(description?: string) {
  const trimmedDescription = description?.trim();
  if (!trimmedDescription) {
    throw new Error("Meal description is required.");
  }

  const content = await chatCompletion([
    { role: "system", content: mealAnalysisSystemPrompt },
    { role: "user", content: createMealAnalysisPrompt(trimmedDescription) },
  ]);

  return normalizeMealAnalysis(parseJSON(content));
}

async function recognizeFoodFromDescription(description?: string) {
  const trimmedDescription = description?.trim();
  if (!trimmedDescription) {
    throw new Error("Food description is required.");
  }

  const content = await chatCompletion([
    { role: "system", content: foodRecognitionSystemPrompt },
    { role: "user", content: createFoodRecognitionPrompt(trimmedDescription) },
  ]);

  const parsed = parseJSON(content);
  const items = Array.isArray(parsed) ? parsed : parsed.foods ?? parsed.items ?? [];
  return Array.isArray(items) ? items.map(normalizeFoodRecognition) : [];
}

async function analyzeFoodImage(imageBase64?: string) {
  const trimmedImage = imageBase64?.trim();
  if (!trimmedImage) {
    throw new Error("Image data is required.");
  }

  const content = await visionCompletion([
    { role: "system", content: mealAnalysisSystemPrompt },
    {
      role: "user",
      content: [
        { type: "text", text: foodImageAnalysisPrompt },
        { type: "image_url", image_url: { url: `data:image/jpeg;base64,${trimmedImage}` } },
      ],
    },
  ]);

  return normalizeMealAnalysis(parseJSON(content));
}

async function suggestDailyMeals(userProfile?: AIRequest["userProfile"], preferences?: AIRequest["preferences"]) {
  if (!userProfile) {
    throw new Error("User profile is required.");
  }

  const content = await chatCompletion([
    { role: "system", content: mealSuggestionSystemPrompt },
    { role: "user", content: createMealSuggestionPrompt(userProfile, preferences) },
  ]);

  return normalizeDailyMealPlan(parseJSON(content));
}

async function chatCompletion(messages: Array<{ role: "system" | "user"; content: string }>) {
  return openAIChatCompletion(messages);
}

async function visionCompletion(messages: unknown[]) {
  return openAIChatCompletion(messages);
}

async function openAIChatCompletion(messages: unknown[]) {
  const apiKey = openAIAPIKey();
  if (!apiKey) {
    throw new Error("OPENAI_API_KEY is not set in Supabase Edge Function secrets.");
  }

  const response = await fetch("https://api.openai.com/v1/chat/completions", {
    method: "POST",
    headers: {
      "Authorization": `Bearer ${apiKey}`,
      "Content-Type": "application/json",
    },
    body: JSON.stringify({
      model,
      messages,
      temperature: 0.3,
      max_tokens: 1500,
      response_format: { type: "json_object" },
    }),
  });

  const responseBody = await response.text();
  if (!response.ok) {
    throw new Error(`OpenAI returned ${response.status}: ${responseBody}`);
  }

  const decoded = JSON.parse(responseBody);
  const content = decoded?.choices?.[0]?.message?.content;
  if (typeof content !== "string" || content.trim().length === 0) {
    throw new Error("OpenAI returned an empty response.");
  }

  return content;
}

function createFoodRecognitionPrompt(description: string) {
  return `
Analyze this food description and identify individual food items with their estimated quantities:
"${description}"

Return valid JSON only using this exact shape:
{
  "foods": [
    {
      "name": "string",
      "estimatedQuantity": "string",
      "confidence": 0
    }
  ]
}

Use confidence values from 0 to 100.
`;
}

function createMealAnalysisPrompt(description: string) {
  return `
Analyze this meal description and provide detailed nutritional information:
"${description}"

Return valid JSON only using this exact shape:
{
  "totalCalories": 0,
  "protein": 0,
  "carbohydrates": 0,
  "fat": 0,
  "fiber": 0,
  "confidence": 0,
  "foodItems": [
    {
      "name": "string",
      "quantity": "string",
      "calories": 0,
      "protein": 0,
      "carbohydrates": 0,
      "fat": 0
    }
  ],
  "assumptions": ["string"]
}

Use grams for macros and fiber. Use a confidence value from 0 to 100.
`;
}

function createMealSuggestionPrompt(
  userProfile: NonNullable<AIRequest["userProfile"]>,
  preferences: AIRequest["preferences"] = {},
) {
  const calories = userProfile.daily_calorie_goal ?? 2000;
  const protein = Math.round((calories * 0.25) / 4);
  const carbs = Math.round((calories * 0.45) / 4);
  const fat = Math.round((calories * 0.30) / 9);

  return `
Create a daily meal plan for a user with these specifications:

User Profile:
- Daily calorie goal: ${Math.round(calories)} calories
- Goal: ${userProfile.goal_type ?? "lose weight"}
- Activity level: ${userProfile.activity_level ?? "moderate"}
- Age: ${userProfile.age ?? "unknown"}, Weight: ${userProfile.weight ?? "unknown"}kg, Height: ${userProfile.height ?? "unknown"}cm

Nutritional Targets:
- Calories: ${Math.round(calories)}
- Protein: ${protein}g
- Carbohydrates: ${carbs}g
- Fat: ${fat}g

Preferences:
- Dietary restrictions: ${(preferences.dietaryRestrictions ?? []).join(", ") || "None"}
- Cuisine preferences: ${(preferences.cuisinePreferences ?? ["Any"]).join(", ")}
- Meal complexity: ${preferences.complexity ?? "Medium (30 min)"}
- Budget level: ${preferences.budgetLevel ?? "Moderate"}

Return valid JSON only using this exact shape:
{
  "breakfast": {
    "name": "string",
    "description": "string",
    "calories": 0,
    "protein": 0,
    "carbohydrates": 0,
    "fat": 0,
    "ingredients": ["string"],
    "instructions": "string"
  },
  "lunch": {
    "name": "string",
    "description": "string",
    "calories": 0,
    "protein": 0,
    "carbohydrates": 0,
    "fat": 0,
    "ingredients": ["string"],
    "instructions": "string"
  },
  "dinner": {
    "name": "string",
    "description": "string",
    "calories": 0,
    "protein": 0,
    "carbohydrates": 0,
    "fat": 0,
    "ingredients": ["string"],
    "instructions": "string"
  },
  "snacks": [
    {
      "name": "string",
      "description": "string",
      "calories": 0,
      "protein": 0,
      "carbohydrates": 0,
      "fat": 0,
      "ingredients": ["string"],
      "instructions": "string"
    }
  ],
  "totalCalories": 0,
  "totalProtein": 0,
  "totalCarbs": 0,
  "totalFat": 0
}

Include exactly two snacks. Keep the daily totals aligned with the target calories and macros.
`;
}

function parseJSON(content: string) {
  const trimmed = content.trim();
  if (trimmed.startsWith("{") && trimmed.endsWith("}")) {
    return JSON.parse(trimmed);
  }

  const fenced = trimmed.match(/```(?:json)?\s*([\s\S]*?)\s*```/i)?.[1];
  if (fenced) {
    return JSON.parse(fenced.trim());
  }

  const start = trimmed.indexOf("{");
  const end = trimmed.lastIndexOf("}");
  if (start >= 0 && end >= start) {
    return JSON.parse(trimmed.slice(start, end + 1));
  }

  throw new Error("AI response did not contain JSON.");
}

function normalizeMealAnalysis(value: Record<string, unknown>) {
  return {
    totalCalories: positiveNumber(value.totalCalories),
    protein: positiveNumber(value.protein),
    carbohydrates: positiveNumber(value.carbohydrates),
    fat: positiveNumber(value.fat),
    fiber: positiveNumber(value.fiber),
    confidence: clampInt(value.confidence, 0, 100),
    foodItems: Array.isArray(value.foodItems) ? value.foodItems.map(normalizeFoodItem) : [],
    assumptions: stringArray(value.assumptions),
  };
}

function normalizeFoodItem(value: unknown) {
  const item = isRecord(value) ? value : {};
  return {
    name: stringValue(item.name, "Food"),
    quantity: stringValue(item.quantity, "1 serving"),
    calories: positiveNumber(item.calories),
    protein: positiveNumber(item.protein),
    carbohydrates: positiveNumber(item.carbohydrates),
    fat: positiveNumber(item.fat),
  };
}

function normalizeFoodRecognition(value: unknown) {
  const item = isRecord(value) ? value : {};
  return {
    name: stringValue(item.name, "Food"),
    estimatedQuantity: stringValue(item.estimatedQuantity ?? item.quantity, "1 serving"),
    confidence: clampInt(item.confidence, 0, 100),
  };
}

function normalizeDailyMealPlan(value: Record<string, unknown>) {
  const breakfast = normalizeSuggestedMeal(value.breakfast, "Breakfast");
  const lunch = normalizeSuggestedMeal(value.lunch, "Lunch");
  const dinner = normalizeSuggestedMeal(value.dinner, "Dinner");
  const snacks = Array.isArray(value.snacks)
    ? value.snacks.map((snack, index) => normalizeSuggestedMeal(snack, `Snack ${index + 1}`))
    : [];
  const meals = [breakfast, lunch, dinner, ...snacks];

  return {
    breakfast,
    lunch,
    dinner,
    snacks,
    totalCalories: positiveNumber(value.totalCalories) || sum(meals, "calories"),
    totalProtein: positiveNumber(value.totalProtein) || sum(meals, "protein"),
    totalCarbs: positiveNumber(value.totalCarbs) || sum(meals, "carbohydrates"),
    totalFat: positiveNumber(value.totalFat) || sum(meals, "fat"),
  };
}

function normalizeSuggestedMeal(value: unknown, fallbackName: string) {
  const meal = isRecord(value) ? value : {};
  return {
    name: stringValue(meal.name, fallbackName),
    description: stringValue(meal.description, ""),
    calories: positiveNumber(meal.calories),
    protein: positiveNumber(meal.protein),
    carbohydrates: positiveNumber(meal.carbohydrates),
    fat: positiveNumber(meal.fat),
    ingredients: stringArray(meal.ingredients),
    instructions: stringValue(meal.instructions, ""),
  };
}

function json(body: unknown, status = 200) {
  return new Response(JSON.stringify(body), {
    status,
    headers: {
      ...corsHeaders,
      "Content-Type": "application/json",
    },
  });
}

function isRecord(value: unknown): value is Record<string, unknown> {
  return typeof value === "object" && value !== null && !Array.isArray(value);
}

function positiveNumber(value: unknown) {
  return Math.max(0, Number(value) || 0);
}

function clampInt(value: unknown, min: number, max: number) {
  return Math.max(min, Math.min(max, Math.round(Number(value) || 0)));
}

function stringValue(value: unknown, fallback: string) {
  return typeof value === "string" && value.trim() ? value.trim() : fallback;
}

function stringArray(value: unknown) {
  return Array.isArray(value) ? value.filter((item): item is string => typeof item === "string") : [];
}

function sum(meals: Array<Record<string, unknown>>, key: string) {
  return meals.reduce((total, meal) => total + positiveNumber(meal[key]), 0);
}

const mealAnalysisSystemPrompt = `
You are a professional nutritionist and dietitian with expertise in food analysis. Analyze meal descriptions and provide accurate nutritional information.

Guidelines:
1. Use standard nutritional databases and USDA food composition data.
2. Be conservative in estimates.
3. Consider typical serving sizes unless quantities are specific.
4. Provide confidence based on description specificity and portion clarity.
5. Always mention assumptions about portion sizes or preparation methods.
Return only JSON.
`;

const mealSuggestionSystemPrompt = `
You are a certified nutritionist and meal planning expert. Create balanced, practical meal plans that meet specific nutritional targets while considering user preferences and dietary restrictions. Return only JSON.
`;

const foodRecognitionSystemPrompt = `
You are an expert at identifying foods from descriptions. Parse meal descriptions into individual food items with estimated quantities and confidence levels. Return only JSON.
`;

const foodImageAnalysisPrompt = `
Analyze this food image and provide detailed nutritional information.
Return valid JSON only using the meal analysis shape:
{
  "totalCalories": 0,
  "protein": 0,
  "carbohydrates": 0,
  "fat": 0,
  "fiber": 0,
  "confidence": 0,
  "foodItems": [
    {
      "name": "string",
      "quantity": "string",
      "calories": 0,
      "protein": 0,
      "carbohydrates": 0,
      "fat": 0
    }
  ],
  "assumptions": ["string"]
}
Be conservative about portion sizes and mention visual assumptions.
`;
