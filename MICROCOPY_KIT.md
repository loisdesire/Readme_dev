# ReadMe App - Complete Microcopy Kit

## App Overview

**ReadMe** is a gamified children's reading platform designed to make reading fun, engaging, and trackable for young readers while giving parents comprehensive oversight and control. The app serves two distinct user types:

**For Children (Primary Users):** ReadMe transforms reading into an adventure through a carefully designed library of age-appropriate books, interactive quizzes to test comprehension, achievement systems with badges and points, and competitive leaderboards to encourage consistent reading habits. Children can browse books, read at their own pace, earn rewards, track their progress, and compete with peers through weekly challenges and league rankings.

**For Parents (Secondary Users/Guardians):** Parents receive a dedicated dashboard to monitor their child's reading activity, set reading goals, apply content filters to ensure age-appropriate material, view detailed reading history with time spent and comprehension scores, and link multiple children's accounts for family oversight.

**User Journey:** New users sign up and complete a personalized quiz that tailors book recommendations to their interests and reading level. Children then explore the library (filtered by parental controls if applicable), start reading books, take optional comprehension quizzes for bonus points, earn achievements, and compete on leaderboards. Parents can log in separately to monitor progress, adjust content settings, and encourage reading through goal-setting.

---

## Authentication & Onboarding

### Login Screen
**Path:** `lib/screens/auth/login_screen.dart`

| Copy | Context | Purpose | User Type |
|------|---------|---------|-----------|
| "Welcome back!" | SnackBar shown after successful login | Greeting message to returning users | Both |
| "Login" | Toggle button / screen title | Indicates user is on login form | Both |
| "Register" | Toggle button for switching to registration | Directs users to create new account | Both |
| "Email" | Input field label | Identifies email address field | Both |
| "Password" | Input field label | Identifies password input | Both |
| "Please enter your email" | Email field validation | Error shown when email is empty | Both |
| "Please enter a valid email" | Email field validation | Error for incorrect email format | Both |
| "Please enter your password" | Password field validation | Error when password is empty | Both |
| "Password must be at least 6 characters" | Password validation | Informs minimum password length requirement | Both |
| "Login" | Primary action button | Submits login form | Both |
| "Don't have an account? Register" | Footer text / navigation | Encourages new users to sign up | Both |
| "Forgot Password?" | Link button | Initiates password recovery flow | Both |

### Register Screen
**Path:** `lib/screens/auth/register_screen.dart`

| Copy | Context | Purpose | User Type |
|------|---------|---------|-----------|
| "Create Account" | Screen title / heading | Indicates registration process | Both |
| "I'm a..." | Account type selector label | Prompts user to choose account type | Both |
| "Child" | Account type option | Child account selection | Child |
| "Parent" | Account type option | Parent account selection | Parent |
| "Username" | Input field label | Identifies username field | Both |
| "Email" | Input field label | Email address input | Both |
| "Password" | Input field label | Password creation input | Both |
| "Confirm Password" | Input field label | Password confirmation input | Both |
| "Date of Birth" | Input field label (child accounts) | Collects child's age for content filtering | Child |
| "Please enter a username" | Validation error | Shown when username is empty | Both |
| "Username must be at least 3 characters" | Validation error | Minimum username length requirement | Both |
| "Please enter your email" | Validation error | Email required | Both |
| "Please enter a valid email" | Validation error | Email format validation | Both |
| "Please enter a password" | Validation error | Password required | Both |
| "Password must be at least 6 characters" | Validation error | Minimum password length | Both |
| "Please confirm your password" | Validation error | Confirmation field required | Both |
| "Passwords do not match" | Validation error | Password mismatch error | Both |
| "Please enter your date of birth" | Validation error | DOB required for child accounts | Child |
| "You must be at least 3 years old" | Validation error | Age restriction message | Child |
| "Register" | Primary action button | Submits registration form | Both |
| "Already have an account? Login" | Footer navigation | Directs existing users to login | Both |
| "Account created successfully!" | Success SnackBar | Confirms successful registration | Both |

### Onboarding Screen
**Path:** `lib/screens/onboarding/onboarding_screen.dart`

| Copy | Context | Purpose | User Type |
|------|---------|---------|-----------|
| "Welcome to ReadMe!" | First onboarding slide title | App introduction | Child |
| "Discover amazing stories and grow your reading skills" | First slide description | App value proposition | Child |
| "Build Your Library" | Second slide title | Feature highlight - library | Child |
| "Choose from hundreds of books tailored to your interests" | Second slide description | Explains personalization | Child |
| "Earn Rewards" | Third slide title | Feature highlight - gamification | Child |
| "Complete quizzes, earn badges, and climb the leaderboard!" | Third slide description | Explains achievement system | Child |
| "Track Progress" | Fourth slide title | Feature highlight - analytics | Child |
| "Watch your reading stats grow as you explore new worlds" | Fourth slide description | Motivates through progress tracking | Child |
| "Next" | Navigation button (slides 1-3) | Advances to next onboarding slide | Child |
| "Get Started" | Final button (slide 4) | Completes onboarding, goes to quiz | Child |
| "Skip" | Skip button (all slides) | Allows users to skip onboarding | Child |

---

## Child Experience

### Home Screen
**Path:** `lib/screens/child/child_home_screen.dart`

| Copy | Context | Purpose | User Type |
|------|---------|---------|-----------|
| "Welcome back, [username]!" | Top greeting with user's name | Personalized welcome message | Child |
| "Good morning, [username]!" | Morning greeting (6am-12pm) | Time-based personalized greeting | Child |
| "Good afternoon, [username]!" | Afternoon greeting (12pm-6pm) | Time-based personalized greeting | Child |
| "Good evening, [username]!" | Evening greeting (6pm-6am) | Time-based personalized greeting | Child |
| "Your Stats" | Section heading for statistics | Introduces stats overview | Child |
| "[X] Books Read" | Stat card showing total books completed | Displays reading achievement count | Child |
| "[X] Total Points" | Stat card showing achievement points | Displays gamification score | Child |
| "[X] Day Streak" | Stat card showing consecutive reading days | Motivates daily reading habit | Child |
| "🔥" | Emoji accompanying streak | Visual reinforcement of streak | Child |
| "Weekly Challenge" | Challenge card heading | Introduces weekly reading goal | Child |
| "Read [X] books this week" | Challenge description | States weekly target | Child |
| "Amazing! You completed the challenge!" | Completion message | Celebrates achieving weekly goal | Child |
| "[X] days left" | Countdown badge | Shows time remaining in week | Child |
| "Completed! 🎉" | Completion badge | Celebratory completion indicator | Child |
| "[X] / [target] books" | Progress indicator | Shows current progress toward target | Child |
| "Continue Reading" | Section heading | Introduces ongoing books | Child |
| "See all >" | Link to library ongoing tab | Navigates to full ongoing list | Child |
| "Your Level" | Level card heading | Shows user's current reading level | Child |
| "Level [X]" | Current level display | Numerical level indicator | Child |
| "[X] XP / [target] XP" | Experience points progress | Shows progress to next level | Child |
| "Next level at [X] XP" | Level-up goal | Motivates earning more points | Child |
| "Recommended For You" | Section heading for recommendations | Introduces personalized books | Child |
| "See all >" | Link to recommended books | Navigates to full recommendations | Child |
| "Start" | Book card button (not started) | Begins reading a new book | Child |
| "Continue" | Book card button (in progress) | Resumes reading ongoing book | Child |
| "Re-read" | Book card button (completed) | Starts completed book again | Child |
| "[X]% complete" | Progress percentage on book card | Shows reading completion status | Child |
| "[X] min" | Estimated reading time | Displays time commitment | Child |

### Library Screen
**Path:** `lib/screens/child/library_screen.dart`

| Copy | Context | Purpose | User Type |
|------|---------|---------|-----------|
| "Library" | Screen title | Identifies library section | Child |
| "All" | First tab label | Shows all available books | Child |
| "Recommended" | Second tab label | Shows personalized recommendations | Child |
| "Ongoing" | Third tab label | Shows books currently being read | Child |
| "Completed" | Fourth tab label | Shows finished books | Child |
| "Favorites" | Fifth tab label | Shows favorited/liked books | Child |
| "Search books..." | Search input placeholder | Prompts user to search | Child |
| "Filter" | Filter button label | Opens filtering options | Child |
| "Age Rating" | Filter category | Groups age-appropriate content | Child |
| "Traits" | Filter category | Groups books by themes/topics | Child |
| "Clear" | Filter reset button | Removes all active filters | Child |
| "Apply" | Filter confirm button | Applies selected filters | Child |
| "No books available" | Empty state heading (all books) | Shown when library is empty | Child |
| "Check back later for new books" | Empty state message | Encourages future visits | Child |
| "No recommended books yet" | Empty state heading (recommended) | Shown when no recommendations | Child |
| "Start reading books to get personalized recommendations" | Empty state message | Explains how to get recommendations | Child |
| "No books in progress" | Empty state heading (ongoing) | Shown when no ongoing books | Child |
| "Start reading a book from the library to see it here" | Empty state message | Directs user to begin reading | Child |
| "No completed books yet" | Empty state heading (completed) | Shown when no books finished | Child |
| "Complete your first book to unlock achievements and rewards!" | Empty state message | Motivates completing books | Child |
| "No favorite books yet" | Empty state heading (favorites) | Shown when no favorites | Child |
| "Tap the heart icon on a book to add it to your favorites" | Empty state message | Explains favoriting feature | Child |
| "No books found" | Search/filter empty state heading | Shown when filters return no results | Child |
| "Try adjusting your search or filter criteria" | Empty state message | Suggests modifying search | Child |
| "Browse Books" | Empty state CTA button | Navigates to all books | Child |
| "[Book Title]" | Book title display | Shows book name | Child |
| "[Author Name]" | Author display | Shows book author | Child |
| "[X] min" | Reading time indicator | Estimated completion time | Child |
| "[Age Rating]" | Age rating display (e.g. "6+") | Content appropriateness | Child |
| "Start" | Action button (not started) | Begins reading | Child |
| "Continue" | Action button (in progress) | Resumes reading | Child |
| "Re-read" | Action button (completed) | Reads again | Child |
| "[X]%" | Progress percentage | Reading completion | Child |

### Book Details Screen
**Path:** `lib/screens/book/book_details_screen.dart`

| Copy | Context | Purpose | User Type |
|------|---------|---------|-----------|
| "[Book Title]" | Top screen title | Displays book name | Child |
| "by [Author]" | Author byline | Shows book author | Child |
| "About this book" | Section heading | Introduces description | Child |
| "[Book Description]" | Full book description | Provides summary/synopsis | Child |
| "Book Details" | Section heading | Introduces metadata | Child |
| "Reading Level" | Detail label | Indicates difficulty | Child |
| "[Level]" | Reading level value (e.g. "Beginner") | Difficulty classification | Child |
| "Age Rating" | Detail label | Indicates age appropriateness | Child |
| "[Age]" | Age rating value (e.g. "6+") | Minimum age recommendation | Child |
| "Estimated Time" | Detail label | Reading duration indicator | Child |
| "[X] minutes" | Time value | Estimated completion time | Child |
| "Genre" | Detail label | Book category | Child |
| "[Genre]" | Genre value (e.g. "Adventure") | Book type/category | Child |
| "Themes" | Detail label | Book topics/traits | Child |
| "[Traits]" | Comma-separated traits | Topics covered in book | Child |
| "Quiz" | Secondary action button | Takes comprehension quiz | Child |
| "Start Reading" | Primary action button (not started) | Begins reading the book | Child |
| "Continue Reading" | Primary action button (in progress) | Resumes reading | Child |
| "Read Again" | Primary action button (completed) | Re-reads completed book | Child |
| "You're [X]% through this book" | Progress indicator | Shows reading progress | Child |

### Reading Screen (PDF Viewer)
**Path:** `lib/screens/book/pdf_reading_screen.dart`

| Copy | Context | Purpose | User Type |
|------|---------|---------|-----------|
| "[Book Title]" | Top app bar title | Shows current book | Child |
| "Page [X] of [Total]" | Bottom page indicator | Shows reading position | Child |
| "Mark as Complete" | Bottom button (when reaching end) | Finishes book and triggers celebration | Child |
| "Congratulations!" | Completion dialog title | Celebrates finishing book | Child |
| "You've finished reading [Book Title]" | Completion dialog message | Confirms book completion | Child |
| "Earn bonus points by taking the quiz!" | Quiz CTA in dialog | Encourages quiz participation | Child |
| "Take Quiz" | Dialog action button | Navigates to quiz | Child |
| "Continue Exploring" | Dialog secondary action | Returns to library | Child |

### Quiz Screen
**Path:** `lib/screens/quiz/quiz_screen.dart`

| Copy | Context | Purpose | User Type |
|------|---------|---------|-----------|
| "Personality Quiz" | Initial quiz screen title | Introduces preference quiz | Child |
| "Let's find your perfect books!" | Quiz intro subtitle | Explains quiz purpose | Child |
| "Answer these questions to get personalized recommendations" | Quiz description | Sets expectation for quiz | Child |
| "Question [X] of [Total]" | Progress indicator | Shows quiz position | Child |
| "[Question Text]" | Question display | Presents question to user | Child |
| "[Answer Option]" | Answer choice button | Selectable answer | Child |
| "Next" | Navigation button | Advances to next question | Child |
| "Finish" | Final question button | Completes quiz | Child |
| "Please select an answer" | Validation message | Prompts user to choose | Child |

**Book Comprehension Quiz (same screen, different context):**

| Copy | Context | Purpose | User Type |
|------|---------|---------|-----------|
| "[Book Title] Quiz" | Quiz screen title | Shows quiz for specific book | Child |
| "Test your understanding of the book!" | Quiz subtitle | Explains comprehension test | Child |
| "Question [X] of [Total]" | Progress indicator | Shows quiz progress | Child |
| "[Question Text]" | Comprehension question | Tests book understanding | Child |
| "[Answer Option]" | Multiple choice option | Selectable answer | Child |
| "Submit" | Final button | Submits quiz for grading | Child |

### Quiz Results Screen
**Path:** `lib/screens/quiz/quiz_result_screen.dart`

| Copy | Context | Purpose | User Type |
|------|---------|---------|-----------|
| "Quiz Complete!" | Results screen title | Celebrates quiz completion | Child |
| "You scored [X]%" | Score display | Shows percentage correct | Child |
| "Correct: [X] / [Total]" | Detailed results | Shows number correct | Child |
| "Excellent work!" | High score message (80%+) | Positive reinforcement | Child |
| "Great job!" | Good score message (60-79%) | Encouragement | Child |
| "Keep trying!" | Low score message (<60%) | Motivational message | Child |
| "You earned [X] points!" | Points reward message | Shows points earned | Child |
| "Retake Quiz" | Secondary button | Allows quiz retry | Child |
| "Continue" | Primary button | Returns to book/home | Child |

### Book Quiz Celebration Screen
**Path:** `lib/screens/book/book_quiz_celebration_screen.dart`

| Copy | Context | Purpose | User Type |
|------|---------|---------|-----------|
| "Quiz Complete!" | Celebration screen title | Announces quiz completion | Child |
| "Amazing work on the quiz!" | Congratulatory message | Positive reinforcement | Child |
| "Score" | Stat card label | Identifies questions correct | Child |
| "[X] / [Total]" | Score value | Shows correct answers | Child |
| "Accuracy" | Stat card label | Identifies percentage | Child |
| "[X]%" | Accuracy value | Percentage score | Child |
| "Points" | Stat card label | Identifies reward | Child |
| "+[X]" | Points earned | Points awarded | Child |
| "Continue Reading" | Primary action button | Returns to book/library | Child |

### Book Completion Celebration Screen
**Path:** `lib/screens/book/book_completion_celebration_screen.dart`

| Copy | Context | Purpose | User Type |
|------|---------|---------|-----------|
| "Book Complete!" | Celebration title | Announces book completion | Child |
| "Congratulations on finishing [Book Title]!" | Congratulatory message | Celebrates achievement | Child |
| "You're one book closer to becoming a reading champion!" | Motivational message | Encourages continued reading | Child |
| "Time" | Stat card label | Reading duration | Child |
| "[X] min" | Time value | Minutes spent reading | Child |
| "Points" | Stat card label | Reward earned | Child |
| "+[X]" | Points value | Points awarded | Child |
| "Speed" | Stat card label | Reading pace | Child |
| "[X] pages/min" | Speed value | Calculated reading speed | Child |
| "Take Quiz" | Secondary button | Navigates to comprehension quiz | Child |
| "Continue Exploring" | Primary button | Returns to library | Child |

### Weekly Challenge Celebration Screen
**Path:** `lib/screens/child/weekly_challenge_celebration_screen.dart`

| Copy | Context | Purpose | User Type |
|------|---------|---------|-----------|
| "Weekly Challenge Complete!" | Celebration title | Announces challenge completion | Child |
| "You read [X] books this week!" | Achievement message | States accomplishment | Child |
| "You're a reading superstar! Keep up the amazing work!" | Motivational message | Positive reinforcement | Child |
| "+[X] Bonus Points" | Points reward | Shows extra points earned | Child |
| "Keep Reading" | Primary button | Returns to home | Child |

### League Promotion Screen
**Path:** `lib/screens/child/league_promotion_screen.dart`

| Copy | Context | Purpose | User Type |
|------|---------|---------|-----------|
| "League Promoted!" | Promotion title | Announces advancement | Child |
| "Congratulations!" | Celebration heading | Positive reinforcement | Child |
| "You've been promoted to [League Name]!" | Promotion message | States new league | Child |
| "Keep reading to climb even higher!" | Motivational CTA | Encourages continued effort | Child |
| "Bronze League" | League name | Entry tier | Child |
| "Silver League" | League name | Second tier | Child |
| "Gold League" | League name | Third tier | Child |
| "Platinum League" | League name | Fourth tier | Child |
| "Diamond League" | League name | Top tier | Child |
| "Continue" | Primary button | Dismisses celebration | Child |

### Leaderboard Screen
**Path:** `lib/screens/child/leaderboard_screen.dart`

| Copy | Context | Purpose | User Type |
|------|---------|---------|-----------|
| "Leaderboard" | Screen title | Identifies rankings page | Child |
| "No rankings yet" | Empty state message | Shown when no users ranked | Child |
| "#[Rank]" | Rank number display | Shows position | Child |
| "[Username]" | User's display name | Player identity | Child |
| "[X] points" | Points display | Player's score | Child |
| "[X] books" | Books read count | Reading achievement | Child |
| "[X] day streak" | Streak display | Consecutive reading days | Child |
| "You" | Badge on current user's card | Highlights user's position | Child |
| "🥇" | First place emoji | Top rank indicator | Child |
| "🥈" | Second place emoji | Second rank indicator | Child |
| "🥉" | Third place emoji | Third rank indicator | Child |

### Profile Edit Screen
**Path:** `lib/screens/child/profile_edit_screen.dart`

| Copy | Context | Purpose | User Type |
|------|---------|---------|-----------|
| "Edit Profile" | Screen title | Indicates profile editing | Child |
| "Profile Picture" | Section label | Avatar selection area | Child |
| "Choose an emoji" | Avatar picker prompt | Explains avatar selection | Child |
| "Username" | Input field label | Username edit field | Child |
| "Email" | Input field label (read-only) | Email display | Child |
| "Date of Birth" | Input field label | DOB display/edit | Child |
| "Account Type" | Field label (read-only) | Shows child/parent type | Child |
| "Linked Parent" | Field label | Shows parent connection status | Child |
| "Link Parent Account" | Button (when not linked) | Initiates parent linking | Child |
| "Unlink Parent" | Button (when linked) | Removes parent connection | Child |
| "Save Changes" | Primary button | Saves profile updates | Child |
| "Cancel" | Secondary button | Discards changes | Child |
| "Profile updated successfully!" | Success SnackBar | Confirms save | Child |

### Parent Link QR Screen
**Path:** `lib/screens/child/parent_link_qr_screen.dart`

| Copy | Context | Purpose | User Type |
|------|---------|---------|-----------|
| "Link Parent Account" | Screen title | Explains linking feature | Child |
| "Show this QR code to your parent" | Instruction heading | Directs child to share QR | Child |
| "Your parent can scan this code to link their account and monitor your reading progress" | Explanation text | Clarifies purpose of linking | Child |
| "[Child's Name]" | Display name under QR | Shows which child is linking | Child |
| "Done" | Bottom button | Returns to settings | Child |

### Settings Screen
**Path:** `lib/screens/child/settings_screen.dart`

| Copy | Context | Purpose | User Type |
|------|---------|---------|-----------|
| "Settings" | Screen title | Identifies settings page | Child |
| "Account" | Section heading | Groups account settings | Child |
| "Edit Profile" | List tile title | Navigates to profile edit | Child |
| "Update your personal information" | List tile subtitle | Explains profile editing | Child |
| "Link Parent Account" | List tile title | Parent linking option | Child |
| "Allow parent to monitor your progress" | List tile subtitle | Explains parent oversight | Child |
| "Preferences" | Section heading | Groups preference settings | Child |
| "Notifications" | List tile title | Notification settings | Child |
| "Manage reading reminders and updates" | List tile subtitle | Explains notification control | Child |
| "Sound Effects" | List tile title | Audio toggle | Child |
| "Enable or disable sound feedback" | List tile subtitle | Explains sound setting | Child |
| "Support" | Section heading | Groups help options | Child |
| "Help & Support" | List tile title | Opens help screen | Child |
| "FAQs, tutorials, and contact support" | List tile subtitle | Describes help resources | Child |
| "Privacy Policy" | List tile title | Opens privacy document | Child |
| "Read our privacy policy" | List tile subtitle | Explains privacy link | Child |
| "About" | Section heading | Groups app info | Child |
| "Version [X.X.X]" | Version display | Shows app version | Child |
| "Logout" | List tile title (danger) | Signs out user | Child |
| "Sign out of your account" | List tile subtitle | Explains logout | Child |
| "Logout Confirmation" | Dialog title | Confirms logout intent | Child |
| "Are you sure you want to logout?" | Dialog message | Double-checks logout | Child |
| "Cancel" | Dialog button | Cancels logout | Child |
| "Logout" | Dialog confirm button | Proceeds with logout | Child |

### Help & Support Screen
**Path:** `lib/screens/child/help_support_screen.dart`

| Copy | Context | Purpose | User Type |
|------|---------|---------|-----------|
| "Help & Support" | Screen title | Identifies help page | Child |
| "Frequently Asked Questions" | Section heading | Introduces FAQ | Child |
| "How do I earn points?" | FAQ question | Points explanation | Child |
| "Finish reading books and maintain daily reading streaks! Check the Leaderboard to see your progress." | FAQ answer | Explains point system | Child |
| "What are badges?" | FAQ question | Achievement inquiry | Child |
| "Badges are special rewards you earn for completing challenges like finishing books or maintaining reading streaks." | FAQ answer | Explains badge system | Child |
| "How do I link my parent's account?" | FAQ question | Parent linking help | Child |
| "Go to Settings > Link Parent Account and show the QR code to your parent to scan." | FAQ answer | Linking instructions | Child |
| "Can I change my reading preferences?" | FAQ question | Preference help | Child |
| "Yes! Retake the personality quiz anytime to update your book recommendations." | FAQ answer | Explains preference updates | Child |
| "How does the leaderboard work?" | FAQ question | Ranking inquiry | Child |
| "Check the leaderboard to see how you rank with other readers. Compete with friends and earn badges!" | FAQ answer | Leaderboard explanation | Child |
| "Contact Support" | Section heading | Support contact area | Child |
| "Need more help?" | Support prompt | Encourages contact | Child |
| "Send us a message" | Email link text | Opens email client | Child |
| "support@readmeapp.com" | Support email address | Contact information | Child |

### Privacy Policy Screen
**Path:** `lib/screens/child/privacy_policy_screen.dart`

| Copy | Context | Purpose | User Type |
|------|---------|---------|-----------|
| "Privacy Policy" | Screen title | Identifies legal document | Both |
| "[Privacy Policy Content]" | Full legal text | GDPR/COPPA compliance | Both |

---

## Parent Experience

### Parent Home Screen
**Path:** `lib/screens/parent/parent_home_screen.dart`

| Copy | Context | Purpose | User Type |
|------|---------|---------|-----------|
| "Parent Dashboard" | Screen title | Identifies parent area | Parent |
| "My Children" | Section heading | Lists linked children | Parent |
| "Add Child" | Button text | Links new child account | Parent |
| "No children linked yet" | Empty state | Shown when no children connected | Parent |
| "Add a child account to start monitoring their reading progress" | Empty state description | Explains how to begin | Parent |
| "[Child Name]" | Child card display | Shows child's name | Parent |
| "[X] books read" | Child stat | Reading count | Parent |
| "[X] points" | Child stat | Achievement points | Parent |
| "View Details" | Child card button | Opens child dashboard | Parent |

### Parent Dashboard Screen
**Path:** `lib/screens/parent/parent_dashboard_screen.dart`

| Copy | Context | Purpose | User Type |
|------|---------|---------|-----------|
| "[Child Name]'s Dashboard" | Screen title | Shows which child's data | Parent |
| "Reading Statistics" | Section heading | Introduces stats | Parent |
| "Total Books Read" | Stat card label | Books completed | Parent |
| "[X]" | Stat value | Number of books | Parent |
| "Total Reading Time" | Stat card label | Time spent reading | Parent |
| "[X] hours" | Stat value | Total hours | Parent |
| "Achievement Points" | Stat card label | Gamification score | Parent |
| "[X]" | Stat value | Total points | Parent |
| "Current Streak" | Stat card label | Consecutive days | Parent |
| "[X] days" | Stat value | Streak count | Parent |
| "Recent Activity" | Section heading | Shows recent reads | Parent |
| "No recent activity" | Empty state | No recent reading | Parent |
| "Reading History" | Button text | Views full history | Parent |
| "Content Filters" | Button text | Manages content settings | Parent |
| "Set Goals" | Button text | Creates reading goals | Parent |
| "Unlink Child" | Danger button | Removes child connection | Parent |

### Reading History Screen
**Path:** `lib/screens/parent/reading_history_screen.dart`

| Copy | Context | Purpose | User Type |
|------|---------|---------|-----------|
| "Reading History" | Screen title | Identifies history view | Parent |
| "[Child Name]'s Reading History" | Subtitle | Shows which child | Parent |
| "All Time" | Filter option | Shows all history | Parent |
| "This Week" | Filter option | Last 7 days | Parent |
| "This Month" | Filter option | Current month | Parent |
| "No reading history yet" | Empty state | No books read | Parent |
| "[Book Title]" | History item title | Book read | Parent |
| "Completed on [Date]" | Timestamp | When finished | Parent |
| "Reading time: [X] minutes" | Duration stat | Time spent | Parent |
| "Quiz score: [X]%" | Quiz result | Comprehension score | Parent |
| "Points earned: [X]" | Points display | Rewards earned | Parent |

### Content Filter Screen
**Path:** `lib/screens/parent/content_filter_screen.dart`

| Copy | Context | Purpose | User Type |
|------|---------|---------|-----------|
| "Content Filters" | Screen title | Identifies filter settings | Parent |
| "[Child Name]'s Content Filters" | Subtitle | Shows which child's filters | Parent |
| "Age-Appropriate Content" | Section heading | Age filtering controls | Parent |
| "Maximum Age Rating" | Setting label | Age limit control | Parent |
| "[X]+" | Age value selector | Selected age rating | Parent |
| "Only show books appropriate for this age and below" | Explanation text | Clarifies age filtering | Parent |
| "Content Themes" | Section heading | Theme filtering | Parent |
| "Block specific themes or topics" | Explanation | Purpose of theme filters | Parent |
| "Violence" | Theme toggle | Content category | Parent |
| "Scary Content" | Theme toggle | Content category | Parent |
| "Mature Themes" | Theme toggle | Content category | Parent |
| "Reading Level" | Section heading | Difficulty filtering | Parent |
| "Maximum Reading Level" | Setting label | Difficulty cap | Parent |
| "Beginner" / "Intermediate" / "Advanced" | Level options | Difficulty settings | Parent |
| "Save Changes" | Primary button | Applies filters | Parent |
| "Cancel" | Secondary button | Discards changes | Parent |
| "Filters updated successfully!" | Success SnackBar | Confirms save | Parent |

### Set Goals Screen
**Path:** `lib/screens/parent/set_goals_screen.dart`

| Copy | Context | Purpose | User Type |
|------|---------|---------|-----------|
| "Set Reading Goals" | Screen title | Goal creation page | Parent |
| "[Child Name]'s Goals" | Subtitle | Shows which child | Parent |
| "Daily Reading Goal" | Section heading | Daily target | Parent |
| "Minutes per day" | Input label | Daily time goal | Parent |
| "[X] minutes" | Input field | Entered value | Parent |
| "Weekly Reading Goal" | Section heading | Weekly target | Parent |
| "Books per week" | Input label | Weekly book goal | Parent |
| "[X] books" | Input field | Entered value | Parent |
| "Monthly Reading Goal" | Section heading | Monthly target | Parent |
| "Books per month" | Input label | Monthly book goal | Parent |
| "[X] books" | Input field | Entered value | Parent |
| "Goal Reminders" | Section heading | Notification settings | Parent |
| "Send reminders to [Child Name]" | Toggle label | Enables goal notifications | Parent |
| "Reminder Time" | Time picker label | When to send reminders | Parent |
| "Save Goals" | Primary button | Saves goal settings | Parent |
| "Cancel" | Secondary button | Discards changes | Parent |
| "Goals updated successfully!" | Success SnackBar | Confirms save | Parent |

### Add Child Screen
**Path:** `lib/screens/parent/add_child_screen.dart`

| Copy | Context | Purpose | User Type |
|------|---------|---------|-----------|
| "Add Child Account" | Screen title | Child linking page | Parent |
| "Scan QR Code" | Method heading | QR scanning option | Parent |
| "Open the ReadMe app on your child's device and navigate to Settings > Link Parent Account" | Instruction 1 | Directs parent | Parent |
| "Scan the QR code displayed on their screen" | Instruction 2 | Explains QR process | Parent |
| "Scan QR Code" | Button text | Opens camera scanner | Parent |
| "Or Enter Code Manually" | Alternative heading | Manual entry option | Parent |
| "Enter the 6-digit code" | Input label | Manual code entry | Parent |
| "[_ _ _ _ _ _]" | Code input field | 6-digit code | Parent |
| "Link Account" | Primary button | Confirms linking | Parent |
| "Cancel" | Secondary button | Aborts linking | Parent |
| "Child account linked successfully!" | Success SnackBar | Confirms connection | Parent |
| "Invalid code" | Error message | Failed linking | Parent |

### QR Scanner Widget
**Path:** `lib/screens/parent/qr_scanner_widget.dart`

| Copy | Context | Purpose | User Type |
|------|---------|---------|-----------|
| "Scan QR Code" | Scanner screen title | Identifies scanning view | Parent |
| "Position the QR code within the frame" | Instruction overlay | Guides positioning | Parent |
| "Cancel" | Bottom button | Closes scanner | Parent |
| "QR code scanned successfully!" | Success message | Confirms scan | Parent |
| "Invalid QR code" | Error message | Failed scan | Parent |

---

## Shared Components & Widgets

### App Bottom Navigation
**Path:** `lib/widgets/app_bottom_nav.dart`

| Copy | Context | Purpose | User Type |
|------|---------|---------|-----------|
| "Home" | Nav tab label | Home screen | Child |
| "Library" | Nav tab label | Library screen | Child |
| "Leaderboard" | Nav tab label | Leaderboard screen | Child |
| "Settings" | Nav tab label | Settings screen | Child |

### App Buttons
**Path:** `lib/widgets/app_button.dart`

| Copy | Context | Purpose | User Type |
|------|---------|---------|-----------|
| "[Dynamic Button Text]" | Primary/Secondary/Compact buttons | Button labels throughout app | Both |

### Progress Button
**Path:** `lib/widgets/common/progress_button.dart`

| Copy | Context | Purpose | User Type |
|------|---------|---------|-----------|
| "Start" | Book not started | Begin reading | Child |
| "Continue" | Book in progress | Resume | Child |
| "Re-read" | Book completed | Read again | Child |

### Book Card
**Path:** `lib/widgets/book_card.dart`

| Copy | Context | Purpose | User Type |
|------|---------|---------|-----------|
| "[Book Title]" | Card title | Book name display | Child |
| "by [Author]" | Card subtitle | Author attribution | Child |
| "[X] min read" | Duration badge | Reading time | Child |
| "[Age Rating]" | Age badge | Content rating | Child |

### Empty States
**Various screens**

| Copy | Context | Purpose | User Type |
|------|---------|---------|-----------|
| "No [items] yet" | Generic empty state | Item absence | Both |
| "Get Started" / "Browse [Section]" | Empty state CTA | Directs user to action | Both |

### Loading States
**Various screens**

| Copy | Context | Purpose | User Type |
|------|---------|---------|-----------|
| "Loading..." | Generic loading | Data fetching | Both |

### Error Messages
**Various screens**

| Copy | Context | Purpose | User Type |
|------|---------|---------|-----------|
| "Error loading [resource]" | Generic error | Loading failure | Both |
| "Something went wrong. Please try again." | Generic error | Retry prompt | Both |
| "Network error. Check your connection." | Network error | Connection issue | Both |

### Success Messages (SnackBars)
**Various actions**

| Copy | Context | Purpose | User Type |
|------|---------|---------|-----------|
| "[Action] successful!" | Generic success | Action confirmation | Both |
| "Welcome back!" | Login success | Greeting | Both |
| "Account created successfully!" | Registration success | Account confirmation | Both |
| "Profile updated successfully!" | Profile save | Update confirmation | Child |
| "Filters updated successfully!" | Content filter save | Filter confirmation | Parent |
| "Goals updated successfully!" | Goal save | Goal confirmation | Parent |
| "Child account linked successfully!" | Parent linking | Link confirmation | Parent |

---

## Achievements & Badges

### Achievement Types
**Path:** `lib/services/achievement_service.dart`

| Copy | Context | Purpose | User Type |
|------|---------|---------|-----------|
| "First Book" | Achievement name | Completed first book | Child |
| "Read your first book!" | Achievement description | Milestone description | Child |
| "5 Books Champion" | Achievement name | Read 5 books | Child |
| "Complete 5 books" | Achievement description | Goal description | Child |
| "10 Books Master" | Achievement name | Read 10 books | Child |
| "Complete 10 books" | Achievement description | Goal description | Child |
| "Quiz Master" | Achievement name | Complete 5 quizzes | Child |
| "Complete 5 book quizzes" | Achievement description | Goal description | Child |
| "Perfect Score" | Achievement name | 100% on quiz | Child |
| "Get a perfect score on any quiz" | Achievement description | Goal description | Child |
| "Week Warrior" | Achievement name | 7-day streak | Child |
| "Read for 7 days in a row" | Achievement description | Streak goal | Child |
| "Month Master" | Achievement name | 30-day streak | Child |
| "Read for 30 days in a row" | Achievement description | Streak goal | Child |
| "Speed Reader" | Achievement name | Fast reading | Child |
| "Complete a book in under 10 minutes" | Achievement description | Speed goal | Child |
| "Book Collector" | Achievement name | Favorite 10 books | Child |
| "Add 10 books to favorites" | Achievement description | Collection goal | Child |

---

## Notifications

### Push Notification Messages
**Path:** `lib/services/notification_service.dart`

| Copy | Context | Purpose | User Type |
|------|---------|---------|-----------|
| "Time to read!" | Daily reminder title | Reading reminder | Child |
| "Your daily reading adventure awaits!" | Daily reminder body | Motivational reminder | Child |
| "New books added!" | New content notification title | Content update | Child |
| "Check out the latest additions to the library" | New content notification body | Library update | Child |
| "Goal reminder" | Goal notification title | Parent-set goal reminder | Child |
| "You're [X] books away from your weekly goal!" | Goal notification body | Progress toward goal | Child |
| "Streak reminder" | Streak notification title | Streak maintenance | Child |
| "Don't break your [X]-day streak! Read today!" | Streak notification body | Streak preservation | Child |
| "Achievement unlocked!" | Achievement notification title | Badge earned | Child |
| "You earned the [Badge Name] badge!" | Achievement notification body | Badge announcement | Child |
| "Weekly challenge available" | Challenge notification title | New challenge | Child |
| "A new weekly reading challenge has started!" | Challenge notification body | Challenge announcement | Child |

---

## Analytics & Tracking

### Activity Logging
**Path:** `lib/services/analytics_service.dart`

| Copy | Context | Purpose | User Type |
|------|---------|---------|-----------|
| "book_started" | Event name | Book reading initiated | Child |
| "book_completed" | Event name | Book finished | Child |
| "quiz_completed" | Event name | Quiz finished | Child |
| "achievement_unlocked" | Event name | Badge earned | Child |
| "daily_login" | Event name | User logged in | Child |
| "book_favorited" | Event name | Book added to favorites | Child |
| "content_filter_applied" | Event name | Parent filter set | Parent |
| "goal_set" | Event name | Parent goal created | Parent |
| "child_linked" | Event name | Parent-child link | Parent |

---

## Usage Notes for Chatbot Copywriting

### Tone & Voice Guidelines

**For Children:**
- Use encouraging, positive, celebratory language
- Maintain age-appropriate vocabulary (6-12 years old)
- Emphasize fun, adventure, achievement, and growth
- Use exclamation marks sparingly but strategically for excitement
- Avoid condescension - respect the child's intelligence
- Use "you" to create personal connection
- Celebrate small wins and progress

**For Parents:**
- Professional but warm and supportive
- Focus on oversight, safety, and educational value
- Emphasize ease of use and actionable insights
- Clear, direct language without jargon
- Balance between control and encouragement

### Key UX Principles

1. **Progress Visibility:** Always show users where they are, how far they've come, and what's next
2. **Positive Reinforcement:** Celebrate achievements, no matter how small
3. **Clear Actions:** Every button and CTA should clearly state what will happen
4. **Gentle Guidance:** Empty states and errors should guide users toward resolution
5. **Age Appropriateness:** All child-facing copy should be readable and understandable by the target age group (6-12)
6. **Motivation Over Pressure:** Goals and challenges should inspire, not stress

### Contextual Considerations

- **First-time Users:** Need more explanation and hand-holding (onboarding, quiz intro)
- **Returning Users:** Want quick access and progress updates (home screen stats, continue reading)
- **Achievement Moments:** Deserve celebration and reinforcement (completion screens, badges)
- **Empty States:** Opportunities to guide and encourage action (library tabs, history)
- **Errors:** Should be helpful and point toward solutions, never blame the user
- **Parent Controls:** Should feel empowering, not restrictive

---

## Copy Gaps & Opportunities

### Areas Needing Enhancement:

1. **Error Messages:** Many screens use generic errors - opportunity for more specific, helpful messaging
2. **Empty State Variety:** Some empty states could be more engaging with illustrations or tips
3. **Loading States:** Opportunity for encouraging micro-copy during waits
4. **Tutorial Tooltips:** First-time feature introductions could use inline tips
5. **Achievement Descriptions:** Could be more colorful and exciting
6. **Quiz Feedback:** Individual question feedback could enhance learning
7. **Parent Communication:** In-app messaging between parent and child could be added
8. **Reading Milestones:** More granular celebrations (25%, 50%, 75% book completion)

---

**Total Screens Documented:** 43+
**Total Copy Items:** 350+
**Last Updated:** January 14, 2026
