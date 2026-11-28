"""[캐릭터 v3 · 2026-11-28] 인형 머리(민머리 각진 로우폴리) + 갈아 끼우는 헤어 부품 + 옷 조각 생성. 좌표 = 쉬는 자세 모델 좌표(m).
입력: mesh.json(zz_export_head.gd)   출력: geo.json(zz_convert_geo.gd 가 character_look_data.res 로 바꾼다)
정면 = -Z, 캐릭터 오른쪽 = +X.  방위각 az: 0 = 앞, +90 = 캐릭터 오른쪽.  고도 el: +90 = 정수리.

v3 생각(2026-11-28 사용자 "두개골처럼 머리만 잡고 헤어를 따로 · 인형에 머리카락 부품을 결합 · 대머리 두피가 울룩불룩 ·
눈썹·코·입·턱의 배치와 선을 지켜 사람 형태로 · 각이 살아있는 로우폴리 카툰"):
  1) 인형 머리 = 승인 모델 머리(곱슬이 조각된 6만 면)를 쓰지 않고 **새로 뜬 로우폴리 머리**(약 2천 2백 면).
     - 껍데기: 머리 가운데 HC 에서 설계한 눈금(방위 27칸 × 고도 줄: 턱 밑·턱·입·코밑·코·광대·눈·눈썹·이마·정수리)으로
       승인 얼굴 면을 다시 뜬다(retopology). 머리카락 자리는 두피 지도, 눈·코·귀 자리는 이웃으로 메운다. 좌우 대칭.
     - 뒷머리 아래는 두개골 → 목 이음새 S 곡선(풍선처럼 처지지 않게) · 볼·귀 둘레는 고르게 · 관자는 채운다.
     - 눈알·눈동자·코(쐐기)·귀(앞은 붙고 뒤가 벌어진 콩 모양)·입(막대)·눈썹(이마 면에 얹은 막대)은 따로 만든 닫힌 조각.
     - 목 이음새: 승인 머리 면의 아래 테두리(정점 118개)를 테두리를 따라 걸은 순서로 지퍼처럼 잇는다(틈·뒤집힌 면 없음).
     - 면 음영: 면 법선 55 % + 40° 안 이웃 평균 45 % → 각은 보이되 지저분하지 않게(이음새 띠만 부드럽게).
     - 캐릭터 얼굴형(턱·턱끝·볼·코)은 character_looks.gd FACE 와 같은 식으로 여기서 굽는다(목 앞 면은 게임이 같은 식으로 민다).
  2) 헤어 = 인형 위에 얹는 **닫힌 덩어리**(평면 금지 — 돌려 보면 안쪽이 비어 보인다, 제페토 헤어 가이드).
     - 바탕 모자(cap_solid): 이마선부터 정수리까지 두피를 빈틈없이 덮는 두께 있는 껍데기. 이마선 가장자리는 두피 속으로 접혀
       들어간다(두피가 헤어 밑으로 드러나지 않게). 안쪽 면은 두피 속(−5 mm).
     - 다발(tube): 4~6각 단면 튜브 — 낮은 다각형 결. 뿌리는 바탕 모자 속에 묻힌다.
     - 헤어는 어느 캐릭터에도 끼운다(얼굴형은 얼굴 앞 아래만 바꾸므로 두피는 모두 같다). 색은 캐릭터 머리색.
  3) 헤어 목록(character_looks.gd HAIRS 와 같은 키): wavy(기본 인형) · spiky(준) · bob(솜) · curls(온, 한 색) · crew · pony
  4) 헤어 꼭대기 상한: 1.805 m 위는 절반으로 눌러 1.835 m 에서 자른다(v3 의 1.80 m 는 볼륨이 납작해서 v4 에서 올렸다).

v4(2026-11-28 오후, 시안 피드백 "뒤통수에서 목으로 이어지는 부분이 뭉툭 · 헤어가 낮아 볼륨이 없다 ·
    면이 너무 일정해 각진 직사각형으로 나뉘어 보인다 — 점을 불규칙한 높이와 거리에"):
  - 귀 뒤·목덜미 깎기: 두개골 밑판(NAPE_RIM) 아래를 잘라 내고 목 이음새를 위로 뽑은 목기둥과 합친다(방위 84° 밖).
  - 헤어 두께 키움(옆 1~1.5 cm · 위 2.5~3.5 cm) · 다발 굵게·더 띄움 · 단발은 바깥·안쪽 두 겹.
  - cap_solid: 벽돌 엇갈림 · 점 흔들기(scatter) · 다발 결과 홈(lanes) · 이마선 톱니(tip_deg) · 무작위 대각선 ·
    두피 둘레 최댓값(head_r_hull) 위에 얹기. tube: 단면 들쭉날쭉(jit) · 고리 비틀기(twist).
  - 짧은 헤어 뒤 머리선 1.49~1.51 m(깎은 목기둥 위 끝).

v5(2026-11-28 저녁, 피드백 "민머리를 옆에서 보면 뒤통수가 너무 크다 · 조금 더 볼륨감" → "크기만 줄인 것 같다 ·
    두개골 모양이 아닌 인형 머리처럼 원형으로 · 점 1개 말고 10개쯤 더 · 위에서 봤을 때 둥글게"):
  - 둥근 인형 뒤통수(_round_back): 귀 줄 뒤를 높이마다 타원 호로 새로 그린다(위에서도 옆에서도 둥근 호).
    가장 튀어나온 곳 z 0.115 → 0.080, 아래는 목 쪽으로 공처럼 말려 들어가 목기둥과 합친다.
  - 뒤쪽 세로줄 한쪽 3 → 8개(AZ_HALF 약 10° 간격) — 인형 머리 2,238 → 2,618 면.
  - 헤어 두께 ×1.15(HAIR_VOL) + 뒤통수 자리에 5 mm 더(_vol) → 헤어를 쓰면 뒤가 살짝 부푼다.
"""
import json, sys, math
import numpy as np

HERE = sys.argv[1] if len(sys.argv) > 1 else '.'
d = json.load(open(f'{HERE}/mesh.json'))
head = d['Body']['surfaces'][2]
P = np.array(head['pos'], dtype=np.float64)
C = np.array(head['col'], dtype=np.float64)
IDX = np.array(head['idx'], dtype=np.int64).reshape(-1, 3)
Y_MAX = 1.835       # 헤어 꼭대기 상한(v4: 볼륨을 위해 1.80 → 1.835, 민머리 정수리 1.773)
Y_SOFT = 1.805


def smooth(e0, e1, x):
    t = np.clip((np.asarray(x, float) - e0) / (e1 - e0), 0, 1)
    return t * t * (3 - 2 * t)


# ---------- 1. 머리카락 정점 분류(텍스처 색) ----------
V = C.max(1)
is_hair_col = (V < 0.5) & (C[:, 0] - C[:, 2] > 0.05)
# 얼굴 앞(눈썹·입술선·눈동자)은 머리카락이 아니다
face_zone = (P[:, 2] < -0.13) & (P[:, 1] < 1.675) & (np.abs(P[:, 0]) < 0.108)
hair = is_hair_col & ~face_zone
key = np.round(P / 1e-5).astype(np.int64)
_, inv = np.unique(key, axis=0, return_inverse=True)
inv = inv.reshape(-1)
grp = np.zeros(inv.max() + 1, bool)
np.logical_or.at(grp, inv, hair)
hair = grp[inv]
# 귀(두피 지도에서 뺀다 → 헤어 밖으로 나온다)
ear = (np.abs(P[:, 0]) > 0.128) & (P[:, 1] > 1.50) & (P[:, 1] < 1.645) & (P[:, 2] > -0.115) & (P[:, 2] < 0.065) & ~hair

# ---------- 2. 두피 지도 ----------
HC = np.array([0.0, 1.60, -0.06])
AZ_STEP, EL_STEP = 4.0, 4.0
AZS = np.arange(-180, 180, AZ_STEP)
ELS = np.arange(-60, 90.01, EL_STEP)


def to_dir(az, el):
    az = np.radians(az); el = np.radians(el)
    return np.stack([np.sin(az) * np.cos(el), np.sin(el), -np.cos(az) * np.cos(el)], axis=-1)


def polar(points):
    rel = points - HC
    r = np.linalg.norm(rel, axis=-1)
    az = np.degrees(np.arctan2(rel[..., 0], -rel[..., 2]))
    el = np.degrees(np.arcsin(np.clip(rel[..., 1] / r, -1, 1)))
    return r, az, el


r0, az0, el0 = polar(P)
ia = ((az0 + 180) / AZ_STEP).astype(int) % len(AZS)
ie = np.clip(np.round((el0 - ELS[0]) / EL_STEP).astype(int), 0, len(ELS) - 1)
known = np.full((len(ELS), len(AZS)), np.nan)
cnt_skin = np.zeros(known.shape, int)
cnt_hair = np.zeros(known.shape, int)
for a, e, rr, h, er in zip(ia, ie, r0, hair, ear):
    if er:
        continue
    if h:
        cnt_hair[e, a] += 1
    else:
        cnt_skin[e, a] += 1
        if np.isnan(known[e, a]) or rr > known[e, a]:
            known[e, a] = rr
trust = (cnt_skin >= 3) & (cnt_hair < cnt_skin)
known[~trust] = np.nan
grid = known.copy()
fill = np.isnan(grid)
grid[fill] = np.nanmean(known)
for _ in range(400):
    pad = np.pad(grid, ((1, 1), (0, 0)), mode='edge')
    avg = (np.roll(grid, 1, 1) + np.roll(grid, -1, 1) + pad[:-2] + pad[2:]) / 4
    grid[fill] = avg[fill]
    grid[-1, :] = grid[-1, :].mean()
# 채운 칸을 한 번 더 고르게(채운 곳만 — 살 정점이 있는 칸은 그대로) → 민머리가 매끈한 두개골이 된다.
for _ in range(60):
    pad = np.pad(grid, ((1, 1), (0, 0)), mode='edge')
    avg = (np.roll(grid, 1, 1) + np.roll(grid, -1, 1) + pad[:-2] + pad[2:] + 4 * grid) / 8
    grid[fill] = avg[fill]
RG = grid


def head_r(az, el):
    """방향별 두피 반지름(쌍선형 보간)."""
    az = np.asarray(az, float); el = np.asarray(el, float)
    fa = (az + 180) / AZ_STEP
    fe = np.clip((el - ELS[0]) / EL_STEP, 0, len(ELS) - 1.0001)
    a0 = np.floor(fa).astype(int); e0 = np.floor(fe).astype(int)
    ta = fa - a0; te = fe - e0
    a0 %= len(AZS); a1 = (a0 + 1) % len(AZS); e1 = np.minimum(e0 + 1, len(ELS) - 1)
    return (RG[e0, a0] * (1 - ta) * (1 - te) + RG[e0, a1] * ta * (1 - te) +
            RG[e1, a0] * (1 - ta) * te + RG[e1, a1] * ta * te)


def surf(az, el, off=0.0):
    return HC + to_dir(az, el) * (head_r(az, el) + off)[..., None] if np.ndim(az) else HC + to_dir(az, el) * (float(head_r(az, el)) + off)


def surf_normal(az, el):
    """두피 표면 법선(옆 두 점 차이의 외적)."""
    az = np.asarray(az, float); el = np.clip(np.asarray(el, float), -59, 87)
    p0 = HC + to_dir(az, el) * head_r(az, el)[..., None]
    pa = HC + to_dir(az + 1.0, el) * head_r(az + 1.0, el)[..., None]
    pe = HC + to_dir(az, el + 1.0) * head_r(az, el + 1.0)[..., None]
    n = np.cross(pe - p0, pa - p0)
    n /= np.linalg.norm(n, axis=-1, keepdims=True)
    # 바깥(머리 가운데에서 먼 쪽)을 보게
    flip = np.sum(n * (p0 - HC), axis=-1) < 0
    n[flip] *= -1
    return n



# ---------- 4. 덩어리 만들기 도구 ----------
def el_at_height(az, y_target):
    lo = np.full(np.shape(az), -60.0); hi = np.full(np.shape(az), 89.0)
    for _ in range(40):
        mid = (lo + hi) / 2
        y = HC[1] + np.sin(np.radians(mid)) * head_r(az, mid)
        below = y < y_target
        lo = np.where(below, mid, lo); hi = np.where(below, hi, mid)
    return (lo + hi) / 2


def periodic_interp(points):
    """[(az, 값)] 제어점 → az 배열을 받는 매끈한 함수(주기 360°, 코사인 보간)."""
    pts = sorted(points)
    xs = np.array([p[0] for p in pts], float); ys = np.array([p[1] for p in pts], float)
    xs = np.concatenate([xs - 360, xs, xs + 360]); ys = np.concatenate([ys, ys, ys])

    def f(az):
        az = (np.asarray(az, float) + 180) % 360 - 180
        i = np.clip(np.searchsorted(xs, az) - 1, 0, len(xs) - 2)
        t = (az - xs[i]) / (xs[i + 1] - xs[i])
        t = (1 - np.cos(t * np.pi)) / 2
        return ys[i] * (1 - t) + ys[i + 1] * t
    return f


def gauss(az, el, az_c, el_c, saz, sel):
    da = (az - az_c + 180) % 360 - 180
    return np.exp(-0.5 * ((da / saz) ** 2 + ((el - el_c) / sel) ** 2))


def signed_volume(V_, T_):
    a = V_[T_[:, 0]]; b = V_[T_[:, 1]]; c = V_[T_[:, 2]]
    return np.einsum('ij,ij->i', a, np.cross(b, c)).sum() / 6.0


def closed_piece(V_, T_):
    """닫힌 덩어리: 감는 방향을 하나로 맞춘 삼각형(바깥 법선 = 오른손) → Godot 앞면 순서(오른손 법선이 안쪽)로 바꾼다."""
    V_ = np.asarray(V_, float); T_ = np.asarray(T_, int)
    if signed_volume(V_, T_) < 0:
        T_ = T_[:, [0, 2, 1]]
    return V_, T_[:, [0, 2, 1]]


def grid_tris(rows, cols, ring=True, rng=None):
    """rows×cols 격자(행마다 cols 개, ring 이면 열이 돈다) → 같은 방향으로 감긴 삼각형.
    rng 를 주면 네모를 가르는 대각선도 아무렇게나(바둑판 무늬가 보이지 않게)."""
    T_ = []
    cmax = cols if ring else cols - 1
    for i in range(rows - 1):
        for j in range(cmax):
            a_ = i * cols + j; b_ = i * cols + (j + 1) % cols
            c_ = (i + 1) * cols + (j + 1) % cols; e_ = (i + 1) * cols + j
            if ((i + j) % 2 == 0) if rng is None else (rng.random() < 0.5):
                T_ += [[a_, b_, c_], [a_, c_, e_]]
            else:
                T_ += [[a_, b_, e_], [b_, c_, e_]]
    return T_


def cap_solid(lim_fn, thick_fn, n_az=36, n_rows=8, gamma=1.0, tuck_deg=7.0, cap_el=86.0, jitter=0.0, seed=1, post=None,
              lanes=0, lane_amp=0.0, tip_deg=0.0, scatter=0.0, edge_thin=1.0):
    """두피를 덮는 두께 있는 바탕 모자(닫힌 덩어리).
    바깥 면: 이마선 lim_fn(az)(높이 m)부터 정수리까지 = 두피 + thick_fn. 이마선 아래 tuck_deg 줄은 두피 속(−3 mm)으로 접혀 들어간다.
    안쪽 면: 두피 −5 mm(보이지 않는다 — 덩어리를 닫기만 한다).
    v4(2026-11-28 사용자 "면이 너무 일정해 머리카락이 각진 직사각형으로 나뉘어 보인다 — 점을 불규칙한 높이·거리에"):
      - 줄마다 반 칸씩 엇갈리고(벽돌), 점마다 옆·위아래로 scatter 칸만큼 흔든다. 두께도 ±jitter. 대각선도 아무렇게나.
      - 다발 결(lanes 개): 정수리에서 이마선으로 흐르는 덩어리 — 가운데는 lane_amp/2 만큼 솟고 사이는 홈(조금씩 굽이친다).
      - 이마선 끝: 다발 가운데가 tip_deg°(점마다 0.6~1.3배) 만큼 뾰족하게 내려온다(톱니) · 끝 두께는 edge_thin 배."""
    rng = np.random.default_rng(seed)
    step = 360.0 / n_az
    base_az = np.arange(n_az) * step - 180.0
    lane_ph = rng.uniform(0, 1)
    wob = rng.uniform(0, 2 * np.pi, 2)

    def lane(A, E):
        if lanes <= 0:
            return np.full(np.shape(A), 0.5)
        u = (np.asarray(A) + 180) / 360 * lanes + lane_ph + 0.22 * np.sin(np.radians(E) * 2.5 + wob[0])             + 0.12 * np.sin(np.radians(A) * 3 + np.radians(E) * 4 + wob[1])
        f = u - np.floor(u)
        return 1 - np.abs(2 * f - 1)

    rows_ae = []
    for k in range(n_rows):                     # k = 0 이마선 … 정수리 쪽
        A = base_az + (0.5 * step if k % 2 else 0.0)
        if 0 < k < n_rows - 1:
            A = A + rng.uniform(-scatter, scatter, n_az) * step
        el_h = el_at_height_smooth(A, lim_fn(A))
        E = el_h + (cap_el - el_h) * ((k / (n_rows - 1)) ** gamma)
        if 0 < k < n_rows - 1:
            gap = (cap_el - el_h) / (n_rows - 1)
            E = E + rng.uniform(-scatter, scatter, n_az) * gap * 0.8
        if k == 0 and tip_deg > 0:
            E = E - tip_deg * lane(A, E) ** 1.5 * rng.uniform(0.6, 1.3, n_az)
        rows_ae.append((A, E))
    A0, E0 = rows_ae[0]
    rows = []
    # 위(정수리) → 이마선(바깥) → 접힌 줄 → 안쪽(이마선 → 정수리)
    for k in reversed(range(n_rows)):
        A, E = rows_ae[k]
        fade = 1 - smooth(cap_el - 24, cap_el - 4, E)
        th = thick_fn(A, E) + lane_amp * (lane(A, E) - 0.5) * fade + rng.uniform(-jitter, jitter, n_az)
        if k == 0:
            th = th * edge_thin
        r_ = head_r_hull(A, E) + np.maximum(th, 0.0035)    # 줄 사이 면이 두개골 곡면 밑으로 처지는 깊이(약 2.3 mm)보다 두껍게
        rows.append(HC + to_dir(A, E) * r_[:, None])
    rows.append(HC + to_dir(A0, E0 - tuck_deg) * (head_r(A0, E0 - tuck_deg) - 0.003)[:, None])
    el_h0 = el_at_height_smooth(A0, lim_fn(A0))
    for t_ in (0.0, 0.5, 1.0):
        e_ = el_h0 + (cap_el - el_h0) * t_
        rows.append(HC + to_dir(A0, e_) * (head_r(A0, e_) - 0.005)[:, None])
    grid_pts = np.array(rows)                      # (R, n_az, 3)
    if post is not None:
        grid_pts = post(grid_pts)
    R = grid_pts.shape[0]
    V_ = list(grid_pts.reshape(-1, 3))
    T_ = grid_tris(R, n_az, rng=rng)
    top_out = len(V_); V_.append(HC + np.array([0, 1.0, 0]) * (float(head_r(0, 90)) + float(thick_fn(np.array(0.0), np.array(90.0)))))
    top_in = len(V_); V_.append(HC + np.array([0, 1.0, 0]) * (float(head_r(0, 90)) - 0.005))
    for j in range(n_az):
        T_.append([top_out, (j + 1) % n_az, j])
        T_.append([top_in, (R - 1) * n_az + j, (R - 1) * n_az + (j + 1) % n_az])
    return closed_piece(np.array(V_), T_)


def head_r_hull(az, el):
    """헤어 바탕용 두피 반지름 = 둘레(방위 ±7° · 고도 ±11°)에서 가장 큰 값.
    헤어 모자 줄은 두피 눈금보다 성기다 → 볼록한 모서리(깎은 목덜미 위 두개골 밑선)에서 두 줄 사이 면이 두피 속으로 파고들어
    두피가 헤어 사이로 비쳤다(2026-11-28 v4) → 둘레 최댓값 위에 얹어 늘 두피 바깥에 있게."""
    az = np.asarray(az, float); el = np.asarray(el, float)
    best = head_r(az, el)
    for da in (-7.0, 0.0, 7.0):
        for de in (-11.0, -5.5, 0.0, 5.5, 11.0):
            if da == 0.0 and de == 0.0:
                continue
            best = np.maximum(best, head_r(az + da, np.minimum(el + de, 89.0)))
    return best


def catmull(points, per=2):
    """제어점을 지나는 곡선(균일 Catmull-Rom), 구간마다 per 조각."""
    p = np.asarray(points, float)
    ext = np.vstack([2 * p[0] - p[1], p, 2 * p[-1] - p[-2]])
    out = []
    for i in range(1, len(ext) - 2):
        p0, p1, p2, p3 = ext[i - 1], ext[i], ext[i + 1], ext[i + 2]
        for k in range(per):
            t = k / per
            out.append(0.5 * ((2 * p1) + (-p0 + p2) * t + (2 * p0 - 5 * p1 + 4 * p2 - p3) * t * t + (-p0 + 3 * p1 - 3 * p2 + p3) * t ** 3))
    out.append(p[-1])
    return np.array(out)


def tube(path, widths, thicks, sides=4, roll=0.0, up=None, tip=True, jit=0.0, twist=0.0, seed=None):
    """다발: path 를 따라가는 닫힌 튜브(단면 sides 각형, 가로 widths · 세로 thicks).
    단면의 '위'는 머리 가운데에서 바깥 쪽(up 함수로 바꿀 수 있다). tip 이면 끝을 한 점으로 모은다.
    jit: 단면 점마다 ±jit 배로 들쭉날쭉 · twist: 고리마다 ±twist 라디안 비틀기(면이 고른 띠로 보이지 않게, v4)."""
    rng = np.random.default_rng(seed) if (jit > 0 or twist > 0) else None
    path = np.asarray(path, float)
    m = len(path)
    widths = np.asarray(widths, float); thicks = np.asarray(thicks, float)
    V_ = []
    for i in range(m):
        t_ = path[min(i + 1, m - 1)] - path[max(i - 1, 0)]
        t_ /= np.linalg.norm(t_)
        u_ = (path[i] - HC) if up is None else up(path[i], i)
        u_ = u_ - t_ * np.dot(u_, t_)
        u_ /= np.linalg.norm(u_)
        s_ = np.cross(t_, u_)
        if tip and i == m - 1:
            V_.append(path[i])
            continue
        rr = roll + (rng.uniform(-twist, twist) if rng is not None and twist > 0 else 0.0)
        for k in range(sides):
            th = 2 * np.pi * k / sides + rr
            sc = 1.0 + (rng.uniform(-jit, jit) if rng is not None and jit > 0 else 0.0)
            V_.append(path[i] + (s_ * np.cos(th) * widths[i] / 2 + u_ * np.sin(th) * thicks[i] / 2) * sc)
    rings = m - 1 if tip else m
    T_ = grid_tris(rings, sides, rng=rng)
    root = len(V_); V_.append(path[0] - (path[1] - path[0]) * 0.05)
    for k in range(sides):
        T_.append([root, (k + 1) % sides, k])
    if tip:
        tip_i = (rings) * sides
        b = (rings - 1) * sides
        for k in range(sides):
            T_.append([b + k, b + (k + 1) % sides, tip_i])
    else:
        end = len(V_); V_.append(path[-1])
        b = (rings - 1) * sides
        for k in range(sides):
            T_.append([b + k, b + (k + 1) % sides, end])
    return closed_piece(np.array(V_), T_)


def ico(center, radii, jitter=0.1, seed=3, rot=None):
    """20면 덩이(곱슬 한 덩이)."""
    t = (1 + 5 ** 0.5) / 2
    v = np.array([[-1, t, 0], [1, t, 0], [-1, -t, 0], [1, -t, 0], [0, -1, t], [0, 1, t], [0, -1, -t], [0, 1, -t],
                  [t, 0, -1], [t, 0, 1], [-t, 0, -1], [-t, 0, 1]], float)
    f = [[0, 11, 5], [0, 5, 1], [0, 1, 7], [0, 7, 10], [0, 10, 11], [1, 5, 9], [5, 11, 4], [11, 10, 2], [10, 7, 6],
         [7, 1, 8], [3, 9, 4], [3, 4, 2], [3, 2, 6], [3, 6, 8], [3, 8, 9], [4, 9, 5], [2, 4, 11], [6, 2, 10],
         [8, 6, 7], [9, 8, 1]]
    v /= np.linalg.norm(v, axis=1, keepdims=True)
    rng = np.random.default_rng(seed)
    v = v * (1 + rng.uniform(-jitter, jitter, (12, 1))) * np.asarray(radii)
    if rot is not None:
        v = v @ rot.T
    return closed_piece(v + np.asarray(center), f)


def frame_at(p):
    """머리 표면 점 p 의 (바깥 법선, 앞→뒤 접선, 옆 접선)."""
    n = p - HC; n /= np.linalg.norm(n)
    side = np.cross(n, np.array([0, 1.0, 0]))
    if np.linalg.norm(side) < 1e-6:
        side = np.array([1.0, 0, 0])
    side /= np.linalg.norm(side)
    up = np.cross(side, n)
    return n, up, side


def merge(pieces):
    V_ = []; T_ = []
    for v_, t_ in pieces:
        b = len(V_)
        V_ += [list(p) for p in np.asarray(v_)]
        T_ += [[a + b, c + b, e + b] for a, c, e in np.asarray(t_)]
    return np.array(V_), np.array(T_, int)


def height_rule(V_):
    """헤어 높이 상한: 1.805 m 위는 절반으로 눌러 1.835 m 에서 자른다(v4 — 볼륨이 납작하다는 피드백으로 1.80 → 1.835)."""
    V_ = V_.copy()
    hi = V_[:, 1] > Y_SOFT
    V_[hi, 1] = Y_SOFT + (V_[hi, 1] - Y_SOFT) * 0.5
    V_[:, 1] = np.minimum(V_[:, 1], Y_MAX)
    return V_


def piece_out(V_, T_, shade=0.05):
    V_ = height_rule(V_)
    return {'v': np.round(V_, 5).tolist(), 't': np.asarray(T_).tolist(), 'shade': shade}


# 귀 둘레(방위 4°마다 HC 에서 잰 가로 거리 최댓값) — 귀를 덮는 헤어가 귀를 뚫지 않게.
_ear_rel = P[ear] - HC
_ear_az = np.degrees(np.arctan2(_ear_rel[:, 0], -_ear_rel[:, 2]))
_ear_hor = np.hypot(_ear_rel[:, 0], _ear_rel[:, 2])
EAR_R = np.zeros(90)
for a_, h_ in zip(((_ear_az + 180) / 4).astype(int) % 90, _ear_hor):
    EAR_R[a_] = max(EAR_R[a_], h_)
EAR_R = np.maximum(EAR_R, np.maximum(np.roll(EAR_R, 1), np.roll(EAR_R, -1)))


def ear_r(az):
    return EAR_R[int(((az + 180) % 360) / 4) % 90]


hairs = {}


def angles(u):
    return float(np.degrees(np.arctan2(u[0], -u[2]))), float(np.degrees(np.arcsin(np.clip(u[1], -1, 1))))


def flow_path(az, el, heading, length, n_pts, off_fn, curve=0.0):
    """머리 표면을 따라 흐르는 다발 중심선. heading: 0 = 정수리 쪽, 180 = 정수리에서 멀어지는 쪽, +90 = 오른쪽(동쪽).
    off_fn(s) = 두피에서 띄우는 높이(s = 0 뿌리 ~ 1 끝). curve = 끝까지 heading 이 바뀌는 양(도)."""
    u = to_dir(az, el)
    h = math.radians(heading)
    pts = []
    for k in range(n_pts):
        s = k / (n_pts - 1)
        a_, e_ = angles(u)
        r_ = float(head_r(a_, e_))
        pts.append(HC + u * (r_ + off_fn(s)))
        n_, north, east = frame_at(HC + u)
        t_ = math.cos(h) * north + math.sin(h) * east
        u = u + t_ * (length / (n_pts - 1)) / r_
        u /= np.linalg.norm(u)
        h += math.radians(curve) / (n_pts - 1)
    return np.array(pts)


def slerp_path(az0_, el0_, az1_, el1_, n_pts, off_fn):
    """두 방향 사이 큰 원을 따라가는 중심선(정수리를 넘는 다발)."""
    a = to_dir(az0_, el0_); b = to_dir(az1_, el1_)
    om = math.acos(float(np.clip(np.dot(a, b), -1, 1)))
    pts = []
    for k in range(n_pts):
        s = k / (n_pts - 1)
        u = (math.sin((1 - s) * om) * a + math.sin(s * om) * b) / math.sin(om)
        a_, e_ = angles(u)
        pts.append(HC + u * (float(head_r(a_, e_)) + off_fn(s)))
    return np.array(pts)


def taper(w0, w1, n, power=1.0, tip=True):
    s = np.linspace(0, 1, n)
    w = w0 + (w1 - w0) * s ** power
    if tip:
        w[-1] = 0.0
    return w


def jagged_lim(base_fn, amp, period_deg, seed):
    """이마선을 다발 끝처럼 조금씩 들쭉날쭉하게(낮은 다각형 결)."""
    rng = np.random.default_rng(seed)
    knots = [(a, float(base_fn(a)) + rng.uniform(-amp, amp)) for a in np.arange(-180, 180, period_deg)]
    return periodic_interp(knots)




# ═══════════════════════════════ 새 인형 머리(각진 로우폴리) ═══════════════════════════════
# 2026-11-28 사용자: "대머리 두피가 울룩불룩 · 두개골을 다시 잡고 눈썹·코·입·턱의 배치와 선을 지켜 사람 형태로 ·
#   각이 살아있는 로우폴리 카툰". → 승인 모델 머리(조각된 곱슬이 붙은 6만 면)를 쓰지 않고 새로 만든다.
#   1) 껍데기: 승인 얼굴을 '설계한 눈금'으로 다시 뜬다(retopology). 가로줄은 턱 밑·턱·입·코밑·코·눈·눈썹·이마선에 맞춘다.
#      머리카락 자리는 두피 지도(매끈한 돔)를 쓴다 → 민머리가 깨끗한 두개골이 된다. 좌우는 대칭으로 맞춘다.
#   2) 눈·눈동자·코·귀·입·눈썹은 따로 만든 닫힌 조각을 껍데기에 박는다(모듈식 머리 — Synty 같은 낮은 다각형 캐릭터 구조).
#   3) 면 음영: 면 법선 55 % + 40° 안 이웃 면 평균 45 % → 각은 보이되 지저분하지 않게.
#   4) 목 이음새: 승인 머리 면의 아래 끝 고리(정점 118개, y 1.37~1.41)에 정확히 붙인다(목 면은 그대로).
#   5) 캐릭터 얼굴형(FACE)은 여기서 굽는다 — character_looks.gd _morph_face 와 같은 식(목 앞 면은 게임이 같은 식으로 민다).

EYE_C = np.array([[0.0625, 1.5912, -0.194], [-0.0625, 1.5912, -0.194]])
EYE_R = 0.0325
eye_v = np.zeros(len(P), bool)
for c_ in EYE_C:
    eye_v |= np.linalg.norm(P - c_, axis=1) < 0.040
nose_v = (np.abs(P[:, 0]) < 0.034) & (P[:, 2] < -0.212) & (P[:, 1] > 1.445) & (P[:, 1] < 1.625)
vcls = np.zeros(len(P), int)
vcls[hair] = 1
vcls[ear] = 4
vcls[nose_v] = 3
vcls[eye_v] = 2
tcls = vcls[IDX].max(axis=1)
TRI = P[IDX]


def raycast(origins, dirs, tris, far=True, batch=24):
    """광선(원점 origins, 방향 dirs)과 삼각형들의 교점 거리. far = 가장 먼 교점(바깥 면), 아니면 가장 가까운 교점."""
    origins = np.broadcast_to(np.asarray(origins, float), np.shape(dirs))
    v0 = tris[:, 0]; e1 = tris[:, 1] - v0; e2 = tris[:, 2] - v0
    out_t = np.full(len(dirs), np.nan); out_i = np.full(len(dirs), -1)
    for s in range(0, len(dirs), batch):
        D = dirs[s:s + batch]; O = origins[s:s + batch]
        pvec = np.cross(D[:, None, :], e2[None])
        det = np.einsum('btk,tk->bt', pvec, e1)
        ok = np.abs(det) > 1e-12
        inv = np.where(ok, 1.0 / np.where(ok, det, 1.0), 0.0)
        tvec = O[:, None, :] - v0[None]
        u = np.einsum('btk,btk->bt', pvec, tvec) * inv
        qvec = np.cross(tvec, e1[None])
        v = np.einsum('bk,btk->bt', D, qvec) * inv
        t = np.einsum('tk,btk->bt', e2, qvec) * inv
        hit = ok & (u >= 0) & (v >= 0) & (u + v <= 1) & (t > 1e-6)
        if far:
            tt = np.where(hit, t, -np.inf); j = tt.argmax(1)
        else:
            tt = np.where(hit, t, np.inf); j = tt.argmin(1)
        best = tt[np.arange(len(D)), j]
        good = np.isfinite(best)
        out_t[s:s + batch][good] = best[good]; out_i[s:s + batch][good] = j[good]
    return out_t, out_i


# ── 눈금 ──
AZ_HALF = [0, 7, 14, 22, 31, 41, 52, 64, 77, 92, 102, 112, 121, 131, 141, 151, 160, 170, 180]   # v5: 뒤쪽 약 10° 간격
COLS = np.array([-a for a in AZ_HALF[::-1][1:-1]] + AZ_HALF, float)          # −170 … 0 … 180 (36칸, 한 바퀴)
NC = len(COLS)
MIRROR = np.array([int(np.argmin(np.abs(((COLS + a + 180) % 360) - 180))) for a in COLS])
# 얼굴 가로줄(HC 에서 본 고도°): 턱 밑 −58 · 턱 −50 · 입 −43 · 코밑 −38 · 코 끝 −32·−24 · 광대 −16·−8 · 눈 −1·6 · 눈썹 13 · 이마 21·30 · 정수리 40~76
FACE_ROWS = [-58, -50, -43, -38, -32, -24, -16, -8, -1, 6, 13, 21, 30, 40, 51, 63, 76]
# 목 이음새 고리(승인 머리 면의 열린 가장자리)
key5 = np.round(P / 1e-5).astype(np.int64)
_u, _first, _inv = np.unique(key5, axis=0, return_index=True, return_inverse=True)
_inv = _inv.reshape(-1)
from collections import Counter
_cnt = Counter()
for a_, b_, c_ in _inv[IDX]:
    for e_ in ((a_, b_), (b_, c_), (c_, a_)):
        _cnt[tuple(sorted(e_))] += 1
_bd_unique = np.unique(np.array([e_ for e_, n_ in _cnt.items() if n_ == 1]).reshape(-1))
SEAM_SRC = _first[_bd_unique]                     # 원래 머리 면 정점 번호(가중치·법선을 게임이 이것에서 베낀다)
SEAM_P = P[SEAM_SRC]
# 테두리를 따라 걷는 순서(SEAM_SRC 안의 번호): 이웃 = 한 번만 쓰인 변으로 이어진 점.
_pos_of = {int(u): k for k, u in enumerate(_bd_unique)}
_nbr = {k: [] for k in range(len(_bd_unique))}
for (e0, e1), n_ in _cnt.items():
    if n_ == 1:
        _nbr[_pos_of[int(e0)]].append(_pos_of[int(e1)]); _nbr[_pos_of[int(e1)]].append(_pos_of[int(e0)])
SEAM_LOOP = [0]
_prev = -1
while True:
    _cur = SEAM_LOOP[-1]
    _nx = [q for q in _nbr[_cur] if q != _prev]
    if not _nx or _nx[0] == 0:
        break
    _prev = _cur
    SEAM_LOOP.append(_nx[0])
_NECK0 = SEAM_P.mean(0)
_angs = [math.atan2(SEAM_P[k][0] - _NECK0[0], -(SEAM_P[k][2] - _NECK0[2])) for k in SEAM_LOOP]
_turn = sum((_angs[(k + 1) % len(_angs)] - _angs[k] + math.pi) % (2 * math.pi) - math.pi for k in range(len(_angs)))
if _turn < 0:
    SEAM_LOOP = SEAM_LOOP[:1] + SEAM_LOOP[1:][::-1]
print('seam loop', len(SEAM_LOOP), 'of', len(SEAM_SRC), 'degree', sorted(set(len(v) for v in _nbr.values())))
NECK_C = SEAM_P.mean(0)
_srel = SEAM_P - HC
SEAM_AZ = np.degrees(np.arctan2(_srel[:, 0], -_srel[:, 2]))
SEAM_EL = np.degrees(np.arcsin(_srel[:, 1] / np.linalg.norm(_srel, axis=1)))
seam_el_fn = periodic_interp(list(zip(SEAM_AZ.tolist(), SEAM_EL.tolist())))
# 맨 위(정수리) 정점 하나 = 머리뼈에 통째로 붙은 정점(이음새 밖 새 정점은 이 정점의 뼈 가중치를 베낀다)
RIGID_SRC = int(np.argmax(P[:, 1]))

ROWS_EL = np.zeros((2 + len(FACE_ROWS), NC))
_e0 = seam_el_fn(COLS) + 2.5
ROWS_EL[0] = _e0
ROWS_EL[1] = (_e0 + FACE_ROWS[0]) / 2
for k_, e_ in enumerate(FACE_ROWS):
    ROWS_EL[2 + k_] = e_
NR = ROWS_EL.shape[0]
A_GRID = np.tile(COLS, (NR, 1))

# ── 승인 머리 떠내기: 바깥 면(가장 먼 교점). 살 = 그대로 · 머리카락 = 두피 지도 · 눈/코/귀 = 이웃으로 채움 ──
_dirs = to_dir(A_GRID, ROWS_EL).reshape(-1, 3)
_t, _i = raycast(HC, _dirs, TRI, far=True)
_cls = np.where(_i >= 0, tcls[np.maximum(_i, 0)], -1)
RAD = np.full(len(_dirs), np.nan)
RAD[_cls == 0] = _t[_cls == 0]
_hair_dir = _cls == 1
RAD[_hair_dir] = head_r(A_GRID.reshape(-1)[_hair_dir], ROWS_EL.reshape(-1)[_hair_dir])
RAD = RAD.reshape(NR, NC)
_fill = np.isnan(RAD)
RAD[_fill] = np.nanmean(RAD)
for _ in range(300):
    up_ = np.vstack([RAD[1:], RAD[-1:]]); dn_ = np.vstack([RAD[:1], RAD[:-1]])
    avg = (np.roll(RAD, 1, 1) + np.roll(RAD, -1, 1) + up_ + dn_) / 4
    RAD[_fill] = avg[_fill]
# 좌우 대칭
RAD = (RAD + RAD[:, MIRROR]) / 2
# 두개골(이마선 위 · 뒤통수): 두피 지도 값을 한 번 더 고르게 — 민머리에 혹이 없게.
_skull = (ROWS_EL >= 21) | ((np.abs((A_GRID + 180) % 360 - 180) > 70) & (ROWS_EL >= -20))
for _ in range(6):
    up_ = np.vstack([RAD[1:], RAD[-1:]]); dn_ = np.vstack([RAD[:1], RAD[:-1]])
    avg = (np.roll(RAD, 1, 1) + np.roll(RAD, -1, 1) + up_ + dn_ + 4 * RAD) / 8
    RAD[_skull] = avg[_skull]
RAD = (RAD + RAD[:, MIRROR]) / 2
# 뒷머리 아래(귀 뒤 · 목덜미): 두피 지도는 목 위로 풍선처럼 처진다(승인 모델은 곱슬머리가 가렸던 자리).
#   → 두개골 점(고도 −8°)에서 목 이음새까지 S 곡선으로 다시 잡는다: 위는 두개골을 따라 아래로, 아래는 목처럼 곧게 아래로.
_seam_r_fn = periodic_interp(list(zip(SEAM_AZ.tolist(), np.linalg.norm(SEAM_P - HC, axis=1).tolist())))
_r8 = 2 + FACE_ROWS.index(-8)
_r1 = 2 + FACE_ROWS.index(-1)
for j in range(NC):
    if abs(COLS[j]) < 100:
        continue
    def _hy(el_, r_):
        return np.array([r_ * math.cos(math.radians(el_)), r_ * math.sin(math.radians(el_))])
    S_ = _hy(-8.0, RAD[_r8, j]); S2_ = _hy(-1.0, RAD[_r1, j])
    N_ = _hy(float(seam_el_fn(COLS[j])), float(_seam_r_fn(COLS[j])))
    L_ = np.linalg.norm(N_ - S_)
    T0 = (S_ - S2_) / np.linalg.norm(S_ - S2_) * L_
    T1 = np.array([0.0, -1.0]) * L_
    ts = np.linspace(0, 1, 400)[:, None]
    C_ = ((2 * ts ** 3 - 3 * ts ** 2 + 1) * S_ + (ts ** 3 - 2 * ts ** 2 + ts) * T0 +
          (-2 * ts ** 3 + 3 * ts ** 2) * N_ + (ts ** 3 - ts ** 2) * T1)
    c_el = np.degrees(np.arctan2(C_[:, 1], C_[:, 0])); c_r = np.hypot(C_[:, 0], C_[:, 1])
    for k_ in range(_r8):
        want = ROWS_EL[k_, j]
        hit_ = np.where((c_el[:-1] - want) * (c_el[1:] - want) <= 0)[0]
        if len(hit_):
            q = hit_[0]
            w_ = (want - c_el[q]) / (c_el[q + 1] - c_el[q] + 1e-12)
            RAD[k_, j] = c_r[q] + (c_r[q + 1] - c_r[q]) * w_
# 관자놀이(이마 위 · 방위 ±41~77°): 승인 얼굴은 좁은 쐐기라 민머리에서 위에서 보면 이마가 뾰족하다 → 가로로 고른 값만큼 채운다(파이지 않게).
for k_ in [2 + FACE_ROWS.index(e) for e in (13, 21, 30, 40, 51)]:
    row_ = RAD[k_].copy()
    sm_ = row_.copy()
    for _ in range(8):
        sm_ = (np.roll(sm_, 1) + 2 * sm_ + np.roll(sm_, -1)) / 4
    zone = (np.abs(COLS) >= 36) & (np.abs(COLS) <= 90)
    RAD[k_, zone] = np.maximum(row_[zone], sm_[zone])
# 볼·턱 뒤·귀 둘레(방위 64~126°, 턱 밑 ~ 눈 높이): 원래 조각의 잔결·귀 메움 자국이 주름으로 보인다 → 고르게.
_cheek = (np.abs(A_GRID) >= 64) & (np.abs(A_GRID) <= 126) & (ROWS_EL >= -58) & (ROWS_EL <= 6)
for _ in range(5):
    up_ = np.vstack([RAD[1:], RAD[-1:]]); dn_ = np.vstack([RAD[:1], RAD[:-1]])
    avg = (np.roll(RAD, 1, 1) + np.roll(RAD, -1, 1) + up_ + dn_ + 4 * RAD) / 8
    RAD[_cheek] = avg[_cheek]
RAD = (RAD + RAD[:, MIRROR]) / 2
# 귀 뒤·목덜미 깎기(2026-11-28 사용자 "뒤통수에서 목이랑 이어지는 부분이 너무 뭉툭 — 더 깎아"):
#   S 곡선만으로는 두개골 → 목 이음새가 긴 비탈(옆에서 보면 귀 뒤가 통째로 두툼)이었다.
#   → 두개골 밑면(뒤 1.524 m · 귀 밑 1.498 m, 목 쪽으로 살짝 내려가는 판) 아래는 잘라 내고,
#     목 이음새 고리를 위로 뽑아 올린 목기둥(위 끝은 살짝 벌어진다)과 합친다. 귀 앞(방위 84° 안)은 그대로.
_nrel = SEAM_P - NECK_C
_nphi = np.degrees(np.arctan2(_nrel[:, 0], -_nrel[:, 2]))
_nrad = np.hypot(_nrel[:, 0], _nrel[:, 2])
_nu, _ni = np.unique(np.round(_nphi, 3), return_index=True)
neck_r_fn = periodic_interp(list(zip(_nu.tolist(), _nrad[_ni].tolist())))
NAPE_RIM = periodic_interp([(90, 1.498), (110, 1.505), (140, 1.518), (180, 1.524), (-90, 1.498), (-110, 1.505), (-140, 1.518), (0, 1.40)])
NAPE_SLOPE, NAPE_H = 0.12, 0.15


def _neck_flare(y_):
    return 1.0 + 0.12 * smooth(1.45, 1.535, y_)


def _ray_neck(az_, el_):
    """HC 에서 (az, el) 로 쏜 광선이 목기둥 옆면을 뚫고 나가는 거리."""
    d_ = to_dir(np.array(az_), np.array(el_))
    lo, hi = 0.0, 0.40
    for _ in range(40):
        mid = (lo + hi) / 2
        p_ = HC + d_ * mid
        q_ = p_ - NECK_C
        phi = math.degrees(math.atan2(q_[0], -q_[2]))
        inside = math.hypot(q_[0], q_[2]) < float(neck_r_fn(phi)) * _neck_flare(p_[1])
        lo, hi = (mid, hi) if inside else (lo, mid)
    return (lo + hi) / 2


RAD_PRE = RAD.copy()        # 깎기 전(매끈한 비탈) — 헤어 머리선 고도는 이것으로 정한다(cap_solid · el_at_height_smooth)
for j in range(NC):
    w_ = float(smooth(84, 106, abs(COLS[j])))
    if w_ <= 0:
        continue
    y_rim = float(NAPE_RIM(COLS[j]))
    for i in range(NR):
        el_ = ROWS_EL[i, j]
        if el_ > -8:
            continue
        s_, c_ = math.sin(math.radians(-el_)), math.cos(math.radians(el_))
        r_clip = (HC[1] - y_rim + NAPE_SLOPE * NAPE_H) / (s_ + NAPE_SLOPE * c_)
        r_new = max(min(RAD[i, j], r_clip), _ray_neck(COLS[j], el_))
        RAD[i, j] += w_ * (r_new - RAD[i, j])
RAD = (RAD + RAD[:, MIRROR]) / 2
# 눈자리: 눈알 가운데 깊이까지 판다(눈알 반이 튀어나오게 — 승인 모델처럼 툭 튀어나온 카툰 눈).
for c_ in EYE_C:
    rel_ = c_ - HC
    d_eye = np.linalg.norm(rel_)
    ang = np.degrees(np.arccos(np.clip((to_dir(A_GRID, ROWS_EL) @ (rel_ / d_eye)), -1, 1)))
    inside = ang < np.degrees(np.arcsin(EYE_R * 0.92 / d_eye))
    RAD[inside] = np.minimum(RAD[inside], d_eye - 0.004)
POLE_R = float(head_r(0.0, 90.0))


def _bilinear_grid(az, el, src=None):
    """새 머리 껍데기 반지름(얼굴 줄 이상). 방위는 한 바퀴, 고도는 −58° 아래를 −58° 값으로. src = 다른 반지름 표(깎기 전)."""
    src = RAD if src is None else src
    az = (np.asarray(az, float) + 180) % 360 - 180
    el = np.asarray(el, float)
    cols = np.concatenate([[COLS[-1] - 360], COLS])                 # −180 … 180
    rad = np.hstack([src[2:, -1:], src[2:]])
    rows = np.array(FACE_ROWS + [90.0])
    rad = np.vstack([rad, np.full((1, rad.shape[1]), POLE_R)])
    ja = np.clip(np.searchsorted(cols, az) - 1, 0, len(cols) - 2)
    je = np.clip(np.searchsorted(rows, np.clip(el, rows[0], 90.0)) - 1, 0, len(rows) - 2)
    ta = (az - cols[ja]) / (cols[ja + 1] - cols[ja])
    te = np.clip((np.clip(el, rows[0], 90.0) - rows[je]) / (rows[je + 1] - rows[je]), 0, 1)
    return (rad[je, ja] * (1 - ta) * (1 - te) + rad[je, ja + 1] * ta * (1 - te) +
            rad[je + 1, ja] * (1 - ta) * te + rad[je + 1, ja + 1] * ta * te)


# 둥근 인형 뒤통수(v5, 2026-11-28 사용자 "옆에서 보면 뒤통수가 너무 크다 · 게임이니 더 깎아서" →
#   "크기만 줄인 것 같다 · 두개골 모양이 아닌 인형 머리처럼 원형으로 보여야 민머리가 예쁘다 · 점 1개 말고 10개쯤 더 ·
#   위에서 봤을 때 각이 둥글게"):
#   귀 줄 평면(z = BACK_ZC) 뒤를 새로 그린다.
#   - 높이 y 의 가로 단면 = 타원 호: 옆 반지름 W(y) = 그 높이에서 귀 줄 평면의 원래 머리 반폭, 뒤 반지름 D(y).
#     → 위에서 보면 귀 줄에서 매끈하게 이어지는 둥근 호(꺾인 모서리 없음).
#   - D(y) 도 타원 = 옆에서 본 뒤통수도 둥근 호: 가장 튀어나온 높이 BACK_YB 에서 BACK_D,
#     위로 BACK_HUP 가면 0(정수리), 아래로 BACK_HLO 가면 0(목 쪽으로 공처럼 말려 들어감). 그 아래는 목기둥과 합친다.
#   - 점: 뒤쪽 세로줄을 한쪽 3 → 8개(AZ_HALF, 약 10° 간격)로 늘렸다(양쪽 합쳐 10개 더).
#   헤어 부품은 이 머리(head_r) 위에 다시 얹으므로 그대로 붙는다.
BACK_ZC, BACK_D, BACK_YB, BACK_HUP, BACK_HLO = -0.05, 0.13, 1.60, 0.175, 0.11
NECK_TOP = 1.56          # 목기둥은 이 높이 아래만(위는 공 모양 뒤통수)


def _back_depth(y_, hlo=BACK_HLO):
    t_ = np.where(y_ >= BACK_YB, (y_ - BACK_YB) / BACK_HUP, (BACK_YB - y_) / hlo)
    return BACK_D * np.sqrt(np.clip(1 - t_ ** 2, 0, 1))


def _half_width_fn(src):
    """귀 줄 평면(z = BACK_ZC)에서 높이별 원래 머리 반폭 W(y)."""
    ys = np.linspace(1.36, 1.80, 221)
    lo = np.zeros_like(ys); hi = np.full_like(ys, 0.30)
    for _ in range(40):
        mid = (lo + hi) / 2
        rel = np.stack([mid, ys - HC[1], np.full_like(ys, BACK_ZC - HC[2])], -1)
        rr = np.linalg.norm(rel, axis=-1)
        a_ = np.degrees(np.arctan2(rel[:, 0], -rel[:, 2])); e_ = np.degrees(np.arcsin(rel[:, 1] / rr))
        inside = rr < _bilinear_grid(a_, e_, src)
        lo = np.where(inside, mid, lo); hi = np.where(inside, hi, mid)
    w_ = (lo + hi) / 2
    w_[w_ < 1e-3] = 0.0
    return lambda y_: np.interp(y_, ys, w_)


def _neck_inside(p_):
    q_ = p_ - NECK_C
    phi = np.degrees(np.arctan2(q_[..., 0], -q_[..., 2]))
    r_n = np.asarray(neck_r_fn(phi.reshape(-1)), float).reshape(phi.shape)
    return (np.hypot(q_[..., 0], q_[..., 2]) < r_n * _neck_flare(p_[..., 1])) & (p_[..., 1] < NECK_TOP)


def _round_back(src, hlo=BACK_HLO):
    """반지름 표 src 의 귀 줄 뒤를 '둥근 인형 뒤통수 + 목기둥'으로 바꾼 반지름 표(같은 방향 광선의 경계 — 이분법)."""
    W_ = _half_width_fn(src)
    out = src.copy()
    A_ = A_GRID[2:]; E_ = ROWS_EL[2:]
    d_ = to_dir(A_, E_)
    lo = np.full(A_.shape, 0.02); hi = np.full(A_.shape, 0.45)
    for _ in range(44):
        mid = (lo + hi) / 2
        p_ = HC + d_ * mid[..., None]
        rel = p_ - HC
        rr = np.linalg.norm(rel, axis=-1)
        a_ = np.degrees(np.arctan2(rel[..., 0], -rel[..., 2]))
        e_ = np.degrees(np.arcsin(np.clip(rel[..., 1] / rr, -1, 1)))
        front = rr < _bilinear_grid(a_, e_, src)
        w_ = np.maximum(W_(p_[..., 1]), 1e-6); dd = np.maximum(_back_depth(p_[..., 1], hlo), 1e-6)
        ball = (p_[..., 0] / w_) ** 2 + ((p_[..., 2] - BACK_ZC) / dd) ** 2 < 1
        inside = np.where(p_[..., 2] <= BACK_ZC, front, ball | _neck_inside(p_))
        lo = np.where(inside, mid, lo); hi = np.where(inside, hi, mid)
    out[2:] = np.where(d_[..., 2] > -0.25, (lo + hi) / 2, src[2:])     # 얼굴 쪽은 원래 값 그대로
    return out


_back_before = float(_bilinear_grid(180.0, -4.0))
RAD = _round_back(RAD)
RAD = (RAD + RAD[:, MIRROR]) / 2
RAD_PRE = _round_back(RAD_PRE, hlo=0.16)     # 머리선 높이 → 고도용: 아래를 더 완만하게(밑판에서 고도가 튀지 않게)
RAD_PRE = (RAD_PRE + RAD_PRE[:, MIRROR]) / 2
print('back of skull (az 180, el -4): r %.3f -> %.3f' % (_back_before, float(_bilinear_grid(180.0, -4.0))))


head_r_old = head_r
head_r = _bilinear_grid          # 이제부터 헤어 부품도 새 두개골 위에 얹는다


def el_at_height_smooth(az, y_target):
    """헤어 머리선 높이 → 고도. 깎기 전 매끈한 머리(RAD_PRE)로 잰다: 깎은 머리는 두개골 밑판이 거의 평평해서
    높이 몇 mm 차이에 고도가 크게 튀어(머리선이 판을 가로지르는 곳) 머리선이 찢어진 틈처럼 보였다(2026-11-28 v4)."""
    lo = np.full(np.shape(az), -60.0); hi = np.full(np.shape(az), 89.0)
    for _ in range(40):
        mid = (lo + hi) / 2
        y = HC[1] + np.sin(np.radians(mid)) * _bilinear_grid(az, mid, RAD_PRE)
        below = y < y_target
        lo = np.where(below, mid, lo); hi = np.where(below, hi, mid)
    return (lo + hi) / 2


# ═══════════════ 인형 머리 v6: 승인 얼굴 원본 면 + 둥근 인형 두피 ═══════════════
# 승인 얼굴 원본 면 + 둥근 인형 두피(v6, 2026-11-28 밤).
# hair_geo3.py 안에서 exec 된다(P, IDX, vcls, polar, to_dir, HC, RAD, _bilinear_grid, SEAM_*, EYE_C, smooth 를 쓴다).
#
# 사용자 "승인 모델의 원본으로 따라가자 · 많지만 들어가고 나오는 부분으로 각을 만들어 이목구비를 구성 ·
# 좌우 대칭 · 더 많은 점 · 면도 승인 모델처럼 · 우리 캐릭터는 매끈하게 하지 않으니 각이 얼굴을 구성하는 게 포인트".
#
#   1) 얼굴(K): 승인 머리 면에서 머리카락 · 목 이음새 한 줄 · 뒷목(헤어 밑에서 두꺼워지는 곳)을 뺀 면을 **그대로** 쓴다.
#      눈썹 뼈 · 눈두덩 · 눈알 · 상자 코 · 광대 판 · 턱 · 귀 · 목 앞이 승인 면 그대로 남는다.
#   2) 좌우 대칭: 오른쪽 반(+X)을 x = 0 에서 잘라 거울로 붙인다(정확한 대칭, 판·모서리가 같은 자리).
#   3) 두피(D): 나머지(이마선 위 · 옆머리 자리 · 귀 뒤 · 뒤통수 · 뒷목)는 v5 둥근 인형 머리(RAD) 위에 점을 고르게 깔고
#      구면 들로네로 잇는다. 경계에서는 승인 면 높이에 맞춰 붙고(차이는 안쪽으로 갈수록 사라진다) 목 이음새 118점은 원래 자리.
#   4) 음영: 승인 모델과 같이 이웃 면 넓이 가중 평균 법선(각은 면의 기하가 만든다).
from collections import defaultdict
from scipy.spatial import ConvexHull, cKDTree
import scipy.sparse as _sp
import scipy.sparse.linalg as _spl

DOME_STEP = 4.5           # 두피 점 간격(°)
SLOPE_REACH = 11.0        # 경계 기울기를 이어받는 두피 범위(°)
SLOPE_W = 1.5             # 그 목표값을 따르는 세기(이웃 평균 대비)
SLOPE_MAX = 0.12          # 기울기 상한(m/rad)
DOME_DECAY = 0.05         # 경계 높이 차가 안쪽으로 사라지는 빠르기(작을수록 멀리 번진다 — 0.05 ≈ 5 cm)
NECK_DECAY_K = 1.0        # 목 높이에서는 그 빠르기에 이 배수(턱 너비가 목 뒤까지 부드럽게 번진다)


def _weld(P_):
    key_ = np.round(P_ / 1e-5).astype(np.int64)
    _, first_, inv_ = np.unique(key_, axis=0, return_index=True, return_inverse=True)
    return P_[first_], first_, inv_.reshape(-1)


AW, AW_FIRST, AW_INV = _weld(P)                 # 승인 머리 정점(용접)
AF = AW_INV[IDX]                                 # 승인 면(Godot 순서: (c−a)×(b−a) 가 바깥)
AW_CLS = np.zeros(len(AW), int)
np.maximum.at(AW_CLS, AW_INV, vcls)
SEAM_W = AW_INV[SEAM_SRC]                        # 이음새 118점(용접 번호)


def _boundary_loops(F_):
    cnt = defaultdict(int)
    for a_, b_, c_ in F_:
        for e0, e1 in ((a_, b_), (b_, c_), (c_, a_)):
            cnt[(e0, e1)] += 1
    # 방향 있는 경계 변: 반대 방향 변이 없는 것
    bd = [(e0, e1) for (e0, e1) in cnt if (e1, e0) not in cnt]
    nxt = defaultdict(list)
    for e0, e1 in bd:
        nxt[e0].append(e1)
    return bd, nxt


SEAM_GAP = 0.010          # 얼굴(K) 아래 끝은 목 이음새에서 이만큼(3D 거리) 떨어진다 — 그 사이 띠는 두피 삼각형이 잇는다
# 얼굴(K) 옆 경계(방위°) — 승인 머리카락 경계(관자 51° · 볼 57~58° · 귀 밑 목 98~100°)보다 조금 안쪽의 매끈한 선.
#   머리카락 색 경계(들쭉날쭉)를 그대로 쓰면 민머리에서 톱니 자국 · 턱 뒤 판처럼 튀어나온 모서리가 보였다(2026-11-28 밤).
TEMPLE_AZ, SIDE_AZ, NECK_AZ = 49.0, 56.0, 64.0
_sa = np.argsort(SEAM_AZ)
_SEAM_AZ_S, _SEAM_Y_S = SEAM_AZ[_sa], SEAM_P[_sa, 1]


def _side_limit(el_):
    """고도별 얼굴 옆 경계 방위: 관자(고도 8° 위) 49° · 볼·턱 56° · 귀 밑(고도 −46° 아래) 목 86°."""
    a_ = SIDE_AZ + (TEMPLE_AZ - SIDE_AZ) * smooth(4.0, 12.0, el_)
    return a_ + (NECK_AZ - SIDE_AZ) * (1 - smooth(-47.0, -39.0, el_))


_SEAM_LP = P[[int(SEAM_SRC[k_]) for k_ in SEAM_LOOP]]   # 목 이음새 고리(차례대로)


def _seam_dist(V_):
    """정점마다 목 이음새 꺾은선까지 3D 거리(m)."""
    A_ = _SEAM_LP
    B_ = np.roll(A_, -1, axis=0)
    AB = B_ - A_
    best = np.full(len(V_), np.inf)
    for k_ in range(len(A_)):
        t_ = np.clip(((V_ - A_[k_]) @ AB[k_]) / max(AB[k_] @ AB[k_], 1e-18), 0.0, 1.0)
        d_ = np.linalg.norm(V_ - (A_[k_] + t_[:, None] * AB[k_]), axis=1)
        best = np.minimum(best, d_)
    return best


def _region_f(V_):
    """얼굴(K) 영역 함수: ≤ 0 이면 얼굴. 이마 위 곡선 · 옆 경계 · 목 이음새에서 띄우는 간격의 교집합(도 단위).
    목 이음새 간격은 높이(y)가 아니라 이음새 꺾은선까지 3D 거리로 잰다 — 높이로 재면 이음새보다 낮은 턱 밑면이
    통째로 잘려 두피가 덮었다(2026-11-28 밤 q3)."""
    _, az_, el_ = polar(V_)
    f_top = _forehead_f(V_)
    f_side = np.abs(az_) - _side_limit(el_)
    f_seam = (SEAM_GAP - _seam_dist(V_)) * 250.0          # 1 mm ≈ 0.25°
    return np.maximum(np.maximum(f_top, f_side), f_seam)


def _components(F_, mask):
    """mask 면들의 변 이웃 덩어리 번호(마스크 밖은 −1)."""
    idx_ = np.where(mask)[0]
    par = {int(i): int(i) for i in idx_}

    def find(x):
        while par[x] != x:
            par[x] = par[par[x]]
            x = par[x]
        return x
    ef = defaultdict(list)
    for fi in idx_:
        t = F_[fi]
        for e in ((t[0], t[1]), (t[1], t[2]), (t[2], t[0])):
            ef[(min(e), max(e))].append(int(fi))
    for fl in ef.values():
        for g in fl[1:]:
            a_, b_ = find(fl[0]), find(g)
            if a_ != b_:
                par[a_] = b_
    lab = -np.ones(len(F_), int)
    for fi in idx_:
        lab[fi] = find(int(fi))
    return lab


BROW_TOP_EL = 27.0        # 이마 위 경계(고도°): 승인 머리선의 M자 홈(27.6°) 바로 위 — 민머리에서 매끈한 호로 보이게
TEMPLE_DROP = (36.0, 56.0, 10.0)   # 관자놀이에서 경계를 내리는 방위 구간과 깊이(°)


def _forehead_f(V_):
    """이마 위 자르는 곡선: f > 0 이면 두피 쪽(자른다)."""
    _, az_, el_ = polar(V_)
    a0, a1, dz = TEMPLE_DROP
    return el_ - (BROW_TOP_EL - dz * smooth(a0, a1, np.abs(az_)))


def _clip_keep(V_, F_, src_, fval):
    """fval ≤ 0 쪽만 남긴다. 경계를 지나는 삼각형은 경계 위 새 점(변 위 선형 보간)으로 잘라 나눈다."""
    eps = 1e-6
    fv = np.where(np.abs(fval) < eps, 0.0, fval)
    side = np.where(fv < 0, 1, np.where(fv > 0, -1, 0))
    V2 = [p.copy() for p in V_]
    S2 = list(src_)
    cache = {}

    def mid(a_, b_):
        k_ = (min(a_, b_), max(a_, b_))
        if k_ not in cache:
            t_ = fv[a_] / (fv[a_] - fv[b_])
            cache[k_] = len(V2)
            V2.append(V_[a_] + t_ * (V_[b_] - V_[a_]))
            S2.append(S2[a_] if t_ < 0.5 else S2[b_])
        return cache[k_]
    out = []
    for f in F_:
        s = side[f]
        if (s >= 0).all():
            if (s == 0).all():
                continue
            out.append(list(f))
            continue
        if (s <= 0).all():
            continue
        poly = []
        for k_ in range(3):
            a_, b_ = f[k_], f[(k_ + 1) % 3]
            if s[k_] >= 0:
                poly.append(a_)
            if s[k_] * s[(k_ + 1) % 3] < 0:
                poly.append(mid(a_, b_))
        for k_ in range(1, len(poly) - 1):
            out.append([poly[0], poly[k_], poly[k_ + 1]])
    V2 = np.array(V2)
    out = np.array(out)
    used = np.unique(out)
    remap = -np.ones(len(V2), int)
    remap[used] = np.arange(len(used))
    return V2[used], remap[out], np.array(S2)[used]


def _cut_right(V_, F_, src_):
    """x ≥ 0 쪽만 남긴다(x = 0 을 지나는 삼각형은 잘라 나눈다). src_ = 정점마다 승인 원본 번호."""
    eps = 1e-9
    side = np.where(V_[:, 0] > eps, 1, np.where(V_[:, 0] < -eps, -1, 0))
    V2 = [p.copy() for p in V_]
    S2 = list(src_)
    for i in np.where(side == 0)[0]:
        V2[i][0] = 0.0
    cache = {}

    def mid(a_, b_):
        k_ = (min(a_, b_), max(a_, b_))
        if k_ not in cache:
            pa, pb = V_[a_], V_[b_]
            t_ = pa[0] / (pa[0] - pb[0])
            p_ = pa + t_ * (pb - pa)
            p_[0] = 0.0
            cache[k_] = len(V2)
            V2.append(p_)
            S2.append(S2[a_] if abs(pa[0]) < abs(pb[0]) else S2[b_])
        return cache[k_]
    out = []
    for f in F_:
        s = side[f]
        if (s >= 0).all():
            if (s == 0).all():
                continue
            out.append(list(f))
            continue
        if (s <= 0).all():
            continue
        poly = []
        for k_ in range(3):
            a_, b_ = f[k_], f[(k_ + 1) % 3]
            if s[k_] >= 0:
                poly.append(a_)
            if s[k_] * s[(k_ + 1) % 3] < 0:
                poly.append(mid(a_, b_))
        for k_ in range(1, len(poly) - 1):
            out.append([poly[0], poly[k_], poly[k_ + 1]])
    V2 = np.array(V2)
    out = np.array(out)
    used = np.unique(out)
    remap = -np.ones(len(V2), int)
    remap[used] = np.arange(len(used))
    return V2[used], remap[out], np.array(S2)[used]


def _mirror(V_, F_, src_):
    mid_ = np.abs(V_[:, 0]) < 1e-12
    n_ = len(V_)
    others = np.where(~mid_)[0]
    mi = np.arange(n_)
    mi[others] = n_ + np.arange(len(others))
    VL = V_[others] * np.array([-1.0, 1.0, 1.0])
    V2 = np.vstack([V_, VL])
    F2 = np.vstack([F_, mi[F_][:, [0, 2, 1]]])
    S2 = np.concatenate([src_, src_[others]])
    side = np.concatenate([np.where(mid_, 0, 1), -np.ones(len(others), int)])
    return V2, F2, S2, side


def _split_edge(V_, F_, S_, a_, b_):
    """경계 변 (a, b) 가운데에 점을 넣고 그 변을 가진 면을 둘로 나눈다(같은 평면 — 모양은 그대로)."""
    m_ = len(V_)
    V_ = np.vstack([V_, (V_[a_] + V_[b_]) / 2])
    S_ = np.append(S_, S_[a_])
    F_ = F_.tolist()
    for fi, f in enumerate(F_):
        for k_ in range(3):
            if f[k_] == a_ and f[(k_ + 1) % 3] == b_ or f[k_] == b_ and f[(k_ + 1) % 3] == a_:
                c_ = f[(k_ + 2) % 3]
                p_, q_ = f[k_], f[(k_ + 1) % 3]
                F_[fi] = [p_, m_, c_]
                F_.append([m_, q_, c_])
                return V_, np.array(F_), S_, m_
    raise RuntimeError('edge not found')


def _hair_faces():
    return (AW_CLS[AF] == 1).all(1)


def build_face_k():
    """승인 얼굴(K) — 매끈한 영역 선으로 자른 승인 면(오른쪽 반을 거울로 붙인 정확한 대칭). (V, F(Godot 순서), 승인 원본 번호)"""
    F0 = AF[~_hair_faces()]
    used = np.unique(F0)
    remap = -np.ones(len(AW), int)
    remap[used] = np.arange(len(used))
    V0 = AW[used]
    S0 = AW_FIRST[used]
    V0, F0c, S0 = _clip_keep(V0, remap[F0], S0, _region_f(V0))
    VR, FR, SR = _cut_right(V0, F0c, S0)
    V_, F_, S_, side = _mirror(VR, FR, SR)
    return V_, F_, S_


EAR_BOX = (64.0, 108.0, -48.0, 4.0)   # 귀 상자(방위° 최소·최대, 고도° 최소·최대) — 승인 귀 둘레


def build_ears():
    """승인 귀(오른쪽 귀를 거울로 왼쪽에도). 승인 모델은 귀 바깥 테두리(C자)만 '귀' 색 분류이고
    귓바퀴 안쪽 · 귓구멍 둘레 · 귀 뒷면은 살 색 분류다 → 귀 상자 안의 머리카락 아닌 면 중 테두리와 이어진 덩어리 전부.
    (테두리만 쓰면 귀가 얇은 C 고리만 남아 작고 묻혀 보였다 — 2026-11-28 밤 q3.) 두피 위에 따로 얹는다."""
    C_ = AW[AF].mean(1)
    _, azc, elc = polar(C_)
    a0, a1, e0, e1 = EAR_BOX
    box = (~_hair_faces()) & (azc > a0) & (azc < a1) & (elc > e0) & (elc < e1)
    rim = (AW_CLS[AF] == 4).all(1) & (C_[:, 0] > 0) & box
    lab = _components(AF, box)
    F0 = AF[np.isin(lab, np.unique(lab[rim]))]
    used = np.unique(F0)
    remap = -np.ones(len(AW), int)
    remap[used] = np.arange(len(used))
    V_, F_, S_, side = _mirror(AW[used], remap[F0], AW_FIRST[used])
    return V_, F_, S_


def _loops_of(F_):
    bd, nxt = _boundary_loops(F_)
    bad = [v for v, l in nxt.items() if len(l) != 1]
    loops = []
    seen = set()
    for e0, e1 in bd:
        if e0 in seen:
            continue
        loop = [e0]
        seen.add(e0)
        cur = e1
        guard = 0
        while cur != e0 and guard < 100000:
            loop.append(cur)
            seen.add(cur)
            cur = nxt[cur][0]
            guard += 1
        loops.append(loop)
    return loops, bad


def _fix_pinches(V_, F_, S_):
    """한 점에서 경계가 두 번 지나는 곳(꼬집힌 점): 그 점을 쓰는 작은 쪽 면 부채를 떼어 낸다."""
    for _ in range(20):
        loops, bad = _loops_of(F_)
        if not bad:
            return V_, F_, S_
        drop = np.zeros(len(F_), bool)
        for v in bad:
            fs = np.where((F_ == v).any(1))[0]
            # 면 부채를 변 이웃으로 묶는다
            groups = []
            left = set(fs.tolist())
            while left:
                g = [left.pop()]
                k_ = 0
                while k_ < len(g):
                    f = F_[g[k_]]
                    for h in list(left):
                        if len(set(F_[h]) & set(f)) >= 2:
                            g.append(h)
                            left.discard(h)
                    k_ += 1
                groups.append(g)
            groups.sort(key=len)
            for g in groups[:-1]:
                drop[g] = True
        F_ = F_[~drop]
    return V_, F_, S_


def _keep_largest(F_):
    par = np.arange(len(F_))

    def find(x):
        while par[x] != x:
            par[x] = par[par[x]]
            x = par[x]
        return x
    ef = defaultdict(list)
    for fi, t in enumerate(F_):
        for e in ((t[0], t[1]), (t[1], t[2]), (t[2], t[0])):
            ef[tuple(sorted(e))].append(fi)
    for fl in ef.values():
        for g in fl[1:]:
            a_, b_ = find(fl[0]), find(g)
            if a_ != b_:
                par[a_] = b_
    roots = np.array([find(i) for i in range(len(F_))])
    u_, c_ = np.unique(roots, return_counts=True)
    return F_[roots == u_[np.argmax(c_)]]


def _to_q(d_):
    """단위 방향 → 정수리에서 본 평면(ρ = 90 − 고도, 방위각)."""
    el_ = np.degrees(np.arcsin(np.clip(d_[:, 1], -1, 1)))
    az_ = np.degrees(np.arctan2(d_[:, 0], -d_[:, 2]))
    rho = 90.0 - el_
    return np.stack([rho * np.sin(np.radians(az_)), rho * np.cos(np.radians(az_))], -1)


def _from_q(q_):
    rho = np.hypot(q_[:, 0], q_[:, 1])
    az_ = np.degrees(np.arctan2(q_[:, 0], q_[:, 1]))
    return to_dir(az_, 90.0 - rho)


def _crossings(Q):
    """닫힌 꺾은선 Q 의 서로 엇갈리는 변 쌍(이웃 변 제외) → 관련 점 번호."""
    n_ = len(Q)
    A = Q
    d1 = np.roll(Q, -1, axis=0) - A
    hit = set()
    for i in range(n_):
        j = np.arange(i + 2, n_)
        if i == 0:
            j = j[j != n_ - 1]
        if not len(j):
            continue
        p, r = A[i], d1[i]
        q, s = A[j], d1[j]
        rxs = r[0] * s[:, 1] - r[1] * s[:, 0]
        den = np.where(np.abs(rxs) < 1e-15, 1e-15, rxs)
        qp = q - p
        t = (qp[:, 0] * s[:, 1] - qp[:, 1] * s[:, 0]) / den
        u = (qp[:, 0] * r[1] - qp[:, 1] * r[0]) / den
        bad = (np.abs(rxs) > 1e-15) & (t >= 0) & (t <= 1) & (u >= 0) & (u <= 1)
        for jj in j[bad]:
            hit |= {i, (i + 1) % n_, int(jj), int(jj + 1) % n_}
    return hit


def _untangle(Q, iters=400):
    """접힌 곳(엇갈린 변) 둘레 점만 이웃 평균 쪽으로 펴서 단순한 고리로."""
    Q = Q.copy()
    n_ = len(Q)
    for it in range(iters):
        hit = _crossings(Q)
        if not hit:
            return Q, it
        idx_ = set()
        for h in hit:
            for k_ in range(-3, 4):
                idx_.add((h + k_) % n_)
        idx_ = np.array(sorted(idx_))
        Q[idx_] = 0.5 * Q[idx_] + 0.25 * (Q[(idx_ - 1) % n_] + Q[(idx_ + 1) % n_])
    raise RuntimeError('untangle failed')


def build_dome(KV, KF, KS):
    """두피: K 바깥 경계 ↔ 목 이음새 사이를 v5 인형 머리 위의 고른 점으로 채운다.
    삼각형 잇기는 '방향 공간'(머리 가운데에서 본 방향)의 구면 들로네로 한다. 경계가 방향 공간에서 접힌 곳
    (이마 가운데 M자 머리선 · 뒷목 이음새)은 잇기용 방향만 펴고, 실제 3D 자리는 그대로 둔다."""
    loops, bad = _loops_of(KF)
    assert not bad, 'pinch left'
    seam_ids = [int(SEAM_SRC[k_]) for k_ in SEAM_LOOP]
    seam_pts = P[seam_ids]
    nsm = len(seam_ids)
    # 이음새 잇기 방향: 실제 방향, 뒷목에서 접힌 곳만 편다
    sd = seam_pts - HC
    sd /= np.linalg.norm(sd, axis=1, keepdims=True)
    Qs, _ = _untangle(_to_q(sd))
    seam_dir = _from_q(Qs)
    s_mid = seam_dir + np.roll(seam_dir, -1, axis=0)
    s_mid /= np.linalg.norm(s_mid, axis=1, keepdims=True)
    s_rad = np.linalg.norm(seam_dir - np.roll(seam_dir, -1, axis=0), axis=1) / 2
    # 두피 안쪽 점: 고도 줄마다 같은 3D 간격
    pts = []
    for el_ in np.arange(88.0, -80.0, -DOME_STEP):
        n_az = max(1, int(round(360 * np.cos(np.radians(el_)) / DOME_STEP)))
        off_ = 0.5 if int(round(el_ / DOME_STEP)) % 2 else 0.0
        for k_ in range(n_az):
            pts.append((((k_ + off_) * 360.0 / n_az + 180) % 360 - 180, el_))
    pts.append((0.0, 90.0))
    pts = np.array(pts)
    dirs_all = to_dir(pts[:, 0], pts[:, 1])
    KV = KV.copy()
    KS = KS.copy()
    pdir = {}            # K 경계 점 → 잇기용 방향(편 것)
    for it in range(30):
        loops, bad = _loops_of(KF)
        kloop = max(loops, key=len)
        nk = len(kloop)
        kd = KV[kloop] - HC
        kd /= np.linalg.norm(kd, axis=1, keepdims=True)
        for k_, v in enumerate(kloop):
            if v in pdir:
                kd[k_] = pdir[v]
        for _p in range(40):
            Qk, n_it = _untangle(_to_q(kd))
            kd = _from_q(Qk)
            # 이음새 변의 지름 원 안에 든 K 점은 잇기 방향만 위(정수리 쪽)로 민다
            dd_ = np.linalg.norm(kd[:, None, :] - s_mid[None], axis=2) / (s_rad[None] * 1.25)
            worst = dd_.min(1)
            bad_ = worst < 1.0
            if not bad_.any():
                break
            rho = np.hypot(Qk[:, 0], Qk[:, 1])
            push = np.degrees(np.min(s_rad[None] * 1.25 - dd_ * s_rad[None] * 1.25 + 1e-9, axis=1).clip(0)) + 0.15
            scale = np.where(bad_, (rho - push) / rho, 1.0)
            kd = _from_q(Qk * scale[:, None])
        for k_, v in enumerate(kloop):
            pdir[v] = kd[k_]
        bdir = np.vstack([kd, seam_dir])
        # 안쪽 점: 경계 · K 면 위 · 목 구멍 아래는 뺀다
        ok = cKDTree(bdir).query(dirs_all)[0] > np.radians(DOME_STEP) * 0.55
        kdir_now = KV - HC
        kdir_now /= np.linalg.norm(kdir_now, axis=1, keepdims=True)
        ok &= cKDTree(kdir_now).query(dirs_all)[0] > np.radians(DOME_STEP) * 0.55
        _, az_i, el_i = polar(HC + dirs_all)
        ok &= el_i > np.asarray(seam_el_fn(az_i), float) + 2.0
        ok[-1] = True
        dirs_in = dirs_all[ok]
        U = np.vstack([bdir, dirs_in])
        tri = ConvexHull(U).simplices
        edges = set()
        for a_, b_, c_ in tri:
            edges |= {(min(a_, b_), max(a_, b_)), (min(b_, c_), max(b_, c_)), (min(c_, a_), max(c_, a_))}
        missing_k = [k_ for k_ in range(nk) if (min(k_, (k_ + 1) % nk), max(k_, (k_ + 1) % nk)) not in edges]
        missing_s = [k_ for k_ in range(nsm) if (min(nk + k_, nk + (k_ + 1) % nsm), max(nk + k_, nk + (k_ + 1) % nsm)) not in edges]
        if missing_s:
            kill = set()
            for k_ in missing_s:      # 이음새 변은 나눌 수 없다 → 그 변의 지름 원 안에 든 점을 찾는다
                m_ = seam_dir[k_] + seam_dir[(k_ + 1) % nsm]
                m_ /= np.linalg.norm(m_)
                rad_ = np.linalg.norm(seam_dir[k_] - seam_dir[(k_ + 1) % nsm]) / 2
                dU = np.linalg.norm(U - m_, axis=1)
                dU[[nk + k_, nk + (k_ + 1) % nsm]] = 9
                j_ = int(np.argmin(dU))
                who = 'K' if j_ < nk else ('seam' if j_ < nk + nsm else 'in')
                print('  seam edge missing', k_, 'nearest', who, 'ratio %.2f' % (dU[j_] / rad_))
                if who == 'in':
                    kill.add(int(np.where(ok)[0][j_ - nk - nsm]))
            if kill:
                dirs_all = np.delete(dirs_all, sorted(kill), axis=0)
        if not missing_k and not missing_s:
            break
        for k_ in missing_k:
            a_, b_ = kloop[k_], kloop[(k_ + 1) % nk]
            KV, KF, KS, m_ = _split_edge(KV, KF, KS, a_, b_)
            dd = pdir[a_] + pdir[b_]
            pdir[m_] = dd / np.linalg.norm(dd)
        print('  iter', it, 'split K edges', len(missing_k), 'untangle iters', n_it)
    else:
        raise RuntimeError('boundary recovery failed')
    small = [l for l in loops if l is not kloop]
    nb = nk + nsm
    cons = set()
    for k_ in range(nk):
        cons.add((min(k_, (k_ + 1) % nk), max(k_, (k_ + 1) % nk)))
    for k_ in range(nsm):
        a_, b_ = nk + k_, nk + (k_ + 1) % nsm
        cons.add((min(a_, b_), max(a_, b_)))
    by_edge = defaultdict(list)
    for ti, (a_, b_, c_) in enumerate(tri):
        for e in ((a_, b_), (b_, c_), (c_, a_)):
            by_edge[(min(e), max(e))].append(ti)
    pole = len(U) - 1
    start = next(ti for ti, t in enumerate(tri) if pole in t)
    inside = np.zeros(len(tri), bool)
    inside[start] = True
    q = [start]
    while q:
        ti = q.pop()
        a_, b_, c_ = tri[ti]
        for e in ((a_, b_), (b_, c_), (c_, a_)):
            k_ = (min(e), max(e))
            if k_ in cons:
                continue
            for tj in by_edge[k_]:
                if not inside[tj]:
                    inside[tj] = True
                    q.append(tj)
    DT = tri[inside]
    nrm = np.cross(U[DT[:, 1]] - U[DT[:, 0]], U[DT[:, 2]] - U[DT[:, 0]])
    outward = np.sum(nrm * U[DT].mean(1), axis=1) > 0
    DT = np.where(outward[:, None], DT[:, [0, 2, 1]], DT)
    # 점 높이: 안쪽 점 = RAD + 경계 차이(가린 푸아송으로 안쪽으로 갈수록 사라진다)
    bpos = np.vstack([KV[kloop], seam_pts])
    _, az_b, el_b = polar(bpos)
    off_b = np.linalg.norm(bpos - HC, axis=1) - _bilinear_grid(az_b, el_b)
    _, az_in, el_in = polar(HC + dirs_in)
    rows, cols = [], []
    for a_, b_, c_ in DT:
        for e0, e1 in ((a_, b_), (b_, c_), (c_, a_)):
            rows += [e0, e1]
            cols += [e1, e0]
    A_ = _sp.coo_matrix((np.ones(len(rows)), (rows, cols)), shape=(len(U), len(U))).tocsr()
    A_.data[:] = 1.0
    deg = np.asarray(A_.sum(1)).reshape(-1)
    ii = np.arange(nb, len(U))
    # 목 높이(고도 −15° 아래)에서는 경계 차이가 멀리 번지게(턱 뒤 판이 목에서 툭 튀어나오지 않게 — 2026-11-28 밤 q5)
    decay_i = DOME_DECAY * (NECK_DECAY_K + (1 - NECK_DECAY_K) * smooth(-35.0, -15.0, el_in))
    # 경계 기울기 잇기: 승인 면(K)이 경계에서 나가던 기울기를 두피 첫 줄들이 이어받게(부드러운 목표값).
    #   그냥 두면 두피가 경계에서 바로 안으로 꺾여(높이만 맞고 기울기는 끊김) 턱 옆면이 목에서 판처럼 튀어나와 보였다(q8).
    kdir_r = KV[kloop] - HC
    kdir_r /= np.linalg.norm(kdir_r, axis=1, keepdims=True)
    # 기울기 = 경계 안쪽 2~8 고리 승인 점들(경계에서 2~9° 안)의 높이 차 ÷ 각도의 중앙값 → 고리를 따라 이웃 평균
    ring = _ring_dist(KF, len(KV), list(kloop), 8)
    cand = np.where((ring >= 2) & (ring <= 8))[0]
    cd = KV[cand] - HC
    cr = np.linalg.norm(cd, axis=1)
    cd /= cr[:, None]
    _, az_c, el_c = polar(KV[cand])
    u_c = cr - _bilinear_grid(az_c, el_c)
    ctree = cKDTree(cd)
    slope = np.zeros(nk)
    for k_ in range(nk):
        js = ctree.query_ball_point(kdir_r[k_], np.radians(9.0))
        if not js:
            continue
        js = np.array(js)
        ang = np.arccos(np.clip(cd[js] @ kdir_r[k_], -1, 1))
        ok_ = ang > np.radians(2.0)
        if ok_.sum() >= 3:
            slope[k_] = np.median((off_b[k_] - u_c[js][ok_]) / ang[ok_])
    for _ in range(3):
        slope = (np.roll(slope, 1) + 2 * slope + np.roll(slope, -1)) / 4
    slope = np.clip(slope, -SLOPE_MAX, SLOPE_MAX)
    dk, jk = cKDTree(kdir_r).query(dirs_in)
    reach = np.radians(SLOPE_REACH)
    near_ = dk < reach
    lam = np.where(near_, SLOPE_W * (1 - dk / reach) ** 2, 0.0) * deg[ii]
    target = off_b[jk] + slope[jk] * dk
    print('  slope continuation: %d dome pts · slope m/rad median %.3f p5 %.3f p95 %.3f' % (
        int(near_.sum()), np.median(slope), np.percentile(slope, 5), np.percentile(slope, 95)))
    L_ii = (_sp.diags(deg[ii] * (1 + decay_i) + lam) - A_[ii][:, ii]).tocsc()
    off_in = _spl.spsolve(L_ii, A_[ii][:, :nb] @ off_b + lam * target)
    pos_in = HC + dirs_in * (_bilinear_grid(az_in, el_in) + off_in)[:, None]
    return KV, KF, KS, kloop, seam_ids, pos_in, DT, nb, nk, small


EAR_SINK = 0.003          # 귀 뿌리 테두리가 두피 속으로 들어가는 깊이(m)
EAR_PULL_RINGS = 2        # 두피 밖으로 나온 뿌리 점을 안으로 당기는 범위(경계에서 고리 수)


def _ring_dist(F_, n_v, seeds, n_rings):
    """seeds 정점에서 변을 따라 몇 고리 떨어졌는지(n_rings 넘으면 n_rings+1)."""
    nb = defaultdict(set)
    for a_, b_, c_ in F_:
        nb[a_] |= {b_, c_}; nb[b_] |= {a_, c_}; nb[c_] |= {a_, b_}
    d_ = np.full(n_v, n_rings + 1)
    front = list(seeds)
    d_[front] = 0
    for r_ in range(1, n_rings + 1):
        nxt = []
        for v in front:
            for w in nb[v]:
                if d_[w] > r_:
                    d_[w] = r_
                    nxt.append(w)
        front = nxt
    return d_


def place_ears(EV, EF, dome_V, dome_F):
    """귀를 두피 위에 얹는다: 귀 테두리(뿌리 쪽 살)가 두피 면보다 EAR_SINK 만큼 안에 들어가게 옆으로 옮기고,
    그래도 두피 밖으로 나온 테두리 가까운 점(3고리 안)은 두피 속으로 당긴다."""
    tris = dome_V[dome_F]
    EV = EV.copy()
    bd, _ = _boundary_loops(EF)
    bverts = np.unique(np.array(bd).reshape(-1))
    near = _ring_dist(EF, len(EV), bverts, EAR_PULL_RINGS) <= EAR_PULL_RINGS
    for side in (1, -1):
        mine = EV[:, 0] * side > 0
        bm = np.zeros(len(EV), bool)
        bm[bverts] = True
        bm &= mine
        d_ = EV[bm] - HC
        r_ = np.linalg.norm(d_, axis=1)
        t_, _ = raycast(HC, d_ / r_[:, None], tris, far=True)
        gap = t_ - r_
        shift = float(np.nanmedian(gap)) - EAR_SINK
        EV[mine, 0] += side * shift
        # 테두리 가까운 점이 두피 밖이면 안으로
        idx = np.where(mine & near)[0]
        d_ = EV[idx] - HC
        r_ = np.linalg.norm(d_, axis=1)
        t_, _ = raycast(HC, d_ / r_[:, None], tris, far=True)
        out = np.isfinite(t_) & (r_ > t_ - 0.0015)
        EV[idx[out]] = HC + d_[out] / r_[out, None] * (t_[out] - 0.0015)[:, None]
        print('  ear side %+d shift %.1f mm · pulled in %d of %d rim verts' % (side, 1000 * shift, int(out.sum()), len(idx)))
    return EV


def assemble_head():
    """K + 두피 + 귀: V, F(Godot 순서), 뼈 원본(정점마다), 이음새 원본(이음새만, 나머지 −1), 면 종류(0 얼굴 · 1 두피 · 2 귀)."""
    KV, KF, KS = build_face_k()
    KF = _keep_largest(KF)
    KV, KF, KS = _fix_pinches(KV, KF, KS)
    KV, KF, KS, kloop, seam_ids, pos_in, DT, nb, nk, small = build_dome(KV, KF, KS)
    nKV = len(KV)
    seam_base = nKV
    in_base = nKV + len(seam_ids)
    V_ = np.vstack([KV, P[seam_ids], pos_in])
    gmap = np.concatenate([np.array(kloop), seam_base + np.arange(len(seam_ids)), in_base + np.arange(len(pos_in))])
    F_ = np.vstack([KF, gmap[DT]])
    bone = np.concatenate([KS, np.array(seam_ids), -np.ones(len(pos_in), int)])
    seam = np.concatenate([-np.ones(nKV, int), np.array(seam_ids), -np.ones(len(pos_in), int)])
    _, j_ = cKDTree(P).query(pos_in)          # 두피 안쪽 점 뼈 = 가장 가까운 승인 정점
    bone[in_base:] = j_
    face_kind = np.concatenate([np.zeros(len(KF), int), np.ones(len(DT), int)])
    # 귀: 두피 위에 따로(두피 면과 겹쳐 박힌다)
    EV, EF, ES = build_ears()
    EV = place_ears(EV, EF, V_, gmap[DT])
    e0 = len(V_)
    V_ = np.vstack([V_, EV])
    F_ = np.vstack([F_, EF + e0])
    bone = np.concatenate([bone, ES])
    seam = np.concatenate([seam, -np.ones(len(EV), int)])
    face_kind = np.concatenate([face_kind, np.full(len(EF), 2)])
    used = np.unique(F_)
    remap = -np.ones(len(V_), int)
    remap[used] = np.arange(len(used))
    V_, F_, bone, seam = V_[used], remap[F_], bone[used], seam[used]
    print('head: K verts %d faces %d · dome pts %d faces %d · ears faces %d · small loops %d' % (nKV, len(KF), len(pos_in), len(DT), len(EF), len(small)))
    return V_, F_, bone, seam, face_kind


def refit_rad(V_, F_, kind):
    """헤어가 새 두피 위에 얹히게: RAD 눈금 방향마다 두피 면(두피만)까지 거리를 다시 잰다(얼굴 쪽 칸은 그대로)."""
    global RAD
    tris = V_[F_[kind == 1]]
    A_ = A_GRID[2:]; E_ = ROWS_EL[2:]
    d_ = to_dir(A_, E_).reshape(-1, 3)
    t_, _ = raycast(HC, d_, tris, far=True)
    new = RAD[2:].reshape(-1).copy()
    ok = np.isfinite(t_)
    new[ok] = t_[ok]
    new = new.reshape(RAD[2:].shape)
    RAD = RAD.copy()
    RAD[2:] = new
    RAD = (RAD + RAD[:, MIRROR]) / 2
    print('  RAD refit: %d of %d grid dirs on dome · change mm median %.1f min %.1f max %.1f' % (
        int(ok.sum()), len(ok), 1000 * np.median((t_ - RAD[2:].reshape(-1))[ok]) if ok.any() else 0,
        1000 * np.min((new.reshape(-1) - _RAD_BEFORE[2:].reshape(-1))[ok]), 1000 * np.max((new.reshape(-1) - _RAD_BEFORE[2:].reshape(-1))[ok])))


def smooth_normals(V_, F_):
    """승인 모델과 같은 법선: 정점마다 이웃 면 (넓이 가중) 평균. F = Godot 순서."""
    a = V_[F_[:, 0]]; b = V_[F_[:, 1]]; c = V_[F_[:, 2]]
    fn = np.cross(c - a, b - a)
    vn = np.zeros_like(V_)
    for k_ in range(3):
        np.add.at(vn, F_[:, k_], fn)
    return vn / np.maximum(np.linalg.norm(vn, axis=1, keepdims=True), 1e-15)


def icosphere(subdiv):
    t = (1 + 5 ** 0.5) / 2
    v = [np.array(x, float) / np.linalg.norm(x) for x in [[-1, t, 0], [1, t, 0], [-1, -t, 0], [1, -t, 0], [0, -1, t], [0, 1, t], [0, -1, -t], [0, 1, -t],
                                                       [t, 0, -1], [t, 0, 1], [-t, 0, -1], [-t, 0, 1]]]
    f = [[0, 11, 5], [0, 5, 1], [0, 1, 7], [0, 7, 10], [0, 10, 11], [1, 5, 9], [5, 11, 4], [11, 10, 2], [10, 7, 6],
         [7, 1, 8], [3, 9, 4], [3, 4, 2], [3, 2, 6], [3, 6, 8], [3, 8, 9], [4, 9, 5], [2, 4, 11], [6, 2, 10],
         [8, 6, 7], [9, 8, 1]]
    for _ in range(subdiv):
        cache = {}; nf = []

        def mid(a, b):
            k = (min(a, b), max(a, b))
            if k not in cache:
                m = v[a] + v[b]; v.append(m / np.linalg.norm(m)); cache[k] = len(v) - 1
            return cache[k]
        for a, b, c in f:
            ab, bc, ca = mid(a, b), mid(b, c), mid(c, a)
            nf += [[a, ab, ca], [b, bc, ab], [c, ca, bc], [ab, bc, ca]]
        f = nf
    return np.array(v), np.array(f)


def stations_solid(stations):
    """단면 점 목록(같은 개수)들을 이은 닫힌 덩어리(양 끝은 가운데 점으로 막는다)."""
    k_ = len(stations[0])
    V_ = [p for st in stations for p in st]
    T_ = grid_tris(len(stations), k_)
    a_ = len(V_); V_.append(np.mean(stations[0], axis=0))
    b_ = len(V_); V_.append(np.mean(stations[-1], axis=0))
    last = (len(stations) - 1) * k_
    for j in range(k_):
        T_.append([a_, (j + 1) % k_, j])
        T_.append([b_, last + j, last + (j + 1) % k_])
    return closed_piece(np.array(V_), T_)


def bump(x, a, peak, b):
    x = np.asarray(x, float)
    t = np.where(x < peak, (x - a) / (peak - a), (b - x) / (b - peak))
    t = np.clip(t, 0, 1)
    out = t * t * (3 - 2 * t)
    return np.where((x <= a) | (x >= b), 0.0, out)


def morph_face(V_, f):
    """character_looks.gd _morph_face 의 턱·턱끝·볼 부분과 같은 식(목 앞 면은 게임이 같은 식으로 민다 → 이음새가 맞는다)."""
    V_ = V_.copy()
    x, y, z = V_[:, 0], V_[:, 1], V_[:, 2]
    m = (y >= 1.30) & (y <= 1.56) & (np.abs(x) <= 0.2) & (z <= -0.02)
    front = smooth(0.02, 0.12, -z)
    under = smooth(1.30, 1.345, y)
    jaw = (1 - smooth(1.42, 1.54, y)) * front * under
    chin = (1 - smooth(1.36, 1.44, y)) * front * under
    cheek = bump(y, 1.38, 1.47, 1.55) * front
    sx = 1 + f[0] * jaw + f[2] * chin + f[3] * cheek
    V_[m, 0] = x[m] * sx[m]
    V_[m, 1] = y[m] + f[1] * chin[m]
    return V_


def face_normals(V_, T_):
    """Godot 순서 삼각형의 바깥 법선(= (c−a)×(b−a))."""
    a = V_[T_[:, 0]]; b = V_[T_[:, 1]]; c = V_[T_[:, 2]]
    n = np.cross(c - a, b - a)
    area = np.linalg.norm(n, axis=1)
    return n / np.maximum(area[:, None], 1e-15), area


def shaded(V_, T_, flat_w=0.55, angle=40.0):
    """한 조각을 꼭짓점마다 풀어 낸다(삼각형마다 꼭짓점 3개). 법선 = 면 법선 flat_w + angle° 안 이웃 면 평균."""
    V_ = np.asarray(V_, float); T_ = np.asarray(T_, int)
    fn, area = face_normals(V_, T_)
    keyv = np.round(V_ / 1e-6).astype(np.int64)
    _, wid = np.unique(keyv, axis=0, return_inverse=True)
    wid = wid.reshape(-1)
    inc = {}
    for f_i, tri in enumerate(T_):
        for vi in tri:
            inc.setdefault(wid[vi], []).append(f_i)
    cosl = math.cos(math.radians(angle))
    outV, outN = [], []
    for f_i, tri in enumerate(T_):
        for vi in tri:
            fs = inc[wid[vi]]
            near = [g for g in fs if np.dot(fn[g], fn[f_i]) >= cosl]
            sm = np.sum(fn[near] * area[near][:, None], axis=0)
            sm /= max(np.linalg.norm(sm), 1e-12)
            n_ = flat_w * fn[f_i] + (1 - flat_w) * sm
            outV.append(V_[vi]); outN.append(n_ / np.linalg.norm(n_))
    return np.array(outV), np.array(outN)


def front_hit_z(mesh_V, mesh_T, x, y):
    """(x, y) 에서 앞(−Z)에서 뒤로 쏜 광선이 처음 닿는 얼굴 면의 z."""
    tris = mesh_V[np.asarray(mesh_T)]
    t, _ = raycast(np.array([[x, y, -1.0]]), np.array([[0, 0, 1.0]]), tris, far=False)
    return -1.0 + float(t[0])


def brow_piece(SV, ST, side, xs, ys, hs, depth, back_sink=0.005, tilt=0.35):
    """입체 눈썹: 이마 면(새 껍데기)에서 앞으로 depth. 단면 = 위 뒤 · 위 앞 · 아래 앞 · 아래 뒤.
    v6: 승인 눈썹뼈는 각진 판이라 제어점 사이에서 면이 눈썹보다 앞으로 나와 눈썹이 군데군데 묻혔다(솜) →
    제어점을 세 배로 촘촘히 하고, 눈썹 위·가운데·아래 세 높이 중 가장 앞으로 나온 면을 기준으로 앞에 붙인다."""
    t0 = np.linspace(0.0, 1.0, len(xs))
    t1 = np.linspace(0.0, 1.0, 3 * len(xs) - 2)
    xs, ys, hs, depth = (np.interp(t1, t0, np.asarray(a_, float)) for a_ in (xs, ys, hs, depth))
    sts = []
    for x, y, h, dp in zip(xs, ys, hs, depth):
        x = x * side
        dp = dp * 0.75
        zf = min(front_hit_z(SV, ST, x, y + h * 0.5), front_hit_z(SV, ST, x, y), front_hit_z(SV, ST, x, y - h * 0.5))
        sts.append([np.array([x, y + h / 2, zf + back_sink]), np.array([x, y + h / 2 - h * tilt * 0.3, zf - dp]),
                    np.array([x, y - h / 2, zf - dp * 0.8]), np.array([x, y - h / 2, zf + back_sink])])
    return stations_solid(sts)


def mouth_piece(SV, ST, half_w, smile, y0=1.4355):
    """입: 입술선을 따라가는 가는 막대(얼굴 면에 반쯤 박힌다)."""
    xs = np.linspace(-half_w, half_w, 7)
    sts = []
    for x in xs:
        y = y0 + smile * (abs(x) / half_w) ** 2
        zf = front_hit_z(SV, ST, x, y)
        h = 0.0042 * (1 - 0.55 * (abs(x) / half_w) ** 3)
        # 앞으로 2.4 mm(각진 얼굴 면에 군데군데 묻혀 입선이 끊겨 보였다 — 2026-11-28)
        sts.append([np.array([x, y + h / 2, zf + 0.002]), np.array([x, y + h / 2, zf - 0.0024]),
                    np.array([x, y - h / 2, zf - 0.0024]), np.array([x, y - h / 2, zf + 0.002])])
    return stations_solid(sts)


# 캐릭터별 얼굴: FACE = character_looks.gd 와 같은 표 [턱 폭, 턱끝 위아래, 턱끝 폭, 볼, 코 길이 줄임, 코 폭]
FACE = {'base': [0, 0, 0, 0, 0, 0],
        'jun': [-0.05, -0.006, -0.03, 0.0, 0.0, -0.06],
        'som': [0.03, 0.012, 0.12, 0.14, 0.80, 0.0],
        'on': [0.16, -0.004, 0.14, 0.0, 0.15, 0.38]}
# 입체 눈썹(안쪽 → 바깥 제어점: 가운데 x, 높이, 세로 두께, 앞으로 나온 깊이)
BROWS = {
    'base': ([0.028, 0.045, 0.062, 0.079, 0.094, 0.106], [1.642, 1.642, 1.641, 1.639, 1.635, 1.631],
             [0.0090, 0.0095, 0.0095, 0.0090, 0.0070, 0.0050], [0.008, 0.009, 0.009, 0.009, 0.008, 0.006]),
    'jun': ([0.026, 0.042, 0.060, 0.078, 0.094, 0.106], [1.639, 1.642, 1.646, 1.649, 1.650, 1.648],
            [0.012, 0.013, 0.012, 0.011, 0.009, 0.006], [0.009, 0.010, 0.010, 0.010, 0.009, 0.007]),
    'som': ([0.030, 0.045, 0.062, 0.078, 0.092, 0.104], [1.643, 1.650, 1.656, 1.657, 1.653, 1.645],
            [0.0065, 0.0070, 0.0065, 0.0055, 0.0045, 0.0030], [0.006, 0.007, 0.007, 0.007, 0.006, 0.005]),
    'on': ([0.030, 0.048, 0.066, 0.082, 0.096], [1.643, 1.647, 1.650, 1.650, 1.646],
           [0.016, 0.017, 0.016, 0.014, 0.011], [0.011, 0.012, 0.012, 0.011, 0.009]),
}
MOUTH = {'base': (0.036, 0.0), 'jun': (0.034, -0.0015), 'som': (0.030, 0.0025), 'on': (0.040, 0.0)}
# 색 키: 0 피부 · 1 흰자 · 2 눈동자 · 3 입 · 4 눈썹 (게임이 캐릭터 색표로 칠한다)
# ═══════════════ 캐릭터 얼굴: 승인 얼굴 원본 면 + 캐릭터별 코·얼굴형 + 눈동자·입·눈썹 조각 ═══════════════
# 캐릭터별 코(v6): 승인 상자 코를 그대로 쓰고 길이·폭만 바꾼다(예전 쐐기 코와 같은 값 — FACE[4] 길이 줄임 · FACE[5] 폭).
#   코끝 쪽(z < NOSE_BASE_Z)만 앞뒤로 줄이고(코 뿌리는 그대로), 코끝 높이에서 가장 넓게 옆으로 편다. 코 밖으로는 0 으로 사라진다.
NOSE_BASE_Z = -0.235
EYE_FRONT_R = 0.0330      # 승인 눈알 앞면 반지름(실측 0.0328~0.0333) — 눈동자를 이 면에 얹는다


def nose_deform(V_, len_cut, wide_k):
    V_ = V_.copy()
    x, y, z = V_[:, 0], V_[:, 1], V_[:, 2]
    w = (1 - smooth(0.022, 0.05, np.abs(x))) * smooth(1.43, 1.452, y) * (1 - smooth(1.615, 1.64, y))
    V_[:, 2] = z - len_cut * np.minimum(0.0, z - NOSE_BASE_Z) * w
    V_[:, 0] = x * (1 + wide_k * bump(y, 1.455, 1.49, 1.56) * w * smooth(0.205, 0.225, -z))
    return V_


def pupil_piece(side_i):
    """눈동자: 승인 눈알 앞면에 반쯤 박힌 납작한 알(정면을 본다)."""
    c_ = EYE_C[side_i]
    pv, pf = icosphere(1)
    d_ = np.array([0.0, -0.02, -1.0])
    d_ /= np.linalg.norm(d_)
    pc = c_ + d_ * (EYE_FRONT_R - 0.0012)
    return closed_piece(pc + pv * np.array([0.0062, 0.0070, 0.0026]), pf)


def split_by_key(F_, keys_f):
    """색 키가 다른 면이 만나는 정점은 키마다 따로 둔다(색이 번지지 않게). → (원래 정점 번호, 키, 새 면)"""
    kv = F_.astype(np.int64) * 8 + keys_f[:, None]
    u_, inv_ = np.unique(kv.reshape(-1), return_inverse=True)
    return u_ // 8, u_ % 8, inv_.reshape(-1, 3)


HEAD_V, HEAD_F, HEAD_BONE, HEAD_SEAM, HEAD_KIND = assemble_head()
_RAD_BEFORE = RAD.copy()
refit_rad(HEAD_V, HEAD_F, HEAD_KIND)          # 헤어가 새 두피 위에 얹히게
# 흰자 면 = 승인 눈알 구(반지름 약 0.033) 위의 면(눈꺼풀은 0.035 부터)
_eye_d = np.min(np.stack([np.linalg.norm(HEAD_V - c_, axis=1) for c_ in EYE_C]), axis=0)
HEAD_KEY = np.where((HEAD_KIND == 0) & (_eye_d[HEAD_F] < 0.0347).all(1), 1, 0)
if __import__('os').environ.get('DEBUG_DOME'):
    HEAD_KEY = np.where(HEAD_KIND == 1, 3, HEAD_KEY)     # 확인용: 두피 면을 입 색으로
print('eye-white faces', int((HEAD_KEY == 1).sum()))
heads = {}
for id_, f_ in FACE.items():
    hv = morph_face(nose_deform(HEAD_V, f_[4], f_[5]), f_)
    hn = smooth_normals(hv, HEAD_F)
    vid, vkey, f1 = split_by_key(HEAD_F, HEAD_KEY)
    VV, NN_, KK, SS, WW, II = [hv[vid]], [hn[vid]], [vkey], [HEAD_SEAM[vid]], [HEAD_BONE[vid]], [f1.reshape(-1)]
    base = len(vid)
    parts_ = []
    for i_ in (0, 1):
        pv_, pt_ = pupil_piece(i_)
        parts_.append((pv_, pt_, 2, 0.0))
    hw_, sm_ = MOUTH[id_]
    mv, mt = mouth_piece(hv, HEAD_F, hw_, sm_)
    parts_.append((mv, mt, 3, 0.3))
    for s_ in (1, -1):
        bv, bt = brow_piece(hv, HEAD_F, s_, *BROWS[id_])
        parts_.append((bv, bt, 4, 0.5))
    for V_, T_, key_, flat_w in parts_:
        ov, on_ = shaded(V_, np.asarray(T_, int), flat_w=flat_w, angle=40.0)
        n_ = len(ov)
        VV.append(ov); NN_.append(on_); KK.append(np.full(n_, key_)); SS.append(-np.ones(n_, int))
        WW.append(np.full(n_, RIGID_SRC)); II.append(base + np.arange(n_))
        base += n_
    heads[id_] = {'v': np.round(np.vstack(VV), 5).tolist(), 'n': np.round(np.vstack(NN_), 4).tolist(),
                  'k': np.concatenate(KK).astype(int).tolist(), 'seam': np.concatenate(SS).astype(int).tolist(),
                  'w': np.concatenate(WW).astype(int).tolist(), 'i': np.concatenate(II).astype(int).tolist()}
    print('head', id_, 'verts', base, 'tris', len(heads[id_]['i']) // 3)

# 귀 둘레(헤어가 귀를 뚫지 않게) — 새 머리의 승인 귀(대칭)에서 다시 잰다.
_kv = np.unique(HEAD_F[HEAD_KIND == 2])
_kp = HEAD_V[_kv]
_ears = _kp[(np.abs(_kp[:, 0]) > 0.128) & (_kp[:, 1] > 1.50) & (_kp[:, 1] < 1.645) & (_kp[:, 2] > -0.115) & (_kp[:, 2] < 0.065)]
_ear_rel = _ears - HC
_ear_az = np.degrees(np.arctan2(_ear_rel[:, 0], -_ear_rel[:, 2]))
_ear_hor = np.hypot(_ear_rel[:, 0], _ear_rel[:, 2])
EAR_R = np.zeros(90)
for a_, h_ in zip(((_ear_az + 180) / 4).astype(int) % 90, _ear_hor):
    EAR_R[a_] = max(EAR_R[a_], h_)
EAR_R = np.maximum(EAR_R, np.maximum(np.roll(EAR_R, 1), np.roll(EAR_R, -1)))


# ═══════════════════════════════ 헤어 부품 ═══════════════════════════════
# 공통 이마선(승인 모델 원래 머리선을 따라 잰 값, 2026-11-28):
#   앞 1.684~1.711 · 관자(±45°) 1.63 · 귀 위(±60~75°) 1.55 · 귀(±90°) 1.49 · 뒤(±135~180°) 1.46.
#   v4: 목덜미를 깎은 뒤(두개골 밑선 뒤 1.524 m)로는 짧은 헤어 뒤 머리선을 1.49~1.51 m 로 올렸다 — 목기둥 위 끝에서 끝난다
#   (예전 1.46~1.47 m 는 이제 가는 목 한가운데라, 뒤에서 보면 머리 밑에 어두운 구멍처럼 보였다).
# 귀 정점: y 1.507~1.594, 방위 ±80~100° — 짧은 헤어는 귀 위(1.60)로 돌아간다.

# ── v4(2026-11-28 사용자 "헤어가 너무 낮아 볼륨이 없고 머리카락 같지 않다 · 면이 일정해 직사각형으로 나뉘어 보인다"):
#   1) 볼륨: 바탕 모자 두께를 옆 1~1.5 cm · 위 2.5~3.5 cm 로(예전 0.5~1.7 cm). 다발도 굵고 더 띄운다. 꼭대기 상한 1.835 m.
#   2) 불규칙: 모자 점은 벽돌처럼 엇갈리고 옆·위아래로 흔든다 · 다발 결(lanes)과 홈 · 이마선 끝은 다발마다 뾰족한 톱니.
#      튜브 다발은 단면 점마다 들쭉날쭉(jit)하고 고리마다 비튼다(twist). 대각선도 아무렇게나.
LOCK = dict(jit=0.16, twist=0.22)

# ── crew: 짧은 스포츠 컷(두피를 고르게 덮는 바탕 모자 + 위는 짧게 솟은 솔) ──
crew_lim = jagged_lim(periodic_interp([(0, 1.700), (25, 1.698), (45, 1.660), (62, 1.612), (72, 1.585), (82, 1.605),
                                       (100, 1.608), (122, 1.530), (145, 1.493), (180, 1.495),
                                       (-25, 1.698), (-45, 1.660), (-62, 1.612), (-72, 1.585), (-82, 1.605),
                                       (-100, 1.608), (-122, 1.530), (-145, 1.493)]), 0.004, 20, 5)


HAIR_VOL = 1.15   # v5(2026-11-28): 헤어 두께 전체 +15 % ("조금 더 볼륨감")


def _vol(A, E, th, back=0.005):
    """v5: 두께를 15 % 키우고, 평평하게 깎은 뒤통수 자리(방위 110° 밖 · 귀 높이~정수리 아래)에 살짝 더 얹는다.
    → 민머리는 평평한 뒤통수, 헤어를 씌우면 뒤가 살짝 둥글게 부푼다."""
    b = back * smooth(110, 160, np.abs(A)) * smooth(-40, -10, E) * (1 - smooth(35, 65, E))
    return th * HAIR_VOL + b


def crew_thick(A, E):
    return _vol(A, E, 0.0065 + 0.0155 * smooth(22, 64, E) + 0.008 * gauss(A, E, 0, 40, 35, 14), back=0.0025)  # 옆·뒤는 짧게, 위만 볼륨


v, t = cap_solid(crew_lim, crew_thick, n_az=40, n_rows=11, jitter=0.0015, seed=51,
                 lanes=17, lane_amp=0.004, tip_deg=2.2, scatter=0.3, edge_thin=0.6)
pieces = [(v, t)]
rng = np.random.default_rng(52)
# 위: 짧게 솟은 솔(앞쪽은 앞으로, 뒤쪽은 뒤로 살짝 눕는다)
for k in range(16):
    a_ = -180 + 360.0 * k / 16 + rng.uniform(-10, 10)
    e_ = rng.uniform(60, 82)
    n_ = 4
    path = flow_path(a_, e_, 180 + rng.uniform(-25, 25), rng.uniform(0.035, 0.055), n_,
                     lambda s: 0.014 + 0.014 * s, curve=rng.uniform(-15, 15))
    v, t = tube(path, taper(0.034, 0.022, n_), taper(0.018, 0.012, n_), sides=4, roll=rng.uniform(0, 1),
                seed=int(rng.integers(1e6)), **LOCK)
    pieces.append((v, t))
v, t = merge(pieces)
hairs['crew'] = [piece_out(v, t, 0.05)]


# ── spiky(준 기본): 짧게 친 옆·뒤 + 앞으로 쏠려 끝이 들린 삐죽 앞머리 + 정수리에서 솟은 삐죽 ──
jun_lim = jagged_lim(periodic_interp([(0, 1.694), (25, 1.690), (42, 1.668), (60, 1.625), (70, 1.570), (80, 1.600),
                                      (100, 1.606), (120, 1.540), (145, 1.493), (180, 1.496),
                                      (-25, 1.692), (-42, 1.668), (-60, 1.625), (-70, 1.570), (-80, 1.600),
                                      (-100, 1.606), (-120, 1.540), (-145, 1.493)]), 0.005, 18, 11)


def jun_thick(A, E):
    return _vol(A, E, 0.010 + 0.014 * smooth(10, 50, E))


v, t = cap_solid(jun_lim, jun_thick, n_az=40, n_rows=9, jitter=0.002, seed=12,
                 lanes=16, lane_amp=0.007, tip_deg=4.0, scatter=0.3, edge_thin=0.55)
pieces = [(v, t)]
rng = np.random.default_rng(13)
# 옆·뒤: 정수리에서 아래로 흐르는 짧은 다발(기와처럼 겹친다) — 세 줄.
for ring_el, ring_n, ln, w0, th0, off_az in [(64, 10, 0.080, 0.046, 0.022, 0.0), (42, 12, 0.062, 0.042, 0.019, 15.0),
                                             (22, 13, 0.045, 0.036, 0.015, 7.0)]:
    for k in range(ring_n):
        a_ = -180 + off_az + 360.0 * k / ring_n + rng.uniform(-6, 6)
        if abs((a_ + 180) % 360 - 180) < 55:
            continue                      # 앞은 앞머리가 맡는다
        n_ = 5
        path = flow_path(a_, ring_el + rng.uniform(-4, 4), 180 + rng.uniform(-18, 18), ln * rng.uniform(0.85, 1.15), n_,
                         lambda s: 0.010 + 0.009 * s * s, curve=rng.uniform(-25, 25))
        v, t = tube(path, taper(w0, w0 * 0.7, n_), taper(th0, th0 * 0.65, n_), sides=5, roll=rng.uniform(0, 1),
                    seed=int(rng.integers(1e6)), **LOCK)
        pieces.append((v, t))
# 정수리 → 앞: 앞으로 흐르다 끝이 들리는 다발(앞머리). 오른쪽으로 살짝 쏠린다.
for a_, e_, ln, lift, sweep in [(-38, 70, 0.11, 0.030, 25), (-14, 74, 0.12, 0.036, 18), (10, 74, 0.12, 0.034, 15),
                                (34, 70, 0.10, 0.028, 8), (-52, 52, 0.07, 0.018, 30), (52, 54, 0.07, 0.018, -5),
                                (0, 86, 0.13, 0.030, 20), (-26, 80, 0.10, 0.032, 22), (22, 80, 0.10, 0.030, 10)]:
    n_ = 6
    path = flow_path(a_, e_, 180 + sweep, ln, n_, lambda s, l=lift: 0.011 + l * s ** 2.0, curve=-sweep * 0.6)
    v, t = tube(path, taper(0.050, 0.032, n_, 1.4), taper(0.026, 0.015, n_), sides=5, roll=rng.uniform(0, 1),
                seed=int(rng.integers(1e6)), **LOCK)
    pieces.append((v, t))
# 정수리 뒤: 뒤로 뻗친 삐죽
for a_, e_, ln in [(150, 72, 0.08), (-150, 70, 0.075), (180, 78, 0.08), (120, 66, 0.065), (-120, 66, 0.065)]:
    n_ = 5
    path = flow_path(a_, e_, 180, ln, n_, lambda s: 0.011 + 0.022 * s ** 2)
    v, t = tube(path, taper(0.044, 0.028, n_), taper(0.022, 0.013, n_), sides=5, roll=rng.uniform(0, 1),
                seed=int(rng.integers(1e6)), **LOCK)
    pieces.append((v, t))
v, t = merge(pieces)
hairs['spiky'] = [piece_out(v, t, 0.05)]


# ── bob(솜 기본): 정수리에서 둥글게 부풀어 흘러내려 턱선에서 끊긴 단발 + 왼쪽 가르마에서 오른쪽으로 넘긴 앞머리 ──
SOM_TIP = 1.458
som_lim = periodic_interp([(0, 1.700), (30, 1.690), (45, 1.660), (60, 1.600), (90, 1.560), (135, 1.490), (180, 1.468),
                           (-30, 1.700), (-45, 1.672), (-60, 1.600), (-90, 1.560), (-135, 1.490)])


def som_thick(A, E):
    return _vol(A, E, 0.013 + 0.010 * smooth(10, 60, E) - 0.005 * gauss(A, E, -36, 62, 6, 20))   # 가르마 홈


v, t = cap_solid(som_lim, som_thick, n_az=40, n_rows=9, jitter=0.0015, seed=21,
                 lanes=18, lane_amp=0.005, tip_deg=1.5, scatter=0.25, edge_thin=0.75)
pieces = [(v, t)]
rng = np.random.default_rng(22)


def hang_lock(a_, root_el, w_mid, th, tip_y, inward=0.016, lift=0.018, n_surf=4, out=0.004, sway=0.010):
    """정수리에서 귀 높이까지 큰 원을 따라 흐른 뒤 떨어지는 단발 다발(귀보다 바깥).
    v4: 떨어지는 부분을 네 마디로 — 가운데가 살짝 부풀고 끝은 안으로 말린다 · 옆으로 ±sway 만큼 휘고 끝은 뾰족하게 모인다
    (곧은 세로 띠가 나란히 서 있는 것처럼 보이지 않게)."""
    p_surf = slerp_path(a_, root_el, a_, 2.0, n_surf, lambda s: 0.012 + lift * s)
    eq = p_surf[-1]
    rel = eq - HC
    hor = math.hypot(rel[0], rel[2])
    want = max(hor + out, ear_r(a_) + 0.016 + th / 2)
    dir_h = np.array([rel[0], 0, rel[2]]) / hor
    side_h = np.array([-dir_h[2], 0, dir_h[0]])
    sw = rng.uniform(-sway, sway)
    y_top = rel[1]
    pts = [p_surf[:-1]]
    for f_, bul, lat in [(0.0, 0.0, 0.0), (0.38, 0.006, 0.4), (0.72, 0.002, 0.8), (1.0, -inward, 1.0)]:
        y_ = HC[1] + y_top + (tip_y - HC[1] - y_top) * f_
        pts.append([HC + dir_h * (want + bul) + side_h * sw * lat + np.array([0, y_ - HC[1], 0])])
    path = np.vstack(pts)
    tip_pt = path[-1] + np.array([0, -0.012, 0]) - dir_h * 0.006 + side_h * sw * 0.3
    path = np.vstack([path, tip_pt])
    n_ = len(path)
    w = np.concatenate([np.linspace(w_mid * 0.55, w_mid, n_surf - 1), [w_mid, w_mid * 1.02, w_mid * 0.85, w_mid * 0.5, 0.0]])
    tt = np.concatenate([np.linspace(th * 0.8, th, n_surf - 1), [th, th * 1.05, th * 0.85, th * 0.5, 0.0]])
    return tube(path, w, tt, sides=5, roll=math.pi / 2 + rng.uniform(-0.25, 0.25), tip=True,
                seed=int(rng.integers(1e6)), jit=0.15, twist=0.2)


# 옆·뒤 바깥 다발(얼굴 앞 ±50° 밖) — 너비·끝 길이·휘는 쪽이 다발마다 다르다.
N_OUT = 19
for k in range(N_OUT):
    a_ = 52 + (360 - 104) * k / (N_OUT - 1)
    a_ = (a_ + 180) % 360 - 180
    a_ += rng.uniform(-3, 3)
    v, t = hang_lock(a_, 68 + rng.uniform(-5, 5), rng.uniform(0.056, 0.080), rng.uniform(0.022, 0.030),
                     SOM_TIP + rng.uniform(-0.014, 0.014))
    pieces.append((v, t))
# 안쪽 다발(바깥 다발 사이를 채운다 — 볼륨 · 조금 짧다)
for k in range(N_OUT - 1):
    a_ = 52 + (360 - 104) * (k + 0.5) / (N_OUT - 1)
    a_ = (a_ + 180) % 360 - 180
    v, t = hang_lock(a_, 62 + rng.uniform(-4, 4), rng.uniform(0.055, 0.070), 0.022, SOM_TIP + 0.014 + rng.uniform(-0.008, 0.010),
                     inward=0.020, lift=0.012, out=-0.004)
    pieces.append((v, t))
# 얼굴 옆을 감싸는 앞 다발(귀 앞, 눈보다 바깥) — 오른쪽은 앞머리가 이어져 조금 짧다.
for a_, tip in [(57, SOM_TIP + 0.012), (-57, SOM_TIP + 0.002)]:
    v, t = hang_lock(a_, 58, 0.062, 0.022, tip, inward=0.008, lift=0.012, sway=0.004)
    pieces.append((v, t))
# 앞머리: 가르마(왼쪽 −36°)에서 이마를 가로질러 오른쪽 관자로 — 아래 끝은 눈썹 위(1.67 m 위).
for a_, e_, ln, w0, curve in [(-40, 58, 0.16, 0.052, 28), (-36, 66, 0.17, 0.050, 22), (-32, 74, 0.15, 0.046, 14),
                              (-44, 48, 0.10, 0.046, 30), (-28, 80, 0.13, 0.044, 10)]:
    n_ = 6
    path = flow_path(a_, e_, 128, ln, n_, lambda s: 0.013 + 0.010 * math.sin(math.pi * min(s, 0.7)), curve=curve)
    v, t = tube(path, taper(w0, w0 * 0.75, n_), taper(0.024, 0.015, n_), sides=5, roll=math.pi / 2,
                seed=int(rng.integers(1e6)), **LOCK)
    pieces.append((v, t))
# 가르마 왼쪽(캐릭터 왼쪽) 짧은 앞 다발 — 왼쪽 관자 쪽으로.
for a_, e_, ln in [(-46, 62, 0.07), (-54, 52, 0.06)]:
    n_ = 5
    path = flow_path(a_, e_, 205, ln, n_, lambda s: 0.013 + 0.006 * s)
    v, t = tube(path, taper(0.047, 0.036, n_), taper(0.022, 0.015, n_), sides=5, roll=math.pi / 2,
                seed=int(rng.integers(1e6)), **LOCK)
    pieces.append((v, t))
v, t = merge(pieces)
hairs['bob'] = [piece_out(v, t, 0.04)]


# ── curls(온 기본): 머리 전체를 한 색 곱슬 덩이로 덮은 짧은 곱슬(위는 두툼) ──
on_lim = jagged_lim(periodic_interp([(0, 1.702), (25, 1.700), (42, 1.668), (60, 1.620), (70, 1.585), (82, 1.608),
                                     (100, 1.610), (122, 1.540), (145, 1.494), (180, 1.498),
                                     (-25, 1.700), (-42, 1.668), (-60, 1.620), (-70, 1.585), (-82, 1.608),
                                     (-100, 1.610), (-122, 1.540), (-145, 1.494)]), 0.003, 20, 31)


def on_thick(A, E):
    return _vol(A, E, 0.010 + 0.016 * smooth(15, 60, E))


v, t = cap_solid(on_lim, on_thick, n_az=40, n_rows=9, jitter=0.002, seed=32,
                 lanes=20, lane_amp=0.004, tip_deg=1.5, scatter=0.3, edge_thin=0.8)
pieces = [(v, t)]
rng = np.random.default_rng(33)
# 피보나치 점(고르게 흩뿌림) 중 이마선 1 cm 위만 — 덩이 크기·높이·자리를 조금씩 흔든다.
N_FIB = 250
gold = math.pi * (3 - math.sqrt(5))
count = 0
for i in range(N_FIB):
    yv = 1 - (i + 0.5) / N_FIB * 1.3
    rr = math.sqrt(max(0.0, 1 - yv * yv))
    th = gold * i + rng.uniform(-0.05, 0.05)
    u = np.array([math.cos(th) * rr, yv, math.sin(th) * rr])
    a_, e_ = angles(u)
    y_here = HC[1] + math.sin(math.radians(e_)) * float(head_r(a_, e_))
    if y_here < float(on_lim(a_)) + 0.010:
        continue
    top_w = float(smooth(15, 60, e_))
    r_ = (0.013 + 0.008 * top_w) * rng.uniform(0.8, 1.2)
    base = float(head_r(a_, e_)) + float(on_thick(np.array(a_), np.array(e_)))
    cen = HC + u * (base - r_ * 0.3 + rng.uniform(-0.004, 0.004))
    n_, up_, side_ = frame_at(cen)
    v, t = ico(np.zeros(3), [r_ * 1.15, r_ * 0.85, r_ * 1.15], jitter=0.2, seed=int(rng.integers(1e6)),
               rot=np.stack([side_, n_, up_], axis=1))
    pieces.append((v + cen, t))
    count += 1
v, t = merge(pieces)
hairs['curls'] = [piece_out(v, t, 0.06)]
print('curls blobs', count)


# ── pony: 뒤로 넘겨 묶은 포니테일(위는 부풀게 넘긴다) ──
pony_lim = jagged_lim(periodic_interp([(0, 1.694), (25, 1.692), (45, 1.655), (60, 1.615), (72, 1.590), (82, 1.606),
                                       (100, 1.608), (122, 1.530), (145, 1.493), (180, 1.496),
                                       (-25, 1.692), (-45, 1.655), (-60, 1.615), (-72, 1.590), (-82, 1.606),
                                       (-100, 1.608), (-122, 1.530), (-145, 1.493)]), 0.003, 20, 41)


def pony_thick(A, E):
    return _vol(A, E, 0.010 + 0.010 * smooth(10, 60, E))


v, t = cap_solid(pony_lim, pony_thick, n_az=40, n_rows=9, jitter=0.0015, seed=42,
                 lanes=16, lane_amp=0.005, tip_deg=1.2, scatter=0.25, edge_thin=0.7)
pieces = [(v, t)]
rng = np.random.default_rng(43)
TIE_AZ, TIE_EL = 180.0, 4.0     # 뒤통수 가장 볼록한 곳(귀 높이 조금 위) — 꼬리가 뒤통수에 기대어 늘어진다
for a_ in [-60, -38, -14, 10, 34, 58, -90, 90, -120, 120, -76, 76]:
    e_ = float(el_at_height(np.array([float(a_)]), np.array([float(pony_lim(a_)) + 0.012]))[0])
    n_ = 6
    path = slerp_path(a_, e_, TIE_AZ + (a_ * 0.04), TIE_EL, n_, lambda s: 0.011 + 0.014 * math.sin(math.pi * s))
    v, t = tube(path, taper(0.050, 0.024, n_, tip=False), taper(0.020, 0.012, n_, tip=False), sides=5, tip=False,
                roll=rng.uniform(0, 1), seed=int(rng.integers(1e6)), **LOCK)
    pieces.append((v, t))
tie = surf(TIE_AZ, TIE_EL, 0.018)
back = np.array([0, 0, 1.0])
# 꼬리: 묶은 자리에서 뒤로 조금 나왔다가 뒤통수를 따라 아래로(목덜미에서 조금 떨어져) 늘어진다. 가운데 굵은 다발 + 양옆 두 다발.
for dx, ln_y, wv in [(0.0, 1.425, 0.076), (0.016, 1.452, 0.054), (-0.016, 1.445, 0.054), (0.0, 1.470, 0.050)]:
    ctrl = np.array([tie - back * 0.010, tie + back * 0.024 + np.array([dx, 0.002, 0]),
                     np.array([tie[0] + dx * 1.5, tie[1] - 0.045, tie[2] + 0.034]),
                     np.array([tie[0] + dx * 2.0, (tie[1] + ln_y) / 2 - 0.035, tie[2] + 0.026]),
                     np.array([tie[0] + dx * 2.2, ln_y, tie[2] + 0.008])])
    path = catmull(ctrl, 2)
    n_ = len(path)
    bulge = np.sin(np.linspace(0, math.pi, n_)) * wv * 0.40
    v, t = tube(path, taper(wv * 0.62, wv * 0.38, n_, 0.8) + bulge, taper(wv * 0.55, wv * 0.32, n_, 0.8) + bulge * 0.7,
                sides=6, up=lambda p, i: np.array([0, 0, 1.0]), seed=int(rng.integers(1e6)), jit=0.14, twist=0.2)
    pieces.append((v, t))
v, t = merge(pieces)
hair_piece = piece_out(v, t, 0.04)
# 머리끈(꼬리 뿌리를 감는 짧은 고리) — 색 키 "tie".
ring_path = np.array([tie - back * 0.002, tie + back * 0.022])
v, t = tube(ring_path, [0.056, 0.056], [0.050, 0.050], sides=8, up=lambda p, i: np.array([0, 1.0, 0]), tip=False)
tie_piece = piece_out(v, t, 0.02)
tie_piece['c'] = 'tie'
hairs['pony'] = [hair_piece, tie_piece]

# ── wavy(기본 인형 기본): 굵게 물결치는 덩어리 — 위는 볼륨, 옆·뒤는 귀 위·목덜미까지 ──
#   바탕 모자 + 정수리 둘레에서 바깥·아래로 흐르며 한쪽으로 휘는 굵은 다발(세 줄, 다발마다 휘는 쪽이 번갈아) + 옆으로 넘긴 앞머리 물결.
def _mirror(pts):
    return pts + [(-a, y) for a, y in pts if 0 < a < 180]


wavy_lim = jagged_lim(periodic_interp(_mirror([(0, 1.690), (25, 1.688), (45, 1.645), (60, 1.605), (72, 1.582), (82, 1.600),
                                               (100, 1.596), (122, 1.522), (145, 1.488), (180, 1.490)])), 0.005, 18, 61)


def wavy_thick(A, E):
    return _vol(A, E, 0.013 + 0.015 * smooth(10, 60, E))


v, t = cap_solid(wavy_lim, wavy_thick, n_az=40, n_rows=9, jitter=0.0022, seed=62,
                 lanes=16, lane_amp=0.007, tip_deg=3.0, scatter=0.3, edge_thin=0.6)
pieces = [(v, t)]
rng = np.random.default_rng(63)
for ring_el, ring_n, ln, w0, th0, off in [(66, 9, 0.110, 0.062, 0.030, 0.0), (42, 11, 0.080, 0.056, 0.026, 16.0),
                                          (22, 12, 0.060, 0.048, 0.020, 8.0)]:
    for k in range(ring_n):
        a_ = -180 + off + 360.0 * k / ring_n + rng.uniform(-5, 5)
        if abs((a_ + 180) % 360 - 180) < 50:
            continue                      # 앞은 앞머리 물결이 맡는다
        n_ = 6
        sign = 1.0 if k % 2 == 0 else -1.0
        path = flow_path(a_, ring_el + rng.uniform(-4, 4), 180 + sign * 18, ln * rng.uniform(0.85, 1.15), n_,
                         lambda s: 0.011 + 0.016 * math.sin(math.pi * min(s, 0.85)), curve=-sign * 42)
        v, t = tube(path, taper(w0, w0 * 0.7, n_, 1.2), taper(th0, th0 * 0.62, n_), sides=5, roll=math.pi / 2,
                    seed=int(rng.integers(1e6)), **LOCK)
        pieces.append((v, t))
# 앞머리 물결: 정수리에서 앞으로 흘러 이마 위에서 캐릭터 오른쪽(+x)으로 휘어 넘어간다(왼쪽 가르마).
for a_, e_, ln, sweep, lift in [(-30, 72, 0.12, 35, 0.030), (-8, 76, 0.13, 30, 0.036), (14, 74, 0.12, 38, 0.032),
                                (36, 66, 0.09, 50, 0.022), (-46, 58, 0.08, 18, 0.016), (4, 84, 0.12, 32, 0.030)]:
    n_ = 6
    path = flow_path(a_, e_, 180 - sweep * 0.3, ln, n_, lambda s, l=lift: 0.011 + l * math.sin(math.pi * min(s, 0.8)),
                     curve=-sweep)
    v, t = tube(path, taper(0.056, 0.036, n_, 1.3), taper(0.028, 0.017, n_), sides=5, roll=math.pi / 2,
                seed=int(rng.integers(1e6)), **LOCK)
    pieces.append((v, t))
v, t = merge(pieces)
hairs['wavy'] = [piece_out(v, t, 0.05)]

# ── bun(솜 기본, 2026-11-28 밤): 뒤로 넘겨 왼쪽 뒤 · 귀 높이에 낮게 틀어 올린 올림머리 + 가르마에서 오른쪽으로 넘긴 앞 볼륨 ──
#   사용자 "솜 여자 캐릭터는 시안에 있던 게(틀어 올린 머리) 없어졌네 — 추가해 줘". 우리 v1 시안(hair_geo_v1.py BUN · KNOT)의
#   자리(캐릭터 왼쪽 뒤 · 낮게)를 새 머리에 맞춰 다시 만든다: 굵은 다발을 감아 올린 똬리 + 속 덩이 + 머리끈.
bun_lim = jagged_lim(periodic_interp([(0, 1.694), (25, 1.692), (45, 1.655), (60, 1.615), (72, 1.590), (82, 1.606),
                                      (100, 1.608), (122, 1.530), (145, 1.493), (180, 1.496),
                                      (-25, 1.692), (-45, 1.655), (-60, 1.615), (-72, 1.590), (-82, 1.606),
                                      (-100, 1.608), (-122, 1.530), (-145, 1.493)]), 0.003, 20, 71)


def bun_thick(A, E):
    return _vol(A, E, 0.009 + 0.010 * smooth(10, 60, E) + 0.007 * gauss(A, E, 22, 58, 34, 16)
                - 0.004 * gauss(A, E, -36, 62, 6, 20))          # 가르마 오른쪽 위가 부풀고 가르마는 홈


v, t = cap_solid(bun_lim, bun_thick, n_az=40, n_rows=9, jitter=0.0015, seed=72,
                 lanes=16, lane_amp=0.005, tip_deg=1.2, scatter=0.25, edge_thin=0.7)
pieces = [(v, t)]
rng = np.random.default_rng(73)
BUN_AZ, BUN_EL = -146.0, -9.0     # 캐릭터 왼쪽 뒤 · 귀 높이 조금 위
_b_th = float(bun_thick(np.array(BUN_AZ), np.array(BUN_EL)))
bun_root = surf(BUN_AZ, BUN_EL, _b_th)
bun_axis = bun_root - HC
bun_axis = bun_axis / np.linalg.norm(bun_axis) + np.array([0.0, 0.18, 0.0])   # 살짝 위를 본다
bun_axis /= np.linalg.norm(bun_axis)
_bu = np.cross(bun_axis, np.array([0.0, 1.0, 0.0]))
_bu /= np.linalg.norm(_bu)
_bv = np.cross(bun_axis, _bu)
bun_c = bun_root + bun_axis * 0.026
# 머리 → 번: 이마선 둘레에서 뒤로 넘겨 번 뿌리로 모이는 다발(위는 부풀게).
for a_ in [-58, -36, -14, 8, 30, 52, 74, 96, 122, 150, 178, -84, -108, -126]:
    e_ = float(el_at_height(np.array([float(a_)]), np.array([float(bun_lim(a_)) + 0.012]))[0])
    n_ = 7
    lift = 0.009 if abs(a_) < 80 else 0.006
    path = slerp_path(a_, e_, BUN_AZ + rng.uniform(-6, 6), BUN_EL + rng.uniform(-4, 4), n_,
                      lambda s, l=lift: 0.011 + l * math.sin(math.pi * min(s, 0.85)))
    v, t = tube(path, taper(0.052, 0.026, n_, tip=False), taper(0.020, 0.012, n_, tip=False), sides=5, tip=False,
                roll=rng.uniform(0, 1), seed=int(rng.integers(1e6)), **LOCK)
    pieces.append((v, t))
# 앞 볼륨: 가르마(왼쪽 −36°)에서 이마 위를 가로질러 오른쪽 관자 · 뒤로 넘어가는 굵은 물결(이마선 위에 머문다).
for a_, e_, ln, w0, curve, lift in [(-34, 70, 0.15, 0.056, 34, 0.026), (-38, 60, 0.13, 0.050, 40, 0.020),
                                    (-30, 78, 0.13, 0.050, 26, 0.024), (-42, 50, 0.08, 0.044, 44, 0.014)]:
    n_ = 6
    path = flow_path(a_, e_, 100, ln, n_, lambda s, l=lift: 0.012 + l * math.sin(math.pi * min(s, 0.75)), curve=curve)
    v, t = tube(path, taper(w0, w0 * 0.7, n_), taper(0.026, 0.016, n_), sides=5, roll=math.pi / 2,
                seed=int(rng.integers(1e6)), **LOCK)
    pieces.append((v, t))
# 번: 속 덩이 + 바깥에서 안으로 2.3 바퀴 감아 올린 굵은 다발(끝은 안쪽 위로 숨는다).
_rot = np.stack([_bu, bun_axis, _bv], axis=1)
v, t = ico(np.zeros(3), [0.041, 0.030, 0.041], jitter=0.12, seed=74, rot=_rot)
pieces.append((v + bun_c + bun_axis * 0.008, t))
n_ = 30
s_ = np.linspace(0.0, 1.0, n_)
ang = 2 * math.pi * 2.3 * s_
rr = 0.045 * (1 - 0.70 * s_)
hh = 0.038 * np.sin(0.5 * math.pi * s_)
coil = bun_c + rr[:, None] * (np.cos(ang)[:, None] * _bu + np.sin(ang)[:, None] * _bv) + hh[:, None] * bun_axis
v, t = tube(coil, taper(0.035, 0.018, n_, 0.8), taper(0.032, 0.017, n_, 0.8), sides=6,
            up=lambda p, i: bun_axis, seed=75, jit=0.12, twist=0.15)
pieces.append((v, t))
v, t = merge(pieces)
bun_piece = piece_out(v, t, 0.04)
# 머리끈(번 뿌리를 감는 짧은 고리) — 색 키 "tie"(포니테일과 같은 고정 색).
v, t = tube(np.array([bun_root - bun_axis * 0.002, bun_root + bun_axis * 0.020]), [0.056, 0.056], [0.056, 0.056], sides=8,
            up=lambda p, i: _bu, tip=False)
bun_tie = piece_out(v, t, 0.02)
bun_tie['c'] = 'tie'
hairs['bun'] = [bun_piece, bun_tie]

for k_, ps in hairs.items():
    print(k_, [(len(p['v']), len(p['t'])) for p in ps])


# ---------- 옛 도구(덧붙이는 조각이 쓴다 — v2 그대로) ----------
def ico_blob(center, radii, subdiv=1, jitter=0.08, seed=3, rot_y=0.0):
    t = (1 + 5 ** 0.5) / 2
    v = [[-1, t, 0], [1, t, 0], [-1, -t, 0], [1, -t, 0], [0, -1, t], [0, 1, t], [0, -1, -t], [0, 1, -t],
         [t, 0, -1], [t, 0, 1], [-t, 0, -1], [-t, 0, 1]]
    f = [[0, 11, 5], [0, 5, 1], [0, 1, 7], [0, 7, 10], [0, 10, 11], [1, 5, 9], [5, 11, 4], [11, 10, 2], [10, 7, 6],
         [7, 1, 8], [3, 9, 4], [3, 4, 2], [3, 2, 6], [3, 6, 8], [3, 8, 9], [4, 9, 5], [2, 4, 11], [6, 2, 10],
         [8, 6, 7], [9, 8, 1]]
    v = [np.array(x, float) / np.linalg.norm(x) for x in v]
    for _ in range(subdiv):
        cache = {}; nf = []

        def mid(a, b):
            k = (min(a, b), max(a, b))
            if k not in cache:
                m = v[a] + v[b]; v.append(m / np.linalg.norm(m)); cache[k] = len(v) - 1
            return cache[k]
        for a, b, c in f:
            ab, bc, ca = mid(a, b), mid(b, c), mid(c, a)
            nf += [[a, ab, ca], [b, bc, ab], [c, ca, bc], [ab, bc, ca]]
        f = nf
    rng = np.random.default_rng(seed)
    V_ = np.array(v) * (1 + rng.uniform(-jitter, jitter, (len(v), 1)))
    V_ = V_ * np.array(radii)
    cy, sy = math.cos(rot_y), math.sin(rot_y)
    R = np.array([[cy, 0, sy], [0, 1, 0], [-sy, 0, cy]])
    V_ = V_ @ R.T + np.array(center)
    return V_, np.array(f)


def godot_winding(verts, tris, center):
    """삼각형 법선이 center 에서 바깥을 보도록 맞춘 뒤, Godot 앞면(시계) 순서로 돌려준다."""
    out = []
    for a, b, c in tris:
        n = np.cross(verts[b] - verts[a], verts[c] - verts[a])
        m = (verts[a] + verts[b] + verts[c]) / 3 - center
        out.append([int(a), int(c), int(b)] if np.dot(n, m) > 0 else [int(a), int(b), int(c)])
    return out


def tuft_winding(verts, tris, base_center):
    out = []
    for a, b, c in tris:
        n = np.cross(verts[b] - verts[a], verts[c] - verts[a])
        m = (verts[a] + verts[b] + verts[c]) / 3 - base_center
        out.append([int(a), int(c), int(b)] if np.dot(n, m) > 0 else [int(a), int(b), int(c)])
    return out



# ---------- 6. 덧붙이는 조각(소맷단·밑단·깃·탭·속눈썹) ----------
TOP = np.array(d['Top_01']['surfaces'][0]['pos']); TOPN = np.array(d['Top_01']['surfaces'][0]['nor'])
BOT = np.array(d['Bottom_01']['surfaces'][0]['pos'])
SHO = np.vstack([np.array(s_['pos']) for s_ in d['Shoes_01']['surfaces']])


def frame(axis):
    a = axis / np.linalg.norm(axis)
    ref = np.array([0, 0, 1.0]) if abs(a[2]) < 0.9 else np.array([1.0, 0, 0])
    u = np.cross(a, ref); u /= np.linalg.norm(u)
    w = np.cross(a, u)
    return a, u, w


def ring_band(points, origin, axis, t0, t1, n=16, pad=0.005, flare=0.002):
    """points(옷 정점)의 축 둘레 단면을 따라 t0~t1 띠를 감싸는 낮은 폴리 고리."""
    a, u, w = frame(axis)
    rel = points - origin
    t = rel @ a
    sel = (t > t0 - 0.01) & (t < t1 + 0.01)
    q = rel[sel] - np.outer(t[sel], a)
    ang = np.arctan2(q @ w, q @ u)
    rad = np.linalg.norm(q, axis=1)
    bins = np.linspace(-np.pi, np.pi, n + 1)
    R = np.full(n, np.nan)
    for i in range(n):
        m = (ang >= bins[i]) & (ang < bins[i + 1])
        if m.any():
            R[i] = rad[m].max()
    R[np.isnan(R)] = np.nanmean(R)
    th = (bins[:-1] + bins[1:]) / 2

    def ring(tt, rr):
        return [origin + a * tt + (u * np.cos(th[i]) + w * np.sin(th[i])) * rr[i] for i in range(n)]
    outer0 = ring(t0, R + pad)
    outer1 = ring(t1, R + pad + flare)
    inner1 = ring(t1, R - 0.002)
    inner0 = ring(t0, R - 0.002)
    V_ = np.array(outer0 + outer1 + inner1 + inner0)
    T_ = []
    for i in range(n):
        j = (i + 1) % n
        for ra, rb in [(0, 1), (1, 2), (3, 0)]:
            T_ += [[ra * n + i, rb * n + i, rb * n + j], [ra * n + i, rb * n + j, ra * n + j]]
    return V_, T_, origin + a * (t0 + t1) / 2, a


def godot_winding_axis(verts, tris, center, axis):
    """축 둘레 고리: 축에서 바깥을 보는 면이 앞면. 끝 마개는 중심에서 바깥으로."""
    out = []
    for a_, b_, c_ in tris:
        n_ = np.cross(verts[b_] - verts[a_], verts[c_] - verts[a_])
        m_ = (verts[a_] + verts[b_] + verts[c_]) / 3 - center
        radial = m_ - axis * (m_ @ axis)
        ref = radial if abs(np.dot(n_ / (np.linalg.norm(n_) + 1e-12), axis)) < 0.7 else m_
        out.append([int(a_), int(c_), int(b_)] if np.dot(n_, ref) > 0 else [int(a_), int(b_), int(c_)])
    return out


extras = {'base': [], 'jun': [], 'som': [], 'on': []}

# 준: 소매 끝 황토 접은 소맷단
for side, bone in [(1, 'upper_arm.R'), (-1, 'upper_arm.L')]:
    sh = np.array([0.175 * side, 1.208, 0.006]); el = np.array([0.367 * side, 0.964, 0.028])
    ax = el - sh; axn = ax / np.linalg.norm(ax)
    sleeve = TOP[(TOP[:, 0] * side > 0.17)]
    tmax = ((sleeve - sh) @ axn).max()
    V_, T_, cen, a_ = ring_band(sleeve, sh, ax, tmax - 0.032, tmax + 0.004, n=16, pad=0.006, flare=0.003)
    extras['jun'].append({'v': np.round(V_, 5).tolist(), 't': godot_winding_axis(V_, T_, cen, a_), 'c': 'accent', 'bone': bone, 'shade': 0.02})


def neck_ring(n=28):
    neck = TOP[TOP[:, 1] > 1.20]
    ang = np.arctan2(neck[:, 0], -(neck[:, 2] + 0.02))
    bins = np.linspace(-np.pi, np.pi, n + 1)
    pts = []
    for i in range(n):
        m = (ang >= bins[i]) & (ang < bins[i + 1])
        cand = neck[m]
        rr = np.hypot(cand[:, 0], cand[:, 2] + 0.02)
        inner = cand[rr < 0.10]
        cand = inner if len(inner) else cand
        pts.append(cand[np.argmax(cand[:, 1])])
    return np.array(pts), (bins[:-1] + bins[1:]) / 2


NR, NA = neck_ring()


def collar(open_deg, rise, outward, tilt_out, color, bone='chest'):
    """목둘레를 따라 세운(또는 눕힌) 깃. open_deg = 앞 가운데 벌어진 각(양쪽 합)."""
    keep = [i for i in range(len(NA)) if abs(np.degrees(NA[i])) > open_deg / 2]
    order = sorted(keep, key=lambda i: (NA[i] if NA[i] > 0 else NA[i] + 2 * np.pi))
    V_ = []
    for i in order:
        base = NR[i]
        out = np.array([np.sin(NA[i]), 0, -np.cos(NA[i])])
        V_ += [base + out * outward - np.array([0, 0.004, 0]), base + out * (outward + tilt_out) + np.array([0, rise, 0])]
    T_ = []
    for k in range(len(order) - 1):
        a0, a1, c0_, c1_ = 2 * k, 2 * k + 1, 2 * k + 2, 2 * k + 3
        T_ += [[a0, a1, c1_], [a0, c1_, c0_]]
    V_ = np.array(V_)
    cen = np.array([0.0, NR[:, 1].mean() - 0.05, -0.02])
    return {'v': np.round(V_, 5).tolist(), 't': godot_winding(V_, T_, cen), 'c': color, 'bone': bone, 'shade': 0.02}


extras['jun'].append(collar(open_deg=64, rise=0.009, outward=0.006, tilt_out=0.016, color='shirt'))
extras['on'].append(collar(open_deg=34, rise=0.030, outward=0.004, tilt_out=-0.004, color='shirt'))

# 솜: 바짓단 연청록 접단
for side, bone in [(1, 'shin.R'), (-1, 'shin.L')]:
    kn = np.array([0.123 * side, 0.385, 0.015]); an = np.array([0.150 * side, 0.086, 0.024])
    ax = an - kn; axn = ax / np.linalg.norm(ax)
    leg = BOT[(BOT[:, 0] * side > 0.02) & (BOT[:, 1] < 0.40)]
    tmax = ((leg - kn) @ axn).max()
    V_, T_, cen, a_ = ring_band(leg, kn, ax, tmax - 0.040, tmax + 0.002, n=16, pad=0.006, flare=0.001)
    extras['som'].append({'v': np.round(V_, 5).tolist(), 't': godot_winding_axis(V_, T_, cen, a_), 'c': 'turnup', 'bone': bone, 'shade': 0.02})

# 솜: 속눈썹(눈 바깥 위쪽 작은 쐐기 3개)
EYES = {1: np.array([0.0735, 1.5955, -0.2027]), -1: np.array([-0.0665, 1.5972, -0.2065])}
for side in (1, -1):
    c_ = EYES[side]
    V_ = []; T_ = []
    for ang, ln in [(62, 0.014), (40, 0.019), (18, 0.016)]:
        a_ = np.radians(ang)
        dirv = np.array([side * np.cos(a_), np.sin(a_), -0.35]); dirv /= np.linalg.norm(dirv)
        root = c_ + np.array([side * np.cos(a_) * 0.9, np.sin(a_) * 0.9, -0.45]) * 0.026
        tip = root + dirv * ln
        perp = np.cross(dirv, np.array([0, 0, -1.0])); perp /= np.linalg.norm(perp)
        b = len(V_)
        V_ += [root + perp * 0.0035, root - perp * 0.0035, tip, root + np.array([0, 0, 0.004])]
        T_ += [[b, b + 1, b + 2], [b + 3, b, b + 2], [b + 3, b + 2, b + 1], [b + 3, b + 1, b]]
    V_ = np.array(V_)
    extras['som'].append({'v': np.round(V_, 5).tolist(), 't': godot_winding(V_, T_, c_ + np.array([0, 0, 0.01])), 'c': 'brow', 'bone': 'head', 'shade': 0.0})

# 온: 허리 양옆 청회색 캡슐 탭
for side in (1, -1):
    sel = (np.abs(TOP[:, 1] - 0.815) < 0.012) & (TOP[:, 2] < 0) & (np.abs(TOP[:, 0] - 0.145 * side) < 0.012)
    k_ = np.argmin(TOP[sel][:, 2])
    p0 = TOP[sel][k_]; nrm = TOPN[sel][k_]
    cen = p0 + nrm * 0.006
    yaw = np.arctan2(-nrm[0], -nrm[2])
    V_, T_ = ico_blob(cen, [0.042, 0.015, 0.012], subdiv=1, jitter=0.03, seed=40 + side)
    R = np.array([[np.cos(yaw), 0, np.sin(yaw)], [0, 1, 0], [-np.sin(yaw), 0, np.cos(yaw)]])
    V_ = (V_ - cen) @ R.T + cen
    extras['on'].append({'v': np.round(V_, 5).tolist(), 't': godot_winding(V_, T_.tolist(), cen), 'c': 'tab', 'bone': 'hips', 'shade': 0.02})

# 온: 신발 뒤꿈치 벽돌색 고리 탭
for side, bone in [(1, 'foot.R'), (-1, 'foot.L')]:
    sh_ = SHO[(SHO[:, 0] * side > 0)]
    xc = sh_[:, 0].mean()
    back = sh_[(np.abs(sh_[:, 0] - xc) < 0.02) & (sh_[:, 1] > 0.08)]
    z = back[:, 2].max(); y = back[:, 1].max()
    cen = np.array([xc, y + 0.004, z - 0.006])
    V_, T_ = ico_blob(cen, [0.011, 0.022, 0.008], subdiv=1, jitter=0.02, seed=50 + side)
    extras['on'].append({'v': np.round(V_, 5).tolist(), 't': godot_winding(V_, T_.tolist(), cen), 'c': 'pull', 'bone': bone, 'shade': 0.0})


# 입체 눈썹(5번에서 만든 것)

out = {
    'extras': extras,
    'head_surface': 2,
    'head_rigid_src': RIGID_SRC,
    'heads': heads,
    'hairs': hairs,
}
json.dump(out, open(f'{HERE}/geo.json', 'w'))
print('heads', {k: len(v['k']) for k, v in heads.items()})
