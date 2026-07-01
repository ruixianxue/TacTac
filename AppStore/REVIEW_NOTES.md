# App Review Notes (paste into "Notes" — limit 4000 chars)

```
Thank you for reviewing TacTac.

WHAT THE APP DOES
TacTac helps you remember where you put physical objects. You tell it where you placed an item ("my keys are on the kitchen counter"), and later ask where it is ("where are my keys?"). It understands natural language, so there are no rigid commands.

NO ACCOUNT / NO HARDWARE NEEDED
There is no login, no sign-up, and no demo account required. TacTac does NOT require any external hardware, Bluetooth device, or tracker tag — it is purely a language/memory app. You can test everything on a single device.

HOW TO TEST INSIDE THE APP (no Siri needed)
The fastest way to verify functionality without voice:
1. Launch the app and tap "Continuer" on the intro screen.
2. Tap the "+" button (top right) to add an item — e.g. name "Keys", location "kitchen counter" — and Save.
3. The item appears in the list. Tap it to edit, swipe to delete.
4. Use the search field to find saved items.
You can also add "Saved Places" (Home/Work/etc.) via the location button (top left).

HOW TO TEST THE VOICE / SIRI FLOW (App Intents)
TacTac exposes App Shortcuts, so reviewers can trigger it hands-free:
1. Ensure Apple Intelligence is enabled (Settings > Apple Intelligence & Siri) on a supported device.
2. Say: "Hey Siri, TacTac" — then, when prompted, say a sentence such as "my wallet is in my backpack." Siri confirms it saved the item.
3. Say: "Hey Siri, TacTac" again, then ask "where is my wallet?" — Siri answers with the saved location.
Alternatively, in the Shortcuts app you'll find "Remember Item," "Find Item," and "TacTac" actions provided by the app.

ON-DEVICE MODEL BEHAVIOR (IMPORTANT)
Natural-language understanding and the spoken answers are generated on-device using Apple Intelligence (the Foundation Models framework). Please note:
- The FIRST request after install (or after the system model finishes downloading) can take noticeably longer while the on-device model warms up. Subsequent requests are fast. This initial latency is expected and is not a bug.
- On devices/simulators where Apple Intelligence is unavailable or disabled, TacTac shows a clear message and falls back to a built-in rule-based parser for simple sentences, so core save/find still works for testing.

PRIVACY
Everything is on-device. No data is transmitted off the device: items and places are stored locally (SwiftData), and language processing uses on-device Apple Intelligence. There are no analytics, ads, accounts, or third-party network calls. Location (When In Use) is optional and only used locally to tag an item with a saved place; it never leaves the device. Hence the App Privacy label is "Data Not Collected."

PERMISSIONS
- Location (When In Use): optional. If you decline, the app works fully; items simply won't be tagged with a place.

Please contact us if you need anything else to complete the review.
```
