set PROJ_FOLDER projects/$PROJ_NAME
set HDL_DIR src_hdl
set TB_DIR testbench
set WAVE_DIR wave

set UNITS   4
set GROUPS  2
set COPIES  2
set MEMBERS 12
set DW_FACTOR_1 3 

set WORD_WIDTH       8
set WORD_WIDTH_ACC   32
set S_WEIGHTS_WIDTH_HF  32

set BEATS_CONFIG_1X1 5 
set BEATS_CONFIG_3X3 9 

set KERNEL_W_MAX  3
set KERNEL_H_MAX  3
set IM_COLS_MAX   384
set IM_ROWS_MAX   256
set IM_CIN_MAX    1024
set LRELU_ALPHA   11878

set LATENCY_MULTIPLIER    3
set LATENCY_ACCUMULATOR   2
set LATENCY_FMA_1         16
set LATENCY_FMA_2         15
set LATENCY_FIXED_2_FLOAT  6
set LATENCY_BRAM           3
set LATENCY_CYCLIC_REG     0
set LATENCY_FLOAT_UPSIZE   2
set LATENCY_FLOAT_DOWNSIZE 3

set BITS_EXP_CONFIG 5
set BITS_FRA_CONFIG 10
set BITS_EXP_FMA_1  8
set BITS_FRA_FMA_1  23
set BITS_EXP_FMA_2  5 
set BITS_FRA_FMA_2  10

set IS_CONV_DW_SLICE 0
set FREQ_LITE        20
set FREQ_LOW         25
set FREQ_HIGH        50
set LRELU_BEATS_MAX    9

set IM_BLOCKS_MAX      [expr int($IM_ROWS_MAX / $UNITS)]
set UNITS_EDGES        [expr $UNITS + $KERNEL_H_MAX-1]
set CORES              [expr $GROUPS * $COPIES]
set BITS_KERNEL_W      [expr int(ceil(log($KERNEL_W_MAX)/log(2)))]
set BITS_KERNEL_H      [expr int(ceil(log($KERNEL_H_MAX)/log(2)))]
set BITS_IM_COLS       [expr int(ceil(log($IM_COLS_MAX)/log(2)))]
set BITS_IM_ROWS       [expr int(ceil(log($IM_ROWS_MAX)/log(2)))]
set BITS_IM_CIN        [expr int(ceil(log($IM_CIN_MAX)/log(2)))]
set BITS_IM_BLOCKS     [expr int(ceil(log($IM_ROWS_MAX/$UNITS)/log(2)))]
set BITS_MEMBERS       [expr int(ceil(log($MEMBERS)/log(2)))]
set BITS_KW2           [expr int(ceil(log($KERNEL_W_MAX/2+1)/log(2)))]

set S_WEIGHTS_WIDTH_LF [expr int($S_WEIGHTS_WIDTH_HF * $FREQ_HIGH / $FREQ_LOW)]
set M_DATA_WIDTH_HF    [expr $WORD_WIDTH * 2**int(ceil(log($GROUPS * $UNITS_EDGES)/log(2)))]
set M_DATA_WIDTH_LF    [expr int($M_DATA_WIDTH_HF * $FREQ_HIGH / $FREQ_LOW)]

set IM_IN_S_DATA_WORDS   [expr 2**int(ceil(log($UNITS_EDGES)/log(2))) * $FREQ_HIGH / $FREQ_LOW]
set WORD_WIDTH_LRELU_1   [expr 1 + $BITS_EXP_FMA_1 + $BITS_FRA_FMA_1]
set WORD_WIDTH_LRELU_2   [expr 1 + $BITS_EXP_FMA_2 + $BITS_FRA_FMA_2]
set WORD_WIDTH_LRELU_OUT $WORD_WIDTH
set TKEEP_WIDTH_IM_IN    [expr $WORD_WIDTH * $IM_IN_S_DATA_WORDS /8]

set BITS_FMA_1 [expr $BITS_FRA_FMA_1 + $BITS_EXP_FMA_1 + 1]
set BITS_FMA_2 [expr $BITS_FRA_FMA_2 + $BITS_EXP_FMA_2 + 1]

# IMAGE TUSER INDICES
set I_IS_NOT_MAX       0
set I_IS_MAX           [expr $I_IS_NOT_MAX + 1]
set I_IS_LRELU         [expr $I_IS_MAX     + 1]
set I_KERNEL_H_1             [expr $I_IS_LRELU   + 1] 
set TUSER_WIDTH_IM_SHIFT_IN  [expr $I_KERNEL_H_1       + $BITS_KERNEL_H]
set TUSER_WIDTH_IM_SHIFT_OUT [expr $I_KERNEL_H_1       + $BITS_KERNEL_H]

# WEIGHTS TUSER INDICES
set I_WEIGHTS_IS_TOP_BLOCK     0
set I_WEIGHTS_IS_BOTTOM_BLOCK  [expr $I_WEIGHTS_IS_TOP_BLOCK    + 1]
set I_WEIGHTS_IS_COLS_1_K2     [expr $I_WEIGHTS_IS_BOTTOM_BLOCK + 1]
set I_WEIGHTS_IS_CONFIG        [expr $I_WEIGHTS_IS_COLS_1_K2    + 1]
set I_WEIGHTS_IS_CIN_LAST      [expr $I_WEIGHTS_IS_CONFIG       + 1] 
set I_WEIGHTS_KERNEL_W_1       [expr $I_WEIGHTS_IS_CIN_LAST     + 1] 
set TUSER_WIDTH_WEIGHTS_OUT    [expr $I_WEIGHTS_KERNEL_W_1 + $BITS_KERNEL_W]

# PIPE TUSER INDICES
set I_IS_NOT_MAX      0
set I_IS_MAX          [expr $I_IS_NOT_MAX      + 1]
set I_KERNEL_H_1      [expr $I_IS_MAX          + 1]
set I_IS_LRELU        [expr $I_KERNEL_H_1      + $BITS_KERNEL_H]
set I_IS_TOP_BLOCK    [expr $I_IS_LRELU        + 1]
set I_IS_BOTTOM_BLOCK [expr $I_IS_TOP_BLOCK    + 1]
set I_IS_COLS_1_K2    [expr $I_IS_BOTTOM_BLOCK + 1]
set I_IS_CONFIG       [expr $I_IS_COLS_1_K2    + 1]
set I_IS_CIN_LAST     [expr $I_IS_CONFIG       + 1]
set I_KERNEL_W_1      [expr $I_IS_CIN_LAST     + 1]

set I_CLR             [expr $I_IS_BOTTOM_BLOCK + 1]

set TUSER_WIDTH_MAXPOOL_IN     [expr $BITS_KERNEL_H + $I_KERNEL_H_1]
set TUSER_WIDTH_LRELU_IN       [expr $BITS_KERNEL_W + $I_CLR]
set TUSER_WIDTH_LRELU_FMA_1_IN [expr 1 + $I_IS_LRELU    ]
set TUSER_WIDTH_CONV_IN        [expr $BITS_KERNEL_W + $I_KERNEL_W_1]

set DEBUG_CONFIG_WIDTH_W_ROT   [expr 1 + 2*$BITS_KERNEL_W + 3*($BITS_KERNEL_H + $BITS_IM_CIN + $BITS_IM_COLS + $BITS_IM_BLOCKS)]
set DEBUG_CONFIG_WIDTH_IM_PIPE [expr 3 + 2 + $BITS_KERNEL_H + 0]
set DEBUG_CONFIG_WIDTH_LRELU   [expr 3 + 4 + $BITS_FMA_2]
set DEBUG_CONFIG_WIDTH_MAXPOOL 1
set DEBUG_CONFIG_WIDTH         [expr $DEBUG_CONFIG_WIDTH_MAXPOOL + $DEBUG_CONFIG_WIDTH_LRELU + 2*$BITS_KERNEL_H + $DEBUG_CONFIG_WIDTH_IM_PIPE + $DEBUG_CONFIG_WIDTH_W_ROT]



# **********    STORE PARAMS    *************


set file_param [open $HDL_DIR/params.v w]
puts $file_param "/*
Parameters of the system. Written from build.tcl
*/

`define UNITS    $UNITS  
`define GROUPS   $GROUPS 
`define COPIES   $COPIES 
`define MEMBERS  $MEMBERS
`define DW_FACTOR_1 $DW_FACTOR_1

`define FREQ_HIGH     $FREQ_HIGH
`define FREQ_LOW      $FREQ_LOW

`define CORES              $CORES
`define UNITS_EDGES        $UNITS_EDGES
`define IM_IN_S_DATA_WORDS $IM_IN_S_DATA_WORDS

`define WORD_WIDTH          $WORD_WIDTH         
`define WORD_WIDTH_ACC      $WORD_WIDTH_ACC    
`define KERNEL_H_MAX        $KERNEL_H_MAX      
`define KERNEL_W_MAX        $KERNEL_W_MAX      

`define TKEEP_WIDTH_IM_IN $TKEEP_WIDTH_IM_IN
`define BITS_KERNEL_W     $BITS_KERNEL_W    
`define BITS_KERNEL_H     $BITS_KERNEL_H    
`define BITS_IM_COLS      $BITS_IM_COLS     
`define BITS_IM_ROWS      $BITS_IM_ROWS     
`define BITS_IM_CIN       $BITS_IM_CIN      
`define BITS_IM_BLOCKS    $BITS_IM_BLOCKS   
`define BITS_MEMBERS      $BITS_MEMBERS     
`define BITS_KW2          $BITS_KW2         

`define DEBUG_CONFIG_WIDTH_W_ROT   $DEBUG_CONFIG_WIDTH_W_ROT  
`define DEBUG_CONFIG_WIDTH_IM_PIPE $DEBUG_CONFIG_WIDTH_IM_PIPE
`define DEBUG_CONFIG_WIDTH_LRELU   $DEBUG_CONFIG_WIDTH_LRELU  
`define DEBUG_CONFIG_WIDTH_MAXPOOL $DEBUG_CONFIG_WIDTH_MAXPOOL
`define DEBUG_CONFIG_WIDTH         $DEBUG_CONFIG_WIDTH        

/*
  IMAGE TUSER INDICES
*/
`define TUSER_WIDTH_IM_SHIFT_IN   $TUSER_WIDTH_IM_SHIFT_IN 
`define TUSER_WIDTH_IM_SHIFT_OUT  $TUSER_WIDTH_IM_SHIFT_OUT

`define IM_CIN_MAX       $IM_CIN_MAX      
`define IM_BLOCKS_MAX    $IM_BLOCKS_MAX   
`define IM_COLS_MAX      $IM_COLS_MAX     
`define LRELU_ALPHA      $LRELU_ALPHA     
`define LRELU_BEATS_MAX  $LRELU_BEATS_MAX

`define S_WEIGHTS_WIDTH_HF  $S_WEIGHTS_WIDTH_HF
`define S_WEIGHTS_WIDTH_LF  $S_WEIGHTS_WIDTH_LF
`define M_DATA_WIDTH_HF     $M_DATA_WIDTH_HF
`define M_DATA_WIDTH_LF     $M_DATA_WIDTH_LF
/*
  LATENCIES & float widths
*/
`define BITS_EXP_CONFIG       $BITS_EXP_CONFIG      
`define BITS_FRA_CONFIG       $BITS_FRA_CONFIG      
`define BITS_EXP_FMA_1        $BITS_EXP_FMA_1       
`define BITS_FRA_FMA_1        $BITS_FRA_FMA_1       
`define BITS_EXP_FMA_2        $BITS_EXP_FMA_2       
`define BITS_FRA_FMA_2        $BITS_FRA_FMA_2       
`define LATENCY_FMA_1         $LATENCY_FMA_1        
`define LATENCY_FMA_2         $LATENCY_FMA_2        
`define LATENCY_FIXED_2_FLOAT $LATENCY_FIXED_2_FLOAT
`define LATENCY_BRAM          $LATENCY_BRAM         
`define LATENCY_CYCLIC_REG    $LATENCY_CYCLIC_REG         
`define LATENCY_FLOAT_UPSIZE   $LATENCY_FLOAT_UPSIZE   
`define LATENCY_FLOAT_DOWNSIZE $LATENCY_FLOAT_DOWNSIZE   
`define LATENCY_ACCUMULATOR   $LATENCY_ACCUMULATOR    
`define LATENCY_MULTIPLIER    $LATENCY_MULTIPLIER     
/*
  WEIGHTS TUSER INDICES
*/
`define I_WEIGHTS_IS_TOP_BLOCK     $I_WEIGHTS_IS_TOP_BLOCK   
`define I_WEIGHTS_IS_BOTTOM_BLOCK  $I_WEIGHTS_IS_BOTTOM_BLOCK
`define I_WEIGHTS_IS_COLS_1_K2     $I_WEIGHTS_IS_COLS_1_K2   
`define I_WEIGHTS_IS_CONFIG        $I_WEIGHTS_IS_CONFIG      
`define I_WEIGHTS_IS_CIN_LAST      $I_WEIGHTS_IS_CIN_LAST    
`define I_WEIGHTS_KERNEL_W_1       $I_WEIGHTS_KERNEL_W_1      
`define TUSER_WIDTH_WEIGHTS_OUT    $TUSER_WIDTH_WEIGHTS_OUT  
/*
  CONV TUSER INDICES
*/
`define I_IS_NOT_MAX         $I_IS_NOT_MAX       
`define I_IS_MAX             $I_IS_MAX           
`define I_KERNEL_H_1         $I_KERNEL_H_1      
`define I_IS_LRELU           $I_IS_LRELU         
`define I_IS_TOP_BLOCK       $I_IS_TOP_BLOCK     
`define I_IS_BOTTOM_BLOCK    $I_IS_BOTTOM_BLOCK  
`define I_IS_COLS_1_K2       $I_IS_COLS_1_K2     
`define I_IS_CONFIG          $I_IS_CONFIG        
`define I_IS_CIN_LAST        $I_IS_CIN_LAST      
`define I_KERNEL_W_1         $I_KERNEL_W_1        
`define TUSER_WIDTH_CONV_IN  $TUSER_WIDTH_CONV_IN
/*
  LRELU & MAXPOOL TUSER INDICES
*/
`define I_CLR                $I_CLR

`define TUSER_WIDTH_MAXPOOL_IN     $TUSER_WIDTH_MAXPOOL_IN    
`define TUSER_WIDTH_LRELU_FMA_1_IN $TUSER_WIDTH_LRELU_FMA_1_IN
`define TUSER_WIDTH_LRELU_IN       $TUSER_WIDTH_LRELU_IN      
`define IS_CONV_DW_SLICE           $IS_CONV_DW_SLICE

/*
  Macro functions
*/
`define BEATS_CONFIG(KH,KW) 1+ 2*(2/KW + 2%KW) + 2*KH
`define CEIL(N,D) N/D + (N%D != 0)
"
close $file_param