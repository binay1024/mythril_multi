label_0000:
	// Inputs[1] { @0005  msg.value }
	0000    60  PUSH1 0x80
	0002    60  PUSH1 0x40
	0004    52  MSTORE
	0005    34  CALLVALUE
	0006    80  DUP1
	0007    15  ISZERO
	0008    61  PUSH2 0x0010
	000B    57  *JUMPI
	// Stack delta = +1
	// Outputs[2]
	// {
	//     @0004  memory[0x40:0x60] = 0x80
	//     @0005  stack[0] = msg.value
	// }
	// Block ends with conditional jump to 0x0010, if !msg.value

label_000C:
	// Incoming jump from 0x000B, if not !msg.value
	// Inputs[1] { @000F  memory[0x00:0x00] }
	000C    60  PUSH1 0x00
	000E    80  DUP1
	000F    FD  *REVERT
	// Stack delta = +0
	// Outputs[1] { @000F  revert(memory[0x00:0x00]); }
	// Block terminates

label_0010:
	// Incoming jump from 0x000B, if !msg.value
	// Inputs[1] { @001E  memory[0x00:0x0133] }
	0010    5B  JUMPDEST
	0011    50  POP
	0012    61  PUSH2 0x0133
	0015    80  DUP1
	0016    61  PUSH2 0x0020
	0019    60  PUSH1 0x00
	001B    39  CODECOPY
	001C    60  PUSH1 0x00
	001E    F3  *RETURN
	// Stack delta = -1
	// Outputs[2]
	// {
	//     @001B  memory[0x00:0x0133] = code[0x20:0x0153]
	//     @001E  return memory[0x00:0x0133];
	// }
	// Block terminates

	001F    FE    *ASSERT
	0020    60    PUSH1 0x80
	0022    60    PUSH1 0x40
	0024    52    MSTORE
	0025    34    CALLVALUE
	0026    80    DUP1
	0027    15    ISZERO
	0028    60    PUSH1 0x0f
	002A    57    *JUMPI
	002B    60    PUSH1 0x00
	002D    80    DUP1
	002E    FD    *REVERT
	002F    5B    JUMPDEST
	0030    50    POP
	0031    60    PUSH1 0x04
	0033    36    CALLDATASIZE
	0034    10    LT
	0035    60    PUSH1 0x32
	0037    57    *JUMPI
	0038    60    PUSH1 0x00
	003A    35    CALLDATALOAD
	003B    60    PUSH1 0xe0
	003D    1C    SHR
	003E    80    DUP1
	003F    63    PUSH4 0x3fa4f245
	0044    14    EQ
	0045    60    PUSH1 0x37
	0047    57    *JUMPI
	0048    80    DUP1
	0049    63    PUSH4 0x55241077
	004E    14    EQ
	004F    60    PUSH1 0x51
	0051    57    *JUMPI
	0052    5B    JUMPDEST
	0053    60    PUSH1 0x00
	0055    80    DUP1
	0056    FD    *REVERT
	0057    5B    JUMPDEST
	0058    60    PUSH1 0x3d
	005A    60    PUSH1 0x69
	005C    56    *JUMP
	005D    5B    JUMPDEST
	005E    60    PUSH1 0x40
	0060    51    MLOAD
	0061    60    PUSH1 0x48
	0063    91    SWAP2
	0064    90    SWAP1
	0065    60    PUSH1 0xc1
	0067    56    *JUMP
	0068    5B    JUMPDEST
	0069    60    PUSH1 0x40
	006B    51    MLOAD
	006C    80    DUP1
	006D    91    SWAP2
	006E    03    SUB
	006F    90    SWAP1
	0070    F3    *RETURN
	0071    5B    JUMPDEST
	0072    60    PUSH1 0x67
	0074    60    PUSH1 0x04
	0076    80    DUP1
	0077    36    CALLDATASIZE
	0078    03    SUB
	0079    81    DUP2
	007A    01    ADD
	007B    90    SWAP1
	007C    60    PUSH1 0x63
	007E    91    SWAP2
	007F    90    SWAP1
	0080    60    PUSH1 0x8c
	0082    56    *JUMP
	0083    5B    JUMPDEST
	0084    60    PUSH1 0x6f
	0086    56    *JUMP
	0087    5B    JUMPDEST
	0088    00    *STOP
	0089    5B    JUMPDEST
	008A    60    PUSH1 0x00
	008C    54    SLOAD
	008D    81    DUP2
	008E    56    *JUMP
	008F    5B    JUMPDEST
	0090    80    DUP1
	0091    60    PUSH1 0x00
	0093    81    DUP2
	0094    90    SWAP1
	0095    55    SSTORE
	0096    50    POP
	0097    50    POP
	0098    56    *JUMP
	0099    5B    JUMPDEST
	009A    60    PUSH1 0x00
	009C    81    DUP2
	009D    35    CALLDATALOAD
	009E    90    SWAP1
	009F    50    POP
	00A0    60    PUSH1 0x86
	00A2    81    DUP2
	00A3    60    PUSH1 0xe9
	00A5    56    *JUMP
	00A6    5B    JUMPDEST
	00A7    92    SWAP3
	00A8    91    SWAP2
	00A9    50    POP
	00AA    50    POP
	00AB    56    *JUMP
	00AC    5B    JUMPDEST
	00AD    60    PUSH1 0x00
	00AF    60    PUSH1 0x20
	00B1    82    DUP3
	00B2    84    DUP5
	00B3    03    SUB
	00B4    12    SLT
	00B5    15    ISZERO
	00B6    60    PUSH1 0x9f
	00B8    57    *JUMPI
	00B9    60    PUSH1 0x9e
	00BB    60    PUSH1 0xe4
	00BD    56    *JUMP
	00BE    5B    JUMPDEST
	00BF    5B    JUMPDEST
	00C0    60    PUSH1 0x00
	00C2    60    PUSH1 0xab
	00C4    84    DUP5
	00C5    82    DUP3
	00C6    85    DUP6
	00C7    01    ADD
	00C8    60    PUSH1 0x79
	00CA    56    *JUMP
	00CB    5B    JUMPDEST
	00CC    91    SWAP2
	00CD    50    POP
	00CE    50    POP
	00CF    92    SWAP3
	00D0    91    SWAP2
	00D1    50    POP
	00D2    50    POP
	00D3    56    *JUMP
	00D4    5B    JUMPDEST
	00D5    60    PUSH1 0xbb
	00D7    81    DUP2
	00D8    60    PUSH1 0xda
	00DA    56    *JUMP
	00DB    5B    JUMPDEST
	00DC    82    DUP3
	00DD    52    MSTORE
	00DE    50    POP
	00DF    50    POP
	00E0    56    *JUMP
	00E1    5B    JUMPDEST
	00E2    60    PUSH1 0x00
	00E4    60    PUSH1 0x20
	00E6    82    DUP3
	00E7    01    ADD
	00E8    90    SWAP1
	00E9    50    POP
	00EA    60    PUSH1 0xd4
	00EC    60    PUSH1 0x00
	00EE    83    DUP4
	00EF    01    ADD
	00F0    84    DUP5
	00F1    60    PUSH1 0xb4
	00F3    56    *JUMP
	00F4    5B    JUMPDEST
	00F5    92    SWAP3
	00F6    91    SWAP2
	00F7    50    POP
	00F8    50    POP
	00F9    56    *JUMP
	00FA    5B    JUMPDEST
	00FB    60    PUSH1 0x00
	00FD    81    DUP2
	00FE    90    SWAP1
	00FF    50    POP
	0100    91    SWAP2
	0101    90    SWAP1
	0102    50    POP
	0103    56    *JUMP
	0104    5B    JUMPDEST
	0105    60    PUSH1 0x00
	0107    80    DUP1
	0108    FD    *REVERT
	0109    5B    JUMPDEST
	010A    60    PUSH1 0xf0
	010C    81    DUP2
	010D    60    PUSH1 0xda
	010F    56    *JUMP
	0110    5B    JUMPDEST
	0111    81    DUP2
	0112    14    EQ
	0113    60    PUSH1 0xfa
	0115    57    *JUMPI
	0116    60    PUSH1 0x00
	0118    80    DUP1
	0119    FD    *REVERT
	011A    5B    JUMPDEST
	011B    50    POP
	011C    56    *JUMP
	011D    FE    *ASSERT
	011E    A2    LOG2
	011F    64    PUSH5 0x6970667358
	0125    22    22
	0126    12    SLT
	0127    20    SHA3
	0128    64    PUSH5 0xd23f3d8847
	012E    AF    AF
	012F    28    28
	0130    51    MLOAD
	0131    8A    DUP11
	0132    21    21
	0133    CD    CD
	0134    DB    DB
	0135    45    GASLIMIT
	0136    44    DIFFICULTY
	0137    7E    PUSH31 0x81d7ac1a7f6e5750ff5366115fac955364736f6c63430008070033