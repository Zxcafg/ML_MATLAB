function ens = create_ens_for_method(method_num, mode)
% CREATE_ENS_FOR_METHOD - TWORZENIE ENSEMBLE DATASTORE DLA DIAGNOSTIC FEATURE DESIGNER
% ==============================================================================
%
% Plik:        create_ens_for_method.m
% Autor:       Pavel Tshonek (155068)
% Data:        2026-01
% Opis:        Główna funkcja konfigurująca fileEnsembleDatastore dla 4 metod
%               analizy sygnałów prądowych silników BLDC
%
% SYSTEM AUTOMATYCZNEJ KONFIGURACJI DFD DLA DIAGNOSTYKI SILNIKÓW BLDC
% ------------------------------------------------------------------------------
% Funkcja stanowi kluczowy interfejs pomiędzy ekstrakcją cech a narzędziem
% Diagnostic Feature Designer (DFD) w MATLAB Predictive Maintenance Toolbox.
% Umożliwia automatyczną konfigurację fileEnsembleDatastore dla czterech
% metod analizy sygnałów prądowych z wykorzystaniem zaawansowanych technik
% przetwarzania sygnałów.
%
% STRUKTURA METOD ANALIZY:
%   M1: Analiza czasowa + filtrowanie 6 pasm częstotliwości (49 cech)
%   M2: Model AR(10) z algorytmem Durand-Kerner (15 cech)
%   M3: FFT + Analiza obwiedni (transformata Hilberta) (96 cech)
%   M4: Dekompozycja falkowa (fala db4, 8 poziomów) (54 cech)
%
% KLASYFIKACJA STANÓW SILNIKA:
%   1. Zdrowy (Healthy)
%   2. Uszkodzenie mechaniczne (Mech_Damage)
%   3. Uszkodzenie elektryczne (Elec_Damage)
%   4. Uszkodzenie kombinowane (Mech_Elec_Damage)
%
% ARCHITEKTURA SYSTEMU:
%   1. Walidacja parametrów wejściowych
%   2. Ładowanie struktury folderów z danymi
%   3. Konfiguracja fileEnsembleDatastore
%   4. Definicja DataVariables i ConditionVariables
%   5. Ustawienie funkcji odczytu (ReadFcn) dla każdej metody
%   6. Przypisanie do przestrzeni roboczej MATLAB
%   7. Wygenerowanie instrukcji dla użytkownika
%
% PARAMETRY TECHNICZNE:
%   Częstotliwość próbkowania: Fs = 50 kHz
%   Liczba próbek: 32768 (2^15)
%   Rząd modelu AR: p_ar = 10
%   Pasma częstotliwości: 
%     [100-500, 500-2000, 2000-5000, 5000-10000, 10000-15000, 15000-20000] Hz
%   Fala falkowa: 'db4', poziom dekompozycji: 8
%
% STRUKTURA FOLDERÓW:
%   DFD_Method1/           # Metoda 1: Analiza czasowa
%   ├── train/            # Zbiór treningowy
%   └── test/             # Zbiór testowy
%   DFD_Method2/          # Metoda 2: Model AR
%   ├── train/
%   └── test/
%   DFD_Method3/          # Metoda 3: FFT + Envelope
%   ├── train/
%   └── test/
%   DFD_Method4/          # Metoda 4: Wavelet
%   ├── train/
%   └── test/
%
% WEJŚCIE:
%   method_num - numer metody (1, 2, 3, 4)
%   mode       - tryb pracy ('train' lub 'test')
%
% WYJŚCIE:
%   ens - obiekt fileEnsembleDatastore skonfigurowany dla wybranej metody
%
% PRZYKŁAD UŻYCIA:
%   >> ens_M1_train = create_ens_for_method(1, 'train');
%   >> ens_M1_test = create_ens_for_method(1, 'test');
%   >> diagnosticFeatureDesigner(ens_M1_train);
%
% AUTORSTWO:
%   Implementacja:         Pavel Tshonek
%   Algorytmy ekstrakcji:  MATLAB Diagnostic Feature Designer
%   Dataset:               DUDU-BLDC (AGH Kraków)
%   Koncepcja systemu:     Praca dyplomowa - Zastosowanie wybranych metod uczenia maszynowego do wykrywania uszkodzeń napędu elektrycznego drona
%
% ==============================================================================

% Sprawdzenie liczby argumentów wejściowych
if nargin < 2
    mode = 'train';
    fprintf('Użyto domyślnego trybu: train\n');
end

% WALIDACJA PARAMETRÓW WEJŚCIOWYCH
% --------------------------------
if ~ismember(method_num, 1:4)
    error('method_num musi być liczbą całkowitą z zakresu 1-4!');
end

if ~ismember(mode, {'train', 'test'})
    error('mode musi być ''train'' lub ''test''!');
end

fprintf('\n========================================================================\n');
fprintf('KONFIGURACJA ENSEMBLE DATASTORE - METODA %d (%s)\n', method_num, upper(mode));
fprintf('========================================================================\n\n');

% ŚCIEŻKA DO DANYCH
% -----------------
dfd_folder = sprintf('DFD_Method%d/%s', method_num, mode);

if ~exist(dfd_folder, 'dir')
    error('Folder %s nie istnieje! Uruchom najpierw master_generator.m', dfd_folder);
end

% TWORZENIE FILEENSEMBLEDATASTORE
% --------------------------------
fprintf('Tworzenie fileEnsembleDatastore...\n');
fprintf('Ścieżka: %s\n', dfd_folder);
fprintf('Rozszerzenie plików: .mat\n\n');

ens = fileEnsembleDatastore(dfd_folder, '.mat');

% KONFIGURACJA CZĘSTOTLIWOŚCI PRÓBKOWANIA
% ----------------------------------------
Fs = 50000;  % 50 kHz
fprintf('Częstotliwość próbkowania: Fs = %d Hz\n', Fs);

%% ============================================================================
%% KONFIGURACJA ZMIENNYCH DLA POSZCZEGÓLNYCH METOD
%% ============================================================================

switch method_num
    case 1
        % METODA 1: ANALIZA CZASOWA + FILTROWANIE PASMOWE
        % --------------------------------------------------
        fprintf('\nKONFIGURACJA METODY 1 - ANALIZA CZASOWA\n');
        fprintf('--------------------------------------------------------------\n');
        fprintf('Liczba cech: 49\n');
        fprintf('Pasma częstotliwości: 6\n');
        fprintf('Typy cech: czasowe, spektralne, harmoniczne, pasmowe\n');
        
        % Definicja zmiennych danych
        ens.DataVariables = [
            "Current",              % Sygnał prądowy (timetable)
            "Current_Spectrum",     % Widmo sygnału
            "Current_AllFeatures"   % Wszystkie 49 cech
        ];
        
        % Zmienna warunkowa (etykieta klasy)
        ens.ConditionVariables = "Condition";
        
        % Zmienne wybrane do wyświetlania
        ens.SelectedVariables = [
            "Current", 
            "Current_AllFeatures", 
            "Condition"
        ];
        
        % Definicja pasm częstotliwości
        freq_bands = [
            100,   500;
            500,   2000;
            2000,  5000;
            5000,  10000;
            10000, 15000;
            15000, 20000
        ];
        
        % Funkcja odczytu dla metody 1
        ens.ReadFcn = @(fname, vars) readDFDMember_Method1(fname, vars, freq_bands, Fs);
        
    case 2
        % METODA 2: MODEL AUTOREGRESYJNY AR(10)
        % --------------------------------------------------
        fprintf('\nKONFIGURACJA METODY 2 - MODEL AR(10)\n');
        fprintf('--------------------------------------------------------------\n');
        fprintf('Liczba cech: 15\n');
        fprintf('Rząd modelu: p = 10\n');
        fprintf('Algorytm: Levinson-Durbin + Durand-Kerner\n');
        
        ens.DataVariables = [
            "Current",              % Sygnał prądowy
            "Current_AllFeatures"   % Wszystkie 15 cech AR
        ];
        
        ens.ConditionVariables = "Condition";
        ens.SelectedVariables = [
            "Current", 
            "Current_AllFeatures", 
            "Condition"
        ];
        
        % Parametry modelu AR
        p_ar = 10;
        
        % Funkcja odczytu dla metody 2
        ens.ReadFcn = @(fname, vars) readDFDMember_Method2(fname, vars, p_ar, Fs);
        
    case 3
        % METODA 3: FFT + ANALIZA OBWIDNI
        % --------------------------------------------------
        fprintf('\nKONFIGURACJA METODY 3 - FFT + ANALIZA OBWIDNI\n');
        fprintf('--------------------------------------------------------------\n');
        fprintf('Liczba cech: 96\n');
        fprintf('Pasma częstotliwości: 6\n');
        fprintf('Transformacja: FFT + Hilbert + FFT obwiedni\n');
        
        ens.DataVariables = [
            "Current",                      % Sygnał prądowy
            "Current_Spectrum",             % Widmo FFT
            "Current_Envelope_Spectrum",    % Widmo obwiedni
            "Current_AllFeatures"           % Wszystkie 96 cech
        ];
        
        ens.ConditionVariables = "Condition";
        ens.SelectedVariables = [
            "Current", 
            "Current_Spectrum",
            "Current_Envelope_Spectrum", 
            "Current_AllFeatures",
            "Condition"
        ];
        
        % Definicja pasm częstotliwości
        freq_bands = [
            100,   500;
            500,   2000;
            2000,  5000;
            5000,  10000;
            10000, 15000;
            15000, 20000
        ];
        
        % Funkcja odczytu dla metody 3
        ens.ReadFcn = @(fname, vars) readDFDMember_Method3(fname, vars, freq_bands, Fs);
        
    case 4
        % METODA 4: TRANSFORMATA FALKOWA
        % --------------------------------------------------
        fprintf('\nKONFIGURACJA METODY 4 - TRANSFORMATA FALKOWA\n');
        fprintf('--------------------------------------------------------------\n');
        fprintf('Liczba cech: 54\n');
        fprintf('Fala falkowa: db4\n');
        fprintf('Poziom dekompozycji: 8\n');
        fprintf('Cechy na poziom: energia, RMS, kurtoza, entropia, skośność, Peak2RMS\n');
        
        ens.DataVariables = [
            "Current",              % Sygnał prądowy
            "Current_AllFeatures"   % Wszystkie 54 cech falkowych
        ];
        
        ens.ConditionVariables = "Condition";
        ens.SelectedVariables = [
            "Current", 
            "Current_AllFeatures", 
            "Condition"
        ];
        
        % Parametry transformaty falkowej
        wavelet_name = 'db4';
        level = 8;
        
        % Funkcja odczytu dla metody 4
        ens.ReadFcn = @(fname, vars) readDFDMember_Method4(fname, vars, wavelet_name, level);
        
    otherwise
        error('Nieznana metoda: %d', method_num);
end

%% ============================================================================
%% PRZYPISANIE DO PRZESTRZENI ROBOCZEJ I PODSUMOWANIE
%% ============================================================================

% Utworzenie nazwy zmiennej
var_name = sprintf('ens_M%d_%s', method_num, mode);

% Przypisanie do przestrzeni roboczej MATLAB
assignin('base', var_name, ens);

% PODSUMOWANIE KONFIGURACJI
% --------------------------
fprintf('\n========================================================================\n');
fprintf('KONFIGURACJA ZAKOŃCZONA POMYŚLNIE\n');
fprintf('========================================================================\n\n');

fprintf(' ENSEMBLE DATASTORE GOTOWY\n');
fprintf('   Zmienna w workspace: %s\n', var_name);
fprintf('   Folder z danymi: %s\n', dfd_folder);
fprintf('   Liczba memberów: %d\n', length(ens.Files));
fprintf('   Zmienne danych: %s\n', strjoin(string(ens.DataVariables), ', '));
fprintf('   Zmienne warunkowe: %s\n', strjoin(string(ens.ConditionVariables), ', '));

fprintf('\n NASTĘPNE KROKI:\n');
fprintf('   1. >> diagnosticFeatureDesigner\n');
fprintf('   2. → New Session\n');
fprintf('   3. → Select "%s"\n', var_name);
fprintf('   4. → Configure ensemble datastore\n');
fprintf('   5. → Extract features and train models\n');

fprintf('\n INFORMACJE TECHNICZNE:\n');
fprintf('   Typ obiektu: %s\n', class(ens));
    if isprop(ens, 'FileExtensions')
        fprintf('   Wspierane pliki: %s\n', ens.FileExtensions);
    else
        fprintf('   Wspierane pliki: .mat\n');
    end
fprintf('   ReadFcn: %s\n', func2str(ens.ReadFcn));

fprintf('\n========================================================================\n');

end

%% ============================================================================
%% FUNKCJE READFCN DLA POSZCZEGÓLNYCH METOD
%% ============================================================================

function T = readDFDMember_Method1(filename, variables, freq_bands, Fs)
    % READDFDMEMBER_METHOD1 - Funkcja odczytu dla metody 1 (Analiza czasowa)
    %
    % Wejście:
    %   filename    - ścieżka do pliku .mat
    %   variables   - lista zmiennych do odczytania
    %   freq_bands  - macierz pasm częstotliwości [6×2]
    %   Fs          - częstotliwość próbkowania [Hz]
    %
    % Wyjście:
    %   T - tabela z odczytanymi danymi
    %
    % Opis:
    %   Odczytano plik .mat i wyekstrahowano:
    %   1. Sygnał prądowy (Current)
    %   2. Widmo sygnału (Current_Spectrum)
    %   3. Wszystkie 49 cech (Current_AllFeatures)
    %   Dodatkowo obliczono widmo FFT z oknem Hanninga.
    
    % Załadowanie danych z pliku
    data = load(filename);
    T = table();
    
    % Przetwarzanie każdej żądanej zmiennej
    for k = 1:numel(variables)
        v = variables(k);
        
        switch v
            case 'Current'
                % Sygnał prądowy (timetable)
                val = {data.Current};
                
            case 'Current_Spectrum'
                % Obliczenie widma FFT
                current_tt = data.Current;
                signal = current_tt.Current;
                N = length(signal);
                
                % Okno Hanninga dla redukcji przecieku widmowego
                signal_windowed = signal .* hann(N);
                
                % Transformata Fouriera
                Y = fft(signal_windowed);
                P2 = abs(Y/N);
                P1 = P2(1:floor(N/2)+1);
                P1(2:end-1) = 2*P1(2:end-1);
                f = Fs*(0:(length(P1)-1))/N;
                
                % Tabela z widmem
                spectrumTable = table(f', P1, 'VariableNames', {'Freq_Hz', 'Amplitude'});
                val = {spectrumTable};
                
            case 'Current_AllFeatures'
                % Ekstrakcja wszystkich 49 cech
                current_tt = data.Current;
                signal = current_tt.Current;
                N = length(signal);
                
                %% 1. PODSTAWOWE CECHY CZASOWE (8 cech)
                features = [];
                feat_names = {};
                
                % Średnia
                features(1) = mean(signal);
                feat_names{1} = 'Mean';
                
                % Odchylenie standardowe
                features(2) = std(signal);
                feat_names{2} = 'Std';
                
                % Maksimum
                features(3) = max(signal);
                feat_names{3} = 'Max';
                
                % Wartość skuteczna (RMS)
                features(4) = rms(signal);
                feat_names{4} = 'RMS';
                
                % Amplituda międzyszczytowa (Peak-to-Peak)
                features(5) = max(signal) - min(signal);
                feat_names{5} = 'Peak2Peak';
                
                % Skośność
                features(6) = skewness(signal);
                feat_names{6} = 'Skew';
                
                % Kurtoza
                features(7) = kurtosis(signal);
                feat_names{7} = 'Kurt';
                
                % Współczynnik szczytowości (Crest Factor)
                rms_val = rms(signal);
                if rms_val > 0
                    features(8) = max(abs(signal)) / rms_val;
                else
                    features(8) = 0;
                end
                feat_names{8} = 'Crest';
                
                %% 2. CECHY SPEKTRALNE (2 cechy)
                signal_windowed = signal .* hann(N);
                Y = fft(signal_windowed);
                P2 = abs(Y/N);
                P1 = P2(1:floor(N/2)+1);
                P1(2:end-1) = 2*P1(2:end-1);
                f_fft = Fs*(0:(length(P1)-1))/N;
                
                % Środek częstotliwościowy
                freq_center = sum(f_fft' .* P1) / sum(P1);
                features(9) = freq_center;
                feat_names{9} = 'Freq_Center';
                
                % Pole widma
                spectrum_area = sum(P1.^2);
                features(10) = spectrum_area;
                feat_names{10} = 'Spectrum_Area';
                
                %% 3. HARMONICZNE (3 cechy)
                low_freq_mask = f_fft < 500;
                [~, max_idx] = max(P1(low_freq_mask));
                f_fft_low = f_fft(low_freq_mask);
                fundamental_freq = f_fft_low(max_idx);
                
                % Amplituda 1x RPM
                amp_1x = find_amplitude_at_freq_dfd(P1, f_fft, fundamental_freq, 5);
                features(11) = amp_1x;
                feat_names{11} = 'Amp_1x_RPM';
                
                % Amplituda 2x RPM
                amp_2x = find_amplitude_at_freq_dfd(P1, f_fft, 2*fundamental_freq, 10);
                features(12) = amp_2x;
                feat_names{12} = 'Amp_2x_RPM';
                
                % Amplituda 3x RPM
                amp_3x = find_amplitude_at_freq_dfd(P1, f_fft, 3*fundamental_freq, 15);
                features(13) = amp_3x;
                feat_names{13} = 'Amp_3x_RPM';
                
                %% 4. CECHY PASMOWE (36 cech = 6 pasm × 6 cech)
                current_idx = 14;
                
                for band_idx = 1:size(freq_bands, 1)
                    f_low = freq_bands(band_idx, 1);
                    f_high = min(freq_bands(band_idx, 2), Fs/2 * 0.95);
                    
                    % Filtr pasmowy Butterwortha 4-go rzędu
                    try
                        [b, a] = butter(4, [f_low f_high]/(Fs/2), 'bandpass');
                        signal_filtered = filtfilt(b, a, signal);
                    catch
                        signal_filtered = signal;
                    end
                    
                    % 1. RMS pasma
                    features(current_idx) = rms(signal_filtered);
                    feat_names{current_idx} = sprintf('Band_%d_%d_RMS', f_low, f_high);
                    current_idx = current_idx + 1;
                    
                    % 2. Maksimum pasma
                    features(current_idx) = max(abs(signal_filtered));
                    feat_names{current_idx} = sprintf('Band_%d_%d_Max', f_low, f_high);
                    current_idx = current_idx + 1;
                    
                    % 3. Odchylenie standardowe pasma
                    features(current_idx) = std(signal_filtered);
                    feat_names{current_idx} = sprintf('Band_%d_%d_Std', f_low, f_high);
                    current_idx = current_idx + 1;
                    
                    % 4. Kurtoza pasma
                    if std(signal_filtered) > 0
                        features(current_idx) = kurtosis(signal_filtered);
                    else
                        features(current_idx) = 0;
                    end
                    feat_names{current_idx} = sprintf('Band_%d_%d_Kurt', f_low, f_high);
                    current_idx = current_idx + 1;
                    
                    % 5. Współczynnik szczytowości pasma
                    rms_filt = rms(signal_filtered);
                    if rms_filt > 0
                        features(current_idx) = max(abs(signal_filtered)) / rms_filt;
                    else
                        features(current_idx) = 0;
                    end
                    feat_names{current_idx} = sprintf('Band_%d_%d_Crest', f_low, f_high);
                    current_idx = current_idx + 1;
                    
                    % 6. Energia pasma
                    features(current_idx) = sum(signal_filtered.^2);
                    feat_names{current_idx} = sprintf('Band_%d_%d_Energy', f_low, f_high);
                    current_idx = current_idx + 1;
                end
                
                % Utworzenie tabeli ze wszystkimi cechami
                allFeaturesTable = array2table(features, 'VariableNames', feat_names);
                val = {allFeaturesTable};
                
            case 'Condition'
                % Etykieta klasy
                val = {string(data.Condition)};
                
            otherwise
                % Domyślna wartość dla nieznanych zmiennych
                val = {[]};
        end
        
        % Dodanie zmiennej do tabeli wyjściowej
        T.(v) = val;
    end
end

function T = readDFDMember_Method2(filename, variables, p, Fs)
    % READDFDMEMBER_METHOD2 - Funkcja odczytu dla metody 2 (Model AR)
    %
    % Wejście:
    %   filename  - ścieżka do pliku .mat
    %   variables - lista zmiennych do odczytania
    %   p         - rząd modelu AR
    %   Fs        - częstotliwość próbkowania [Hz]
    %
    % Wyjście:
    %   T - tabela z odczytanymi danymi
    %
    % Opis:
    %   Odczytano plik .mat i wyekstrahowano:
    %   1. Sygnał prądowy (Current)
    %   2. Wszystkie 15 cech AR (Current_AllFeatures)
    %   Obliczono cechy modelu AR z wykorzystaniem algorytmu
    %   Levinson-Durbin i metody Durand-Kernera.
    
    data = load(filename);
    T = table();
    
    for k = 1:numel(variables)
        v = variables(k);
        
        switch v
            case 'Current'
                val = {data.Current};
                
            case 'Current_AllFeatures'
                % Ekstrakcja wszystkich 15 cech AR
                current_tt = data.Current;
                signal = current_tt.Current;
                
                %% OBLICZENIE WSZYSTKICH 15 CECH AR
                % Sygnał oryginalny
                Current = signal;
                
                % Sygnał po usunięciu trendu liniowego
                p_detrend = polyfit((1:length(signal))', signal, 1);
                trend = polyval(p_detrend, (1:length(signal))');
                Current_tsproc = signal - trend;
                
                % Sygnał rezydualny (po odjęciu średniej)
                Current_res = signal - mean(signal);
                
                %% Obliczenie cech AR dla każdego wariantu sygnału
                features = zeros(1, 15);
                feat_names = cell(1, 15);
                
                % 1. Current_tsmodel (4 cechy)
                [f1, d1, ~, mae1, aic1, ~] = compute_tsmodel_durand_kerner(Current, Fs, p);
                features(1) = aic1;   % Current_tsmodel_AIC
                features(5) = mae1;   % Current_tsmodel_MAE  
                features(10) = d1;    % Current_tsmodel_Damp1
                features(12) = f1;    % Current_tsmodel_Freq1
                
                % 2. Current_tsproc_tsmodel (5 cech)
                [f2, d2, ~, mae2, aic2, ~, rms2] = compute_tsmodel_with_rms_durand_kerner(Current_tsproc, Fs, p);
                features(2) = aic2;   % Current_tsproc_tsmodel_AIC
                features(4) = mae2;   % Current_tsproc_tsmodel_MAE
                features(7) = rms2;   % Current_tsproc_tsmodel_RMS
                features(9) = d2;     % Current_tsproc_tsmodel_Damp1
                features(11) = f2;    % Current_tsproc_tsmodel_Freq1
                
                % 3. Current_res_tsmodel (5 cech)
                [f3, d3, ~, mae3, aic3, ~, rms3] = compute_tsmodel_with_rms_durand_kerner(Current_res, Fs, p);
                features(3) = aic3;   % Current_res_tsmodel_AIC
                features(6) = mae3;   % Current_res_tsmodel_MAE
                features(8) = rms3;   % Current_res_tsmodel_RMS
                features(14) = d3;    % Current_res_tsmodel_Damp1
                features(13) = f3;    % Current_res_tsmodel_Freq1
                
                % 4. EnergyIMF1 (1 cecha)
                features(15) = compute_energy_imf(Current);
                
                %% Nazwy cech (zgodne z extract_ar_features_durand_kerner)
                feat_names = {
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
                
                allFeaturesTable = array2table(features, 'VariableNames', feat_names);
                val = {allFeaturesTable};
                
            case 'Condition'
                val = {string(data.Condition)};
                
            otherwise
                val = {[]};
        end
        
        T.(v) = val;
    end
end

function T = readDFDMember_Method3(filename, variables, freq_bands, Fs)
    % READDFDMEMBER_METHOD3 - Funkcja odczytu dla metody 3 (FFT + Envelope)
    %
    % Wejście:
    %   filename    - ścieżka do pliku .mat
    %   variables   - lista zmiennych do odczytania
    %   freq_bands  - macierz pasm częstotliwości [6×2]
    %   Fs          - częstotliwość próbkowania [Hz]
    %
    % Wyjście:
    %   T - tabela z odczytanymi danymi
    %
    % Opis:
    %   Odczytano plik .mat i wyekstrahowano:
    %   1. Sygnał prądowy (Current)
    %   2. Widmo FFT (Current_Spectrum)
    %   3. Widmo obwiedni (Current_Envelope_Spectrum)
    %   4. Wszystkie 96 cech (Current_AllFeatures)
    %   Wykorzystano transformację Hilberta do analizy obwiedni.
    
    data = load(filename);
    T = table();
    
    for k = 1:numel(variables)
        v = variables(k);
        
        switch v
            case 'Current'
                val = {data.Current};
                
            case 'Current_Spectrum'
                % Obliczenie widma FFT
                current_tt = data.Current;
                signal = current_tt.Current;
                N = length(signal);
                
                Y = fft(signal .* hann(N));
                P2 = abs(Y/N);
                P1 = P2(1:floor(N/2)+1);
                P1(2:end-1) = 2*P1(2:end-1);
                f = Fs*(0:(length(P1)-1))/N;
                
                spectrumTable = table(f', P1, 'VariableNames', {'Freq_Hz', 'Amplitude'});
                val = {spectrumTable};
                
            case 'Current_Envelope_Spectrum'
                % Obliczenie widma obwiedni dla każdego pasma
                current_tt = data.Current;
                signal = current_tt.Current;
                
                all_envelopes = [];
                band_labels = {};
                
                for band_idx = 1:size(freq_bands, 1)
                    f_low = freq_bands(band_idx, 1);
                    f_high = min(freq_bands(band_idx, 2), Fs/2 * 0.95);
                    
                    % Filtracja pasmowa
                    [b, a] = butter(4, [f_low f_high]/(Fs/2), 'bandpass');
                    signal_filt = filtfilt(b, a, signal);
                    
                    % Transformata Hilberta (obwiednia)
                    envelope = abs(hilbert(signal_filt));
                    
                    % FFT obwiedni
                    N_env = length(envelope);
                    Y_env = fft(envelope .* hann(N_env));
                    P2_env = abs(Y_env/N_env);
                    P1_env = P2_env(1:floor(N_env/2)+1);
                    P1_env(2:end-1) = 2*P1_env(2:end-1);
                    f_env = Fs*(0:(length(P1_env)-1))/N_env;
                    
                    % Ograniczenie do zakresu 0-500 Hz
                    mask = f_env <= 500;
                    
                    if band_idx == 1
                        all_envelopes = f_env(mask)';
                        band_labels{1} = 'Freq_Hz';
                    end
                    
                    all_envelopes = [all_envelopes, P1_env(mask)];
                    band_labels{end+1} = sprintf('Env_%d_%d', f_low, f_high);
                end
                
                envTable = array2table(all_envelopes, 'VariableNames', band_labels);
                val = {envTable};
                
            case 'Current_AllFeatures'
                % Ekstrakcja wszystkich 96 cech FFT+Envelope
                current_tt = data.Current;
                signal = current_tt.Current;
                N = length(signal);
                
                num_bands = size(freq_bands, 1);
                features_per_band = 16;
                num_features = features_per_band * num_bands;
                
                features = zeros(1, num_features);
                feat_names = cell(1, num_features);
                
                %% FFT całego sygnału
                signal_windowed = signal .* hann(N);
                Y = fft(signal_windowed);
                P2 = abs(Y/N);
                P1 = P2(1:floor(N/2)+1);
                P1(2:end-1) = 2*P1(2:end-1);
                f_fft = Fs*(0:(length(P1)-1))/N;
                
                feat_idx = 1;
                
                %% DLA KAŻDEGO PASMA
                for band_idx = 1:num_bands
                    f_low = freq_bands(band_idx, 1);
                    f_high = min(freq_bands(band_idx, 2), Fs/2 * 0.95);
                    band_name = sprintf('Band_%d_%d', f_low, f_high);
                    
                    % 1. ENERGIA W PAŚMIE (FFT)
                    band_mask = (f_fft >= f_low) & (f_fft <= f_high);
                    P1_band = P1(band_mask);
                    f_band = f_fft(band_mask);
                    
                    band_energy = sum(P1_band.^2);
                    features(feat_idx) = band_energy;
                    feat_names{feat_idx} = [band_name '_FFT_Energy'];
                    feat_idx = feat_idx + 1;
                    
                    % 2. TOP 3 CZĘSTOTLIWOŚCI W PAŚMIE (FFT)
                    if ~isempty(P1_band) && length(P1_band) > 3
                        [pks, locs] = findpeaks(P1_band, 'SortStr', 'descend', 'NPeaks', 3);
                        
                        for peak_idx = 1:3
                            if peak_idx <= length(locs)
                                features(feat_idx) = f_band(locs(peak_idx));
                                feat_names{feat_idx} = sprintf('%s_FFT_Freq%d', band_name, peak_idx);
                                feat_idx = feat_idx + 1;
                                
                                features(feat_idx) = pks(peak_idx);
                                feat_names{feat_idx} = sprintf('%s_FFT_Amp%d', band_name, peak_idx);
                                feat_idx = feat_idx + 1;
                            else
                                % Wypełnienie zerami jeśli brakuje szczytów
                                features(feat_idx) = 0;
                                feat_names{feat_idx} = sprintf('%s_FFT_Freq%d', band_name, peak_idx);
                                feat_idx = feat_idx + 1;
                                
                                features(feat_idx) = 0;
                                feat_names{feat_idx} = sprintf('%s_FFT_Amp%d', band_name, peak_idx);
                                feat_idx = feat_idx + 1;
                            end
                        end
                    else
                        % Wypełnienie zerami jeśli brak danych
                        for peak_idx = 1:3
                            features(feat_idx) = 0;
                            feat_names{feat_idx} = sprintf('%s_FFT_Freq%d', band_name, peak_idx);
                            feat_idx = feat_idx + 1;
                            
                            features(feat_idx) = 0;
                            feat_names{feat_idx} = sprintf('%s_FFT_Amp%d', band_name, peak_idx);
                            feat_idx = feat_idx + 1;
                        end
                    end
                    
                    % 3. FILTROWANIE PASMOWE + ENVELOPE
                    try
                        if f_low < 50
                            [b, a] = butter(4, f_high/(Fs/2), 'low');
                        else
                            [b, a] = butter(4, [f_low f_high]/(Fs/2), 'bandpass');
                        end
                        signal_filtered = filtfilt(b, a, signal);
                    catch
                        signal_filtered = signal;
                    end
                    
                    % RMS sygnału przefiltrowanego
                    features(feat_idx) = rms(signal_filtered);
                    feat_names{feat_idx} = [band_name '_RMS'];
                    feat_idx = feat_idx + 1;
                    
                    % Wartość szczytowa sygnału przefiltrowanego
                    features(feat_idx) = max(abs(signal_filtered));
                    feat_names{feat_idx} = [band_name '_Peak'];
                    feat_idx = feat_idx + 1;
                    
                    % 4. ENVELOPE (HILBERT) + FFT
                    envelope = abs(hilbert(signal_filtered));
                    
                    N_env = length(envelope);
                    envelope_windowed = envelope .* hann(N_env);
                    Y_env = fft(envelope_windowed);
                    P2_env = abs(Y_env/N_env);
                    P1_env = P2_env(1:floor(N_env/2)+1);
                    P1_env(2:end-1) = 2*P1_env(2:end-1);
                    f_env = Fs*(0:(length(P1_env)-1))/N_env;
                    
                    % Ograniczenie do 0-500 Hz
                    env_freq_mask = f_env <= 500;
                    P1_env_limited = P1_env(env_freq_mask);
                    f_env_limited = f_env(env_freq_mask);
                    
                    % Energia obwiedni
                    env_energy = sum(P1_env_limited.^2);
                    features(feat_idx) = env_energy;
                    feat_names{feat_idx} = [band_name '_Env_Energy'];
                    feat_idx = feat_idx + 1;
                    
                    % 5. TOP 3 CZĘSTOTLIWOŚCI ENVELOPE
                    if ~isempty(P1_env_limited) && length(P1_env_limited) > 3
                        [pks_env, locs_env] = findpeaks(P1_env_limited, 'SortStr', 'descend', 'NPeaks', 3);
                        
                        for peak_idx = 1:3
                            if peak_idx <= length(locs_env)
                                features(feat_idx) = f_env_limited(locs_env(peak_idx));
                                feat_names{feat_idx} = sprintf('%s_Env_Freq%d', band_name, peak_idx);
                                feat_idx = feat_idx + 1;
                                
                                features(feat_idx) = pks_env(peak_idx);
                                feat_names{feat_idx} = sprintf('%s_Env_Amp%d', band_name, peak_idx);
                                feat_idx = feat_idx + 1;
                            else
                                features(feat_idx) = 0;
                                feat_names{feat_idx} = sprintf('%s_Env_Freq%d', band_name, peak_idx);
                                feat_idx = feat_idx + 1;
                                
                                features(feat_idx) = 0;
                                feat_names{feat_idx} = sprintf('%s_Env_Amp%d', band_name, peak_idx);
                                feat_idx = feat_idx + 1;
                            end
                        end
                    else
                        for peak_idx = 1:3
                            features(feat_idx) = 0;
                            feat_names{feat_idx} = sprintf('%s_Env_Freq%d', band_name, peak_idx);
                            feat_idx = feat_idx + 1;
                            
                            features(feat_idx) = 0;
                            feat_names{feat_idx} = sprintf('%s_Env_Amp%d', band_name, peak_idx);
                            feat_idx = feat_idx + 1;
                        end
                    end
                end
                
                allFeaturesTable = array2table(features, 'VariableNames', feat_names);
                val = {allFeaturesTable};
                
            case 'Condition'
                val = {string(data.Condition)};
                
            otherwise
                val = {[]};
        end
        
        T.(v) = val;
    end
end

function T = readDFDMember_Method4(filename, variables, wavelet_name, level)
    % READDFDMEMBER_METHOD4 - Funkcja odczytu dla metody 4 (Wavelet)
    %
    % Wejście:
    %   filename     - ścieżka do pliku .mat
    %   variables    - lista zmiennych do odczytania
    %   wavelet_name - nazwa fali falkowej ('db4')
    %   level        - poziom dekompozycji
    %
    % Wyjście:
    %   T - tabela z odczytanymi danymi
    %
    % Opis:
    %   Odczytano plik .mat i wyekstrahowano:
    %   1. Sygnał prądowy (Current)
    %   2. Wszystkie 54 cech falkowe (Current_AllFeatures)
    %   Wykorzystano dyskretną transformatę falkową (wavedec).
    
    data = load(filename);
    T = table();
    
    for k = 1:numel(variables)
        v = variables(k);
        
        switch v
            case 'Current'
                val = {data.Current};
                
            case 'Current_AllFeatures'
                % Ekstrakcja wszystkich 54 cech falkowych
                current_tt = data.Current;
                signal = current_tt.Current;
                
                %% OBLICZENIE WSZYSTKICH 54 CECH FALKOWYCH
                try
                    % Dyskretna transformata falkowa
                    [C, L] = wavedec(signal, level, wavelet_name);
                catch
                    % Obsługa błędów - wypełnienie zerami
                    num_levels = level + 1;
                    features_per_level = 6;
                    num_features = features_per_level * num_levels;
                    features = zeros(1, num_features);
                    feat_names = cell(1, num_features);
                    
                    feat_types = {'Energy', 'RMS', 'Kurtosis', 'Entropy', 'Skewness', 'Peak2RMS'};
                    feat_idx = 1;
                    
                    for lev = 1:num_levels
                        if lev <= level
                            level_name = sprintf('D%d', lev);
                        else
                            level_name = sprintf('A%d', level);
                        end
                        
                        for type_idx = 1:features_per_level
                            feat_names{feat_idx} = sprintf('Wavelet_%s_%s', level_name, feat_types{type_idx});
                            features(feat_idx) = 0;
                            feat_idx = feat_idx + 1;
                        end
                    end
                    
                    allFeaturesTable = array2table(features, 'VariableNames', feat_names);
                    val = {allFeaturesTable};
                    continue;
                end
                
                % Ekstrakcja współczynników falkowych
                coeffs = cell(1, level + 1);
                
                for lev = 1:level
                    coeffs{lev} = detcoef(C, L, lev);
                end
                coeffs{level + 1} = appcoef(C, L, wavelet_name);
                
                num_levels = level + 1;
                features_per_level = 6;
                num_features = features_per_level * num_levels;
                
                features = zeros(1, num_features);
                feat_names = cell(1, num_features);
                feat_idx = 1;
                
                for lev = 1:num_levels
                    coef = coeffs{lev};
                    
                    if isempty(coef)
                        % Wypełnienie zerami jeśli brak współczynników
                        for type_idx = 1:features_per_level
                            features(feat_idx) = 0;
                            feat_idx = feat_idx + 1;
                        end
                        continue;
                    end
                    
                    % Nazwa poziomu
                    if lev <= level
                        level_name = sprintf('D%d', lev);
                    else
                        level_name = sprintf('A%d', level);
                    end
                    
                    %% 1. ENERGIA
                    energy = sum(coef.^2);
                    features(feat_idx) = energy;
                    feat_names{feat_idx} = sprintf('Wavelet_%s_Energy', level_name);
                    feat_idx = feat_idx + 1;
                    
                    %% 2. RMS
                    rms_val = sqrt(mean(coef.^2));
                    features(feat_idx) = rms_val;
                    feat_names{feat_idx} = sprintf('Wavelet_%s_RMS', level_name);
                    feat_idx = feat_idx + 1;
                    
                    %% 3. KURTOZA
                    if std(coef) > 1e-10
                        kurt_val = kurtosis(coef);
                    else
                        kurt_val = 0;
                    end
                    features(feat_idx) = kurt_val;
                    feat_names{feat_idx} = sprintf('Wavelet_%s_Kurtosis', level_name);
                    feat_idx = feat_idx + 1;
                    
                    %% 4. ENTROPIA SHANNON
                    p = coef.^2;
                    sum_p = sum(p);
                    if sum_p > 0
                        p = p / sum_p;
                        p(p == 0) = [];
                        if ~isempty(p)
                            entropy_val = -sum(p .* log2(p));
                        else
                            entropy_val = 0;
                        end
                    else
                        entropy_val = 0;
                    end
                    features(feat_idx) = entropy_val;
                    feat_names{feat_idx} = sprintf('Wavelet_%s_Entropy', level_name);
                    feat_idx = feat_idx + 1;
                    
                    %% 5. SKEWNESS
                    if std(coef) > 1e-10
                        skew_val = skewness(coef);
                    else
                        skew_val = 0;
                    end
                    features(feat_idx) = skew_val;
                    feat_names{feat_idx} = sprintf('Wavelet_%s_Skewness', level_name);
                    feat_idx = feat_idx + 1;
                    
                    %% 6. PEAK-TO-RMS RATIO
                    if rms_val > 1e-10
                        peak2rms = max(abs(coef)) / rms_val;
                    else
                        peak2rms = 0;
                    end
                    features(feat_idx) = peak2rms;
                    feat_names{feat_idx} = sprintf('Wavelet_%s_Peak2RMS', level_name);
                    feat_idx = feat_idx + 1;
                end
                
                allFeaturesTable = array2table(features, 'VariableNames', feat_names);
                val = {allFeaturesTable};
                
            case 'Condition'
                val = {string(data.Condition)};
                
            otherwise
                val = {[]};
        end
        
        T.(v) = val;
    end
end

%% ============================================================================
%% FUNKCJE POMOCNICZE AR DLA METODY 2 (DFD)
%% ============================================================================

function [Freq1, Damp1, MSE, MAE, AIC, Variance] = compute_tsmodel_durand_kerner(signal, Fs, p)
    % COMPUTE_TSMODEL_DURAND_KERNER - Obliczenie cech modelu AR
    %
    % Wejście:
    %   signal - wektor sygnału
    %   Fs     - częstotliwość próbkowania [Hz]
    %   p      - rząd modelu AR
    %
    % Wyjście:
    %   Freq1    - częstotliwość dominująca [Hz]
    %   Damp1    - współczynnik tłumienia
    %   MSE      - błąd średniokwadratowy
    %   MAE      - średni błąd bezwzględny
    %   AIC      - kryterium informacyjne Akaike
    %   Variance - wariancja reszt modelu
    
    x = signal;
    y = x - mean(x, 'omitnan');
    N = numel(x);
    
    % Autokorelacja
    R = xcorr(y, p, 'biased');
    R(1:p) = [];
    
    % Algorytm Levinson-Durbin
    [a, Ep] = levinson(R, p);
    
    % Pierwiastki wielomianu charakterystycznego
    r = sort(roots(a), 'descend');
    
    % Konwersja do dziedziny s (tylko dominujący pierwiastek)
    if ~isempty(r)
        s = Fs * log(r(1));
        Freq1 = abs(s) / (2*pi);
        Damp1 = -real(s) / abs(s);
    else
        Freq1 = 0;
        Damp1 = 0;
    end
    
    % Szum procesowy
    w = filter(a, 1, y);
    MSE = var(w, 'omitnan');
    MAE = mean(abs(w), 'omitnan');
    
    % Reszty modelu
    e = filter(a, 1, x);
    Variance = var(e, 'omitnan');
    
    % Kryterium informacyjne Akaike
    AIC = log(Ep) + 2*p/N;
end

function [Freq1, Damp1, MSE, MAE, AIC, Variance, RMS] = compute_tsmodel_with_rms_durand_kerner(signal, Fs, p)
    % COMPUTE_TSMODEL_WITH_RMS_DURAND_KERNER - Obliczenie cech AR z RMS
    %
    % Rozszerzenie funkcji compute_tsmodel_durand_kerner o obliczenie
    % wartości skutecznej (RMS) reszt modelu.
    
    % Obliczenie podstawowych cech
    [Freq1, Damp1, MSE, MAE, AIC, Variance] = compute_tsmodel_durand_kerner(signal, Fs, p);
    
    % Obliczenie RMS
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
    % COMPUTE_ENERGY_IMF - Obliczenie energii pierwszej funkcji modalnej
    %
    % Wejście:
    %   signal - wektor sygnału
    %
    % Wyjście:
    %   EnergyIMF1 - energia pierwszej funkcji modalnej (IMF)
    %
    % Opis:
    %   Obliczenie energii pierwszej funkcji modalnej uzyskanej
    %   za pomocą empirycznej dekompozycji modalnej (EMD).
    
    try
        if exist('emd', 'file') == 2
            % Empiryczna dekompozycja modalna
            outputEMD = emd(signal, "MaxNumIMF", 1);
            EnergyIMF1 = sum(outputEMD(:, 1));
        else
            % Przybliżenie jeśli brak EMD toolbox
            EnergyIMF1 = sum(abs(signal - mean(signal)));
        end
    catch
        EnergyIMF1 = sum(abs(signal));
    end
end

%% ============================================================================
%% FUNKCJE POMOCNICZE DLA WSZYSTKICH METOD
%% ============================================================================

function amplitude = find_amplitude_at_freq_dfd(spectrum, freq_vec, target_freq, tolerance_hz)
    % FIND_AMPLITUDE_AT_FREQ_DFD - Znajdowanie amplitudy w okolicy częstotliwości
    %
    % Wejście:
    %   spectrum      - wektor widma amplitudowego
    %   freq_vec      - wektor częstotliwości
    %   target_freq   - docelowa częstotliwość [Hz]
    %   tolerance_hz  - tolerancja wyszukiwania [Hz]
    %
    % Wyjście:
    %   amplitude - maksymalna amplituda w okolicy target_freq
    
    % Definicja maski częstotliwościowej
    freq_mask = (freq_vec >= target_freq - tolerance_hz) & ...
                (freq_vec <= target_freq + tolerance_hz);
    
    if any(freq_mask)
        amplitude = max(spectrum(freq_mask));
    else
        amplitude = 0;
    end
end

%% ============================================================================
%% PODSUMOWANIE
%% ============================================================================
%
% FUNKCJA CREATE_ENS_FOR_METHOD STANOWI KLUCZOWY ELEMENT SYSTEMU DIAGNOSTYCZNEGO
% DLA SILNIKÓW BLDC. UMOŻLIWIA AUTOMATYCZNĄ KONFIGURACJĘ DANYCH DLA CZTERECH
% METOD ANALIZY SYGNAŁÓW PRĄDOWYCH ORAZ INTEGRACJĘ Z NARZĘDZIEM DIAGNOSTIC
% FEATURE DESIGNER.
%
% GŁÓWNE ZALETY SYSTEMU:
%   1. Automatyzacja procesu konfiguracji DFD
%   2. Wsparcie dla 4 różnych metod ekstrakcji cech
%   3. Elastyczna konfiguracja parametrów analizy
%   4. Generowanie szczegółowych raportów i instrukcji
%   5. Integracja z istniejącym pipeline przetwarzania sygnałów
%
% ==============================================================================