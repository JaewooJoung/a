#!/bin/bash

# TypeScript 프로젝트 설정 스크립트
# Arch Linux에서 TypeScript 개발 환경을 설정합니다

# 1. 공식 저장소에서 Node.js와 npm 설치
# Node.js와 npm을 시스템에 설치합니다
sudo pacman -S nodejs npm

# 2. 프로젝트 디렉토리 생성
# 새로운 TypeScript 프로젝트 폴더를 만들고 이동합니다
mkdir my-typescript-project
cd my-typescript-project

# 3. npm 프로젝트 초기화
# package.json 파일을 자동으로 생성합니다 (-y 옵션으로 기본 설정 사용)
npm init -y

# 4. TypeScript 로컬 설치 (권장 방법)
# 개발 의존성으로 TypeScript, ts-node, Node.js 타입 정의를 설치합니다
npm install --save-dev typescript ts-node @types/node

# 5. TypeScript 설정 파일 초기화
# tsconfig.json 파일을 생성합니다 (TypeScript 컴파일러 설정)
npx tsc --init

# 6. TypeScript 파일 생성 및 테스트
# 간단한 TypeScript 예제 파일을 생성하고 실행합니다
echo 'console.log("Hello from TypeScript on Arch!");' > index.ts
npx ts-node index.ts

# 스크립트 완료 메시지
echo "TypeScript 프로젝트 설정이 완료되었습니다!"
echo "프로젝트 디렉토리: $(pwd)"
echo "다음 명령어로 프로젝트를 실행할 수 있습니다: npx ts-node index.ts"
