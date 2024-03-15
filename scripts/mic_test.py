#!/usr/bin/env python3

import numpy as np
import pyaudio
from scipy.interpolate import CubicSpline

SAMPLE_COUNT = 128
SAMPLE_RATE = 96000
MAX_DELAY = 16
REF_CHANNEL = 6

np.set_printoptions(threshold=np.inf, precision=3, floatmode='fixed', sign=' ', suppress=True)

p = pyaudio.PyAudio()

info = p.get_device_info_by_index(0)
for k, v in info.items():
    print(f"{k}: {v}")

stream = p.open(
    rate = SAMPLE_RATE,
    channels = 8,
    format = pyaudio.paInt32,
    input = True,
    start = False,
    input_device_index=0)

# Generate window
win = np.blackman(SAMPLE_COUNT)
# Generate correlation independent vars
#period_swing_ms = 1000*MAX_DELAY/SAMPLE_RATE
period_swing_ms = MAX_DELAY # Track samples
corr_xi = np.linspace(-period_swing_ms, period_swing_ms, num=(2*MAX_DELAY + 1))

while True:
    # Discard samples immediately after initialization
    stream.start_stream()
    stream.read(SAMPLE_RATE//16)
    bin = stream.read(SAMPLE_COUNT)
    stream.stop_stream()

    data = np.frombuffer(bin, dtype=np.int32)
    mat = np.reshape(data, newshape=(8, SAMPLE_COUNT), order='F')
    # Delete the unused channel
    mat = np.delete(mat, [3], axis=0)

    # Top bit is suspect, possibly because of long cables
    mat = mat << 1
    # Bottom 8 bits are garbage
    mat = mat >> 9

    #print(mat)

    win_mat = mat #* win

    # Subtract DC offset
    win_mat = win_mat - win_mat.mean(axis=1, keepdims=True)
    # Normalize
    pwrs = np.sqrt(np.square(win_mat).sum(axis=1, keepdims=True))
    #print(pwrs)
    if np.min(pwrs) < 10000:
        # Too quiet to read anything, discard and continue
        continue

    win_mat = win_mat / pwrs
    #print(win_mat)
    #break

    reference = np.pad(win_mat[REF_CHANNEL], (MAX_DELAY, MAX_DELAY))

    cross_corr = np.array([ np.correlate(reference, x, mode='valid') for x in win_mat ])

    #print(np.shape(cross_corr))
    #print(cross_corr)
    #np.savetxt("cross.csv", np.transpose(cross_corr))

    cross_corr_interp = [ CubicSpline(corr_xi, x) for x in cross_corr ]
    cross_corr_interp_dx = [ x.derivative() for x in cross_corr_interp ]
    extrema = [ x.solve() for x in cross_corr_interp_dx ]
    # If no extrema exist we don't have a local max in the cross-correlation
    # which means we need to check samples further away or something else is wrong.
    #print(extrema)
    if any([len(x) == 0 for x in extrema]):
        print("No extrema found")
        np.savetxt("wfm.csv", np.transpose(mat))
        np.savetxt("normalized_wfm.csv", np.transpose(win_mat))
        np.savetxt("cross_corr.csv", np.transpose(cross_corr))
        continue

    offset_idx = [ np.argmin(abs(x)) for x in extrema ]
    offset = np.array([ x[i] for x, i in zip(extrema, offset_idx) ])
    power = np.array([ x(i) for x, i in zip(cross_corr_interp, offset)])

    if any(power < -0.8):
        print("Power less than zero, found minimum instead of maximum")
        with open("raw.bin", "wb") as raw:
            raw.write(bin)
        np.savetxt("wfm.csv", np.transpose(mat))
        np.savetxt("normalized_wfm.csv", np.transpose(win_mat))
        np.savetxt("cross_corr.csv", np.transpose(cross_corr))
        continue

    if all(power > 0.9):
        print(f"off: {offset}")
        print(f"pow: {power}")

stream.close()
