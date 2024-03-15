#!/usr/bin/env python3

import numpy as np
import pyaudio
from scipy.interpolate import CubicSpline
from scipy.signal import firwin, filtfilt

SAMPLE_COUNT = 1024
SAMPLE_RATE = 48000
MAX_DELAY = 32
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

# Generate correlation independent vars
#period_swing_ms = 1000*MAX_DELAY/SAMPLE_RATE
period_swing_ms = MAX_DELAY # Track samples
corr_xi = np.linspace(-period_swing_ms, period_swing_ms, num=(2*MAX_DELAY + 1))
# Generate bandpass filter for vocal range: 200 - 1000 Hz
voice_filter_b = firwin(16, [200, 1000], pass_zero=False, fs=SAMPLE_RATE)
voice_filter_a = [1] # FIR filter has unity for denominator

while True:
    # Discard samples immediately after initialization; the mics need some amount
    # of time to stabilize
    stream.start_stream()
    stream.read(SAMPLE_RATE // 16)
    bin = stream.read(SAMPLE_COUNT)
    # Stop stream to avoid overruns. We don't care about any data we might miss
    stream.stop_stream()

    data = np.frombuffer(bin, dtype=np.int32)
    mat = np.reshape(data, newshape=(8, SAMPLE_COUNT), order='F')
    # Delete the unused channel
    mat = np.delete(mat, [3], axis=0)

    # Top bit is suspect, possibly because of long cables
    mat = mat << 1
    # Bottom 8 bits are garbage
    mat = mat >> 9

    # Subtract DC offset. This should also be done by the bandpass filter, but
    # explicitly taking out the DC offset makes plotting intermediate results
    # much easier.
    mat_win = mat - mat.mean(axis=1, keepdims=True)

    # Filter
    mat_filt = np.array([filtfilt(voice_filter_b, voice_filter_a, x) for x in mat_win])

    # Normalize to reference. This way we keep channel power relative. If one mic
    # has very low signal, we want that to be apparent from the cross-correlations.
    ref_pwr_sq = np.square(mat_filt[REF_CHANNEL]).sum()
    # Compute the average per-sample RMS power. This value is invariant to the number
    # of samples acquired.
    ref_pwr_norm = np.sqrt(ref_pwr_sq/SAMPLE_COUNT)
    if ref_pwr_norm < 10000:
        # Less than about 10k the signal is too quiet. Indoor speaking voice is 3-10x
        # this threshold.
        continue
    # We normalize the total power here because we want the maximum cross-correlation
    # to be approximately 1.0. 
    mat_filt = mat_filt / np.sqrt(ref_pwr_sq)

    # Pad the reference waveform and use the `valid` cross-correlation mode so we
    # compute only the correlation for the number of samples we pad. This cuts down
    # on the number of computations.
    reference = np.pad(mat_filt[REF_CHANNEL], (MAX_DELAY, MAX_DELAY))
    cross_corr = np.array([ np.correlate(reference, x, mode='valid') for x in mat_filt ])

    # Interpolate the cross-correlations and find the maximum. The scipy interpolation
    # works by creating piecewise polynomials, so there is no interpolation factor.
    # Instead we find the roots of the derivatrive piecewise polynomials to find the
    # maximum. The cubic interpolation is guaranteed to be twice continuously
    # differentiable so we should not get spurious extrema.
    cross_corr_interp = [ CubicSpline(corr_xi, x) for x in cross_corr ]
    cross_corr_interp_dx = [ x.derivative() for x in cross_corr_interp ]
    extrema = [ x.solve() for x in cross_corr_interp_dx ]
    # If no extrema exist we don't have a local max in the cross-correlation
    # which means we need to check samples further away or we are seeing a frequency
    # below what we expect. The second case is typically taken care of by the bandpass
    # filter.
    if any([len(x) == 0 for x in extrema]):
        print("No extrema found")
        np.savetxt("wfm.csv", np.transpose(mat))
        np.savetxt("normalized_wfm.csv", np.transpose(mat_win))
        np.savetxt("filtered_wfm.csv", np.transpose(mat_filt))
        np.savetxt("cross_corr.csv", np.transpose(cross_corr))
        continue

    # Locate the extrema closest to zero sample offset.
    offset_idx = [ np.argmin(abs(x)) for x in extrema ]
    # Retrieve the actual offset, including the sign of the offset.
    offset = np.array([ x[i] for x, i in zip(extrema, offset_idx) ])
    # Calculate the (approximate) cross-correlation at this fractional offset.
    power = np.array([ x(i) for x, i in zip(cross_corr_interp, offset)])

    if any(power < -0.8):
        # If we are dealing with high frequencies and significant phase delay, the
        # closest extrema may be a minimum instead of a maximum. Doing something
        # more robust to find the maximum may be warranted if this is common.
        print("Power less than zero, found minimum instead of maximum")
        with open("raw.bin", "wb") as raw:
            raw.write(bin)
        np.savetxt("wfm.csv", np.transpose(mat))
        np.savetxt("normalized_wfm.csv", np.transpose(mat_win))
        np.savetxt("filtered_wfm.csv", np.transpose(mat_filt))
        np.savetxt("cross_corr.csv", np.transpose(cross_corr))
        continue

    # Empirically a cross-correlation of greater than 0.9 for all channels seems
    # to be a decent indicator of good SNR. Note that the cross-correlation may
    # be greater than 1 if the channel is a higher magnitude than the reference.
    if all(power > 0.9):
        print(f"off: {offset}")
        print(f"pow: {power}")

stream.close()
