## This file contains all Matlab codes needed to generate model comparison in the paper.

1. compare_ISI_all.m : script to calculate L1-Wasserstein distances after collecting sufficiently large number of ISI samples from each model

2. function for different models: 
	- Dangerfield.m (Dangerfield et al 2012) 
	- Fox97 (Fox 1997)
	- FoxandLu94 (Fox and Lu's matrix square root method in 1994, reflecting BCs)
	- Goldwyn (Goldwyn et al 2011)
	- FoxLu_StoHH (Fox and Lu 1994's method of using "skip that" method)
	- HH14D (deterministic 14D HH model)
	- HH14D_skip (stochastic 14D HH model using "skip that" method)
	- HHSS14D (stochastic 14D HH model)
	- HHSto15D (stochastic 14D HH model but save time vector as well)
	- MC (markov chain model, adapted from Golwyn et al, 2011)
	- OrioSoudry (Orio et all 2012)

3. run_models.m  example code to run different models
	

4. Table 3, Figure 7, Figure 8, Figure 9 are generated by codes in this file. Repeated simulations with different random number generator seeds are used for different trails.
For more details, please refer to the paper.
