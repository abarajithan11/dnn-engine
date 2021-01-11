module conv_engine (
    clk            ,
    clken          ,
    resetn         ,
    s_valid        ,
    s_ready        ,
    s_last         ,
    s_user         ,
    s_data_pixels_1_flat,
    s_data_pixels_2_flat,
    s_data_weights_flat ,
    m_valid        ,
    m_data_flat    ,
    m_last         ,
    m_user         
  );

  parameter  CORES              = 32 ;
  parameter  UNITS              = 8  ;
  parameter  WORD_WIDTH_IN      =  8 ; 
  parameter  WORD_WIDTH_OUT     = 25 ; 
  parameter  ACCUMULATOR_DELAY  =  2 ;
  parameter  MULTIPLIER_DELAY   =  3 ;
  parameter  KERNEL_W_MAX       =  3 ; 
  parameter  KERNEL_H_MAX       =  3 ;   // odd number
  parameter  IM_CIN_MAX         = 1024;
  parameter  IM_COLS_MAX        = 1024;
  localparam BITS_IM_CIN        = $clog2(IM_CIN_MAX);
  localparam BITS_IM_COLS       = $clog2(IM_COLS_MAX);
  localparam BITS_KERNEL_W      = $clog2(KERNEL_W_MAX   + 1);
  localparam BITS_KERNEL_H      = $clog2(KERNEL_H_MAX   + 1);

  parameter I_IS_NOT_MAX        = 0;
  parameter I_IS_MAX            = I_IS_NOT_MAX      + 1;
  parameter I_IS_LRELU          = I_IS_MAX          + 1;
  parameter I_IS_TOP_BLOCK      = I_IS_LRELU        + 1;
  parameter I_IS_BOTTOM_BLOCK   = I_IS_TOP_BLOCK    + 1;
  parameter I_IS_1X1            = I_IS_BOTTOM_BLOCK + 1;
  parameter I_IS_COLS_1_K2      = I_IS_1X1          + 1;
  parameter I_IS_CONFIG         = I_IS_COLS_1_K2    + 1;
  parameter I_IS_ACC_LAST       = I_IS_CONFIG       + 1;
  parameter I_KERNEL_W_1        = I_IS_ACC_LAST     + 1; 

  parameter I_IS_LEFT_COL       = I_IS_1X1          + 1;
  parameter I_IS_RIGHT_COL      = I_IS_LEFT_COL     + 1;

  parameter TUSER_WIDTH_CONV_IN = BITS_KERNEL_W + I_KERNEL_W_1;
  parameter TUSER_WIDTH_CONV_OUT= 1 + I_IS_RIGHT_COL;

  input  logic clk;
  input  logic clken;
  input  logic resetn;
  input  logic s_valid;
  output logic s_ready;
  input  logic s_last;
  output logic m_valid;
  output logic m_last ;
  input  logic [TUSER_WIDTH_CONV_IN             -1:0] s_user;
  input  logic [WORD_WIDTH_IN*UNITS             -1:0] s_data_pixels_1_flat;
  input  logic [WORD_WIDTH_IN*UNITS             -1:0] s_data_pixels_2_flat;
  input  logic [WORD_WIDTH_IN*CORES*KERNEL_W_MAX-1:0] s_data_weights_flat;                                                                        
  output logic [WORD_WIDTH_OUT*CORES*UNITS      -1:0] m_data_flat;
  output logic [TUSER_WIDTH_CONV_OUT            -1:0] m_user;

  logic [WORD_WIDTH_IN       -1:0] s_data_pixels    [1:0][UNITS-1:0];
  logic [WORD_WIDTH_IN       -1:0] s_data_weights   [1:0][CORES/2-1:0][KERNEL_W_MAX-1:0];                                                                        
  logic [WORD_WIDTH_OUT      -1:0] m_data           [1:0][CORES/2-1:0][UNITS-1:0];

  assign s_data_pixels    [0] = {>>{s_data_pixels_1_flat}};
  assign s_data_pixels    [1] = {>>{s_data_pixels_2_flat}};
  assign s_data_weights       = {>>{s_data_weights_flat }};
  assign {>>{m_data_flat}}    = m_data;


  logic [BITS_KERNEL_W  -1:0] s_user_kernel_w_1;
  assign s_user_kernel_w_1 = s_user [I_KERNEL_W_1 + BITS_KERNEL_W-1 : I_KERNEL_W_1];

  logic m_step_pixels_valid     [KERNEL_W_MAX-1:0];
  logic m_step_pixels_last      [KERNEL_W_MAX-1:0];
  logic [TUSER_WIDTH_CONV_IN-1:0] s_step_pixels_repeated_user [KERNEL_W_MAX-1: 0];
  logic [TUSER_WIDTH_CONV_IN-1:0] m_step_pixels_user          [KERNEL_W_MAX-1: 0];
  logic [WORD_WIDTH_IN-1:0] m_step_weights_data         [1:0][CORES/2-1: 0][KERNEL_W_MAX-1: 0];
  logic [WORD_WIDTH_IN-1:0] m_step_pixels_data          [1:0][UNITS-1: 0][KERNEL_W_MAX-1: 0];
  logic [WORD_WIDTH_IN-1:0] s_step_pixels_repeated_data [1:0][UNITS-1: 0][KERNEL_W_MAX-1: 0];

  logic mux_sel_none ;
  logic clken_mul;
  logic [KERNEL_W_MAX-1: 1] mux_sel  ;
  logic [KERNEL_W_MAX-1: 0] clken_acc;

  logic mul_m_valid [KERNEL_W_MAX-1: 0];
  logic mul_m_last  [KERNEL_W_MAX-1: 0];
  
  logic first_bypass[KERNEL_W_MAX-1: 0];
  logic acc_s_valid [KERNEL_W_MAX-1: 0];
  logic acc_s_last  [KERNEL_W_MAX-1: 0];

  logic acc_m_valid           [KERNEL_W_MAX-1: 0];
  logic acc_m_last            [KERNEL_W_MAX-1: 0];
  logic acc_m_cin_last        [KERNEL_W_MAX-1: 0];
  logic acc_m_cin_last_masked [KERNEL_W_MAX-1: 0];
  logic acc_m_cin_last_masked_delayed  [KERNEL_W_MAX-1: 0];

  logic selected_valid [KERNEL_W_MAX-1: 1]; 
  logic update_switch  [KERNEL_W_MAX-1: 1];
  logic sel_in         [KERNEL_W_MAX-1: 1];

  logic mux_s2_valid [KERNEL_W_MAX-1: 1];
  logic mux_m_valid  [KERNEL_W_MAX-1: 1];

  logic mask_partial [KERNEL_W_MAX-1: 1];
  logic mask_full    [KERNEL_W_MAX-1: 0];

  logic shift_sel    [KERNEL_W_MAX-2: 0];

  logic shift_in_valid  [KERNEL_W_MAX-1: 0];
  logic shift_in_last   [KERNEL_W_MAX-1: 0];
  logic shift_out_valid [KERNEL_W_MAX-1: 0];
  logic shift_out_last  [KERNEL_W_MAX-1: 0];

  logic [TUSER_WIDTH_CONV_IN -1: 0] mul_m_user    [KERNEL_W_MAX-1: 0];
  logic [TUSER_WIDTH_CONV_IN -1: 0] acc_s_user    [KERNEL_W_MAX-1: 0];
  logic [TUSER_WIDTH_CONV_IN -1: 0] mux_s2_user   [KERNEL_W_MAX-1: 1];
  logic [TUSER_WIDTH_CONV_IN -1: 0] acc_m_user    [KERNEL_W_MAX-1: 0];
  logic [TUSER_WIDTH_CONV_OUT-1: 0] shift_in_user [KERNEL_W_MAX-1: 0];
  logic [TUSER_WIDTH_CONV_OUT-1: 0] shift_out_user[KERNEL_W_MAX-1: 0];
  logic pad_is_left_col [KERNEL_W_MAX-1: 0]; 
  logic pad_is_right_col[KERNEL_W_MAX-1: 0];

  logic [WORD_WIDTH_IN*2-1:0] mul_m_data      [1:0][CORES/2-1:0][UNITS-1:0][KERNEL_W_MAX-1: 0];
  logic [WORD_WIDTH_OUT -1:0] acc_s_data      [1:0][CORES/2-1:0][UNITS-1:0][KERNEL_W_MAX-1: 0];
  logic [WORD_WIDTH_OUT -1:0] acc_m_data      [1:0][CORES/2-1:0][UNITS-1:0][KERNEL_W_MAX-1: 0];
  logic [WORD_WIDTH_OUT -1:0] mux_s2_data     [1:0][CORES/2-1:0][UNITS-1:0][KERNEL_W_MAX-1: 1];
  logic [WORD_WIDTH_OUT -1:0] shift_in_data   [1:0][CORES/2-1:0][UNITS-1:0][KERNEL_W_MAX-1: 0];
  logic [WORD_WIDTH_OUT -1:0] shift_out_data  [1:0][CORES/2-1:0][UNITS-1:0][KERNEL_W_MAX-1: 0];

  /*
    CONTROL PATHS
  */

  assign mux_sel_none = !(|mux_sel) ;
  assign clken_mul    = clken &&  mux_sel_none;
  assign s_ready      = clken_mul   ;
  assign clken_acc[0] = clken_mul   ;

  /*
    STEP BUFFER PIXELS CONTROL
  */

  generate
    for (genvar w=0 ; w < KERNEL_W_MAX; w++)
      assign s_step_pixels_repeated_user [w] = s_user;
  endgenerate

  step_buffer  #(
    .WORD_WIDTH       (WORD_WIDTH_IN),
    .STEPS            (KERNEL_W_MAX),
    .ACCUMULATOR_DELAY(ACCUMULATOR_DELAY),
    .TUSER_WIDTH      (TUSER_WIDTH_CONV_IN)
  ) STEP_PIXELS_CONTROL (
    .aclk       (clk                        ),
    .aclken     (s_ready                    ),
    .aresetn    (resetn                     ),
    .is_1x1     (s_user[I_IS_1X1]           ),
    .s_valid    ({>>{{KERNEL_W_MAX{s_valid}}}}    ),
    .s_last     ({>>{{KERNEL_W_MAX{s_last}}}}     ),
    .s_user     (s_step_pixels_repeated_user),
    .m_valid    (m_step_pixels_valid        ),
    .m_last     (m_step_pixels_last         ),
    .m_user     (m_step_pixels_user         )
  );

  /*
    CONTROL CHAINS
  */
  generate
    for (genvar w=0; w < KERNEL_W_MAX; w++) begin: w_gen

      /*
        Multiplier Delay
      */

      n_delay_stream #(
        .N          (MULTIPLIER_DELAY),
        .WORD_WIDTH (WORD_WIDTH_IN   ),
        .TUSER_WIDTH(TUSER_WIDTH_CONV_IN)
      ) MULTIPLIER_DELAY_CONTROL (
        .aclk       (clk),
        .aclken     (clken_mul),
        .aresetn    (resetn),

        .valid_in   (m_step_pixels_valid  [w]),
        .last_in    (m_step_pixels_last   [w]),
        .user_in    (m_step_pixels_user   [w]),

        .valid_out  (mul_m_valid [w]),
        .last_out   (mul_m_last  [w]),
        .user_out   (mul_m_user  [w])
      );

      /* 
        CLKEN ACCUMULATOR

        * For datapath[0], keep accumulator enabled when "mux_sel_none"
        * Other datapaths, allow accumulator only if the sel bit of that datapath rises.
        * This ensures accumulators and multiplers are tied together, hence 
            delays being in sync for ANY cin >= 3. 
      */
      if (w!=0) assign clken_acc[w] = clken && (mux_sel_none || mux_sel[w]);

      assign acc_m_cin_last  [w] = acc_m_user[w][I_IS_ACC_LAST]; // Has to be valid last - ensured at axis_input_pipe

      register #(
        .WORD_WIDTH     (1),
        .RESET_VALUE    (0)
      ) ACCUMULATOR_DELAY_LAST (
        .clock          (clk),
        .resetn         (resetn),
        .clock_enable   (clken_acc    [w]),
        .data_in        (acc_s_last   [w]),
        .data_out       (first_bypass [w])
      );

      n_delay_stream #(
        .N              (ACCUMULATOR_DELAY),
        .WORD_WIDTH     (WORD_WIDTH_IN    ),
        .TUSER_WIDTH    (TUSER_WIDTH_CONV_IN )
      ) ACCUMULATOR_DELAY_CONTROL (
        .aclk       (clk   ),
        .aclken     (clken_acc   [w]),
        .aresetn    (resetn),

        .valid_in   (acc_s_valid [w]),
        .last_in    (acc_s_last  [w]),
        .user_in    (acc_s_user  [w]),

        .valid_out  (acc_m_valid [w]),
        .last_out   (acc_m_last  [w]),
        .user_out   (acc_m_user  [w])
      );

      /*
        Directly connect Mul_0 to Acc_0
      */
      assign acc_s_valid [0] = mul_m_valid [0] && mux_sel_none;
      
      assign acc_s_last  [0] = mul_m_last  [0];
      assign acc_s_user  [0] = mul_m_user  [0];

      /*
        SEL BITS

        * 1x1 : mux_sel   [i] = 0 ; permanently connecting mul to acc
        * nxm : mul_m_last[i] are delayed by one data beat
        * NOTE: sel_register is updated using the true acc_m_valid, not pad_filtered one

        * nxm : Delays inside step_buffer should sync perfectly, such that
          for every datapath[i] (except 0):

            1. last data from multiplier comes to mux_s1[i]
                * Directly goes into acc_s[i]
                * Clearing the accumulator with it
                * mul_m_last[i] that comes with it gets delayed (enters  mux_sel[i])

            2. On next data beat, last data from acc_s[i-1] comes into mux_s2[i]
                * mux_sel[i] is asserted, mux[i] allows mux_s2[i] into acc_s[i]
                * acc_s[i-1] enters acc_s[i], as 1st data of new accumulation
                    its tlast is not allowed passed
                * All multipliers are disabled
                * All accumulators, except [i] are disabled
                * acc_s[i] accepts acc_s[i-1]
                * "bias" has come to the mul_s[i] and waits
                    as multipler pipeline is disabled

            3. On next data_beat, mux_sel[i] is updated (deasserted)
                * BECAUSE selected_valid[i] = acc_m_cin_last  [i-1] was asserted in prev clock
                * mux[i] allows mux_s1[i] into acc_s[i]
                * acc_s[i] accepts bias as 2nd data of new accumulation
                * all multipliers and other accumulators resume operation

            -  If last data from acc_m[i-1] doesn't follow last data of mul_s[i]:
                - mux_sel[i] will NOT be deasserted (updated)
                - multipliers and other accumulators will freeze forever
            - For this sync to happen:
                - datapath[i] should be delayed by DELAY clocks than datapath[i-1]
                - DELAY = (A-1) -1 = (A-2)
                    - When multipliers are frozen, each accumulator works 
                        one extra clock than its corresponding multiplier,
                        in (2), to accept other acc_s value. This means, the
                        relative delay of accumulator is (A-1) 
                        as seen by a multiplier
                    - If (A-1), both mul_s[i] and acc_s[i-1] will give tlast together
                    - (-1) ensures mul_s[i] comes first
      */
      
      if (w !=0 ) begin
        assign selected_valid [w] = (mux_sel[w]==0) ? mul_m_valid [w] : acc_m_cin_last  [w-1];
        assign update_switch  [w] = clken && selected_valid [w];
        assign sel_in         [w] = mul_m_last [w] && (!mul_m_user[w][I_IS_1X1]);
        
        register #(
          .WORD_WIDTH     (1),
          .RESET_VALUE    (0)
        ) MUX_SEL (
          .clock          (clk    ),
          .resetn         (resetn),
          .clock_enable   (update_switch[w]),
          .data_in        (sel_in       [w]),
          .data_out       (mux_sel      [w])
        );

        assign mux_s2_valid [w] = acc_m_cin_last   [w-1] && mask_partial[w];
        assign mux_s2_user  [w] = acc_m_user       [w-1];

        assign acc_s_valid  [w] = mux_m_valid[w] && (mux_sel[w] || mux_sel_none);

        assign mux_m_valid  [w] = mux_sel [w] ? mux_s2_valid [w] : mul_m_valid [w];
        assign acc_s_user   [w] = mux_sel [w] ? mux_s2_user  [w] : mul_m_user  [w];
        assign acc_s_last   [w] = mux_sel [w] ? 0                : mul_m_last  [w];
      end

      /*
      SHIFT REGISTERS

      * KW_MAX number of shift registers are chained. 
      * Values are shifted from shift_reg[KW_MAX-1] -> ... -> shift_reg[1] -> shift_reg[0]
      * Conv_unit output is given by shift_reg[0]

      * Muxing
          - Input of shift registers are the muxed result of acc_m[i] and shift_out[i+1]
          - Priority is given to shifting. 
              - If shift_out[i+1] is high, input is taken from there.
              - Else, input is taken from acc_m[i]
          - Because, if two acc_m[1] and acc_m[2] are released together, as in A=2 (default fixed point), 
              acc_m[1] stays for two clocks until it's value goes into acc_m[2]
          - So, the clock sequence goes as follows:
              - acc_m[0] == 0 ; shift[0] == 0        ; acc_m[1] == 1 ; shift[1] == 0         ; acc_m[2] == 1  ; shift[2] == 0
              - acc_m[0] == 0 ; shift[0] == 0        ; acc_m[1] == 1 ; shift[1] == acc_m[1]  ; acc_m[2] == 0  ; shift[2] == acc_m[2]
              - acc_m[0] == 0 ; shift[0] == acc_m[1] ; acc_m[1] == 0 ; shift[1] == acc_m[2]  ; acc_m[2] == 0  ; shift[2] == 0

      * Shift enable = aclk = m_ready of the AXIS outside.
          - whenever m_ready goes down, whole unit freezes, including shift regs.
          - if we use acc_clken or something else:
              when m_ready stays high, shift_clken might go low.
              this would result in valid staying high and data unchanged
              for multiple clocks as m_ready stays high. Downstream module
              will count it as multiple transactions as per AXIS protocol.

      n x m:

      * Middle cols:  - Only one datapath gives output, spaced ~CIN*KW delay apart.
                      - For any delay, outputs will come out one after the other, all is well
      * End cols   :  - (KW/2 + 1) datapaths give data out, spaced (A-2) delays apart
                      - But they come out in reversed order
      * Start cols :  - KW/2 cols are ignored
                      - So there is time for end_cols to come out

      1 x 1:

      * All datapaths give outputs
      * Order is messed up if CIN > i(A-1)-2
          - Can be solved by bypassing the (A-1) delay
          - But then back-to-back kernel change is not possible
      */

      assign  acc_m_cin_last_masked  [w] = acc_m_cin_last  [w] & mask_full[w] & !acc_m_cin_last_masked_delayed[w];

      register #(
        .WORD_WIDTH     (1),
        .RESET_VALUE    (0)
      ) ACCUMULATOR_CIN_LAST_DELAYED (
        .clock          (clk    ),
        .clock_enable   (clken  ),
        .resetn         (resetn ),
        .data_in        (acc_m_cin_last_masked        [w] ),
        .data_out       (acc_m_cin_last_masked_delayed[w])
      );

      if (w != KERNEL_W_MAX-1) begin
        assign shift_sel      [w] = shift_out_valid  [w+1]; //-------GET THIS OUT

        assign shift_in_valid [w] = shift_sel  [w] ? shift_out_valid [w+1] : acc_m_cin_last_masked [w];
        assign shift_in_last  [w] = shift_sel  [w] ? shift_out_last  [w+1] : acc_m_last            [w];

        assign shift_in_user  [w][I_IS_1X1:I_IS_NOT_MAX] = shift_sel  [w] ? shift_out_user  [w+1][I_IS_1X1:I_IS_NOT_MAX] : acc_m_user      [w][I_IS_1X1:I_IS_NOT_MAX];
        assign shift_in_user  [w][I_IS_LEFT_COL ]        = shift_sel  [w] ? shift_out_user  [w+1][I_IS_LEFT_COL ]        : pad_is_left_col [w];
        assign shift_in_user  [w][I_IS_RIGHT_COL]        = shift_sel  [w] ? shift_out_user  [w+1][I_IS_RIGHT_COL]        : pad_is_right_col[w];
      end

      assign shift_in_valid [KERNEL_W_MAX - 1] = acc_m_cin_last_masked [KERNEL_W_MAX - 1];
      assign shift_in_last  [KERNEL_W_MAX - 1] = acc_m_cin_last_masked [KERNEL_W_MAX - 1];

      assign shift_in_user  [KERNEL_W_MAX - 1][I_IS_1X1:I_IS_NOT_MAX] = acc_m_user [KERNEL_W_MAX - 1][I_IS_1X1:I_IS_NOT_MAX];
      assign shift_in_user  [KERNEL_W_MAX - 1][I_IS_LEFT_COL ] = pad_is_left_col   [KERNEL_W_MAX - 1];
      assign shift_in_user  [KERNEL_W_MAX - 1][I_IS_RIGHT_COL] = pad_is_right_col  [KERNEL_W_MAX - 1];

      n_delay_stream #(
          .N           (1                 ),
          .WORD_WIDTH  (WORD_WIDTH_OUT    ),
          .TUSER_WIDTH (TUSER_WIDTH_CONV_OUT)
      ) SHIFT_CONTROL (
          .aclk       (clk    ),
          .aclken     (clken  ), // = m_ready of outside
          .aresetn    (resetn ),

          .valid_in   (shift_in_valid  [w]),
          .last_in    (shift_in_last   [w]),
          .user_in    (shift_in_user   [w]),

          .valid_out  (shift_out_valid [w]), 
          .last_out   (shift_out_last  [w]),
          .user_out   (shift_out_user  [w])
      );
    end
  endgenerate

  /*
    PAD FILTER
  */

  pad_filter # (
    .KERNEL_W_MAX  (KERNEL_W_MAX       ),
    .TUSER_WIDTH   (TUSER_WIDTH_CONV_IN),
    .I_IS_COLS_1_K2(I_IS_COLS_1_K2     ),
    .I_IS_CONFIG   (I_IS_CONFIG        ),
    .I_IS_1X1      (I_IS_1X1           ),
    .I_IS_ACC_LAST (I_IS_ACC_LAST      ),
    .I_KERNEL_W_1  (I_KERNEL_W_1       )
  )
  pad_filter_dut
  (
    .aclk            (clk               ),
    .aclken          (clken_acc         ),
    .aresetn         (resetn            ),
    .user_in         (acc_m_user        ),
    .mask_partial    (mask_partial      ),
    .mask_full       (mask_full         ),
    .is_left_col     (pad_is_left_col   ),
    .is_right_col    (pad_is_right_col  )
  );

  assign m_valid = shift_out_valid [0];
  assign m_last  = shift_out_last  [0];
  assign m_user  = shift_out_user  [0];

  /*
    CONVOLUTION CORES

    - Each core computes an output channel
    - Pixels step buffer is kept  common to all cores, in engine (here, above)
    - Weights step buffer is placed inside each core, for weights of that output channel
    - Pixels and weights are not in sync at this point. They get into sync after weights buffer
  
  */

  generate
    /* PER-COPY*/
    for (genvar c=0; c < 2; c++) begin: c_step
      /*
        PER-CORE STEP BUFFER FOR WEIGHTS
      */
      for (genvar r=0; r < CORES/2; r++) begin: r_step_weights
        step_buffer  #(
          .WORD_WIDTH       (WORD_WIDTH_IN    ),
          .STEPS            (KERNEL_W_MAX     ),
          .ACCUMULATOR_DELAY(ACCUMULATOR_DELAY),
          .TUSER_WIDTH      (TUSER_WIDTH_CONV_IN )
        ) STEP_WEIGHTS (
          .aclk       (clk),
          .aclken     (s_ready),
          .aresetn    (resetn),
          .is_1x1     (s_user[I_IS_1X1]),
          
          .s_data     (s_data_weights      [c][r]),
          .m_data     (m_step_weights_data [c][r])
        );
      end
      /*
        PER-UNIT STEP BUFFER FOR PIXELS
      */
      for (genvar u=0; u < UNITS; u++) begin: u_step_pixels
        for (genvar w=0 ; w < KERNEL_W_MAX; w++)
            assign s_step_pixels_repeated_data[c][u][w] = s_data_pixels[c][u];

        step_buffer  #(
          .WORD_WIDTH       (WORD_WIDTH_IN),
          .STEPS            (KERNEL_W_MAX),
          .ACCUMULATOR_DELAY(ACCUMULATOR_DELAY),
          .TUSER_WIDTH      (TUSER_WIDTH_CONV_IN)
        ) STEP_PIXELS (
          .aclk       (clk          ),
          .aclken     (s_ready ),
          .aresetn    (resetn       ),
          .is_1x1     (s_user[I_IS_1X1]),
          
          .s_data     (s_step_pixels_repeated_data[c][u]),
          .m_data     (m_step_pixels_data         [c][u])
        );
      end
    end

    /*
      DOT PRODUCT CHAIN
    */
    for (genvar c=0; c < 2; c++) begin: c_gen
      for (genvar r=0; r < CORES/2; r++) begin: r_gen
        for (genvar u=0; u < UNITS; u++) begin: u_gen
          for (genvar w=0; w < KERNEL_W_MAX; w++) begin: w_gen

            multiplier multiplier 
            (
              .CLK    (clk      ),
              .CE     (clken_mul),
              .A      (m_step_pixels_data [c]   [u][w]),
              .B      (m_step_weights_data[c][r]   [w]),
              .P      (mul_m_data         [c][r][u][w])
            );
            
            if (w==0) begin
              assign acc_s_data [c][r][u][w] = mul_m_data [c][r][u][w] & {WORD_WIDTH_IN{mul_m_valid[w]}};
            end
            else begin
              assign mux_s2_data[c][r][u][w] = acc_m_data [c][r][u][w-1];
              assign acc_s_data [c][r][u][w] = mux_sel [w] ? mux_s2_data [c][r][u][w] : WORD_WIDTH_OUT'(signed'(mul_m_data [c][r][u][w] & {(WORD_WIDTH_IN*2){mul_m_valid [w]}}));
              // AND the input with valid such that invalid inputs are zeroed and accumulated
            end
            
            accumulator accumulator 
            (
              .CLK    (clk),  
              .BYPASS (first_bypass[w]),  
              .CE     (clken_acc   [w]),  
              .B      (acc_s_data  [c][r][u][w]),  
              .Q      (acc_m_data  [c][r][u][w])  
            );

            n_delay_stream #(
                .N           (1             ),
                .WORD_WIDTH  (WORD_WIDTH_OUT),
                .TUSER_WIDTH (TUSER_WIDTH_CONV_IN)
            ) SHIFT (
                .aclk       (clk     ),
                .aclken     (clken   ), // = m_ready of outside
                .aresetn    (resetn ),
                .data_in    (shift_in_data  [c][r][u][w]),
                .data_out   (shift_out_data [c][r][u][w])
            );
            
            if (w == KERNEL_W_MAX-1) assign shift_in_data [c][r][u][w] = acc_m_data [c][r][u][w];
            else                     assign shift_in_data [c][r][u][w] = shift_sel  [w] ? shift_out_data [c][r][u][w+1] : acc_m_data [c][r][u][w];

            assign m_data [c][r][u] = shift_out_data  [c][r][u][0];
          end
        end
      end
    end
  endgenerate

endmodule