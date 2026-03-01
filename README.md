<p align="center">
  <img src="docs/AppIcon.png" width="200" height="200" alt="CalorieCop Icon">
</p>

<h1 align="center">CalorieCop</h1>

<p align="center">
  A personal health management iOS app for weight loss tracking with natural language food input and Apple Watch activity integration.
</p>

## Features

- **Natural Language Food Input**: Describe your food in plain Chinese (e.g., "一碗米饭") and AI will parse the nutrition info
- **AI-Powered Nutrition Parsing**: Uses MiniMax API to accurately estimate calories and macros
- **HealthKit Integration**: Syncs with Apple Watch to track calories burned
- **Calorie Balance Tracking**: See your daily intake vs burn at a glance
- **SwiftData Persistence**: All food entries stored locally on device

## Requirements

- iOS 17.0+
- Xcode 15.0+
- Apple Watch (optional, for activity tracking)
- MiniMax API key

## Setup

### 1. Clone the repository

```bash
git clone <repository-url>
cd CalorieCop
```

### 2. Configure API Key

The app uses the MiniMax API for food parsing. Set up your API key:

1. Open the project in Xcode
2. Edit the scheme (Product → Scheme → Edit Scheme)
3. Select "Run" → "Arguments" → "Environment Variables"
4. Add a new variable:
   - Name: `MINIMAX_API_KEY`
   - Value: Your MiniMax API key

### 3. Enable HealthKit

1. Open the project in Xcode
2. Select the CalorieCop target
3. Go to "Signing & Capabilities"
4. Click "+ Capability" and add "HealthKit"
5. Check "Clinical Health Records" if needed

### 4. Build and Run

1. Select your target device or simulator
2. Press Cmd+R to build and run

## Project Structure

```
CalorieCop/
├── App/
│   ├── CalorieCopApp.swift      # App entry point
│   └── ContentView.swift         # Main tab view
├── Models/
│   ├── FoodEntry.swift           # SwiftData model
│   └── NutritionInfo.swift       # API response struct
├── Services/
│   ├── AIService/
│   │   ├── AIServiceProtocol.swift
│   │   ├── MiniMaxService.swift
│   │   └── FoodParsingPrompt.swift
│   ├── HealthKitService.swift
│   └── APIKeyManager.swift
├── Views/
│   ├── FoodInput/
│   │   ├── FoodInputView.swift
│   │   └── FoodConfirmationView.swift
│   ├── Dashboard/
│   │   ├── DashboardView.swift
│   │   └── FoodListView.swift
│   └── Components/
│       ├── NutritionCard.swift
│       └── CalorieBalanceView.swift
└── Utilities/
    └── Extensions.swift
```

## Usage

1. **Record Food**: Tap the "记录" tab and describe what you ate
2. **Review & Confirm**: Check the AI-parsed nutrition and confirm
3. **Track Progress**: View your daily summary on the "概览" tab
4. **Monitor Balance**: See calories consumed vs burned

## API Reference

### MiniMax API

The app uses MiniMax's ChatCompletion API:
- Endpoint: `https://api.minimaxi.chat/v1/text/chatcompletion_v2`
- Model: `MiniMax-M2.5` (multimodal, supports text & image)
- AI Advisor: `MiniMax-M2.5-highspeed` (faster responses)
- Response format: JSON object

## Privacy

- All food data is stored locally on your device using SwiftData
- HealthKit data never leaves your device
- API calls only send food descriptions (no personal data)

## License

MIT License
