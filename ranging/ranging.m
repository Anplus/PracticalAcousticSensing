clc;clear;close all;
%%
%% === Inputs you may change ===
wav_file = 'recording2.wav';   % your long 2-ch recording (two mics)
fs       = 44100;                  % Hz
f0       = 10000;                  % chirp start freq (Hz)
f1       = 20000;                  % chirp end freq (Hz)
slope    = 100000;                 % Hz/s  (=> T_chirp = 0.1 s)
c_sound  = 343;                    % m/s (≈ 20°C). Use 331+0.6*T_C if desired.

% Detection & reflection search parameters
guard_ms_after_direct = 1.5;       % skip first 1.5 ms after direct (sidelobes)
max_reflection_ms     = 20;        % only search reflections up to 20 ms after direct (~3.4 m)
min_peak_prom_rel     = 0.35;      % relative to robust scale of MF envelope
min_inter_chirp_ms    = 150;       % minimum spacing between chirps (ms), 0.1s chirp + 0.1s silence -> 200ms typical
                                   % but we allow 150ms to be tolerant

%% === Derived ===
T_chirp = (f1 - f0)/slope;         % 0.1 s
guard_s = guard_ms_after_direct/1000;
max_s   = max_reflection_ms/1000;

%% === Build reference chirp used during playback ===
t_ref     = 0:1/fs:(T_chirp - 1/fs);
ref_chirp = chirp(t_ref, f0, T_chirp, f1, 'linear', 0);
h         = flipud(ref_chirp(:));          % matched filter kernel (time-reversed)

%% === Load long recording ===
[x, fs_read] = audioread(wav_file);
if fs_read ~= fs
    error('Recording fs (%d) != expected fs (%d). Resample or update fs.', fs_read, fs);
end
assert(size(x,2) >= 2, 'Expect a two-channel recording (two mics).');

%% === Matched filter (per channel) ===
y1 = conv(x(:,1), h, 'same');
y2 = conv(x(:,2), h, 'same');

env1 = abs(y1);
env2 = abs(y2);

%% === Detect each chirp using channel 1 envelope ===
% Robust thresholding using median absolute deviation (MAD-like)
scale = median(abs(env1 - median(env1))) * 1.4826;
prom_thresh = min_peak_prom_rel * max(scale, eps);

[pk, loc] = findpeaks(env1, ...
    'MinPeakDistance', round(fs * (min_inter_chirp_ms/1000)), ...
    'MinPeakProminence', prom_thresh);

t_direct_all = (loc - 1)/fs;  % time of direct arrivals (one per chirp)

%% === For each detected chirp, find strongest reflection AFTER a guard ===
N = numel(loc);
dt1 = nan(N,1); dt2 = nan(N,1);      % excess delays per chirp (mic1, mic2)
idx_r1 = nan(N,1); idx_r2 = nan(N,1);

for k = 1:N
    i0 = loc(k);  % index of direct arrival

    % Mic 1
    i_start = i0 + ceil(guard_s * fs);
    i_end   = min(length(env1), i0 + ceil(max_s * fs));
    if i_start < i_end
        seg = env1(i_start:i_end);
        [pks, locs, ~, prom] = findpeaks(seg);
        if ~isempty(pks)
            % Keep peaks with reasonable prominence vs local stats
            if any(prom >= prom_thresh)
                [~, kk] = max(pks);       % strongest in the window
                idx_r1(k) = i_start + locs(kk) - 1;
                dt1(k)    = (idx_r1(k) - i0)/fs;
            end
        end
    end

    % Mic 2
    i_start = i0 + ceil(guard_s * fs);
    i_end   = min(length(env2), i0 + ceil(max_s * fs));
    if i_start < i_end
        seg = env2(i_start:i_end);
        [pks, locs, ~, prom] = findpeaks(seg);
        if ~isempty(pks)
            if any(prom >= prom_thresh)
                [~, kk] = max(pks);
                idx_r2(k) = i_start + locs(kk) - 1;
                dt2(k)    = (idx_r2(k) - i0)/fs;
            end
        end
    end
end

%% === Convert delays to range (monostatic approximation) ===
range1 = (c_sound .* dt1)/2;   % meters
range2 = (c_sound .* dt2)/2;   % meters

%% === Basic outlier cleanup (optional but helpful) ===
% Physically plausible window (0–3.4 m for 20 ms). Tighten if needed.
valid1 = ~isnan(range1) & range1 >= 0 & range1 <= (c_sound*max_s/2);
valid2 = ~isnan(range2) & range2 >= 0 & range2 <= (c_sound*max_s/2);
range1(~valid1) = NaN;
range2(~valid2) = NaN;

%% === Plot: Range over time ===
figure;
plot(t_direct_all, range1, '.-','LineWidth',3); hold on;
plot(t_direct_all, range2, '-x','LineWidth',2);
xlabel('Time (s)'); ylabel('Range (m)');
title('Reflection range vs. time (per chirp)');
legend('Mic 1','Mic 2','Location','best'); grid on;

%% === (Optional) Show a small snippet of matched-filter trace with markers ===
if ~isempty(loc)
    w = round(0.6 * fs);                % ~0.6 s window around first chirp
    a = max(1, loc(1)-w);
    b = min(length(env1), loc(1)+w);
    tt = (a:b)/fs;

    figure;
    subplot(2,1,1);
    plot(tt, env1(a:b)); hold on; grid on;
    yl = ylim;
    xline((loc(1)-1)/fs, '--');
    if ~isnan(idx_r1(1)), xline((idx_r1(1)-1)/fs, '--'); end
    ylim(yl);
    title('Matched-filter envelope (Mic 1) with direct/reflection markers');
    xlabel('Time (s)'); ylabel('|y1|');

    subplot(2,1,2);
    plot(tt, env2(a:b)); hold on; grid on;
    yl = ylim;
    xline((loc(1)-1)/fs, '--');
    if ~isnan(idx_r2(1)), xline((idx_r2(1)-1)/fs, '--'); end
    ylim(yl);
    title('Matched-filter envelope (Mic 2) with direct/reflection markers');
    xlabel('Time (s)'); ylabel('|y2|');
end

%% === Notes ===
% - We detect each chirp by the strong matched-filter peak of the direct path.
% - For each chirp, we search a short window after the direct for the strongest
%   reflection and convert the excess delay to range via R ≈ c*Δt/2.
% - Tweak guard_ms_after_direct, max_reflection_ms, and min_peak_prom_rel to fit
%   your space and SNR. If your repetition period differs from 0.2 s, adjust
%   min_inter_chirp_ms accordingly (or increase it until you get one direct peak per chirp).