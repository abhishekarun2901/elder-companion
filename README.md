# 🤖 Mitra – LLM Based Elderly Companion Bot

Mitra is a cross-platform, AI-powered companion application designed to support and engage elderly users through natural language conversations. Built using Large Language Models (LLMs) and modern application frameworks, Mitra aims to provide companionship, assistance, and emotional support in a simple and accessible way.

---

## 📌 Overview

As people age, loneliness and lack of engagement can significantly impact mental and emotional well-being. **Mitra** addresses this challenge by acting as a friendly digital companion that can:

- Hold natural conversations
- Provide companionship and engagement
- Assist with simple queries and reminders
- Run across multiple platforms (mobile, desktop, and web)

---

## ✨ Features

- 💬 **LLM-Powered Conversations**  
  Natural and context-aware dialogue using large language models.

- 👵 **Elderly-Friendly Design**  
  Focus on simplicity, clarity, and accessibility.

- 🌐 **Cross-Platform Support**  
  - Android  
  - iOS  
  - Web  
  - Windows  
  - macOS  

- ☁️ **Firebase Backend**  
  Uses Firebase for backend services such as authentication, database, and cloud functions.

- 🧩 **Modular Architecture**  
  Clean separation of frontend, backend functions, and shared logic.

---

## 🏗️ Project Structure
```text
mitra/
├── android/                # Android platform code
├── ios/                    # iOS platform code
├── web/                    # Web application
├── windows/                # Windows desktop support
├── macos/                  # macOS desktop support
├── lib/                    # Shared application logic
├── functions/              # Firebase cloud functions
├── test/                   # Test cases
├── firebase.json           # Firebase configuration
├── firestore.rules         # Firestore security rules
├── firestore.indexes.json  # Firestore indexes
├── pubspec.yaml            # Project dependencies
└── README.md               # Project documentation
```

## 🚀 Getting Started

### Prerequisites

Ensure you have the following installed:

- Flutter SDK
- Dart
- Firebase CLI
- Android Studio / Xcode (for mobile builds)
- Node.js (for Firebase Functions)


### 🔧 Installation

1. **Clone the repository**
   ```bash
   git clone https://github.com/abhishekarun2901/mitra.git
   cd mitra
   ```

2. **Install dependencies**

   ```bash
   flutter pub get
   ```

3. **Configure Firebase**

   * Create a Firebase project
   * Update `firebase.json` and Firestore rules if required
   * Deploy Firebase functions:

     ```bash
     firebase deploy
     ```

4. **Run the application**

   ```bash
   flutter run
   ```

---

## 🧪 Testing

Run tests using:

```bash
flutter test
```

---

## 🔐 Security

* Firestore security rules are defined in `firestore.rules`
* Database indexes are managed via `firestore.indexes.json`
* Review and update rules before deploying to production

---

## 🛣️ Roadmap

* Voice-based interaction
* Reminder and alert system
* Emotion-aware conversation responses
* Healthcare and wellness integrations
* Multi-language support

---

## 🤝 Contributing

Contributions are welcome!

1. Fork the repository
2. Create a new feature branch
3. Commit your changes
4. Open a pull request

Please ensure code quality and add tests where applicable.

---

## 📄 License

This project is licensed under the **MIT License**.
See the `LICENSE` file for more information.

---

## ❤️ Acknowledgements

* Flutter & Dart Community
* Firebase
* Open-source LLM research and tools


