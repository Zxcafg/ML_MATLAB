function features = extract_fft_envelope_features(signals, CONFIG)
% EKSTRAKCJA CECH METODĄ 3: ANALIZA FFT Z DEMODULACJĄ OBWIDNI
% 
% Wejście:
%   signals - macierz sygnałów [liczba_sygnałów × SAMPLES_PER_EXP]
%   CONFIG  - struktura konfiguracyjna systemu
%
% Wyjście:
%   features.data  - macierz cech [liczba_sygnałów × liczba_cech]
%   features.names - nazwy cech (cell array)
%
% Opis:
%   Przeprowadzono ekstrakcję cech sygnałów prądowych metodą
%   analizy FFT z demodulacją obwiedni (envelope analysis).
%   Wyekstrahowano cechy dla każdego z 6 pasm częstotliwościowych.
%   Dla każdego pasma obliczono 16 cech, co daje łącznie 96 cech.
%
% Źródło algorytmów:
%   Algorytmy ekstrakcji cech zostały wygenerowane przez
%   MATLAB Diagnostic Feature Designer zgodnie z metodologią
%   określoną w pracy dyplomowej.
%
% Metodyka:
%   Dla każdego sygnału:
%   1. Obliczono widmo FFT z oknem Hanninga
%   2. Dla każdego z 6 pasm częstotliwości:
%      a. Obliczono energię widmową w paśmie
%      b. Wyszukano 3 dominujące częstotliwości w widmie FFT
%      c. Przefiltrowano sygnał filtrem pasmowym
%      d. Obliczono wartość skuteczną i maksymalną przefiltrowanego sygnału
%      e. Wykonano demodulację obwiedni transformatą Hilberta
%      f. Obliczono widmo obwiedni (envelope spectrum)
%      g. Obliczono energię widma obwiedni
%      h. Wyszukano 3 dominujące częstotliwości w widmie obwiedni
%
% Pasma częstotliwości:
%   1. 100-500 Hz
%   2. 500-2000 Hz
%   3. 2000-5000 Hz
%   4. 5000-10000 Hz
%   5. 10000-15000 Hz
%   6. 15000-20000 Hz

    Fs = CONFIG.Fs;
    freq_bands = CONFIG.freq_bands;
    num_signals = size(signals, 1);
    num_bands = size(freq_bands, 1);
    
    % Określono liczbę cech:
    % Dla każdego pasma obliczono 16 cech:
    % - Energia widma FFT: 1 cecha
    % - 3 dominujące częstotliwości FFT: 3 cechy
    % - 3 amplitudy dla częstotliwości FFT: 3 cechy
    % - Energia widma obwiedni: 1 cecha
    % - 3 dominujące częstotliwości obwiedni: 3 cechy
    % - 3 amplitudy dla częstotliwości obwiedni: 3 cechy
    % - Wartość skuteczna przefiltrowanego sygnału: 1 cecha
    % - Wartość maksymalna przefiltrowanego sygnału: 1 cecha
    % Razem na pasmo: 1+3+3+1+3+3+1+1 = 16 cech
    % Dla 6 pasm: 16 × 6 = 96 cech
    
    features_per_band = 16;
    num_features = features_per_band * num_bands;
    
    feature_matrix = zeros(num_signals, num_features);
    
    fprintf('   Rozpoczęto ekstrakcję cech FFT z demodulacją obwiedni dla %d sygnałów\n', num_signals);
    
    for sig_idx = 1:num_signals
        if mod(sig_idx, 100) == 0
            fprintf('     Postęp przetwarzania: %d/%d sygnałów\n', sig_idx, num_signals);
        end
        
        signal = signals(sig_idx, :)';
        N = length(signal);
        
        % Obliczono widmo FFT całego sygnału (referencyjne)
        signal_windowed = signal .* hann(N);
        Y = fft(signal_windowed);
        P2 = abs(Y/N);
        P1 = P2(1:floor(N/2)+1);
        P1(2:end-1) = 2*P1(2:end-1);
        f_fft = Fs*(0:(length(P1)-1))/N;
        
        feat_idx = 1;
        
        %% PRZETWARZANIE DLA KAŻDEGO Z 6 PASM CZĘSTOTLIWOŚCIOWYCH
        for band_idx = 1:num_bands
            f_low = freq_bands(band_idx, 1);
            f_high = freq_bands(band_idx, 2);
            
            % Dostosowano górną granicę pasma do częstotliwości Nyquista
            f_high = min(f_high, Fs/2 * 0.95);
            
            %% 1. ENERGIA WIDMOWA W PAŚMIE (ANALIZA FFT)
            band_mask = (f_fft >= f_low) & (f_fft <= f_high);
            P1_band = P1(band_mask);
            f_band = f_fft(band_mask);
            
            band_energy = sum(P1_band.^2);
            feature_matrix(sig_idx, feat_idx) = band_energy;
            feat_idx = feat_idx + 1;
            
            %% 2. DOMINUJĄCE CZĘSTOTLIWOŚCI W PAŚMIE (FFT)
            if ~isempty(P1_band) && length(P1_band) > 3
                % Wyszukano 3 największe piki w widmie FFT
                [pks, locs] = findpeaks(P1_band, 'SortStr', 'descend', 'NPeaks', 3);
                
                for peak_idx = 1:3
                    if peak_idx <= length(locs)
                        % Zapisz częstotliwość piku
                        feature_matrix(sig_idx, feat_idx) = f_band(locs(peak_idx));
                        feat_idx = feat_idx + 1;
                        % Zapisz amplitudę piku
                        feature_matrix(sig_idx, feat_idx) = pks(peak_idx);
                        feat_idx = feat_idx + 1;
                    else
                        % Brak piku - wypełnij zerami
                        feature_matrix(sig_idx, feat_idx) = 0;
                        feat_idx = feat_idx + 1;
                        feature_matrix(sig_idx, feat_idx) = 0;
                        feat_idx = feat_idx + 1;
                    end
                end
            else
                % Brak wystarczających danych w paśmie
                for peak_idx = 1:3
                    feature_matrix(sig_idx, feat_idx) = 0;
                    feat_idx = feat_idx + 1;
                    feature_matrix(sig_idx, feat_idx) = 0;
                    feat_idx = feat_idx + 1;
                end
            end
            
            %% 3. FILTROWANIE PASMOWE + PARAMETRY CZASOWE
            try
                if f_low < 50
                    % Dla niskich częstotliwości zastosowano filtr dolnoprzepustowy
                    [b, a] = butter(4, f_high/(Fs/2), 'low');
                else
                    % Standardowy filtr pasmowy Butterwortha 4-go rzędu
                    [b, a] = butter(4, [f_low f_high]/(Fs/2), 'bandpass');
                end
                signal_filtered = filtfilt(b, a, signal);
            catch
                % W przypadku błędu filtracji użyto sygnału oryginalnego
                signal_filtered = signal;
            end
            
            % Wartość skuteczna (RMS) przefiltrowanego sygnału
            feature_matrix(sig_idx, feat_idx) = rms(signal_filtered);
            feat_idx = feat_idx + 1;
            
            % Wartość maksymalna przefiltrowanego sygnału
            feature_matrix(sig_idx, feat_idx) = max(abs(signal_filtered));
            feat_idx = feat_idx + 1;
            
            %% 4. DEMODULACJA OBWIDNI (ENVELOPE) TRANSFORMATĄ HILBERTA
            envelope = abs(hilbert(signal_filtered));
            
            % Obliczono widmo obwiedni
            N_env = length(envelope);
            envelope_windowed = envelope .* hann(N_env);
            Y_env = fft(envelope_windowed);
            P2_env = abs(Y_env/N_env);
            P1_env = P2_env(1:floor(N_env/2)+1);
            P1_env(2:end-1) = 2*P1_env(2:end-1);
            f_env = Fs*(0:(length(P1_env)-1))/N_env;
            
            % Ograniczono analizę widma obwiedni do zakresu 0-500 Hz
            env_freq_mask = f_env <= 500;
            P1_env_limited = P1_env(env_freq_mask);
            f_env_limited = f_env(env_freq_mask);
            
            % Energia widma obwiedni
            env_energy = sum(P1_env_limited.^2);
            feature_matrix(sig_idx, feat_idx) = env_energy;
            feat_idx = feat_idx + 1;
            
            %% 5. DOMINUJĄCE CZĘSTOTLIWOŚCI W WIDMIE OBWIDNI
            if ~isempty(P1_env_limited) && length(P1_env_limited) > 3
                % Wyszukano 3 największe piki w widmie obwiedni
                [pks_env, locs_env] = findpeaks(P1_env_limited, 'SortStr', 'descend', 'NPeaks', 3);
                
                for peak_idx = 1:3
                    if peak_idx <= length(locs_env)
                        % Zapisz częstotliwość piku obwiedni
                        feature_matrix(sig_idx, feat_idx) = f_env_limited(locs_env(peak_idx));
                        feat_idx = feat_idx + 1;
                        % Zapisz amplitudę piku obwiedni
                        feature_matrix(sig_idx, feat_idx) = pks_env(peak_idx);
                        feat_idx = feat_idx + 1;
                    else
                        % Brak piku - wypełnij zerami
                        feature_matrix(sig_idx, feat_idx) = 0;
                        feat_idx = feat_idx + 1;
                        feature_matrix(sig_idx, feat_idx) = 0;
                        feat_idx = feat_idx + 1;
                    end
                end
            else
                % Brak wystarczających danych w widmie obwiedni
                for peak_idx = 1:3
                    feature_matrix(sig_idx, feat_idx) = 0;
                    feat_idx = feat_idx + 1;
                    feature_matrix(sig_idx, feat_idx) = 0;
                    feat_idx = feat_idx + 1;
                end
            end
        end
    end
    
    %% NAZWY CECH
    % Zdefiniowano nazwy dla wszystkich 96 cech
    feature_names = {};
    
    for band_idx = 1:num_bands
        f_low = freq_bands(band_idx, 1);
        f_high = freq_bands(band_idx, 2);
        band_name = sprintf('Band_%d_%d', f_low, f_high);
        
        % Cechy z analizy FFT
        feature_names{end+1} = [band_name '_FFT_Energy'];
        
        % Cechy dla 3 dominujących częstotliwości FFT
        for peak_idx = 1:3
            feature_names{end+1} = sprintf('%s_FFT_Freq%d', band_name, peak_idx);
            feature_names{end+1} = sprintf('%s_FFT_Amp%d', band_name, peak_idx);
        end
        
        % Cechy czasowe przefiltrowanego sygnału
        feature_names{end+1} = [band_name '_RMS'];
        feature_names{end+1} = [band_name '_Peak'];
        
        % Cechy z analizy obwiedni
        feature_names{end+1} = [band_name '_Env_Energy'];
        
        % Cechy dla 3 dominujących częstotliwości obwiedni
        for peak_idx = 1:3
            feature_names{end+1} = sprintf('%s_Env_Freq%d', band_name, peak_idx);
            feature_names{end+1} = sprintf('%s_Env_Amp%d', band_name, peak_idx);
        end
    end
    
    % Zwrócono strukturę z cechami
    features = struct();
    features.data = feature_matrix;
    features.names = feature_names;
    
    fprintf('   Zakończono ekstrakcję cech: %d cech FFT z demodulacją obwiedni\n', num_features);
end