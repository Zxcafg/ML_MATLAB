function features = extract_ar_features_durand_kerner(signals, ensemble_mean, CONFIG)
% EKSTRAKCJA CECH METODĄ 2: AUTOREGRESYJNA (AR) Z ALGORYTMEM DURAND-KERNER
% 
% Wejście:
%   signals       - macierz sygnałów [liczba_sygnałów × SAMPLES_PER_EXP]
%   ensemble_mean - wektor średniej sygnału z całego zbioru treningowego
%   CONFIG        - struktura konfiguracyjna systemu
%
% Wyjście:
%   features.data  - macierz cech [liczba_sygnałów × liczba_cech]
%   features.names - nazwy cech (cell array)
%
% Opis:
%   Przeprowadzono ekstrakcję cech sygnałów prądowych metodą
%   autoregresyjną (AR) z algorytmem Durand-Kernera do wyznaczania
%   pierwiastków wielomianu charakterystycznego. Wyekstrahowano
%   15 cech pogrupowanych w 4 kategorie:
%   1. Parametry modelu AR dla sygnału oryginalnego (4 cechy)
%   2. Parametry modelu AR dla sygnału detrendowanego (5 cech)
%   3. Parametry modelu AR dla sygnału rezydualnego (5 cech)
%   4. Energia pierwszej funkcji modalnej IMF (1 cecha)
%
% Źródło algorytmów:
%   Algorytmy ekstrakcji cech zostały wygenerowane przez
%   MATLAB Diagnostic Feature Designer. Zastosowano identyczny
%   algorytm wyznaczania pierwiastków jak w implementacji na ESP32.
%
% Różnice w stosunku do standardowego MATLAB:
%   - Zastąpiono funkcję roots() własną implementacją Durand-Kernera
%   - Zachowano identyczną kolejność sortowania pierwiastków
%   - Zastosowano te same współczynniki inicjalizacji
%
% Metodyka:
%   Dla każdego sygnału obliczono parametry modelu AR rzędu p=10
%   dla trzech wariantów sygnału:
%   A. Sygnał oryginalny
%   B. Sygnał detrendowany (usunięcie trendu liniowego)
%   C. Sygnał rezydualny (odejmowanie średniej zespołowej)
%
%   Następnie wyznaczono:
%   - Częstotliwość i tłumienie dominującego bieguna
%   - Kryterium informacyjne Akaike (AIC)
%   - Błędy predykcji (MAE, RMS)
%   - Energię pierwszej funkcji IMF z empirycznej dekompozycji modalnej

    Fs = CONFIG.Fs;
    p = CONFIG.p_ar;
    num_signals = size(signals, 1);
    
    % Określono liczbę cech:
    % Parametry modelu AR dla sygnału oryginalnego: 4 cechy
    % Parametry modelu AR dla sygnału detrendowanego: 5 cech
    % Parametry modelu AR dla sygnału rezydualnego: 5 cech
    % Energia IMF1: 1 cecha
    % Razem: 4 + 5 + 5 + 1 = 15 cech
    
    feature_matrix = zeros(num_signals, 15);
    
    fprintf('   Rozpoczęto ekstrakcję cech AR dla %d sygnałów\n', num_signals);
    fprintf('   Zastosowano algorytm Durand-Kernera zgodny z implementacją ESP32\n');
    
    for sig_idx = 1:num_signals
        if mod(sig_idx, 100) == 0
            fprintf('     Postęp przetwarzania: %d/%d sygnałów\n', sig_idx, num_signals);
        end
        
        signal = signals(sig_idx, :)';
        
        %% TRZY WARIANTY SYGNAŁU DO ANALIZY
        % A. Sygnał oryginalny (Current)
        Current = signal;
        
        % B. Sygnał detrendowany (Current_tsproc)
        p_detrend = polyfit((1:length(signal))', signal, 1);
        trend = polyval(p_detrend, (1:length(signal))');
        Current_tsproc = signal - trend;
        
        % C. Sygnał rezydualny (Current_res)
        Current_res = signal - ensemble_mean';
        
        %% WYCIĄGANIE CECH Z MODELU AR Z ALGORYTMEM DURAND-KERNERA
        
        % 1. Parametry dla sygnału oryginalnego (Current_tsmodel)
        [f1, d1, ~, mae1, aic1, ~] = compute_tsmodel_durand_kerner(Current, Fs, p);
        feature_matrix(sig_idx, 1) = aic1;   % Current_tsmodel_AIC
        feature_matrix(sig_idx, 5) = mae1;   % Current_tsmodel_MAE
        feature_matrix(sig_idx, 10) = d1;    % Current_tsmodel_Damp1
        feature_matrix(sig_idx, 12) = f1;    % Current_tsmodel_Freq1
        
        % 2. Parametry dla sygnału detrendowanego (Current_tsproc_tsmodel)
        [f2, d2, ~, mae2, aic2, ~, rms2] = compute_tsmodel_with_rms_durand_kerner(Current_tsproc, Fs, p);
        feature_matrix(sig_idx, 2) = aic2;   % Current_tsproc_tsmodel_AIC
        feature_matrix(sig_idx, 4) = mae2;   % Current_tsproc_tsmodel_MAE
        feature_matrix(sig_idx, 7) = rms2;   % Current_tsproc_tsmodel_RMS
        feature_matrix(sig_idx, 9) = d2;     % Current_tsproc_tsmodel_Damp1
        feature_matrix(sig_idx, 11) = f2;    % Current_tsproc_tsmodel_Freq1
        
        % 3. Parametry dla sygnału rezydualnego (Current_res_tsmodel)
        [f3, d3, ~, mae3, aic3, ~, rms3] = compute_tsmodel_with_rms_durand_kerner(Current_res, Fs, p);
        feature_matrix(sig_idx, 3) = aic3;   % Current_res_tsmodel_AIC
        feature_matrix(sig_idx, 6) = mae3;   % Current_res_tsmodel_MAE
        feature_matrix(sig_idx, 8) = rms3;   % Current_res_tsmodel_RMS
        feature_matrix(sig_idx, 14) = d3;    % Current_res_tsmodel_Damp1
        feature_matrix(sig_idx, 13) = f3;    % Current_res_tsmodel_Freq1
        
        % 4. Energia pierwszej funkcji modalnej IMF
        feature_matrix(sig_idx, 15) = compute_energy_imf(Current);
    end
    
    %% NAZWY CECH
    % Zdefiniowano nazwy dla wszystkich 15 cech zgodnie z DFD
    feature_names = {
        'Current_tsmodel_AIC', ...              % 1
        'Current_tsproc_tsmodel_AIC', ...       % 2
        'Current_res_tsmodel_AIC', ...          % 3
        'Current_tsproc_tsmodel_MAE', ...       % 4
        'Current_tsmodel_MAE', ...              % 5
        'Current_res_tsmodel_MAE', ...          % 6
        'Current_tsproc_tsmodel_RMS', ...       % 7
        'Current_res_tsmodel_RMS', ...          % 8
        'Current_tsproc_tsmodel_Damp1', ...     % 9
        'Current_tsmodel_Damp1', ...            % 10
        'Current_tsproc_tsmodel_Freq1', ...     % 11
        'Current_tsmodel_Freq1', ...            % 12
        'Current_res_tsmodel_Freq1', ...        % 13
        'Current_res_tsmodel_Damp1', ...        % 14
        'Current_emdfeat_EnergyIMF1'            % 15
    };
    
    % Zwrócono strukturę z cechami
    features = struct();
    features.data = feature_matrix;
    features.names = feature_names;
    
    fprintf('   Zakończono ekstrakcję cech: %d cech AR z algorytmem Durand-Kernera\n', length(feature_names));
end

%% FUNKCJE POMOCNICZE

function dominant_root = durand_kerner_roots(a)
% ALGORYTM DURAND-KERNERA DO WYZNACZANIA PIERWIASTKÓW WIELOMIANU
%
% Wejście:
%   a - współczynniki wielomianu [1, a1, a2, ..., aN]
%
% Wyjście:
%   dominant_root - dominujący pierwiastek (największy moduł)
%
% Opis:
%   Zaimplementowano algorytm Durand-Kernera (Weierstrassa)
%   do wyznaczania pierwiastków wielomianu. Algorytm jest
%   identyczny z implementacją w języku C na mikrokontrolerze ESP32.
%
% Metodyka:
%   1. Inicjalizowano punkty startowe równomiernie na okręgu |z|=0.9
%   2. Wykonano iteracyjne poprawki według wzoru Durand-Kernera
%   3. Sprawdzono zbieżność przy zmianie mniejszej niż tolerancja
%   4. Posortowano pierwiastki według malejącego modułu
%   5. Zwrócono pierwiastki dominujący
%
% Parametry:
%   MAX_ITER = 200  - maksymalna liczba iteracji
%   TOL = 1e-10     - tolerancja zbieżności

    N = length(a) - 1;  % Stopień wielomianu
    
    if N == 0
        dominant_root = 0;
        return;
    end
    
    if N == 1
        dominant_root = -a(2);
        return;
    end
    
    MAX_ITER = 200;
    TOL = 1e-10;
    
    % Inicjalizacja: punkty równomiernie na okręgu |z| = 0.9
    R = 0.9;
    roots = zeros(N, 1);
    
    for i = 1:N
        angle = 2 * pi * (i-1) / N;
        pert = 0.05 * sin((i) * 1.234);
        roots(i) = (R + pert) * (cos(angle) + 1i * sin(angle));
    end
    
    % Iteracje algorytmu Durand-Kernera
    for iter = 1:MAX_ITER
        max_change = 0;
        new_roots = zeros(N, 1);
        
        for i = 1:N
            z = roots(i);
            
            % Obliczono wartość wielomianu schematem Hornera
            p_val = a(1);  % a(1) = 1.0
            for j = 2:(N+1)
                p_val = p_val * z + a(j);
            end
            
            % Obliczono iloczyn różnic
            prod = 1;
            for k = 1:N
                if k ~= i
                    diff = roots(i) - roots(k);
                    if abs(diff) > 1e-14
                        prod = prod * diff;
                    end
                end
            end
            
            % Poprawka Durand-Kernera
            if abs(prod) > 1e-14
                correction = p_val / prod;
                new_roots(i) = z - correction;
                
                change = abs(correction);
                if change > max_change
                    max_change = change;
                end
            else
                new_roots(i) = z;
            end
        end
        
        % Sprawdzono zbieżność
        if max_change < TOL
            break;
        end
        
        roots = new_roots;
    end
    
    % Posortowano pierwiastki według malejącego modułu
    [~, sort_idx] = sort(abs(roots), 'descend');
    roots = roots(sort_idx);
    
    % Zwrócono pierwiastki dominujący
    dominant_root = roots(1);
end

function [Freq1, Damp1, MSE, MAE, AIC, Variance] = compute_tsmodel_durand_kerner(signal, Fs, p)
% OBLICZANIE PARAMETRÓW MODELU AR Z ALGORYTMEM DURAND-KERNERA
%
% Wejście:
%   signal - wektor sygnału
%   Fs     - częstotliwość próbkowania [Hz]
%   p      - rząd modelu AR
%
% Wyjście:
%   Freq1    - częstotliwość dominującego bieguna [Hz]
%   Damp1    - współczynnik tłumienia dominującego bieguna
%   MSE      - błąd średniokwadratowy predykcji
%   MAE      - średni błąd bezwzględny predykcji
%   AIC      - kryterium informacyjne Akaike
%   Variance - wariancja reszt modelu

    x = signal;
    y = x - mean(x, 'omitnan');
    N = numel(x);
    
    % Obliczono funkcję autokorelacji
    R = xcorr(y, p, 'biased');
    R(1:p) = [];
    
    % Estymowano parametry modelu AR algorytmem Levinsona-Durbina
    [a, Ep] = levinson(R, p);
    
    % Wyznaczono pierwiastki wielomianu charakterystycznego
    r = durand_kerner_roots(a);
    
    % Przekształcono do dziedziny s (ciągłej)
    s = Fs * log(r);
    
    % Obliczono częstotliwość i tłumienie
    Freq1 = abs(s) / (2*pi);
    Damp1 = -real(s) / abs(s);
    
    % Obliczono błędy predykcji
    w = filter(a, 1, y);
    MSE = var(w, 'omitnan');
    MAE = mean(abs(w), 'omitnan');
    
    % Obliczono reszty modelu
    e = filter(a, 1, x);
    Variance = var(e, 'omitnan');
    
    % Obliczono kryterium Akaike (AIC)
    AIC = log(Ep) + 2*p/N;
end

function [Freq1, Damp1, MSE, MAE, AIC, Variance, RMS] = compute_tsmodel_with_rms_durand_kerner(signal, Fs, p)
% OBLICZANIE PARAMETRÓW MODELU AR Z DODATKOWYM PARAMETREM RMS
%
% Wejście:
%   signal - wektor sygnału
%   Fs     - częstotliwość próbkowania [Hz]
%   p      - rząd modelu AR
%
% Wyjście:
%   Freq1    - częstotliwość dominującego bieguna [Hz]
%   Damp1    - współczynnik tłumienia dominującego bieguna
%   MSE      - błąd średniokwadratowy predykcji
%   MAE      - średni błąd bezwzględny predykcji
%   AIC      - kryterium informacyjne Akaike
%   Variance - wariancja reszt modelu
%   RMS      - wartość skuteczna reszt modelu

    % Obliczono podstawowe parametry modelu
    [Freq1, Damp1, MSE, MAE, AIC, Variance] = compute_tsmodel_durand_kerner(signal, Fs, p);
    
    % Dodatkowo obliczono wartość skuteczną (RMS)
    x = signal;
    y = x - mean(x, 'omitnan');
    
    R = xcorr(y, p, 'biased');
    R(1:p) = [];
    [a, ~] = levinson(R, p);
    
    e = filter(a, 1, x);
    
    if exist('rms', 'file') == 2
        RMS = rms(e, 'omitnan');
    else
        RMS = sqrt(mean(e.^2, 'omitnan'));
    end
end

function EnergyIMF1 = compute_energy_imf(signal)
% OBLICZANIE ENERGII PIERWSZEJ FUNKCJI MODALNEJ IMF
%
% Wejście:
%   signal - wektor sygnału
%
% Wyjście:
%   EnergyIMF1 - energia pierwszej funkcji IMF
%
% Opis:
%   Obliczono energię pierwszej funkcji modalnej (IMF)
%   z empirycznej dekompozycji modalnej (EMD).
%   Jeśli toolbox EMD jest niedostępny, zastosowano
%   przybliżenie jako sumę wartości bezwzględnych
%   sygnału po usunięciu składowej stałej.

    try
        if exist('emd', 'file') == 2
            % Wykonano empiryczną dekompozycję modalną
            outputEMD = emd(signal, "MaxNumIMF", 1);
            % Obliczono energię pierwszej funkcji IMF
            EnergyIMF1 = sum(outputEMD(:, 1));
        else
            % Przybliżenie gdy brak toolboxu EMD
            EnergyIMF1 = sum(abs(signal - mean(signal)));
        end
    catch
        % Rezerwowa metoda w przypadku błędu
        EnergyIMF1 = sum(abs(signal));
    end
end