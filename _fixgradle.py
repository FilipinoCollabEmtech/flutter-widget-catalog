p = "android/settings.gradle.kts"
src = open(p, encoding="utf8").read()
src = src.replace('id("com.android.application") version "9.1.0" apply false',
                  'id("com.android.application") version "9.1.1" apply false', 1)
open(p, "w", encoding="utf8").write(src)
print("OK" if '9.1.1' in src else "FAIL")