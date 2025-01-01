if [ "$EUID" -ne 0 ]; then 
    echo "root 권한으로 실행해주세요"
    exit 1
fi

# 한국어 환경 설정
echo "한국어 환경을 설정합니다..."
echo "ko_KR.UTF-8 UTF-8" >> /etc/locale.gen
locale-gen
export LANG=ko_KR.UTF-8
setfont ter-132n # 한글 폰트 설정

# 1. 하드드라이브 표시
echo "시스템에서 사용 가능한 하드드라이브 목록:"
drives=($(lsblk -d -o NAME,SIZE,TYPE | grep disk | nl -w2 -s'. ' | awk '{print $2}'))
lsblk -d -o NAME,SIZE,TYPE | grep disk | nl -w2 -s'. '

# 2. 드라이브 선택
read -p "설치할 하드드라이브 번호를 선택하세요 (예: 1, 2): " choice

# 3. 선택 검증
if [[ $choice -gt 0 && $choice -le ${#drives[@]} ]]; then
    DEVICE="/dev/${drives[$choice-1]}"
    echo "선택된 하드드라이브: $DEVICE"
else
    echo "잘못된 번호입니다. 종료합니다..."
    exit 1
fi

# CPU 종류 선택
echo "CPU 종류를 선택하세요:"
echo "1. 인텔 (Intel)"
echo "2. AMD"
read -p "선택하세요 (1 또는 2): " cpu_choice

case $cpu_choice in
    1)
        CPU_UCODE="intel-ucode"
        ;;
    2)
        CPU_UCODE="amd-ucode"
        ;;
    *)
        echo "잘못된 선택입니다. 종료합니다..."
        exit 1
        ;;
esac

# 사용자 정보 입력
# 사용자 이름 입력
while true; do
   read -p "사용자 이름을 입력하세요: " input_username
   if [ -n "$input_username" ]; then
       USERNAME="$input_username"
       break
   else
       echo "사용자 이름은 비워둘 수 없습니다. 다시 시도하세요."
   fi
done

# 호스트명 입력
while true; do
   read -p "호스트명을 입력하세요: " input_hostname
   if [ -n "$input_hostname" ]; then
       HOSTNAME="$input_hostname"
       break
   else
       echo "호스트명은 비워둘 수 없습니다. 다시 시도하세요."
   fi
done

# root 비밀번호 설정
while true; do
   read -s -p "root 비밀번호를 입력하세요: " input_root_pass
   echo
   read -s -p "root 비밀번호를 다시 입력하세요: " input_root_pass2
   echo
   
   if [ -z "$input_root_pass" ]; then
       echo "비밀번호는 비워둘 수 없습니다. 다시 시도하세요."
       continue
   fi
   
   if [ "$input_root_pass" = "$input_root_pass2" ]; then
       ROOT_PASSWORD="$input_root_pass"
       break
   else
       echo "비밀번호가 일치하지 않습니다. 다시 시도하세요."
   fi
done

# 사용자 비밀번호 설정
while true; do
   read -s -p "사용자 비밀번호를 입력하세요: " input_user_pass
   echo
   read -s -p "사용자 비밀번호를 다시 입력하세요: " input_user_pass2
   echo
   
   if [ -z "$input_user_pass" ]; then
       echo "비밀번호는 비워둘 수 없습니다. 다시 시도하세요."
       continue
   fi
   
   if [ "$input_user_pass" = "$input_user_pass2" ]; then
       USER_PASSWORD="$input_user_pass"
       break
   else
       echo "비밀번호가 일치하지 않습니다. 다시 시도하세요."
   fi
done

# 설치 계획 표시
echo "==========================="
echo "설치 계획:"
echo "디바이스: ${DEVICE}"
echo "EFI 파티션: ${EFI_PART}"
echo "스왑 파티션: ${SWAP_PART}"
echo "루트 파티션: ${ROOT_PART}"
echo "사용자 이름: ${USERNAME}"
echo "호스트명: ${HOSTNAME}"
echo "CPU 종류: ${CPU_UCODE}"
echo "==========================="
echo "경고: 선택한 드라이브의 모든 데이터가 삭제됩니다!"
echo "취소하려면 5초 이내에 Ctrl+C를 누르세요..."
sleep 5

# 디스크 초기화 중...
echo "디스크를 초기화합니다..."

[이후 설치 과정 메시지들...]

# 최종 메시지
echo "설치가 완료되었습니다!"
echo ""
echo "중요한 설치 후 단계:"
echo "1. 컴퓨터를 완전히 종료하세요 (재부팅 아님)"
echo "2. USB 설치 미디어를 제거하세요"
echo "3. BIOS 설정에서 다음 사항을 변경하세요:"
echo "   a. BIOS 기본값을 먼저 로드하세요"
echo "   b. 보안 부팅(Secure Boot)을 비활성화하세요"
echo "   c. UEFI 부팅 모드로 설정하세요 (CSM/Legacy 완전히 비활성화)"
echo "   d. 부팅 장치 우선순위를 ${DEVICE}로 설정하세요"
echo ""
echo "첫 부팅 후 할 일:"
echo "1. 한글 입력은 Shift+Space로 전환할 수 있습니다"
echo "2. 입력기 설정은 'fcitx5-configtool'로 할 수 있습니다"
echo "3. 문제가 있다면 'fcitx5 --debug &'로 디버깅할 수 있습니다"
