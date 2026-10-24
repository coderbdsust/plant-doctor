# 🩺🌿 গাছের ডাক্তার

> **নগর অরণ্য** গাইডলাইন-নির্মিত অ্যাপ — ছাদ বাগান ও উদ্ভিদ পরিচর্যা, সম্পূর্ণ বাংলা গাইড, ধাপে ধাপে পড়ার অ্যাপ
> সাথে **গাছের ডাক্তার 🩺** — ছবি দেখে উদ্ভিদ শনাক্ত ও রোগ নির্ণয় (Gemini AI)

`nogor_oronno` — Flutter 3.38+ (Android · iOS · Web · macOS)

---

## 📥 ডাউনলোড

- 📱 **APK (Android):** [Google Drive ফোল্ডার](https://drive.google.com/drive/folders/1OjWUaNrAtvvx065L26KAZP_zpoXbOke6?usp=drive_link) — রিলিজ APK এখানে আপলোড থাকে, ডাউনলোড করে সরাসরি ইন্সটল করুন

> ইন্সটলের আগে "Unknown sources / অজানা উৎস" অনুমতি দিতে হতে পারে।
> অ্যাপের ভেতরে AI ফিচার চালাতে নিজের Gemini API key দরকার (নিচে সেটআপ দেখুন)।

---

## ✨ ফিচারসমূহ

| ফিচার | বিবরণ |
|---|---|
| 📖 **ধাপে ধাপে পড়া** | ১০টি অধ্যায়, ৮৪টি ধাপ — প্রতিটি ধাপ ছোট টুকরোয় ভাগ করা, পড়ার পজিশন মনে থাকে |
| 🔍 **গাইডে সার্চ** | পুরো গাইডলাইনের ভেতরে বাংলা টেক্সট সার্চ + সম্পর্কিত কীওয়ার্ড |
| ✍️ **বাংলা টাইপোগ্রাফি** | বান্ডল করা Noto Sans Bengali ফন্ট, ফন্ট সাইজ নিয়ন্ত্রণ (৮৫%–১৪০%) |
| 🌙 **থিম** | সবুজ হটা-টোনড (foliage) লাইট/ডার্ক থিম, সিস্টেম অনুসারে স্বয়ংক্রিয় |
| 💬 **জেমিনি AI সহায়ক** | ছাদ বাগান নিয়ে প্রশ্ন করুন — Google Search grounding সহ live উত্তর ও সূত্র |
| 🩺 **গাছের ডাক্তার** | পাতা/কান্ডের ছবি আপলোড → উদ্ভিদের নাম, স্বাস্থ্য, রোগ/পোকা, কারণ, জৈব ও রাসায়নিক প্রতিকার, প্রতিরোধ — সব বাংলায় |
| ⚙️ **সেটিংস** | API key, মডেল নির্বাচন, থিম, ফন্ট সাইজ, গুগল সার্চ টগল — সব SharedPreferences-এ সংরক্ষিত |

---

## 🏗️ প্রজেক্ট স্ট্রাকচার

```
lib/
├── main.dart                     # অ্যাপ এন্ট্রি,thic থিম ও নেভিগেশন
├── data/guide_parser.dart        # Markdown → Chapter → Step → Block পার্সার
│                                 #   (নেস্টেড লিস্ট, টেবিল, বাংলা ডিজিট ১-৯ সমর্থন)
├── models/guide.dart             # GuideDocument / Chapter / Step / Block মডেল
├── screens/
│   ├── home_screen.dart          # হোম: অগ্রগতি, quick actions, অধ্যায় তালিকা
│   ├── reader_screen.dart        # ধাপে ধাপে রিডার (গ্রুপ চিপ, নেস্টেড লিস্ট)
│   ├── search_screen.dart        # গাইড সার্চ
│   ├── gemini_chat_screen.dart   # AI চ্যাট
│   ├── plant_doctor_screen.dart  # 🩺 গাছের ডাক্তার (ছবি → রোগ নির্ণয়)
│   └── settings_screen.dart      # সেটিংস
├── services/
│   ├── gemini_service.dart       # Gemini REST ক্লায়েন্ট (x-goog-api-key হেডার,
│   │                             #   429 retryDelay পার্সিং + অটো-রিট্রাই)
│   ├── local_search_service.dart # ইন-মেমোরি সার্চ ইনডেক্স
│   ├── web_search_service.dart   # ইন্টারনেট সার্চ হেল্পার
│   └── settings_service.dart     # প্রেফারেন্স স্টোর
├── state/app_controller.dart     # গাইড লোডিং + অ্যাপ স্টেট (ChangeNotifier)
├── theme/app_theme.dart          # সবুজ থিম (seed #1B7A3D)
└── widgets/                      # ব্লক রেন্ডারিং, বোল্ড/ইনলাইন টেক্সট
```

---

## 🚀 দ্রুত শুরু

```bash
# ১. ডিপেন্ডেন্সি
flutter pub get

# ২. API key সেট করুন (নিচের সেকশন দেখুন)
#    অ্যাপে: সেটিংস → Gemini API key

# ৩. চালান
flutter run                    # সংযুক্ত ডিভাইস/এমুলেটর

# ৪. রিলিজ বিল্ড
flutter build apk --release    # Android
flutter build web --release    # Web
```

---

## 🔑 Gemini API key সেটআপ

1. [aistudio.google.com/apikey](https://aistudio.google.com/apikey) থেকে API key তৈরি করুন
2. অ্যাপে **সেটিংস → Gemini API key** → key বসান → 💾 Save
3. ব্যস — AI চ্যাট ও গাছের ডাক্তার দুটোই এই key দিয়ে চলবে

### মডেল নির্বাচন

সেটিংস থেকে যেকোনো মডেল বাছতে পারবেন:

| মডেল | কখন ব্যবহার করবেন |
|---|---|
| `gemini-3.8-flash` (ডিফল্ট) | সবচেয়ে স্মার্ট Flash |
| `gemini-3.6-flash` | ভারসাম্যপূর্ণ, দ্রুত |
| `gemini-3.5-flash-lite` | সবচেয়ে সস্তা/দ্রুত — **ভালো কোটা** লাগলে এটা বাছুন |
| `gemini-2.5-flash` / `2.5-flash-lite` / `2.5-pro` | পুরনো জেনারেশন |

> 💡 **রেট-লিমিট (৪২৯) টিপস:** একই Google Cloud প্রজেক্টের সব key মিলে কোটা গোনা হয়।
> নতুন key বানালেও একই প্রজেক্টে কোটা রিসেট হয় **না** — ভিন্ন প্রজেক্টের key নিন,
> অথবা `gemini-3.5-flash-lite`-এর মতো বেশি কোটার মডেল বাছুন। অ্যাপ নিজেই
> সার্ভারের বলা `retryDelay` (≤ ১৫ সে.) অপেক্ষা করে একবার অটো-রিট্রাই করে।

---

## 📷 Android পারমিশন

`android/app/src/main/AndroidManifest.xml`-এ কনফিগার করা আছে:

| পারমিশন | কাজ |
|---|---|
| `INTERNET` | Gemini API কল |
| `CAMERA` | ক্যামেরায় ছবি তোলা (রানটাইমে অনুমতি চাওয়া হয়) |
| `READ_MEDIA_IMAGES` (Android 13+) | গ্যালারি থেকে ছবি |
| `READ_EXTERNAL_STORAGE` (Android ≤ 12) | পুরনো ডিভাইসে গ্যালারি |

> ⚠️ **গুরুত্বপূর্ণ:** Manifest বদলানোর পর হট-রিলোড **যথেষ্ট নয়** —
> অ্যাপ সম্পূর্ণ বন্ধ করে আবার `flutter run` করুন। প্রথমবার ছবি নেওয়ার
> সময় অনুমতির পপআপ **Allow** করে দিন।

---

## 🩺 গাছের ডাক্তার — টেকনিক্যাল নোট

```
ছবি পিক (image_picker)
  → 1280px / 80% quality-তে ডাউনস্কেল
  → ব্যাকগ্রাউন্ড আইসোলেটে base64 (compute) — UI ফ্রিজ হয় না
  → Gemini generateContent (inlineData + বাংলা system instruction)
  → ফলাফল: উদ্ভিদ, রোগ, কারণ, প্রতিকার, প্রতিরোধ
```

- প্রিভিউ `Image.memory` দিয়ে — Android/iOS/Web সবখানে কাজ করে
- ছবি ছোট রাখা হয় যাতে কম RAM ফোনে OOM না হয় এবং API cost কম থাকে
- ক্যামেরা/পারমিশন/মেমোরি সমস্যায় ক্র্যাশের বদলে বাংলা মেসেজ দেখায়

---

## 📚 গাইড কনটেন্ট আপডেট

অ্যাপ **bundled asset** থেকে কনটেন্ট পড়ে, নেটওয়ার্ক থেকে নয়:

- সোর্স: `নগর অরণ্য - ছাদ বাগান ও উদ্ভিদ পরিচর্যা সম্পূর্ণ গাইডলাইন.md`
- অ্যাপ পড়ে: `assets/guideline.md` (কপি)

সোর্স বদলালে:

```bash
# সোর্স থেকে asset রিফ্রেশ করুন, তারপর
dart run tool/verify.dart   # কনটেন্ট-লস যাচাই (প্রতিটি লাইন হুবহু থাকা চাই)
dart run tool/summary.dart  # অধ্যায়/ধাপ সারসংক্ষেপ
flutter pub get && flutter run
```

---

## ✅ কোয়ালিটি যাচাই

```bash
flutter analyze   # লিন্ট — No issues found
flutter test      # পার্সার + উইজেট টেস্ট — All tests passed!
```

---

## 🧰 টেক স্ট্যাক

- **Flutter / Dart** — Material 3, single codebase (Android, iOS, Web, macOS)
- **`http`** — Gemini REST API (`x-goog-api-key` হেডার)
- **`image_picker`** — ক্যামেরা/গ্যালারি
- **`shared_preferences`** — সেটিংস সংরক্ষণ
- **`url_launcher`** — সূত্র/বাহ্যিক লিংক খোলা
- কাস্টম **Markdown পার্সার** — নেস্টেড লিস্ট, টেবিল, বাংলা ডিজিট, ধাপ অটো-স্প্লিট

## 📄 লাইসেন্স

ব্যক্তিগত প্রজেক্ট। গাইড কনটেন্টের স্বত্ব লেখকের।
