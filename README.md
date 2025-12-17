
# Cecchi_2025_attention_norm_RL

This repository contains the behavioral analyses, eye-tracking pipelines, and model fitting/simulation scripts for the study:

**"Elucidating Attentional Mechanisms Underlying Value Normalization in Human Reinforcement Learning"**  
Authors: Romane Cecchi, Sebastian Gluth, Stefano Palminteri  
Year: 2025

---

## Overview

This project includes analyses of data from three reinforcement learning experiments designed to investigate how attention—manipulated via top-down and bottom-up mechanisms—influences value computation through range normalization. It includes:

- Behavioral performance analyses
- Analyses of eye-tracking data
- Model fitting and simulation routines for the attentional normalization hypotheses

---

## 📁 Folder Structure

```
Cecchi_2025_attention_norm_RL/
├── behavior_cecchi2025.m                  % Behavioral analysis script
├── eye_behavior_cecchi2025.m              % Eye-tracking fixation analysis script
├── model_fitting_cecchi2025.m             % Main model-fitting entry point (models 1–14)
├── model_fitting_incremental_window.m     % Incremental attentional window sweep (model 15)
├── model_fitting_discrete_window.m        % Discrete attentional window sweep (model 16)
├── model_simulation_cecchi2025.m          % Simulation pipeline using fitted parameters
├── Data/
│   ├── e1_forced_data.mat                 % Data for Experiment 1 (top-down attention)
│   ├── e2_lum_stim_data.mat               % Data for Experiment 2 (stimulus saliency)
│   ├── e3_lum_out_data.mat                % Data for Experiment 3 (outcome saliency)
│   └── Eye_data/                          % Raw eye-tracking data (stimuli/outcome fixations)
├── Figures/
│   ├── Behavior/                          % Behavioral plots
│   ├── Eye/                               % Eye-tracking plots
│   ├── Fitting/                           % Model comparison + window sweep figures
│   └── Simulation/                        % Outputs from `model_simulation_cecchi2025.m`
├── Modelling_results/                     % .mat files storing fitted parameters and simulations
└── Subfunctions/                          % Supporting functions shared across scripts
```

---

## Usage

### 1. Behavioral Analyses

Run:

```matlab
behavior_cecchi2025
```

Configure the script by setting:

- `opt.task`: experiment to analyze (`'e1_forced'`, `'e2_lum_stim'`, `'e3_lum_out'`)
- `opt.analyse`: type of behavioral analysis (1–5; see script header for full list)

### 2. Eye-Tracking Analyses

Run:

```matlab
eye_behavior_cecchi2025
```

Configure the script by setting:

- `init.task`: experiment to analyze
- `init.analyse`: type of fixation analysis (see script header for full list)

### 3. Model Fitting

Run:

```matlab
model_fitting_cecchi2025
```

Key options in the script:

- `opt.task`: experiment to fit (`'e1_forced'`, `'e2_lum_stim'`, `'e3_lum_out'`)
- `opt.whichmodel`: subset of models 1–14 to evaluate (see script header for descriptions)
- `opt.phase_fit`: `'learning'`, `'transfer'`, or `'both'`

Fitted parameters, likelihoods, and metadata are saved in `Modelling_results/fitting_<phase>_phase_cecchi2025_<task>.mat`.  
In the manuscript, the main model space (Figure 4, Tables 2–3) corresponds to models 1–5, and the model comparison uses `opt.phase_fit = 'both'`.
Use the dedicated scripts for the attentional window analyses:

- `model_fitting_incremental_window.m` (model 15, Figure 7): grid-search incremental fixation windows via `opt.times`
- `model_fitting_discrete_window.m` (model 16, Supplementary Figure 8): discrete window analysis across time bins

Both scripts export their `.mat` summaries and heatmap figures (stored in `Figures/Fitting/`).

### 4. Model Simulations

Run:

```matlab
model_simulation_cecchi2025
```

This script loads the previously saved fits (`opt.fit_phase`) and runs ex-post simulations (`opt.repet` repetitions per participant) for the models listed in `opt.model_idx`. In the paper, simulations use the parameters fitted on the learning phase only (`opt.phase_fit = 'learning'`). Simulation outputs (choice probabilities, Q-values, etc.) and the accompanying figures are saved to `Modelling_results/` and `Figures/Simulation/`.

---

## Dependencies

- MATLAB (tested with R2024b or later)
- MATLAB Optimization Toolbox (`fmincon`) and Statistics and Machine Learning Toolbox (`fitrm`, `ranova`)
- VBA-toolbox for Bayesian model comparison
- Subfunctions (in `Subfunctions/` folder)
- `.mat` files containing behavioral data (`header` and `expe` structures)
- `.mat` files containing eye-tracking data

---

## Output

Figures will be automatically saved in the `Figures/` directory.

---

## Citation

If you use this code, please cite the associated preprint or publication:

> Cecchi, R., Gluth, S., & Palminteri, S. (2025). *Elucidating Attentional Mechanisms Underlying Value Normalization in Human Reinforcement Learning*.

---

## Contact

For questions or issues, please contact **Romane Cecchi** at [romane.cecchi@gmail.com].

---
