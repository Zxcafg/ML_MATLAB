function features = extract_time_domain_features(signals, CONFIG)
% EKSTRAKCJA CECH METODĄ 1: ANALIZA CZASOWA Z FILTROWANIEM PASMOWYM
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
%   Przeprowadzono ekstrakcję cech sygnałów prądowych metodą analizy
%   czasowej z filtrowaniem pasmowym. Wyekstrahowano łącznie 49 cech
%   pogrupowanych w cztery kategorie:
%   1. Podstawowe cechy statystyczne (8 cech)
%   2. Cechy spektralne (2 cechy)
%   3. Amplitudy harmonicznych (3 cechy)
%   4. Cechy z 6 pasm częstotliwościowych (36 cech)
%
% Źródło algorytmów:
%   Algorytmy ekstrakcji cech zostały wygenerowane przez
%   MATLAB Diagnostic Feature Designer na podstawie konfiguracji
%   określonej w pracy dyplomowej.
%
% Metodyka:
%   Dla każdego sygnału obliczono:
%   - Statystyki czasowe (średnia, odchylenie standardowe, etc.)
%   - Parametry widmowe (centrum częstotliwościowe, pole widma)
%   - Amplitudy trzech pierwszych harmonicznych
%   - Cechy z sygnałów przefiltrowanych w 6 zakresach częstotliwości
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
    
    % Określono liczbę cech:
    % Podstawowe cechy czasowe: 8
    % Cechy spektralne: 2
    % Harmoniczne: 3
    % Cechy z 6 pasm: 6 cech/pasmo × 6 pasm = 36
    % Razem: 8 + 2 + 3 + 36 = 49 cech
    
    num_features = 8 + 2 + 3 + (6 * size(freq_bands, 1));
    feature_matrix = zeros(num_signals, num_features);
    
    fprintf('   Rozpoczęto ekstrakcję cech czasowych dla %d sygnałów\n', num_signals);
    
    for sig_idx = 1:num_signals
        if mod(sig_idx, 100) == 0
            fprintf('     Postęp przetwarzania: %d/%d sygnałów\n', sig_idx, num_signals);
        end
        
        signal = signals(sig_idx, :)';
        feat_idx = 1;
        
        %% PODSTAWOWE CECHY STATYSTYCZNE CZASOWE
        % 1. Wartość średnia sygnału
        feature_matrix(sig_idx, feat_idx) = mean(signal);
        feat_idx = feat_idx + 1;
        
        % 2. Odchylenie standardowe sygnału
        feature_matrix(sig_idx, feat_idx) = std(signal);
        feat_idx = feat_idx + 1;
        
        % 3. Wartość maksymalna sygnału
        feature_matrix(sig_idx, feat_idx) = max(signal);
        feat_idx = feat_idx + 1;
        
        % 4. Wartość skuteczna (RMS)
        feature_matrix(sig_idx, feat_idx) = rms(signal);
        feat_idx = feat_idx + 1;
        
        % 5. Amplituda międzyszczytowa (peak-to-peak)
        feature_matrix(sig_idx, feat_idx) = max(signal) - min(signal);
        feat_idx = feat_idx + 1;
        
        % 6. Skośność rozkładu wartości sygnału
        feature_matrix(sig_idx, feat_idx) = skewness(signal);
        feat_idx = feat_idx + 1;
        
        % 7. Kurtoza rozkładu wartości sygnału
        feature_matrix(sig_idx, feat_idx) = kurtosis(signal);
        feat_idx = feat_idx + 1;
        
        % 8. Współczynnik szczytowości (crest factor)
        rms_val = rms(signal);
        if rms_val > 0
            feature_matrix(sig_idx, feat_idx) = max(abs(signal)) / rms_val;
        else
            feature_matrix(sig_idx, feat_idx) = 0;
        end
        feat_idx = feat_idx + 1;
        
        %% CECHY SPEKTRALNE (ANALIZA FFT)
        % Obliczono widmo sygnału z oknem Hanninga
        N = length(signal);
        signal_windowed = signal .* hann(N);
        Y = fft(signal_windowed);
        P2 = abs(Y/N);
        P1 = P2(1:floor(N/2)+1);
        P1(2:end-1) = 2*P1(2:end-1);
        f_fft = Fs*(0:(length(P1)-1))/N;
        
        % 9. Centrum częstotliwościowe (częstotliwość średnia ważona amplitudą)
        freq_center = sum(f_fft' .* P1) / sum(P1);
        feature_matrix(sig_idx, feat_idx) = freq_center;
        feat_idx = feat_idx + 1;
        
        % 10. Pole widma (całkowita moc widmowa)
        spectrum_area = sum(P1.^2);
        feature_matrix(sig_idx, feat_idx) = spectrum_area;
        feat_idx = feat_idx + 1;
        
        %% AMPLITUDY HARMONICZNYCH
        % Wyznaczono częstotliwość podstawową z zakresu poniżej 500 Hz
        low_freq_mask = f_fft < 500;
        [~, max_idx] = max(P1(low_freq_mask));
        f_fft_low = f_fft(low_freq_mask);
        fundamental_freq = f_fft_low(max_idx);
        
        % 11. Amplituda pierwszej harmonicznej (1×RPM)
        [amp_1x, ~] = find_amplitude_at_freq(P1, f_fft, fundamental_freq, 5);
        feature_matrix(sig_idx, feat_idx) = amp_1x;
        feat_idx = feat_idx + 1;
        
        % 12. Amplituda drugiej harmonicznej (2×RPM)
        [amp_2x, ~] = find_amplitude_at_freq(P1, f_fft, 2*fundamental_freq, 10);
        feature_matrix(sig_idx, feat_idx) = amp_2x;
        feat_idx = feat_idx + 1;
        
        % 13. Amplituda trzeciej harmonicznej (3×RPM)
        [amp_3x, ~] = find_amplitude_at_freq(P1, f_fft, 3*fundamental_freq, 15);
        feature_matrix(sig_idx, feat_idx) = amp_3x;
        feat_idx = feat_idx + 1;
        
        %% CECHY Z PASM CZĘSTOTLIWOŚCIOWYCH
        % Przetworzono sygnał w każdym z 6 zdefiniowanych pasm
        for band_idx = 1:size(freq_bands, 1)
            f_low = freq_bands(band_idx, 1);
            f_high = freq_bands(band_idx, 2);
            
            % Dostosowano górną granicę pasma do częstotliwości Nyquista
            f_high = min(f_high, Fs/2 * 0.95);
            
            % Zastosowano filtr pasmowy Butterwortha 4-go rzędu
            try
                [b, a] = butter(4, [f_low f_high]/(Fs/2), 'bandpass');
                signal_filtered = filtfilt(b, a, signal);
            catch
                % W przypadku błędu filtracji użyto sygnału oryginalnego
                signal_filtered = signal;
            end
            
            % Wyekstrahowano 6 cech z przefiltrowanego sygnału:
            % 1. Wartość skuteczna (RMS)
            feature_matrix(sig_idx, feat_idx) = rms(signal_filtered);
            feat_idx = feat_idx + 1;
            
            % 2. Wartość maksymalna
            feature_matrix(sig_idx, feat_idx) = max(abs(signal_filtered));
            feat_idx = feat_idx + 1;
            
            % 3. Odchylenie standardowe
            feature_matrix(sig_idx, feat_idx) = std(signal_filtered);
            feat_idx = feat_idx + 1;
            
            % 4. Kurtoza
            if std(signal_filtered) > 0
                feature_matrix(sig_idx, feat_idx) = kurtosis(signal_filtered);
            else
                feature_matrix(sig_idx, feat_idx) = 0;
            end
            feat_idx = feat_idx + 1;
            
            % 5. Współczynnik szczytowości
            rms_filt = rms(signal_filtered);
            if rms_filt > 0
                feature_matrix(sig_idx, feat_idx) = max(abs(signal_filtered)) / rms_filt;
            else
                feature_matrix(sig_idx, feat_idx) = 0;
            end
            feat_idx = feat_idx + 1;
            
            % 6. Energia sygnału (suma kwadratów)
            feature_matrix(sig_idx, feat_idx) = sum(signal_filtered.^2);
            feat_idx = feat_idx + 1;
        end
    end
    
    %% NAZWY CECH
    % Zdefiniowano nazwy dla wszystkich 49 cech
    feature_names = {
        'Current_mean', 'Current_std', 'Current_max', 'Current_rms', ...
        'Current_peak_to_peak', 'Current_skew', 'Current_kurtosis', 'Current_crest_factor', ...
        'Current_Frequency_Center', 'Current_Spectrum_Area', ...
        'Current_Amp_1x_RPM', 'Current_Amp_2x_RPM', 'Current_Amp_3x_RPM'
    };
    
    % Dodano nazwy cech dla każdego pasma częstotliwościowego
    for band_idx = 1:size(freq_bands, 1)
        f_low = freq_bands(band_idx, 1);
        f_high = freq_bands(band_idx, 2);
        band_name = sprintf('Band_%d_%d', f_low, f_high);
        
        feature_names{end+1} = [band_name '_RMS'];
        feature_names{end+1} = [band_name '_Max'];
        feature_names{end+1} = [band_name '_Std'];
        feature_names{end+1} = [band_name '_Kurtosis'];
        feature_names{end+1} = [band_name '_Crest'];
        feature_names{end+1} = [band_name '_Energy'];
    end
    
    % Zwrócono strukturę z cechami
    features = struct();
    features.data = feature_matrix;
    features.names = feature_names;
    
    fprintf('   Zakończono ekstrakcję cech: %d cech dla %d sygnałów\n', num_features, num_signals);
end

function [amplitude, freq_found] = find_amplitude_at_freq(spectrum, freq_vec, target_freq, tolerance_hz)
% WYSZUKIWANIE AMPLITUDY W OKOLICY OKREŚLONEJ CZĘSTOTLIWOŚCI
%
% Wejście:
%   spectrum     - wektor widma amplitudowego
%   freq_vec     - wektor częstotliwości odpowiadający widmu
%   target_freq  - poszukiwana częstotliwość [Hz]
%   tolerance_hz - tolerancja wyszukiwania [Hz]
%
% Wyjście:
%   amplitude   - amplituda w okolicy target_freq
%   freq_found  - częstotliwość przy której znaleziono maksimum
%
% Opis:
%   Wyszukano maksymalną amplitudę w widmie w zakresie
%   target_freq ± tolerance_hz. Jeśli w zakresie nie ma
%   punktów widma, zwrócono amplitudę 0.
%
% Algorytm:
%   1. Wyznaczono zakres częstotliwości
%   2. Wyszukano maksimum widma w tym zakresie
%   3. Zwrócono amplitudę i odpowiadającą częstotliwość
    
    % Wyznaczono zakres wyszukiwania
    freq_mask = (freq_vec >= target_freq - tolerance_hz) & ...
                (freq_vec <= target_freq + tolerance_hz);
    
    if any(freq_mask)
        % Znaleziono maksimum w określonym zakresie
        [amplitude, max_idx] = max(spectrum(freq_mask));
        freq_subset = freq_vec(freq_mask);
        freq_found = freq_subset(max_idx);
    else
        % Brak punktów w zakresie - zwrócono wartości domyślne
        amplitude = 0;
        freq_found = target_freq;
    end
end