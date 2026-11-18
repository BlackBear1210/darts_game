"""실제 ENet 3프로세스: 초대/암호/정원/착석/호스트 권한/다트 턴 카드/재준비 검증."""
import argparse,math,time
from pathlib import Path
from run_multiplayer import Peer,free_port,wait_for,PROJECT

def main():
    parser=argparse.ArgumentParser();parser.add_argument('--godot',type=Path,required=True);args=parser.parse_args()
    output=PROJECT/'.godot'/'lounge_network'/str(time.time_ns());output.mkdir(parents=True)
    port=free_port();peers=[]
    try:
        host=Peer(args.godot,output,0,port,'social_host');peers.append(host)
        hs=wait_for([host],lambda ss:len(ss[0]['room']['players'])==1 and ss[0]['markers']==1,'host in map')[0]
        code=hs['room']['room_code']
        client=Peer(args.godot,output,1,port,'client');peers.append(client)
        wait_for([client],lambda ss:not ss[0]['connecting'] and ss[0]['local_id']==0 and '코드' in ss[0]['message'],'missing invite rejected')
        client.command('secure_join',['WRONG','test-password'])
        wait_for([client],lambda ss:ss[0]['command_id']>=1 and not ss[0]['connecting'] and '코드' in ss[0]['message'],'wrong invite rejected')
        client.command('secure_join',[code,'bad'])
        wait_for([client],lambda ss:ss[0]['command_id']>=2 and not ss[0]['connecting'] and '비밀번호' in ss[0]['message'],'wrong password rejected')
        client.command('secure_join',[code,'test-password'])
        # 손님 차림(look)은 들어온 뒤 방장을 한 번 거쳐 돌아온다 → 두 화면의 방 정보가 같아질 때까지 기다린다(2026-11-18).
        states=wait_for(peers,lambda ss:all(len(s['room']['players'])==2 and s['markers']==2 and s['room']['phase']==0 for s in ss) and ss[0]['room']==ss[1]['room'],'authenticated joins visible in waiting map')
        client_id=states[1]['local_id']
        assert states[0]['room']==states[1]['room']
        assert not any('password' in key and key!='has_password' for key in states[1]['room'])
        third=Peer(args.godot,output,2,port,'client');peers.append(third)
        wait_for([third],lambda ss:not ss[0]['connecting'] and ss[0]['local_id']==0,'third challenge')
        third.command('secure_join',[code,'test-password'])
        wait_for([third],lambda ss:ss[0]['command_id']>=1 and not ss[0]['connecting'] and '가득' in ss[0]['message'],'capacity two enforced')
        rules=states[0]['room']['settings'].copy();rules['rounds']=19;rules['hit_stun']=3.0
        client.command('raw_settings',rules)
        wait_for([client],lambda ss:ss[0]['command_id']>=4,'forged settings sent');time.sleep(.2)
        assert host.status()['room']['settings']['rounds']==5
        host.command('ready',True);client.command('ready',True)
        time.sleep(.35)
        assert host.status()['room']['phase']==0 and all(not p['ready'] for p in host.status()['room']['players'])
        host.command('seat');client.command('seat')
        wait_for([host,client],lambda ss:all(all(p['seated'] for p in s['poses']) for s in ss),'both seated')
        host.command('ready',True)
        wait_for([host,client],lambda ss:all(s['room']['players'][0]['ready'] for s in ss),'host ready visible')
        rules['rounds']=6;host.command('settings',rules)
        wait_for([host,client],lambda ss:all(s['room']['settings']['rounds']==6 and all(not p['ready'] for p in s['room']['players']) for s in ss),'rules update resets ready')
        assert host.status()['room']['settings']['hit_stun']==1.0
        host.command('ready',True);client.command('ready',True)
        states=wait_for([host,client],lambda ss:all(s['room']['phase']==2 and s['match']['phase']==5 for s in ss),'all ready loads card view')
        # 현재 손패를 다시 시작하지 않고 다음 다트 턴부터 시간을 적용한다.
        live=states[0]['room']['settings'].copy()
        original_theme=live['theme_id']
        live.update(rounds=2,dart_seconds=15.0,special_chance=85.0,theme_id=1-original_theme)
        host.command('settings',live)
        states=wait_for([host,client],lambda ss:all(s['room']['settings']['rounds']==2 and s['room']['settings']['dart_seconds']==15 for s in ss),'live rules replicated')
        assert all(s['room']['settings']['theme_id']==original_theme and s['room']['settings']['special_chance']==85 and s['match']['phase']==5 for s in states)
        # 2026-10-31: 카드 턴은 없다. 카드 확인(5초) 동안은 못 쓰고, 다트 턴에 누구나 쓴다.
        client.command('card',['select',0]);time.sleep(.25)
        assert all(p['pending_card']==-1 for p in host.status()['match']['players'])
        states=wait_for([host,client],lambda ss:all(s['match']['phase']==2 for s in ss),'card view leads straight to darts',timeout=8)
        assert all(12<s['remaining']<=15.5 for s in states)
        host.command('card',['select',0])
        wait_for([host,client],lambda ss:all(s['match']['players'][0]['pending_card']>=0 for s in ss),'host selection')
        host.command('card',['choice',0])
        wait_for([host,client],lambda ss:all(s['match']['players'][0]['card_effects']['choice']==0 for s in ss),'host value replicated')
        time.sleep(1.5);host.command('card',['use',1])
        wait_for([host,client],lambda ss:all(len(s['match']['players'][0]['hand'])==6 for s in ss),'thrower card use replicated')
        client.command('card',['select',0])
        wait_for([host,client],lambda ss:all(s['match']['players'][1]['pending_card']>=0 for s in ss),'client selection')
        client.command('card',['choice',0])
        wait_for([host,client],lambda ss:all(s['match']['players'][1]['card_effects']['choice']==0 for s in ss),'remote value replicated')
        time.sleep(1.5);client.command('card',['use',1])
        states=wait_for([host,client],lambda ss:all(len(s['match']['players'][1]['hand'])==6 and s['match']['phase']==2 for s in ss),'remote card use during dart turn')
        assert states[0]['match']['players']==states[1]['match']['players']
        host.command('lobby')
        states=wait_for([host,client],lambda ss:all(s['room']['phase']==0 and s['match']['phase']==0 and all(not p['ready'] for p in s['room']['players']) for s in ss),'back to map and re-ready')
        print('PASS: invite/password/capacity, host-only settings, seated readiness, setting consent reset, real remote card use, map return',flush=True)
        # 2026-11-18 "방 만든 뒤 대기 없애기": 로비로 돌아와도·경기를 시작해도 경기 화면을 지우고 새로 만들지 않는다
        # (app/main.gd → GameView.begin_match). 같은 화면에서 두 번째 경기: 점수·손패는 새로, 손님 준비·카드·움직임은 그대로 통한다.
        first_match=states[0]['room']['match_id']
        assert all(all(p['seated'] for p in s['poses']) for s in states),'map return keeps players seated'
        host.command('ready',True);client.command('ready',True)
        states=wait_for([host,client],lambda ss:all(s['room']['phase']==2 and s['room']['match_id']==first_match+1 and s['match']['match_id']==first_match+1 and s['match']['phase']==5 for s in ss),'second match on the same map')
        assert all(p['score']==0 and len(p['hand'])==7 for s in states for p in s['match']['players']),'second match starts clean'
        wait_for([host,client],lambda ss:all(s['match']['phase']==2 for s in ss),'second match darts',timeout=8)
        client.command('card',['select',0])
        wait_for([host,client],lambda ss:all(s['match']['players'][1]['pending_card']>=0 for s in ss),'client card request in second match')
        client_pose=lambda s:next(p for p in s['poses'] if p['id']==client_id)
        client.command('seat')
        wait_for([host,client],lambda ss:all(not client_pose(s)['seated'] for s in ss),'client stands up in second match')
        start=client_pose(host.status())['position']
        # 테이블 가운데(TableView.TABLE_CENTER = (0, 0, 4.4))에서 바깥쪽을 보고 앞으로 걷는다(테이블에 막히지 않게).
        away=math.atan2(-start[0],-(start[2]-4.4))
        client.command('move',[0,-1,away,False,False])
        wait_for([host,client],lambda ss:all(math.dist(client_pose(s)['position'],start)>0.3 for s in ss),'client walks in second match')
        client.command('stop')
        print('PASS: second match on the same map (no scene rebuild)',flush=True)
    finally:
        for peer in peers:peer.stop()
    for path in output.glob('*.log'):
        errors=[line for line in path.read_text(encoding='utf-8').splitlines() if ('ERROR:' in line or 'SCRIPT ERROR:' in line) and 'root certificate store' not in line]
        assert not errors,(path,errors[:10])
    print('All lounge checks passed. Logs:',output,flush=True)
if __name__=='__main__':main()
