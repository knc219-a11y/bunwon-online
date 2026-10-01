"""분원리 소리 만들기 (2026-10-01 사운드 첫 단계).

모든 효과음 · 배경음을 코드로 합성한다. 외부 소리 파일을 하나도 쓰지 않으므로 저작권 걱정이 없다.
같은 곡 · 같은 효과음을 세 가지 음색으로 만든다:
  chip     칩튠 (네모파 · 세모파 · 노이즈, 옛날 게임기 느낌)
  acoustic 따뜻한 어쿠스틱 (기타 · 마림바 · 플루트 · 셰이커, 아늑한 시골)
  gugak    국악풍 (가야금 · 대금 · 장구 · 북, 한국 시골 + 요괴)

쓰는 법:  python3 tools/make_sounds.py <스타일|all> <출력 폴더> [--ogg] [--game]
필요: numpy, scipy (ogg 는 ffmpeg)
"""
import os
import subprocess
import sys

import numpy as np
from scipy import signal

SR = 44100
RNG = np.random.default_rng(219)

NOTE_IDX = {"C": 0, "C#": 1, "D": 2, "D#": 3, "E": 4, "F": 5, "F#": 6, "G": 7, "G#": 8, "A": 9, "A#": 10, "B": 11}


def midi(name: str) -> int:
	return NOTE_IDX[name[:-1]] + 12 * (int(name[-1]) + 1)


def hz(m: float) -> float:
	return 440.0 * 2 ** ((m - 69) / 12)


def t_axis(sec: float) -> np.ndarray:
	return np.arange(int(sec * SR)) / SR


def lowpass(x, cut, order=2):
	b, a = signal.butter(order, min(cut, SR * 0.45) / (SR / 2), "low")
	return signal.lfilter(b, a, x)


def highpass(x, cut, order=2):
	b, a = signal.butter(order, cut / (SR / 2), "high")
	return signal.lfilter(b, a, x)


def bandpass(x, lo, hi, order=2):
	b, a = signal.butter(order, [lo / (SR / 2), min(hi, SR * 0.45) / (SR / 2)], "band")
	return signal.lfilter(b, a, x)


def env_ar(n, attack, release_total, hold=None):
	"""attack 뒤 지수 감쇠."""
	t = np.arange(n) / SR
	e = np.minimum(1.0, t / max(attack, 1e-4))
	return e * np.exp(-t / max(release_total, 1e-4))


def gate_env(n, attack, dur, release):
	"""dur 동안 유지 후 release."""
	t = np.arange(n) / SR
	e = np.minimum(1.0, t / max(attack, 1e-4))
	tail = np.clip(1 - (t - dur) / release, 0, 1)
	return e * np.where(t < dur, 1.0, tail)


def phase_of(freq_arr):
	return 2 * np.pi * np.cumsum(freq_arr) / SR


def noise(n):
	return RNG.uniform(-1, 1, n)


def reverb(x, sec=1.4, wet=0.22, bright=5000):
	n = int(sec * SR)
	ir = noise(n) * np.exp(-np.arange(n) / SR * (6.9 / sec))
	ir = lowpass(ir, bright)
	ir[:int(0.012 * SR)] = 0
	ir /= np.sqrt(np.sum(ir ** 2)) + 1e-9
	y = signal.fftconvolve(x, ir)[:len(x)]
	return x * (1 - wet) + y * wet * 0.9


# ---------------------------------------------------------------- 악기

# 칩튠
def chip_square(f, dur, vel=1.0, duty=0.5, vib=0.0):
	n = int((dur + 0.06) * SR)
	t = np.arange(n) / SR
	fr = f * (1 + vib * 0.012 * np.sin(2 * np.pi * 5.5 * t) * np.clip((t - 0.15) / 0.2, 0, 1))
	ph = np.cumsum(fr) / SR % 1.0
	w = np.where(ph < duty, 1.0, -1.0)
	e = gate_env(n, 0.003, dur, 0.05) * (0.75 + 0.25 * np.exp(-t * 8))
	return w * e * vel * 0.22


def chip_tri(f, dur, vel=1.0):
	n = int((dur + 0.03) * SR)
	ph = np.cumsum(np.full(n, f)) / SR % 1.0
	ph = np.floor(ph * 16) / 16  # 4비트 계단
	w = 4 * np.abs(ph - 0.5) - 1
	return w * gate_env(n, 0.002, dur, 0.02) * vel * 0.4


def chip_noise(dur, vel=1.0, rate=8000, decay=0.08):
	n = int(dur * SR)
	hold = max(1, int(SR / rate))
	w = np.repeat(noise(n // hold + 1), hold)[:n]
	return w * env_ar(n, 0.001, decay) * vel * 0.3


def chip_kick(vel=1.0):
	n = int(0.16 * SR)
	t = np.arange(n) / SR
	fr = 50 + 160 * np.exp(-t * 35)
	ph = np.cumsum(fr) / SR % 1.0
	w = 4 * np.abs(ph - 0.5) - 1
	return w * env_ar(n, 0.001, 0.07) * vel * 0.55


# 어쿠스틱 / 국악 공통: 카플러스-스트롱 뜯는 줄
def ks_pluck(f, dur, vel=1.0, bright=0.6, decay=0.996, ring=1.2):
	period = max(2, int(round(SR / f)))
	n = int((dur + ring) * SR)
	y = np.zeros(n + period + 1)
	burst = noise(period)
	burst = lowpass(burst, 1500 + 7000 * bright)
	y[:period] = burst
	k = period
	while k < n:
		end = min(k + period, n)
		seg = y[k - period:end - period]
		prev = y[k - period - 1:end - period - 1] if k - period - 1 >= 0 else np.concatenate(([0], y[k - period:end - period - 1]))
		y[k:end] = decay * 0.5 * (seg + prev)
		k = end
	y = y[:n]
	t = np.arange(n) / SR
	damp = np.where(t < dur, 1.0, np.exp(-(t - dur) * 6))
	return y * damp * vel * 0.5


def marimba(f, dur, vel=1.0):
	n = int((min(dur, 0.6) + 0.8) * SR)
	t = np.arange(n) / SR
	w = np.sin(2 * np.pi * f * t) * np.exp(-t * 4.5)
	w += 0.35 * np.sin(2 * np.pi * f * 4.0 * t) * np.exp(-t * 18)
	w += 0.12 * np.sin(2 * np.pi * f * 9.8 * t) * np.exp(-t * 40)
	w *= np.minimum(1, t / 0.002)
	return w * vel * 0.45


def flute(f, dur, vel=1.0, breath=0.10, scoop=0.0, reedy=0.0):
	n = int((dur + 0.18) * SR)
	t = np.arange(n) / SR
	vib = 0.008 * np.sin(2 * np.pi * 5.2 * t) * np.clip((t - 0.25) / 0.3, 0, 1)
	sc = -scoop * np.exp(-t * 18)  # 반음 아래에서 밀어 올리기 (대금 느낌)
	fr = f * 2 ** ((sc) / 12) * (1 + vib)
	ph = phase_of(fr)
	w = np.sin(ph) + 0.25 * np.sin(2 * ph) + 0.08 * np.sin(3 * ph)
	if reedy:
		w += reedy * (0.5 * np.sin(3 * ph) + 0.3 * np.sin(5 * ph) + 0.15 * np.sin(7 * ph))
	b = bandpass(noise(n), f * 1.5, min(f * 6, 15000)) * breath * 4
	e = gate_env(n, 0.06, dur, 0.15)
	return (w + b * (0.6 + 0.6 * np.exp(-t * 10))) * e * vel * 0.22


def pad(f, dur, vel=1.0):
	n = int((dur + 0.8) * SR)
	t = np.arange(n) / SR
	w = np.zeros(n)
	for det in (-0.004, 0.0, 0.005):
		ph = np.cumsum(np.full(n, f * (1 + det))) / SR % 1.0
		w += 2 * ph - 1
	w = lowpass(w, 1400)
	return w * gate_env(n, 0.5, dur, 0.8) * vel * 0.05


def gayageum(f, dur, vel=1.0, nonghyeon=1.0, bright=1.0):
	"""가야금: 뜯은 뒤 줄을 눌러 흔드는 농현."""
	n = int((dur + 1.0) * SR)
	t = np.arange(n) / SR
	vib = nonghyeon * 0.018 * np.sin(2 * np.pi * 5.0 * t) * np.clip((t - 0.18) / 0.25, 0, 1)
	ph = phase_of(f * (1 + vib))
	w = np.zeros(n)
	for k in range(1, 10):
		w += (1.0 / k ** (1.3 - 0.3 * bright)) * np.sin(k * ph) * np.exp(-t * (2.2 + k * 1.6))
	w += 0.3 * lowpass(noise(n), 4000) * np.exp(-t * 120)
	damp = np.where(t < dur + 0.1, 1.0, np.exp(-(t - dur - 0.1) * 5))
	return w * damp * np.minimum(1, t / 0.002) * vel * 0.32


def geomungo(f, dur, vel=1.0):
	n = int((dur + 0.6) * SR)
	t = np.arange(n) / SR
	ph = phase_of(np.full(n, f))
	w = np.zeros(n)
	for k in range(1, 7):
		w += (1.0 / k) * np.sin(k * ph) * np.exp(-t * (2.5 + k * 2.2))
	w += 0.5 * bandpass(noise(n), 200, 1800) * np.exp(-t * 60)  # 술대로 치는 소리
	return w * np.minimum(1, t / 0.002) * vel * 0.5


def drum_tone(f0, f1, decay, vel=1.0, noise_amt=0.2, length=0.4):
	n = int(length * SR)
	t = np.arange(n) / SR
	fr = f1 + (f0 - f1) * np.exp(-t * 30)
	w = np.sin(phase_of(fr)) * np.exp(-t / decay)
	w += noise_amt * lowpass(noise(n), 2500) * np.exp(-t * 40)
	return w * vel * 0.6


def shaker(vel=1.0):
	n = int(0.09 * SR)
	return highpass(noise(n), 5000) * env_ar(n, 0.008, 0.03) * vel * 0.25


def snap(vel=1.0, lo=1200, hi=5000, decay=0.05):
	n = int(0.25 * SR)
	return bandpass(noise(n), lo, hi) * env_ar(n, 0.001, decay) * vel * 0.6


def woodblock(f=900, vel=1.0):
	n = int(0.12 * SR)
	t = np.arange(n) / SR
	return (np.sin(2 * np.pi * f * t) + 0.4 * np.sin(2 * np.pi * f * 2.7 * t)) * np.exp(-t * 45) * vel * 0.35


def crickets(sec, vel=1.0):
	n = int(sec * SR)
	t = np.arange(n) / SR
	out = np.zeros(n)
	for f, rate, off in ((4300, 2.1, 0.0), (4700, 1.7, 0.4), (3900, 2.6, 0.9)):
		chirp = (np.sin(2 * np.pi * 30 * t) > 0.2).astype(float)  # 따르르
		burst = (np.sin(2 * np.pi * (t * rate + off)) > 0.55).astype(float)
		out += np.sin(2 * np.pi * f * t) * lowpass(chirp * burst, 400)
	return out * vel * 0.02


# ---------------------------------------------------------------- 곡 (세 스타일이 같은 곡을 쓴다)

def parse(seq):
	"""'F#5:1 A5:.5 R:1' → [(시작박, 길이, midi or None)]"""
	out, beat = [], 0.0
	for tok in seq.split():
		name, d = tok.split(":")
		d = float(d)
		out.append((beat, d, None if name == "R" else midi(name)))
		beat += d
	return out


SONGS = {
	"village_day": {
		"bpm": 96, "bars": 16,
		"chords": ["D", "Bm", "G", "A"] * 4,
		"melody": parse(
			"F#5:1 A5:1 B5:1 A5:1  F#5:1.5 E5:.5 D5:2  E5:1 F#5:1 A5:1 B5:1  A5:3 R:1 "
			"F#5:1 A5:1 B5:1 D6:1  B5:1.5 A5:.5 F#5:2  E5:1 D5:1 E5:1 F#5:1  E5:3 R:1 "
			"D6:1.5 B5:.5 A5:1 B5:1  A5:1 F#5:1 D5:2  E5:.5 F#5:.5 A5:1 B5:1 A5:1  F#5:1 E5:1 R:2 "
			"F#5:1 A5:1 B5:1 A5:1  F#5:1.5 E5:.5 D5:1 B4:1  D5:1 E5:1 F#5:1 A5:1  E5:2 F#5:1 E5:1"),
	},
	"village_night": {
		"bpm": 66, "bars": 8,
		"chords": ["Am", "F", "C", "G"] * 2,
		"melody": parse(
			"E5:2 D5:1 C5:1  A4:3 R:1  C5:1 D5:1 E5:1 G5:1  E5:3 R:1 "
			"A5:2 G5:1 E5:1  D5:2 C5:1 D5:1  E5:1.5 D5:.5 C5:1 A4:1  G4:3 R:1"),
	},
	"hunt": {
		"bpm": 132, "bars": 16,
		"chords": ["Em", "Em", "C", "D"] * 4,
		"melody": parse(
			"E5:.5 E5:.5 G5:.5 A5:.5 B5:1 A5:.5 G5:.5  E5:1 D5:.5 E5:.5 G5:1 R:1 "
			"A5:.5 A5:.5 G5:.5 A5:.5 B5:1 D6:1  B5:1.5 A5:.5 G5:1 D5:1 "
			"E5:.5 E5:.5 G5:.5 A5:.5 B5:1 A5:.5 G5:.5  E5:1 D5:.5 E5:.5 G5:1 R:1 "
			"A5:.5 B5:.5 D6:.5 E6:.5 D6:1 B5:1  A5:1.5 G5:.5 A5:1 B5:1 "
			"E6:1 D6:.5 B5:.5 D6:1 E6:1  B5:1 A5:.5 G5:.5 E5:2 "
			"G5:.5 A5:.5 B5:.5 A5:.5 G5:1 E5:1  D5:1 E5:.5 G5:.5 A5:2 "
			"E6:1 D6:.5 B5:.5 D6:1 E6:1  G6:1 E6:.5 D6:.5 B5:2 "
			"A5:.5 B5:.5 D6:.5 B5:.5 A5:1 G5:1  A5:1 B5:1 D6:.5 B5:.5 A5:.5 D5:.5"),
	},
}

CHORD_TONES = {
	"D": ["D", "F#", "A"], "Bm": ["B", "D", "F#"], "G": ["G", "B", "D"], "A": ["A", "C#", "E"],
	"Am": ["A", "C", "E"], "F": ["F", "A", "C"], "C": ["C", "E", "G"],
	"Em": ["E", "G", "B"],
}


def chord_midis(ch, octave):
	root = midi(CHORD_TONES[ch][0] + str(octave))
	out = []
	for nm in CHORD_TONES[ch]:
		m = midi(nm + str(octave))
		while m < root:
			m += 12
		out.append(m)
	return out


class Track:
	def __init__(self, bpm, bars):
		self.spb = 60.0 / bpm
		self.length = bars * 4 * self.spb
		self.buf = np.zeros(int((self.length + 3.0) * SR))

	def put(self, beat, wave, gain=1.0, pan=0.0):
		i = int(beat * self.spb * SR)
		end = min(len(self.buf), i + len(wave))
		self.buf[i:end] += wave[:end - i] * gain

	def finish(self, verb=None):
		x = self.buf
		if verb:
			x = reverb(x, **verb)
		n = int(self.length * SR)
		loop = x[:n].copy()
		tail = x[n:]
		loop[:len(tail)] += tail[:n]  # 끝에서 넘친 소리를 앞으로 접어 이음새 없이 반복
		return loop


def arrange(style, song_id):
	s = SONGS[song_id]
	tr = Track(s["bpm"], s["bars"])
	spb = tr.spb
	night = song_id == "village_night"
	hunt = song_id == "hunt"
	# --- 멜로디
	for beat, d, m in s["melody"]:
		if m is None:
			continue
		f, dur = hz(m), d * spb * 0.95
		if style == "chip":
			w = chip_tri(f, dur, 0.9) * 0.9 if night else chip_square(f, dur, 0.9, duty=0.25 if hunt else 0.5, vib=1.0)
		elif style == "acoustic":
			if night:
				w = flute(f, dur, 1.0, breath=0.05)
			elif hunt:
				w = ks_pluck(f, dur, 0.9, bright=0.9, ring=0.3) + ks_pluck(f * 1.003, dur, 0.5, bright=0.9, ring=0.3)
			else:
				w = marimba(f, dur, 1.0)
		else:  # gugak
			if night:
				w = flute(f / 2, dur, 1.1, breath=0.14, scoop=1.0)
			elif hunt:
				w = mix(gayageum(f, dur, 0.9, nonghyeon=0.4, bright=1.5), flute(f, dur, 0.5, breath=0.12, reedy=0.8))
			else:
				w = gayageum(f, dur, 1.0)
		tr.put(beat, w)
	# --- 반주 · 베이스 · 북
	for bar, ch in enumerate(s["chords"]):
		b0 = bar * 4
		tones3 = chord_midis(ch, 3)
		tones4 = chord_midis(ch, 4)
		root2 = tones3[0] - 12
		# 베이스
		if hunt:
			for e in range(8):
				m = root2 if e % 2 == 0 else root2 + 12
				if style == "chip":
					w = chip_tri(hz(m), spb * 0.45)
				elif style == "acoustic":
					w = ks_pluck(hz(m), spb * 0.4, 0.9, bright=0.3, ring=0.1)
				else:
					w = geomungo(hz(m), spb * 0.4, 0.8)
				tr.put(b0 + e * 0.5, w)
		else:
			for beat, m in ((0, root2), (2, root2 + 7)):
				dur = spb * (3.8 if night else 1.8)
				if night and beat == 2:
					continue
				if style == "chip":
					w = chip_tri(hz(m), dur * 0.9)
				elif style == "acoustic":
					w = ks_pluck(hz(m), dur, 0.9, bright=0.2, decay=0.998)
				else:
					w = geomungo(hz(m), dur, 0.8)
				tr.put(b0 + beat, w)
		# 화음
		if night:
			arp = [tones4[0], tones4[1], tones4[2], tones4[1]]
			for i, m in enumerate(arp):
				f = hz(m)
				if style == "chip":
					w = chip_square(f, spb * 0.5, 0.35, duty=0.125)
				elif style == "acoustic":
					w = ks_pluck(f, spb * 0.9, 0.45, bright=0.4)
				else:
					w = gayageum(f, spb * 0.8, 0.35, nonghyeon=0.5)
				tr.put(b0 + i, w)
			if style != "chip":
				for m in tones3:
					tr.put(b0, pad(hz(m), 4 * spb, 0.9))
		else:
			arp = [tones4[0], tones4[2], tones4[1] + 12 if hunt else tones4[0] + 12, tones4[1]] * 2
			for i, m in enumerate(arp):
				f = hz(m)
				if style == "chip":
					w = chip_square(f, spb * 0.4, 0.3, duty=0.125)
				elif style == "acoustic":
					w = ks_pluck(f, spb * 0.45, 0.4, bright=0.5, ring=0.4)
				else:
					w = gayageum(f, spb * 0.4, 0.28, nonghyeon=0.0)
				tr.put(b0 + i * 0.5, w)
		# 타악
		if night:
			if style == "gugak" and bar % 2 == 0:
				tr.put(b0, drum_tone(110, 70, 0.25, 0.25))
			continue
		if hunt:
			for e in range(8):
				pos = b0 + e * 0.5
				if style == "chip":
					if e in (0, 4, 5):
						tr.put(pos, chip_kick())
					if e in (2, 6):
						tr.put(pos, chip_noise(0.15, 1.0, 9000, 0.06))
					tr.put(pos, chip_noise(0.04, 0.35, 20000, 0.012))
				elif style == "acoustic":
					if e in (0, 4, 5):
						tr.put(pos, drum_tone(130, 55, 0.12, 1.0))
					if e in (2, 6):
						tr.put(pos, snap(0.9, 900, 4500, 0.07))
					tr.put(pos, shaker(0.8))
				else:
					if e in (0, 3, 4):  # 북
						tr.put(pos, drum_tone(140, 60, 0.18, 1.1, noise_amt=0.4))
					if e in (2, 6, 7):  # 장구 채편 '덕'
						tr.put(pos, mix(snap(0.7, 1500, 6000, 0.04), woodblock(700, 0.4)))
		else:
			if style == "chip":
				tr.put(b0, chip_kick(0.7))
				tr.put(b0 + 2, chip_kick(0.5))
				for e in range(8):
					tr.put(b0 + e * 0.5, chip_noise(0.03, 0.25 if e % 2 else 0.12, 20000, 0.01))
			elif style == "acoustic":
				tr.put(b0, drum_tone(110, 60, 0.12, 0.5))
				for e in range(8):
					tr.put(b0 + e * 0.5, shaker(0.6 if e % 2 else 0.35))
				tr.put(b0 + 3.5, woodblock(1100, 0.4))
			else:  # 장구: 쿵 . 덕 . 쿵 쿵 덕 .
				tr.put(b0, drum_tone(120, 75, 0.15, 0.7))
				tr.put(b0 + 1, mix(snap(0.5, 1500, 6000, 0.035), woodblock(800, 0.3)))
				tr.put(b0 + 2, drum_tone(120, 75, 0.15, 0.55))
				tr.put(b0 + 2.5, drum_tone(120, 75, 0.15, 0.45))
				tr.put(b0 + 3, mix(snap(0.5, 1500, 6000, 0.035), woodblock(800, 0.3)))
	verb = None if style == "chip" else {"sec": 2.2 if night else 1.2, "wet": 0.3 if night else 0.18}
	if style == "chip":
		verb = {"sec": 0.6, "wet": 0.06}
	x = tr.finish(verb)
	if night and style != "chip":
		x += crickets(len(x) / SR, 1.0)
	return x


# ---------------------------------------------------------------- 효과음

def sfx(style, name):
	if name == "hoe":  # 괭이로 흙 파기
		if style == "chip":
			return mix(chip_kick(0.6)[:int(0.12 * SR)], chip_noise(0.18, 1.2, 3000, 0.05))
		n = int(0.35 * SR)
		dirt = lowpass(noise(n), 900) * env_ar(n, 0.002, 0.06) * 1.4
		crumble = bandpass(noise(n), 800, 3000) * env_ar(n, 0.02, 0.09) * 0.35
		thud = drum_tone(150, 70, 0.05, 0.9, 0, 0.35)
		out = mix(dirt, crumble, thud)
		if style == "gugak":
			out = mix(out, woodblock(420, 0.25))
		return out
	if name == "water":  # 물뿌리개
		n = int(0.75 * SR)
		t = np.arange(n) / SR
		if style == "chip":
			out = chip_noise(0.75, 0.5, 14000, 0.3) * (np.sin(2 * np.pi * 14 * t) * 0.3 + 0.7)
			for i, m in enumerate([84, 88, 91, 96]):
				place(out, int(i * 0.07 * SR), chip_square(hz(m), 0.05, 0.3, duty=0.25))
			return out
		hiss = bandpass(noise(n), 2500, 9000) * gate_env(n, 0.05, 0.45, 0.25) * 0.6
		drops = np.zeros(n)
		for _ in range(18):
			at = RNG.integers(0, int(0.6 * SR))
			f = RNG.uniform(1200, 3200)
			m = int(0.04 * SR)
			tt = np.arange(m) / SR
			place(drops, int(at), np.sin(2 * np.pi * (f + 9000 * tt) * tt) * np.exp(-tt * 90) * 0.25)
		return hiss + drops
	if name == "harvest":  # 쑥 뽑기 + 올라가는 음
		out = np.zeros(int(0.6 * SR))
		pop = drum_tone(300, 900, 0.04, 0.7, 0.3, 0.12)
		place(out, 0, pop)
		notes = [74, 78, 81] if style != "gugak" else [74, 76, 81]
		for i, m in enumerate(notes):
			at = int((0.06 + i * 0.07) * SR)
			if style == "chip":
				w = chip_square(hz(m + 12), 0.08, 0.6, duty=0.25)
			elif style == "acoustic":
				w = marimba(hz(m + 12), 0.1, 0.6)
			else:
				w = gayageum(hz(m + 12), 0.1, 0.6, nonghyeon=0)
			place(out, at, w)
		return out
	if name == "coin":  # 공급함 판매 · 구매
		out = np.zeros(int(0.7 * SR))
		for i, m in enumerate([midi("B5"), midi("E6")]):
			at = int(i * 0.08 * SR)
			if style == "chip":
				w = chip_square(hz(m), 0.07 if i == 0 else 0.35, 0.6, duty=0.5)
			else:
				tt = t_axis(0.6)
				w = (np.sin(2 * np.pi * hz(m) * tt) + 0.5 * np.sin(2 * np.pi * hz(m) * 2.76 * tt) + 0.25 * np.sin(2 * np.pi * hz(m) * 5.4 * tt)) * np.exp(-tt * (12 if i == 0 else 5)) * 0.35
				if style == "gugak":
					w = mix(w * 0.7, gayageum(hz(m - 12), 0.2, 0.3, nonghyeon=0))
			place(out, at, w)
		return out
	if name == "hatch":  # 알 깨지기 → 짠
		out = np.zeros(int(1.6 * SR))
		for at in (0.0, 0.18, 0.3):
			c = snap(0.8, 2000, 8000, 0.015)
			i = int(at * SR)
			place(out, i, c)
		pop = drum_tone(200, 600, 0.05, 0.6, 0.4, 0.15)
		i = int(0.45 * SR)
		place(out, i, pop)
		for k, m in enumerate([67, 71, 74, 79, 83, 86]):
			at = int((0.5 + k * 0.06) * SR)
			dur = 0.5 if k == 5 else 0.08
			if style == "chip":
				w = chip_square(hz(m + 12), dur, 0.5, duty=0.25, vib=1.0)
			elif style == "acoustic":
				w = mix(marimba(hz(m + 12), dur, 0.55), ks_pluck(hz(m), dur, 0.2, ring=0.5))
			else:
				w = gayageum(hz(m + 12), dur, 0.55, nonghyeon=1.0 if k == 5 else 0)
			place(out, at, w)
		if style != "chip":
			out = reverb(out, 1.0, 0.25)
		return out
	if name == "hit":  # 내가 때림
		if style == "chip":
			return mix(chip_noise(0.12, 1.4, 6000, 0.04), chip_kick(0.6)[:int(0.12 * SR)])
		n = int(0.2 * SR)
		whack = bandpass(noise(n), 600, 4000) * env_ar(n, 0.001, 0.03) * 1.2
		body = drum_tone(220, 90, 0.05, 0.9, 0, 0.2)
		out = mix(whack, body)
		if style == "gugak":
			out = mix(out, woodblock(600, 0.5))
		return out
	if name == "hurt":  # 내가 맞음
		n = int(0.35 * SR)
		t = np.arange(n) / SR
		fr = 520 * np.exp(-t * 4)
		if style == "chip":
			ph = np.cumsum(fr) / SR % 1.0
			return np.where(ph < 0.5, 1.0, -1.0) * env_ar(n, 0.001, 0.12) * 0.3 + chip_noise(0.35, 0.6, 4000, 0.06)
		buzz = signal.sawtooth(phase_of(fr)) * env_ar(n, 0.002, 0.1) * 0.25
		buzz = lowpass(buzz, 2200)
		thump = drum_tone(140, 60, 0.07, 0.8, 0.4, 0.35)
		return mix(buzz, thump)
	raise KeyError(name)


SFX = ["hoe", "water", "harvest", "coin", "hatch", "hit", "hurt"]
BGM = ["village_day", "village_night", "hunt"]
BGM_RMS = {"village_day": 0.10, "village_night": 0.075, "hunt": 0.12}


def place(out, at, w):
	"""out 의 at 샘플 자리에 w 를 더한다 (넘치면 자른다)."""
	end = min(len(out), at + len(w))
	out[at:end] += w[:end - at]


def mix(*ws):
	out = np.zeros(max(len(w) for w in ws))
	for w in ws:
		out[:len(w)] += w
	return out


def normalize(x, peak=0.89, rms=None):
	"""rms 를 주면 그 크기로 맞추되 peak 를 넘지 않게 한다 (곡끼리 소리 크기 맞추기)."""
	m = np.max(np.abs(x)) + 1e-9
	g = peak / m
	if rms:
		g = min(g, rms / (np.sqrt(np.mean(x ** 2)) + 1e-9))
	return x * g


def fade_tail(x, sec=0.03):
	n = min(len(x), int(sec * SR))
	x = x.copy()
	x[-n:] *= np.linspace(1, 0, n)
	return x


def write(path, x, ogg, loop=False):
	x = np.clip(x, -1, 1)
	pcm = (x * 32767).astype(np.int16)
	wav = path + ".wav"
	from scipy.io import wavfile
	wavfile.write(wav, SR, pcm)
	if ogg:
		q = "4" if loop else "5"
		subprocess.run(["ffmpeg", "-y", "-loglevel", "error", "-i", wav, "-c:a", "libvorbis", "-q:a", q, path + ".ogg"], check=True)
		os.remove(wav)


def build(style, out_dir, ogg, game=False):
	"""game=True 면 게임 폴더 모양 (out_dir/sfx/<이름>.ogg, out_dir/bgm/<이름>.ogg)."""
	sfx_dir = os.path.join(out_dir, "sfx") if game else out_dir
	bgm_dir = os.path.join(out_dir, "bgm") if game else out_dir
	os.makedirs(sfx_dir, exist_ok=True)
	os.makedirs(bgm_dir, exist_ok=True)
	for name in SFX:
		path = os.path.join(sfx_dir, name if game else "sfx_" + name)
		write(path, fade_tail(normalize(sfx(style, name), 0.8, 0.15)), ogg)
	for name in BGM:
		path = os.path.join(bgm_dir, name if game else "bgm_" + name)
		write(path, normalize(arrange(style, name), 0.85, BGM_RMS[name]), ogg, loop=True)


if __name__ == "__main__":
	# 게임에 넣기:   python3 tools/make_sounds.py gugak audio --ogg --game
	# 세 후보 비교:  python3 tools/make_sounds.py all <폴더> --ogg
	style, out = sys.argv[1], sys.argv[2]
	ogg = "--ogg" in sys.argv
	game = "--game" in sys.argv
	for s in (["chip", "acoustic", "gugak"] if style == "all" else [style]):
		build(s, os.path.join(out, s) if style == "all" else out, ogg, game)
		print("made", s)
