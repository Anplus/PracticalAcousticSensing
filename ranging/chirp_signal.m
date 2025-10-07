clc;clear;close all;
%% Params
fs    = 44100;          % sampling rate (Hz)
f0    = 10000;          % start freq (Hz)
f1    = 20000;          % end freq (Hz)
slope = 100000;         % sweep rate (Hz/s) = 100 kHz/s
T     = (f1 - f0) / slope;  % chirp duration (s) -> 0.1 s
silence_ms = 100;       % trailing silence (ms)

%% Time vectors
t_chirp   = 0:1/fs:(T - 1/fs);
t_silence = zeros(round(silence_ms/1000 * fs), 1);  % 100 ms of silence

%% Generate linear chirp (10 kHz -> 20 kHz in 0.1 s)
x = chirp(t_chirp, f0, T, f1, 'linear', 0);

% Optional: fade in/out 5 ms to avoid clicks at boundaries
fade = round(0.005 * fs);
win  = ones(size(x));
win(1:fade)              = linspace(0,1,fade);
win(end-fade+1:end)      = linspace(1,0,fade);
x = x .* win;

%% Concatenate chirp + silence
y = [x(:); t_silence];

%% Write to WAV (16-bit PCM)
audiowrite('chirp_10k_to_20k_100ksps_44k1.wav', y, fs, 'BitsPerSample', 16);

%% (Optional) quick plot & listen
figure; spectrogram(y, 1024, 768, 2048, fs, 'yaxis'); title('Chirp Spectrogram');
sound(y, fs);