%% ========================================================================
% WIZUALIZACJA WYNIKÓW MODELI UCZENIA MASZYNOWEGO
% ========================================================================
%
% Plik:        generator_wykresow.m
% Autor:       Pavel Tshonek (155068)
% Data:        2026-01
% Opis:        Skrypt do wizualizacji wyników testów modeli ML
%
% CEL:
%   Wygenerowanie kompleksowej wizualizacji wyników testów 33 modeli
%   uczenia maszynowego. Skrypt analizuje pliki CSV eksportowane z
%   MATLAB Classification Learner i tworzy 4 wykresy analityczne.
%
% FUNKCJONALNOŚĆ:
%   1. Wczytanie danych z pliku CSV
%   2. Przygotowanie danych do wizualizacji
%   3. Generowanie 4 wykresów analitycznych
%   4. Wyświetlenie statystyk końcowych
%
% WYKRESY GENEROWANE:
%   1. Dokładność wszystkich modeli (test)
%   2. Porównanie walidacja vs test
%   3. Analiza overfitting/underfitting
%   4. Top 10 najlepszych modeli
%
% KLASYFIKACJA MODELI:
%   - Wysoko precyzyjne: ≥95% dokładności
%   - Standardowe: 80-95% dokładności
%   - Niedokładne: <80% dokładności
%   - Overfitting: różnica walidacja-test >5%
%   - Underfitting: różnica walidacja-test <-5%
%
% ŹRÓDŁO DANYCH:
%   Pliki CSV wyeksportowane z MATLAB Classification Learner
%   zawierające wyniki dla 33 modeli uczenia maszynowego.
%

clear; clc; close all;

fprintf('================================================================\n');
fprintf('WIZUALIZACJA WYNIKÓW MODELI UCZENIA MASZYNOWEGO\n');
fprintf('================================================================\n\n');

%% FUNKCJE POMOCNICZE - MAPOWANIE NAZW MODELI
function model_name = getModelName(model_number)
% PRZYPORZĄDKOWANIE NUMERÓW MODELI DO ICH NAZW
%
% Wejście:
%   model_number - numer modelu według Classification Learner
%
% Wyjście:
%   model_name - czytelna nazwa modelu
%
% Opis:
%   Zmapowano numery modeli z Classification Learner na czytelne nazwy.
%   System numeracji odpowiada 33 modelom testowanym w pracy dyplomowej.

    switch model_number
        case 2.1, model_name = 'Fine Tree';
        case 2.2, model_name = 'Medium Tree';
        case 2.3, model_name = 'Coarse Tree';
        case 2.4, model_name = 'Linear Discriminant';
        case 2.5, model_name = 'Quadratic Discriminant';
        case 2.6, model_name = 'Efficient Logistic Regression';
        case 2.7, model_name = 'Efficient Linear SVM';
        case 2.8, model_name = 'Gaussian Naive Bayes';
        case 2.9, model_name = 'Kernel Naive Bayes';
        case 2.10, model_name = 'Linear SVM';
        case 2.11, model_name = 'Quadratic SVM';
        case 2.12, model_name = 'Cubic SVM';
        case 2.13, model_name = 'Fine Gaussian SVM';
        case 2.14, model_name = 'Medium Gaussian SVM';
        case 2.15, model_name = 'Coarse Gaussian SVM';
        case 2.16, model_name = 'Fine KNN';
        case 2.17, model_name = 'Medium KNN';
        case 2.18, model_name = 'Coarse KNN';
        case 2.19, model_name = 'Cosine KNN';
        case 2.20, model_name = 'Cubic KNN';
        case 2.21, model_name = 'Weighted KNN';
        case 2.22, model_name = 'Boosted Trees';
        case 2.23, model_name = 'Bagged Trees';
        case 2.24, model_name = 'Subspace Discriminant';
        case 2.25, model_name = 'Subspace KNN';
        case 2.26, model_name = 'RUSBoosted Trees';
        case 2.27, model_name = 'Narrow Neural Network';
        case 2.28, model_name = 'Medium Neural Network';
        case 2.29, model_name = 'Wide Neural Network';
        case 2.30, model_name = 'Bilayered Neural Network';
        case 2.31, model_name = 'Trilayered Neural Network';
        case 2.32, model_name = 'SVM Kernel';
        case 2.33, model_name = 'Logistic Regression Kernel';
        otherwise, model_name = sprintf('Model %.2f', model_number);
    end
end

function category = getModelCategory(model_name)
% KLASYFIKACJA MODELI DO KATEGORII
%
% Wejście:
%   model_name - nazwa modelu
%
% Wyjście:
%   category - kategoria modelu (Tree, Ensemble, SVM, etc.)
%
% Opis:
%   Przypisano modele do 7 głównych kategorii na podstawie
%   ich nazw. Kategoryzacja ułatwia analizę porównawczą.

    if contains(model_name, 'Tree') && ~contains(model_name, 'Boost') && ~contains(model_name, 'Bag')
        category = 'Tree';
    elseif contains(model_name, 'Boost') || contains(model_name, 'Bag') || contains(model_name, 'Subspace')
        category = 'Ensemble';
    elseif contains(model_name, 'SVM')
        category = 'SVM';
    elseif contains(model_name, 'KNN')
        category = 'KNN';
    elseif contains(model_name, 'Neural')
        category = 'Neural Network';
    elseif contains(model_name, 'Discriminant')
        category = 'Discriminant';
    elseif contains(model_name, 'Regression')
        category = 'Regression';
    elseif contains(model_name, 'Bayes')
        category = 'Naive Bayes';
    else
        category = 'Other';
    end
end

%% WCZYTANIE PLIKU Z DANYMI
fprintf('Wykaz dostępnych plików CSV:\n');
csv_files = dir('*.csv');
for i = 1:length(csv_files)
    fprintf('   %d. %s\n', i, csv_files(i).name);
end

file_choice = input('Wprowadź numer pliku do analizy: ', 's');
file_idx = str2double(file_choice);
filename = csv_files(file_idx).name;

fprintf('Rozpoczęto wczytywanie pliku: %s\n', filename);

%% PRZYGOTOWANIE DANYCH DO ANALIZY
% Wykryto i wczytano nagłówki pliku CSV
fid = fopen(filename, 'r');
file_content = fread(fid, '*char')';
fclose(fid);
lines = strsplit(file_content, {'\r\n', '\n', '\r'});

% Znaleziono linię z nagłówkami
header_line_num = 0;
for i = 1:length(lines)
    if contains(lines{i}, 'Model Number') && contains(lines{i}, 'Accuracy')
        header_line_num = i;
        break;
    end
end

% Wczytano dane z uwzględnieniem znalezionej linii nagłówka
opts = detectImportOptions(filename, 'NumHeaderLines', header_line_num - 1);
data = readtable(filename, opts);

%% EKSTRAKCJA KOLUMN Z DANYMI
col_names = data.Properties.VariableNames;

% Zidentyfikowano odpowiednie kolumny
for i = 1:length(col_names)
    if contains(col_names{i}, 'ModelNumber', 'IgnoreCase', true)
        model_num_col = col_names{i};
    end
    if contains(col_names{i}, 'ModelType', 'IgnoreCase', true)
        model_type_col = col_names{i};
    end
    if contains(col_names{i}, 'Validation', 'IgnoreCase', true) && contains(col_names{i}, 'Accuracy')
        acc_val_col = col_names{i};
    end
    if contains(col_names{i}, 'Test', 'IgnoreCase', true) && contains(col_names{i}, 'Accuracy')
        acc_test_col = col_names{i};
    end
end

n = height(data);
model_nums = zeros(n, 1);
acc_vals = zeros(n, 1);
acc_tests = zeros(n, 1);
model_types = cell(n, 1);

% Skonwertowano dane do odpowiednich formatów
for i = 1:n
    val = data.(model_num_col)(i);
    if iscell(val), model_nums(i) = val{1}; else, model_nums(i) = val; end
    
    val = data.(model_type_col)(i);
    if iscell(val), model_types{i} = val{1}; else, model_types{i} = char(val); end
    
    val = data.(acc_val_col)(i);
    if iscell(val), acc_vals(i) = val{1}; else, acc_vals(i) = val; end
    
    val = data.(acc_test_col)(i);
    if iscell(val), acc_tests(i) = val{1}; else, acc_tests(i) = val; end
end

% Usunięto rekordy z brakującymi wartościami
valid = ~isnan(acc_vals) & ~isnan(acc_tests);
model_nums = model_nums(valid);
model_types = model_types(valid);
acc_vals = acc_vals(valid);
acc_tests = acc_tests(valid);

% Posortowano modele według malejącej dokładności testowej
[acc_tests, idx] = sort(acc_tests, 'descend');
model_nums = model_nums(idx);
model_types = model_types(idx);
acc_vals = acc_vals(idx);

% Wygenerowano nazwy i kategorie dla wszystkich modeli
n = length(acc_tests);
model_names = cell(n, 1);
categories = cell(n, 1);
for i = 1:n
    model_names{i} = getModelName(model_nums(i));
    categories{i} = getModelCategory(model_names{i});
end

% Obliczono różnice między walidacją a testem (wskaźnik overfitting)
diff = acc_vals - acc_tests;

fprintf('Przygotowano dane dla %d modeli\n\n', n);

%% WYKRES 1: DOKŁADNOŚĆ WSZYSTKICH MODELI (TEST)
figure('Position', [100, 100, 1400, 700], 'Name', 'Dokładność wszystkich modeli');

x_pos = 1:n;

% Przypisano kolory według poziomu dokładności
colors_accuracy = zeros(n, 3);
for i = 1:n
    if acc_tests(i) >= 95
        colors_accuracy(i, :) = [0.1 0.7 0.1]; % Zielony - wysoko precyzyjny
    elseif acc_tests(i) >= 80 && acc_tests(i) < 95
        colors_accuracy(i, :) = [0.2 0.6 0.8]; % Niebieski - standardowy
    else 
        colors_accuracy(i, :) = [0.9 0.1 0.1]; % Czerwony - niedokładny
    end
end

% Narysowano słupki z przypisanymi kolorami
for i = 1:n
    bar(i, acc_tests(i), 'FaceColor', colors_accuracy(i, :), 'EdgeColor', 'k', 'LineWidth', 1.5);
    hold on;
end

xlabel('Model', 'FontSize', 14, 'FontWeight', 'bold');
ylabel('Dokładność (Test) (%)', 'FontSize', 14, 'FontWeight', 'bold');
title('DOKŁADNOŚĆ (TEST) - WSZYSTKIE MODELE', 'FontSize', 16, 'FontWeight', 'bold');
grid on;
ylim([0 105]);

set(gca, 'XTick', x_pos);
set(gca, 'XTickLabel', model_names);
xtickangle(45);
set(gca, 'FontSize', 9);

% Dodano wartości liczbowe nad słupkami
for i = 1:n
    text(i, acc_tests(i) + 1.5, sprintf('%.1f', acc_tests(i)), ...
        'HorizontalAlignment', 'center', 'FontSize', 7, 'FontWeight', 'bold');
end

% Dodano legendę z wyjaśnieniem kolorów
legend_x = n * 0.98;
legend_y_bottom = 3;
cm_to_units = 6;

text(legend_x, legend_y_bottom + 2*cm_to_units, '■ Zielony: Wysoko precyzyjny (≥95%)', ...
    'Color', [0.1 0.7 0.1], 'FontSize', 10, 'FontWeight', 'bold', ...
    'BackgroundColor', 'w', 'EdgeColor', 'k', 'HorizontalAlignment', 'right');
text(legend_x, legend_y_bottom + cm_to_units, '■ Niebieski: Standard (80-95%)', ...
    'Color', [0.2 0.6 0.8], 'FontSize', 10, 'FontWeight', 'bold', ...
    'BackgroundColor', 'w', 'EdgeColor', 'k', 'HorizontalAlignment', 'right');
text(legend_x, legend_y_bottom, '■ Czerwony: Niedokładny (<80%)', ...
    'Color', [0.9 0.1 0.1], 'FontSize', 10, 'FontWeight', 'bold', ...
    'BackgroundColor', 'w', 'EdgeColor', 'k', 'HorizontalAlignment', 'right');

hold off;

%% WYKRES 2: PORÓWNANIE WALIDACJA VS TEST
figure('Position', [100, 100, 1400, 700], 'Name', 'Porównanie walidacja vs test');

x_pos = 1:n;
bar_width = 0.35;

bar(x_pos - bar_width/2, acc_vals, bar_width, 'FaceColor', [0.8 0.4 0.2], 'EdgeColor', 'k');
hold on;
bar(x_pos + bar_width/2, acc_tests, bar_width, 'FaceColor', [0.2 0.6 0.8], 'EdgeColor', 'k');

xlabel('Model', 'FontSize', 14, 'FontWeight', 'bold');
ylabel('Dokładność (%)', 'FontSize', 14, 'FontWeight', 'bold');
title('PORÓWNANIE: WALIDACJA vs TEST', 'FontSize', 16, 'FontWeight', 'bold');
legend({'Walidacja', 'Test'}, 'Location', 'southeast', 'FontSize', 12);
grid on;
ylim([0 105]);

set(gca, 'XTick', x_pos);
set(gca, 'XTickLabel', model_names);
xtickangle(45);
set(gca, 'FontSize', 9);

% Oznaczono modele z overfittingiem
for i = 1:n
    if diff(i) > 10
        % Wysoki overfitting - czerwona flaga
        plot(i, max(acc_vals(i), acc_tests(i)) + 3, 'rv', 'MarkerSize', 12, ...
            'MarkerFaceColor', 'r', 'LineWidth', 2);
        text(i, max(acc_vals(i), acc_tests(i)) + 5, '!!!', ...
            'HorizontalAlignment', 'center', 'FontSize', 10, 'Color', 'r', 'FontWeight', 'bold');
    elseif diff(i) > 5
        % Umiarkowany overfitting - żółta flaga
        plot(i, max(acc_vals(i), acc_tests(i)) + 3, '^', 'MarkerSize', 10, ...
            'MarkerFaceColor', [1 0.8 0], 'MarkerEdgeColor', 'k', 'LineWidth', 1.5);
    end
end

%% WYKRES 3: ANALIZA OVERFITTING/UNDERFITTING
figure('Position', [100, 100, 1400, 700], 'Name', 'Analiza overfitting');

% Przypisano kolory według poziomu overfittingu
colors_overfit = zeros(n, 3);
for i = 1:n
    if diff(i) > 10
        colors_overfit(i, :) = [1 0.2 0.2]; % Czerwony - wysoki overfitting
    elseif diff(i) > 5
        colors_overfit(i, :) = [1 0.8 0]; % Żółty - umiarkowany overfitting
    elseif diff(i) < -5
        colors_overfit(i, :) = [0.5 0.5 1]; % Niebieski - underfitting
    else
        colors_overfit(i, :) = [0.2 0.8 0.2]; % Zielony - dobre dopasowanie
    end
end

x_pos = 1:n;
for i = 1:n
    bar(i, diff(i), 'FaceColor', colors_overfit(i, :), 'EdgeColor', 'k', 'LineWidth', 1.5);
    hold on;
end

xlabel('Model', 'FontSize', 14, 'FontWeight', 'bold');
ylabel('Różnica: Walidacja - Test (%)', 'FontSize', 14, 'FontWeight', 'bold');
title('ANALIZA OVERFITTING', 'FontSize', 16, 'FontWeight', 'bold');
grid on;
yline(0, 'k--', 'LineWidth', 2);
yline(5, 'Color', [1 0.8 0], 'LineWidth', 1.5, 'LineStyle', '--', 'DisplayName', 'Próg overfitting');
yline(10, 'r--', 'LineWidth', 1.5, 'DisplayName', 'Wysoki overfitting');

set(gca, 'XTick', x_pos);
set(gca, 'XTickLabel', model_names);
xtickangle(45);
set(gca, 'FontSize', 9);

% Dodano legendę z wyjaśnieniem kolorów
legend_x = n * 0.98;
cm_to_units = 1.5;
legend_y_bottom = -14;

text(legend_x, legend_y_bottom + 3*cm_to_units, '■ Zielony: Dobre dopasowanie', ...
    'Color', [0.2 0.8 0.2], 'FontSize', 10, 'FontWeight', 'bold', ...
    'BackgroundColor', 'w', 'EdgeColor', 'k', 'HorizontalAlignment', 'right');
text(legend_x, legend_y_bottom + 2*cm_to_units, '■ Żółty: Umiarkowany overfitting', ...
    'Color', [1 0.8 0], 'FontSize', 10, 'FontWeight', 'bold', ...
    'BackgroundColor', 'w', 'EdgeColor', 'k', 'HorizontalAlignment', 'right');
text(legend_x, legend_y_bottom + cm_to_units, '■ Czerwony: Wysoki overfitting', ...
    'Color', [1 0.2 0.2], 'FontSize', 10, 'FontWeight', 'bold', ...
    'BackgroundColor', 'w', 'EdgeColor', 'k', 'HorizontalAlignment', 'right');
text(legend_x, legend_y_bottom, '■ Niebieski: Underfitting', ...
    'Color', [0.5 0.5 1], 'FontSize', 10, 'FontWeight', 'bold', ...
    'BackgroundColor', 'w', 'EdgeColor', 'k', 'HorizontalAlignment', 'right');

%% WYKRES 4: TOP 10 NAJLEPSZYCH MODELI
figure('Position', [100, 100, 1200, 700], 'Name', 'Top 10 modeli');

top_n = min(10, n);
x_pos = 1:top_n;
bar_width = 0.35;

bar(x_pos - bar_width/2, acc_vals(1:top_n), bar_width, 'FaceColor', [0.8 0.4 0.2], 'EdgeColor', 'k');
hold on;
bar(x_pos + bar_width/2, acc_tests(1:top_n), bar_width, 'FaceColor', [0.2 0.6 0.8], 'EdgeColor', 'k');

xlabel('Model', 'FontSize', 14, 'FontWeight', 'bold');
ylabel('Dokładność (%)', 'FontSize', 14, 'FontWeight', 'bold');
title('TOP 10 MODELI - Walidacja vs Test', 'FontSize', 16, 'FontWeight', 'bold');
legend({'Walidacja', 'Test'}, 'Location', 'southeast', 'FontSize', 12);
grid on;
ylim([0 105]);

set(gca, 'XTick', x_pos);
set(gca, 'XTickLabel', model_names(1:top_n));
xtickangle(45);
set(gca, 'FontSize', 10);

% Dodano wartości liczbowe
for i = 1:top_n
    text(i - bar_width/2, acc_vals(i) + 1, sprintf('%.1f', acc_vals(i)), ...
        'HorizontalAlignment', 'center', 'FontSize', 7, 'FontWeight', 'bold');
    text(i + bar_width/2, acc_tests(i) + 1, sprintf('%.1f', acc_tests(i)), ...
        'HorizontalAlignment', 'center', 'FontSize', 7, 'FontWeight', 'bold');
end

fprintf('Wygenerowano 4 wykresy analityczne\n\n');

%% ANALIZA STATYSTYCZNA I PODSUMOWANIE
fprintf('================================================================\n');
fprintf('ANALIZA STATYSTYCZNA WYNIKÓW\n');
fprintf('================================================================\n\n');

fprintf('NAJLEPSZY MODEL:\n');
fprintf('   Dokładna nazwa: %s\n', model_names{1});
fprintf('   Numer modelu: %.1f\n', model_nums(1));
fprintf('   Ogólny typ: %s\n', model_types{1});
fprintf('   Dokładność walidacyjna: %.2f%%\n', acc_vals(1));
fprintf('   Dokładność testowa: %.2f%%\n', acc_tests(1));

if diff(1) > 10
    fprintf('   Status: WYSOKI OVERFITTING (+%.2f%%)\n', diff(1));
elseif diff(1) > 5
    fprintf('   Status: Umiarkowany overfitting (+%.2f%%)\n', diff(1));
elseif diff(1) < -5
    fprintf('   Status: Underfitting (%.2f%%)\n', diff(1));
else
    fprintf('   Status: Dobre dopasowanie (%.2f%%)\n', diff(1));
end

fprintf('\nREKOMENDACJE:\n');
fprintf('   1. NAJLEPSZY MODEL: %s (numer %.1f)\n', model_names{1}, model_nums(1));
if n >= 2
    fprintf('   2. DRUGI NAJLEPSZY MODEL: %s (numer %.1f)\n', model_names{2}, model_nums(2));
end
if n >= 3
    fprintf('   3. TRZECI NAJLEPSZY MODEL: %s (numer %.1f)\n', model_names{3}, model_nums(3));
end

fprintf('\nTOP 5 MODELI:\n');
for i = 1:min(5, n)
    fprintf('   %d. %-30s Test: %.2f%%  Walidacja: %.2f%%', ...
        i, model_names{i}, acc_tests(i), acc_vals(i));
    
    if diff(i) > 10
        fprintf('  WYSOKI OVERFITTING\n');
    elseif diff(i) > 5
        fprintf('  Overfitting\n');
    else
        fprintf('  Dobre dopasowanie\n');
    end
end

fprintf('\nSTATYSTYKI OGÓLNE:\n');
fprintf('   Test - Średnia: %.2f%%, Minimum: %.2f%%, Maksimum: %.2f%%\n', ...
    mean(acc_tests), min(acc_tests), max(acc_tests));
fprintf('   Walidacja - Średnia: %.2f%%, Minimum: %.2f%%, Maksimum: %.2f%%\n', ...
    mean(acc_vals), min(acc_vals), max(acc_vals));

% Obliczono statystyki overfittingu
high_overfit = sum(diff > 10);
moderate_overfit = sum(diff > 5 & diff <= 10);
good_fit = sum(diff <= 5 & diff >= -5);
underfit = sum(diff < -5);

fprintf('\nANALIZA OVERFITTING:\n');
fprintf('   Wysoki overfitting: %d modeli (%.1f%%)\n', high_overfit, 100*high_overfit/n);
fprintf('   Umiarkowany overfitting: %d modeli (%.1f%%)\n', moderate_overfit, 100*moderate_overfit/n);
fprintf('   Dobre dopasowanie: %d modeli (%.1f%%)\n', good_fit, 100*good_fit/n);
fprintf('   Underfitting: %d modeli (%.1f%%)\n', underfit, 100*underfit/n);

fprintf('\nAnaliza zakończona pomyślnie\n');