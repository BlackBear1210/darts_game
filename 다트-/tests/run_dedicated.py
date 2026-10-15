"""에디터 없이 export template 실행 파일 서버 + 실제 클라이언트를 검증한다."""

import argparse
import math
import subprocess
import time
from pathlib import Path

from run_multiplayer import PROJECT, Peer, assert_unchanged, free_port, lobby_count, playing, wait_for


def run(server, client, folder, count, lifecycle_only=False):
    port = free_port()
    peers = []
    extras = []
    log = (folder / "server.log").open("w", encoding="utf-8")
    process = subprocess.Popen(
        [str(server), "--", "--port", str(port)],
        cwd=server.parent, stdout=log, stderr=subprocess.STDOUT,
        creationflags=getattr(subprocess, "CREATE_NO_WINDOW", 0),
    )
    try:
        deadline = time.monotonic() + 12
        # 기본 실행 경로도 검증한다. --log-file로 시작 오류를 우회하지 않는다.
        while "Dedicated server listening" not in (folder / "server.log").read_text(encoding="utf-8"):
            assert process.poll() is None, "server startup failed"
            assert time.monotonic() < deadline, "server startup timeout"
            time.sleep(0.1)
        for index in range(count):
            peers.append(Peer(client, folder, index, port, "client", exported=True))
            wait_for(peers, lambda ss: lobby_count(ss, index + 1), "dedicated roster")
        ss = [p.status() for p in peers]
        ids = [s["local_id"] for s in ss]
        assert 1 not in ids
        assert all(s["room"]["host_peer_id"] == ids[0] for s in ss)
        for p in peers:
            p.command("ready", True)
        wait_for(peers, lambda ss: all(all(p["ready"] for p in s["room"]["players"]) for s in ss), "ready")
        if count == 4:
            extra = Peer(client, folder, 4, port, "client", exported=True)
            extras.append(extra)
            wait_for([extra], lambda ss: ss[0]["local_id"] == 0 and not ss[0]["connecting"] and "가득" in ss[0]["message"], "fifth player rejected")
        peers[1].command("raw_room_action", "start")
        assert_unchanged(peers, 0, "nonleader start rejected")
        peers[0].command("start")
        ss = wait_for(peers, lambda ss: playing(ss, count, 1), "dedicated loading barrier")
        if count == 4:
            late = Peer(client, folder, 5, port, "client", exported=True)
            extras.append(late)
            wait_for([late], lambda ss: ss[0]["local_id"] == 0 and not ss[0]["connecting"] and "진행" in ss[0]["message"], "late join rejected")
        assert all(len(s["match"]["players"]) == count and 1 not in [p["id"] for p in s["poses"]] for s in ss)
        # 자기 차례인 첫 참가자도 자리 고정 없이 실제 서버 물리로 움직인다.
        def pose(s, peer_id):
            return next(p["position"] for p in s["poses"] if p["id"] == peer_id)
        origin = pose(ss[0], ids[0])
        other = pose(ss[0], ids[1])
        peers[0].command("move", [-1, 0, 0, False, False])
        wait_for(peers, lambda ss: all(abs(pose(s, ids[0])[0] - origin[0]) > 0.25 for s in ss), "active player free movement")
        peers[0].command("stop")
        ss = wait_for(peers, lambda ss: all(s["command_id"] == p.command_id for p, s in zip(peers, ss))
                      and all(math.dist(pose(s, ids[0]), pose(ss[0], ids[0])) < 0.12 for s in ss), "movement settles on every client")
        assert all(math.dist(pose(s, ids[1]), other) < 0.1 for s in ss)
        assert all(math.dist(pose(s, ids[0]), pose(ss[0], ids[0])) < 0.12 for s in ss)
        # 타인 투척과 로비 복귀를 거부한다.
        peers[1].command("throw", [0, 0, 1])
        wait_for([peers[1]], lambda ss: ss[0]["command_id"] == peers[1].command_id, "invalid throw received")
        time.sleep(0.2)
        peers[1].command("raw_room_action", "lobby")
        assert_unchanged(peers, 2, "nonleader lobby rejected")
        assert sum(p["score"] for p in peers[0].status()["match"]["players"]) == 0
        if not lifecycle_only:
            for turn in range(count * 5):
                ss = wait_for(peers, lambda ss: all(s["match"]["phase"] == 2 and s["match"]["turn_id"] == turn + 1 for s in ss), "next turn")
                active = ss[0]["match"]["players"][ss[0]["match"]["turn_index"]]["peer_id"]
                for dart in range(3):
                    peer = peers[ids.index(active)]
                    peer.command("throw", [0, 0, 1])
                    score = (turn * 3 + dart + 1) * 50
                    ss = wait_for(peers, lambda ss: all(sum(p["score"] for p in s["match"]["players"]) == score for s in ss), "authoritative score")
                    assert all(s["match"]["last_hit"] == ss[0]["match"]["last_hit"] for s in ss)
                    if dart < 2:
                        assert all(s["match"]["turn_id"] == turn + 1 and s["match"]["darts_left"] == 2 - dart for s in ss)
                    assert process.poll() is None
            ss = wait_for(peers, lambda ss: all(s["match"]["phase"] == 6 for s in ss), "finish")
            assert all([p["score"] for p in s["match"]["players"]] == [750] * count for s in ss)
            peers[1].command("raw_restart")
            time.sleep(0.3)
            assert peers[0].status()["match"]["phase"] == 6
            peers[0].command("restart")
            wait_for(peers, lambda ss: all(s["match"]["phase"] == 2 and all(p["score"] == 0 for p in s["match"]["players"]) for s in ss), "leader restart")
        peers[0].command("leave")
        remaining = peers[1:]
        wait_for(remaining, lambda ss: all(s["room"]["host_peer_id"] == ids[1] and len(s["room"]["players"]) == count - 1 for s in ss), "leader succession")
        remaining[0].command("lobby")
        wait_for(remaining, lambda ss: lobby_count(ss, count - 1), "new leader lobby")
        for peer in remaining:
            peer.command("leave")
        wait_for(peers, lambda ss: all(s["local_id"] == 0 for s in ss), "all leave")
        time.sleep(0.3)
        peers[0].command("join")
        wait_for([peers[0]], lambda ss: lobby_count(ss, 1) and ss[0]["room"]["host_peer_id"] == ss[0]["local_id"], "empty server reusable")
        if lifecycle_only:
            print(f"PASS dedicated lifecycle: {count} clients, permissions, join rejection, succession, simultaneous departure, reuse", flush=True)
            return
        print(f"PASS dedicated: server + {count} exported clients; movement, 3 darts, 5 rounds, 750 points each, restart, leader succession, reuse", flush=True)
    finally:
        for peer in peers + extras:
            peer.stop()
        process.terminate()
        process.wait(timeout=5)
        log.close()


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--server", type=Path, required=True)
    parser.add_argument("--client", type=Path, required=True)
    parser.add_argument("--players", type=int, nargs="+", choices=(2, 3, 4), default=(2, 3, 4))
    parser.add_argument("--lifecycle-only", action="store_true")
    args = parser.parse_args()
    results = PROJECT / ".godot" / "dedicated_tests" / str(time.time_ns())
    for count in args.players:
        folder = results / str(count)
        folder.mkdir(parents=True)
        run(args.server.resolve(), args.client.resolve(), folder, count, args.lifecycle_only)
    for path in results.rglob("*.log"):
        errors = [line for line in path.read_text(encoding="utf-8").splitlines()
                  if ("ERROR:" in line or "SCRIPT ERROR:" in line) and "root certificate store" not in line]
        assert not errors, (path, errors)
    print(f"All checks passed. Logs: {results}", flush=True)


if __name__ == "__main__":
    main()
