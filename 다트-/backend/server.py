"""로컬 개발용 계정·프로필·경기 결과 API. 외부 공개/Steam 인증 서버가 아니다."""

import argparse
import hashlib
import hmac
import json
import os
import secrets
import sqlite3
import time
import uuid
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path

MAX_BODY = 16384
SESSION_SECONDS = 86400
PASSWORD_ITERATIONS = 600000

SCHEMA = """
PRAGMA journal_mode=WAL;
CREATE TABLE IF NOT EXISTS accounts (
 id TEXT PRIMARY KEY, username TEXT UNIQUE NOT NULL,
 salt BLOB NOT NULL, password_hash BLOB NOT NULL
);
CREATE TABLE IF NOT EXISTS sessions (
 token_hash TEXT PRIMARY KEY, account_id TEXT NOT NULL REFERENCES accounts(id),
 expires INTEGER NOT NULL
);
CREATE TABLE IF NOT EXISTS matches (
 id TEXT PRIMARY KEY, payload TEXT NOT NULL, created INTEGER NOT NULL
);
CREATE TABLE IF NOT EXISTS scores (
 match_id TEXT NOT NULL REFERENCES matches(id),
 account_id TEXT NOT NULL REFERENCES accounts(id), score INTEGER NOT NULL,
 PRIMARY KEY(match_id, account_id)
);
"""


class ApiError(Exception):
    def __init__(self, status, message):
        self.status = status
        self.message = message


def profile(db, account_id):
    account = db.execute("SELECT id, username FROM accounts WHERE id=?", (account_id,)).fetchone()
    stats = db.execute("""
        SELECT COUNT(*), COALESCE(SUM(score),0),
        COALESCE(SUM(score=(SELECT MAX(s.score) FROM scores s WHERE s.match_id=scores.match_id)),0)
        FROM scores WHERE account_id=?
    """, (account_id,)).fetchone()
    return {"account_id": account[0], "name": account[1], "provider": "development",
            "matches": stats[0], "total_score": stats[1], "wins": stats[2]}


def session_account(db, token):
    if not isinstance(token, str) or not 1 <= len(token) <= 256:
        raise ApiError(401, "invalid_session")
    row = db.execute("SELECT account_id FROM sessions WHERE token_hash=? AND expires>?",
                     (hashlib.sha256(token.encode()).hexdigest(), int(time.time()))).fetchone()
    if row is None:
        raise ApiError(401, "invalid_or_expired_session")
    return row[0]


def login(db, body):
    name, password = body.get("name"), body.get("password")
    if not isinstance(name, str) or not 1 <= len(name) <= 20 or name != name.strip() or not name.isprintable():
        raise ApiError(400, "name_requires_1_to_20_printable_characters")
    if not isinstance(password, str) or not 8 <= len(password) <= 128:
        raise ApiError(400, "password_requires_8_to_128_characters")
    # 첫 로그인에서 개발 계정을 생성한다. 같은 이름은 비밀번호가 일치해야 재사용한다.
    with db:
        db.execute("BEGIN IMMEDIATE")
        row = db.execute("SELECT id,salt,password_hash FROM accounts WHERE username=?", (name,)).fetchone()
        salt = row[1] if row else secrets.token_bytes(16)
        digest = hashlib.pbkdf2_hmac("sha256", password.encode(), salt, PASSWORD_ITERATIONS)
        if row:
            if not hmac.compare_digest(digest, row[2]):
                raise ApiError(401, "invalid_credentials")
            account_id = row[0]
        else:
            account_id = "dev_" + uuid.uuid4().hex
            db.execute("INSERT INTO accounts VALUES (?,?,?,?)", (account_id, name, salt, digest))
        token = secrets.token_urlsafe(32)
        expires = int(time.time()) + SESSION_SECONDS
        db.execute("DELETE FROM sessions WHERE expires<=?", (int(time.time()),))
        db.execute("INSERT INTO sessions VALUES (?,?,?)",
                   (hashlib.sha256(token.encode()).hexdigest(), account_id, expires))
    return {"token": token, "expires": expires, "profile": profile(db, account_id)}


def save_result(db, match_id, body):
    if len(match_id) != 32 or any(c not in "0123456789abcdef" for c in match_id):
        raise ApiError(400, "invalid_match_id")
    players = body.get("players")
    if body.get("rules") != {"rounds": 5, "darts_per_turn": 3}:
        raise ApiError(400, "unsupported_rules")
    if not isinstance(players, list) or not 2 <= len(players) <= 4:
        raise ApiError(400, "requires_2_to_4_players")
    cleaned = []
    for player in players:
        if not isinstance(player, dict):
            raise ApiError(400, "invalid_player")
        account_id, score = player.get("account_id"), player.get("score")
        # Godot가 대기 JSON을 다시 읽으면 정수도 float로 복원된다. 소수점이 없는 값만 허용한다.
        if not isinstance(account_id, str) or type(score) not in (int, float) or not 0 <= score <= 900 or score != int(score):
            raise ApiError(400, "invalid_score_or_account")
        cleaned.append({"account_id": account_id, "score": int(score)})
    if len({p["account_id"] for p in cleaned}) != len(cleaned):
        raise ApiError(400, "duplicate_account")
    canonical = json.dumps({"rules": {"rounds": 5, "darts_per_turn": 3},
                            "players": sorted(cleaned, key=lambda p: p["account_id"])}, sort_keys=True)
    with db:
        db.execute("BEGIN IMMEDIATE")
        previous = db.execute("SELECT payload FROM matches WHERE id=?", (match_id,)).fetchone()
        if previous:
            if previous[0] != canonical:
                raise ApiError(409, "match_result_conflict")
            return {"saved": True, "duplicate": True, "match_id": match_id}
        for player in cleaned:
            if db.execute("SELECT 1 FROM accounts WHERE id=?", (player["account_id"],)).fetchone() is None:
                raise ApiError(400, "unknown_account")
        db.execute("INSERT INTO matches VALUES (?,?,?)", (match_id, canonical, int(time.time())))
        db.executemany("INSERT INTO scores VALUES (?,?,?)",
                       [(match_id, p["account_id"], p["score"]) for p in cleaned])
    return {"saved": True, "duplicate": False, "match_id": match_id}


class Handler(BaseHTTPRequestHandler):
    def log_message(self, format, *args):
        # 토큰·비밀번호·서버 키를 출력하지 않는다.
        return

    def do_GET(self):
        self.handle_api()

    def do_POST(self):
        self.handle_api()

    def handle_api(self):
        db = None
        try:
            self.connection.settimeout(5)
            db = sqlite3.connect(self.server.database, timeout=5)
            db.execute("PRAGMA foreign_keys=ON")
            status, value = 200, self.route(db)
        except ApiError as error:
            status, value = error.status, {"error": error.message}
        except (ValueError, UnicodeError, TimeoutError):
            status, value = 400, {"error": "invalid_request"}
        except sqlite3.Error:
            status, value = 503, {"error": "database_unavailable"}
        finally:
            if db:
                db.close()
        output = json.dumps(value, ensure_ascii=False).encode()
        try:
            self.send_response(status)
            self.send_header("Content-Type", "application/json; charset=utf-8")
            self.send_header("Content-Length", str(len(output)))
            self.send_header("Cache-Control", "no-store")
            self.end_headers()
            self.wfile.write(output)
        except (BrokenPipeError, ConnectionResetError):
            pass

    def route(self, db):
        if self.command == "GET" and self.path == "/health":
            return {"status": "ok", "mode": "local-development", "protocol": 1}
        if self.command == "GET" and self.path == "/v1/profile":
            token = self.headers.get("Authorization", "").removeprefix("Bearer ")
            return profile(db, session_account(db, token))
        if self.command != "POST":
            raise ApiError(404, "not_found")
        if self.path.startswith("/internal/"):
            supplied = self.headers.get("Authorization", "").removeprefix("Bearer ")
            if not hmac.compare_digest(supplied.encode(), self.server.server_key.encode()):
                raise ApiError(403, "server_credentials_required")
        if self.headers.get_content_type() != "application/json":
            raise ApiError(415, "json_required")
        size = int(self.headers.get("Content-Length", "0"))
        if not 0 < size <= MAX_BODY:
            raise ApiError(413, "invalid_body_size")
        body = json.loads(self.rfile.read(size))
        if not isinstance(body, dict):
            raise ApiError(400, "json_object_required")
        if self.path == "/v1/dev/login":
            return login(db, body)
        if self.path == "/internal/session/verify":
            return profile(db, session_account(db, body.get("token")))
        if self.path.startswith("/internal/results/"):
            return save_result(db, self.path.removeprefix("/internal/results/"), body)
        raise ApiError(404, "not_found")


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--dev", action="store_true", help="로컬 개발 서비스임을 명시")
    parser.add_argument("--port", type=int, default=8080)
    parser.add_argument("--database", type=Path, default=Path(__file__).parent / "data/accounts.sqlite3")
    args = parser.parse_args()
    if not args.dev:
        parser.error("--dev is required; this service is local-development only")
    server_key = os.environ.get("DART_SERVER_KEY", "")
    if len(server_key) < 32 or not server_key.isascii():
        parser.error("DART_SERVER_KEY must contain at least 32 ASCII characters")
    if not 1024 <= args.port <= 65535:
        parser.error("port must be 1024~65535")
    args.database.parent.mkdir(parents=True, exist_ok=True)
    with sqlite3.connect(args.database) as db:
        db.executescript(SCHEMA)
    server = ThreadingHTTPServer(("127.0.0.1", args.port), Handler)
    server.daemon_threads = True
    server.database = args.database
    server.server_key = server_key
    print(f"Development API listening on http://127.0.0.1:{args.port}", flush=True)
    try:
        server.serve_forever()
    except KeyboardInterrupt:
        pass
    finally:
        server.server_close()


if __name__ == "__main__":
    main()
