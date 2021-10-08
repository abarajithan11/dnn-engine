from math import floor, ceil

BYTES_XK = 1
BYTES_Y = 3

def kraken_calc_params(r,c, layer_config, BYTES_XK, BYTES_Y):
    
    is_conv, k, s, hi, ci, ho, co = layer_config
    kw = kh = k
    sw = sh = s
    wi = hi
    wo = ho

    n = r

    '''
    Parameters
    '''
    l = ceil(ho/r) if is_conv else ceil(n/r) # blocks
    
    j = kw + sw -1         # cores per elatic group
    e = floor(c/j)         # num elastic groups
    t = ceil(co/(sw*e))    # iterations

    '''
    Operations
    '''
    p = kw*kh*ci*co*ho*wo*n # operations in the layer
    

    shift_clock = 1 if is_conv and kw != 1 else 0
    n_eff = n if is_conv else n/r

    q = t*(1+n_eff*l*wi*(shift_clock+ci*kh)) # clocks needed

    p_max = q*r*c # peak op
    eff = p/p_max # perf eff

    '''
    Data
    '''
    min_dx = hi*wi*ci*n
    min_dy = ho*wo*co*n
    min_dk = kh*kw*ci*co

    min_bytes = (min_dx + min_dk) * BYTES_XK + min_dy * BYTES_Y

    f = ceil(kh/sh)-1      # shift amount
    hl = r + f             # block height
    dx = hl*sh*ci*wi*l*t*n_eff
    dy = r*e*sw* wo*l*t*n_eff 
    dk = c* kh*ci* sw *t
    layer_bytes = (dx + dk) * BYTES_XK + dy * BYTES_Y

    data_ratio = layer_bytes/min_bytes

    return eff, q, data_ratio, layer_bytes, p

'''
CNN CONFIG
is_conv, k,s,H,Ci,Ho,Co
'''    


alex = [
    [1, 11	,4, 228, 3   , 57, 96  ],
    [1, 5  ,1, 27 , 96  , 27, 256 ],
    [1, 3  ,1, 13 , 256 , 13, 384 ],
    [1, 3  ,1, 13 , 384 , 13, 384 ],
    [1, 3  ,1, 13 , 384 , 13, 256 ],
    [0, 1  ,1, 1  , 9216, 1 , 4096],
    [0, 1  ,1, 1  , 4096, 1 , 4096],
    [0, 1  ,1, 1  , 1000, 1 , 1000],
]

vgg16 = [
    [1, 3, 1, 224, 3    , 224, 64  ],
    [1, 3, 1, 224, 64   , 224, 64  ],
    [1, 3, 1, 112, 64   , 112, 128 ],
    [1, 3, 1, 112, 128  , 112, 128 ],
    [1, 3, 1, 56 , 128  , 56 , 256 ],
    [1, 3, 1, 56 , 256  , 56 , 256 ],
    [1, 3, 1, 56 , 256  , 56 , 256 ],
    [1, 3, 1, 28 , 256  , 28 , 512 ],
    [1, 3, 1, 28 , 512  , 28 , 512 ],
    [1, 3, 1, 28 , 512  , 28 , 512 ],
    [1, 3, 1, 14 , 512  , 14 , 512 ],
    [1, 3, 1, 14 , 512  , 14 , 512 ],
    [1, 3, 1, 14 , 512  , 14 , 512 ],
    [0, 1, 1, 1  , 25088, 1  , 4096],
    [0, 1, 1, 1  , 4096 , 1  , 4096],
    [0, 1, 1, 1  , 4096 , 1  , 1000],
]

res50 = [
    [1, 7 ,2 ,224 ,3    ,112 ,64  ],
    [1, 1 ,1 ,56  ,64   ,56  ,64  ],
    [1, 3 ,1 ,56  ,64   ,56  ,64  ],
    [1, 1 ,1 ,56  ,64   ,56  ,256 ],
    [1, 1 ,1 ,56  ,64   ,56  ,256 ],
    [1, 1 ,1 ,56  ,256  ,56  ,64  ],
    [1, 3 ,1 ,56  ,64   ,56  ,64  ],
    [1, 1 ,1 ,56  ,64   ,56  ,256 ],
    [1, 1 ,1 ,56  ,256  ,56  ,64  ],
    [1, 3 ,1 ,56  ,64   ,56  ,64  ],
    [1, 1 ,1 ,56  ,64   ,56  ,256 ],
    [1, 1 ,1 ,28  ,256  ,28  ,128 ],
    [1, 3 ,1 ,28  ,128  ,28  ,128 ],
    [1, 1 ,1 ,28  ,256  ,28  ,512 ],
    [1, 1 ,1 ,28  ,128  ,28  ,512 ],
    [1, 1 ,1 ,28  ,512  ,28  ,128 ],
    [1, 3 ,1 ,28  ,128  ,28  ,128 ],
    [1, 1 ,1 ,28  ,128  ,28  ,512 ],
    [1, 1 ,1 ,28  ,512  ,28  ,128 ],
    [1, 3 ,1 ,28  ,128  ,28  ,128 ],
    [1, 1 ,1 ,28  ,128  ,28  ,512 ],
    [1, 1 ,1 ,28  ,512  ,28  ,128 ],
    [1, 3 ,1 ,28  ,128  ,28  ,128 ],
    [1, 1 ,1 ,28  ,128  ,28  ,512 ],
    [1, 1 ,1 ,14  ,512  ,14  ,256 ],
    [1, 3 ,1 ,14  ,256  ,14  ,256 ],
    [1, 1 ,1 ,14  ,512  ,14  ,1024],
    [1, 1 ,1 ,14  ,256  ,14  ,1024],
    [1, 1 ,1 ,14  ,1024 ,14  ,256 ],
    [1, 3 ,1 ,14  ,256  ,14  ,256 ],
    [1, 1 ,1 ,14  ,256  ,14  ,1024],
    [1, 1 ,1 ,14  ,1024 ,14  ,256 ],
    [1, 3 ,1 ,14  ,256  ,14  ,256 ],
    [1, 1 ,1 ,14  ,256  ,14  ,1024],
    [1, 1 ,1 ,14  ,1024 ,14  ,256 ],
    [1, 3 ,1 ,14  ,256  ,14  ,256 ],
    [1, 1 ,1 ,14  ,256  ,14  ,1024],
    [1, 1 ,1 ,14  ,1024 ,14  ,256 ],
    [1, 3 ,1 ,14  ,256  ,14  ,256 ],
    [1, 1 ,1 ,14  ,256  ,14  ,1024],
    [1, 1 ,1 ,14  ,1024 ,14  ,256 ],
    [1, 3 ,1 ,14  ,256  ,14  ,256 ],
    [1, 1 ,1 ,14  ,256  ,14  ,1024],
    [1, 1 ,1 ,7   ,1024 ,7   ,512 ],
    [1, 3 ,1 ,7   ,512  ,7   ,512 ],
    [1, 1 ,1 ,7   ,1024 ,7   ,2048],
    [1, 1 ,1 ,7   ,512  ,7   ,2048],
    [1, 1 ,1 ,7   ,2048 ,7   ,512 ],
    [1, 3 ,1 ,7   ,512  ,7   ,512 ],
    [1, 1 ,1 ,7   ,512  ,7   ,2048],
    [1, 1 ,1 ,7   ,2048 ,7   ,512 ],
    [1, 3 ,1 ,7   ,512  ,7   ,512 ],
    [1, 1 ,1 ,7   ,512  ,7   ,2048],
    [0, 1 ,1 ,1   ,2048 ,1   ,1000],
]
