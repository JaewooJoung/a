# Arch(아치리눅스) installation made easy. (한글🇰🇷화 된 리눅스 자동설치)
유튜브 좋아하시는 분들은 유튜브 보고 따라 하시면 됩니다. 😘

## Arch Linux 설치 가이드

### 1. 인터넷 연결

유선 인터넷의 경우 자동으로 연결됩니다.

무선 인터넷 연결이 필요한 경우:<br>
<img src="https://jaewoojoung.github.io/a/internet.png" alt="인터넷선이 없으면.." width="600"/> 
```bash
iwctl
station wlan0 connect [WIFI이름]
[패스워드][엔터]
[quit][엔터]
```

### 2. 설치 스크립트 다운로드

다음 명령어를 실행하여 설치 스크립트를 다운로드합니다:
```bash
curl -O https://jaewoojoung.github.io/a/install.sh
```

### 3. 스크립트 실행

스크립트에 실행 권한을 부여하고 실행합니다:
```bash
chmod +x install.sh && bash install.sh
```

---
# 🚀 아치리눅스 자동 설치 가이드

## 📝 소개
이 가이드는 아치리눅스를 쉽고 재미있게 설치할 수 있도록 도와주는 자동 설치 스크립트 사용법을 설명합니다.

## ⚠️ 시작하기 전에
- UEFI 모드로 부팅해야 합니다
- 인터넷 연결이 필요합니다
- USB로 부팅된 아치리눅스 환경이 필요합니다
- **주의**: 선택한 디스크의 모든 데이터가 삭제됩니다!

## 🎮 설치 과정

### 설치 단계별 가이드
1. **시스템 확인** 🔍
   - UEFI 모드 확인
   - 키보드 레이아웃 설정 (기본: US)

2. **하드드라이브 선택** 💽
   - 시스템의 모든 하드드라이브 목록이 표시됨
   - 번호로 설치할 드라이브 선택
   ```
   예시:
   1. sda      500GB  disk
   2. nvme0n1   1TB  disk
   ```

3. **CPU 선택** 🔧
   ```
   1. Intel
   2. AMD
   ```

4. **계정 설정** 👤
   - 사용자 이름 입력
   - 컴퓨터 이름(hostname) 입력
   - root 비밀번호 설정
   - 사용자 비밀번호 설정

5. **설치 계획 확인** 📋
   - 선택한 설정들 확인
   - 5초 카운트다운 (취소하려면 Ctrl+C)

### 4️⃣ 자동 설치 진행 🚀
스크립트가 자동으로 다음을 수행합니다:
- 디스크 파티셔닝
- 기본 시스템 설치
- 한글 환경 설정
- KDE Plasma 데스크톱 설치
- 개발 도구 설치
- 한글 입력기(fcitx5) 설정

## 🎉 설치 완료 후 할 일

### 1️⃣ 첫 부팅 전 준비
1. 컴퓨터 완전 종료
2. USB 제거
3. BIOS 설정 변경:
   - BIOS 기본값 로드
   - 보안 부팅(Secure Boot) 비활성화
   - UEFI 모드 설정
   - 부팅 순서 설정

### 2️⃣ 첫 부팅 후 설정
1. 한글 입력 활성화
   - Shift+Space로 한/영 전환
   - `fcitx5-configtool`로 추가 설정

## 🎨 설치되는 주요 프로그램들
- 🌐 Firefox, Chromium
- 📝 LibreOffice (한글 지원)
- 💻 개발 도구 (VSCode, Git 등)
- 🎨 그래픽 도구 (GIMP, Krita)
- 🔧 시스템 도구

## 💡 문제 해결
문제가 발생하면:
1. 인터넷 연결 확인
2. UEFI 모드 확인
3. `fcitx5 --debug &`로 입력기 디버깅

## 🌈 아치리눅스로 바꾼 당신은 지금 리눅스🐧의 **모든** 최신기술을 쓰시고 있습니다. 🥰
