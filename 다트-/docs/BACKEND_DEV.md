# 로컬 개발용 로그인·프로필·전적

현재 단계는 **개발 계정 로그인 → 인증된 전용 서버 참가 → 경기 결과 저장 → 재실행 후 전적 유지**다. Steam App ID 없이 실행한다. 개발 계정은 Steam 계정이 아니며 자동으로 Steam 계정으로 바꾸지 않는다.

## 실행

Godot 루트 `다트-/`에서 PowerShell 창 세 개를 열고 순서대로 실행한다. Python 3.10 이상이 필요하며 별도 pip 패키지는 없다.

```powershell
# 첫 창: 계정 API (계속 실행해 둔다)
./backend/run_local.ps1 -Role api

# 둘째 창: 인증·결과 저장이 연결된 경기 서버
./backend/run_local.ps1 -Role server

# 셋째 창: 플레이어. 인원수만큼 반복 실행
./backend/run_local.ps1 -Role player
```

Python 명령을 찾지 못하면 첫 명령에 `-PythonExe '설치된 python.exe의 절대 경로'`를 추가한다. 스크립트 실행을 허용하지 않는 PowerShell 환경에서는 `powershell -ExecutionPolicy Bypass -File ./backend/run_local.ps1 -Role api`처럼 해당 실행에만 적용할 수 있다.

플레이어 창에서 이름·8~128자 비밀번호를 입력하고 **개발 계정 로그인 / 생성**을 누른다. 처음 쓰는 이름이면 계정을 만들고, 기존 이름이면 비밀번호를 확인한다. 로그인 후 `127.0.0.1`, 포트 `7000`으로 **방 참가**한다. 전원 준비 후 첫 참가자가 시작한다. 경기 후 대기실에서 **전적 새로고침**으로 확인할 수도 있다.

API 기본 주소는 `http://127.0.0.1:8080`이다. API/경기 포트를 바꾸려면 모든 실행에 동일한 `-ApiPort`, `-GamePort`를 전달한다. 현재 API는 의도적으로 이 PC 안에서만 접속된다. 다른 PC 온라인 로그인용 배포는 후속 단계다.

## 저장 위치와 권한

| 경로/대상 | 내용 |
| --- | --- |
| `backend/data/accounts.sqlite3` | 계정·비밀번호 해시·세션 해시·경기 결과·전적. WAL/SHM도 같은 폴더 |
| `backend/data/server_key.txt` | 로컬 API와 경기 서버만 공유하는 개발용 키. 실행 스크립트가 최초 생성 |
| `output/builds/server/data/results/*.json` | 아직 백엔드가 저장 확인하지 않은 경기 결과 |
| 클라이언트 메모리 | 로그인 토큰. 파일 저장하지 않으며 실행할 때 다시 로그인 |

이 데이터 경로는 Git에서 제외한다. 백엔드 코드/DB/키는 플레이어와 서버 PCK에도 넣지 않는다. DB가 필요하면 SQLite 연결을 닫은 상태로 DB와 관련 WAL 파일을 보존해야 한다. 개발 데이터를 지우면 계정과 전적도 사라진다.

클라이언트는 DB에 접근하지 않는다. 서버가 받은 로그인 토큰을 API에서 확인하고, 확인된 계정 ID·이름을 사용한다. 같은 계정으로 같은 방에 중복 입장할 수 없다. 비밀번호는 salt + PBKDF2-SHA256, 세션은 만료시간을 가진 무작위 토큰의 SHA256 해시로 저장한다. 세션 유효기간은 24시간이다.

## 경기 결과 저장 규칙

- 현재 5라운드·턴당 3발의 정상 완주 경기만 집계한다. 봇 경기, 중도 이탈 경기, 다른 규칙은 집계하지 않는다.
- 승수는 현재 누적 점수 최고인 사람에게 반영하며 공동 최고점은 공동 승리다. 이는 현재 프로토타입 기준이고 목표 점수 근접 모드는 아직 구현하지 않았다.
- 결과 제출에는 서버 키가 필요하다. 플레이어의 로그인 토큰으로 결과를 제출할 수 없다.
- 경기마다 무작위 128bit 결과 ID를 생성한다. 재경기는 새로운 ID다. 같은 ID·같은 결과는 성공으로 응답하며 전적을 다시 올리지 않는다. 같은 ID·다른 결과는 409로 거부한다.
- 결과·참가자 점수는 하나의 DB 트랜잭션에서 저장한다. 프로필 전적은 저장된 점수를 집계한다.
- 서버는 전송 전에 결과 파일을 기록하고 성공 응답 후 삭제한다. API 연결 실패 시 5초 간격 재시도하며 서버 재시작 후에도 대기 파일을 읽어 전송한다. 결과 파일이 남아 있으면 해당 폴더를 삭제하지 않는다.

## API와 검증

| API | 권한 |
| --- | --- |
| `GET /health` | 로컬 상태 확인 |
| `POST /v1/dev/login` | 개발 계정 생성/로그인 (`name`, `password`) |
| `GET /v1/profile` | 사용자 Bearer 토큰 |
| `POST /internal/session/verify` | 서버 Bearer 키 + 사용자 토큰 |
| `POST /internal/results/{결과ID}` | 서버 Bearer 키 |

```powershell
python tests/test_backend.py
python tests/run_backend_game.py --server output/builds/server/DartPartyServer.exe --client output/builds/verification/DartPartyTest.exe
```

첫 시험은 실제 HTTP/SQLite의 권한·비밀번호·만료·점수 경계·동시 중복 처리를 확인한다. 둘째는 내보낸 서버/클라이언트로 실제 경기를 진행하고, API 장애와 경기 서버 재시작을 거쳐 결과 복구·계정 유지·중복 없는 전적을 확인한다. 시험 DB/로그는 `.godot/`에 따로 생성한다.

현재는 로컬 개발용 HTTP/SQLite 서비스다. Steam 인증·HTTPS 외부 배포·운영 DB·매치 배정·부하 수용량은 구현/검증 범위가 아니다. Steam 인증은 향후 실제 티켓을 서버에서 검증해 연결하며 SteamID 문자열만 신뢰하지 않는다. [Steam 공식 인증 문서](https://partner.steamgames.com/doc/features/auth)
