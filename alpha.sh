#!/bin/bash

# 루트 권한 확인
if [ "$EUID" -ne 0 ]; then 
    echo "이 스크립트는 루트 권한으로 실행되어야 합니다."
    exit 1
fi

# 한국어 폰트 설치
echo "한국어 폰트를 설치합니다..."
pacman -Sy --noconfirm noto-fonts-cjk adobe-source-han-sans-kr-fonts adobe-source-han-serif-kr-fonts ttf-baekmuk

# 폰트 캐시 업데이트
echo "폰트 캐시를 업데이트합니다..."
fc-cache -fv

# 로케일 설정
echo "로케일을 한국어로 설정합니다..."
sed -i '/ko_KR.UTF-8/s/^#//g' /etc/locale.gen
locale-gen
echo "LANG=ko_KR.UTF-8" > /etc/locale.conf
export LANG=ko_KR.UTF-8

# 시스템 폰트 설정
echo "시스템 폰트를 설정합니다..."
mkdir -p /etc/fonts/conf.d
cat > /etc/fonts/conf.d/99-korean-fonts.conf <<EOF
<?xml version="1.0"?>
<!DOCTYPE fontconfig SYSTEM "fonts.dtd">
<fontconfig>
    <!-- 기본 폰트 설정 -->
    <match>
        <edit name="family" mode="prepend" binding="strong">
            <string>Noto Sans CJK KR</string>
            <string>Source Han Sans KR</string>
            <string>Baekmuk Gulim</string>
        </edit>
    </match>

    <!-- 한국어 폰트 우선 순위 설정 -->
    <match>
        <test name="lang" compare="contains">
            <string>ko</string>
        </test>
        <edit name="family" mode="prepend" binding="strong">
            <string>Noto Sans CJK KR</string>
            <string>Source Han Sans KR</string>
            <string>Baekmuk Gulim</string>
        </edit>
    </match>
</fontconfig>
EOF

# 폰트 서비스 재시작
echo "폰트 서비스를 재시작합니다..."
fc-cache -fv

# 테스트 메시지 출력
echo "한국어 지원 테스트:"
echo "안녕하세요, Arch Linux!"
sleep 2

echo "한국어 폰트 설정이 완료되었습니다."
