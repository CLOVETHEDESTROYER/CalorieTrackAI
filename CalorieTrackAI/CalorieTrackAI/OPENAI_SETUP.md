# OpenAI Integration Setup Guide

This guide will help you integrate OpenAI's GPT API with your CalTrack AI app for intelligent meal analysis and suggestions.

## 🚀 Quick Setup

### 1. Get OpenAI API Key

1. Visit [OpenAI Platform](https://platform.openai.com/api-keys)
2. Sign in or create an account
3. Click "Create new secret key"
4. Give it a name like "CalTrack AI"
5. Copy your API key (starts with `sk-`)

### 2. Configure Your App

1. Open `Info.plist` in your Xcode project
2. Find the `OPENAI_API_KEY` entry
3. Replace `your-openai-api-key-here` with your actual API key

```xml
<key>OPENAI_API_KEY</key>
<string>sk-your-actual-api-key-here</string>
```

**⚠️ Security Note**: For production apps, use a more secure method to store API keys (like Keychain or environment variables).

### 3. Test the Integration

1. Build and run your app
2. Navigate to the "AI Assistant" tab
3. Try the meal analysis feature:
   - Enter: "Grilled chicken breast with steamed broccoli and brown rice"
   - Tap "Analyze with AI"
   - Check if you get nutrition estimates

## 🎯 Features Overview

### 🍽️ Meal Analysis

- **Natural Language Processing**: Describe meals in plain English
- **Nutrition Estimation**: Get calories, protein, carbs, fat, and fiber
- **Confidence Scoring**: AI provides confidence levels for estimates
- **Quick Logging**: Add analyzed meals directly to your food log

### 🍳 Daily Meal Suggestions

- **Personalized Plans**: Based on your profile and goals
- **Dietary Preferences**: Supports vegetarian, vegan, gluten-free, etc.
- **Cuisine Variety**: Choose from different cooking styles
- **Budget Considerations**: Options for different price ranges

### ⚡ Quick Analysis in Log Food

- **Instant Analysis**: Analyze meals right from the Log Food tab
- **Auto-Fill**: AI results pre-fill the manual entry form
- **Streamlined Workflow**: Faster food logging with AI assistance

## 📊 Usage Examples

### Meal Analysis Examples

**Input**: "Two slices of whole wheat toast with avocado and scrambled eggs"

**Expected Output**:

- Calories: ~450
- Protein: ~20g
- Carbohydrates: ~35g
- Fat: ~25g
- Confidence: 85%

### Meal Suggestion Preferences

Configure your preferences for better suggestions:

- **Dietary Restrictions**: Vegetarian, Vegan, Gluten-Free, etc.
- **Cuisine Types**: Mediterranean, Asian, American, etc.
- **Complexity**: Simple (15 min), Medium (30 min), Complex (45+ min)
- **Budget**: Budget-friendly, Moderate, Premium

## 💰 Cost Management

### Token Usage

- **GPT-4o-mini**: Cost-effective model optimized for nutrition tasks
- **Average Cost**: ~$0.01-0.03 per analysis
- **Monthly Estimate**: $5-15 for regular use

### Cost-Saving Tips

1. Use the Quick Analysis for simple meals
2. Batch multiple food items in one description
3. Set up usage limits in OpenAI dashboard
4. Monitor usage in OpenAI billing section

## 🛠️ Advanced Configuration

### Custom Prompts

You can modify the system prompts in `OpenAIService.swift`:

- `mealAnalysisSystemPrompt`: For meal analysis accuracy
- `mealSuggestionSystemPrompt`: For meal planning style
- `foodRecognitionSystemPrompt`: For food identification

### Model Selection

Change the model in `OpenAIService.swift`:

```swift
private let model = "gpt-4o-mini" // Current default
// Alternatives:
// "gpt-4o" - More accurate but more expensive
// "gpt-3.5-turbo" - Faster but less accurate
```

### Temperature Settings

Adjust creativity vs consistency:

```swift
temperature: 0.3 // Current setting (more consistent)
// 0.0 - Very consistent, less creative
// 0.7 - More creative, less consistent
```

## 🔍 Troubleshooting

### Common Issues

1. **"Invalid API Key" Error**

   - Verify your API key is correct
   - Check if you have credits in your OpenAI account
   - Ensure the key has proper permissions

2. **Network Errors**

   - Check internet connection
   - Verify OpenAI API status
   - Try again after a few seconds

3. **Poor Analysis Results**

   - Be more specific in meal descriptions
   - Include quantities when possible
   - Try different wording

4. **API Rate Limits**
   - OpenAI has rate limits for API calls
   - Implement retry logic with exponential backoff
   - Consider upgrading your OpenAI plan

### Debug Mode

Enable debug logging by adding this to `OpenAIService.swift`:

```swift
private func logRequest(_ prompt: String) {
    print("🤖 OpenAI Request: \(prompt)")
}
```

## 📈 Analytics & Monitoring

### Track Usage

Monitor your OpenAI usage:

1. Visit [OpenAI Usage Dashboard](https://platform.openai.com/usage)
2. Set up billing alerts
3. Review monthly reports

### Performance Metrics

- **Response Time**: Typically 2-5 seconds
- **Accuracy**: 80-95% confidence for common foods
- **User Satisfaction**: Track how often users accept AI suggestions

## 🔒 Privacy & Security

### Data Handling

- Meal descriptions are sent to OpenAI for processing
- No personal user information is included in requests
- OpenAI's data usage policy applies

### Security Best Practices

1. **Never commit API keys** to version control
2. **Use environment variables** in production
3. **Rotate keys regularly**
4. **Monitor usage** for unusual activity

### GDPR Compliance

- Inform users that meal descriptions are processed by OpenAI
- Provide opt-out options for AI features
- Include in your privacy policy

## 🚦 Production Deployment

### Environment Setup

```swift
// Production configuration
private init() {
    #if DEBUG
    self.apiKey = Bundle.main.object(forInfoDictionaryKey: "OPENAI_API_KEY") as? String ?? ""
    #else
    // Use Keychain or secure environment variable
    self.apiKey = KeychainHelper.getAPIKey() ?? ""
    #endif
}
```

### Error Handling

Implement comprehensive error handling:

- Network timeouts
- API rate limits
- Invalid responses
- Fallback to manual entry

### Caching

Consider caching common food analyses:

```swift
// Cache frequently analyzed foods
private var analysisCache: [String: MealAnalysis] = [:]
```

## 🎉 Next Steps

### Enhanced Features

1. **Food Image Recognition**: Combine with Core ML
2. **Nutritionist Chat**: Interactive nutrition advice
3. **Recipe Generation**: Create recipes based on preferences
4. **Grocery Lists**: Generate shopping lists from meal plans

### Integration Ideas

1. **Health App Sync**: Export nutrition data to Apple Health
2. **Fitness Trackers**: Integrate with workout apps
3. **Smart Scales**: Connect with bluetooth scales
4. **Social Features**: Share meal suggestions with friends

---

🎯 **You're Ready!** Your CalTrack AI app now has powerful AI-driven nutrition analysis capabilities. Start tracking smarter with natural language meal descriptions and personalized meal suggestions!
