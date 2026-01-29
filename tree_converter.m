%% ========================================================================
% KONWERTER MODELU DRZEWA DECYZYJNEGO MATLAB -> C (ESP32)
% ========================================================================
%
% Plik:        tree_converter.m
% Autor:       Pavel Tshonek (155068)
% Data:        2026-01
% Opis:        Konwerter modelu drzewa decyzyjnego z MATLAB Classification Learner
%              do kodu C dla ESP32. Generuje pliki tree_model.h i tree_model.c.
%
% INSTRUKCJA UZYCIA:
%   1. Wytrenować model drzewa decyzyjnego w MATLAB Classification Learner
%   2. Wyeksportować model jako 'trainedModel' do przestrzeni roboczej
%   3. Uruchomić ten skrypt
%   4. Pliki zostaną zapisane w bieżącym folderze
%
% WYMAGANIA:
%   - Zmienna 'trainedModel' w przestrzeni roboczej MATLAB
%   - Model musi być drzewem decyzyjnym (ClassificationTree)
%   - Nazwy cech muszą być identyczne jak w strukturze MotorFeatures15
% ========================================================================

% clear; clc; close all;
fprintf('================================================================\n');
fprintf('KONWERTER MODELU DRZEWA DECYZYJNEGO MATLAB -> C (ESP32)\n');
fprintf('================================================================\n');
fprintf('Autor: Pavel Tshonek (155068)\n');
fprintf('Data:  %s\n', datestr(now, 'yyyy-mm-dd'));
fprintf('================================================================\n\n');

%% SPRAWDZENIE CZY MODEL ISTNIEJE W PRZESTRZENI ROBOCZEJ
if ~exist('trainedModel', 'var')
    error('Błąd: Nie znaleziono zmiennej trainedModel w przestrzeni roboczej.');
    error('Najpierw należy wytrenować model w Classification Learner i wyeksportować jako trainedModel.');
end

if ~isfield(trainedModel, 'ClassificationTree')
    error('Błąd: Zmienna trainedModel nie zawiera pola ClassificationTree.');
    error('Upewnić się, że wytrenowano model drzewa decyzyjnego.');
end

%% WCZYTANIE MODELU
model = trainedModel.ClassificationTree;
fprintf('Znaleziono model drzewa decyzyjnego:\n');

% Sprawdzenie czy istnieje pole About
if isfield(trainedModel, 'About')
    fprintf('  Informacje: %s\n', trainedModel.About);
end

fprintf('  Liczba wezłów: %d\n', model.NumNodes);
fprintf('  Liczba cech: %d\n', length(model.PredictorNames));
fprintf('  Liczba klas: %d\n\n', length(model.ClassNames));

%% EKSTRAKCJA DANYCH Z MODELU
% Podstawowe informacje
num_nodes = model.NumNodes;
num_classes = length(model.ClassNames);
num_features = length(model.PredictorNames);

% Weryfikacja liczby cech
if num_features ~= 15
    warning('Model ma %d cech, oczekiwano 15. Sprawdzić czy to prawidłowy model.', num_features);
end

% Ekstrakcja struktury drzewa
children = model.Children;
cut_point = model.CutPoint;
cut_predictor = model.CutPredictor;
class_count = model.ClassCount;
node_class = model.NodeClass;
class_prob = model.ClassProbability;

% Nazwy cech (muszą być w tej samej kolejności co w MATLAB)
feature_names = model.PredictorNames;

% Nazwy klas
class_names_matlab = model.ClassNames;

%% WYŚWIETLENIE INFORMACJI O CECHACH
fprintf('Nazwy cech w modelu MATLAB:\n');
for i = 1:length(feature_names)
    fprintf('  %2d: %s\n', i, feature_names{i});
end
fprintf('\n');

%% WYŚWIETLENIE INFORMACJI O KLASACH
fprintf('Nazwy klas w modelu MATLAB:\n');
for i = 1:length(class_names_matlab)
    fprintf('  %2d: %s\n', i, char(class_names_matlab(i)));
end
fprintf('\n');

%% MAPOWANIE NAZW CECH NA INDEKSY
% Określenie jak nazwy cech z MATLAB mapują się na indeksy w strukturze C
% Musi być zgodne z kolejnością w pliku feature_extractor_15.h

% Mapowanie zgodne z wcześniej zdefiniowaną strukturą
feature_mapping = {
    'Current_AIC',              % indeks 0
    'Current_MAE',              % indeks 1  
    'Current_Freq1',            % indeks 2
    'Current_Damp1',            % indeks 3
    'Current_tsproc_AIC',       % indeks 4
    'Current_tsproc_MAE',       % indeks 5
    'Current_tsproc_RMS',       % indeks 6
    'Current_tsproc_Freq1',     % indeks 7
    'Current_tsproc_Damp1',     % indeks 8
    'Current_res_AIC',          % indeks 9
    'Current_res_MAE',          % indeks 10
    'Current_res_RMS',          % indeks 11
    'Current_res_Freq1',        % indeks 12
    'Current_res_Damp1',        % indeks 13
    'Current_EnergyIMF1'        % indeks 14
};

% Sprawdzenie czy wszystkie cechy są zmapowane
missing_features = {};
for i = 1:length(feature_names)
    feat_name = feature_names{i};
    if ~any(strcmp(feature_mapping, feat_name))
        missing_features{end+1} = feat_name;
    end
end

if ~isempty(missing_features)
    warning('Następujące cechy nie są zmapowane:');
    for i = 1:length(missing_features)
        fprintf('  - %s\n', missing_features{i});
    end
    fprintf('Dodać je do tablicy feature_mapping.\n');
end

% Tworzenie mapy nazwa_cechy -> indeks
feature_index_map = containers.Map();
for i = 1:length(feature_mapping)
    feature_index_map(feature_mapping{i}) = i-1; % C indeksy od 0
end

%% MAPOWANIE NAZW KLAS NA KODY
% MATLAB ClassNames -> kody w C (enum MotorClass)
% Musi być zgodne z plikiem C

% Mapowanie klas zgodne z wcześniejszą definicją
class_mapping = {
    'Elec_Damage',      0;  % ELEC_DAMAGE = 0
    'Healthy',          1;  % HEALTHY = 1  
    'Mech_Damage',      2;  % MECH_DAMAGE = 2
    'Mech_Elec_Damage', 3   % MECH_ELEC_DAMAGE = 3
};

% Tworzenie mapy nazwa_klasy -> kod
class_code_map = containers.Map();
for i = 1:size(class_mapping, 1)
    class_code_map(class_mapping{i, 1}) = class_mapping{i, 2};
end

% Sprawdzenie czy wszystkie klasy MATLAB są zmapowane
for i = 1:length(class_names_matlab)
    class_name = char(class_names_matlab(i));
    if ~isKey(class_code_map, class_name)
        warning('Klasa MATLAB "%s" nie jest zmapowana. Dodać ją do class_mapping.', class_name);
    end
end

%% PRZETWORZENIE STRUKTURY DRZEWA
fprintf('Przetwarzanie struktury drzewa...\n');

% Inicjalizacja tablicy węzłów
tree_nodes = cell(num_nodes, 1);

for node_idx = 1:num_nodes
    node = struct();
    
    % Sprawdzenie czy to liść
    if children(node_idx, 1) == 0  % Brak dzieci = liść
        node.feature_index = -1;
        node.threshold = 0;
        node.left_child = -1;
        node.right_child = -1;
        
        % Pobranie etykiety klasy dla liścia
        if iscell(node_class)
            class_name = char(node_class{node_idx});
        else
            class_name = char(node_class(node_idx));
        end
        
        % Mapowanie nazwy klasy na kod
        if isKey(class_code_map, class_name)
            node.class_label = class_code_map(class_name);
        else
            % Domyślnie pierwsza klasa
            node.class_label = 0;
            warning('Nie znaleziono mapowania dla klasy "%s", użyto kodu 0', class_name);
        end
        
        % Prawdopodobieństwo (najwyższe w ClassProbability)
        if ~isempty(class_prob)
            node.probability = max(class_prob(node_idx, :));
        else
            node.probability = 1.0;
        end
        
    else
        % Węzeł wewnętrzny
        node.left_child = children(node_idx, 1);
        node.right_child = children(node_idx, 2);
        node.class_label = -1;  % -1 dla węzłów wewnętrznych
        
        % Próg podziału
        if iscell(cut_point)
            node.threshold = cut_point{node_idx};
        elseif ~isnan(cut_point(node_idx))
            node.threshold = cut_point(node_idx);
        else
            node.threshold = 0;
        end
        
        % Indeks cechy
        if iscell(cut_predictor)
            if ~isempty(cut_predictor{node_idx})
                feat_name = char(cut_predictor{node_idx});
            else
                feat_name = '';
            end
        elseif ~isnan(cut_predictor(node_idx))
            feat_name = char(cut_predictor(node_idx));
        else
            feat_name = '';
        end
        
        % Mapowanie nazwy cechy na indeks
        if ~isempty(feat_name) && isKey(feature_index_map, feat_name)
            node.feature_index = feature_index_map(feat_name);
        else
            node.feature_index = -1; % Dla węzłów bez cechy
        end
        
        % Prawdopodobieństwo (nieistotne dla węzłów wewnętrznych)
        node.probability = 0.0;
    end
    
    tree_nodes{node_idx} = node;
end

fprintf('Przetworzono %d węzłów drzewa.\n', num_nodes);

%% GENERACJA PLIKU tree_model.h
fprintf('\nGenerowanie pliku tree_model.h...\n');

header_filename = 'tree_model.h';
fid = fopen(header_filename, 'w');

if fid == -1
    error('Nie można utworzyć pliku %s', header_filename);
end

% Nagłówek pliku
fprintf(fid, '/**\n');
fprintf(fid, ' * @file tree_model.h\n');
fprintf(fid, ' * @author Pavel Tshonek - 155068\n');
fprintf(fid, ' * @date %s\n', datestr(now, 'yyyy'));
fprintf(fid, ' * @brief Nagłówek modelu drzewa decyzyjnego dla diagnostyki silnika\n');
fprintf(fid, ' * \n');
fprintf(fid, ' * Definicje modelu drzewa decyzyjnego wyeksportowanego\n');
fprintf(fid, ' * z MATLAB Classification Learner. Model składa się z %d węzłów\n', num_nodes);
fprintf(fid, ' * i klasyfikuje %d stanów silnika na podstawie %d cech.\n', num_classes, num_features);
fprintf(fid, ' * \n');
fprintf(fid, ' * Praca dyplomowa: "Zastosowanie wybranych metod uczenia maszynowego do wykrywania uszkodzeń napędu elektrycznego drona" \n');
fprintf(fid, ' * \n');
fprintf(fid, ' * Implementacja własna - autor Pavel Tshonek.\n');
fprintf(fid, ' */\n\n');
fprintf(fid, '#ifndef TREE_MODEL_H\n');
fprintf(fid, '#define TREE_MODEL_H\n\n');
fprintf(fid, '#include <stddef.h>\n');
fprintf(fid, '#include "feature_extractor_15.h"\n\n');

% Definicje stałych
fprintf(fid, '// ========== PARAMETRY MODELU (MUSZĄ PASOWAĆ DO MATLAB) ==========\n\n');
fprintf(fid, '/**\n');
fprintf(fid, ' * @def NUM_CLASSES\n');
fprintf(fid, ' * @brief Liczba klas diagnostycznych\n');
fprintf(fid, ' * \n');
fprintf(fid, ' * Model rozróżnia %d stanów silnika.\n', num_classes);
fprintf(fid, ' */\n');
fprintf(fid, '#define NUM_CLASSES %d\n\n', num_classes);

fprintf(fid, '/**\n');
fprintf(fid, ' * @def NUM_FEATURES\n');
fprintf(fid, ' * @brief Liczba cech wejściowych\n');
fprintf(fid, ' * \n');
fprintf(fid, ' * Model wykorzystuje %d cech wyekstrahowanych metodą AR+EMD.\n', num_features);
fprintf(fid, ' */\n');
fprintf(fid, '#define NUM_FEATURES %d\n\n', num_features);

fprintf(fid, '/**\n');
fprintf(fid, ' * @def TREE_SIZE\n');
fprintf(fid, ' * @brief Liczba węzłów w drzewie decyzyjnym\n');
fprintf(fid, ' * \n');
fprintf(fid, ' * Drzewo składa się z %d węzłów (w tym liści).\n', num_nodes);
fprintf(fid, ' */\n');
fprintf(fid, '#define TREE_SIZE %d\n\n', num_nodes);

% Enumeracja klas
fprintf(fid, '// ========== KLASY DIAGNOSTYCZNE SILNIKA ==========\n\n');
fprintf(fid, '/**\n');
fprintf(fid, ' * @enum MotorClass\n');
fprintf(fid, ' * @brief Enumeracja klas diagnostycznych silnika\n');
fprintf(fid, ' * \n');
fprintf(fid, ' * Kody klas muszą być identyczne jak w MATLAB ClassNames.\n');
fprintf(fid, ' * Implementacja własna - autor Pavel Tshonek.\n');
fprintf(fid, ' */\n');
fprintf(fid, 'typedef enum {\n');

% Wypisanie klas w kolejności z MATLAB
for i = 1:length(class_names_matlab)
    class_name = char(class_names_matlab(i));
    if isKey(class_code_map, class_name)
        code = class_code_map(class_name);
        % Zamiana na format C (bez spacji, podłoga zamiast spacji)
        c_class_name = strrep(class_name, ' ', '_');
        c_class_name = strrep(c_class_name, '-', '_');
        c_class_name = upper(c_class_name);
        
        fprintf(fid, '    %s = %d', c_class_name, code);
        if i < length(class_names_matlab)
            fprintf(fid, ',');
        end
        fprintf(fid, '       ///< %s\n', class_name);
    end
end
fprintf(fid, '} MotorClass;\n\n');

% Struktura TreeNode
fprintf(fid, '// ========== STRUKTURA WĘZŁA DRZEWA DECYZYJNEGO ==========\n\n');
fprintf(fid, '/**\n');
fprintf(fid, ' * @struct TreeNode\n');
fprintf(fid, ' * @brief Struktura reprezentująca węzeł drzewa decyzyjnego\n');
fprintf(fid, ' * \n');
fprintf(fid, ' * Zawiera wszystkie informacje potrzebne do przetwarzania\n');
fprintf(fid, ' * drzewa binarnego. Struktura jest zoptymalizowana pod kątem\n');
fprintf(fid, ' * wydajności na ESP32.\n');
fprintf(fid, ' * \n');
fprintf(fid, ' * Implementacja własna - autor Pavel Tshonek.\n');
fprintf(fid, ' */\n');
fprintf(fid, 'typedef struct {\n');
fprintf(fid, '    int feature_index;     ///< Indeks cechy do testu (-1 dla liścia)\n');
fprintf(fid, '    float threshold;       ///< Próg podziału dla testowanej cechy\n');
fprintf(fid, '    int left_child;        ///< Indeks lewego dziecka (-1 jeśli brak)\n');
fprintf(fid, '    int right_child;       ///< Indeks prawego dziecka (-1 jeśli brak)\n');
fprintf(fid, '    int class_label;       ///< Etykieta klasy dla liścia (-1 dla węzłów)\n');
fprintf(fid, '    float probability;     ///< Prawdopodobieństwo przypisania do klasy\n');
fprintf(fid, '} TreeNode;\n\n');

% Deklaracje zewnętrzne
fprintf(fid, '// ========== ZEWNĘTRZNE DEKLARACJE MODELU ==========\n\n');
fprintf(fid, '/**\n');
fprintf(fid, ' * @var decision_tree[TREE_SIZE]\n');
fprintf(fid, ' * @brief Tablica zawierająca strukturę drzewa decyzyjnego\n');
fprintf(fid, ' * \n');
fprintf(fid, ' * Model wyeksportowany z MATLAB Classification Learner.\n');
fprintf(fid, ' * Drzewo jest przechowywane w postaci tablicy dla efektywnego\n');
fprintf(fid, ' * dostępu na mikrokontrolerze.\n');
fprintf(fid, ' * \n');
fprintf(fid, ' * Implementacja własna - autor Pavel Tshonek.\n');
fprintf(fid, ' */\n');
fprintf(fid, 'extern const TreeNode decision_tree[TREE_SIZE];\n\n');

fprintf(fid, '/**\n');
fprintf(fid, ' * @var class_names[NUM_CLASSES]\n');
fprintf(fid, ' * @brief Tablica nazw klas diagnostycznych\n');
fprintf(fid, ' * \n');
fprintf(fid, ' * Nazwy odpowiadające kodom z enumeracji MotorClass.\n');
fprintf(fid, ' * Używane do czytelnego wyświetlania wyników.\n');
fprintf(fid, ' */\n');
fprintf(fid, 'extern const char* class_names[NUM_CLASSES];\n\n');

% Deklaracje funkcji
fprintf(fid, '// ========== FUNKCJE KLASYFIKACYJNE ==========\n\n');
fprintf(fid, '/**\n');
fprintf(fid, ' * @brief Klasyfikuje stan silnika na podstawie cech\n');
fprintf(fid, ' * \n');
fprintf(fid, ' * Funkcja przetwarza drzewo decyzyjne od korzenia do liścia,\n');
fprintf(fid, ' * dokonując klasyfikacji na podstawie %d cech.\n', num_features);
fprintf(fid, ' * \n');
fprintf(fid, ' * @param features Wskaźnik do struktury z cechami diagnostycznymi\n');
fprintf(fid, ' * @return Przewidziana klasa silnika (MotorClass)\n');
fprintf(fid, ' * \n');
fprintf(fid, ' * Implementacja własna - autor Pavel Tshonek.\n');
fprintf(fid, ' */\n');
fprintf(fid, 'MotorClass tree_predict(const MotorFeatures15* features);\n\n');

fprintf(fid, '/**\n');
fprintf(fid, ' * @brief Klasyfikuje stan silnika na podstawie tablicy cech\n');
fprintf(fid, ' * \n');
fprintf(fid, ' * Alternatywna funkcja klasyfikacji przyjmująca znormalizowane\n');
fprintf(fid, ' * cechy w postaci tablicy. Używana po normalizacji Z-score.\n');
fprintf(fid, ' * \n');
fprintf(fid, ' * @param features Tablica %d znormalizowanych cech\n', num_features);
fprintf(fid, ' * @return Przewidziana klasa silnika (MotorClass)\n');
fprintf(fid, ' * \n');
fprintf(fid, ' * Implementacja własna - autor Pavel Tshonek.\n');
fprintf(fid, ' */\n');
fprintf(fid, 'MotorClass tree_predict_from_array(const float features[NUM_FEATURES]);\n\n');

fprintf(fid, '#endif // TREE_MODEL_H\n');
fclose(fid);

fprintf('Plik %s wygenerowany pomyślnie.\n', header_filename);

%% GENERACJA PLIKU tree_model.c
fprintf('\nGenerowanie pliku tree_model.c...\n');

source_filename = 'tree_model.c';
fid = fopen(source_filename, 'w');

if fid == -1
    error('Nie można utworzyć pliku %s', source_filename);
end

% Nagłówek pliku
fprintf(fid, '/**\n');
fprintf(fid, ' * @file tree_model.c\n');
fprintf(fid, ' * @author Pavel Tshonek - 155068\n');
fprintf(fid, ' * @date %s\n', datestr(now, 'yyyy'));
fprintf(fid, ' * @brief Implementacja modelu drzewa decyzyjnego\n');
fprintf(fid, ' * \n');
fprintf(fid, ' * Model wyeksportowany z MATLAB Classification Learner dla\n');
fprintf(fid, ' * klasyfikacji %d stanów silnika elektrycznego na podstawie\n', num_classes);
fprintf(fid, ' * %d cech wyekstrahowanych metodą AR+EMD.\n', num_features);
fprintf(fid, ' * \n');
fprintf(fid, ' * Praca dyplomowa: "Zastosowanie wybranych metod uczenia maszynowego do wykrywania uszkodzeń napędu elektrycznego drona" \n');
fprintf(fid, ' * \n');
fprintf(fid, ' * Implementacja własna - autor Pavel Tshonek.\n');
fprintf(fid, ' */\n\n');
fprintf(fid, '#include "tree_model.h"\n');
fprintf(fid, '#include <stdio.h>\n');
fprintf(fid, '#include <string.h>\n\n');

% Tablica nazw klas
fprintf(fid, '// ========== NAZWY KLAS DIAGNOSTYCZNYCH ==========\n\n');
fprintf(fid, '/**\n');
fprintf(fid, ' * @var class_names[NUM_CLASSES]\n');
fprintf(fid, ' * @brief Tablica tekstowych nazw klas diagnostycznych\n');
fprintf(fid, ' * \n');
fprintf(fid, ' * Kolejność musi być identyczna jak w MATLAB ClassNames.\n');
fprintf(fid, ' * Używane do czytelnego wyświetlania wyników klasyfikacji.\n');
fprintf(fid, ' * \n');
fprintf(fid, ' * Implementacja własna - autor Pavel Tshonek.\n');
fprintf(fid, ' */\n');
fprintf(fid, 'const char* class_names[NUM_CLASSES] = {\n');

for i = 1:length(class_names_matlab)
    class_name = char(class_names_matlab(i));
    fprintf(fid, '    "%s"', class_name);
    if i < length(class_names_matlab)
        fprintf(fid, ',');
    end
    fprintf(fid, '          ///< %s\n', class_name);
end
fprintf(fid, '};\n\n');

% Tablica drzewa decyzyjnego
fprintf(fid, '// ========== MODEL DRZEWA DECYZYJNEGO ==========\n\n');
fprintf(fid, '/**\n');
fprintf(fid, ' * @var decision_tree[TREE_SIZE]\n');
fprintf(fid, ' * @brief Drzewo decyzyjne z %d węzłami\n', num_nodes);
fprintf(fid, ' * \n');
fprintf(fid, ' * Struktura drzewa odpowiada modelowi wytrenowanemu w MATLAB\n');
fprintf(fid, ' * Classification Learner. Każdy węzeł zawiera:\n');
fprintf(fid, ' * - Indeks testowanej cechy (0-%d dla cech, -1 dla liścia)\n', num_features-1);
fprintf(fid, ' * - Próg podziału (wartość znormalizowana)\n');
fprintf(fid, ' * - Wskaźniki do dzieci (indeksy w tablicy)\n');
fprintf(fid, ' * - Etykietę klasy dla liścia\n');
fprintf(fid, ' * - Prawdopodobieństwo przypisania\n');
fprintf(fid, ' * \n');
fprintf(fid, ' * UWAGA: Wartości progowe są znormalizowane (Z-score).\n');
fprintf(fid, ' * \n');
fprintf(fid, ' * Implementacja własna - autor Pavel Tshonek.\n');
fprintf(fid, ' */\n');
fprintf(fid, 'const TreeNode decision_tree[TREE_SIZE] = {\n');

% Wypisanie wszystkich węzłów
for node_idx = 1:num_nodes
    node = tree_nodes{node_idx};
    
    % MATLAB indeksuje od 1, C od 0
    c_idx = node_idx - 1;
    left_child_c = node.left_child - 1;
    right_child_c = node.right_child - 1;
    
    % Komentarz z informacją o węźle
    if node.feature_index == -1
        % Liść
        class_name = 'UNKNOWN';
        for i = 1:length(class_names_matlab)
            if isKey(class_code_map, char(class_names_matlab(i))) && ...
               class_code_map(char(class_names_matlab(i))) == node.class_label
                class_name = char(class_names_matlab(i));
                break;
            end
        end
        fprintf(fid, '    // WĘZEŁ %d: LIŚĆ - %s\n', c_idx, class_name);
    else
        % Węzeł wewnętrzny
        feat_name = 'UNKNOWN';
        for i = 1:length(feature_mapping)
            if feature_index_map(feature_mapping{i}) == node.feature_index
                feat_name = feature_mapping{i};
                break;
            end
        end
        fprintf(fid, '    // WĘZEŁ %d: test %s <= %.10f\n', c_idx, feat_name, node.threshold);
    end
    
    fprintf(fid, '    {\n');
    fprintf(fid, '        .feature_index = %d,\n', node.feature_index);
    
    if node.threshold == 0
        fprintf(fid, '        .threshold = 0.0f,\n');
    else
        fprintf(fid, '        .threshold = %.10ff,\n', node.threshold);
    end
    
    fprintf(fid, '        .left_child = %d,\n', left_child_c);
    fprintf(fid, '        .right_child = %d,\n', right_child_c);
    fprintf(fid, '        .class_label = %d,\n', node.class_label);
    fprintf(fid, '        .probability = %.6ff\n', node.probability);
    
    if node_idx < num_nodes
        fprintf(fid, '    },\n\n');
    else
        fprintf(fid, '    }\n');
    end
end

fprintf(fid, '};\n\n');

% Funkcja konwersji cech do tablicy
fprintf(fid, '// ========== FUNKCJE POMOCNICZE ==========\n\n');
fprintf(fid, '/**\n');
fprintf(fid, ' * @brief Konwertuje strukturę cech do tablicy w kolejności MATLAB\n');
fprintf(fid, ' * \n');
fprintf(fid, ' * Funkcja mapuje pola struktury MotorFeatures15 na tablicę\n');
fprintf(fid, ' * w dokładnej kolejności używanej przez model MATLAB.\n');
fprintf(fid, ' * Kolejność musi być identyczna jak podczas trenowania modelu.\n');
fprintf(fid, ' * \n');
fprintf(fid, ' * @param features Wskaźnik do struktury z cechami\n');
fprintf(fid, ' * @param array Tablica wyjściowa (%d elementów)\n', num_features);
fprintf(fid, ' * \n');
fprintf(fid, ' * Implementacja własna - autor Pavel Tshonek.\n');
fprintf(fid, ' */\n');
fprintf(fid, 'static void features_to_array(const MotorFeatures15* features, float* array) {\n');
fprintf(fid, '    // Mapowanie zgodne z kolejnością cech w MATLAB\n');

% Wypisanie mapowania
for i = 1:length(feature_mapping)
    % Zamiana nazwy cechy na nazwę pola struktury
    field_name = feature_mapping{i};
    fprintf(fid, '    array[%d] = features->%s;\n', i-1, field_name);
end

fprintf(fid, '}\n\n');

% Funkcja klasyfikacji z tablicy
fprintf(fid, '// ========== FUNKCJE KLASYFIKACYJNE ==========\n\n');
fprintf(fid, '/**\n');
fprintf(fid, ' * @brief Klasyfikuje stan silnika na podstawie tablicy cech\n');
fprintf(fid, ' * \n');
fprintf(fid, ' * Funkcja przetwarza drzewo decyzyjne od korzenia (węzeł 0)\n');
fprintf(fid, ' * do liścia, podejmując decyzje na podstawie znormalizowanych\n');
fprintf(fid, ' * wartości cech. Zawiera tryb debugowania pokazujący ścieżkę\n');
fprintf(fid, ' * decyzyjną.\n');
fprintf(fid, ' * \n');
fprintf(fid, ' * @param features Tablica %d znormalizowanych cech (Z-score)\n', num_features);
fprintf(fid, ' * @return Przewidziana klasa silnika (MotorClass)\n');
fprintf(fid, ' * \n');
fprintf(fid, ' * Implementacja własna - autor Pavel Tshonek.\n');
fprintf(fid, ' */\n');
fprintf(fid, 'MotorClass tree_predict_from_array(const float features[NUM_FEATURES]) {\n');
fprintf(fid, '    int node_idx = 0;  // Start od korzenia (węzeł 0)\n');
fprintf(fid, '    \n');
fprintf(fid, '    printf("\\n=== ŚCIEŻKA DECYZYJNA DRZEWA ===\\n");\n');
fprintf(fid, '    \n');
fprintf(fid, '    while (1) {\n');
fprintf(fid, '        const TreeNode* node = &decision_tree[node_idx];\n');
fprintf(fid, '        \n');
fprintf(fid, '        // Sprawdzenie czy węzeł jest liściem\n');
fprintf(fid, '        if (node->feature_index == -1) {\n');
fprintf(fid, '            printf("LIŚĆ Węzeł %%d -> Klasa %%s (id=%%d, prawdopodobieństwo=%%.3f)\\n", \n');
fprintf(fid, '                   node_idx, class_names[node->class_label], \n');
fprintf(fid, '                   node->class_label, node->probability);\n');
fprintf(fid, '            return (MotorClass)node->class_label;\n');
fprintf(fid, '        }\n');
fprintf(fid, '        \n');
fprintf(fid, '        // Pobranie wartości testowanej cechy\n');
fprintf(fid, '        float value = features[node->feature_index];\n');
fprintf(fid, '        \n');
fprintf(fid, '        // Wyświetlenie informacji debugowej\n');
fprintf(fid, '        printf("Węzeł %%d: cecha[%%d]=%%.6f <= %%.6f? ", \n');
fprintf(fid, '               node_idx, node->feature_index, value, node->threshold);\n');
fprintf(fid, '        \n');
fprintf(fid, '        // Podjęcie decyzji: przejście do lewego lub prawego dziecka\n');
fprintf(fid, '        if (value <= node->threshold) {\n');
fprintf(fid, '            printf("TAK -> przejdź do węzła %%d\\n", node->left_child);\n');
fprintf(fid, '            node_idx = node->left_child;\n');
fprintf(fid, '        } else {\n');
fprintf(fid, '            printf("NIE -> przejdź do węzła %%d\\n", node->right_child);\n');
fprintf(fid, '            node_idx = node->right_child;\n');
fprintf(fid, '        }\n');
fprintf(fid, '        \n');
fprintf(fid, '        // Zabezpieczenie przed błędnymi indeksami\n');
fprintf(fid, '        if (node_idx < 0 || node_idx >= TREE_SIZE) {\n');
fprintf(fid, '            printf("BŁĄD: Nieprawidłowy indeks węzła %%d!\\n", node_idx);\n');
fprintf(fid, '            // Zwróć domyślną klasę w przypadku błędu\n');
fprintf(fid, '            // Zmień na odpowiednią klasę domyślną\n');
fprintf(fid, '            for (int i = 0; i < NUM_CLASSES; i++) {\n');
fprintf(fid, '                if (strcmp(class_names[i], "Elec_Damage") == 0) {\n');
fprintf(fid, '                    return (MotorClass)i;\n');
fprintf(fid, '                }\n');
fprintf(fid, '            }\n');
fprintf(fid, '            return (MotorClass)0;\n');
fprintf(fid, '        }\n');
fprintf(fid, '    }\n');
fprintf(fid, '}\n\n');

% Funkcja klasyfikacji ze struktury
fprintf(fid, '/**\n');
fprintf(fid, ' * @brief Klasyfikuje stan silnika na podstawie struktury cech\n');
fprintf(fid, ' * \n');
fprintf(fid, ' * Wrapper funkcji tree_predict_from_array() konwertujący\n');
fprintf(fid, ' * strukturę MotorFeatures15 do tablicy przed klasyfikacją.\n');
fprintf(fid, ' * \n');
fprintf(fid, ' * @param features Wskaźnik do struktury z cechami diagnostycznymi\n');
fprintf(fid, ' * @return Przewidziana klasa silnika (MotorClass)\n');
fprintf(fid, ' * \n');
fprintf(fid, ' * Implementacja własna - autor Pavel Tshonek.\n');
fprintf(fid, ' */\n');
fprintf(fid, 'MotorClass tree_predict(const MotorFeatures15* features) {\n');
fprintf(fid, '    float feature_array[NUM_FEATURES];\n');
fprintf(fid, '    features_to_array(features, feature_array);\n');
fprintf(fid, '    return tree_predict_from_array(feature_array);\n');
fprintf(fid, '}\n');

fclose(fid);

fprintf('Plik %s wygenerowany pomyślnie.\n', source_filename);

%% INFORMACJE KOŃCOWE
fprintf('\n================================================================\n');
fprintf('KONWERSJA ZAKOŃCZONA POMYŚLNIE\n');
fprintf('================================================================\n\n');

fprintf('WYGENEROWANE PLIKI:\n');
fprintf('  tree_model.h - %d węzłów, %d klas, %d cech\n', num_nodes, num_classes, num_features);
fprintf('  tree_model.c - pełna implementacja modelu\n\n');

fprintf('INSTRUKCJE DLA ESP32:\n');
fprintf('  1. Skopiować oba pliki do projektu ESP32\n');
fprintf('  2. Upewnić się, że istnieje plik feature_extractor_15.h\n');
fprintf('  3. Dołączyć tree_model.h w kodzie: #include "tree_model.h"\n');
fprintf('  4. Użyć funkcji tree_predict() do klasyfikacji\n\n');

fprintf('UWAGI:\n');
fprintf('  - Sprawdzić, czy mapowanie cech i klas jest poprawne\n');
fprintf('  - Jeśli nazwy cech/klas się różnią, zmodyfikować sekcję mapping\n');
fprintf('  - Wartości progowe są znormalizowane (Z-score)\n');
fprintf('  - Prawdopodobieństwa są obliczane na podstawie danych treningowych\n');

% Wyświetlenie przykładowego wywołania
fprintf('\nPRZYKŁADOWE UŻYCIE W ESP32:\n');
fprintf('  MotorFeatures15 features;\n');
fprintf('  // Wypełnić strukturę features\n');
fprintf('  MotorClass result = tree_predict(&features);\n');
fprintf('  printf("Silnik jest w stanie: %%s\\n", class_names[result]);\n');

fprintf('\n================================================================\n');