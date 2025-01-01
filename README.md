# Arch installation made easy. (한글🇰🇷 자동설치)

## Arch Linux 설치 가이드

### 1. 인터넷 연결

유선 인터넷의 경우 자동으로 연결됩니다.

무선 인터넷 연결이 필요한 경우:
```bash
iwctl
station wlan0 connect [WIFI이름]
```

### 2. 설치 스크립트 다운로드

다음 명령어를 실행하여 설치 스크립트를 다운로드합니다:
```bash
curl -O https://jaewoojoung.github.io/markdown/ist/arch_install.sh
```

### 3. 스크립트 실행

스크립트에 실행 권한을 부여하고 실행합니다:
```bash
chmod +x arch_install.sh
./arch_install.sh
```

---
**주의**:  앞으로 주의할것을 여기에 쓰겠습니다. 
