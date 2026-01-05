# Impedance Monitor - 빌드 가이드

## 지원 플랫폼
- **Web** (Chrome, Edge, Firefox, Safari)
- **Windows** (Windows 10/11 - x64)
- **Linux** (Ubuntu, Debian - x64)
- **macOS** (Intel & Apple Silicon)
- **Android** (APK/AAB)

---

## Windows EXE 빌드 방법

### 필수 요구사항
1. **Flutter SDK** 3.35.4 이상
2. **Visual Studio 2022** (Community 이상)
   - "Desktop development with C++" 워크로드 필수
3. **Windows 10 SDK** (10.0.17763.0 이상)

### 방법 1: 원클릭 빌드 스크립트 (권장)

프로젝트 폴더에서 스크립트 실행:

**CMD 사용:**
```cmd
build_windows.bat
```

**PowerShell 사용:**
```powershell
.\build_windows.ps1
```

스크립트가 자동으로:
- Flutter 환경 검사
- 이전 빌드 정리
- 의존성 설치
- Release 빌드 생성
- 포터블 ZIP 패키지 생성 (PowerShell)

### 방법 2: 수동 빌드

```bash
# 프로젝트 디렉토리로 이동
cd flutter_app

# 의존성 설치
flutter pub get

# Windows Release 빌드
flutter build windows --release
```

### 빌드 결과물 위치
```
build/windows/x64/runner/Release/
├── alternative_impedance.exe    # 실행 파일
├── flutter_windows.dll          # Flutter 런타임
├── data/                        # 앱 데이터
└── *.dll                        # 필요한 DLL 파일들
```

### 배포용 패키징
Release 폴더 전체를 ZIP으로 압축하여 배포:
```bash
cd build/windows/x64/runner
zip -r ImpedanceMonitor_Windows.zip Release/
```

---

## Linux 빌드 방법

### 필수 요구사항
```bash
sudo apt-get update
sudo apt-get install -y clang cmake ninja-build libgtk-3-dev
```

### 빌드 명령어
```bash
flutter build linux --release
```

### 빌드 결과물 위치
```
build/linux/x64/release/bundle/
├── alternative_impedance        # 실행 파일
├── data/                        # 앱 데이터
└── lib/                         # 라이브러리 파일들
```

---

## macOS 빌드 방법

### 필수 요구사항
- Xcode 14 이상
- CocoaPods (`sudo gem install cocoapods`)

### 빌드 명령어
```bash
flutter build macos --release
```

### 빌드 결과물 위치
```
build/macos/Build/Products/Release/
└── alternative_impedance.app
```

---

## Web 빌드 방법

### 빌드 명령어
```bash
flutter build web --release
```

### 빌드 결과물 위치
```
build/web/
├── index.html
├── main.dart.js
├── flutter_service_worker.js
└── assets/
```

### 로컬 테스트
```bash
cd build/web
python3 -m http.server 8080
# 브라우저에서 http://localhost:8080 접속
```

---

## Android APK 빌드 방법

### 빌드 명령어
```bash
# Debug APK
flutter build apk --debug

# Release APK (서명 필요)
flutter build apk --release

# App Bundle (Play Store용)
flutter build appbundle --release
```

### 빌드 결과물 위치
```
build/app/outputs/flutter-apk/
├── app-debug.apk
└── app-release.apk

build/app/outputs/bundle/release/
└── app-release.aab
```

---

## 문제 해결

### Windows 빌드 오류
1. Visual Studio 설치 확인: `flutter doctor -v`
2. CMake 캐시 삭제: `rd /s /q build\windows`
3. 재빌드: `flutter clean && flutter pub get && flutter build windows`

### BLE 시뮬레이션 모드
데스크탑 환경에서는 실제 BLE 하드웨어 없이 시뮬레이션 모드로 동작합니다.
- 스캔: 가상 디바이스 목록 표시
- 연결: 시뮬레이션 연결
- 측정: 테스트 데이터 생성

---

## 버전 정보
- Flutter: 3.35.4
- Dart: 3.9.2
- 앱 버전: 1.0.0

---

© 2026 TODOC
