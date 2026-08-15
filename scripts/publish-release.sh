#!/usr/bin/env bash
# Phát hành một bản cập nhật WeTube, từ đầu tới cuối bằng một lệnh:
# ghi phiên bản vào pubspec, build, kiểm chữ ký, đưa lên GitHub Releases,
# rồi ghi thẳng bản ghi vào Supabase.
#
#   ./scripts/publish-release.sh                       # hỏi từng thứ
#   ./scripts/publish-release.sh 1.0.1 2 "Sửa lỗi ..."  # truyền sẵn
#
# Cài đặt một lần:
#   echo 'sdk-...' > scripts/.music-sdk-key
#   printf 'admin@example.com\n' > scripts/.supabase-admin   # dòng 2: mật khẩu, nếu muốn khỏi gõ
# Cả hai file đều đã nằm trong .gitignore — repo car-app là repo công khai.
#
# Vì sao đăng nhập bằng tài khoản admin chứ không dùng service_role key:
# service_role bỏ qua toàn bộ RLS trên mọi bảng, cất nó trên máy là đặt cả
# backend vào một file. Token admin chỉ làm được đúng những gì policy
# is_admin() cho phép, và đổi mật khẩu là thu hồi được.
set -euo pipefail

REPO="DuongAty/car-app"

# Dấu vân tay chứng chỉ của keystore release (~/keys/youcar-release.jks).
# Android chỉ cho cài đè khi chữ ký trùng; lệch là khách phải gỡ app, mất
# sạch dữ liệu và mất luôn trạng thái kích hoạt.
EXPECTED_FINGERPRINT="9B:DC:D1:F0:00:AD:F2:78:33:1C:80:8A:9A:6B:B6:97:0B:F0:10:23:3D:CE:21:3E:E2:9C:CB:4D:46:FA:1B:36"

die()  { printf '\n✗ %s\n' "$*" >&2; exit 1; }
step() { printf '\n── %s\n' "$*"; }

cd "$(dirname "$0")/.."

# ── 0. Điều kiện cần ─────────────────────────────────────────────────────────
step "Kiểm tra điều kiện"

command -v gh      >/dev/null || die "Chưa có gh CLI."
command -v python3 >/dev/null || die "Chưa có python3."
gh auth status >/dev/null 2>&1 || die "gh chưa đăng nhập. Chạy: gh auth login"

KEY_FILE="scripts/.music-sdk-key"
if [ -z "${MUSIC_SDK_LICENSE_KEY:-}" ] && [ -f "$KEY_FILE" ]; then
  MUSIC_SDK_LICENSE_KEY="$(tr -d ' \t\r\n' < "$KEY_FILE")"
fi
[ -n "${MUSIC_SDK_LICENSE_KEY:-}" ] || die "Chưa có khoá MusicSDK.
   Làm một lần:  echo 'sdk-...' > $KEY_FILE
   Thiếu khoá thì app build ra không tìm và không phát được bài nào."

APKSIGNER="$(find "${ANDROID_HOME:-/opt/homebrew/share/android-commandlinetools}/build-tools" \
             -name apksigner -maxdepth 2 2>/dev/null | sort | tail -1)"
[ -x "$APKSIGNER" ] || die "Không tìm thấy apksigner trong Android SDK build-tools."

# Script sẽ commit và push riêng pubspec.yaml. Nếu file đó đang có sửa đổi
# khác chưa commit, chúng sẽ bị cuốn theo vào commit phát hành — nên dừng lại
# và để bạn tự xử lý phần của mình trước.
git diff --quiet -- pubspec.yaml || die "pubspec.yaml đang có thay đổi chưa commit.
   Script chỉ nên commit đúng dòng version nó tự ghi. Commit hoặc hoàn lại
   phần sửa của bạn trước, rồi chạy lại."

BRANCH="$(git rev-parse --abbrev-ref HEAD)"
[ "$BRANCH" != "HEAD" ] || die "Đang ở trạng thái detached HEAD, không push được. Checkout một nhánh trước."
git rev-parse --abbrev-ref '@{upstream}' >/dev/null 2>&1 \
  || die "Nhánh $BRANCH chưa theo dõi remote nào. Chạy: git push -u origin $BRANCH"

# Một nguồn sự thật cho URL và anon key: chính file cấu hình app đang dùng.
CFG="lib/core/config/supabase_config.dart"
SUPA_URL="$(grep -o 'https://[a-z0-9]*\.supabase\.co' "$CFG" | head -1)"
ANON_KEY="$(grep -o 'eyJ[A-Za-z0-9._-]*' "$CFG" | head -1)"
[ -n "$SUPA_URL" ] && [ -n "$ANON_KEY" ] || die "Không đọc được URL/anon key từ $CFG."

# ── 1. Phiên bản và ghi chú ──────────────────────────────────────────────────
step "Phiên bản"

CURRENT="$(grep '^version:' pubspec.yaml | awk '{print $2}')"
CURRENT_CODE="${CURRENT##*+}"
echo "   pubspec đang là: $CURRENT"

# Bản đang phát hành trên máy chủ — dùng để chặn việc phát hành lùi.
PUBLISHED="$(curl -s -X POST "$SUPA_URL/rest/v1/rpc/latest_release" \
              -H "apikey: $ANON_KEY" -H 'Content-Type: application/json' -d '{}' \
            | python3 -c 'import json,sys
try:
    d = json.load(sys.stdin)
    print(d["version_code"] if d else 0)
except Exception:
    print(0)')"
echo "   đang phát hành:  versionCode $PUBLISHED"

VERSION_NAME="${1:-}"
VERSION_CODE="${2:-}"
NOTES="${3:-}"

# Ngưỡng thấp nhất chấp nhận được là lớn hơn CẢ HAI: bản đã phát hành, và
# bản đang nằm trong pubspec (tức bản bạn vừa build và cài lên máy). Chỉ so
# với bản đã phát hành là chưa đủ — lần phát hành đầu tiên, máy chủ trống nên
# ngưỡng là 0, và một versionCode bằng đúng bản đang cài sẽ lọt qua rồi máy
# báo "đã mới nhất" mãi mãi.
FLOOR="$PUBLISHED"
[ "$CURRENT_CODE" -gt "$FLOOR" ] 2>/dev/null && FLOOR="$CURRENT_CODE"
NEXT=$((FLOOR + 1))

[ -n "$VERSION_NAME" ] || read -rp "   versionName mới (vd 1.0.1): " VERSION_NAME
[ -n "$VERSION_CODE" ] || read -rp "   versionCode mới (thấp nhất $NEXT): " VERSION_CODE
[ -n "$NOTES" ]        || read -rp "   Ghi chú thay đổi (hiện trong app): " NOTES

[[ "$VERSION_NAME" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]] || die "versionName phải dạng 1.0.1, đang là '$VERSION_NAME'."
[[ "$VERSION_CODE" =~ ^[0-9]+$ ]]                 || die "versionCode phải là số nguyên, đang là '$VERSION_CODE'."
[ -n "$NOTES" ] || die "Ghi chú không được để trống — nó hiện nguyên văn trong app."

[ "$VERSION_CODE" -gt "$FLOOR" ] || die "versionCode $VERSION_CODE phải lớn hơn $FLOOR.
   Đã phát hành: $PUBLISHED · pubspec hiện tại: $CURRENT_CODE · thấp nhất chấp nhận: $NEXT

   App so sánh bằng versionCode, KHÔNG phải tên phiên bản, và không bao giờ
   hạ cấp. Đặt số bằng hoặc thấp hơn bản đang cài thì dù tên có là 1.0.2 hay
   2.0.0, máy vẫn báo 'không có bản cập nhật mới' — mãi mãi."

TAG="v$VERSION_NAME"
APK="wetube-$VERSION_NAME.apk"

gh release view "$TAG" --repo "$REPO" >/dev/null 2>&1 && die "Tag $TAG đã tồn tại trên $REPO.
   Đừng ghi đè một bản đã phát hành: máy nào lỡ tải bản cũ sẽ thấy hash
   không khớp và báo tệp hỏng. Chọn số phiên bản khác."

# ── 2. Thông tin admin ───────────────────────────────────────────────────────
# Lấy trước khi build, để không build xong vài phút rồi mới phát hiện thiếu.
step "Tài khoản admin (để ghi vào Supabase)"

ADMIN_FILE="scripts/.supabase-admin"
ADMIN_EMAIL=""; ADMIN_PASS=""
if [ -f "$ADMIN_FILE" ]; then
  ADMIN_EMAIL="$(sed -n '1p' "$ADMIN_FILE" | tr -d ' \t\r\n')"
  ADMIN_PASS="$(sed -n '2p' "$ADMIN_FILE" | tr -d '\r\n')"
fi
[ -n "$ADMIN_EMAIL" ] || read -rp "   Email admin: " ADMIN_EMAIL
if [ -z "$ADMIN_PASS" ]; then
  read -rsp "   Mật khẩu: " ADMIN_PASS; echo
fi
[ -n "$ADMIN_PASS" ] || die "Chưa có mật khẩu."

TOKEN="$(python3 - "$SUPA_URL" "$ANON_KEY" "$ADMIN_EMAIL" "$ADMIN_PASS" <<'PY'
import json, sys, urllib.request, urllib.error
url, key, email, password = sys.argv[1:5]
req = urllib.request.Request(
    f"{url}/auth/v1/token?grant_type=password",
    data=json.dumps({"email": email, "password": password}).encode(),
    headers={"apikey": key, "Content-Type": "application/json"},
)
try:
    print(json.load(urllib.request.urlopen(req))["access_token"])
except urllib.error.HTTPError as e:
    sys.stderr.write(e.read().decode()[:300]); sys.exit(1)
PY
)" || die "Đăng nhập admin thất bại. Kiểm tra email/mật khẩu, và kiểm tra
   Authentication → Sign In / Providers → Email đang BẬT (tắt nó là chặn cả đăng nhập)."
echo "   đăng nhập được"

IS_ADMIN="$(curl -s -X POST "$SUPA_URL/rest/v1/rpc/is_admin" \
             -H "apikey: $ANON_KEY" -H "Authorization: Bearer $TOKEN" \
             -H 'Content-Type: application/json' -d '{}')"
[ "$IS_ADMIN" = "true" ] || die "Tài khoản này đăng nhập được nhưng KHÔNG phải admin (is_admin trả '$IS_ADMIN').
   Thêm nó vào bảng public.admins rồi chạy lại:
     insert into public.admins (user_id, note)
     select id, 'admin' from auth.users where email = '$ADMIN_EMAIL';"
echo "   là admin: đúng"

# ── 3. Ghi phiên bản vào pubspec ─────────────────────────────────────────────
step "Ghi pubspec.yaml"

python3 - "$VERSION_NAME" "$VERSION_CODE" <<'PY'
import re, sys
name, code = sys.argv[1], sys.argv[2]
p = "pubspec.yaml"
s = open(p, encoding="utf-8").read()
s2, n = re.subn(r"(?m)^version:.*$", f"version: {name}+{code}", s, count=1)
if n != 1:
    sys.exit("Không tìm thấy dòng 'version:' trong pubspec.yaml")
open(p, "w", encoding="utf-8").write(s2)
PY
echo "   version: $VERSION_NAME+$VERSION_CODE"

# ── 4. Build ─────────────────────────────────────────────────────────────────
step "Build release (vài phút)"

flutter build apk --release --dart-define=MUSIC_SDK_LICENSE_KEY="$MUSIC_SDK_LICENSE_KEY"
BUILT="build/app/outputs/flutter-apk/app-release.apk"
[ -f "$BUILT" ] || die "Không thấy $BUILT sau khi build."

# ── 5. Kiểm chữ ký — chặn ở đây nếu sai ─────────────────────────────────────
step "Kiểm chữ ký"

ACTUAL="$("$APKSIGNER" verify --print-certs "$BUILT" \
          | grep -i 'SHA-256 digest' | head -1 | awk '{print $NF}' \
          | tr 'a-f' 'A-F' | sed 's/../&:/g; s/:$//')"

if [ "$ACTUAL" != "$EXPECTED_FINGERPRINT" ]; then
  die "CHỮ KÝ KHÔNG KHỚP — dừng lại, chưa phát hành gì cả.

   Mong đợi: $EXPECTED_FINGERPRINT
   Thực tế : $ACTUAL

   Bản này KHÔNG cài đè được lên máy khách: Android sẽ từ chối với
   INSTALL_FAILED_UPDATE_INCOMPATIBLE, và cách duy nhất là bảo khách gỡ app,
   mất hết dữ liệu và mất trạng thái kích hoạt.

   Thường là do build trên máy khác, hoặc ~/.android/debug.keystore đã bị xoá
   và Android SDK sinh lại file mới. Khôi phục đúng keystore rồi chạy lại."
fi
echo "   khớp: $ACTUAL"

# ── 6. Commit và push pubspec ────────────────────────────────────────────────
# Phải xong TRƯỚC khi tạo release: `gh release create` gắn tag vào commit
# đang có trên remote, nên nếu push sau thì tag v$VERSION_NAME sẽ trỏ vào mã
# nguồn còn ghi phiên bản cũ. Và phải sau bước kiểm chữ ký, để không đẩy lên
# một lần bump cho bản phát hành rốt cuộc bị chặn.
step "Commit và push pubspec.yaml"

git add pubspec.yaml
# Chạy lại sau một lần push hỏng: commit đã có sẵn từ lần trước, không còn gì
# để commit nữa. `git commit` khi rỗng sẽ báo lỗi và `set -e` giết cả script,
# nên bỏ qua bước này và đi thẳng tới push.
if git diff --cached --quiet; then
  echo "   không có gì mới để commit (chạy lại sau lần push hỏng)"
else
  git commit -m "chore: wetube $VERSION_NAME (versionCode $VERSION_CODE)

$NOTES"
fi
git push origin "$BRANCH" \
  || die "Push thất bại. Bản build đã xong nhưng CHƯA phát hành gì cả — chưa có
   release trên GitHub, chưa ghi gì vào Supabase.
   Thường là do remote đã đi trước: chạy 'git pull --rebase' rồi chạy lại
   script với đúng số phiên bản này. Lần chạy lại sẽ build lại (nhanh hơn nhờ
   build tăng dần) và bỏ qua bước commit vì commit đã nằm sẵn."
echo "   đã push lên $BRANCH"

# ── 7. Đưa lên GitHub Releases ───────────────────────────────────────────────
step "Tải lên GitHub Releases"

cp "$BUILT" "$APK"
trap 'rm -f "$APK"' EXIT

gh release create "$TAG" "$APK" --repo "$REPO" \
  --title "WeTube $VERSION_NAME" --notes "$NOTES"

URL="https://github.com/$REPO/releases/download/$TAG/$APK"

CODE="$(curl -sIL -o /dev/null -w '%{http_code}' "$URL")"
[ "$CODE" = "200" ] || die "Link trả về HTTP $CODE thay vì 200: $URL
   Máy khách tải bằng anon, không có token — link phải mở công khai."

# Chỉ 64 ký tự hash. `shasum` in ra "<hash>  <tên file>"; kèm tên file vào là
# mọi máy tải xong 145MB rồi báo tệp hỏng và thử lại vô tận.
SHA="$(shasum -a 256 "$APK" | awk '{print $1}')"
echo "   HTTP 200, sha256 $SHA"

# ── 8. Ghi vào Supabase ──────────────────────────────────────────────────────
step "Ghi bản ghi vào Supabase"

python3 - "$SUPA_URL" "$ANON_KEY" "$TOKEN" "$VERSION_CODE" "$VERSION_NAME" "$URL" "$SHA" "$NOTES" <<'PY'
import json, sys, urllib.request, urllib.error
url, key, token, code, name, apk, sha, notes = sys.argv[1:9]
body = json.dumps({
    "version_code": int(code), "version_name": name,
    "apk_url": apk, "sha256": sha, "notes": notes,
}).encode()
req = urllib.request.Request(
    f"{url}/rest/v1/app_releases", data=body,
    headers={"apikey": key, "Authorization": f"Bearer {token}",
             "Content-Type": "application/json", "Prefer": "return=minimal"},
)
try:
    urllib.request.urlopen(req)
except urllib.error.HTTPError as e:
    sys.stderr.write(e.read().decode()[:400]); sys.exit(1)
PY

# ── 9. Xác nhận app sẽ thấy đúng bản này ─────────────────────────────────────
step "Xác nhận"

SEEN="$(curl -s -X POST "$SUPA_URL/rest/v1/rpc/latest_release" \
         -H "apikey: $ANON_KEY" -H 'Content-Type: application/json' -d '{}')"
echo "   latest_release() trả về: $SEEN"
python3 -c 'import json,sys; d=json.loads(sys.argv[1]); sys.exit(0 if d and d["version_code"]==int(sys.argv[2]) else 1)' \
  "$SEEN" "$VERSION_CODE" \
  || die "Đã ghi nhưng latest_release() chưa trả về versionCode $VERSION_CODE. Kiểm tra bảng app_releases."

cat <<DONE

════════════════════════════════════════════════════════════════════
Xong. WeTube $VERSION_NAME (versionCode $VERSION_CODE) đã phát hành.

  APK   $URL
  Kiểm  mở app → Cài đặt → Hệ thống → Kiểm tra cập nhật

pubspec.yaml đã được commit và push lên nhánh $BRANCH.
════════════════════════════════════════════════════════════════════
DONE
