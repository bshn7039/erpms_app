# ERPMS: Emergency Response & Professional Management System

### 🏥 Project Overview
ERPMS is a high-trust **Life-Safety System** designed to bridge the gap between emergency incidents and coordinated response. In critical situations, every second counts. This app provides verified communication channels between citizens, emergency contacts, and professional volunteers.

### 🎯 Core Features

#### 🚨 SOS & Active Assistance
*   **Two-Stage SOS:** Immediate private alert to emergency contacts, followed by an optional "Publicize" broadcast to nearby volunteers.
*   **Live Tracking:** Real-time GPS streaming (10m accuracy) between victim and responder on a synchronized map.
*   **Assistance Hub:** A centralized command center for all active and past emergency chat sessions.
*   **Standardized Triage:** 8 core categories (Medical, Physical, Fire, Rescue, Logistics, Tech, Flood, General) mapping to local authority hotlines.

#### 📖 AI-Powered Emergency Aid Guide
*   **On-Demand Manual:** A stateless, high-speed search engine powered by Gemini 1.5 Flash.
*   **"Search & Forget" Architecture:** Zero data persistence for maximum privacy and zero cost. No data is stored in Firestore or local databases.
*   **Medical Triage Tone:** Delivers concise, life-saving instructions (Critical Actions, Step-by-Step, Red Flags) in Markdown format.
*   **Localized Protocols:** Specifically optimized for Indian emergency numbers (108 Ambulance, 102 Maternity, 101 Fire).

#### 📊 Real-Time India Reports
*   **Local & National Feed:** News-style dashboard pulling live updates from IMD, CPCB, and NITI Aayog.
*   **District-Level Filtering:** Automatic local filtering using reverse-geocoding to show relevant reports for the user's specific region.
*   **Smart AQI Meter:** Automatic extraction and visualization of Air Quality Index from environmental reports.

#### 🛡️ Verified Security
*   **OTP Verification:** Mandatory mobile number connection via Firebase Phone Auth before accessing emergency or volunteer features.
*   **Privacy Guard:** Strict visibility rules ensuring personal SOS data remains private unless explicitly publicized.
*   **Owner Deletion:** Users have full control to delete their emergency records and connected alerts instantly.

#### 🤝 Community & Volunteering
*   **Volunteer Genre Matching:** Responders only see personal alerts that match their specific skills (e.g., Medical volunteers see Medical alerts).
*   **Impact Metrics:** Real-time tracking of "Queries Handled" based on successfully resolved incidents.

### 🛠️ Tech Stack
*   **Framework:** Flutter (Dart)
*   **Backend:** Firebase (Firestore, Authentication)
*   **AI Engine:** Gemini 1.5 Flash (via Google AI SDK)
*   **UI Rendering:** Flutter Markdown (for AI guides)
*   **Location:** Geolocator & Geocoding (Reverse-lookup)
*   **Security:** Firebase Phone Auth (OTP)
