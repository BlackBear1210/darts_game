"""실제 2·3·4개 ENet 프로세스로 이동/착석/5라운드/권한/시간 초과를 검증한다."""
import argparse
import math
import time
from pathlib import Path
from run_multiplayer import PROJECT, Peer, free_port, lobby_count, wait_for


def states(peers):
    return wait_for(peers, lambda ss: all("match" in s for s in ss), "match exists")


def done(peers):
    return wait_for(peers, lambda ss: all(s["command_id"] == p.command_id for p, s in zip(peers, ss)), "command handled")


def pose(state, identity):
    return next(p for p in state["poses"] if p["id"] == identity)


def start(engine, folder, count, afk=False):
    peers = []
    port = free_port()
    try:
        peers.append(Peer(engine, folder, 0, port, "host", fast_match=True, afk_match=afk))
        wait_for(peers, lambda ss: lobby_count(ss, 1), "host")
        for index in range(1, count):
            peers.append(Peer(engine, folder, index, port, "client", fast_match=True))
        wait_for(peers, lambda ss: lobby_count(ss, count), "join")
        for p in peers:
            p.command("ready", True)
        wait_for(peers, lambda ss: all(all(p["ready"] for p in s["room"]["players"]) for s in ss), "ready")
        peers[0].command("start")
        wait_for(peers, lambda ss: all(s.get("match", {}).get("phase") == 2 for s in ss), "aiming")
        return peers
    except BaseException:
        for peer in peers:
            peer.stop()
        raise


# 라운지에서 다트 홀로 나가는 옆길(테이블과 바 / NPC 테이블 사이). TableView 배치에 맞춘 값이다.
LANE_LEFT = -3.0
LANE_RIGHT = 3.0
# 투척선 뒤에 서는 자리(TableView.THROW_LINE_Z = -4.05 보다 뒤).
OCHE = (0.0, -3.5)


def walk(peers, peer, identity, target, tolerance=0.5, steps=60):
    """실제 이동 명령으로 목표까지 걸어간다(순간이동 금지). 도착하면 True."""
    for _ in range(steps):
        p = pose(states(peers)[0], identity)["position"]
        dx, dz = target[0] - p[0], target[1] - p[2]
        if math.hypot(dx, dz) < tolerance:
            peer.command("stop")
            done(peers)
            return True
        length = max(1.0, math.hypot(dx, dz))
        peer.command("move", [dx / length, dz / length, 0, False, False])
        time.sleep(0.1)
    peer.command("stop")
    done(peers)
    return False


def walk_to_oche(peers, peer, identity, seat_xz):
    """2026-10-28 규칙: 라운지에서는 못 던진다. 테이블을 피해 옆길로 돌아 투척선 뒤까지 간다."""
    p = pose(states(peers)[0], identity)["position"]
    if p[2] > -0.2:
        lane = LANE_LEFT if seat_xz[0] <= 0 else LANE_RIGHT
        assert walk(peers, peer, identity, (lane, p[2])), ("옆길로 못 나왔다", identity)
        assert walk(peers, peer, identity, (lane, 0.6)), ("단차 앞까지 못 갔다", identity)
    assert walk(peers, peer, identity, OCHE, tolerance=0.6), ("투척선까지 못 갔다", identity)


def walk_to_seat(peers, peer, identity, seat_xz):
    """다트 홀에서 자기 자리로 돌아가 앉는다(테이블 집합에 지각하지 않게)."""
    p = pose(states(peers)[0], identity)["position"]
    lane = LANE_LEFT if seat_xz[0] <= 0 else LANE_RIGHT
    if p[2] < 0.2:
        assert walk(peers, peer, identity, (lane, 0.6)), ("라운지로 못 돌아왔다", identity)
        assert walk(peers, peer, identity, (lane, seat_xz[1])), ("자리 옆까지 못 갔다", identity)
    assert walk(peers, peer, identity, seat_xz, tolerance=0.45), ("자리까지 못 갔다", identity)
    peer.command("seat")
    done(peers)


def rejected(peers, peer, value):
    before = states(peers)[0]["match"]
    peer.command("raw_throw", value)
    done(peers)
    time.sleep(0.18)
    after = states(peers)[0]["match"]
    assert after == before, ("invalid request mutated match", before, after)


def run_match(engine, folder, count):
    peers = start(engine, folder, count)
    try:
        ss = states(peers)
        ids = [s["local_id"] for s in ss]
        first = ss[0]["match"]
        # 착석은 투척 조건이 아니며, 다른 사람 차례의 요청만 거부한다.
        peers[1].command("throw", [0, 0, 1])
        done(peers)
        time.sleep(0.2)
        assert states(peers)[0]["match"] == first
        # 실제 원격 입력은 해당 발신자의 캐릭터만 움직인다.
        before_host = pose(ss[0], ids[0])["position"]
        before_client = pose(ss[0], ids[1])["position"]
        peers[1].command("move", [-1, 0, 0, True, True])
        wait_for(peers, lambda ss: all(pose(s, ids[1])["crouched"] and pose(s, ids[1])["position"][1] > 0.1 for s in ss), "remote jump+crouch")
        time.sleep(0.25)
        peers[1].command("stop")
        done(peers)
        time.sleep(0.5)
        ss = states(peers)
        client_pos = pose(ss[0], ids[1])["position"]
        assert abs(client_pos[0] - before_client[0]) > 0.15
        assert math.dist(pose(ss[0], ids[0])["position"], before_host) < 0.1
        for s in ss[1:]:
            assert math.dist(pose(s, ids[1])["position"], client_pos) < 0.12
        # 이동한 사람이 자기 자리로 직접 돌아온다. 위치를 순간이동시키지 않는다.
        # TableView.SEATS 와 같아야 한다(2026-10-28 도면 방, 1.5배 확대).
        seats = [(-1.5, 4.4), (0, 5.65), (1.5, 4.4), (0, 3.2)]
        seat = next(p["seat"] for p in ss[0]["room"]["players"] if p["peer_id"] == ids[1])
        target_x, target_z = seats[seat]
        for _ in range(40):
            p = pose(states(peers)[0], ids[1])["position"]
            dx, dz = target_x - p[0], target_z - p[2]
            if math.hypot(dx, dz) < 0.5:
                break
            length = max(1, math.hypot(dx, dz))
            peers[1].command("move", [dx / length, dz / length, 0, False, False])
            time.sleep(0.12)
        peers[1].command("stop")
        done(peers)
        time.sleep(0.25)
        seated_ids = set(ids[1::2])
        for index, p in enumerate(peers):
            if index % 2 == 1:
                p.command("seat")
        wait_for(peers, lambda ss: all(all(p["seated"] == (p["id"] in seated_ids)
                                         for p in s["poses"]) for s in ss), "standing and seated players")
        rejected(peers, peers[1], [first["match_id"], first["turn_id"], 500, 0, 0, 1])
        rejected(peers, peers[1], [first["match_id"] - 1, first["turn_id"], 501, 0, 0, 1])
        # 자기 차례여도 라운지(테이블 쪽)에서는 방장이 투척을 거부한다.
        ss = states(peers)
        active = ss[0]["match"]["players"][ss[0]["match"]["turn_index"]]["peer_id"]
        before = ss[0]["match"]
        peers[ids.index(active)].command("throw", [0, 0, 1])
        done(peers)
        time.sleep(0.2)
        assert states(peers)[0]["match"] == before, "라운지에서 던진 다트가 받아들여졌다"
        # 5라운드 턴마다 3발, 모든 PC의 점수와 최종 적중 좌표가 같아야 한다.
        # 투척선까지 걸어 나가야 하므로 집합(fast_match 1초)에 맞춰 돌아오려면 다음 사람 차례를 빌려야 한다.
        # 턴 20초 안에 "앞사람 복귀 + 내 이동 + 3발"이 다 들어가도록 라운드마다 첫 투척자 한 명만 돌아가 앉는다.
        # 그 사람은 1.0, 나머지는 지각이라 자동 착석 + 슬로우 0.5 여야 한다.
        punctual = None
        for turn in range(count * 5):
            ss = wait_for(peers, lambda ss: all(s.get("match", {}).get("phase") == 2 and s["match"]["turn_id"] == turn + 1 for s in ss), "next turn")
            if turn > 0 and turn % count == 0:
                # 자세는 20Hz 이동 채널로 오므로 경기 스냅샷(AIMING)보다 조금 늦게 도착할 수 있다.
                ss = wait_for(peers, lambda ss: all(all(p["seated"] for p in s["poses"]) for s in ss), "late players auto-seated")
                assert all(all(p["speed_scale"] == (1.0 if p["peer_id"] == punctual else 0.5) for p in s["match"]["players"]) for s in ss), ("집합 슬로우", punctual)
            active = ss[0]["match"]["players"][ss[0]["match"]["turn_index"]]["peer_id"]
            peer = peers[ids.index(active)]
            seat_xz = seats[next(p["seat"] for p in ss[0]["room"]["players"] if p["peer_id"] == active)]
            # 앉아 있으면 일어나서 투척선까지 걸어 나간다.
            if pose(states(peers)[0], active)["seated"]:
                peer.command("seat")
                done(peers)
            walk_to_oche(peers, peer, active, seat_xz)
            for dart_index in range(3):
                # 투척선에서 과녁까지 2m라 비행이 0.3초다. 명령 파일 왕복(~0.2초)보다 짧아
                # "비행 중 중복 요청"을 여기서 재현할 수 없다(두 번째가 비행이 끝난 뒤 도착해 정상 투척이 된다).
                # 비행 중 잠금은 tests/test_prototype.gd 가 같은 프로세스에서 확정적으로 검사한다.
                # 여기서는 한 발이 정확히 50점씩만 더해지는지(누적 합)로 추가 투척이 없음을 본다.
                peer.command("throw", [0, 0, 1])
                done(peers)
                ss = wait_for(peers, lambda ss: all(s["match"].get("last_hit", {}).get("peer_id") == active and s["match"]["last_hit"].get("points") == 50 and sum(p["score"] for p in s["match"]["players"]) == (turn * 3 + dart_index + 1) * 50 for s in ss), "single score synchronized")
                assert all(s["match"]["last_hit"] == ss[0]["match"]["last_hit"] for s in ss)
                if dart_index < 2:
                    assert all(s["match"]["turn_id"] == turn + 1 and s["match"]["darts_left"] == 2 - dart_index for s in ss)
            # 라운드의 첫 투척자만 다음 사람 차례 동안 자리로 돌아가 앉는다(지각하지 않는 한 명).
            if turn % count == 0:
                walk_to_seat(peers, peer, active, seat_xz)
                punctual = active
        ss = wait_for(peers, lambda ss: all(s["match"]["phase"] == 6 for s in ss), "finished")
        assert all([p["score"] for p in s["match"]["players"]] == [750] * count for s in ss)
        peers[1].command("restart")
        done(peers)
        assert states(peers)[0]["match"]["phase"] == 6
        peers[0].command("restart")
        wait_for(peers, lambda ss: all(s["match"]["phase"] == 2 and s["match"]["round"] == 1 and not s["match"]["last_hit"] and all(p["score"] == 0 for p in s["match"]["players"]) for s in ss), "rematch reset")
        print(f"PASS: {count} real peers, walk from the table to the oche each turn, lounge throw rejected, movement/jump/crouch, ownership, invalid requests, table gathering auto-seat/slow, 5 rounds, identical impact/score, one dart per request, rematch", flush=True)
    finally:
        for p in peers:
            p.stop()


def timeout(engine, folder):
    peers = start(engine, folder, 2)
    try:
        start_time = time.monotonic()
        ss = wait_for(peers, lambda ss: all(s["match"]["turn_id"] >= 2 for s in ss), "real twenty second timeout", timeout=23)
        assert 17 < time.monotonic() - start_time < 23
        assert all(sum(p["score"] for p in s["match"]["players"]) == 0 for s in ss)
        assert all(s["match"]["last_hit"]["reason"] == "시간 초과 · 0점" for s in ss)
        print("PASS: actual 20 second unseated timeout -> zero and next turn", flush=True)
    finally:
        for p in peers:
            p.stop()


def bots(engine, folder):
    port = free_port()
    peers = [Peer(engine, folder, 0, port, "host")]
    try:
        wait_for(peers, lambda ss: lobby_count(ss, 1), "bot host")
        peers[0].command("bots")
        wait_for(peers, lambda ss: lobby_count(ss, 4) and sum(p["bot"] for p in ss[0]["room"]["players"]) == 3, "bots filled")
        for index in range(1, 4):
            peers.append(Peer(engine, folder, index, port, "client"))
            wait_for(peers, lambda ss: lobby_count(ss, 4) and all(sum(p["bot"] for p in s["room"]["players"]) == 3 - index for s in ss), "human replaces bot")
        assert all(p["peer_id"] > 0 for p in peers[0].status()["room"]["players"])
        print("PASS: three real clients replace stationary bots in lobby, total stays four", flush=True)
    finally:
        for p in peers:
            p.stop()


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--godot", type=Path, required=True)
    args = parser.parse_args()
    results = PROJECT / ".godot" / "prototype_tests" / str(time.time_ns())
    results.mkdir(parents=True)
    for count in (2, 3, 4):
        folder = results / str(count)
        folder.mkdir()
        run_match(args.godot, folder, count)
    for name, run in (("timeout", timeout), ("bots", bots)):
        folder = results / name
        folder.mkdir()
        run(args.godot, folder)
    for path in results.rglob("*.log"):
        errors = [line for line in path.read_text(encoding="utf-8").splitlines() if ("ERROR:" in line or "SCRIPT ERROR:" in line) and "root certificate store" not in line]
        assert not errors, (path, errors)
    print(f"All checks passed. Logs: {results}", flush=True)

if __name__ == "__main__":
    main()
