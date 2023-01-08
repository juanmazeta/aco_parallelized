/**
 * Ant Colony Optimization for the CellNopt
 *
 * @file ants.c
 * @author patricia.gonzalez@udc.es
 * @brief File contains procedures related with ants
 */
 
#include <stdio.h>
#include <stdlib.h>
#include <math.h>
#include <assert.h>
#include <limits.h>
#include <time.h>
#include "aco.h"

int * ant_solutions;            /* size [n_ants * n] */
int * best_so_far_ant_solution; /* size [n] */

double * ant_scores;            /* size [n_ants] */
double best_so_far_ant_score;   /* just the best */

double   *pheromone;

int n_ants;      /* number of ants */

double rho;           /* parameter for evaporation */
double q_0;           /* probability of best choice in tour construction */

int as_flag;     /* ant system */
int eas_flag;    /* elitist ant system */
int mmas_flag;   /* MAX-MIN ant system */

double   trail_max;       /* maximum pheromone trail in MMAS */
double   trail_min;       /* minimum pheromone trail in MMAS */
double   trail_0;         /* initial pheromone level */
int     u_gb;

int n;		/* problem size */


void allocate_ants ( void )
/*    
      FUNCTION:       allocate the memory for the ant colony, the best-so-far and 
                      the iteration best ant
      INPUT:          none
      OUTPUT:         none
      (SIDE)EFFECTS:  allocation of memory for the ant colony and two ants that 
                      store intermediate tours

*/
{

    /* ANTS */
    if((ant_solutions = (int*) malloc(sizeof( int ) * n_ants * n)) == NULL){
        printf("Out of memory, exit.");
        exit(1);
    }

    if((ant_scores = (double*) malloc(sizeof( double ) * n_ants)) == NULL){
        printf("Out of memory, exit.");
        exit(1);
    }

    /* BEST ANT */
    if((best_so_far_ant_solution = (int*) malloc(sizeof( int ) * n)) == NULL){
        printf("Out of memory, exit.");
        exit(1);
    }

}



int find_best( void )
/*    
      FUNCTION:       find the best ant of the current iteration
      INPUT:          none
      OUTPUT:         index of solution array containing the iteration best ant
      (SIDE)EFFECTS:  none
*/
{
    double   min;
    int   k, k_min;

    min = ant_scores[0];
    k_min = 0;
    for( k = 1 ; k < n_ants ; k++ ) {
        if( ant_scores[k] < min ) {
            min = ant_scores[k];
            k_min = k;
        }
    }
    return k_min;
}



int find_worst( void )
/*    
      FUNCTION:       find the worst ant of the current iteration
      INPUT:          none
      OUTPUT:         pointer to struct containing iteration best ant
      (SIDE)EFFECTS:  none
*/
{
    double   max;
    int   k, k_max;

    max = ant_scores[0];
    k_max = 0;
    for( k = 1 ; k < n_ants ; k++ ) {
        if( ant_scores[k] > max ) {
            max = ant_scores[k];
            k_max = k;
        }
    }
    return k_max;
}



/************************************************************
 ************************************************************
Procedures for pheromone manipulation 
 ************************************************************
 ************************************************************/


void check_pheromone_trail_limits( void )
/*
 FUNCTION:      MMAS keeps pheromone trails inside trail limits
 INPUT:         none
 OUTPUT:        none
 (SIDE)EFFECTS: pheromones are forced to interval [trail_min,trail_max]
 */
{
    int i, j;
    
    for ( i = 0 ; i < n ; i++ ) {
        for ( j = 0 ; j < 2 ; j++ ) {
            if ( pheromone[i * 2 + j] < trail_min ) {
                pheromone[i * 2 + j] = trail_min;
            } else if ( pheromone[i * 2 + j] > trail_max ) {
                pheromone[i * 2 + j] = trail_max;
            }
        }
    }
}


void init_pheromone_trails( double initial_trail )
/*
 FUNCTION:      initialize pheromone trails
 INPUT:         initial value of pheromone trails "initial_trail"
 OUTPUT:        none
 (SIDE)EFFECTS: pheromone matrix is reinitialized
 */
{
    int i, j;
    
    /* Initialize pheromone trails */
    for ( i = 0 ; i < n ; i++ ) {
        for ( j = 0 ; j < 2 ; j++ ) {
            pheromone[i * 2 + j] = initial_trail;
        }
    }
}


void evaporation( void )
/*    
      FUNCTION:      implements the pheromone trail evaporation
      INPUT:         none
      OUTPUT:        none
      (SIDE)EFFECTS: pheromones are reduced by factor rho
*/
{ 
    int    i, j;

    for ( i = 0 ; i < n ; i++ ) {
        for ( j = 0 ; j < 2 ; j++ ) {
            pheromone[i * 2 + j] = (1 - rho) * pheromone[i * 2 + j];
        }
    }
}


void global_update_pheromone( int *solutions, double score )
/*    
      FUNCTION:      reinforces edges used in ant k's solution
      INPUT:         index k of the ant that updates the pheromone trail [0, n_ants]
      OUTPUT:        none
      (SIDE)EFFECTS: pheromones of arcs in ant k's tour are increased
*/
{  
    int i, j;
    double   d_tau;

    d_tau = 1.0 / score;
 
    for ( i = 0 ; i < n ; i++ ) {
        j = solutions[i];
        pheromone[i * 2 + j] += d_tau;
    }
}


void global_update_pheromone_weighted( int *solution, double score, int weight )
/*    
      FUNCTION:      reinforces edges of the ant's tour with weight "weight"
      INPUT:         index k of the ant that updates pheromones and its weight  
      OUTPUT:        none
      (SIDE)EFFECTS: pheromones of arcs in the ant's tour are increased
*/
{  
    int      i, j;
    double   d_tau;

    d_tau = (double) weight / score;

    for ( i = 0 ; i < n ; i++ ) {
        j = solution[i];
        pheromone[i * 2 + j] += d_tau;
    }       
}


/****************************************************************
 ****************************************************************
Procedures implementing solution construction and related things
 ****************************************************************
 ****************************************************************/


void select_gate( int k, int gate )
/*    
      FUNCTION:      chooses for an ant the next gate as the one with
                     maximal value of heuristic information times pheromone 
      INPUT:         index k of the ant and the construction step
      OUTPUT:        none 
      (SIDE)EFFECT:  ant moves to the next gate
*/
{ 
    double prob, prob0, prob1;
    prob  = pheromone[gate * 2 /*+ 0*/] + pheromone[gate * 2 + 1];
    prob0 = pheromone[gate * 2 /*+ 0*/] / prob;
    prob1 = pheromone[gate * 2   + 1  ] / prob;

    if ( (q_0 > 0.0) && (ran01( &seed ) < q_0)  ) {
        /* with a probability q_0 make the best possible choice
         according to pheromone trails and heuristic information */
        /* we first check whether q_0 > 0.0, to avoid the very common case
         of q_0 = 0.0 to have to compute a random number, which is
         expensive computationally */
        if (prob1 < prob0 ) {
            ant_solutions[k * n + gate] = 0;
        }
        else {
            ant_solutions[k * n + gate] = 1;
        }
        return;
    }
    else {
        if (ran01(&seed) < prob0 ) {
            ant_solutions[k * n + gate] = 0;
        }
        else {
            ant_solutions[k * n + gate] = 1;
        }
    }
    
 }


/**************************************************************************
 **************************************************************************
Procedures specific to the ant's tour manipulation other than construction
***************************************************************************
 **************************************************************************/



void copy_from_to(int *solution1, double score1, int *solution2, double *score2) 
{
/*    
      FUNCTION:       copy solution from ant a1 [j] and a2 [k]
      INPUT:          indices of the two ants a1 [j] and a2 [k]
      OUTPUT:         none
      (SIDE)EFFECTS:  a2 is copy of a1
*/
    int   i;

    *score2 = score1; //copying first position

    for ( i = 0 ; i < n ; i++ ) { // we can start at index 1 as first position is copied right before
        solution2[i] = solution1[i]; 
    }
}




