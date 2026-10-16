# النشر، وين وصلنا وشنو يحتاج يد صاحب الحساب

## آيفون
- 1.0.0 منشورة على App Store من 25 سبتمبر 2026 (READY_FOR_SALE).
- 1.2.0 (البناء 11) مقدّمة لمراجعة App Store في 16 أكتوبر 2026 مع الوصف الجديد وملاحظات الإصدار، وهي في TestFlight لمجموعة المختبرين، والبناء 11 حل محل اللي قبله قبل المراجعة لأن وضع السفر ورسالة الجمعة ومن يسويها لحقوا عليه.
- الودجت ينتظر App Group يُنشأ باليد مرة وحدة، والخطوات في ios/WIDGET.md.

## أندرويد
- 1.1.3 (الرمز 15) في مسار الاختبار المغلق، وصفحة المتجر بالعربي والإنجليزي بوصفها ولقطاتها وملاحظات إصدارها، وتتحدث بسكربت tools/android/play-listing.py من مجلد play/.
- النشر للإنتاج مرفوض من Play بـ FAILED_PRECONDITION: حساب المطور الشخصي الجديد لازم يكمل اختبار مغلق بـ 12 مختبر لمدة 14 يوم، ثم يقدّم طلب "الوصول للإنتاج" من Play Console (Dashboard ثم Apply for production)، وهذي الخطوة ما لها واجهة برمجية وتحتاج صاحب الحساب.
- بعد الموافقة: انطلاق android-release.yml من Actions برقم الإصدار، ثم نقل الإصدار من alpha إلى production من الكونسول أو بسكربت tools/android/play-upload.py مع `--track production`.

## الويب
- منشور دائماً على nokhatha.3li.info من فرع main.

## الوسوم والانطلاق
- وكيل git في هذي الجلسة ما يسمح بدفع الوسوم، فالإصدارات تنطلق باليد من Actions بإدخال رقم الإصدار (workflow_dispatch في android-release.yml وios-release.yml)، والوسوم تنحط لاحقاً من جهاز فيه صلاحية كاملة.
- من الطرفية: `gh api -X POST repos/SiteQ8/Nokhatha/actions/workflows/ios-release.yml/dispatches -f ref=main -f 'inputs[version]=1.2.1'` ونفسها لأندرويد.
