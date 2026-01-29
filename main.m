%% ========================================================================
% MASTER GENERATOR - SYSTEM EKSTRAKCJI CECH DIAGNOSTYCZNYCH SILNIKÓW BLDC
% ========================================================================
%
% Plik:        main.m
% Autor:       Pavel Tshonek (155068)
% Data:        2026-01
% Opis:        Główny skrypt generowania tabel cech dla 4 metod analizy sygnałów
% 
% SYSTEM DIAGNOSTYCZNY DLA SILNIKÓW BLDC W DRONACH
% --------------------------------------------------
% System implementuje kompleksowy pipeline przetwarzania sygnałów prądowych
% z czterech stanów silnika. Przeprowadzono analizę czterema metodami ekstrakcji 
% cech z wykorzystaniem zaawansowanych technik augmentacji i testów odporności.
%
% STRUKTURA METOD ANALIZY:
%   M1: Analiza czasowa + filtrowanie 6 pasm częstotliwości
%   M2: Model AR(10) z algorytmem Durand-Kerner
%   M3: FFT + Analiza obwiedni (transformata Hilberta)
%   M4: Dekompozycja falkowa + Fisher Ratio
%
% KLASYFIKACJA STANÓW SILNIKA:
%   1. Zdrowy (Healthy)
%   2. Uszkodzenie mechaniczne (Mech_Damage)
%   3. Uszkodzenie elektryczne (Elec_Damage)
%   4. Uszkodzenie kombinowane (Mech_Elec_Damage)
%
% ARCHITEKTURA SYSTEMU:
%   1. Wczytano i przygotowano sygnały
%   2. Przeprowadzono augmentację danych (opcjonalnie)
%   3. Wyekstrahowano cechy dla każdej metody
%   4. Znormalizowano cechy metodą Z-score
%   5. Wygenerowano testy odporności
%   6. Połączono cechy wszystkich metod
%   7. Przeprowadzono analizę ważności cech
%   8. Wyeksportowano dane do DFD (Diagnostic Feature Designer)
%
% PARAMETRY TECHNICZNE:
%   Częstotliwość próbkowania: Fs = 50 kHz
%   Liczba próbek: SAMPLES = 32768 (2^15)
%   Rząd modelu AR: p_ar = 10
%   Pasma częstotliwości: 
%     [100-500, 500-2000, 2000-5000, 5000-10000, 10000-15000, 15000-20000] Hz
%
% STRUKTURA WYJŚCIOWA:
%   FeatureTables/
%   ├── Train/              # Zbiory treningowe
%   ├── Test/               # Zbiory testowe
%   ├── Robustness/         # Testy odporności (7 scenariuszy)
%   ├── Combined/           # Cechy połączone wszystkich metod
%   └── Analysis/           # Wyniki analiz statystycznych
%
% ŹRÓDŁA I AUTORSTWO:
%   Pipeline:               Pavel Tshonek (155068)
%   Algorytmy ekstrakcji:   MATLAB Diagnostic Feature Designer
%   Augmentacja:            Implementacja własna
%   Dataset:                DUDU-BLDC (AGH Kraków)
% ========================================================================

%% Inicjalizacja środowiska
clear; clc; close all;
fprintf('========================================================================\n');
fprintf('SYSTEM DIAGNOSTYCZNY SILNIKÓW BLDC - GENERATOR CECH\n');
fprintf('========================================================================\n');
fprintf('Autor: Pavel Tshonek (155068)\n');
fprintf('Data:  2026-01\n');
fprintf('========================================================================\n\n');

%% SEKCJA 1: KONFIGURACJA METOD ANALIZY
% Wybór metod do uruchomienia
% --------------------------------------------------
fprintf('WYBÓR METOD ANALIZY\n');
fprintf('-------------------------------------------------------------\n');
fprintf('1 - Analiza czasowa + filtrowanie pasmowe\n');
fprintf('2 - Model AR(10) z algorytmem Durand-Kerner\n');
fprintf('3 - FFT + Analiza obwiedni\n');
fprintf('4 - Dekompozycja falkowa + Fisher Ratio\n');
fprintf('5 - Wszystkie metody (osobno)\n');
fprintf('6 - Wszystkie metody (połączone + analiza)\n');
fprintf('-------------------------------------------------------------\n');

method_choice = input('Wybierz metodę (1-6): ', 's');
if isempty(method_choice), method_choice = '5'; end

% Określono zestaw metod do uruchomienia
run_methods = [];
switch method_choice
    case '1', run_methods = 1;      % M1: Analiza czasowa
    case '2', run_methods = 2;      % M2: Model AR
    case '3', run_methods = 3;      % M3: FFT + Envelope
    case '4', run_methods = 4;      % M4: Wavelet
    case '5', run_methods = 1:4;    % Wszystkie metody osobno
    case '6', run_methods = 1:4; run_combined = true;  % Połączone + analiza
    otherwise
        error('Nieprawidłowy wybór! Proszę wybrać wartość z zakresu 1-6.');
end

if ~exist('run_combined', 'var'), run_combined = false; end

%% SEKCJA 2: KONFIGURACJA DODATKOWYCH FUNKCJONALNOŚCI
% Ustawienia augmentacji i testów odporności
% --------------------------------------------------
fprintf('\nKONFIGURACJA DODATKOWYCH MODUŁÓW\n');
fprintf('-------------------------------------------------------------\n');

% Konfiguracja augmentacji: 18× więcej danych (3 amp × 3 freq × 2 noise)
use_augmentation = input('Włączyć augmentację danych treningowych? (t/n) [t]: ', 's');
use_augmentation = isempty(use_augmentation) || strcmpi(use_augmentation, 't');

% Konfiguracja testów odporności: 7 scenariuszy testowych
generate_robustness = input('Generować zestawy testów odporności? (t/n) [t]: ', 's');
generate_robustness = isempty(generate_robustness) || strcmpi(generate_robustness, 't');

if run_combined
    analyze_feature_importance = true;
else
    analyze_feature_importance_input = input('Włączyć analizę ważności cech? (t/n) [n]: ', 's');
    analyze_feature_importance = strcmpi(analyze_feature_importance_input, 't');
end

%% SEKCJA 3: GLOBALNA KONFIGURACJA SYSTEMU
% Definicja głównej struktury konfiguracyjnej
% --------------------------------------------------
fprintf('\nKONFIGURACJA GLOBALNA SYSTEMU\n');
fprintf('-------------------------------------------------------------\n');

CONFIG = struct();
CONFIG.folderPath = 'Experiments_Split/';          % Ścieżka do danych
CONFIG.Fs = 50000;                                 % Częstotliwość próbkowania [Hz]
CONFIG.SAMPLES_PER_EXP = 32768;                    % Próbki na eksperyment
CONFIG.p_ar = 10;                                  % Rząd modelu AR

% Pliki treningowe i testowe
CONFIG.train_files = {
    'healthy_train.csv',
    'healthy_zip_train.csv', 
    'faulty_train.csv',
    'faulty_zip_train.csv'
};

CONFIG.test_files = {
    'healthy_test.csv',
    'healthy_zip_test.csv', 
    'faulty_test.csv',
    'faulty_zip_test.csv'
};

% Zdefiniowano 6 pasm częstotliwości do analizy
CONFIG.freq_bands = [
    100,   500;
    500,   2000;
    2000,  5000;
    5000,  10000;
    10000, 15000;
    15000, 20000
];

%% SEKCJA 4: PARAMETRY ROBUSTNESS I AUGMENTACJI
% Wspólne parametry dla augmentacji i testów odporności
% --------------------------------------------------
fprintf('\nKONFIGURACJA PARAMETRÓW ODNOŚNOŚCI\n');
fprintf('-------------------------------------------------------------\n');
fprintf('Poziomy odporności:\n');
fprintf('  1 - Łagodny:     freq ±10%%, amp ±30%%, noise 2-5%%\n');
fprintf('  2 - Umiarkowany: freq ±10%%, amp -40%%/+60%%, noise 3-7%%\n');
fprintf('  3 - Agresywny:   freq ±20%%, amp -50%%/+80%%, noise 5-10%%\n');
fprintf('-------------------------------------------------------------\n');

robustness_level = input('Wybierz poziom odporności (1-3) [2]: ', 's');
if isempty(robustness_level), robustness_level = '2'; end

% Ustawiono parametry według wybranego poziomu
switch robustness_level
    case '1'
        freq_range = [0.9, 1.1];
        amp_range = [0.7, 1.3];
        noise_range = [0.02, 0.05];
        fprintf('Wybrano poziom łagodny\n');
        
    case '2'
        freq_range = [0.85, 1.15];
        amp_range = [0.6, 1.6];
        noise_range = [0.03, 0.07];
        fprintf('Wybrano poziom umiarkowany\n');
        
    case '3'
        freq_range = [0.8, 1.2];
        amp_range = [0.5, 1.8];
        noise_range = [0.05, 0.10];
        fprintf('Wybrano poziom agresywny\n');
        
    otherwise
        freq_range = [0.85, 1.15];
        amp_range = [0.6, 1.6];
        noise_range = [0.03, 0.07];
        fprintf('Ustawiono poziom umiarkowany (domyślnie)\n');
end

CONFIG.augmentation = struct();
CONFIG.robustness = struct();

CONFIG.augmentation.amp_levels = linspace(amp_range(1), amp_range(2), 3);
CONFIG.augmentation.freq_shifts = linspace(freq_range(1), freq_range(2), 3);
CONFIG.augmentation.noise_levels = linspace(noise_range(1), noise_range(2), 2);

CONFIG.robustness.amp_range = amp_range;
CONFIG.robustness.freq_shift_levels = [freq_range(1), 1.0, freq_range(2)];
CONFIG.robustness.noise_level = mean(noise_range);
CONFIG.robustness.combined_noise = noise_range(1);

%% SEKCJA 5: PRZYGOTOWANIE STRUKTURY FOLDERÓW
% Utworzenie niezbędnych katalogów wyjściowych
% --------------------------------------------------
fprintf('\nPRZYGOTOWANIE STRUKTURY FOLDERÓW\n');
fprintf('-------------------------------------------------------------\n');

utworzono_foldery = false;
if ~exist('FeatureTables', 'dir')
    mkdir('FeatureTables'); utworzono_foldery = true;
end
if ~exist('FeatureTables/Train', 'dir')
    mkdir('FeatureTables/Train'); utworzono_foldery = true;
end
if ~exist('FeatureTables/Test', 'dir')
    mkdir('FeatureTables/Test'); utworzono_foldery = true;
end
if run_combined || analyze_feature_importance
    if ~exist('FeatureTables/Combined', 'dir')
        mkdir('FeatureTables/Combined'); utworzono_foldery = true;
    end
end
if ~exist('FeatureTables/Analysis', 'dir')
    mkdir('FeatureTables/Analysis'); utworzono_foldery = true;
end
if generate_robustness && ~exist('FeatureTables/Robustness', 'dir')
    mkdir('FeatureTables/Robustness'); utworzono_foldery = true;
end
if ~exist('Analysis_Plots', 'dir')
    mkdir('Analysis_Plots'); utworzono_foldery = true;
end
if ~exist('Robustness_Signals', 'dir')
    mkdir('Robustness_Signals'); utworzono_foldery = true;
end

for m = run_methods
    dfd_folder = sprintf('DFD_Method%d', m);
    if ~exist(dfd_folder, 'dir')
        mkdir(dfd_folder); utworzono_foldery = true;
    end
    if ~exist([dfd_folder '/train'], 'dir')
        mkdir([dfd_folder '/train']); utworzono_foldery = true;
    end
    if ~exist([dfd_folder '/test'], 'dir')
        mkdir([dfd_folder '/test']); utworzono_foldery = true;
    end
end

if utworzono_foldery
    fprintf('Utworzono strukturę folderów wyjściowych\n');
end

%% SEKCJA 6: WCZYTANIE SYGNAŁÓW POMIAROWYCH
% Ładowanie sygnałów treningowych i testowych
% --------------------------------------------------
fprintf('\nŁADOWANIE SYGNAŁÓW POMIAROWYCH\n');
fprintf('-------------------------------------------------------------\n');

[train_signals, train_conditions] = load_all_signals(CONFIG.train_files, CONFIG.folderPath, CONFIG.SAMPLES_PER_EXP);
[test_signals, test_conditions] = load_all_signals(CONFIG.test_files, CONFIG.folderPath, CONFIG.SAMPLES_PER_EXP);

fprintf('Zbiór treningowy: %d sygnałów\n', size(train_signals, 1));
fprintf('Zbiór testowy:    %d sygnałów\n', size(test_signals, 1));

% Obliczono dominującą częstotliwość dla augmentacji
dominant_freqs = zeros(size(train_signals, 1), 1);
for i = 1:size(train_signals, 1)
    [freq, ~] = compute_dominant_frequency_improved(train_signals(i, :), CONFIG.Fs);
    dominant_freqs(i) = freq(1);
end
CONFIG.dominant_freq = median(dominant_freqs);
fprintf('Dominująca częstotliwość: %.1f Hz\n', CONFIG.dominant_freq);

ensemble_mean = mean(train_signals, 1);

%% SEKCJA 7: AUGMENTACJA DANYCH TRENINGOWYCH
% Rozszerzenie zbioru treningowego (opcjonalnie)
% --------------------------------------------------
if use_augmentation
    fprintf('\nPRZEPROWADZANIE AUGMENTACJI DANYCH\n');
    fprintf('-------------------------------------------------------------\n');
    [train_signals_aug, train_conditions_aug] = augment_signals_improved(train_signals, train_conditions, CONFIG);
    fprintf('Wygenerowano %d augmentowanych sygnałów\n', size(train_signals_aug, 1));
else
    fprintf('\nAugmentacja danych wyłączona\n');
    train_signals_aug = train_signals;
    train_conditions_aug = train_conditions;
end

if generate_robustness
    fprintf('\nPRZYGOTOWANIE SYGNAŁÓW DO TESTOW ODNOŚNOŚCI\n');
    fprintf('-------------------------------------------------------------\n');
    save(fullfile('Robustness_Signals', 'test_signals.mat'), 'test_signals', 'test_conditions', 'CONFIG');
    fprintf('Zapisano oryginalne sygnały testowe\n');
end

%% SEKCJA 8: EKSTRAKCJA CECH DLA KAŻDEJ METODY
% Główna pętla przetwarzania dla wybranych metod
% --------------------------------------------------
all_features_train = struct();
all_features_test = struct();
all_feature_names = {};
all_method_names = {};
all_stats = struct();

for method_idx = run_methods
    fprintf('\n==============================================================\n');
    fprintf('PRZETWARZANIE METODY %d\n', method_idx);
    fprintf('==============================================================\n');
    
    switch method_idx
        case 1
            fprintf('ANALIZA CZASOWA + FILTROWANIE Pasmowe\n');
            method_name = 'M1_time_domain';
        case 2
            fprintf('MODEL AR(10) Z ALGORYTMEM DURAND-KERNER\n');
            method_name = 'M2_ar_model';
        case 3
            fprintf('FFT + ANALIZA OBWIDNI (HILBERT)\n');
            method_name = 'M3_fft_envelope';
        case 4
            fprintf('DEKOMPOZYCJA FALKOWA + FISHER RATIO\n');
            method_name = 'M4_wavelet';
    end
    
    %% Ekstrakcja cech treningowych
    fprintf('\nEkstrakcja cech treningowych...\n');
    
    switch method_idx
        case 1
            features_train = extract_time_domain_features(train_signals_aug, CONFIG);
        case 2
            features_train = extract_ar_features_durand_kerner(train_signals_aug, ensemble_mean, CONFIG);
        case 3
            features_train = extract_fft_envelope_features(train_signals_aug, CONFIG);
        case 4
            features_train = extract_wavelet_features(train_signals_aug, CONFIG);
    end
    
    all_features_train.(method_name) = features_train.data;
    prefixed_names = strcat(method_name, '_', features_train.names);
    all_feature_names = [all_feature_names, prefixed_names];
    all_method_names{end+1} = method_name;
    
    feature_table_train = array2table(features_train.data, 'VariableNames', features_train.names);
    if use_augmentation
        feature_table_train.Condition = categorical(train_conditions_aug);
    else
        feature_table_train.Condition = categorical(train_conditions');
    end
    
    %% Ekstrakcja cech testowych
    fprintf('Ekstrakcja cech testowych...\n');
    
    switch method_idx
        case 1
            features_test = extract_time_domain_features(test_signals, CONFIG);
        case 2
            features_test = extract_ar_features_durand_kerner(test_signals, ensemble_mean, CONFIG);
        case 3
            features_test = extract_fft_envelope_features(test_signals, CONFIG);
        case 4
            features_test = extract_wavelet_features(test_signals, CONFIG);
    end
    
    all_features_test.(method_name) = features_test.data;
    feature_table_test = array2table(features_test.data, 'VariableNames', features_test.names);
    feature_table_test.Condition = categorical(test_conditions');
    
    %% Obliczenie Fisher Ratio (tylko dla metody 4)
    if method_idx == 4
        fprintf('Obliczanie Fisher Ratio...\n');
        if use_augmentation
            features_train_original = extract_wavelet_features(train_signals, CONFIG);
            fisher_ratios = compute_fisher_ratio_internal(features_train_original.data, train_conditions);
        else
            fisher_ratios = compute_fisher_ratio_internal(features_train.data, train_conditions);
        end
    else
        fisher_ratios = [];
    end
    
    %% Normalizacja cech metodą Z-score
    fprintf('Normalizacja cech (Z-score)...\n');
    stats = compute_normalization_params(feature_table_train);
    all_stats.(method_name) = stats;
    
    feature_table_train_norm = normalize_table(feature_table_train, stats);
    feature_table_test_norm = normalize_table(feature_table_test, stats);
    
    %% Zapis wyników do plików
    train_file = sprintf('FeatureTables/Train/%s_train.mat', method_name);
    test_file = sprintf('FeatureTables/Test/%s_test.mat', method_name);
    
    if method_idx == 4
        save(train_file, 'feature_table_train_norm', 'stats', 'fisher_ratios');
    else
        save(train_file, 'feature_table_train_norm', 'stats');
    end
    save(test_file, 'feature_table_test_norm');
    
    fprintf('Zapisano: %s\n', method_name);
    fprintf('  Trening: %d cech × %d próbek\n', size(feature_table_train_norm, 2)-1, size(feature_table_train_norm, 1));
    fprintf('  Test:    %d cech × %d próbek\n', size(feature_table_test_norm, 2)-1, size(feature_table_test_norm, 1));
    
    %% Generacja testów odporności
    if generate_robustness
        fprintf('\nGENERACJA TESTOW ODNOŚNOŚCI\n');
        fprintf('-------------------------------------------------------------\n');
        generate_robustness_tests_improved_fixed(test_signals, test_conditions, method_idx, ...
            method_name, stats, CONFIG);
    end
    
    %% Przygotowanie danych dla Diagnostic Feature Designer
    fprintf('Tworzenie memberów DFD...\n');
    create_dfd_members(train_signals_aug, train_conditions_aug, method_idx, 'train', CONFIG);
    create_dfd_members(test_signals, test_conditions, method_idx, 'test', CONFIG);
    
    %% Opcjonalne otwarcie DFD
    fprintf('\nDIAGNOSTIC FEATURE DESIGNER\n');
    fprintf('-------------------------------------------------------------\n');
    open_dfd = input(sprintf('Otworzyć DFD dla Metody %d? (t/n) [n]: ', method_idx), 's');
    
    if strcmpi(open_dfd, 't')
        fprintf('Otwieranie DFD dla Metody %d...\n', method_idx);
        ens_train = create_ens_for_method(method_idx, 'train');
        ens_test = create_ens_for_method(method_idx, 'test');
        
        fd_choice = input('Wybierz zbiór: 1-treningowy, 2-testowy, 3-oba [1]: ', 's');
        if isempty(fd_choice), fd_choice = '1'; end
        
        switch fd_choice
            case '1', diagnosticFeatureDesigner(ens_train);
            case '2', diagnosticFeatureDesigner(ens_test);
            case '3'
                diagnosticFeatureDesigner(ens_train);
                pause(2);
                diagnosticFeatureDesigner(ens_test);
        end
    end
    
    fprintf('Metoda %d zakończona pomyślnie\n', method_idx);
end

%% SEKCJA 9: ŁĄCZENIE CECH WSZYSTKICH METOD
% Połączenie cech z różnych metod (opcjonalnie)
% --------------------------------------------------
if run_combined || analyze_feature_importance
    fprintf('\n==============================================================\n');
    fprintf('ŁĄCZENIE CECH WSZYSTKICH METOD\n');
    fprintf('==============================================================\n');
    
    combined_train_data = [];
    combined_test_data = [];
    
    for i = 1:length(all_method_names)
        method = all_method_names{i};
        if isfield(all_features_train, method) && isfield(all_features_test, method)
            fprintf('Metoda %s: %d cech\n', method, size(all_features_train.(method), 2));
            combined_train_data = [combined_train_data, all_features_train.(method)];
            combined_test_data = [combined_test_data, all_features_test.(method)];
        end
    end
    
    if isempty(combined_train_data)
        error('Brak danych do połączenia!');
    end
    
    combined_train_table = array2table(combined_train_data, 'VariableNames', all_feature_names);
    combined_test_table = array2table(combined_test_data, 'VariableNames', all_feature_names);
    
    if use_augmentation
        combined_train_table.Condition = categorical(train_conditions_aug);
    else
        combined_train_table.Condition = categorical(train_conditions');
    end
    combined_test_table.Condition = categorical(test_conditions');
    
    fprintf('\nŁączna liczba cech: %d\n', size(combined_train_data, 2));
    
    fprintf('\nNormalizacja połączonych cech...\n');
    combined_stats = compute_normalization_params(combined_train_table);
    combined_train_norm = normalize_table(combined_train_table, combined_stats);
    combined_test_norm = normalize_table(combined_test_table, combined_stats);
    
    save('FeatureTables/Combined/ALL_METHODS_train.mat', 'combined_train_norm', 'combined_stats', 'all_feature_names', 'all_method_names');
    save('FeatureTables/Combined/ALL_METHODS_test.mat', 'combined_test_norm');
    
    if analyze_feature_importance
        fprintf('\nANALIZA WAŻNOŚCI CECH\n');
        fprintf('-------------------------------------------------------------\n');
        analyze_all_features_importance(combined_train_norm, combined_test_norm, all_feature_names, all_method_names);
    end
end

%% SEKCJA 10: PODSUMOWANIE WYKONANYCH OPERACJI
% Wyświetlenie końcowego raportu
% --------------------------------------------------
fprintf('\n==============================================================\n');
fprintf('GENERACJA ZAKOŃCZONA POMYŚLNIE\n');
fprintf('==============================================================\n\n');

fprintf('WYGENEROWANE PLIKI:\n');
for method_idx = run_methods
    method_name = sprintf('M%d', method_idx);
    fprintf('\nMetoda %d:\n', method_idx);
    fprintf('  FeatureTables/Train/%s_*_train.mat\n', method_name);
    fprintf('  FeatureTables/Test/%s_*_test.mat\n', method_name);
    if generate_robustness
        fprintf('  FeatureTables/Robustness/%s_*.csv (7 plików)\n', method_name);
    end
    fprintf('  DFD_Method%d/train/*.mat\n', method_idx);
    fprintf('  DFD_Method%d/test/*.mat\n', method_idx);
end

if run_combined || analyze_feature_importance
    fprintf('\nPOŁĄCZONE CECHY:\n');
    fprintf('  FeatureTables/Combined/ALL_METHODS_train.mat\n');
    fprintf('  FeatureTables/Combined/ALL_METHODS_test.mat\n');
end

fprintf('\nNASTĘPNE KROKI:\n');
fprintf('1. Classification Learner - trening modeli ML\n');
fprintf('2. Testy odporności - walidacja w warunkach zaburzeń\n');
fprintf('3. Diagnostic Feature Designer - analiza cech\n');

%% ========================================================================
% FUNKCJE POMOCNICZE
% ========================================================================

function [signals, conditions] = load_all_signals(files, folderPath, SAMPLES_PER_EXP)
% WCZYTYWANIE SYGNAŁÓW Z PLIKÓW CSV
%
% Wejście:
%   files           - lista plików CSV
%   folderPath      - ścieżka do folderu z danymi
%   SAMPLES_PER_EXP - wymagana liczba próbek
%
% Wyjście:
%   signals     - macierz sygnałów [N × SAMPLES_PER_EXP]
%   conditions  - etykiety klas
%
% Opis:
%   Wczytano sygnały prądowe z plików CSV. Przeprowadzono weryfikację
%   liczby próbek i przypisano odpowiednie etykiety klas.

    signals = [];
    conditions = {};
    
    for fileIdx = 1:length(files)
        data = readtable(fullfile(folderPath, files{fileIdx}));
        data.Properties.VariableNames = strrep(data.Properties.VariableNames, ' ', '_');
        data.Properties.VariableNames = strrep(data.Properties.VariableNames, '-', '_');
        
        if contains(files{fileIdx}, 'healthy') && contains(files{fileIdx}, 'zip')
            condition = 'Mech_Damage';
        elseif contains(files{fileIdx}, 'healthy')
            condition = 'Healthy';
        elseif contains(files{fileIdx}, 'faulty') && contains(files{fileIdx}, 'zip')
            condition = 'Mech_Elec_Damage';
        else
            condition = 'Elec_Damage';
        end
        
        if ismember('Current_A', data.Properties.VariableNames)
            current_col = 'Current_A';
        else
            current_col = 'Current';
        end
        
        if ismember('Experiment_ID', data.Properties.VariableNames)
            exp_id_col = 'Experiment_ID';
        else
            exp_id_col = 'ExperimentID';
        end
        
        experiments = unique(data.(exp_id_col));
        
        for exp_id = experiments'
            exp_mask = data.(exp_id_col) == exp_id;
            exp_data = data(exp_mask, :);
            
            if height(exp_data) == SAMPLES_PER_EXP
                signal = exp_data.(current_col);
                signals = [signals; signal(:)']; %#ok<AGROW>
                conditions{end+1} = condition; %#ok<AGROW>
            end
        end
    end
end

function [aug_signals, aug_conditions] = augment_signals_improved(signals, conditions, CONFIG)
% AUGMENTACJA SYGNAŁÓW TRENINGOWYCH
%
% Wejście:
%   signals     - oryginalne sygnały
%   conditions  - etykiety klas
%   CONFIG      - struktura konfiguracyjna
%
% Wyjście:
%   aug_signals    - augmentowane sygnały
%   aug_conditions - etykiety augmentowanych sygnałów
%
% Opis:
%   Przeprowadzono augmentację sygnałów poprzez:
%   1. Skalowanie amplitudy (3 poziomy)
%   2. Przesunięcie częstotliwości (3 poziomy)
%   3. Dodanie szumu gaussowskiego (2 poziomy)
%   Otrzymano ~18× więcej sygnałów.

    amp_levels = CONFIG.augmentation.amp_levels;
    freq_shifts = CONFIG.augmentation.freq_shifts;
    noise_levels = CONFIG.augmentation.noise_levels;
    
    num_original = size(signals, 1);
    num_aug_per_signal = length(amp_levels) * length(freq_shifts) * length(noise_levels);
    num_total = num_original * (num_aug_per_signal + 1);
    
    aug_signals = zeros(num_total, size(signals, 2));
    aug_conditions = cell(num_total, 1);
    
    aug_signals(1:num_original, :) = signals;
    for i = 1:num_original
        aug_conditions{i} = conditions{i};
    end
    
    idx = num_original + 1;
    
    fprintf('Parametry augmentacji:\n');
    fprintf('  Amplituda: %d poziomów (%.1f-%.1fx)\n', length(amp_levels), min(amp_levels), max(amp_levels));
    fprintf('  Częstotliwość: %d przesunięć (%.1f-%.1fx)\n', length(freq_shifts), min(freq_shifts), max(freq_shifts));
    fprintf('  Szum: %d poziomów (%.1f-%.1f%%)\n', length(noise_levels), noise_levels(1)*100, noise_levels(end)*100);
    
    t = (0:CONFIG.SAMPLES_PER_EXP-1) / CONFIG.Fs;
    
    for orig_idx = 1:num_original
        original_signal = signals(orig_idx, :);
        original_condition = conditions{orig_idx};
        
        for amp = amp_levels
            for freq_shift = freq_shifts
                for noise_level = noise_levels
                    
                    augmented = original_signal * amp;
                    
                    if freq_shift ~= 1.0
                        freq_change_hz = CONFIG.dominant_freq * (freq_shift - 1);
                        phase_mod = 2 * pi * freq_change_hz * t;
                        
                        if abs(freq_change_hz) < 50
                            augmented = augmented .* cos(phase_mod);
                        else
                            doppler_factor = 1 + (freq_shift - 1) * 0.3;
                            time_scaled = t * doppler_factor;
                            augmented = interp1(t, augmented, time_scaled, 'spline', 'extrap');
                        end
                    end
                    noise = noise_level * std(original_signal) * randn(1, CONFIG.SAMPLES_PER_EXP);
                augmented = augmented + noise;
                
                aug_signals(idx, :) = augmented;
                aug_conditions{idx} = original_condition;
                idx = idx + 1;
                
            end
        end
    end
    
    if mod(orig_idx, 10) == 0
        fprintf('  Postęp: %d/%d\n', orig_idx, num_original);
    end
end

rows_with_nan = any(isnan(aug_signals), 2);
if any(rows_with_nan)
    fprintf('  Usunięto %d wierszy z wartościami NaN\n', sum(rows_with_nan));
    aug_signals = aug_signals(~rows_with_nan, :);
    aug_conditions = aug_conditions(~rows_with_nan);
end

fprintf('  Wygenerowano łącznie %d sygnałów\n', size(aug_signals, 1));
end
function [freq, amp] = compute_dominant_frequency_improved(signal, Fs)
% OBLICZANIE DOMINUJĄCEJ CZĘSTOTLIWOŚCI SYGNAŁU METODĄ FFT
%
% Wejście:
%   signal - wektor sygnału czasowego
%   Fs     - częstotliwość próbkowania [Hz]
%
% Wyjście:
%   freq - dominująca częstotliwość [Hz]
%   amp  - amplituda składowej dominującej
%
% Opis:
%   Obliczono dominującą częstotliwość sygnału metodą FFT.
%   W pierwszym kroku usunięto składową stałą (średnią).
%   Następnie zastosowano szybką transformatę Fouriera.
%   Wyszukano maksimum widma w zakresie 10-500 Hz.
%   W przypadku braku maksimum w tym zakresie wybrano globalne maksimum.
%
% Algorytm:
%   1. Usunięto składową stałą
%   2. Obliczono FFT
%   3. Przeskalowano widmo
%   4. Znaleziono maksimum w określonym zakresie
%   5. Przeprowadzono walidację wyników

    N = length(signal);
    signal = signal - mean(signal);

    Y = fft(signal);
    P2 = abs(Y/N);
    P1 = P2(1:floor(N/2)+1);
    P1(2:end-1) = 2*P1(2:end-1);

    f = Fs*(0:(N/2))/N;

    freq_range = find(f >= 10 & f <= 500);
    if ~isempty(freq_range)
        [amp, idx_in_range] = max(P1(freq_range));
        idx = freq_range(idx_in_range);
        freq = f(idx);
    else
        [amp, idx] = max(P1(2:end));
        freq = f(idx+1);
    end

    if freq == 0 || isnan(freq) || isinf(freq)
        freq = 100;
        amp = 0.1;
    end
end

function generate_robustness_tests_improved_fixed(test_signals, test_conditions, method_idx, ...
    method_name, train_stats, CONFIG)
% GENEROWANIE TESTOW ODNOŚNOŚCI (ROBUSTNESS)
%
% Wejście:
%   test_signals    - macierz sygnałów testowych
%   test_conditions - etykiety klas dla sygnałów testowych
%   method_idx      - indeks metody (1-4)
%   method_name     - nazwa metody
%   train_stats     - statystyki normalizacji ze zbioru treningowego
%   CONFIG          - struktura konfiguracyjna systemu
%
% Wyjście:
%   Pliki CSV w folderze FeatureTables/Robustness/
%   Zmienne w przestrzeni roboczej MATLAB
%
% Opis:
%   Wygenerowano 7 zestawów testowych do oceny odporności modeli.
%   Każdy zestaw symuluje inne zakłócenia występujące w rzeczywistych
%   warunkach pracy silnika BLDC w dronie.
%
% Scenariusze testowe:
%   1. Oryginalne dane (referencyjne)
%   2. Przesunięcie częstotliwości
%   3. Fluktuacja amplitudy
%   4. Szum gaussowski
%   5. Kombinacja zakłóceń
%   6. Ekstremalne zmiany amplitudy
%   7. Nieznany rozkład (out-of-distribution)

    folder = 'FeatureTables/Robustness/';
    num_samples = size(test_signals, 1);

    fprintf('   Rozpoczęto generowanie 7 zestawów testowych...\n');

    %% 1. ORYGINALNE DANE
    fprintf('   1. Oryginalne dane...\n');
    features_original = extract_features_by_method(test_signals, method_idx, CONFIG);
    test_original_table = array2table(features_original);
    test_original_table.Condition = categorical(test_conditions');
    test_original_norm = normalize_with_stats_fixed(test_original_table, train_stats);
    writetable(test_original_norm, [folder method_name '_test_original_norm.csv']);
    assignin('base', [method_name '_test_original_norm'], test_original_norm);

    %% 2. PRZESUNIĘCIE CZĘSTOTLIWOŚCI
    fprintf('   2. Przesunięcie częstotliwości...\n');
    test_signals_freq = apply_frequency_shift_batch(test_signals, CONFIG.Fs, ...
        CONFIG.dominant_freq, CONFIG.robustness.freq_shift_levels(3));
    features_freq = extract_features_by_method(test_signals_freq, method_idx, CONFIG);
    test_freq_table = array2table(features_freq);
    test_freq_table.Condition = categorical(test_conditions');
    test_freq_norm = normalize_with_stats_fixed(test_freq_table, train_stats);
    writetable(test_freq_norm, [folder method_name '_test_freq_shift_norm.csv']);
    assignin('base', [method_name '_test_freq_shift_norm'], test_freq_norm);

    %% 3. FLUKTUACJA AMPLITUDY
    fprintf('   3. Fluktuacja amplitudy...\n');
    scale_factors = CONFIG.robustness.amp_range(1) + ...
        rand(num_samples, 1) * (CONFIG.robustness.amp_range(2) - CONFIG.robustness.amp_range(1));
    test_signals_amp = zeros(size(test_signals));
    for i = 1:num_samples
        test_signals_amp(i, :) = test_signals(i, :) * scale_factors(i);
    end
    features_amp = extract_features_by_method(test_signals_amp, method_idx, CONFIG);
    test_amp_table = array2table(features_amp);
    test_amp_table.Condition = categorical(test_conditions');
    test_amp_norm = normalize_with_stats_fixed(test_amp_table, train_stats);
    writetable(test_amp_norm, [folder method_name '_test_amp_fluctuation_norm.csv']);
    assignin('base', [method_name '_test_amp_fluctuation_norm'], test_amp_norm);

    %% 4. SZUM GAUSSOWSKI
    fprintf('   4. Szum gaussowski...\n');
    test_signals_noise = zeros(size(test_signals));
    for i = 1:num_samples
        signal = test_signals(i, :);
        noise = CONFIG.robustness.noise_level * std(signal) * randn(1, length(signal));
        test_signals_noise(i, :) = signal + noise;
    end
    features_noise = extract_features_by_method(test_signals_noise, method_idx, CONFIG);
    test_noise_table = array2table(features_noise);
    test_noise_table.Condition = categorical(test_conditions');
    test_noise_norm = normalize_with_stats_fixed(test_noise_table, train_stats);
    writetable(test_noise_norm, [folder method_name '_test_noise_norm.csv']);
    assignin('base', [method_name '_test_noise_norm'], test_noise_norm);

    %% 5. KOMBINACJA ZAKŁÓCEŃ
    fprintf('   5. Kombinacja zakłóceń...\n');
    test_signals_combined = zeros(size(test_signals));
    for i = 1:num_samples
        signal = test_signals(i, :);
        amp_factor = CONFIG.robustness.amp_range(1) + rand * (CONFIG.robustness.amp_range(2) - CONFIG.robustness.amp_range(1));
        signal = apply_frequency_shift(signal * amp_factor, CONFIG.Fs, CONFIG.dominant_freq, CONFIG.robustness.freq_shift_levels(3));
        noise = CONFIG.robustness.combined_noise * std(test_signals(i, :)) * randn(1, length(signal));
        test_signals_combined(i, :) = signal + noise;
    end
    features_combined = extract_features_by_method(test_signals_combined, method_idx, CONFIG);
    test_combined_table = array2table(features_combined);
    test_combined_table.Condition = categorical(test_conditions');
    test_combined_norm = normalize_with_stats_fixed(test_combined_table, train_stats);
    writetable(test_combined_norm, [folder method_name '_test_combined_norm.csv']);
    assignin('base', [method_name '_test_combined_norm'], test_combined_norm);

    %% 6. EKSTREMALNE ZMIANY AMPLITUDY
    fprintf('   6. Ekstremalne zmiany amplitudy...\n');
    scale_extreme = 0.5 + rand(num_samples, 1) * 1.5;
    test_signals_extreme = zeros(size(test_signals));
    for i = 1:num_samples
        test_signals_extreme(i, :) = test_signals(i, :) * scale_extreme(i);
    end
    features_extreme = extract_features_by_method(test_signals_extreme, method_idx, CONFIG);
    test_extreme_table = array2table(features_extreme);
    test_extreme_table.Condition = categorical(test_conditions');
    test_extreme_norm = normalize_with_stats_fixed(test_extreme_table, train_stats);
    writetable(test_extreme_norm, [folder method_name '_test_amp_extreme_norm.csv']);
    assignin('base', [method_name '_test_amp_extreme_norm'], test_extreme_norm);

    %% 7. NIEZNANY ROZKŁAD (OUT-OF-DISTRIBUTION)
    fprintf('   7. Nieznany rozkład...\n');
    test_signals_unknown = zeros(size(test_signals));
    for i = 1:num_samples
        orig_signal = test_signals(i, :);
        test_signals_unknown(i, :) = min(orig_signal) + rand(1, length(orig_signal)) * (max(orig_signal) - min(orig_signal));
    end
    features_unknown = extract_features_by_method(test_signals_unknown, method_idx, CONFIG);
    test_unknown_table = array2table(features_unknown);
    known_label = test_conditions{1}; 
    test_unknown_table.Condition = categorical(repmat({known_label}, num_samples, 1));
    test_unknown_norm = normalize_with_stats_fixed(test_unknown_table, train_stats);
    writetable(test_unknown_norm, [folder method_name '_test_unknown_norm.csv']);
    assignin('base', [method_name '_test_unknown_norm'], test_unknown_norm);
end

function features = extract_features_by_method(signals, method_idx, CONFIG)
% WYWOŁYWANIE FUNKCJI EKSTRAKCJI CECH DLA OKREŚLONEJ METODY
%
% Wejście:
%   signals    - macierz sygnałów [N × SAMPLES_PER_EXP]
%   method_idx - indeks metody (1-4)
%   CONFIG     - struktura konfiguracyjna systemu
%
% Wyjście:
%   features - macierz cech [N × liczba_cech]
%
% Opis:
%   Wywołano odpowiednią funkcję ekstrakcji cech w zależności
%   od wybranej metody. Funkcja pełni rolę wrappera, który
%   zapewnia jednolity interfejs dla różnych metod ekstrakcji.
%
% Metody:
%   1 - Analiza czasowa z filtrowaniem pasmowym
%   2 - Model AR z algorytmem Durand-Kernera
%   3 - FFT z analizą obwiedni
%   4 - Dekompozycja falkowa z Fisher Ratio

    if isempty(signals)
        error('Próba ekstrakcji cech z pustych sygnałów!');
    end

    switch method_idx
        case 1
            result = extract_time_domain_features(signals, CONFIG);
        case 2
            ensemble_mean = mean(signals, 1);
            result = extract_ar_features_durand_kerner(signals, ensemble_mean, CONFIG);
        case 3
            result = extract_fft_envelope_features(signals, CONFIG);
        case 4
            result = extract_wavelet_features(signals, CONFIG);
        otherwise
            error('Nieznana metoda: %d', method_idx);
    end

    if ~isfield(result, 'data')
        error('Funkcja ekstrakcji nie zwróciła pola "data"');
    end

    features = result.data;
end

function shifted_signals = apply_frequency_shift_batch(signals, Fs, dominant_freq, freq_shift)
% PRZESUNIĘCIE CZĘSTOTLIWOŚCI DLA GRUPY SYGNAŁÓW
%
% Wejście:
%   signals       - macierz sygnałów [N × liczba_próbek]
%   Fs            - częstotliwość próbkowania [Hz]
%   dominant_freq - dominująca częstotliwość sygnału [Hz]
%   freq_shift    - współczynnik przesunięcia częstotliwości
%
% Wyjście:
%   shifted_signals - macierz przesuniętych sygnałów
%
% Opis:
%   Zastosowano przesunięcie częstotliwości dla całej grupy sygnałów.
%   Wykorzystano modulację fazy z częstotliwością proporcjonalną
%   do dominującej częstotliwości sygnału.
%
% Wzór:
%   shifted_signal(t) = original_signal(t) × cos(2π × Δf × t)
%   gdzie Δf = dominant_freq × (freq_shift - 1)

    num_signals = size(signals, 1);
    signal_length = size(signals, 2);
    shifted_signals = zeros(num_signals, signal_length);

    t = (0:signal_length-1) / Fs;

    for i = 1:num_signals
        signal = signals(i, :);
        
        if freq_shift ~= 1.0
            freq_change_hz = dominant_freq * (freq_shift - 1);
            phase_mod = 2 * pi * freq_change_hz * t;
            shifted_signals(i, :) = signal .* cos(phase_mod);
        else
            shifted_signals(i, :) = signal;
        end
    end
end

function shifted_signal = apply_frequency_shift(signal, Fs, dominant_freq, freq_shift)
% PRZESUNIĘCIE CZĘSTOTLIWOŚCI DLA POJEDYNCZEGO SYGNAŁU
%
% Wejście:
%   signal        - wektor sygnału
%   Fs            - częstotliwość próbkowania [Hz]
%   dominant_freq - dominująca częstotliwość sygnału [Hz]
%   freq_shift    - współczynnik przesunięcia częstotliwości
%
% Wyjście:
%   shifted_signal - przesunięty sygnał
%
% Opis:
%   Zastosowano przesunięcie częstotliwości dla pojedynczego sygnału.
%   Metoda opiera się na modulacji fazy.

    t = (0:length(signal)-1) / Fs;

    if freq_shift ~= 1.0
        freq_change_hz = dominant_freq * (freq_shift - 1);
        phase_mod = 2 * pi * freq_change_hz * t;
        shifted_signal = signal .* cos(phase_mod);
    else
        shifted_signal = signal;
    end
end

function stats = compute_normalization_params(feature_table)
% OBLICZANIE PARAMETRÓW NORMALIZACJI Z-SCORE
%
% Wejście:
%   feature_table - tabela cech (ostatnia kolumna: Condition)
%
% Wyjście:
%   stats - struktura z parametrami normalizacji:
%     .names - nazwy cech
%     .means - średnie wartości cech
%     .stds  - odchylenia standardowe cech
%
% Opis:
%   Obliczono parametry normalizacji Z-score na podstawie
%   danych treningowych. Dla cech o zerowym odchyleniu
%   standardowym ustawiono małą wartość (1e-10) aby uniknąć
%   dzielenia przez zero.

    feature_data = table2array(feature_table(:, 1:end-1));
    stats = struct();
    stats.names = feature_table.Properties.VariableNames(1:end-1);
    stats.means = mean(feature_data, 1);
    stats.stds = std(feature_data, 0, 1);
    stats.stds(stats.stds == 0) = 1e-10;
end

function normalized_table = normalize_table(feature_table, stats)
% NORMALIZACJA TABELI CECH METODĄ Z-SCORE
%
% Wejście:
%   feature_table - tabela cech do normalizacji
%   stats         - struktura z parametrami normalizacji
%
% Wyjście:
%   normalized_table - znormalizowana tabela cech
%
% Opis:
%   Znormalizowano cechy metodą Z-score.
%   Zachowano kolumnę Condition z oryginalnej tabeli.
%
% Wzór:
%   x_norm = (x - μ) / σ

    feature_data = table2array(feature_table(:, 1:end-1));
    normalized_data = (feature_data - stats.means) ./ stats.stds;
    normalized_table = array2table(normalized_data, 'VariableNames', stats.names);
    normalized_table.Condition = feature_table.Condition;
end

function tbl_norm = normalize_with_stats_fixed(tbl, stats)
% NORMALIZACJA Z WYKORZYSTANIEM WYCZEŚNIOWO OBLICZONYCH STATYSTYK
%
% Wejście:
%   tbl   - tabela cech do normalizacji
%   stats - struktura ze statystykami ze zbioru treningowego
%
% Wyjście:
%   tbl_norm - znormalizowana tabela cech
%
% Opis:
%   Znormalizowano cechy wykorzystując wcześniej obliczone
%   statystyki (średnie i odchylenia standardowe).
%   W przypadku niezgodności liczby kolumn dostosowano
%   wymiary do mniejszej wartości.

    feature_data = table2array(tbl(:, 1:end-1));

    if size(feature_data, 2) ~= length(stats.means)
        min_cols = min(size(feature_data, 2), length(stats.means));
        feature_data = feature_data(:, 1:min_cols);
        stats.means = stats.means(1:min_cols);
        stats.stds = stats.stds(1:min_cols);
        stats.names = stats.names(1:min_cols);
    end

    normalized_data = (feature_data - stats.means) ./ stats.stds;
    tbl_norm = array2table(normalized_data, 'VariableNames', stats.names);

    if ismember('Condition', tbl.Properties.VariableNames)
        tbl_norm.Condition = tbl.Condition;
    end
end

function fisher_ratios = compute_fisher_ratio_internal(feature_matrix, conditions)
% OBLICZANIE FISHER RATIO DLA CECH
%
% Wejście:
%   feature_matrix - macierz cech [N × liczba_cech]
%   conditions     - wektor etykiet klas
%
% Wyjście:
%   fisher_ratios - wektor wartości Fisher Ratio dla każdej cechy
%
% Opis:
%   Obliczono współczynnik Fisher Ratio dla każdej cechy.
%   Fisher Ratio mierzy zdolność cechy do rozróżniania klas.
%   Wyższa wartość oznacza lepszą separacyjność.
%
% Wzór:
%   FR = międzyklasowa_wariancja / wewnątrzklasowa_wariancja

    num_features = size(feature_matrix, 2);
    fisher_ratios = zeros(1, num_features);
    unique_classes = unique(conditions);
    num_classes = length(unique_classes);

    for feat_idx = 1:num_features
        feature_data = feature_matrix(:, feat_idx);
        overall_mean = mean(feature_data);
        
        class_sizes = zeros(num_classes, 1);
        class_means = zeros(num_classes, 1);
        class_vars = zeros(num_classes, 1);
        
        for class_idx = 1:num_classes
            class_name = unique_classes{class_idx};
            class_mask = strcmp(conditions, class_name);
            class_data = feature_data(class_mask);
            class_sizes(class_idx) = length(class_data);
            class_means(class_idx) = mean(class_data);
            class_vars(class_idx) = var(class_data, 1);
        end
        
        bc_var = 0;
        total_samples = sum(class_sizes);
        for class_idx = 1:num_classes
            bc_var = bc_var + class_sizes(class_idx) * (class_means(class_idx) - overall_mean)^2;
        end
        bc_var = bc_var / total_samples;
        
        wc_var = 0;
        for class_idx = 1:num_classes
            wc_var = wc_var + class_sizes(class_idx) * class_vars(class_idx);
        end
        wc_var = wc_var / total_samples;
        
        if wc_var > 1e-10
            fisher_ratios(feat_idx) = bc_var / wc_var;
        else
            fisher_ratios(feat_idx) = 0;
        end
    end

    fprintf('   Fisher Ratio: mediana=%.4f, maksimum=%.4f\n', median(fisher_ratios), max(fisher_ratios));
end

function create_dfd_members(signals, conditions, method_idx, mode, CONFIG)
% TWORZENIE PLIKÓW MEMBER DLA DIAGNOSTIC FEATURE DESIGNER
%
% Wejście:
%   signals     - macierz sygnałów
%   conditions  - etykiety klas
%   method_idx  - indeks metody (1-4)
%   mode        - tryb ('train' lub 'test')
%   CONFIG      - struktura konfiguracyjna systemu
%
% Wyjście:
%   Pliki .mat w folderze DFD_Method[method_idx]/[mode]/
%
% Opis:
%   Utworzono pliki member dla Diagnostic Feature Designer.
%   Każdy plik zawiera sygnał w formacie timetable, etykietę
%   klasy oraz indeks sygnału.
%
% Struktura pliku:
%   Current     - timetable z sygnałem prądowym
%   Condition   - etykieta klasy
%   SignalIndex - indeks sygnału

    dfd_folder = sprintf('DFD_Method%d/%s', method_idx, mode);
    Fs = CONFIG.Fs;

    for sig_idx = 1:size(signals, 1)
        signal = signals(sig_idx, :)';
        condition = conditions{sig_idx};
        
        t = seconds((0:length(signal)-1)'/Fs);
        Current = timetable(t, signal, 'VariableNames', {'Current'});
        Current.Properties.SampleRate = Fs;
        
        Condition = condition;
        SignalIndex = sig_idx;
        
        fname = sprintf('member_%03d.mat', sig_idx);
        save(fullfile(dfd_folder, fname), 'Current', 'Condition', 'SignalIndex');
    end

    fprintf('   Utworzono %d memberów DFD (%s)\n', size(signals, 1), mode);
end