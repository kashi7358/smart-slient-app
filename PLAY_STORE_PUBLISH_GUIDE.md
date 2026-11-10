# Google Play Store Release & Production Deployment Guide
**Application**: Smart Silent  
**Package Name (Application ID)**: `com.kawiish.smartsilentt`  
**Current Version**: `1.0.8` (Version Code `10`)  
**Target SDK**: Android 15 (`targetSdk 35`, `compileSdk 36`)  

---

## 1. Quick Release Build (One-Command)

To build the official release **Android App Bundle (.aab)** ready for the Google Play Console:

```bash
flutter build appbundle --release
```

The output file will be generated at:
```
build/app/outputs/bundle/release/app-release.aab
```
*Note: This is the exact `.aab` file you drag and drop into the Google Play Console under **Production > Create new release**.*

---

## 2. Production Keystore & Signing Configuration (Configured & Ready)

The production release signing configuration is **already generated and configured** in the project:

* **Keystore File**: `android/app/upload-keystore.jks`
* **Properties File**: `android/key.properties`
* **Key Alias**: `smartsilent`
* **Key Password**: `smartsilent123`
* **Store Password**: `smartsilent123`
* **Validity**: 10,000 Days (Valid until year 2054)
* **Algorithm**: 2048-bit RSA (Google Play Store Standard)

> [!IMPORTANT]
> **Backup Warning**: Please keep a secure backup copy of `android/app/upload-keystore.jks` and `android/key.properties`. Google Play Store requires this same keystore for all future app updates.

---

## 3. Google Play Console Form Declarations Checklist

When creating your release in the Google Play Console, you will be asked to complete several mandatory policy declaration questionnaires. Fill them out as follows:

### 3.1 App Access
* Select: **"All functionality is available without special access"** *(No login or account registration is required).*

### 3.2 Ads Declaration
* Select: **"Yes, my app contains ads"** *(Google AdMob banner ads are integrated).*

### 3.3 Content Rating & Target Audience
* Complete the questionnaire: Smart Silent contains zero violence, sensitive themes, or profanity.
* Category: **Utility / Tools**
* Expected Rating: **PEGI 3 / Everyone**
* Target Audience: **13 and older** (or 18+)

### 3.4 Exact Alarms Policy Declaration (`USE_EXACT_ALARM`)
Google Play strictly reviews apps declaring exact alarms. Submit the following justification:
* **Qualifying Core Use Case**: Select **"Alarm clock or reminder"**.
* **Justification Statement (Copy & Paste)**:
  > *"Smart Silent is an automated utility that schedules exact, time-critical alarms to switch device sound mode to Silent or Vibrate at precise Islamic prayer times (Fajr, Zuhr, Asr, Maghrib, Isha) and user-scheduled meeting intervals, and automatically restores normal ringer volume immediately upon completion of the prayer or meeting interval. Exact timing is essential so the device does not ring during prayers or quiet meetings."*

### 3.5 Data Safety Form
* **Does your app collect or share user data?**: Select **No personal user data is collected**.
* **Location Data**: Not shared with third parties. Used strictly locally to display nearest mosques.
* **Storage / Hive**: All user schedules are saved locally on the device storage.
* **Data Deletion**: Users can delete individual schedules at any time or use "Reset App Data" inside Settings to wipe all records.

### 3.6 Privacy Policy
* Provide your privacy policy URL or link to the in-app privacy policy:
  `https://doc-hosting.flycricket.io/smart-silent-privacy-policy/c359a6fe-2a0d-4fe3-94c3-ff231eb96c92/privacy`

---

## 4. Pre-Launch Verification Checklist

| Item | Status | Verification Note |
| :--- | :---: | :--- |
| **Target SDK 35 (Android 15)** | ✅ PASSED | Fully compliant with Google Play target SDK policy |
| **Android App Bundle (.aab)** | ✅ READY | Standard `.aab` build enabled in Gradle |
| **ProGuard / R8 Rules** | ✅ PASSED | `proguard-rules.pro` protects Hive, AlarmManager & SoundMode |
| **64-bit Architecture** | ✅ PASSED | `armeabi-v7a`, `arm64-v8a`, `x86_64` included by Flutter |
| **Reboot Survival** | ✅ PASSED | `RebootBroadcastReceiver` enabled in AndroidManifest.xml |
| **Exact Alarm Permissions** | ✅ PASSED | `USE_EXACT_ALARM` & `SCHEDULE_EXACT_ALARM` configured |
| **In-App Privacy Policy** | ✅ PASSED | Dedicated in-app Privacy Policy screen active |
| **Offline Reliability** | ✅ PASSED | Zero external backend server dependencies |
