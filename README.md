# DocVartaa 🩺📱

**DocVartaa** is a comprehensive telemedicine application built with **Flutter** and **Firebase**. It bridges the gap between patients and doctors by providing a seamless platform for booking appointments, secure video consultations, and integrated wallet management.

---

## 🌟 Key Features

### 👤 For Patients

* **Doctor Discovery:** Search and filter doctors by specialization.
* **Appointment Booking:** View doctor schedules and book available time slots.
* **Secure Payments:** Integrated **Wallet System** for managing funds and paying for consultations.
* **Video Consultations:** High-quality, secure video calls with doctors using **ZegoCloud/Agora**.
* **Appointment History:** Track upcoming and past appointments.

### 👨‍⚕️ For Doctors

* **Profile Management:** Manage professional details, consultation fees, and availability.
* **Slot Management:** Create and manage appointment slots.
* **Dashboard:** View upcoming appointments and patient details.
* **Wallet & Earnings:** Track earnings and manage withdrawals.
* **KYC Verification:** Secure verification process for doctor onboarding.

### 🔐 Core Features

* **Role-Based Authentication:** Secure login/signup flow separating Doctors and Patients.
* **In-App Wallet:** Rechargeable wallet system integrated with **Razorpay** for seamless transactions.
* **Real-time Database:** Powered by **Cloud Firestore** for instant updates on bookings and calls.
* **Secure Environment:** Sensitive API keys managed via `flutter_dotenv`.

---

## 🛠️ Tech Stack

* **Frontend:** [Flutter](https://flutter.dev/) (Dart)
* **Backend:** [Firebase](https://firebase.google.com/) (Auth, Firestore, Storage)
* **State Management:** Provider
* **Video Calls:** ZegoCloud / Agora RTC
* **Payments:** Razorpay Integration

---

## 📂 Project Structure

The project follows a clean, feature-based architecture for scalability.

```text
lib/
├── config/             # App themes, routes, and provider configurations
├── core/               # Core services (Auth, API, Utilities)
│   ├── models/         # Data models (User, Doctor, Appointment, Transaction)
│   ├── services/       # Services (Auth, Wallet, Firestore, CallService)
│   └── providers/      # State providers
├── features/           # Feature-specific modules
├── screens/            # UI Screens
│   ├── auth/           # Login, Signup, Forgot Password
│   ├── doctor/         # Doctor Dashboard, Profile, Schedule, Wallet
│   ├── patient/        # Patient Home, Search, Slots, Appointments
│   └── common/         # Shared screens (Video Call, Wallet, KYC)
├── widgets/            # Reusable UI components (Buttons, Cards, Dialogs)
├── main.dart           # Application entry point
└── firebase_options.dart # Firebase configuration

```

---

## 🚀 Getting Started

Follow these steps to set up the project locally.

### Prerequisites

* [Flutter SDK](https://docs.flutter.dev/get-started/install) (Latest Stable)
* [Android Studio](https://developer.android.com/studio) or VS Code
* A Firebase Project
* Razorpay Merchant Account (for payments)
* ZegoCloud/Agora Account (for video calls)

### Installation

1. **Clone the repository:**
```bash
git clone https://github.com/thekartikeyamishra/docvarta-3012205-.git
cd docvartaa

```


2. **Install dependencies:**
```bash
flutter pub get

```


3. **Environment Setup:**
Create a `.env` file in the root directory (add this to `.gitignore`) and populate it with your keys:
```properties
# .env
ZEGO_APP_ID=your_zego_app_id
ZEGO_APP_SIGN=your_zego_app_sign
AGORA_APP_ID=your_agora_app_id
RAZORPAY_KEY_ID=your_razorpay_key_id

```


4. **Firebase Setup:**
* Configure your Firebase project using `flutterfire configure`.
* Ensure Firestore and Authentication (Email/Password) are enabled.


5. **Run the App:**
```bash
flutter run

```



---

## ⚙️ Configuration Details

### Permissions

This app requires the following permissions (configured in `AndroidManifest.xml`):

* `INTERNET`: For API and Database access.
* `CAMERA` & `RECORD_AUDIO`: For Video Consultations.
* `ACCESS_NETWORK_STATE` & `WIFI_STATE`: For connectivity checks.
* `BLUETOOTH_CONNECT`: For audio device management during calls.

### Payments

The app uses a **Razorpay** integration. Ensure your `.env` contains a valid `RAZORPAY_KEY_ID`.

* **Test Mode:** Use `rzp_test_...` keys during development.
* **Live Mode:** Use `rzp_live_...` keys for production builds.

---

## 🤝 Contributing

Contributions are welcome! Please follow these steps:

1. Fork the repository.
2. Create a feature branch (`git checkout -b feature/AmazingFeature`).
3. Commit your changes (`git commit -m 'Add some AmazingFeature'`).
4. Push to the branch (`git push origin feature/AmazingFeature`).
5. Open a Pull Request.

---

## 📄 License

Distributed under the MIT License. See `LICENSE` for more information.

---

<p align="center">
Built with ❤️ for better healthcare access.
</p>
