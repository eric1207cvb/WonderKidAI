# App Store Privacy Label Worksheet — WonderKidAI

**Prepared:** August 12, 2026  
**Status:** Draft for App Store Connect; review against the deployed Render configuration and each vendor dashboard immediately before submission.

This worksheet is based on the current iOS source code. It deliberately takes a conservative view: questions, transcripts, and identifiers are transmitted to external services and should not be labelled “No Data Collected.” It is not legal advice.

## Recommended App Store Connect answers

### Data Used to Track You

**No.** The app does not use data for tracking as Apple defines it: linking user or device data collected from the app with third-party data for targeted advertising or sharing it with a data broker.

### Data Linked to You

Select the following only after confirming how Render, OpenAI, and RevenueCat retain production requests:

| App Store data type | What the app sends or syncs | Recipients | Purpose to select | Tracking |
| --- | --- | --- | --- | --- |
| **User Content → Other User Content** | Typed question and speech-recognition transcript; answer/narration text; iCloud-synced Q&A history for verified subscribers | Render, OpenAI, Apple iCloud; some factual search terms go to Wikimedia/Wikipedia | App Functionality | No |
| **Identifiers → User ID** | Random installation identifier and RevenueCat anonymous App User ID | Render; RevenueCat | App Functionality; Other Purposes (rate limiting / abuse prevention) | No |
| **Purchases → Purchase History** | Subscription entitlement / purchase status used to unlock features | RevenueCat, Apple App Store | App Functionality | No |

For each row above, choose **“Linked to the User”** if the recipient can associate the data with the same installation or RevenueCat App User ID. This is the conservative and recommended choice for the current implementation.

### Audio Data — verify before submission

The app uses Apple Speech recognition and asks for microphone permission. The app does not upload raw microphone audio to Render or OpenAI. Apple’s handling of speech recognition may still require an **Audio Data** disclosure depending on the Speech service configuration and Apple’s current App Store Connect guidance. Before submitting, verify this item in App Store Connect and Apple’s documentation; if Apple’s service processes audio off-device, disclose **Audio Data → App Functionality → Not used for tracking** unless Apple confirms an exemption.

### Do not select

Do not claim collection of contacts, location, health/fitness, financial information, photos, camera data, advertising data, or browsing history. The current app does not implement those flows.

## Required release checks

1. Confirm Render request logs and retention settings. If Render logs request bodies, the User Content row must remain disclosed.
2. Confirm the OpenAI API organization’s data controls and any retention setting; this does not remove the need to disclose text sent to OpenAI.
3. Confirm RevenueCat dashboard configuration and its current privacy documentation, including how the anonymous App User ID and subscription events are processed.
4. In App Store Connect, provide a publicly reachable HTTPS privacy-policy URL. The in-app policy and this repository file are not a replacement for that required listing URL.
5. Keep the in-app policy, hosted policy, and App Store privacy label identical whenever a new SDK, analytics service, backend route, or data field is added.

## Current data-flow summary

```text
Speech → Apple Speech → transcript ─┐
Typed question ─────────────────────┼→ Render → OpenAI → answer / speech
Install ID + RevenueCat App User ID ┘

Factual search term → Wikipedia / Wikimedia
Verified subscriber Q&A + language preference → Apple iCloud KVS
Subscription entitlement → RevenueCat / App Store
```

Reference: [Apple App Privacy Details](https://developer.apple.com/app-store/app-privacy-details/) and [App Review Guidelines](https://developer.apple.com/app-store/review/guidelines/).
