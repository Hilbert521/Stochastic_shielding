# Matlab code for Pu and Thomas' Neural Computation paper
## Fast and Accurate Langevin Simulations of Stochas-tic Hodgkin-Huxley Dynamics
1. Figure 1 (HH diagram) is generated by the tex code
2. Figure 2 (4D and 14D HH models) can be generated from codes in folder "Figure2", it takes roughly 3-5 minutes to run the script Fig2.m
3. Figure 3 (convergence to the multinomial submanifold) can be generated by codes in folder "Figure3", it takes roughly 3-5 minutes to run the script Fig3.m
4. Figure 4 (Edge importance under voltage clamp) is reproduced with permission from Figs. 10 & 13 of [Schmidt and Thmas (2014) paper](https://pubmed.ncbi.nlm.nih.gov/24742077/)
5. Figure 5 (edge importance under current clamp) can be reproduced from codes in folder "Figure5". 
   - to generate figure 5, one needs to run hundreds repeated simulations, high performance computing is recommended
   - one can modify the code gene_data_SS.m to generat desired many samples
   - fig5data.mat can be loaded and viewed by plot_fig5.m
6. Figure 6 (pathwise equivalency) can be generated by the code Fig6.m, which takes roughly 1-2 minutes to run.
7. Codes for Table 3, Figure 7, 8 and 9 are all included in  the file "All_models"
   - cluster computing or high performance computing is highly recommended for generating the data for these tables and figures
   - details of the simulation for the paper is specified in Section 5
   - simulation efficiency is computed through the same laptop, the time might be different using different machines but the ratio should  be roughly the same
   - since the data for all plots are more than 500 MB, data for the plots are not uploaded here but one should be able to re-generate the data with the provided code

