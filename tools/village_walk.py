#!/usr/bin/env python3
"""마을 동선 계산 (2026-10-01 넓어진 마을 동선 점검).

tests/village_walk.tscn 이 남긴 JSON (실제 막힘으로 뽑은 4px 격자 · 장소마다 F 가 닿는 자리 · 들나물 판)으로
농부가 마을 안에서 걷는 시간을 구한다. 길은 8방향 최단 경로 (모서리를 깎지 않음), 빠르기는 장비 없는 기본값.

    python3 tools/village_walk.py new.json [old.json]

old.json 을 주면 옛 마을과 나란히 적는다.
"""
import heapq
import json
import math
import sys

# 하루 일과 (농부, 마을 안에서 걷기만. 밭 안 · 사냥터 안 걷기는 마을 크기와 상관없어서 뺀다)
EARLY = ["집 현관", "밭", "공급함", "부화기", "공급함", "들나물", "공급함", "집 현관"]
LATE_EXTRA = ["창고", "대장간", "약방", "축사"]


class Village:
    def __init__(self, path):
        d = json.load(open(path, encoding="utf-8"))
        self.d = d
        self.cols, self.rows, self.g = d["cols"], d["rows"], d["grid"]
        self.free = d["free"]
        self.speed = d["speed"]
        self.mps = d["min_per_sec"]
        self.places = {k: set(v) for k, v in d["places"].items()}
        self.herbs = {k: set(v) for k, v in d["herbs"].items()}
        self._cache = {}
        # 장소마다 기준 자리 = 현관에서 걸어가 처음 닿는 자리
        door = min(self.places["집 현관"])
        self.anchor = {"집 현관": door}
        for name, nodes in self.places.items():
            if name != "집 현관":
                self.anchor[name] = self.reach(door, nodes)[1]

    def dist(self, s):
        if s in self._cache:
            return self._cache[s]
        c, r, free = self.cols, self.rows, self.free
        dist = {s: 0.0}
        pq = [(0.0, s)]
        diag = math.sqrt(2)
        while pq:
            d, i = heapq.heappop(pq)
            if d > dist.get(i, 1e18):
                continue
            x, y = i % c, i // c
            for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1), (1, 1), (1, -1), (-1, 1), (-1, -1)):
                xx, yy = x + dx, y + dy
                if not (0 <= xx < c and 0 <= yy < r):
                    continue
                j = yy * c + xx
                if not free[j]:
                    continue
                if dx and dy and (not free[y * c + xx] or not free[yy * c + x]):
                    continue
                nd = d + (diag if dx and dy else 1.0) * self.g
                if nd < dist.get(j, 1e18):
                    dist[j] = nd
                    heapq.heappush(pq, (nd, j))
        self._cache[s] = dist
        return dist

    def reach(self, s, goal):
        """s 에서 goal 마디들 중 가장 가까운 곳까지 (초, 도착 마디)"""
        if s in goal:
            return 0.0, s
        dist = self.dist(s)
        best = min(((dist[g], g) for g in goal if g in dist), default=None)
        if best is None:
            raise RuntimeError("길 없음")
        return best[0] / self.speed, best[1]

    def leg(self, a, b):
        return self.reach(self.anchor[a], self.places[b])[0]

    def herb_run(self, start):
        """start 에서 오늘 돋은 들나물을 가까운 것부터 다 캐고 공급함으로 → [판마다 초]"""
        out, counts = [], []
        for sprout in self.d["sprouts"]:
            node, sec, left = start, 0.0, list(sprout)
            counts.append(len(left))
            while left:
                best = None
                for h in left:
                    t, n = self.reach(node, self.herbs[h])
                    if best is None or t < best[0]:
                        best = (t, n, h)
                sec += best[0]
                node = best[1]
                left.remove(best[2])
            sec += self.reach(node, self.places["공급함"])[0]
            out.append(sec)
        return out, sum(counts) / len(counts)

    def route(self, names):
        total, rows = 0.0, []
        herb_avg = herb_max = 0.0
        for a, b in zip(names, names[1:]):
            if b == "들나물":
                runs, n = self.herb_run(self.anchor[a])
                herb_avg, herb_max = sum(runs) / len(runs), max(runs)
                rows.append((f"{a} → 들나물 {n:.1f}포기 → 공급함 (평균, 가장 긴 판 {herb_max:.0f}초)", herb_avg))
                total += herb_avg
            elif a == "들나물":
                continue
            else:
                t = self.leg(a, b)
                rows.append((f"{a} → {b}", t))
                total += t
        return total, rows


def late_route(v):
    extra = [p for p in LATE_EXTRA if p in v.places]
    # 공급함에서 시설을 한 바퀴 (가까운 순서) 돌고 공급함으로
    names, cur, left = ["공급함"], "공급함", list(extra)
    while left:
        nxt = min(left, key=lambda p: v.leg(cur, p))
        names.append(nxt)
        left.remove(nxt)
        cur = nxt
    names.append("공급함")
    return names


def main():
    vs = [Village(p) for p in sys.argv[1:3]]
    labels = ["%dx%d" % tuple(v.d["map"]) for v in vs]
    print("# 마을 동선 (농부, 장비 없는 기본 빠르기 %.0fpx/초 · 실제 1초 = 게임 %.0f분 · 하루 6시~새벽 2시 = 실제 600초)" % (vs[0].speed, vs[0].mps))
    print()
    print("## 구간 (초)  " + " / ".join(labels))
    keys = ["집 현관", "밭", "공급함", "부화기", "사냥터 입구", "창고", "대장간", "약방", "축사"]
    for a, b in [("집 현관", "밭"), ("밭", "공급함"), ("공급함", "부화기"), ("공급함", "집 현관"), ("공급함", "사냥터 입구"),
                 ("공급함", "창고"), ("공급함", "대장간"), ("공급함", "약방"), ("공급함", "축사"), ("밭", "집 현관")]:
        if all(a in v.places and b in v.places for v in vs):
            print(f"- {a} → {b}: " + " / ".join(f"{v.leg(a, b):.1f}" for v in vs))
    results = []
    for v, lab in zip(vs, labels):
        early, rows = v.route(EARLY)
        late_names = late_route(v)
        late, lrows = v.route(late_names)
        hunt = v.leg("사냥터 입구", "공급함") + v.leg("공급함", "사냥터 입구")
        results.append((early, late, hunt))
        print(f"\n## {lab} 마을")
        for name, t in rows:
            print(f"- {name}: {t:.1f}초")
        print(f"- 하루 기본 일과 합계: {early:.1f}초 = 게임 {early * v.mps:.0f}분 (하루의 {early / 6:.1f}%)")
        print(f"- 시설 한 바퀴 ({' → '.join(late_names)}): {late:.1f}초")
        print(f"- 사냥꾼 사냥터 입구 ↔ 공급함 왕복: {hunt:.1f}초")
        print(f"- 늦은 날 (기본 + 시설 한 바퀴): {early + late:.1f}초 = 게임 {(early + late) * v.mps:.0f}분 (하루의 {(early + late) / 6:.1f}%)")
    if len(vs) == 2:
        (e0, l0, h0), (e1, l1, h1) = results
        print(f"\n## 비교 ({labels[1]} → {labels[0]})")
        print(f"- 하루 기본 일과: {e1:.1f}초 → {e0:.1f}초 (+{e0 - e1:.1f}초, x{e0 / e1:.2f})")
        print(f"- 늦은 날: {e1 + l1:.1f}초 → {e0 + l0:.1f}초 (+{e0 + l0 - e1 - l1:.1f}초, x{(e0 + l0) / (e1 + l1):.2f})")
        print(f"- 사냥꾼 입구 ↔ 공급함: {h1:.1f}초 → {h0:.1f}초")
    print("\nRESULT " + json.dumps({lab: {"early": round(e, 1), "late": round(e + l, 1), "hunt": round(h, 1)} for lab, (e, l, h) in zip(labels, results)}, ensure_ascii=False))


if __name__ == "__main__":
    main()
