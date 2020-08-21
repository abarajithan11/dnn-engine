/*//////////////////////////////////////////////////////////////////////////////////
Group : ABruTECH
Engineer: Abarajithan G.

Create Date: 26/07/2020
Design Name: AXIS Convolution Engine
Tool Versions: Vivado 2018.2
Description: * Output is not AXIS yet
             * Multiple cores

             * Find condition for output shift registers to work safely

Dependencies: 

Revision:
Revision 0.01 - File Created
Additional Comments: 

//////////////////////////////////////////////////////////////////////////////////*/

/*
    MODULE HIERARCHY

    - AXIS_CONV_ENGINE
        - AXIS_reg_slice - Not yet implemented
        - CONV_ENGINE
            - pixels_shift_buffer
            - Sync pixels-weights
            - pixels_buffer   x 8
                (step_buffer) 
                - reg         x 1
                - reg         x   (A-2) + 1
                - reg         x 2*(A-2) + 1
            - CONV_CORE       x 32
                - CONV_UNIT   x 8
                    - mul     x 3
                    - acc     x 3
                    - mux     x 3
                    - reg     x 3
                - weights_buffer
                    (step_buffer)
                    - reg     x 1
                    - reg     x   (A-1) + 1
                    - reg     x 2*(A-1) + 1

    - AXIS_Output_Pipe  - Not yet implemented
        - Core converter
        - Engine converter
*/

module axis_conv_engine # (
    parameter IS_FIXED_POINT            =  0 , 
    parameter CONV_CORES                = 24 ,
    parameter CONV_UNITS                =  8 ,
    parameter DATA_WIDTH                = 16 ,
    parameter KERNEL_W_MAX              =  3 ,
    parameter KERNEL_H_MAX              =  3 , // odd number
    parameter TUSER_WIDTH               =  4 ,
    parameter CIN_COUNTER_WIDTH         = 10 ,
    parameter COLS_COUNTER_WIDTH        = 10 ,
    parameter FLOAT_ACCUMULATOR_DELAY   = 19 ,
    parameter FLOAT_MULTIPLIER_DELAY    =  6 ,
    parameter FIXED_ACCUMULATOR_DELAY   =  4 ,
    parameter FIXED_MULTIPLIER_DELAY    =  3 ,

    parameter INDEX_IS_1x1              =  0 ,
    parameter INDEX_IS_MAX              =  1 ,
    parameter INDEX_IS_RELU             =  2 ,
    parameter INDEX_IS_COLS_1_K2        =  3  
)(
    aclk            ,
    aclken          ,
    aresetn         ,

    start           ,
    kernel_w_1      ,
    kernel_h_1      ,
    is_max          ,
    is_relu         ,
    cols_1          ,
    cin_1           ,

    s_pixels_valid  ,       
    s_pixels_data   ,   
    s_pixels_ready  ,

    s_weights_valid ,       
    s_weights_data  ,
    s_weights_ready ,

    m_valid         ,
    m_data          ,
    m_last          ,
    m_user          
);
    genvar k,i;
    localparam KERNEL_W_WIDTH       = $clog2(KERNEL_W_MAX   + 1);
    localparam KERNEL_H_WIDTH       = $clog2(KERNEL_H_MAX   + 1);
    localparam ACCUMULATOR_DELAY    = IS_FIXED_POINT ? FIXED_ACCUMULATOR_DELAY : FLOAT_ACCUMULATOR_DELAY ; 

    input  wire                          aclk                                                       ;
    input  wire                          aclken                                                     ;               
    input  wire                          aresetn                                                    ;
                                                                                                                                                
    input  wire                          start                                                      ;
    input  wire [KERNEL_W_WIDTH    -1:0] kernel_w_1                                                 ;
    input  wire [KERNEL_H_WIDTH    -1:0] kernel_h_1                                                 ;
    input  wire                          is_max                                                     ;
    input  wire                          is_relu                                                    ;
    input  wire [COLS_COUNTER_WIDTH-1:0] cols_1                                                     ;
    input  wire [CIN_COUNTER_WIDTH -1:0] cin_1                                                      ;
                                                                                                    
    input  wire                          s_pixels_valid                                             ;
    input  wire [DATA_WIDTH        -1:0] s_pixels_data  [CONV_UNITS + (KERNEL_H_MAX-1)    - 1 : 0]  ;
    output wire                          s_pixels_ready                                             ;
                                                                                                        
    input  wire                          s_weights_valid                                            ;
    output wire                          s_weights_ready                                            ;
    input  wire [DATA_WIDTH        -1:0] s_weights_data [CONV_CORES - 1 : 0][KERNEL_W_MAX - 1 : 0]  ;
                                                                                                    
    output wire                          m_valid                                                    ;
    output wire [DATA_WIDTH        -1:0] m_data         [CONV_CORES - 1 : 0][CONV_UNITS   - 1 : 0]  ;
    output wire                          m_last                                                     ;
    output wire [TUSER_WIDTH       -1:0] m_user                                                     ;
                                                                                                    


    /*
        SHIFT PIXELS BUFFER
    */
    
    
    wire    [DATA_WIDTH -1 : 0]   m_shift_pixels_data   [CONV_UNITS-1 : 0];
    wire                          m_shift_pixels_valid                    ;
    wire                          m_shift_pixels_ready                    ;
    wire                          m_shift_pixels_last                     ;
    wire    [TUSER_WIDTH-1 : 0]   m_shift_pixels_user                     ;

    axis_shift_buffer #(
        .IS_FIXED_POINT     (IS_FIXED_POINT    ) ,
        .DATA_WIDTH         (DATA_WIDTH),
        .CONV_UNITS         (CONV_UNITS),
        .KERNEL_H_MAX       (KERNEL_H_MAX),
        .KERNEL_W_MAX       (KERNEL_W_MAX),
        .CIN_COUNTER_WIDTH  (CIN_COUNTER_WIDTH ),
        .COLS_COUNTER_WIDTH (COLS_COUNTER_WIDTH),
        .TUSER_WIDTH        (TUSER_WIDTH       ),
        .INDEX_IS_1x1       (INDEX_IS_1x1      ),
        .INDEX_IS_MAX       (INDEX_IS_MAX      ),
        .INDEX_IS_RELU      (INDEX_IS_RELU     ),
        .INDEX_IS_COLS_1_K2 (INDEX_IS_COLS_1_K2)
    )
    SHIFT_BUFFER
    (
        .aclk               (aclk                 ),
        .aresetn            (aresetn              ),
        .start              (start                ),
        .kernel_h_1_in      (kernel_w_1           ),
        .kernel_w_1_in      (kernel_h_1           ),
        .is_max             (is_max               ),
        .is_relu            (is_relu              ),
        .cols_1             (cols_1               ),
        .cin_1              (cin_1                ),

        .S_AXIS_tdata       (s_pixels_data        ),
        .S_AXIS_tvalid      (s_pixels_valid       ),
        .S_AXIS_tready      (s_pixels_ready       ),

        .M_AXIS_tdata       (m_shift_pixels_data   ),
        .M_AXIS_tvalid      (m_shift_pixels_valid  ),
        .M_AXIS_tready      (m_shift_pixels_ready  ),
        .M_AXIS_tlast       (m_shift_pixels_last   ),
        .M_AXIS_tuser       (m_shift_pixels_user   )
    );

    /*
        SYNC WEIGHTS and PIXELS
    */

    wire conv_s_valid;

    assign conv_s_valid             = s_weights_valid   & m_shift_pixels_valid;
    assign s_weights_ready          = conv_s_ready [0]  & m_shift_pixels_valid;
    assign m_shift_pixels_ready     = conv_s_ready [0]  & s_weights_valid;

    wire   is_1x1                   = m_shift_pixels_user[INDEX_IS_1x1];

    /*
        STEP BUFFER FOR PIXELS

        - Pixel data of each row is stepped KW_MAX times
        - Pixel valid, last, user is stepped once and given to all CONV_UNITS
    */

    wire                      m_step_pixels_valid                       [KERNEL_W_MAX - 1 : 0];
    wire [DATA_WIDTH  - 1: 0] m_step_pixels_data    [CONV_UNITS - 1 : 0][KERNEL_W_MAX - 1 : 0];
    wire                      m_step_pixels_last                        [KERNEL_W_MAX - 1 : 0];
    wire [TUSER_WIDTH - 1: 0] m_step_pixels_user                        [KERNEL_W_MAX - 1 : 0];


    generate
        for (k=0 ; k < CONV_UNITS;   k = k + 1) begin: step_pixels_gen

            wire [DATA_WIDTH  - 1: 0] s_step_pixels_repeated_data    [KERNEL_W_MAX - 1 : 0];

            for (i=0 ; i < KERNEL_W_MAX; i = i + 1) begin: repeat_pixels_gen
                assign s_step_pixels_repeated_data [i] = m_shift_pixels_data[k];
            end

            step_buffer  #(
                .DATA_WIDTH       (DATA_WIDTH),
                .STEPS            (KERNEL_W_MAX),
                .ACCUMULATOR_DELAY(ACCUMULATOR_DELAY),
                .TUSER_WIDTH      (TUSER_WIDTH)
            )
            step_buffer_pixels_data
            (
                .aclk       (aclk),
                .aclken     (conv_s_ready [0]),
                .aresetn    (aresetn),
                .is_1x1     (is_1x1),
                
                .s_data     (s_step_pixels_repeated_data           ),
                .m_data     (m_step_pixels_data               [k]  )
            );

        end
    endgenerate

    wire [TUSER_WIDTH - 1: 0] s_step_pixels_repeated_user    [KERNEL_W_MAX - 1 : 0];

    generate
    for (i=0 ; i < KERNEL_W_MAX; i = i + 1) begin: repeat_user_gen
        assign s_step_pixels_repeated_user [i] = m_shift_pixels_user;
    end
    endgenerate

    step_buffer  #(
        .DATA_WIDTH       (DATA_WIDTH),
        .STEPS            (KERNEL_W_MAX),
        .ACCUMULATOR_DELAY(ACCUMULATOR_DELAY),
        .TUSER_WIDTH      (TUSER_WIDTH)
    )
    step_buffer_pixels_other
    (
        .aclk       (aclk),
        .aclken     (conv_s_ready [0]),
        .aresetn    (aresetn),
        .is_1x1     (is_1x1),
        
        .s_last     ('{KERNEL_W_MAX{m_shift_pixels_last}}  ),
        .s_user     (s_step_pixels_repeated_user           ),

        .m_valid    (m_step_pixels_valid                   ),
        .m_last     (m_step_pixels_last                    ),
        .m_user     (m_step_pixels_user                    )
    );

    /*
        CONVOLUTION CORES

        - Each core computes an output channel
        - Pixels step buffer is kept  common to all cores, in engine (here, above)
        - Weights step buffer is placed inside each core, for weights of that output channel
        - Pixels and weights are not in sync at this point. They get into sync after weights buffer
    
    */


    wire                   conv_s_ready [CONV_CORES-1 : 0];
    wire                   conv_m_valid [CONV_CORES-1 : 0];
    wire                   conv_m_last  [CONV_CORES-1 : 0];
    wire [TUSER_WIDTH-1:0] conv_m_user  [CONV_CORES-1 : 0];

    assign m_valid  = conv_m_valid[0];
    assign m_last   = conv_m_last [0];
    assign m_user   = conv_m_user [0];

    generate
    for (i=0; i < CONV_CORES; i++) begin: cores_gen
        
        conv_core # (
            .IS_FIXED_POINT         (IS_FIXED_POINT         ),
            .CONV_UNITS             (CONV_UNITS             ),
            .DATA_WIDTH             (DATA_WIDTH             ),
            .KERNEL_W_MAX           (KERNEL_W_MAX           ),
            .TUSER_WIDTH            (TUSER_WIDTH            ),
            .FLOAT_ACCUMULATOR_DELAY(FLOAT_ACCUMULATOR_DELAY),
            .FLOAT_MULTIPLIER_DELAY (FLOAT_MULTIPLIER_DELAY ),
            .FIXED_ACCUMULATOR_DELAY(FIXED_ACCUMULATOR_DELAY),
            .FIXED_MULTIPLIER_DELAY (FIXED_MULTIPLIER_DELAY ),
            .INDEX_IS_1x1           (INDEX_IS_1x1           ),
            .INDEX_IS_MAX           (INDEX_IS_MAX           ),
            .INDEX_IS_RELU          (INDEX_IS_RELU          ),
            .INDEX_IS_COLS_1_K2     (INDEX_IS_COLS_1_K2     ) 
        )
        CONV_CORE
        (
            .aclk                (aclk                      ),
            .aclken              (aclken                    ),
            .aresetn             (aresetn                   ),
            .start               (start                     ),
            .kernel_w_1          (kernel_w_1                ),
            .is_1x1              (is_1x1                    ),
            .s_ready             (conv_s_ready          [i] ),
            .s_weights_valid     (conv_s_valid              ),
            .s_weights_data      (s_weights_data        [i] ),
            .s_step_pixels_data  (m_step_pixels_data        ), 
            .s_step_pixels_last  (m_step_pixels_last        ), 
            .s_step_pixels_user  (m_step_pixels_user        ),     
            .m_valid             (conv_m_valid          [i] ),
            .m_data              (m_data                [i] ),
            .m_last              (conv_m_last           [i] ),
            .m_user              (conv_m_user           [i] )
        );
       
    end
    endgenerate

endmodule