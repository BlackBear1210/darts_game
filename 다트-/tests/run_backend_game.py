"""로컬 API + 내보낸 서버/클라이언트의 로그인→경기→영구 저장 통합 시험."""

import argparse
import json
import os
import secrets
import sqlite3
import subprocess
import sys
import time
import urllib.request
from pathlib import Path

from run_multiplayer import PROJECT, Peer, free_port, lobby_count, playing, wait_for


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--server", type=Path, required=True)
    parser.add_argument("--client", type=Path, required=True)
    args = parser.parse_args()
    folder = PROJECT / ".godot/backend_tests" / str(time.time_ns())
    folder.mkdir(parents=True)
    api_port, game_port = free_port(), free_port()
    url = f"http://127.0.0.1:{api_port}"
    key = secrets.token_hex(32)
    os.environ["DART_TEST_PASSWORD"] = secrets.token_urlsafe(20)
    environment = dict(os.environ, DART_SERVER_KEY=key)
    db = folder / "accounts.sqlite3"
    api_log = (folder / "api.log").open("w", encoding="utf-8")
    server_log = (folder / "server.log").open("w", encoding="utf-8")
    processes, peers = [], []

    def boot_api():
        process = subprocess.Popen([sys.executable, str(PROJECT / "backend/server.py"), "--dev", "--port", str(api_port), "--database", str(db)],
            env=environment, stdout=api_log, stderr=subprocess.STDOUT, creationflags=getattr(subprocess, "CREATE_NO_WINDOW", 0))
        processes.append(process)
        deadline = time.monotonic() + 10
        while time.monotonic() < deadline:
            try:
                with urllib.request.urlopen(url + "/health", timeout=1) as response:
                    assert json.load(response)["status"] == "ok"
                    return process
            except OSError:
                time.sleep(0.1)
        raise AssertionError("API startup timeout")

    try:
        api_process = boot_api()
        server = args.server.resolve()
        game = subprocess.Popen([str(server), "--", "--port", str(game_port), "--backend-url", url, "--outbox-dir", str(folder / "outbox")],
            cwd=server.parent, env=environment, stdout=server_log, stderr=subprocess.STDOUT, creationflags=getattr(subprocess, "CREATE_NO_WINDOW", 0))
        processes.append(game)
        deadline = time.monotonic() + 10
        while "Dedicated server listening" not in (folder / "server.log").read_text(encoding="utf-8"):
            assert game.poll() is None and time.monotonic() < deadline
            time.sleep(0.1)
        for index in range(2):
            peers.append(Peer(args.client.resolve(), folder, index, game_port, "client", exported=True, backend_url=url))
            wait_for(peers, lambda ss: lobby_count(ss, index + 1), "authenticated registration")
        ids = [p.status()["local_id"] for p in peers]
        accounts = [p.status()["profile"]["account_id"] for p in peers]
        # 익명 참가자는 같은 서버에서 거부해야 한다.
        stranger = Peer(args.client.resolve(), folder, 9, game_port, "client", exported=True)
        peers.append(stranger)
        wait_for([stranger], lambda ss: ss[0]["local_id"] == 0 and "인증 실패" in ss[0]["message"], "anonymous rejected")
        stranger.stop()
        peers.pop()
        os.environ["DART_TEST_ACCOUNT"] = "Player0"
        try:
            duplicate = Peer(args.client.resolve(), folder, 10, game_port, "client", exported=True, backend_url=url)
        finally:
            os.environ.pop("DART_TEST_ACCOUNT", None)
        peers.append(duplicate)
        wait_for([duplicate], lambda ss: ss[0]["local_id"] == 0 and "같은 계정" in ss[0]["message"], "duplicate account rejected")
        duplicate.stop()
        peers.pop()
        for peer in peers:
            peer.command("ready", True)
        wait_for(peers, lambda ss: all(all(p["ready"] for p in s["room"]["players"]) for s in ss), "ready")
        peers[0].command("start")
        wait_for(peers, lambda ss: playing(ss, 2, 1), "playing")
        # 결과 저장 전 API를 내려도 서버의 결과 파일이 남아야 한다.
        api_process.terminate()
        api_process.wait(timeout=5)
        for turn in range(10):
            ss = wait_for(peers, lambda ss: all(s["match"]["phase"] == 2 and s["match"]["turn_id"] == turn + 1 for s in ss), "next turn")
            active = ss[0]["match"]["players"][ss[0]["match"]["turn_index"]]["peer_id"]
            for dart in range(3):
                peers[ids.index(active)].command("throw", [0, 0, 1])
                score = (turn * 3 + dart + 1) * 50
                wait_for(peers, lambda ss: all(sum(p["score"] for p in s["match"]["players"]) == score for s in ss), "score")
        wait_for(peers, lambda ss: all(s["match"]["phase"] == 6 for s in ss), "finished")
        deadline = time.monotonic() + 10
        while not list((folder / "outbox").glob("*.json")):
            assert time.monotonic() < deadline, "durable result missing"
            time.sleep(0.1)
        result_file = next((folder / "outbox").glob("*.json"))
        match_id, record = result_file.stem, json.loads(result_file.read_text(encoding="utf-8"))
        # 경기 서버도 재시작해 메모리 대기가 아닌 디스크 복구를 확인한다.
        game.terminate()
        game.wait(timeout=5)
        boot_api()
        replay = subprocess.Popen([str(server), "--", "--port", str(game_port), "--backend-url", url, "--outbox-dir", str(folder / "outbox")],
            cwd=server.parent, env=environment, stdout=server_log, stderr=subprocess.STDOUT, creationflags=getattr(subprocess, "CREATE_NO_WINDOW", 0))
        processes.append(replay)
        deadline = time.monotonic() + 15
        while time.monotonic() < deadline:
            with sqlite3.connect(db) as connection:
                if connection.execute("SELECT COUNT(*) FROM matches").fetchone()[0] == 1:
                    break
            time.sleep(0.2)
        else:
            raise AssertionError("outbox recovery failed")
        deadline = time.monotonic() + 8
        while list((folder / "outbox").glob("*.json")):
            assert time.monotonic() < deadline, "acknowledged outbox not removed"
            time.sleep(0.1)
        request = urllib.request.Request(url + "/internal/results/" + match_id, data=json.dumps(record).encode(),
            headers={"Content-Type": "application/json", "Authorization": "Bearer " + key})
        with urllib.request.urlopen(request) as response:
            assert json.load(response)["duplicate"] is True
        for peer in peers:
            peer.command("profile")
        wait_for(peers, lambda ss: all(s["profile"]["matches"] == 1 and s["profile"]["total_score"] == 750 for s in ss), "Godot profile refresh after API restart")
        for index, account in enumerate(accounts):
            request = urllib.request.Request(url + "/v1/dev/login", data=json.dumps({"name": f"Player{index}", "password": os.environ["DART_TEST_PASSWORD"]}).encode(), headers={"Content-Type": "application/json"})
            with urllib.request.urlopen(request) as response:
                saved = json.load(response)["profile"]
                assert (saved["account_id"], saved["matches"], saved["wins"], saved["total_score"]) == (account, 1, 1, 750)
        print("PASS: exported authenticated game, anonymous/duplicate account rejection, 3 darts/5 rounds, API outage, disk outbox, server/API restart, Godot profile refresh, same accounts, exactly-once profile stats", flush=True)
        print(f"Logs: {folder}", flush=True)
    finally:
        for peer in peers:
            peer.stop()
        for process in reversed(processes):
            if process.poll() is None:
                process.terminate()
                process.wait(timeout=5)
        api_log.close()
        server_log.close()


if __name__ == "__main__":
    main()
