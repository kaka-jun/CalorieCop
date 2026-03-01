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
- Model: `MiniMax-M2.5` (supports both text and vision/multimodal)
- Endpoint: `https://api.minimaxi.chat/v1/text/chatcompletion_v2`
- Note: `MiniMax-VL-01` is open-source only, not available via API

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

## Development Rules

**Always verify builds before asking user to test:**
```bash
xcodebuild -scheme CalorieCop -destination 'platform=iOS Simulator,name=iPhone 15 Pro' build 2>&1 | grep -E "(error:|warning:|BUILD SUCCEEDED|BUILD FAILED)"
```

- Run this command after making code changes
- Fix any errors or warnings before telling user to build/run
- Only ask user to test after BUILD SUCCEEDED with no warnings

## Common Commands

```bash
# Build (with error/warning filter)
xcodebuild -scheme CalorieCop -destination 'platform=iOS Simulator,name=iPhone 15 Pro' build 2>&1 | grep -E "(error:|warning:|BUILD SUCCEEDED|BUILD FAILED)"

# Open project
open CalorieCop.xcodeproj
```
