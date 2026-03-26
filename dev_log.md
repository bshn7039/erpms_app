# ERPMS Development Journey & System Architecture

### ✅ Phase 7: Life-Safety "One-Tap" Ecosystem (Latest)
*   **Specialized Medical & Fire Triage:** Developed dedicated, high-reliability emergency interfaces.
    *   **Direct Emergency Dialing:** Integrated massive dial-buttons for 108 (Ambulance), 101 (Fire), and 112 (All-in-One).
    *   **12-Category Grid Logic:** Created scenario-specific icon grids for Medical (Cardiac, Trauma, etc.) and Fire (Electrical, Chemical, Residential, etc.) to ensure responders receive accurate situational data.
    *   **Dynamic Triage Tags:** Implemented multi-select chips for instant status reporting (e.g., "People Trapped," "Unconscious," "Gas Leak").
*   **Media-Rich Alerts:**
    *   **Base64 Image Injection:** Integrated camera capture that compresses and converts photos to Base64 strings for direct storage in Firestore (zero-latency media sync without external buckets).
    *   **Detailed Address Logic:** Added a dedicated field for specific location notes (e.g., "Block B, Room 302") stored separately from description.
*   **UI/UX Optimization:**
    *   **Home Screen Reordering:** Prioritized life-saving tools (Emergency Guide, Medical, Fire) in the main feature grid for faster access during stress.
    *   **Enhanced Detail View:** Alert details now render attached Base64 images and highlight detailed addresses in a prioritized UI box.
*   **Model Expansion:** Updated `AlertModel` to support `detailedAddress` and `imageBase64` fields across the entire ecosystem.

### ✅ Phase 6: Life-Safety Core & SOS
*   **Two-Stage SOS Protocol:** Implemented a secure SOS system.
    *   **Private Mode:** Initial SOS is private to emergency contacts and visible only in the Assistant Hub.
    *   **Publicize Action:** Victim can choose to broadcast the SOS to the global volunteer network.
*   **Live Location Streaming:** Integrated `Geolocator` stream to update `incidents` and `alerts` collections in real-time (10m filters).
*   **Assistant Hub:** Built a multi-session command center for tracking all active and past emergencies, sorted by latest activity.
*   **Standardized Triage:** Unified emergency categories across SOS and Manual Alerts (Medical, Physical, Fire, etc.).

### ✅ Phase 5: Verified Security & Connectivity
*   **Firebase OTP Integration:** Replaced text-based phone input with mandatory **Firebase Phone Authentication**.
*   **Account-Phone Binding:** Implemented strict rules where one verified number links to one account.
*   **Access Guard:** Developed a global feature-lock system that disables emergency/volunteer functions until phone verification is complete.
*   **Privacy Controls:** Implemented owner-only deletion for incidents and connected alerts to ensure victim privacy.

### ✅ Phase 4: India-Specific Intelligence (Reports)
*   **Real-Time Reports Dashboard:** Integrated live feeds for India (IMD, CPCB, NITI Aayog).
*   **Dynamic AQI Meter:** Built an extraction engine to visualize Air Quality Index from raw report text.
*   **Regional Filtering:** Implemented a "Local Only" toggle using reverse-geocoding to filter national reports by the user's district.
*   **Pull-to-Refresh:** Added manual sync capability for cached reports.

### ✅ Phase 3: Global Alert & Map Ecosystem
*   **Firestore Alert Sync:** Real-time listeners for district-based alerts.
*   **Verified Volunteer Matching:** Alerts are filtered so only volunteers with relevant genres (e.g., Medical) can engage with personal requests.
*   **AppShell Navigation:** Unified bottom-nav and sidebar drawer for consistent access.

---

# Implementation Specifications

### 🚨 Alert Visibility Rules
| Alert Type | Visibility | Engagement |
| :--- | :--- | :--- |
| **Public Alert** | Everyone (Global/Nearby) | Info Only (No Engagement) |
| **Personal (Medical/Fire/Manual)** | Admin & Matching Volunteers | Full Engagement |
| **Initial SOS** | Victim & Emergency Contact | Private Tracking |
| **Publicized SOS** | Admin & Matching Volunteers (Global) | Full Engagement |

### 🛠️ Technical Stack (Updated)
*   **Framework:** Flutter (3.11+)
*   **Database:** Firestore (Real-time), SQLite (Local Chat History)
*   **Auth:** Firebase Phone Auth (OTP) + Email/Password
*   **AI:** Gemini Flash 2.5 (Lead Coordinator Persona)
*   **Media Handling:** Base64 Image Compression (No Storage Bucket required)
*   **APIs:** Google Maps SDK, Open Government Data (OGD) India
*   **Refresh Logic:** Pull-to-refresh + Automated Background Scripts (GitHub Actions)
