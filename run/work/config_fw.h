#define N_BUNDLES 7
Bundle_t bundles [N_BUNDLES] = {
   {.n=1  , .l=1  , .kw=7  , .coe=9  , .h=28 , .w=28 , .ci=1   , .co=8   , .w_kw2=25 , .t=1  , .p=1  , .cm=73 , .cm_p0=1  , .on=1  , .oh=7  , .ow=10 , .oc=8   , .ch=14 , .ph=7  , .cw=28 , .pw=10 , .xp_words=1008  , .b_offset=0    , .w_bpt=224  , .w_bpt_p0=224  , .x_bpt=504     , .x_bpt_p0=504     , .o_words=2560    , .o_bytes=1280    , .ib_out=1   , .in_buffer_idx=-1 , .out_buffer_idx=0  , .add_out_buffer_idx=0 , .add_in_buffer_idx=-1, .is_bias=1  , .is_flatten=0  , .is_softmax=0  , .x_pad=4  , .b_val_shift=9  , .b_bias_shift=0  , .ca_nzero=0  , .ca_shift=12 , .ca_pl_scale=0  , .aa_nzero=0  , .aa_shift=0  , .aa_pl_scale=0  , .pa_nzero=1  , .pa_shift=0  , .pa_pl_scale=0  , .softmax_frac=0  , .csh=2  , .csh_shift=1  , .pkh=3  , .psh=2  , .psh_shift=0  , .csw=1  , .csw_shift=0  , .pkw=4  , .psw=3  , .psw_shift=1  , .pool=POOL_AVG  , .softmax_max_f=0              , .header=    4593777182697849051u, .debug_nhwc_words=560       },
   {.n=1  , .l=1  , .kw=1  , .coe=64 , .h=7  , .w=10 , .ci=8   , .co=8   , .w_kw2=10 , .t=1  , .p=1  , .cm=512, .cm_p0=8  , .on=1  , .oh=7  , .ow=10 , .oc=8   , .ch=7  , .ph=7  , .cw=10 , .pw=10 , .xp_words=320   , .b_offset=9    , .w_bpt=256  , .w_bpt_p0=256  , .x_bpt=1280    , .x_bpt_p0=1280    , .o_words=2880    , .o_bytes=1440    , .ib_out=2   , .in_buffer_idx=0  , .out_buffer_idx=1  , .add_out_buffer_idx=1 , .add_in_buffer_idx=0 , .is_bias=1  , .is_flatten=0  , .is_softmax=0  , .x_pad=0  , .b_val_shift=9  , .b_bias_shift=0  , .ca_nzero=1  , .ca_shift=12 , .ca_pl_scale=0  , .aa_nzero=1  , .aa_shift=3  , .aa_pl_scale=3  , .pa_nzero=0  , .pa_shift=0  , .pa_pl_scale=0  , .softmax_frac=0  , .csh=1  , .csh_shift=0  , .pkh=1  , .psh=1  , .psh_shift=0  , .csw=1  , .csw_shift=0  , .pkw=1  , .psw=1  , .psw_shift=0  , .pool=POOL_NONE , .softmax_max_f=0              , .header=    4602802033060675656u, .debug_nhwc_words=560       },
   {.n=1  , .l=1  , .kw=7  , .coe=9  , .h=7  , .w=10 , .ci=8   , .co=8   , .w_kw2=7  , .t=1  , .p=1  , .cm=73 , .cm_p0=8  , .on=1  , .oh=7  , .ow=10 , .oc=8   , .ch=7  , .ph=7  , .cw=10 , .pw=10 , .xp_words=360   , .b_offset=73   , .w_bpt=1792 , .w_bpt_p0=1792 , .x_bpt=1440    , .x_bpt_p0=1440    , .o_words=2880    , .o_bytes=1440    , .ib_out=3   , .in_buffer_idx=1  , .out_buffer_idx=0  , .add_out_buffer_idx=-1, .add_in_buffer_idx=1 , .is_bias=1  , .is_flatten=0  , .is_softmax=0  , .x_pad=4  , .b_val_shift=9  , .b_bias_shift=0  , .ca_nzero=1  , .ca_shift=12 , .ca_pl_scale=0  , .aa_nzero=0  , .aa_shift=0  , .aa_pl_scale=0  , .pa_nzero=0  , .pa_shift=0  , .pa_pl_scale=0  , .softmax_frac=0  , .csh=1  , .csh_shift=0  , .pkh=1  , .psh=1  , .psh_shift=0  , .csw=1  , .csw_shift=0  , .pkw=1  , .psw=1  , .psw_shift=0  , .pool=POOL_NONE , .softmax_max_f=0              , .header=    4594639199814484043u, .debug_nhwc_words=560       },
   {.n=1  , .l=1  , .kw=5  , .coe=12 , .h=7  , .w=10 , .ci=8   , .co=8   , .w_kw2=8  , .t=1  , .p=1  , .cm=102, .cm_p0=8  , .on=1  , .oh=7  , .ow=10 , .oc=8   , .ch=7  , .ph=7  , .cw=10 , .pw=10 , .xp_words=360   , .b_offset=82   , .w_bpt=1280 , .w_bpt_p0=1280 , .x_bpt=1440    , .x_bpt_p0=1440    , .o_words=2880    , .o_bytes=1440    , .ib_out=4   , .in_buffer_idx=0  , .out_buffer_idx=1  , .add_out_buffer_idx=-1, .add_in_buffer_idx=0 , .is_bias=1  , .is_flatten=0  , .is_softmax=0  , .x_pad=4  , .b_val_shift=9  , .b_bias_shift=0  , .ca_nzero=1  , .ca_shift=12 , .ca_pl_scale=0  , .aa_nzero=0  , .aa_shift=0  , .aa_pl_scale=0  , .pa_nzero=0  , .pa_shift=0  , .pa_pl_scale=0  , .softmax_frac=0  , .csh=1  , .csh_shift=0  , .pkh=1  , .psh=1  , .psh_shift=0  , .csw=1  , .csw_shift=0  , .pkw=1  , .psw=1  , .psw_shift=0  , .pool=POOL_NONE , .softmax_max_f=0              , .header=    4585350529475346506u, .debug_nhwc_words=560       },
   {.n=1  , .l=1  , .kw=3  , .coe=21 , .h=7  , .w=10 , .ci=8   , .co=24  , .w_kw2=9  , .t=2  , .p=1  , .cm=170, .cm_p0=8  , .on=1  , .oh=7  , .ow=10 , .oc=24  , .ch=7  , .ph=7  , .cw=10 , .pw=10 , .xp_words=360   , .b_offset=94   , .w_bpt=768  , .w_bpt_p0=768  , .x_bpt=1440    , .x_bpt_p0=1440    , .o_words=7680    , .o_bytes=3840    , .ib_out=5   , .in_buffer_idx=1  , .out_buffer_idx=0  , .add_out_buffer_idx=-1, .add_in_buffer_idx=-1, .is_bias=1  , .is_flatten=0  , .is_softmax=0  , .x_pad=4  , .b_val_shift=9  , .b_bias_shift=0  , .ca_nzero=0  , .ca_shift=12 , .ca_pl_scale=0  , .aa_nzero=0  , .aa_shift=0  , .aa_pl_scale=0  , .pa_nzero=0  , .pa_shift=0  , .pa_pl_scale=0  , .softmax_frac=0  , .csh=1  , .csh_shift=0  , .pkh=1  , .psh=1  , .psh_shift=0  , .csw=1  , .csw_shift=0  , .pkw=1  , .psw=1  , .psw_shift=0  , .pool=POOL_NONE , .softmax_max_f=0              , .header=    4585069063625441353u, .debug_nhwc_words=1680      },
   {.n=1  , .l=1  , .kw=1  , .coe=64 , .h=7  , .w=10 , .ci=24  , .co=10  , .w_kw2=10 , .t=1  , .p=1  , .cm=512, .cm_p0=24 , .on=1  , .oh=1  , .ow=1  , .oc=700 , .ch=7  , .ph=7  , .cw=10 , .pw=10 , .xp_words=320   , .b_offset=136  , .w_bpt=768  , .w_bpt_p0=768  , .x_bpt=3840    , .x_bpt_p0=3840    , .o_words=22400   , .o_bytes=11200   , .ib_out=6   , .in_buffer_idx=0  , .out_buffer_idx=1  , .add_out_buffer_idx=-1, .add_in_buffer_idx=-1, .is_bias=1  , .is_flatten=1  , .is_softmax=0  , .x_pad=0  , .b_val_shift=9  , .b_bias_shift=0  , .ca_nzero=0  , .ca_shift=12 , .ca_pl_scale=0  , .aa_nzero=0  , .aa_shift=0  , .aa_pl_scale=0  , .pa_nzero=0  , .pa_shift=0  , .pa_pl_scale=0  , .softmax_frac=0  , .csh=1  , .csh_shift=0  , .pkh=1  , .psh=1  , .psh_shift=0  , .csw=1  , .csw_shift=0  , .pkw=1  , .psw=1  , .psw_shift=0  , .pool=POOL_NONE , .softmax_max_f=0              , .header=    4603083508038434888u, .debug_nhwc_words=700       },
   {.n=1  , .l=1  , .kw=1  , .coe=64 , .h=1  , .w=1  , .ci=700 , .co=10  , .w_kw2=1  , .t=1  , .p=2  , .cm=512, .cm_p0=188, .on=1  , .oh=1  , .ow=1  , .oc=10  , .ch=1  , .ph=1  , .cw=1  , .pw=1  , .xp_words=32    , .b_offset=200  , .w_bpt=16384, .w_bpt_p0=6016 , .x_bpt=8192    , .x_bpt_p0=3008    , .o_words=10      , .o_bytes=40      , .ib_out=-1  , .in_buffer_idx=1  , .out_buffer_idx=-1 , .add_out_buffer_idx=-1, .add_in_buffer_idx=-1, .is_bias=0  , .is_flatten=0  , .is_softmax=1  , .x_pad=0  , .b_val_shift=0  , .b_bias_shift=0  , .ca_nzero=1  , .ca_shift=3  , .ca_pl_scale=0  , .aa_nzero=0  , .aa_shift=0  , .aa_pl_scale=0  , .pa_nzero=0  , .pa_shift=0  , .pa_pl_scale=0  , .softmax_frac=3  , .csh=1  , .csh_shift=0  , .pkh=1  , .psh=1  , .psh_shift=0  , .csw=1  , .csw_shift=0  , .pkw=1  , .psw=1  , .psw_shift=0  , .pool=POOL_NONE , .softmax_max_f=0.375          , .header=    4605968626560466944u, .debug_nhwc_words=10        }
};

#define X_BITS_L2   2
#define W_BITS_L2   2
#define KH_MAX      9
#define PE_ROWS     32
#define PE_COLS     64

#define N_OUT_BUF   2
#define N_ADD_BUF   2
#define WB_BYTES    28656
#define W_BYTES     28256
#define X_BYTES     504
#define O_WORDS     10
#define O_WORDS_MAX 22400
#define O_BYTES_MAX 11200
#define X_BYTES_ALL 21144
#define NHWC_WORDS  6272
#define Y_TYPE      int32_t
#define B_TYPE      int16_t
#define O_TYPE      float
#define B_WORDS     200
#define AXI_WIDTH   64
#define CONFIG_BASEADDR 0xB0000000
#define DATA_DIR   "../vectors"

static const uint8_t X_POSITION_INVERTED_MASKS [] = { 240, 15 };
