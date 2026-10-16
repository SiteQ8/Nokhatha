# ودجت آيفون

الودجت جاهز في `ios/NokhathaWidget` ويبني على المحاكي، لكنه يحتاج App Group مشترك بينه وبين التطبيق، ومجموعات التطبيقات ما لها واجهة في App Store Connect API، فتنشأ مرة وحدة باليد:

1. من developer.apple.com افتح Certificates, Identifiers & Profiles ثم Identifiers ثم App Groups، وأنشئ مجموعة بالمعرّف `group.com.eworldq8.nokhatha`.
2. في `ios/project.yml` أضف تحت `Nokhatha` ثم `dependencies`:
   ```yaml
   - target: NokhathaWidget
     embed: true
   ```
   وأضف تحت `Nokhatha` السطرين:
   ```yaml
   entitlements:
     path: Nokhatha/Nokhatha.entitlements
   ```
3. في `.github/workflows/ios-release.yml` أضف `NOKHATHA_WIDGET: "1"` إلى بيئة خطوة "Bundle id and provisioning profile"، فيسجّل السكربت معرّف الودجت ويفعّل المجموعة على المعرّفين ويوقّع الودجت.

بعدها أي إصدار يحمل الودجت، والتطبيق يكتب حالته في المجلد المشترك ويحدّث الودجت مع كل حفظ.
