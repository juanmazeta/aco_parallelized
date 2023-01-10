/* 
   Programación de GPUs (General Purpose Computation on Graphics Processing 
   Unit)

   Margarita Amor López
   Emilio J. Padrón González

   sumavectores.c

   Suma dos vectores en CPU y GPU
   Parámetros opcionales (en este orden): sumavectores #rep #n #blk
   #rep: número de repetiones
   #n: número de elementos en cada vector
   #blk: hilos por bloque CUDA
*/

#include <cuda_runtime.h>
#include <stdio.h>
#include <stdlib.h>


const int N = 1048576;    // Número predeterm. de elementos en los vectores

const int CUDA_BLK = 1024;  // Tamaño predeterm. de bloque de hilos ƒCUDA


/* 
   Para medir el tiempo transcurrido (elapsed time):

   resnfo: tipo de dato definido para abstraer la métrica de recursos a usar
   timenfo: tipo de dato definido para abstraer la métrica de tiempo a usar

   timestamp: abstrae función usada para tomar las muestras del tiempo transcurrido

   printtime: abstrae función usada para imprimir el tiempo transcurrido

   void myElapsedtime(resnfo start, resnfo end, timenfo *t): función para obtener 
   el tiempo transcurrido entre dos medidas
*/

#include <sys/time.h>
#include <sys/resource.h>

#ifdef _noWALL_
typedef struct rusage resnfo;
typedef struct _timenfo {
  double time;
  double systime;
} timenfo;
#define timestamp(sample) getrusage(RUSAGE_SELF, (sample))
#define printtime(t) printf("%15f s (%f user + %f sys) ",		\
			    t.time + t.systime, t.time, t.systime);
#else
typedef struct timeval resnfo;
typedef double timenfo;
#define timestamp(sample)     gettimeofday((sample), 0)
#define printtime(t) printf("%15f s ", t);
#endif

void myElapsedtime(const resnfo start, const resnfo end, timenfo *const t)
{
#ifdef _noWALL_
  t->time = (end.ru_utime.tv_sec + (end.ru_utime.tv_usec * 1E-6)) 
    - (start.ru_utime.tv_sec + (start.ru_utime.tv_usec * 1E-6));
  t->systime = (end.ru_stime.tv_sec + (end.ru_stime.tv_usec * 1E-6)) 
    - (start.ru_stime.tv_sec + (start.ru_stime.tv_usec * 1E-6));
#else
  *t = (end.tv_sec + (end.tv_usec * 1E-6)) 
    - (start.tv_sec + (start.tv_usec * 1E-6));
#endif /*_noWALL_*/
}


/*
  Función para inicializar los vectores que vamos a utilizar
*/
void populating_arrays(float arrayA[], float arrayB[], 
		       float arrayR[], const unsigned int n)
{
  unsigned int i;

  for(i = 0; i < n; i++) {
    arrayA[i] = i;
    arrayB[i] = n-i;
    arrayR[i] = 0;
  }
}


/*
  Función que devuelve la suma de todos los elementos de un vector, 
  y que usaremos para comprobar el resultado. 
  De paso inicializa el array.
*/
float checkini_array(float array[], const unsigned int n)
{
  unsigned int i;
  float res = 0;

  for(i = 0; i < n; i++) {
    res += array[i];
    array[i] = 0;
  }

  return(res);
}


/*
  Función para sumar dos vectores en la CPU *r* veces
*/
void add_arrays_CPU(const float arrayA[], const float arrayB[], 
		    float arrayR[], const unsigned int n)
{
  unsigned int i;


    for(i = 0; i < n; i++) {
      arrayR[i] += arrayA[i] + arrayB[i];
    }
  
}


// Declación de kernel, definición más abajo
__global__ void add_arrays_kernel_cuda(const float *const mA, 
				       const float *const mB, 
				       float *const mR, const int n);


/*
  Función para sumar dos vectores en la GPU *r* veces
*/
void add_arrays_GPU(const float arrayA[], const float arrayB[], 
		    float arrayR[], const unsigned int n, const unsigned int blk_size, 
		    resnfo *const start, resnfo *const end)
{

  // Número de bytes de cada uno de nuestros vectores
  unsigned int numBytes = n * sizeof(float);

  // Reservamos memoria global del device (GPU) para nuestros 
  // arrays y los copiamos
  float *cA;
  cudaMalloc((void **) &cA, numBytes);
  cudaMemcpy(cA, arrayA, numBytes, cudaMemcpyHostToDevice); // CPU -> GPU

  float *cB;
  cudaMalloc((void **) &cB, numBytes);
  cudaMemcpy(cB, arrayB, numBytes, cudaMemcpyHostToDevice); // CPU -> GPU

  float *cR;
  cudaMalloc((void **) &cR, numBytes);
  cudaMemset(cR, 0, numBytes); // Inicializamos (a 0) array para el resultado

  // Bloque unidimensional de hilos (*blk_size* hilos)
  dim3 dimBlock(blk_size);

  // Rejilla unidimensional (*ceil(n/blk_size)* bloques)
  dim3 dimGrid((n + dimBlock.x - 1) / dimBlock.x);

  // Lanzamos ejecución del kernel en la GPU *r* veces
  timestamp(start);            // Medimos tiempo de cálculo en GPU
     add_arrays_kernel_cuda<<<dimGrid, dimBlock>>>(cA, cB, cR, n);
  
 
  timestamp(end);

  cudaMemcpy(arrayR, cR, numBytes, cudaMemcpyDeviceToHost); // GPU -> CPU

  cudaFree (cA);
  cudaFree (cB);
  cudaFree (cR);
}


// Declaración de función para ver recursos del device
void devicenfo(void);


// Declaración de función para comprobar y ajustar los parámetros de
// ejecución del kernel a las restricciones de la GPU
void checkparams(unsigned int *n, unsigned int *cb);


/*
  Función principal
*/
int main(int argc, char *argv[])
{
  // Para medir tiempos
  resnfo start, end, startgpu, endgpu;
  timenfo time, timegpu;

  // Aceptamos algunos parámetros

  // Número de elementos en los vectores (predeterminado: N)
  unsigned int n = (argc > 1)?atoi (argv[1]):N;

  if (n == 0) {
    devicenfo();
    return(0);
  }

   // Número de hilos en cada bloque CUDA (predeterminado: CUDA_BLK)
  unsigned int cb = (argc > 2)?atoi (argv[2]):CUDA_BLK;

  checkparams(&n, &cb);

  // Número de bytes a reservar para nuestros vectores
  unsigned int numBytes = n * sizeof(float);

  // Reservamos e inicializamos vectores
  timestamp(&start);
  float *vectorA = (float *) malloc(numBytes);
  float *vectorB = (float *) malloc(numBytes);
  float *vectorR = (float *) malloc(numBytes);
  populating_arrays(vectorA, vectorB, vectorR, n);
  timestamp(&end);

  myElapsedtime(start, end, &time);
  printtime(time);
  printf(" -> Reservar e inicializar vectores (%u)\n\n", n);


  // Sumamos vectores en CPU
  timestamp(&start);
  add_arrays_CPU(vectorA, vectorB, vectorR, n);
  timestamp(&end);

  myElapsedtime(start, end, &time);
  printtime(time);
  printf(" -> Sumar vectores en CPU \n\n");

  // Sumamos elementos de vector resultante, para comprobar cálculo en GPU
  float result = checkini_array(vectorR, n);


  // Sumamos vectores en GPU
  timestamp(&start);
  add_arrays_GPU(vectorA, vectorB, vectorR, n, cb, &startgpu, &endgpu);
  timestamp(&end);

  // Sumamos elementos de vector resultante, para comprobar cálculo en GPU
  float result_gpu = checkini_array(vectorR, n);

  myElapsedtime(start, end, &time);
  printtime(time);
  printf(" -> Sumar vectores en GPU (%d hilos, %d hilos/bloq)\n", n, cb);
  if (result_gpu == result) // Comprobamos si resultado numérico es OK
    printf("\t\t      Resultado de la suma OK\n\n");
  else
    printf("\t\t      mec!\n\n");

  // Separamos tiempo de cálculo en GPU de tiempo de transferencia
  myElapsedtime(startgpu, endgpu, &timegpu);
  printf("\t\tDesglose:\n\t\t");	
  printtime(timegpu);
  printf("tiempo cálculo en GPU\n\t\t%15f s alloc y comm\n", time - timegpu);

  free(vectorA);
  free(vectorB);
  free(vectorR);

  return(0);
}


/*
  Definición de nuestro kernel para sumar dos vectores en CUDA
*/
__global__ void add_arrays_kernel_cuda(const float *const mA, 
				       const float *const mB, 
				       float *const mR, const int n)
{
  int global_id = blockIdx.x * blockDim.x + threadIdx.x;

   if (global_id < n)
    mR[global_id] += mA[global_id] + mB[global_id];
}


/*
  Sacar por pantalla información del *device*
*/
void devicenfo(void)
{
  struct cudaDeviceProp capabilities;

  cudaGetDeviceProperties (&capabilities, 0);

  printf("->CUDA Platform & Capabilities\n");
  printf("Name: %s\n", capabilities.name);
  printf("totalGlobalMem: %.2f MB\n", capabilities.totalGlobalMem/1024.0f/1024.0f);
  printf("sharedMemPerBlock: %.2f KB\n", capabilities.sharedMemPerBlock/1024.0f);
  printf("regsPerBlock (32 bits): %d\n", capabilities.regsPerBlock);
  printf("warpSize: %d\n", capabilities.warpSize);
  printf("memPitch: %.2f KB\n", capabilities.memPitch/1024.0f);
  printf("maxThreadsPerBlock: %d\n", capabilities.maxThreadsPerBlock);
  printf("maxThreadsDim: %d x %d x %d\n", capabilities.maxThreadsDim[0], 
	 capabilities.maxThreadsDim[1], capabilities.maxThreadsDim[2]);
  printf("maxGridSize: %d x %d\n", capabilities.maxGridSize[0], 
	 capabilities.maxGridSize[1]);
  printf("totalConstMem: %.2f KB\n", capabilities.totalConstMem/1024.0f);
  printf("major.minor: %d.%d\n", capabilities.major, capabilities.minor);
  printf("clockRate: %.2f MHz\n", capabilities.clockRate/1024.0f);
  printf("deviceOverlap: %d\n", capabilities.deviceOverlap);
  printf("multiProcessorCount: %d\n", capabilities.multiProcessorCount);
}


/*
  Función que ajusta el número de hilos, de bloques, y de bloques por hilo 
  de acuerdo a las restricciones de la GPU
*/
void checkparams(unsigned int *n, unsigned int *cb)
{
  struct cudaDeviceProp capabilities;

  // Si menos numero total de hilos que tamaño bloque, reducimos bloque
  if (*cb > *n)
    *cb = *n;

  cudaGetDeviceProperties (&capabilities, 0);

  if (*cb > capabilities.maxThreadsDim[0]) {
    *cb = capabilities.maxThreadsDim[0];
    printf("->Núm. hilos/bloq cambiado a %d (máx por bloque para dev)\n\n", 
	   *cb);
  }

  if (((*n + *cb - 1) / *cb) > capabilities.maxGridSize[0]) {
    *cb = 2 * (*n - 1) / (capabilities.maxGridSize[0] - 1);
    if (*cb > capabilities.maxThreadsDim[0]) {
      *cb = capabilities.maxThreadsDim[0];
      printf("->Núm. hilos/bloq cambiado a %d (máx por bloque para dev)\n", 
	     *cb);
      if (*n > (capabilities.maxGridSize[0] * *cb)) {
	*n = capabilities.maxGridSize[0] * *cb;
	printf("->Núm. total de hilos cambiado a %d (máx por grid para \
dev)\n\n", *n);
      } else {
	printf("\n");
      }
    } else {
      printf("->Núm. hilos/bloq cambiado a %d (%d máx. bloq/grid para \
dev)\n\n", 
	     *cb, capabilities.maxGridSize[0]);
    }
  }
}
