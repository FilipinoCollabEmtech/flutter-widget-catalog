# Keep ML Kit classes for text recognition
-keep class com.google.mlkit.** { *; }
-keep class com.google.android.gms.** { *; }
-dontwarn com.google.mlkit.**
-dontwarn com.google.android.gms.**

# Keep ONNX Runtime (docTR engine) classes. Without this the release build
# strips the JNI entry points and every docTR inference fails at runtime.
-keep class ai.onnxruntime.** { *; }
-dontwarn ai.onnxruntime.**
