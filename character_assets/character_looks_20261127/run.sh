#!/bin/bash
# 게임 폴더(다트-) 밖 도구를 Godot 프로젝트 tests/ 에 잠깐 복사해 돌리고, 끝나면 복사본과 .uid 를 지운다(게임 폴더에 남기지 않는다).
# usage: ./run.sh [--window] <zz_스크립트 이름(확장자 없이)> [인자...]
#   예) ./run.sh zz_convert_geo "C:\...\geo.json"          (자료 만들기 — 창 없이)
#       ./run.sh --window zz_char_review turn "C:\...\out" base jun som on   (12방향 사진 — 창 모드 필수)
# 아래 세 줄을 내 컴퓨터에 맞게 고친다. Godot 는 APPDATA 를 따로 둬서 편집기 설정·최근 프로젝트를 건드리지 않는다.
HERE="$(cd "$(dirname "$0")" && pwd)"
P="$HERE/../../다트-"
G=/c/Users/Public/godot46/Godot_v4.6.3-stable_win64_console.exe
HEAD="--headless"
if [ "$1" = "--window" ]; then HEAD=""; shift; fi
NAME="$1"; shift
mkdir -p "$HERE/.appdata"
cp "$HERE/$NAME.gd" "$P/tests/"
cd "$P"
APPDATA="$(cygpath -w "$HERE/.appdata")" $G $HEAD --path . --script "res://tests/$NAME.gd" -- "$@"
code=$?
rm -f "$P/tests/$NAME.gd" "$P/tests/$NAME.gd.uid"
exit $code
