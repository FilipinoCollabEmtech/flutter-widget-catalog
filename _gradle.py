import os, glob
base = "android"
for p in ["settings.gradle", "settings.gradle.kts", "build.gradle", "build.gradle.kts",
          "app/build.gradle", "app/build.gradle.kts"]:
    full = os.path.join(base, p)
    if os.path.exists(full):
        print("===", full, "===")
        print(open(full).read())
        print()