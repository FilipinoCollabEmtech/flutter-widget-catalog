p = "lib/models/route.dart"
src = open(p, encoding="utf8").read()
src = src.replace("final String? landmarkCode;", "final String? code;", 1)
src = src.replace("const Waypoint(this.name, this.point, [this.landmarkCode]);", "const Waypoint(this.name, this.point, [this.code]);", 1)
open(p, "w", encoding="utf8").write(src)
print("OK")