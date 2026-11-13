# Amar Hisab (আমার হিসাব)

একটি Flutter Android অ্যাপ। বাংলা ডিফল্ট, ইংরেজি ভাষা, BDT (৳), SQLite অফলাইন ডেটাবেজ। কোনো সার্ভারে তথ্য পাঠায় না।

## যা আছে
- আয় ও ব্যয়ের এন্ট্রি যোগ, সম্পাদনা ও মুছে ফেলা (সোয়াইপ/লং-প্রেস, Undo সহ)
- ব্যক্তিগত, ব্যবসা ও পরিবার অ্যাকাউন্ট; নতুন অ্যাকাউন্ট যোগ/নাম পরিবর্তন/মুছা; "সব অ্যাকাউন্ট" ভিউ
- ড্যাশবোর্ড: ব্যালেন্স, এই মাসের সারাংশ, খরচের ডোনাট চার্ট, শেষ ৭ দিনের চার্ট
- দৈনিক / সাপ্তাহিক / মাসিক রিপোর্ট ও ক্যাটাগরি চার্ট
- বাংলা (বাংলা সংখ্যাসহ) ও ইংরেজি; লাখ-কোটি হিসাবে ৳ ফরম্যাট
- লাইট / ডার্ক / অটো থিম
- ব্যাকআপ ও রিস্টোর
- পুরনো (v1.0) ডেটা আপগ্রেডের পর অক্ষত থাকে

## APK বানানোর নিয়ম

### পদ্ধতি ক (কিছু ইনস্টল করতে হবে না — GitHub Actions)
1. বিনামূল্যে GitHub অ্যাকাউন্ট খুলে একটি নতুন repository বানান।
2. এই ফোল্ডারের সব ফাইল (লুকানো `.github` ফোল্ডারসহ) `main` branch-এ আপলোড করুন।
3. **Actions** ট্যাব → **Build Android APK** → ৬–১০ মিনিট অপেক্ষা করুন।
4. শেষ হলে run খুলে **Artifacts** থেকে `amar-hisab-apk` ডাউনলোড করুন।

### পদ্ধতি খ (নিজের কম্পিউটারে, Windows)
1. Flutter SDK ইনস্টল করে `flutter doctor` চালান।
2. PowerShell-এ এই ফোল্ডারে গিয়ে চালান:
   ```powershell
   flutter create . --platforms=android --org com.amarhisab --project-name amar_hisab
   dart run tool/patch_android.dart
   flutter pub get
   flutter test
   flutter build apk --release
   ```
3. APK: `build\app\outputs\flutter-apk\app-release.apk`

## গুরুত্বপূর্ণ সীমাবদ্ধতা
PDF/Excel export, PIN/fingerprint lock এবং Play Store signing এখনো নেই। ব্যাকআপ হলো টেক্সট কপি/পেস্ট পদ্ধতির। ডেটা ফোনেই থাকে; অ্যাপ আনইনস্টল করলে মুছে যায়, তাই নিয়মিত ব্যাকআপ রাখুন।
