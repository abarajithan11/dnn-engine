module axis_lrelu_engine #(
    WORD_WIDTH_IN  = 32,
    WORD_WIDTH_OUT = 8 ,
    WORD_WIDTH_CONFIG = 8,

    UNITS   = 8,
    GROUPS  = 2,
    COPIES  = 2,
    MEMBERS = 2,

    CONFIG_BEATS_3X3_1 = 21-1,
    CONFIG_BEATS_1X1_1 = 9 -1,
    
    LATENCY_FIXED_2_FLOAT =  6,
    LATENCY_FLOAT_32      = 16,
    BRAM_LATENCY          = 2 ,

    BITS_CONV_CORE       = $clog2(GROUPS * COPIES * MEMBERS),
    I_IS_3X3             = BITS_CONV_CORE + 0,  
    I_MAXPOOL_IS_MAX     = BITS_CONV_CORE + 1,
    I_MAXPOOL_IS_NOT_MAX = BITS_CONV_CORE + 2,
    I_LRELU_IS_LRELU     = BITS_CONV_CORE + 3,
    I_LRELU_IS_TOP       = BITS_CONV_CORE + 4,
    I_LRELU_IS_BOTTOM    = BITS_CONV_CORE + 5,
    I_LRELU_IS_LEFT      = BITS_CONV_CORE + 6,
    I_LRELU_IS_RIGHT     = BITS_CONV_CORE + 7,

    TUSER_WIDTH_LRELU       = BITS_CONV_CORE + 8,
    TUSER_WIDTH_LRELU_FMA_1 = BITS_CONV_CORE + 4,
    TUSER_WIDTH_MAXPOOL     = BITS_CONV_CORE + 3
  )(
    aclk         ,
    aresetn      ,
    s_axis_tvalid,
    s_axis_tready,
    s_axis_tdata , // mcgu
    s_axis_tuser ,
    s_axis_tlast ,
    m_axis_tvalid,
    m_axis_tready,
    m_axis_tdata , // cgu
    m_axis_tuser 
  );

    input  wire aclk, aresetn;
    input  wire s_axis_tvalid, s_axis_tlast, m_axis_tready;
    output wire m_axis_tvalid, s_axis_tready;
    input  wire [TUSER_WIDTH_LRELU  -1:0] s_axis_tuser;
    output wire [TUSER_WIDTH_MAXPOOL-1:0] m_axis_tuser;

    input  wire [MEMBERS * COPIES * GROUPS * UNITS * WORD_WIDTH_IN -1:0] s_axis_tdata;
    output wire [          COPIES * GROUPS * UNITS * WORD_WIDTH_OUT-1:0] m_axis_tdata;

    wire [MEMBERS * COPIES * GROUPS * UNITS * WORD_WIDTH_IN -1:0] s_axis_tdata_cmgu;

    wire [COPIES * GROUPS * UNITS * WORD_WIDTH_IN -1:0] s_data_e;
    wire [COPIES * GROUPS * UNITS * WORD_WIDTH_OUT-1:0] m_data_e;
    wire s_valid_e, s_last_e, m_valid_e;
    wire [TUSER_WIDTH_LRELU  -1:0] s_user_e;
    wire [TUSER_WIDTH_MAXPOOL-1:0] m_user_e;
    wire s_ready_slice;

    localparam BYTES_IN = WORD_WIDTH_IN/8;

    /*
      AXIS DEMUX

      * sel_config is driven by state machine 
        - 1: slave bypasses dw and directly connects to config port
        - 0: slave connects to dw bank
    */
    wire dw_s_valid, dw_s_ready, config_s_valid;
    reg  sel_config, resetn_config, config_s_ready;

    assign dw_s_valid     = sel_config ? 0              : s_axis_tvalid;
    assign config_s_valid = sel_config ? s_axis_tvalid  : 0;
    assign s_axis_tready  = sel_config ? config_s_ready : dw_s_ready;

    /*
      STATE MACHINE

      * initial state: WRITE_1_S

      * PASS_S:
        - connect dw to slave
        - when a tlast enters dw, switch to BLOCK
      * BLOCK_S:
        - connect config to slave
        - keep s_ready low (block transactions)
        - wait until all members of last transactions leave dw
        - when tlast leaves dw, switch to RESET
      * RESET_S:
        - pass a config_resetn for one clock
        - keep s_ready low (block transactions)
        - this is tied to the delays. This goes just behind the data and clears 
            the bram buffer registers just after they process the tlast from previous cycle.
      * WRITE_1_S:
        - connect engine's config to slave
        - Get the first config beat
        - Also sample whether it is 3x3 or 1x1. 
        - Hence set the config_count as num_beats-1
      * WRITE_2_S:
        - connect engine's config to slave
        - config_count decremets at every config_handshake
        - when config_count = 0 and handshake, switch to PASS_S
      * FILL_S
        - Block input and wait for (BRAM_LATENCY+1) clocks for BRAMs to get valid
      * default:
        - same as PASS_S
    */
    wire config_handshake, s_vr_last_conv_out, s_vr_last_dw_out;

    assign s_vr_last_conv_out = s_axis_tlast  && s_axis_tvalid && s_axis_tready;
    assign s_vr_last_dw_out   = s_last_e      && s_valid_e     && s_ready_slice;
    assign config_handshake   = s_axis_tvalid && config_s_ready;

    localparam PASS_S    = 0;
    localparam BLOCK_S   = 1;
    localparam RESET_S   = 2;
    localparam WRITE_1_S = 3;
    localparam WRITE_2_S = 4;
    localparam FILL_S    = 5;

    wire [2:0] state;
    reg  [2:0] state_next;
    register #(
      .WORD_WIDTH   (3), 
      .RESET_VALUE  (WRITE_1_S)
    ) STATE (
      .clock        (aclk   ),
      .resetn       (aresetn),
      .clock_enable (1'b1),
      .data_in      (state_next),
      .data_out     (state)
    );

    localparam CONFIG_BEATS_BITS = $clog2(CONFIG_BEATS_3X3_1 + 1);
    wire [CONFIG_BEATS_BITS-1:0] count_config, num_beats_1;
    reg  [CONFIG_BEATS_BITS-1:0] count_config_next;
    register #(
      .WORD_WIDTH   (CONFIG_BEATS_BITS), 
      .RESET_VALUE  (0)
    ) COUNT_CONFIG (
      .clock        (aclk   ),
      .resetn       (aresetn),
      .clock_enable (config_handshake ),
      .data_in      (count_config_next),
      .data_out     (count_config)
    );
    localparam FILL_BITS = $clog2(BRAM_LATENCY+1);
    wire [FILL_BITS-1:0] count_fill;
    reg  [FILL_BITS-1:0] count_fill_next;    
    register #(
      .WORD_WIDTH   (FILL_BITS), 
      .RESET_VALUE  (0)
    ) FILL_CONFIG (
      .clock        (aclk   ),
      .resetn       (aresetn),
      .clock_enable (s_ready_slice ),
      .data_in      (count_fill_next),
      .data_out     (count_fill)
    );

    always @ (*) begin
      state_next = state;
      case (state)
        PASS_S    : if (s_vr_last_conv_out) state_next = BLOCK_S;
        BLOCK_S   : if (s_vr_last_dw_out  ) state_next = RESET_S;
        RESET_S   : if (s_ready_slice)      state_next = WRITE_1_S;
        WRITE_1_S : if (config_handshake)   state_next = WRITE_2_S;
        WRITE_2_S : if ((count_config == 0)              && config_handshake) state_next = FILL_S;
        FILL_S    : if (count_fill == (BRAM_LATENCY+1-1) && s_ready_slice )   state_next = PASS_S;
        default   : state_next = state;
      endcase
    end

    always @ (*) begin
      case (state)
        PASS_S  : begin
                    sel_config        = 0;
                    config_s_ready    = 0;
                    resetn_config     = 1;
                    count_config_next = 0;
                    count_fill_next   = 0;
                  end
        BLOCK_S : begin
                    sel_config        = 1;
                    config_s_ready    = 0;
                    resetn_config     = 1;
                    count_config_next = 0;
                    count_fill_next   = 0;
                  end
        RESET_S : begin
                    sel_config        = 1;
                    config_s_ready    = 0;
                    resetn_config     = 0;
                    count_config_next = 0;
                    count_fill_next   = 0;
                  end
        WRITE_1_S:begin
                    sel_config        = 1;
                    config_s_ready    = s_ready_slice;
                    resetn_config     = 1;
                    count_config_next = s_axis_tuser[I_IS_3X3] ? CONFIG_BEATS_3X3_1 : CONFIG_BEATS_1X1_1;
                    count_fill_next   = 0;
                  end
        WRITE_2_S:begin
                    sel_config        = 1;
                    config_s_ready    = s_ready_slice;
                    resetn_config     = 1;
                    count_config_next = count_config - 1;
                    count_fill_next   = 0;
                  end
        FILL_S:   begin
                    sel_config        = 1;
                    config_s_ready    = 0;
                    resetn_config     = 1;
                    count_config_next = 0;
                    count_fill_next   = count_fill + 1;
                  end
        default  :begin
                    sel_config        = 0;
                    config_s_ready    = 0;
                    resetn_config     = 1;
                    count_config_next = 0;
                    count_fill_next   = 0;
                  end
      endcase
    end
    
    wire is_3x3_config;
    assign is_3x3_config = s_axis_tuser[I_IS_3X3];

    /*
      DATAWIDTH CONVERTER BANKS

      * Size: GUM(W) -> GU(W) : 2*8*8*(26) -> 2*8*(26) : 3328 -> 416 : 416B -> 52B
      * Number: 2 (one per copy)
    */
    generate
      for(genvar c=0; c<COPIES; c=c+1) begin: c

        // Transpose MCGU -> CGUM
        for (genvar g=0; g<GROUPS; g=g+1) begin: g
          for (genvar u=0; u<UNITS; u=u+1) begin: u
            for (genvar m=0; m<MEMBERS; m=m+1) begin: m
              assign s_axis_tdata_cmgu [(c*MEMBERS*GROUPS*UNITS + m*GROUPS*UNITS + g*UNITS + u +1)*WORD_WIDTH_IN-1:(c*MEMBERS*GROUPS*UNITS + m*GROUPS*UNITS + g*UNITS + u)*WORD_WIDTH_IN] = s_axis_tdata[(m*COPIES*GROUPS*UNITS + c*GROUPS*UNITS + g*UNITS + u +1)*WORD_WIDTH_IN-1:(m*COPIES*GROUPS*UNITS + c*GROUPS*UNITS + g*UNITS + u)*WORD_WIDTH_IN];
            end
          end
        end

        wire [MEMBERS * GROUPS * UNITS * WORD_WIDTH_IN-1:0] dw_s_data_mgu;
        wire [          GROUPS * UNITS * WORD_WIDTH_IN-1:0] dw_m_data_gu ;
        
        assign dw_s_data_mgu = s_axis_tdata_cmgu[(c+1)*MEMBERS*GROUPS*UNITS*WORD_WIDTH_IN-1:(c)*MEMBERS*GROUPS*UNITS*WORD_WIDTH_IN];
        assign s_data_e[(c+1)*GROUPS*UNITS*WORD_WIDTH_IN-1:(c)*GROUPS*UNITS*WORD_WIDTH_IN] = dw_m_data_gu;

        if (c==0) begin
          axis_dw_gum_gu_active dw (
            .aclk           (aclk),          
            .aresetn        (aresetn),             
            .s_axis_tvalid  (dw_s_valid),  
            .s_axis_tready  (dw_s_ready),  
            .s_axis_tdata   (dw_s_data_mgu),
            .s_axis_tlast   (s_axis_tlast),    
            .s_axis_tid     (s_axis_tuser),   

            .m_axis_tvalid  (s_valid_e),  
            .m_axis_tready  (s_ready_slice), 
            .m_axis_tdata   (s_data_e),
            .m_axis_tlast   (s_last_e),  
            .m_axis_tid     (s_user_e)   
          );
        end
        else begin
          axis_dw_gum_gu dw (
            .aclk           (aclk),          
            .aresetn        (aresetn),             
            .s_axis_tvalid  (dw_s_valid),  
            .s_axis_tdata   (dw_s_data_mgu),

            .m_axis_tready  (s_ready_slice), 
            .m_axis_tdata   (s_data_e)
          );
        end
      end
    endgenerate

    lrelu_engine #(
      .WORD_WIDTH_IN  (WORD_WIDTH_IN ),
      .WORD_WIDTH_OUT (WORD_WIDTH_OUT),
      .WORD_WIDTH_CONFIG(WORD_WIDTH_CONFIG ),

      .UNITS   (UNITS  ),
      .GROUPS  (GROUPS ),
      .COPIES  (COPIES ),
      .MEMBERS (MEMBERS),

      .LATENCY_FIXED_2_FLOAT (LATENCY_FIXED_2_FLOAT),
      .LATENCY_FLOAT_32      (LATENCY_FLOAT_32     ),

      .BITS_CONV_CORE       (BITS_CONV_CORE      ),
      .I_IS_3X3             (I_IS_3X3            ),
      .I_MAXPOOL_IS_MAX     (I_MAXPOOL_IS_MAX    ),
      .I_MAXPOOL_IS_NOT_MAX (I_MAXPOOL_IS_NOT_MAX),
      .I_LRELU_IS_LRELU     (I_LRELU_IS_LRELU    ),
      .I_LRELU_IS_TOP       (I_LRELU_IS_TOP      ),
      .I_LRELU_IS_BOTTOM    (I_LRELU_IS_BOTTOM   ),
      .I_LRELU_IS_LEFT      (I_LRELU_IS_LEFT     ),
      .I_LRELU_IS_RIGHT     (I_LRELU_IS_RIGHT    ),

      .TUSER_WIDTH_LRELU       (TUSER_WIDTH_LRELU      ),
      .TUSER_WIDTH_LRELU_FMA_1 (TUSER_WIDTH_LRELU_FMA_1),
      .TUSER_WIDTH_MAXPOOL     (TUSER_WIDTH_MAXPOOL    )
    )
    engine
    (
      .clk              (aclk    ),
      .clken            (s_ready_slice),
      .resetn           (aresetn  ),
      .s_valid          (s_valid_e),
      .s_user           (s_user_e ),
      .m_valid          (m_valid_e),
      .m_user           (m_user_e ),
      .s_data_flat_cgu  (s_data_e ),
      .m_data_flat_cgu  (m_data_e ),

      .resetn_config     (resetn_config ),
      .s_valid_config    (config_s_valid),
      .is_3x3_config     (is_3x3_config ),
      .s_data_conv_out   (s_axis_tdata  )
    );

    axis_reg_slice_lrelu slice (
      .aclk           (aclk           ),
      .aresetn        (aresetn        ),
      .s_axis_tvalid  (m_valid_e      ),
      .s_axis_tready  (s_ready_slice  ),
      .s_axis_tdata   (m_data_e       ),
      .s_axis_tuser   (m_user_e       ),  

      .m_axis_tvalid  (m_axis_tvalid  ),
      .m_axis_tready  (m_axis_tready  ),
      .m_axis_tdata   (m_axis_tdata   ),
      .m_axis_tuser   (m_axis_tuser   ) 
    );

endmodule