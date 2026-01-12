AESCore/
├── rtl/
│   ├── common/             <-- 存放两边共用的模块
│   │   ├── taxi_axis_if.sv     (接口定义)
│   │   ├── SBox.sv             (S盒，加密和密钥扩展都会用到)
│   │   ├── xTimes.sv           (GF(2^8)域乘法辅助模块)
│   │   ├── AddRoundKey.sv      (轮密钥加，只是简单的异或，两边通用)
│   │   └── KeyExpander.sv      (密钥扩展模块，加解密通常用同一套正向扩展)
│   │
│   ├── cipher/             <-- 存放加密专用模块
│   │   ├── AESCipher.sv        (加密顶层)
│   │   ├── AESRound.sv         (加密轮函数)
│   │   ├── SubBytes.sv         (字节代换)
│   │   ├── ShiftRows.sv        (行移位)
│   │   └── MixColumns.sv       (列混合)
│   │
│   └── inv_cipher/         <-- 存放解密专用模块
│       ├── InvAESCipher.sv     (解密顶层)
│       ├── InvAESRound.sv      (解密轮函数)
│       ├── InvSBox.sv          (逆S盒，解密专用)
│       ├── InvSubBytes.sv      (逆字节代换)
│       ├── InvShiftRows.sv     (逆行移位)
│       └── InvMixColumns.sv    (逆列混合)
│
└── tb/                    <-- 存放测试平台
    ├── tb_AESCipher.sv
    └── tb_InvAESCipher.sv