# System Diagnostyczny Silników BLDC - Implementacja MATLAB

---

## Opis Projektu

Kompleksowy system diagnostyki uszkodzeń silników BLDC oparty na analizie sygnałów prądowych z wykorzystaniem **czterech metod ekstrakcji cech** i **33 modeli uczenia maszynowego**.

---

## Struktura Plików

### Pliki główne

- **`main.m`** - główny skrypt zarządzający procesem ekstrakcji cech
- **`create_ens_for_method.m`** - konfiguracja fileEnsembleDatastore dla Diagnostic Feature Designer
- **`generator_wykresow.m`** - generowanie wykresów wyników modeli ML
- **`tree_converter.m`** - konwerter modelu drzewa decyzyjnego z MATLAB do kodu C dla ESP32S3

### Funkcje ekstrakcji cech

- **`extract_time_domain_features.m`** - Metoda 1: analiza czasowa + filtrowanie pasmowe
- **`extract_ar_features_durand_kerner.m`** - Metoda 2: model AR(10) + algorytm Durand-Kernera
- **`extract_fft_envelope_features.m`** - Metoda 3: FFT + analiza obwiedni
- **`extract_wavelet_features.m`** - Metoda 4: transformata falkowa + Fisher Ratio

---

## Metody Analizy Sygnałów

### Metoda 1: Analiza czasowa z filtrowaniem pasmowym

**Liczba cech:** 49

**Pasma częstotliwości:**
- 100-500 Hz
- 500-2000 Hz
- 2000-5000 Hz
- 5000-10000 Hz
- 10000-15000 Hz
- 15000-20000 Hz

**Cechy czasowe:**
- Średnia
- Odchylenie standardowe
- RMS
- Maksimum
- Amplituda międzyszczytowa
- Skośność
- Kurtoza
- Współczynnik szczytowości

**Cechy widmowe:**
- Środek częstotliwościowy
- Pole widma
- Amplitudy harmonicznych (1x, 2x, 3x)

---

### Metoda 2: Model AR z algorytmem Durand-Kernera

**Liczba cech:** 120

**Rząd modelu AR:** p=10

**Cechy:**
- AIC (Kryterium Informacyjne Akaike)
- MAE (Średni błąd bezwzględny)
- Częstotliwość dominująca
- Tłumienie
- RMS reszt
- Energia IMF1

---

### Metoda 3: FFT z analizą obwiedni

**Liczba cech:** 96

**Proces:** FFT → filtrowanie pasmowe → transformata Hilberta → FFT obwiedni

**Cechy dla każdego pasma:**
- Energia widma
- 3 częstotliwości dominujące
- Amplitudy
- RMS
- Wartość szczytowa
- Energia obwiedni

---

### Metoda 4: Transformata falkowa

**Liczba cech:** 54

**Fala falkowa:** db4 (Daubechies 4)

**Poziomy dekompozycji:** 8 + trending

**Cechy na poziom:**
- Energia
- RMS
- Kurtoza
- Entropia
- Skośność
- Peak2RMS

---

## Klasyfikacja Stanów Silnika

System rozpoznaje **4 stany** silnika BLDC:

1. **Zdrowy** (Healthy)
2. **Uszkodzenie mechaniczne** (Mech_Damage)
3. **Uszkodzenie elektryczne** (Elec_Damage)
4. **Uszkodzenie kombinowane** (Mech_Elec_Damage)

---

## Modele Uczenia Maszynowego

System testuje **33 modele** z MATLAB Classification Learner:

### Decision Trees

- Fine Tree
- Medium Tree
- Coarse Tree

### Discriminant Analysis

- Linear Discriminant
- Quadratic Discriminant

### Efficiently Trained Linear Classifiers

- Efficient Logistic Regression
- Efficient Linear SVM

### Naive Bayes Classifiers

- Gaussian Naive Bayes
- Kernel Naive Bayes

### Support Vector Machines

- Linear SVM
- Quadratic SVM
- Cubic SVM
- Fine Gaussian SVM
- Medium Gaussian SVM
- Coarse Gaussian SVM

### Nearest Neighbor Classifiers

- Fine KNN
- Medium KNN
- Coarse KNN
- Cosine KNN
- Cubic KNN
- Weighted KNN

### Ensemble Classifiers

- Boosted Trees
- Bagged Trees
- Subspace Discriminant
- Subspace KNN
- RUSBoosted Trees

### Neural Network Classifiers

- Narrow Neural Network
- Medium Neural Network
- Wide Neural Network
- Bilayered Neural Network
- Trilayered Neural Network

### Kernel Approximation Classifiers

- SVM Kernel
- Logistic Regression Kernel

---

## Struktura Folderów Wyjściowych

```
FeatureTables/
├── Train/              # Zbiory treningowe cech
├── Test/               # Zbiory testowe cech
├── Robustness/         # Testy odporności (7 scenariuszy)
└── Combined/           # Cechy połączone wszystkich metod

DFD_Method[1-4]/        # Dane dla Diagnostic Feature Designer
├── train/              # Member-y treningowe
└── test/               # Member-y testowe

ML_Features_C_Exact/    # Cechy zgodne z implementacją C na ESP32

Analysis_Plots/         # Wykresy analityczne

Robustness_Signals/     # Sygnały do testów odporności
```

---

## Instrukcja Użycia

### 1. Uruchomienie głównego skryptu

```matlab
% Uruchom główny skrypt
main
```

Skrypt interaktywnie zapyta o:
- Wybór metod do uruchomienia (1-4 lub wszystkie)
- Włączenie augmentacji danych treningowych
- Generowanie testów odporności (7 scenariuszy)
- Analizę ważności cech

---

### 2. Generowanie danych dla Diagnostic Feature Designer

```matlab
% Konfiguracja ensemble datastore dla wybranej metody
ens_train = create_ens_for_method(1, 'train');
ens_test = create_ens_for_method(1, 'test');

% Otwarcie Diagnostic Feature Designer
diagnosticFeatureDesigner(ens_train);
```

---

### 3. Trenowanie modeli uczenia maszynowego

```matlab
% Wczytanie danych treningowych
load('FeatureTables/Train/M1_time_domain_train.mat');

% Uruchomienie Classification Learner
classificationLearner
```

---

### 4. Konwersja modelu drzewa decyzyjnego do C

```matlab
% Wytrenować model drzewa decyzyjnego w Classification Learner
% Wyeksportować model jako 'trainedModel' do przestrzeni roboczej
% Uruchomić konwerter
tree_converter

% Skrypt wygeneruje pliki tree_model.h i tree_model.c
% gotowe do implementacji na ESP32S3
```

**Uwagi dotyczące konwersji:**
- Mapowanie cech musi być zgodne z kolejnością w strukturze MotorFeatures15
- Wartości progowe są znormalizowane (Z-score)
- Wygenerowane pliki zawierają pełną implementację drzewa decyzyjnego w C
- Kod zawiera funkcje debugowania pokazujące ścieżkę decyzyjną

---

### 5. Testy odporności

Testy odporności automatycznie generowane przez main.m

Pliki dostępne w folderze `FeatureTables/Robustness/`

**Scenariusze testowe:**
- Frequency shift
- Amplitude fluctuation
- Noise
- Combined
- Extreme amplitude
- Unknown distribution

---

### 6. Generowanie wykresów analitycznych

```matlab
% Generowanie 4 wykresów analitycznych wyników ML
generator_wykresow
```

---

## Parametry Techniczne

| Parametr | Wartość |
|----------|---------|
| Częstotliwość próbkowania | 50 kHz |
| Liczba próbek na eksperyment | 32768 (2^15) |
| Zbiór treningowy | 176 sygnałów |
| Po augmentacji | 3344 sygnały |
| Zbiór testowy | 44 sygnały |
| Normalizacja | Z-score na podstawie zbioru treningowego |
| Walidacja krzyżowa | 5 foldów (po augmentacji 10) |

---

## Dane pomiarowe

Wykorzystano zbiór DUDU-BLDC do walidacji systemu (https://explore.openaire.eu/search/result?pid=10.5281%2Fzenodo.15522163)

## Dołączone ML modele

- **Kernel_Naive_Bayes.mat** - najlepszy model 3 metody po augmentacji danych
- **fine_tree_model.mat** - jeden z najlepszych modeli drugiej metody (zaimplementowany model na mikrokontroler)
