# 📚 ReadMe - AI-Powered Children's Reading App

> Personalized reading experiences for kids aged 6-12, powered by AI

---

## 🎯 What is ReadMe?

ReadMe is a cross-platform reading application designed to encourage children aged 6-12 to read more through:

- **🤖 AI-Powered Recommendations**: Personalized book suggestions based on personality traits and reading history
- **🎮 Gamification**: Achievements, badges, streaks, and progress tracking
- **📊 Analytics**: Comprehensive reading statistics and parental monitoring
- **📖 Rich Reading Experience**: PDF viewer with progress tracking and session management
- **🌟 Personality-Based Matching**: Quiz system to understand each child's unique reading preferences

---

## 🚀 Quick Start

```bash
# Clone repository
git clone <repository-url>
cd Readme_dev

# Install dependencies
flutter pub get

# Configure Firebase
flutterfire configure

# Run the app
flutter run
```

**For detailed setup instructions, see [SETUP_GUIDE.md](./SETUP_GUIDE.md)**

---

## 📖 Documentation

### **Complete Guides:**

1. **[SETUP_GUIDE.md](./SETUP_GUIDE.md)** - Setup, deployment, and configuration
   - Firebase configuration
   - Cloud Functions setup
   - Environment variables
   - CORS configuration
   - Moving to new location/repo
   - Troubleshooting

2. **[TECHNICAL_DOCUMENTATION.md](./TECHNICAL_DOCUMENTATION.md)** - Architecture and technical details
   - System architecture
   - Feature explanations
   - Data models and collections
   - Backend systems (Firebase + AI)
   - Frontend architecture
   - UI system and design
   - Key algorithms and logic
   - Integration and data flow

---

## 💻 Tech Stack

- **Frontend**: Flutter 3.x (Dart 3.1+)
- **Backend**: Firebase (Firestore, Storage, Auth, Functions)
- **AI**: OpenAI GPT-4
- **State Management**: Provider 6.1+
- **PDF Viewer**: Syncfusion Flutter PDF Viewer
- **Navigation**: GoRouter 16.2+
- **Fonts**: DM Sans (custom typography)

---

## ✨ Key Features

### For Children:
- 🎯 Personalized book recommendations based on Big Five personality traits
- 📖 Interactive PDF reading experience with progress tracking
- 🏆 Achievement badges with celebratory animations and confetti
- 🔥 Reading streak calendar with visual feedback
- 📊 Personal reading statistics and milestones
- 🎮 Comprehension quizzes with bonus points
- 🏅 Leaderboard with competitive rankings
- ⭐ Favorite books collection
- 🎨 Profile customization with avatars

### For Parents:
- 📊 Comprehensive reading analytics dashboard
- ✅ Book completion tracking
- ⏱️ Time spent reading insights
- 📚 Complete reading history
- 🎯 Daily reading goal management
- 🔒 Content filter settings (coming soon)

### For Administrators:
- 📤 Bulk book upload system
- 🤖 AI-powered automatic book tagging
- 📊 User analytics and insights

---

## 🏗️ Project Structure

```
Readme_dev/
├── lib/
│   ├── screens/           # UI screens (auth, child, parent, book)
│   ├── widgets/           # Reusable widgets
│   │   ├── common/       # Common widgets (cards, badges, progress bars)
│   │   └── ...           # Feature-specific widgets
│   ├── providers/         # State management (Provider pattern)
│   ├── services/          # Business logic & Firebase integration
│   ├── theme/            # App theme and styling
│   └── utils/            # Helper functions and utilities
├── functions/             # Firebase Cloud Functions (Node.js)
│   └── index.js          # AI tagging & recommendations
├── assets/
│   ├── illustrations/     # SVG illustrations
│   ├── sounds/           # UI sound effects
│   └── fonts/            # DM Sans font family
├── tools/                # Admin scripts for book management
│   ├── pdfs/             # Sample PDFs
│   └── covers/           # Book cover images
└── docs/                 # Comprehensive documentation
```

---

## 🔑 Firebase Collections

- `books` - Book catalog with AI-generated traits/tags
- `users` - User profiles and preferences
- `reading_progress` - Reading tracking per book
- `reading_sessions` - Session duration tracking
- `achievements` - Achievement definitions (master list)
- `user_achievements` - Unlocked badges and achievements
- `quiz_analytics` - Personality quiz results
- `book_quizzes` - AI-generated comprehension quizzes per book
- `quiz_attempts` - User quiz attempt history
- `book_interactions` - Favorites and bookmarks

---

## 🤖 AI Systems

### 1. **AI Book Tagging**
Automatically extracts personality traits, themes, and age ratings from PDF content using OpenAI GPT-4.

- Runs daily at 2 AM UTC via scheduled Cloud Function
- Processes books flagged with `needsTagging: true`
- Generates comprehensive trait lists based on Big Five personality model
- Assigns appropriate age ratings (6+, 8+, 10+, 12+)
- Extracts thematic tags for better categorization

### 2. **AI Recommendations**
Matches user personality and reading behavior with available books using multi-factor analysis.

- Runs daily at 3 AM UTC via scheduled Cloud Function
- **Factors considered:**
  - Personality quiz results (Big Five traits)
  - Reading history and completed books
  - Favorited books
  - Reading session duration and frequency
- Returns ranked, personalized book recommendations
- Adapts over time as reading patterns evolve

---

## 🎨 UI Highlights

- **Clean Design**: Purple brand color (#8E44AD) with subtle shadows and rounded corners
- **Custom Typography**: DM Sans font family for better readability
- **Material Icons**: Consistent iconography throughout
- **Animations**: Confetti celebrations, smooth transitions, haptic feedback
- **Sound Effects**: Optional tap feedback for enhanced UX
- **Responsive**: Optimized layouts for mobile, tablet, and desktop
- **Accessible**: High contrast, clear typography, child-friendly interface

---

## 📱 Platforms

- ✅ iOS
- ✅ Android
- ✅ Web
- ✅ macOS
- ✅ Windows
- ✅ Linux

---

## 🔧 Development

```bash
# Run in development
flutter run

# Run tests
flutter test

# Build for production
flutter build apk --release      # Android
flutter build ios --release      # iOS
flutter build web --release      # Web
```

---

## 🚀 Deployment

### Mobile Apps:
- **Android**: Build APK and upload to Google Play Console
- **iOS**: Build with Xcode and submit to App Store

### Web App:
```bash
flutter build web --release
firebase deploy --only hosting
```

### Cloud Functions:
```bash
cd functions
npm install
cd ..
firebase deploy --only functions
```

**For detailed deployment instructions, see [SETUP_GUIDE.md](./SETUP_GUIDE.md#deployment)**

---

## 📊 Current Status

| Feature | Status |
|---------|--------|
| Authentication | ✅ Complete |
| Personality Quiz (Big Five) | ✅ Complete |
| AI Book Tagging | ✅ Complete |
| AI Recommendations | ✅ Complete |
| Reading Progress Tracking | ✅ Complete |
| Streak System | ✅ Complete |
| Achievements & Badges | ✅ Complete |
| Book Comprehension Quizzes | ✅ Complete |
| Leaderboard System | ✅ Complete |
| PDF Reader (Syncfusion) | ✅ Complete |
| Parent Dashboard | ✅ Complete |
| Profile & Avatar System | ✅ Complete |
| Sound & Haptic Feedback | ✅ Complete |
| Responsive UI | ✅ Complete |
| Admin Portal | 🔄 Scripts Available (UI in development) |
| Content Filters | 🔄 Backend Ready (UI coming soon) |

---

## 🐛 Known Issues & Recent Fixes

### ✅ Recently Fixed (December 2025):
- Account type screen icon consistency
- Login password field focus color (removed pink tint)
- Signup screen spacing improvements
- Leaderboard redesign with medals and gradients
- QR screen redundant icon removal
- Help & Support content accuracy
- Quiz results screen with confetti and animations
- Achievement collection regeneration after accidental deletion
- Database cleanup script protection fixes
- All withOpacity deprecation warnings

### 🔄 In Progress:
- Admin portal UI development
- Content filter parent controls UI

**For detailed issue tracking, see [TECHNICAL_DOCUMENTATION.md](./TECHNICAL_DOCUMENTATION.md#known-issues--fixes)**

---

## 📞 Support

### Documentation:
- Setup & Configuration: [SETUP_GUIDE.md](./SETUP_GUIDE.md)
- Technical Details: [TECHNICAL_DOCUMENTATION.md](./TECHNICAL_DOCUMENTATION.md)

### Firebase:
- Console: https://console.firebase.google.com
- Project ID: `readme-40267`

### Resources:
- Flutter Docs: https://flutter.dev/docs
- Firebase Docs: https://firebase.google.com/docs
- OpenAI Docs: https://platform.openai.com/docs

---

## 🎓 Learning Path

**New to the project?**

1. Read this README for overview
2. Follow [SETUP_GUIDE.md](./SETUP_GUIDE.md) to set up your environment
3. Read [TECHNICAL_DOCUMENTATION.md](./TECHNICAL_DOCUMENTATION.md) to understand architecture
4. Run the app and explore features
5. Make your first contribution!

---

## 🤝 Contributing

This is a private educational project. For questions or contributions, refer to the comprehensive documentation:

- [SETUP_GUIDE.md](./SETUP_GUIDE.md) - Setup and deployment
- [TECHNICAL_DOCUMENTATION.md](./TECHNICAL_DOCUMENTATION.md) - Architecture and features

---

## 📄 License

Private Project - All Rights Reserved

---

## 🎉 Acknowledgments

- **Flutter Team** - Amazing cross-platform framework
- **Firebase** - Robust backend infrastructure
- **OpenAI** - Powerful AI capabilities
- **Syncfusion** - Excellent PDF viewer component

---

**Built with ❤️ for young readers**

*Last Updated: December 19, 2025*
