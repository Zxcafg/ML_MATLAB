function features = extract_wavelet_features(signals, CONFIG)
% EKSTRAKCJA CECH METODĄ 4: TRANSFORMATA FALKOWA Z ANALIZĄ STATYSTYCZNĄ
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
%   dyskretnej transformaty falkowej (DWT) z analizą statystyczną
%   współczynników falkowych. Wyekstrahowano 54 cechy podzielone
%   na 9 poziomów dekompozycji (8 poziomów szczegółów + 1 poziom aproksymacji).
%   Dla każdego poziomu obliczono 6 cech statystycznych.
%
% Źródło algorytmów:
%   Algorytmy ekstrakcji cech zostały wygenerowane przez
%   MATLAB Diagnostic Feature Designer zgodnie z metodologią
%   określoną w pracy dyplomowej.
%
% Metodyka:
%   1. Wykonano dyskretną transformatę falkową (DWT) z użyciem
%      falki Daubechies 4-go rzędu (db4) na 8 poziomach dekompozycji.
%   2. Wyodrębniono współczynniki falkowe dla każdego poziomu:
%      - D1-D8: współczynniki szczegółów (wysokie częstotliwości)
%      - A8: współczynniki aproksymacji (niskie częstotliwości, trend)
%   3. Dla współczynników każdego poziomu obliczono:
%      a. Energię (suma kwadratów)
%      b. Wartość skuteczną (RMS)
%      c. Kurtozę rozkładu
%      d. Entropię Shannona
%      e. Skośność rozkładu
%      f. Współczynnik szczytowości (peak-to-RMS)
%
% Specyfikacja techniczna:
%   - Falka: Daubechies 4 (db4)
%   - Liczba poziomów dekompozycji: 8
%   - Cechy na poziom: 6
%   - Łączna liczba cech: 6 × 9 = 54

    num_signals = size(signals, 1);
    
    % Parametry transformaty falkowej
    wavelet_name = 'db4';      % Falka Daubechies 4-go rzędu
    level = 8;                 % Liczba poziomów dekompozycji
    
    % Określono liczbę cech:
    % 6 cech statystycznych × 9 poziomów (D1-D8 + A8)
    features_per_level = 6;
    num_levels = level + 1;    % +1 dla współczynników aproksymacji
    num_features = features_per_level * num_levels;
    
    feature_matrix = zeros(num_signals, num_features);
    
    fprintf('   Rozpoczęto ekstrakcję cech falkowych dla %d sygnałów\n', num_signals);
    fprintf('   Falka: %s, Liczba poziomów dekompozycji: %d\n', wavelet_name, level);
    
    for sig_idx = 1:num_signals
        if mod(sig_idx, 100) == 0
            fprintf('     Postęp przetwarzania: %d/%d sygnałów\n', sig_idx, num_signals);
        end
        
        signal = signals(sig_idx, :)';
        
        %% DYSKRETNA TRANSFORMATA FALKOWA (DWT)
        try
            % Wykonano dekompozycję falkową na 8 poziomów
            [C, L] = wavedec(signal, level, wavelet_name);
        catch ME
            fprintf('     Błąd transformaty falkowej dla sygnału %d: %s\n', sig_idx, ME.message);
            % Kontynuowano przetwarzanie kolejnych sygnałów
            continue;
        end
        
        % Wyodrębniono współczynniki falkowe dla każdego poziomu
        coeffs = cell(1, num_levels);
        
        % Współczynniki szczegółów D1-D8
        for lev = 1:level
            coeffs{lev} = detcoef(C, L, lev);
        end
        
        % Współczynniki aproksymacji A8
        coeffs{num_levels} = appcoef(C, L, wavelet_name);
        
        %% EKSTRAKCJA CECH STATYSTYCZNYCH
        feat_idx = 1;
        
        for lev = 1:num_levels
            coef = coeffs{lev};
            
            if isempty(coef)
                % Brak współczynników - wypełniono zerami
                for feat = 1:features_per_level
                    feature_matrix(sig_idx, feat_idx) = 0;
                    feat_idx = feat_idx + 1;
                end
                continue;
            end
            
            %% 1. ENERGIA WSPÓŁCZYNNIKÓW FALKOWYCH
            energy = sum(coef.^2);
            feature_matrix(sig_idx, feat_idx) = energy;
            feat_idx = feat_idx + 1;
            
            %% 2. WARTOŚĆ SKUTECZNA (RMS) WSPÓŁCZYNNIKÓW
            rms_val = sqrt(mean(coef.^2));
            feature_matrix(sig_idx, feat_idx) = rms_val;
            feat_idx = feat_idx + 1;
            
            %% 3. KURTOZA ROZKŁADU WSPÓŁCZYNNIKÓW
            if std(coef) > 1e-10
                kurt_val = kurtosis(coef);
            else
                kurt_val = 0;
            end
            feature_matrix(sig_idx, feat_idx) = kurt_val;
            feat_idx = feat_idx + 1;
            
            %% 4. ENTROPIA SHANNONA WSPÓŁCZYNNIKÓW
            % Przekształcono współczynniki do rozkładu prawdopodobieństwa
            p = coef.^2;
            sum_p = sum(p);
            if sum_p > 0
                p = p / sum_p;
                p(p == 0) = [];  % Usunięto zera
                if ~isempty(p)
                    entropy_val = -sum(p .* log2(p));
                else
                    entropy_val = 0;
                end
            else
                entropy_val = 0;
            end
            feature_matrix(sig_idx, feat_idx) = entropy_val;
            feat_idx = feat_idx + 1;
            
            %% 5. SKOŚNOŚĆ ROZKŁADU WSPÓŁCZYNNIKÓW
            if std(coef) > 1e-10
                skew_val = skewness(coef);
            else
                skew_val = 0;
            end
            feature_matrix(sig_idx, feat_idx) = skew_val;
            feat_idx = feat_idx + 1;
            
            %% 6. WSPÓŁCZYNNIK SZCZYTOWOŚCI (PEAK-TO-RMS)
            if rms_val > 1e-10
                peak2rms = max(abs(coef)) / rms_val;
            else
                peak2rms = 0;
            end
            feature_matrix(sig_idx, feat_idx) = peak2rms;
            feat_idx = feat_idx + 1;
        end
    end
    
    %% NAZWY CECH
    % Zdefiniowano nazwy dla wszystkich 54 cech
    feature_names = {};
    
    % Typy cech statystycznych
    feat_types = {'Energy', 'RMS', 'Kurtosis', 'Entropy', 'Skewness', 'Peak2RMS'};
    
    for lev = 1:num_levels
        % Określono nazwę poziomu
        if lev <= level
            level_name = sprintf('D%d', lev);      % Poziom szczegółów
        else
            level_name = sprintf('A%d', level);    % Poziom aproksymacji
        end
        
        % Dodano nazwy dla 6 cech na poziom
        for feat_idx = 1:features_per_level
            feat_name = feat_types{feat_idx};
            feature_names{end+1} = sprintf('Wavelet_%s_%s', level_name, feat_name);
        end
    end
    
    % Zwrócono strukturę z cechami
    features = struct();
    features.data = feature_matrix;
    features.names = feature_names;
    
    fprintf('   Zakończono ekstrakcję cech: %d cech falkowych\n', num_features);
end

function fisher_ratios = compute_fisher_ratio(feature_matrix, conditions)
% OBLICZANIE WSPÓŁCZYNNIKA FISHER RATIO DLA CECH
%
% Wejście:
%   feature_matrix - macierz cech [liczba_próbek × liczba_cech]
%   conditions     - wektor etykiet klas dla każdej próbki
%
% Wyjście:
%   fisher_ratios - wektor współczynników Fisher Ratio dla każdej cechy
%
% Opis:
%   Obliczono współczynnik Fisher Ratio dla każdej cechy.
%   Fisher Ratio jest miarą zdolności cechy do separacji klas.
%   Wyższa wartość oznacza lepszą zdolność dyskryminacyjną.
%
% Wzory:
%   Var_B = (1/K) × Σ(μ_i - μ)^2           (wariancja międzyklasowa)
%   Var_W = (1/K) × Σσ_i^2                 (wariancja wewnątrzklasowa)
%   Fisher Ratio = Var_B / Var_W
%
% Alternatywnie z ważeniem:
%   Var_B = Σ(n_i × (μ_i - μ)^2) / N_total
%   Var_W = Σ(n_i × σ_i^2) / N_total
%
% gdzie:
%   K - liczba klas
%   μ_i - średnia cechy w klasie i
%   μ - średnia globalna cechy
%   σ_i^2 - wariancja cechy w klasie i
%   n_i - liczba próbek w klasie i
%   N_total - całkowita liczba próbek

    num_features = size(feature_matrix, 2);
    fisher_ratios = zeros(1, num_features);
    
    % Wyznaczono unikalne klasy
    unique_classes = unique(conditions);
    num_classes = length(unique_classes);
    
    fprintf('   Rozpoczęto obliczanie Fisher Ratio dla %d cech i %d klas\n', num_features, num_classes);
    
    for feat_idx = 1:num_features
        feature_data = feature_matrix(:, feat_idx);
        
        % Obliczono średnią globalną cechy
        overall_mean = mean(feature_data);
        
        % Inicjalizowano tablice dla statystyk klasowych
        class_sizes = zeros(num_classes, 1);
        class_means = zeros(num_classes, 1);
        class_vars = zeros(num_classes, 1);
        
        for class_idx = 1:num_classes
            class_name = unique_classes{class_idx};
            class_mask = strcmp(conditions, class_name);
            
            class_data = feature_data(class_mask);
            class_sizes(class_idx) = length(class_data);
            class_means(class_idx) = mean(class_data);
            class_vars(class_idx) = var(class_data, 1);  % Wariancja z dzielnikiem N
        end
        
        %% WARIANCJA MIĘDZYKLASOWA
        total_samples = sum(class_sizes);
        bc_var = 0;
        
        for class_idx = 1:num_classes
            % Zastosowano ważoną wariancję międzyklasową
            bc_var = bc_var + class_sizes(class_idx) * (class_means(class_idx) - overall_mean)^2;
        end
        bc_var = bc_var / total_samples;
        
        %% WARIANCJA WEWNĄTRZKLASOWA
        wc_var = 0;
        for class_idx = 1:num_classes
            wc_var = wc_var + class_sizes(class_idx) * class_vars(class_idx);
        end
        wc_var = wc_var / total_samples;
        
        %% WSPÓŁCZYNNIK FISHER RATIO
        if wc_var > 1e-10
            fisher_ratios(feat_idx) = bc_var / wc_var;
        else
            fisher_ratios(feat_idx) = 0;
        end
    end
    
    %% WYŚWIETLENIE STATYSTYK
    fprintf('   Zakończono obliczanie Fisher Ratio\n');
    fprintf('     Mediana: %.4f, Maksimum: %.4f, Minimum: %.4f\n', ...
        median(fisher_ratios), max(fisher_ratios), min(fisher_ratios));
    
    % Wyszukano i wyświetlono 10 cech o najwyższym Fisher Ratio
    [sorted_fr, sort_idx] = sort(fisher_ratios, 'descend');
    fprintf('     10 cech o najwyższym Fisher Ratio:\n');
    for i = 1:min(10, length(sorted_fr))
        fprintf('       Pozycja %d: cecha nr %d, FR = %.4f\n', i, sort_idx(i), sorted_fr(i));
    end
end