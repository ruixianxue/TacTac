# TacTac — App Store Connect Submission Metadata

Copy/paste-ready values for App Store Connect. Character counts are noted where Apple enforces a limit.

---

## Identity

| Field | Value |
|---|---|
| Bundle ID | `com.tacteam.tac` |
| SKU | `tactac-ios-001` (any unique string; not shown to users) |
| Primary language | English (U.S.) |
| Primary category | Productivity |
| Secondary category | Utilities |

> Note: the in-app onboarding is currently written in French. If you ship it as-is, add **French** as a localization in App Store Connect *or* localize onboarding to English so the listing language and the app UI match (see "Known review risks" below).

---

## App Name (limit 30)

**TacTac** *(6)*

Optional descriptive variant if you want keywords in the name:
- `TacTac: Find Your Things` *(24)*

## Subtitle (limit 30)

**Remember where you put things** *(29)*

Alternates:
- `Ask Siri where you put things` *(29)*
- `Voice memory for your stuff` *(27)*

## Promotional Text (limit 170 — editable anytime without a new build)

> Never lose your keys, wallet, or passport again. Just tell TacTac where you put something — then ask. Everything runs privately on your device with Apple Intelligence.
*(≈181 — trim to:)*

> Never lose your keys, wallet, or passport again. Tell TacTac where you put something, then just ask. Runs privately on-device with Apple Intelligence.
*(≈150)*

## Keywords (limit 100, comma-separated, no spaces after commas)

```
find my things,lost keys,where did i put,memory,reminder,siri,voice,belongings,organizer,forgetful
```
*(98 chars)*

> Don't repeat words already in the app name/subtitle, and don't use "app" or competitor names.

---

## Description (limit 4000)

```
Where did I put my keys? Where's my passport? TacTac is the effortless way to remember where you left your things — powered entirely by on-device Apple Intelligence.

Just tell TacTac in plain language, out loud or by typing:
"My keys are on the kitchen counter."
"I put my passport in the top desk drawer."

Later, ask and get an instant answer:
"Where are my keys?" → "Your keys are on the kitchen counter, saved 2 hours ago."

HANDS-FREE WITH SIRI
Trigger TacTac without opening the app. Say "Hey Siri, TacTac" and speak naturally, or use the "Remember" and "Find" shortcuts. TacTac understands everyday sentences — no rigid commands to memorize.

SMART, NOT LITERAL
TacTac understands what you mean. Ask for "my glasses" and it can match "sunglasses." Ask for "my charger" and it finds the cable you saved. It also respects the details that matter — "my sister's keys" won't be confused with your own.

PLACE-AWARE MEMORY
Save places like Home, Work, School, or your car. When you save an item, TacTac can note which place you were at, so answers are more useful: "Your umbrella is by the front door, at Home."

COMPLETELY PRIVATE
TacTac was built privacy-first. Everything happens on your device:
- Language understanding runs on-device with Apple Intelligence — nothing is sent to a server.
- Your items and places are stored locally on your iPhone.
- No account. No sign-up. No tracking. No ads.

Your data is yours — not even we can see it.

A CLEAN, SIMPLE APP
Browse everything you've saved in one tidy list, search instantly, edit or delete items, and pick icons that make your things easy to spot at a glance.

Never retrace your steps again. Tell TacTac once — and just ask.

—
TacTac uses Apple Intelligence and requires a compatible device with Apple Intelligence enabled for voice understanding. Location is optional and only used to tag items with your saved places; it never leaves your device.
```

## What's New in This Version (1.0)

```
This is the first release of TacTac. Tell it where you put your things, then ask — hands-free with Siri and fully private on your device. We'd love your feedback.
```

---

## App Store Icon (1024×1024)

- The project uses an **Icon Composer** icon (`TacTacIcon.icon`, iOS 26 Liquid Glass). App Store Connect derives the 1024 marketing icon from the icon bundled in your uploaded build — you generally do **not** upload a separate PNG.
- If App Store Connect asks for a 1024×1024 PNG anyway: open `TacTacIcon.icon` in **Icon Composer → File → Export** a 1024×1024 PNG with **no alpha channel** and **no rounded corners** (Apple applies the mask).

---

## Age Rating Questionnaire

Answer every content question **None / No**. TacTac has no objectionable content, no web access, no user-generated content, no ads.

Expected result: **4+ / Ages 4 and up.**

Specifically:
- Violence (cartoon, realistic), sexual content, nudity, profanity, horror/fear: **None**
- Alcohol/tobacco/drugs, gambling, contests: **None**
- Medical/treatment info: **None**
- Unrestricted web access: **No**
- User-generated content / chat: **No**
- Data collection for advertising / tracking: **No**

---

## App Privacy — "Nutrition Label"

**Recommended selection: "Data Not Collected."**

Rationale: Apple defines "collect" as transmitting data off the device. TacTac keeps everything local:
- Item names, locations, and saved places → stored on-device via SwiftData.
- Language understanding → on-device Apple Intelligence (Foundation Models); no server calls.
- Location (When In Use) → used only on-device to tag items with your saved places; never transmitted.
- No analytics SDKs, no ads, no accounts, no third-party network calls.

In App Store Connect → App Privacy:
1. "Do you or your third-party partners collect data from this app?" → **No**.
2. This yields the **Data Not Collected** label.

> If you later add any analytics, crash reporting, or a backend sync, you must revisit this and disclose accordingly.

---

## Review Notes

See `REVIEW_NOTES.md` — paste its contents into the "Notes" field (App Review Information). It is within the 4000-character limit.

## Support & Marketing URLs

- Support URL (required): a reachable page with a contact method (email is fine). e.g. a simple GitHub Pages page or `mailto:`-style contact page.
- Marketing URL (optional).
- Privacy Policy URL (required): host `privacy-policy.html` (see `PRIVACY_POLICY.md` for hosting steps) and paste the resulting URL.

## App Review Contact

- First/Last name, phone, and email for Apple to reach you (your Apple ID email is fine).
- Demo account: **Not required** (no login in the app).
