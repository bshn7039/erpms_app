# ERPMS (Emergency Response & Professional Management System) - Project Documentation

## 1. Project Overview
ERPMS is a high-performance emergency response platform built with **Flutter** and **Firebase**. It serves as a digital bridge between individuals in crisis and a network of professional responders, volunteers, and automated AI assistance. The system handles real-time location tracking, critical alert broadcasting, and intelligent emergency guidance.

---

## 2. Detailed Page Architecture & Functionality

### **Core User Interface (Auth & General)**
- **Splash Screen (`splash_screen.dart`)**: The initial entry point that handles app branding, typewriter animations, and proactive location initialization to detect the user's district.
- **Login/Signup (`login_screen.dart`, `signup_screen.dart`)**: Secure authentication gateway with email verification. Features password reset functionality and a verification flow that prevents unverified logins.
- **Home Screen (`home_screen.dart`)**: The central hub featuring a real-time public alert ticker, an interactive map preview, and a categorized feature grid. It includes a "Safety Check" mechanism that disables critical features if the user's mobile number is not verified.
- **App Shell (`app_shell.dart`)**: A sophisticated UI wrapper that provides consistent navigation via a Bottom Navigation Bar, a Navigation Drawer, and floating action buttons for SOS and AI Chat.
- **Profile & Edit Profile (`profile_screen.dart`, `edit_profile_screen.dart`)**: Comprehensive user profile management, including medical ID (blood group, allergies), emergency contact syncing, and live SOS tracking toggles.

### **Response & Incident Management**
- **SOS Logic (`sos_page.dart`)**: A high-priority module that triggers a private emergency incident, initiates high-accuracy location streaming, and allows the victim to "Publicize" the alert to nearby district volunteers.
- **Active Assistance Page (`active_assistance_page.dart`)**: A real-time coordination dashboard for engaged incidents. 
  - **Live Map Tracker**: Synchronous tracking of both victim and responder positions on Google Maps.
  - **Proximity Logic**: Uses Haversine calculations to display the responder's distance in kilometers.
  - **Incident Chat**: A dedicated, firestore-backed real-time messaging channel for tactical coordination.
- **Alerts Feed (`alerts_page.dart`)**: A sophisticated filtering system that allows users to toggle between "Near Me" (District-based) and "All India" alerts, with specialized visibility rules for public, personal, and SOS types.
- **Map Screen (`map_screen.dart`)**: An interactive geospatial interface showing active incidents, NGO resources, and responder positions with custom color-coded markers.

### **Emergency Broadcast Modules**
- **Medical Help (`medical_page.dart`)**: A specialized interface for medical emergencies (Cardiac, Trauma, etc.) allowing users to broadcast a "Medical SOS" to the volunteer network along with site photos and status tags (Unconscious, No Pulse).
- **Fire Safety (`fire_safety_page.dart`)**: Parallel to medical help, but focused on fire scenarios (Residential, Electrical, Chemical). Includes one-tap calls to 101/112 and site-specific alert broadcasting.

### **Public Information & Resources**
- **Public Reports (`reports_page.dart`)**: A news-style feed for Weather, Environment (AQI), and Welfare advisories sourced from official agencies. Includes an integrated "AQI Meter" that parses text to show visual health indicators.
- **Emergency Guide (`emergency_guide_page.dart`)**: A searchable, AI-powered emergency manual that provides extremely concise, life-saving instructions (First-aid, CPR, etc.) using Markdown formatting.
- **Community Hub (`community_page.dart`)**: Displays the collective impact metrics (Users, Volunteers, Handled Queries) and verifies "Community Stories" of successful rescues.
- **Join Us (`join_us_page.dart`)**: A multi-step volunteer application portal that collects identity proof (Aadhaar/License) and skill certifications via camera/gallery.

---

## 3. Core Logic & Technical Implementation

### **Geospatial & Location Logic (`location_helper.dart`)**
- **District Detection**: Uses reverse geocoding to identify the user's administrative district, which serves as the primary key for regional alert filtering.
- **Location Streaming**: Implements `geolocator` with a `10m` distance filter to balance tracking accuracy with battery efficiency during active emergencies.
- **Haversine Distance**: A custom mathematical implementation used to calculate direct paths between users and responders.

### **Advanced Image Processing**
- **Storage Strategy**: To maintain a lightweight footprint, ID proofs and certificates are captured via `image_picker`, compressed using `flutter_image_compress`, and stored as **Base64 strings** directly within Firestore. This avoids the complexity of cloud storage buckets while enabling instant cross-platform synchronization.

### **FCM & Notification Architecture**
- **Topic-based Broadcasting**: The app automatically subscribes users to a district-specific topic (e.g., `Mumbai`, `Navi_Mumbai`). When an emergency is publicized, an FCM is sent to that specific topic, ensuring only nearby volunteers are alerted.
- **Foreground Handling**: Integrated listeners in `main.dart` handle incoming data payloads even while the app is active.

---

## 4. Integrated AI Architecture

### **Google Gemini 1.5/2.0 Integration**
- **Persona-Driven AI**: Configured as the "ERPMS Lead Coordinator"—a calm, decisive engine optimized for Indian emergency infrastructure (108, 112).
- **Mode 1: Stateful Chat**: Context-aware history managed via local SQLite (`DBHelper`) and Firestore. Used for tactical coordination and ongoing consultations.
- **Mode 2: Stateless Manual**: Used in the **Emergency Aid Guide**. Employs zero-persistence `generateContent` for high-speed, volatile manual lookups to ensure immediate instruction delivery without data overhead.
- **Safety & Constraints**: Strict blockage of harmful content; mandatory escalation to authorities (SOS/108) for life-threatening queries.

---

## 5. Security & Development Workflow

### **Infrastructure & Database**
- **Firestore**: Real-time synchronization of users, incidents, alerts, and reports.
- **SQLite**: Local persistence for AI chat history to ensure offline accessibility of survival advice.
- **Authentication**: Mandatory **Firebase Phone Auth (OTP)** for critical features, creating a high-trust volunteer network.

### **Development Lifecycle (Latest Phase)**
- **Phase 7: Life-Safety Ecosystem**: Focused on 12-category triage grids for Fire/Medical, direct dial-button integration, and Base64 media injection for zero-latency sync.
- **Linter & Analysis**: Configured via `analysis_options.yaml` utilizing `package:flutter_lints` for standardized code quality and performance monitoring.
- **Environment Management**: Secure credential handling via `.env` files for Gemini and Firebase API keys.

### **Access Control**
- **Protected Routes**: A custom `ProtectedRoute` wrapper in `main.dart` guards sensitive features, checking the `FirebaseAuth` stream before allowing page entry.
- **Admin Hub**: Restricted to users with the `admin` role, allowing for nationwide incident monitoring and volunteer verification.
