🛠️ Home Services Application
The Home Services App is a role-based mobile application built using Flutter and Firebase, allowing users to book, manage, and provide home-related services (like cleaning, plumbing, and repairs). It offers dedicated dashboards for Customers, Professionals, and Admins.

Developed as a final project in May–June 2025, this app demonstrates advanced Flutter concepts, Firestore integration, state management, and real-time data updates.

📱 Key Features
👨‍🔧 Professional Dashboard
Create/edit service listings with subcategories (e.g., Electrician → Fan Repair)

View and manage assigned orders

View reviews, badge status, and profile info

Apply for a verified badge

Receive notifications for order updates and badge approval

👩‍💼 Customer Dashboard
Browse services by category (e.g., Cleaning, Plumbing)

View professionals offering each service

Book a service with date, time, and notes

Track order status (Pending, Accepted, Completed)

View booking history and leave reviews/ratings

🛡️ Admin Dashboard
View all users, orders, and reported accounts

Manage badge approval requests from professionals

View visual insights and charts (growth stats, order statuses)

Send admin-side notifications

🔧 Tech Stack
Frontend: Flutter (Dart)

Database: Firebase Firestore

Auth: Firebase Authentication (Email/Password)

Media: Firebase Storage for image uploads

Notifications: Firebase Cloud Messaging (FCM)

State Management: Provider

📁 Project Structure (Simplified)
bash
Copy
Edit
lib/
├── main.dart
├── models/                 # Data models (User, Order, Service)
├── pages/
│   ├── customer/           # Customer views
│   ├── professional/       # Professional views
│   ├── admin/              # Admin views
│   └── auth/               # Login/Signup/Onboarding
├── services/               # Firebase CRUD functions
├── providers/              # App-wide state management
├── utils/                  # Constants, helpers
└── widgets/                # Shared custom UI components
🛠️ How to Run the Project
1. Clone the repository
bash
Copy
Edit
git clone https://github.com/your-username/homifix-app.git
cd home-services-app
2. Install dependencies
bash
Copy
Edit
flutter pub get
3. Set up Firebase
Connect your Flutter project to Firebase (Android/iOS)

Add the google-services.json (for Android) or GoogleService-Info.plist (for iOS)

Enable:

Firestore Database

Firebase Authentication

Firebase Storage

Firebase Cloud Messaging (optional)

4. Run the app
bash
Copy
Edit
flutter run
📊 Admin Analytics
Admin dashboard shows real-time charts and tables using Firestore data:

📈 Total users by role

📋 Orders by status (pending, accepted, completed)

🚩 List of reported users

✅ Pending badge requests

🔒 Authentication & Security
Role-based login (Customer, Professional, Admin)

Protected access using Firebase Auth and Firestore rules

✅ Completed Features Checklist
 Role-based dashboards (Customer, Professional, Admin)

 Category-wise service system

 Firebase Firestore + Storage integration

 Badge request & approval flow

 Notifications using FCM

 Reporting and insights for admin

 Local state management using Provider

👨‍💻 Developed By
Maryam Munawar
kiran Shehzadi
Momna Ahmed
📚 Project Info
Platform: Flutter (Mobile App)

Timeline: May – June 2025

Course/Context: Personal/Academic Project
