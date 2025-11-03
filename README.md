# 📚 ReadMe - AI-Powered Children's Reading App

> Personalized reading experiences for kids aged 6-12, powered by AI

---

## 🎯 What is ReadMe?

ReadMe is a cross-platform reading application designed to encourage children to read more through:

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

- **Frontend**: Flutter 3.x (Dart)
- **Backend**: Firebase (Firestore, Storage, Auth, Functions)
- **AI**: OpenAI GPT-4
- **State Management**: Provider
- **PDF Viewer**: Syncfusion Flutter PDF Viewer

---

## ✨ Key Features

### For Children:
- Personalized book recommendations
- Interactive reading experience
- Achievement badges and celebrations
- Reading streak calendar
- Progress tracking

### For Parents:
- Reading analytics dashboard
- Completion tracking
- Time spent reading
- Book history

### For Administrators:
- Book upload and management
- AI-powered tagging
- Content moderation

---

## 🏗️ Project Structure

```
Readme_dev/
├── lib/
│   ├── screens/           # UI screens
│   ├── widgets/           # Reusable widgets
│   ├── providers/         # State management
│   ├── services/          # Business logic
│   ├── models/            # Data models
│   └── utils/             # Helper functions
├── functions/             # Firebase Cloud Functions
│   └── index.js          # AI tagging & recommendations
├── assets/
│   ├── illustrations/     # SVG illustrations
│   └── fonts/            # Custom fonts
├── tools/                # Admin scripts
└── docs/                 # Documentation
```

---

## 🔑 Firebase Collections

- `books` - Book catalog with AI-generated traits/tags
- `users` - User profiles and preferences
- `reading_progress` - Reading tracking per book
- `reading_sessions` - Session duration tracking
- `user_achievements` - Unlocked badges
- `quiz_analytics` - Personality quiz results
- `book_interactions` - Favorites and bookmarks

---

## 🤖 AI Systems

### 1. **AI Book Tagging**
Automatically extracts traits, tags, and age ratings from PDF content using OpenAI GPT-4.

- Runs daily at 2 AM UTC
- Processes books flagged with `needsTagging: true`
- Generates 15 unified traits and tags

### 2. **AI Recommendations**
Matches user personality and reading history with available books.

- Runs daily at 3 AM UTC
- Analyzes quiz results, favorites, completed books, and session duration
- Returns ranked list of personalized book recommendations

---

## 🎨 UI Highlights

- **Clean Design**: Purple brand color (#8E44AD) with subtle shadows
- **Material Icons**: Consistent iconography throughout
- **Animations**: Confetti celebrations, smooth transitions
- **Responsive**: Works on mobile, tablet, and desktop
- **Accessible**: High contrast, clear typography

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
| Personality Quiz | ✅ Complete |
| AI Book Tagging | ✅ Complete |
| AI Recommendations | ✅ Complete |
| Reading Progress | ✅ Complete |
| Streak System | ✅ Complete (Bug fixed Nov 2025) |
| Achievements | ✅ Complete |
| PDF Reader | ✅ Complete |
| Parent Dashboard | ✅ Complete |
| Admin Portal | ⚠️ In Progress |

---

## 🐛 Known Issues

- ⚠️ `reading_sessions` field name mismatch (identified, not yet fixed in production)
- ✅ All other critical bugs resolved

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

*Last Updated: November 2025*
