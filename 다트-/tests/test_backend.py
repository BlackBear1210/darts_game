"""실제 HTTP 요청과 SQLite 트랜잭션으로 로컬 API 계약을 검증한다."""

import concurrent.futures
import importlib.util
import json
import secrets
import sqlite3
import threading
import time
import unittest
import urllib.error
import urllib.request
from pathlib import Path

SPEC = importlib.util.spec_from_file_location("dart_backend", Path(__file__).resolve().parents[1] / "backend/server.py")
api = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(api)


class BackendTests(unittest.TestCase):
    def setUp(self):
        self.test_root = Path(__file__).resolve().parents[1] / ".godot/backend_unit"
        self.test_root.mkdir(parents=True, exist_ok=True)
        folder = self.test_root / secrets.token_hex(8)
        folder.mkdir()
        self.db = folder / "accounts.sqlite3"
        with sqlite3.connect(self.db) as db:
            db.executescript(api.SCHEMA)
        self.key = secrets.token_hex(32)
        self.server = api.ThreadingHTTPServer(("127.0.0.1", 0), api.Handler)
        self.server.database = self.db
        self.server.server_key = self.key
        self.server.daemon_threads = True
        self.thread = threading.Thread(target=self.server.serve_forever, daemon=True)
        self.thread.start()
        self.url = f"http://127.0.0.1:{self.server.server_port}"

    def tearDown(self):
        self.server.shutdown()
        self.server.server_close()
        self.thread.join()

    def request(self, path, body=None, token=""):
        request = urllib.request.Request(self.url + path,
            data=json.dumps(body).encode() if body is not None else None,
            headers={"Content-Type": "application/json", "Authorization": "Bearer " + token})
        try:
            with urllib.request.urlopen(request, timeout=8) as response:
                return response.status, json.load(response)
        except urllib.error.HTTPError as error:
            with error:
                return error.code, json.load(error)

    def login(self, name):
        code, body = self.request("/v1/dev/login", {"name": name, "password": "test-password-123"})
        self.assertEqual(code, 200)
        return body

    def result(self):
        accounts = [self.login(name) for name in ("Player0", "Player1")]
        body = {"rules": {"rounds": 5, "darts_per_turn": 3}, "players": [
            {"account_id": player["profile"]["account_id"], "score": 750} for player in accounts]}
        return accounts, body

    def test_login_identity_password_hash_and_expiry(self):
        first = self.login("테스터")
        second = self.login("테스터")
        self.assertEqual(first["profile"]["account_id"], second["profile"]["account_id"])
        self.assertNotEqual(first["token"], second["token"])
        self.assertEqual(self.request("/v1/dev/login", {"name": "테스터", "password": "wrong-password"})[0], 401)
        self.assertEqual(self.request("/v1/profile", token="invalid")[0], 401)
        self.assertEqual(self.request("/internal/session/verify", {"token": first["token"]}, self.key)[1]["account_id"], first["profile"]["account_id"])
        with sqlite3.connect(self.db) as db:
            self.assertEqual(db.execute("SELECT COUNT(*) FROM accounts").fetchone()[0], 1)
            self.assertNotIn(first["token"], str(db.execute("SELECT * FROM sessions").fetchall()))
            self.assertNotIn("test-password-123", str(db.execute("SELECT * FROM accounts").fetchall()))
            db.execute("UPDATE sessions SET expires=?", (int(time.time()) - 1,))
        self.assertEqual(self.request("/v1/profile", token=first["token"])[0], 401)

    def test_result_authority_idempotency_and_conflict(self):
        accounts, body = self.result()
        path = "/internal/results/" + secrets.token_hex(16)
        self.assertEqual(self.request(path, body, accounts[0]["token"])[0], 403)
        with concurrent.futures.ThreadPoolExecutor(2) as pool:
            responses = list(pool.map(lambda _: self.request(path, body, self.key), range(2)))
        self.assertTrue(all(code == 200 for code, _ in responses))
        self.assertEqual(sorted(data["duplicate"] for _, data in responses), [False, True])
        for player in body["players"]:
            player["score"] = float(player["score"])
        body["rules"] = {"rounds": 5.0, "darts_per_turn": 3.0}
        self.assertTrue(self.request(path, body, self.key)[1]["duplicate"])
        for account in accounts:
            code, saved = self.request("/v1/profile", token=account["token"])
            self.assertEqual((code, saved["matches"], saved["wins"], saved["total_score"]), (200, 1, 1, 750))
        body["players"][0]["score"] = 700
        self.assertEqual(self.request(path, body, self.key)[0], 409)

    def test_invalid_result_rolls_back(self):
        _, body = self.result()
        path = "/internal/results/" + secrets.token_hex(16)
        for value in (-1, 901, True, "750", 1.5, float("nan")):
            body["players"][0]["score"] = value
            self.assertEqual(self.request(path, body, self.key)[0], 400)
        body["players"][0]["score"] = 750
        body["players"][1]["account_id"] = "missing"
        self.assertEqual(self.request(path, body, self.key)[0], 400)
        with sqlite3.connect(self.db) as db:
            self.assertEqual(db.execute("SELECT COUNT(*) FROM matches").fetchone()[0], 0)
            self.assertEqual(db.execute("SELECT COUNT(*) FROM scores").fetchone()[0], 0)


if __name__ == "__main__":
    unittest.main(verbosity=2)
