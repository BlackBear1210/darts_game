# 전용 서버 첫 번째 목표

하나의 서버 프로세스가 하나의 방을 소유한다. 서버는 선수 자리를 차지하지 않으며 실제 클라이언트 2~4명이 참가한다. 현재 규칙인 자유 이동, 턴당 3발, 5라운드, 누적 점수를 그대로 사용한다.

## 실행 파일

Godot 루트 `다트-/` 기준:

- 서버: `output/builds/server/DartPartyServer.exe`와 같은 폴더의 `.pck`.
- 플레이어: `output/builds/client/DartParty.exe`와 같은 폴더의 `.pck`.
- 자동 검증 전용: `output/builds/verification/`. 팀원에게 배포하는 플레이어 빌드와 구분한다.

PowerShell에서 서버를 실행한다. 경로는 프로젝트 루트 기준이다.

```powershell
& './output/builds/server/DartPartyServer.console.exe' -- --port 7000
```

서버 빌드는 `dedicated_server` feature로 창 없이 시작한다. 기본 포트는 UDP 7000이다. 잘못된 포트나 바인딩 실패 시 종료 코드 1을 반환한다. 로그 파일을 지정하려면 `--log-file '절대경로/server.log'`를 `--` 앞에 넣는다.

기본 실행은 콘솔 출력만 사용한다. Godot 4.6.3은 기본 파일 로그를 열지 못하면 게임 시작 전에 접근 위반으로 종료되는 경로가 있어 자동 파일 로그를 껐다. 콘솔 EXE에서 `Dedicated server listening on UDP 7000`을 확인한다. 파일 로그가 필요하면 쓰기 가능한 경로를 명시한다. 예를 들어 프로젝트 루트에서:

```powershell
New-Item -ItemType Directory -Force output/builds/server/logs | Out-Null
$serverLog = Join-Path (Get-Location) 'output/builds/server/logs/server.log'
& './output/builds/server/DartPartyServer.console.exe' --log-file $serverLog -- --port 7000
```

`--log-file`에 쓰기 불가능한 경로를 지정하면 같은 엔진 문제가 발생할 수 있다. 위 `logs/`는 빌드 폴더와 함께 Git에서 제외한다.

플레이어는 `DartParty.exe`를 실행하고 이름·서버 IP·포트를 입력해 **방 참가**를 누른다. 같은 PC면 `127.0.0.1`, 다른 PC면 서버 PC의 LAN IP다. 전용 서버에 접속할 때는 **방 만들기**를 누르지 않는다. 모두 준비 후 첫 접속자가 **함께 시작**을 누른다.

방장이 나가면 남은 첫 참가자가 방장을 이어받는다. 서버 프로세스는 유지된다. 전원 이탈하면 빈 로비로 돌아가 재사용한다. 경기 중 새 참가와 다섯 번째 참가는 거부한다. 서버 자체가 종료되면 참가자들은 연결 종료 안내를 받는다.

LAN 접속에는 서버 PC의 해당 UDP 포트 수신 허용이 필요하다. 외부 인터넷 직접 접속은 공인 주소와 포트 접근성을 별도로 준비해야 한다.

## 다시 내보내기

Godot 4.6.3과 같은 버전의 Windows export templates가 필요하다. `$godot`에는 로컬 콘솔 실행 파일의 절대 경로를 지정한다.

```powershell
New-Item -ItemType Directory -Force output/builds/client, output/builds/server, output/builds/verification | Out-Null
& $godot --headless --path . --export-release 'Windows Server'
& $godot --headless --path . --export-release 'Windows Client'
& $godot --headless --path . --export-debug 'Windows Verification'
```

플레이어 Release 빌드는 자동 봇 입장을 하지 않는다. 서버·플레이어 배포본에는 `tests/`를 포함하지 않는다. 검증 빌드는 `verification` feature의 시작 Scene에서 파일 명령 기반 실제 ENet 시험을 수행한다. 에디터 CLI와 같은 `tests/network_probe.gd`를 사용한다.

```powershell
python tests/run_dedicated.py --server output/builds/server/DartPartyServer.exe --client output/builds/verification/DartPartyTest.exe
python tests/check_export_startup.py --server output/builds/server/DartPartyServer.exe --client output/builds/client/DartParty.exe
```

시험은 에디터를 실행하지 않고 내보낸 서버와 클라이언트 프로세스를 실행한다. 결과와 엔진 로그는 `.godot/dedicated_tests/`에 저장한다. 이동·투척은 자동 입력이므로 사람의 수동 조작감 검증과 구분한다.

자동 시험은 서버가 선수 목록에 없는지, 방장 외 관리 요청 거부, 자유 이동 동기화, 턴당 3발·5라운드·동일 적중/점수, 재경기, 방장 이전, 전원 이탈 후 재접속을 확인한다. 4인 시험에는 다섯 번째 접속과 경기 중 참가 거부도 포함한다.

서버는 `--headless`나 `--log-file`을 추가하지 않은 기본 실행 경로로 검사하고 콘솔 출력을 수집한다. 시작 회귀 시험은 서버/콘솔/실제 D3D12 플레이어 기본 실행과 명시적 파일 로그 저장을 확인한다.

## 범위

현재는 직접 IP로 접속하는 단일 방 서버다. 추가된 로컬 계정 API·SQLite 전적 저장은 [BACKEND_DEV.md](BACKEND_DEV.md)를 따른다. Steam 인증·초대·로비 검색·중계, 외부 운영 DB, 여러 방 할당과 자동 확장은 후속 작업이다.

구현 기준: [Godot 4.6 전용 서버 내보내기 공식 문서](https://docs.godotengine.org/en/4.6/tutorials/export/exporting_for_dedicated_servers.html).

로그 설정: [Godot 4.6 ProjectSettings](https://docs.godotengine.org/en/4.6/classes/class_projectsettings.html#class-projectsettings-property-debug-file-logging-enable-file-logging), 충돌 경로: [Godot 4.6.3 logger.cpp](https://github.com/godotengine/godot/blob/4.6.3-stable/core/io/logger.cpp#L155).
