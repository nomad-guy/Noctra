import os
import shutil
import hashlib
import json

version = "1.0.3"
version_code = 17005
min_android = 26
apk_dir = os.path.join("build", "app", "outputs", "flutter-apk")
rel_dir = "release"

os.makedirs(rel_dir, exist_ok=True)

# Remove old 1.0.2 apks
for f in os.listdir(rel_dir):
    if f.startswith("Noctra-1.0.2") and f.endswith(".apk"):
        os.remove(os.path.join(rel_dir, f))

abis = {
    "arm64-v8a": "app-arm64-v8a-release.apk",
    "armeabi-v7a": "app-armeabi-v7a-release.apk",
    "x86_64": "app-x86_64-release.apk",
    "universal": "app-release.apk",
}

pkg_map = {}
sums_lines = []

for abi, apk_name in abis.items():
    src = os.path.join(apk_dir, apk_name)
    if not os.path.exists(src):
        print(f"Warning: {src} does not exist!")
        continue
    dest_file = f"Noctra-{version}-{abi}.apk"
    dest_path = os.path.join(rel_dir, dest_file)
    shutil.copy2(src, dest_path)

    hasher = hashlib.sha256()
    with open(dest_path, "rb") as f:
        while chunk := f.read(65536):
            hasher.update(chunk)
    digest = hasher.hexdigest()
    sums_lines.append(f"{digest}  {dest_file}")
    pkg_map[abi] = {
        "file": dest_file,
        "sha256": digest,
    }
    size_mb = os.path.getsize(dest_path) / (1024 * 1024)
    print(f"Packaged {dest_file} ({size_mb:.1f} MB): {digest}")

with open(os.path.join(rel_dir, "SHA256SUMS.txt"), "w", encoding="utf-8") as f:
    f.write("\n".join(sums_lines) + "\n")

manifest = {
    "version": version,
    "versionCode": version_code,
    "minimumAndroid": min_android,
    "packages": pkg_map,
}

manifest_json = json.dumps(manifest, indent=2)
with open(os.path.join(rel_dir, "noctra-update-manifest.json"), "w", encoding="utf-8") as f:
    f.write(manifest_json + "\n")
with open(os.path.join(rel_dir, "release.json"), "w", encoding="utf-8") as f:
    f.write(manifest_json + "\n")

print("Release packaging completed successfully.")
