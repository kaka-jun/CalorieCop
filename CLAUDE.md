# CalorieCop

A personal health management iOS app for calorie tracking and weight management.

## Tech Stack

- **UI**: SwiftUI (iOS 17+)
- **Storage**: SwiftData
- **AI**: MiniMax API (text & vision models)
- **Health**: HealthKit (Apple Watch integration)
- **Charts**: Swift Charts

## Project Structure

```
CalorieCop/
├── App/
│   ├── CalorieCopApp.swift      # Entry point, ModelContainer setup
│   └── ContentView.swift        # Main TabView (今日/记录/历史/目标)
├── Models/
│   ├── FoodEntry.swift          # Food record with nutrition
│   ├── NutritionInfo.swift      # Parsed nutrition data
│   ├── UserGoal.swift           # Calorie/weight targets
│   ├── UserSettings.swift       # Preferences (weight unit)
│   ├── WeightEntry.swift        # Weight records
│   ├── ChatMessage.swift        # AI advisor chat history
│   └── FoodPreference.swift     # User food habits for AI
├── Services/
│   ├── AIService/
│   │   ├── MiniMaxService.swift     # API calls (text & vision)
│   │   └── FoodParsingPrompt.swift  # System prompts
│   ├── HealthKitService.swift   # Apple Watch data
│   ├── APIKeyManager.swift      # API key handling
│   └── Secrets.swift            # API keys (gitignored)
├── Views/
│   ├── Dashboard/               # 今日 tab
│   ├── FoodInput/               # 记录 tab (camera, text input)
│   ├── History/                 # 历史 tab (calendar, AI advisor)
│   └── Goals/                   # 目标 tab (weight chart, goals)
└── Resources/
    └── Assets.xcassets/
```

## Key Patterns

### SwiftData Models
All models use `@Model` macro. Schema registered in `CalorieCopApp.swift`:
```swift
.modelContainer(for: [FoodEntry.self, UserGoal.self, ...])
```

### API Key Setup
Copy `Secrets.swift.template` to `Secrets.swift` and add your key:
```swift
enum Secrets {
    static let miniMaxAPIKey = "your_key_here"
}
```

### MiniMax API
- Text model: `MiniMax-Text-01`
- Vision model: `MiniMax-VL-01`
- Endpoint: `https://api.minimaxi.chat/v1/text/chatcompletion_v2`

### Food Parsing
AI returns JSON with: `food_name`, `grams`, `calories`, `protein`, `carbohydrates`, `fat`, `confidence`, `notes`, `days_ago`

User preferences are injected into system prompt for personalized parsing.

## Build & Run

1. Open `CalorieCop.xcodeproj`
2. Set up Secrets.swift with MiniMax API key
3. Select your device/simulator
4. Cmd+R to run

For physical device: configure Signing & Capabilities with your Apple ID.

## Language

- UI: Chinese (Simplified)
- Code: English

## Common Commands

```bash
# Build
xcodebuild -scheme CalorieCop -destination 'platform=iOS Simulator,name=iPhone 16 Pro' build

# Open project
open CalorieCop.xcodeproj
```
