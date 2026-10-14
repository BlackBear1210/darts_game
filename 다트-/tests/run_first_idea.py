"""실제 ENet 참가자들의 4라운드 완주와 요청 검증을 확인한다."""

import argparse
import time
from pathlib import Path

from run_multiplayer import PROJECT, Peer, free_port, lobby_count, wait_for


def current(peers):
    return wait_for(peers, lambda states: all("match" in state for state in states), "game exists")


def command_done(peers):
    return wait_for(peers, lambda states: all(state["command_id"] == peer.command_id
                                           for peer, state in zip(peers, states)), "commands handled")


def start_room(engine, folder, count, afk=False):
    peers = []
    port = free_port()
    try:
        peers.append(Peer(engine, folder, 0, port, "host", fast_match=True, afk_match=afk))
        wait_for(peers, lambda states: lobby_count(states, 1), "host")
        for index in range(1, count):
            peers.append(Peer(engine, folder, index, port, "client", fast_match=True))
        wait_for(peers, lambda states: lobby_count(states, count), "join")
        for peer in peers:
            peer.command("ready", True)
        wait_for(peers, lambda states: all(all(player["ready"] for player in state["room"]["players"])
                                          for state in states), "ready")
        peers[0].command("start")
        current(peers)
        return peers
    except BaseException:
        for peer in peers:
            peer.stop()
        raise


def same_aim(states, turn_id):
    return all(state.get("match", {}).get("phase") == 2
               and state["match"]["turn_id"] == turn_id and state["table_ready"] for state in states)


def validate_rejected_throw(peers, peer, values):
    before = current(peers)[0]["match"]
    peer.command("raw_throw", values)
    command_done(peers)
    time.sleep(0.15)
    after = peers[0].status()["match"]
    assert before["darts_left"] == after["darts_left"]
    assert [p["score"] for p in before["players"]] == [p["score"] for p in after["players"]]


def handle_cards(peers, round_number):
    states = wait_for(peers, lambda states: all(state["match"]["phase"] == 5
                      and len(state["private"]["candidates"]) == 3 for state in states), "private candidates")
    all_ids = [card["uid"] for state in states for card in state["private"]["candidates"]]
    assert len(set(all_ids)) == len(all_ids), "candidate data must be private to its owner"
    for index, (peer, state) in enumerate(zip(peers, states)):
        wanted = index % 3
        choice = next(i for i, card in enumerate(state["private"]["candidates"]) if card["kind"] == wanted)
        peer.command("choose", choice)
    states = wait_for(peers, lambda states: all(state["private"]["picked"] >= 0 for state in states), "card picks")
    for index, (peer, state) in enumerate(zip(peers, states)):
        local = next(p for p in state["match"]["players"] if p["peer_id"] == state["local_id"])
        card = local["hand"][-1]
        target = states[0]["local_id"] if card["kind"] == 2 else state["local_id"]
        if round_number == 2 and index == 1:
            peer.command("card", [card["uid"], states[0]["local_id"]])
            command_done(peers)
            time.sleep(0.1)
            assert peer.status()["private"]["planned"]["uid"] == 0, "buff cannot target another player"
        peer.command("card", [card["uid"], target])
    wait_for(peers, lambda states: all(state["private"]["planned"]["uid"] != 0 for state in states), "card reservations")


def run_game(engine, folder, count):
    peers = start_room(engine, folder, count)
    try:
        round_cards = set()
        tested_emote = False
        for turn_id in range(1, count * 4 + 1):
            states = current(peers)
            if turn_id > count and (turn_id - 1) % count == 0:
                round_number = (turn_id - 1) // count + 1
                if round_number not in round_cards:
                    handle_cards(peers, round_number)
                    round_cards.add(round_number)
            states = wait_for(peers, lambda states: same_aim(states, turn_id), f"turn {turn_id}")
            active_id = states[0]["match"]["players"][states[0]["match"]["turn_index"]]["peer_id"]
            actor = next(peer for peer, state in zip(peers, states) if state["local_id"] == active_id)
            inactive = next(peer for peer, state in zip(peers, states) if state["local_id"] != active_id)
            if turn_id == 1:
                before = states[0]["match"]["darts_left"]
                inactive.command("throw", [0, 0, 0.5])
                command_done(peers)
                time.sleep(0.15)
                assert peers[0].status()["match"]["darts_left"] == before, "wrong turn rejected"
                spectators = [peer for peer, state in zip(peers, states) if state["local_id"] != active_id]
                spectators[0].command("emote")
                wait_for(peers, lambda states: all(state["emote_count"] == 1 for state in states), "emote replicated")
                time.sleep(0.25)
                spectators[0].command("emote")
                command_done(peers)
                time.sleep(0.15)
                assert all(peer.status()["emote_count"] == 1 for peer in peers), "repeat emote rejected"
                if count == 4:
                    spectators[1].command("emote")
                    wait_for(peers, lambda states: all(state["emote_count"] == 2 for state in states), "second emote")
                    time.sleep(0.25)
                    spectators[2].command("emote")
                    command_done(peers)
                    time.sleep(0.15)
                    assert all(peer.status()["emote_count"] == 2 for peer in peers), "room emote limit"
                tested_emote = True

            if actor is not peers[0]:
                match_id = states[0]["match"]["match_id"]
                validate_rejected_throw(peers, actor, [match_id, turn_id - 1, 999, 0, 0, 0.5])
                validate_rejected_throw(peers, actor, [match_id, turn_id, 999, 3.0, 0, 0.5])
                validate_rejected_throw(peers, actor, [match_id, turn_id, 999, 0, 0, 2.0])
            actor.command("mouse_throw" if turn_id == 1 else "throw", [0, 0, 0.5])
            states = wait_for(peers, lambda states: same_aim(states, turn_id)
                             and all(state["match"]["darts_left"] == 1 and state["match"]["last_hit"] for state in states),
                             "first dart landed")
            if actor is not peers[0]:
                hit = states[0]["match"]["last_hit"]
                validate_rejected_throw(peers, actor, [states[0]["match"]["match_id"], turn_id, hit["request_id"], 0, 0, 0.5])
            actor.command("throw", [0, 0, 0.5])
            wait_for(peers, lambda states: all(state["match"]["turn_id"] > turn_id
                     or state["match"]["phase"] in (4, 5, 6) for state in states), "second dart ends turn")

        states = wait_for(peers, lambda states: all(state["match"]["phase"] == 6 for state in states), "finish")
        assert all(state["match"] == states[0]["match"] for state in states), "final snapshots agree"
        expected_by_id = {state["local_id"]: [460, 700, 400, 460][index]
                          for index, state in enumerate(states)}
        # 접속 완료 순서는 프로세스 실행 순서와 다를 수 있으므로 peer ID로 비교한다.
        expected = [expected_by_id[player["peer_id"]] for player in states[0]["match"]["players"]]
        scores = [p["score"] for p in states[0]["match"]["players"]]
        assert scores == expected, f"Scores {scores} != expected {expected}"
        assert all(p["bonus"] == 0 and p["multiplier"] == 1 and not p["hand"]
                   for p in states[0]["match"]["players"]), "cards consumed and effects expired"
        assert tested_emote and len(round_cards) == 3
        peers[0].command("lobby")
        wait_for(peers, lambda states: lobby_count(states, count) and all("match" not in state for state in states), "cleanup")
        print(f"PASS: {count} players complete 4 rounds, 2 darts/turn, 3 card phases, authoritative scores {expected}", flush=True)
    finally:
        for peer in peers:
            peer.stop()


def run_afk(engine, folder):
    peers = start_room(engine, folder, 2, afk=True)
    try:
        states = wait_for(peers, lambda states: all(state["match"]["phase"] == 6 for state in states), "AFK completion")
        assert all(player["score"] == 0 and len(player["hand"]) == 1 for player in states[0]["match"]["players"])
        print("PASS: turn/card timeouts complete a match without player input", flush=True)
    finally:
        for peer in peers:
            peer.stop()


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--godot", type=Path, required=True)
    args = parser.parse_args()
    results = PROJECT / ".godot" / "first_idea_tests" / str(time.time_ns())
    results.mkdir(parents=True)
    for count in (2, 3, 4):
        folder = results / str(count)
        folder.mkdir()
        run_game(args.godot, folder, count)
    folder = results / "afk"
    folder.mkdir()
    run_afk(args.godot, folder)
    for path in results.rglob("*.log"):
        errors = [line for line in path.read_text(encoding="utf-8").splitlines()
                  if ("ERROR:" in line or "SCRIPT ERROR:" in line)
                  and "Failed to read the root certificate store" not in line]
        assert not errors, f"Engine errors: {path}: {errors}"
    print(f"All gameplay checks passed. Logs: {results}", flush=True)


if __name__ == "__main__":
    main()
