"""실제 ENet 4프로세스로 서로 다른 3인의 협동 방해와 중복 거절을 확인한다."""
import argparse
import math
import time
from pathlib import Path
from run_multiplayer import PROJECT, Peer, free_port, wait_for


def player(state, peer_id):
    return next(p for p in state["match"]["players"] if p["peer_id"] == peer_id)


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--godot", type=Path, required=True)
    args = parser.parse_args()
    output = PROJECT / ".godot" / "synergy_network" / str(time.time_ns())
    output.mkdir(parents=True)
    peers = []
    port = free_port()
    try:
        peers.append(Peer(args.godot, output, 0, port, "synergy_host"))
        wait_for(peers, lambda ss: ss[0]["markers"] == 1, "host map")
        for index in range(1, 4):
            peers.append(Peer(args.godot, output, index, port, "client"))
        wait_for(peers, lambda ss: all(s["markers"] == 4 for s in ss), "four players join")
        for peer in peers:
            peer.command("seat")
        wait_for(peers, lambda ss: all(all(p["seated"] for p in s["poses"]) for s in ss), "all seated")
        for peer in peers:
            peer.command("ready", True)
        wait_for(peers, lambda ss: all(s.get("match", {}).get("phase") == 2 for s in ss), "dart phase", timeout=20)
        for count, peer in enumerate(peers[1:], 1):
            peer.command("card", ["select", 0])
            wait_for(peers, lambda ss: all(player(s, peer.status()["local_id"])["pending_card"] >= 0 for s in ss), "remote selected")
            time.sleep(1.35)
            peer.command("card", ["use", 1])
            states = wait_for(peers, lambda ss: all(s["match"]["players"][0]["card_effects"].get("synergies", {}).get("wind", {}).get("players") == count for s in ss), "cooperative stage replicated")
            for state in states:
                effects = state["match"]["players"][0]["card_effects"]
                assert math.isclose(abs(effects["push"]), .32 * (1 + .5 * (count - 1)))
                assert len(player(state, peer.status()["local_id"])["hand"]) == 6
            assert all(s["match"]["players"] == states[0]["match"]["players"] for s in states)
        repeated = peers[1]
        repeated.command("card", ["select", 0])
        wait_for(peers, lambda ss: all(player(s, repeated.status()["local_id"])["pending_card"] >= 0 for s in ss), "repeat selected")
        time.sleep(1.35)
        repeated.command("card", ["use", 1])
        wait_for([repeated], lambda ss: ss[0]["command_id"] == repeated.command_id, "repeat request processed")
        time.sleep(.3)
        assert all(len(player(p.status(), repeated.status()["local_id"])["hand"]) == 6 for p in peers)
        assert all(p.status()["match"]["players"][0]["card_effects"]["synergies"]["wind"]["players"] == 3 for p in peers)
        print("PASS: real four-peer 1/2/3-contributor wind, 1.0/1.5/2.0 strength, equal snapshots and repeat-card preservation", flush=True)
    finally:
        for peer in peers:
            peer.stop()
    for path in output.glob("*.log"):
        errors = [line for line in path.read_text(encoding="utf-8").splitlines() if ("ERROR:" in line or "SCRIPT ERROR:" in line) and "root certificate store" not in line]
        assert not errors, (path, errors)
    print("All synergy checks passed. Logs:", output, flush=True)


if __name__ == "__main__":
    main()
