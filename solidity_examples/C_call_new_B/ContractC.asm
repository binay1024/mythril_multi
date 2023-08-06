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
	// Inputs[1] { @0014  memory[0x40:0x60] }
	0010    5B  JUMPDEST
	0011    50  POP
	0012    60  PUSH1 0x40
	0014    51  MLOAD
	0015    61  PUSH2 0x001d
	0018    90  SWAP1
	0019    61  PUSH2 0x007e
	001C    56  *JUMP
	// Stack delta = +1
	// Outputs[2]
	// {
	//     @0018  stack[0] = memory[0x40:0x60]
	//     @0018  stack[-1] = 0x001d
	// }
	// Block ends with call to 0x007e, returns to 0x001D

label_001D:
	// Incoming return from call to 0x007E at 0x001C
	// Inputs[4]
	// {
	//     @0020  memory[0x40:0x60]
	//     @0022  stack[-1]
	//     @0027  new(memory[memory[0x40:0x60]:memory[0x40:0x60] + stack[-1] - memory[0x40:0x60]]).value(0x00)()
	//     @0027  memory[memory[0x40:0x60]:memory[0x40:0x60] + stack[-1] - memory[0x40:0x60]]
	// }
	001D    5B  JUMPDEST
	001E    60  PUSH1 0x40
	0020    51  MLOAD
	0021    80  DUP1
	0022    91  SWAP2
	0023    03  SUB
	0024    90  SWAP1
	0025    60  PUSH1 0x00
	0027    F0  CREATE
	0028    80  DUP1
	0029    15  ISZERO
	002A    80  DUP1
	002B    15  ISZERO
	002C    61  PUSH2 0x0039
	002F    57  *JUMPI
	// Stack delta = +1
	// Outputs[3]
	// {
	//     @0027  new(memory[memory[0x40:0x60]:memory[0x40:0x60] + stack[-1] - memory[0x40:0x60]]).value(0x00)()
	//     @0027  stack[-1] = new(memory[memory[0x40:0x60]:memory[0x40:0x60] + stack[-1] - memory[0x40:0x60]]).value(0x00)()
	//     @0029  stack[0] = !new(memory[memory[0x40:0x60]:memory[0x40:0x60] + stack[-1] - memory[0x40:0x60]]).value(0x00)()
	// }
	// Block ends with conditional jump to 0x0039, if !!new(memory[memory[0x40:0x60]:memory[0x40:0x60] + stack[-1] - memory[0x40:0x60]]).value(0x00)()

label_0030:
	// Incoming jump from 0x002F, if not !!new(memory[memory[0x40:0x60]:memory[0x40:0x60] + stack[-1] - memory[0x40:0x60]]).value(0x00)()
	// Inputs[4]
	// {
	//     @0030  returndata.length
	//     @0034  returndata[0x00:0x00 + returndata.length]
	//     @0035  returndata.length
	//     @0038  memory[0x00:0x00 + returndata.length]
	// }
	0030    3D  RETURNDATASIZE
	0031    60  PUSH1 0x00
	0033    80  DUP1
	0034    3E  RETURNDATACOPY
	0035    3D  RETURNDATASIZE
	0036    60  PUSH1 0x00
	0038    FD  *REVERT
	// Stack delta = +0
	// Outputs[2]
	// {
	//     @0034  memory[0x00:0x00 + returndata.length] = returndata[0x00:0x00 + returndata.length]
	//     @0038  revert(memory[0x00:0x00 + returndata.length]);
	// }
	// Block terminates

label_0039:
	// Incoming jump from 0x002F, if !!new(memory[memory[0x40:0x60]:memory[0x40:0x60] + stack[-1] - memory[0x40:0x60]]).value(0x00)()
	// Inputs[2]
	// {
	//     @0043  storage[0x00]
	//     @005E  stack[-2]
	// }
	0039    5B  JUMPDEST
	003A    50  POP
	003B    60  PUSH1 0x00
	003D    80  DUP1
	003E    61  PUSH2 0x0100
	0041    0A  EXP
	0042    81  DUP2
	0043    54  SLOAD
	0044    81  DUP2
	0045    73  PUSH20 0xffffffffffffffffffffffffffffffffffffffff
	005A    02  MUL
	005B    19  NOT
	005C    16  AND
	005D    90  SWAP1
	005E    83  DUP4
	005F    73  PUSH20 0xffffffffffffffffffffffffffffffffffffffff
	0074    16  AND
	0075    02  MUL
	0076    17  OR
	0077    90  SWAP1
	0078    55  SSTORE
	0079    50  POP
	007A    61  PUSH2 0x008b
	007D    56  *JUMP
	// Stack delta = -2
	// Outputs[1] { @0078  storage[0x00] = (0xffffffffffffffffffffffffffffffffffffffff & stack[-2]) * 0x0100 ** 0x00 | (~(0xffffffffffffffffffffffffffffffffffffffff * 0x0100 ** 0x00) & storage[0x00]) }
	// Block ends with unconditional jump to 0x008b

label_007E:
	// Incoming call from 0x001C, returns to 0x001D
	// Inputs[2]
	// {
	//     @0086  stack[-1]
	//     @0089  stack[-2]
	// }
	007E    5B  JUMPDEST
	007F    61  PUSH2 0x0153
	0082    80  DUP1
	0083    61  PUSH2 0x0309
	0086    83  DUP4
	0087    39  CODECOPY
	0088    01  ADD
	0089    90  SWAP1
	008A    56  *JUMP
	// Stack delta = -1
	// Outputs[2]
	// {
	//     @0087  memory[stack[-1]:stack[-1] + 0x0153] = code[0x0309:0x045c]
	//     @0089  stack[-2] = 0x0153 + stack[-1]
	// }
	// Block ends with unconditional jump to stack[-2]

label_008B:
	// Incoming jump from 0x007D
	// Inputs[1] { @0098  memory[0x00:0x026f] }
	008B    5B  JUMPDEST
	008C    61  PUSH2 0x026f
	008F    80  DUP1
	0090    61  PUSH2 0x009a
	0093    60  PUSH1 0x00
	0095    39  CODECOPY
	0096    60  PUSH1 0x00
	0098    F3  *RETURN
	// Stack delta = +0
	// Outputs[2]
	// {
	//     @0095  memory[0x00:0x026f] = code[0x9a:0x0309]
	//     @0098  return memory[0x00:0x026f];
	// }
	// Block terminates

	0099    FE    *ASSERT
	009A    60    PUSH1 0x80
	009C    60    PUSH1 0x40
	009E    52    MSTORE
	009F    34    CALLVALUE
	00A0    80    DUP1
	00A1    15    ISZERO
	00A2    61    PUSH2 0x0010
	00A5    57    *JUMPI
	00A6    60    PUSH1 0x00
	00A8    80    DUP1
	00A9    FD    *REVERT
	00AA    5B    JUMPDEST
	00AB    50    POP
	00AC    60    PUSH1 0x04
	00AE    36    CALLDATASIZE
	00AF    10    LT
	00B0    61    PUSH2 0x0036
	00B3    57    *JUMPI
	00B4    60    PUSH1 0x00
	00B6    35    CALLDATALOAD
	00B7    60    PUSH1 0xe0
	00B9    1C    SHR
	00BA    80    DUP1
	00BB    63    PUSH4 0x672ba239
	00C0    14    EQ
	00C1    61    PUSH2 0x003b
	00C4    57    *JUMPI
	00C5    80    DUP1
	00C6    63    PUSH4 0x9ff8a368
	00CB    14    EQ
	00CC    61    PUSH2 0x0057
	00CF    57    *JUMPI
	00D0    5B    JUMPDEST
	00D1    60    PUSH1 0x00
	00D3    80    DUP1
	00D4    FD    *REVERT
	00D5    5B    JUMPDEST
	00D6    61    PUSH2 0x0055
	00D9    60    PUSH1 0x04
	00DB    80    DUP1
	00DC    36    CALLDATASIZE
	00DD    03    SUB
	00DE    81    DUP2
	00DF    01    ADD
	00E0    90    SWAP1
	00E1    61    PUSH2 0x0050
	00E4    91    SWAP2
	00E5    90    SWAP1
	00E6    61    PUSH2 0x013c
	00E9    56    *JUMP
	00EA    5B    JUMPDEST
	00EB    61    PUSH2 0x0075
	00EE    56    *JUMP
	00EF    5B    JUMPDEST
	00F0    00    *STOP
	00F1    5B    JUMPDEST
	00F2    61    PUSH2 0x005f
	00F5    61    PUSH2 0x0103
	00F8    56    *JUMP
	00F9    5B    JUMPDEST
	00FA    60    PUSH1 0x40
	00FC    51    MLOAD
	00FD    61    PUSH2 0x006c
	0100    91    SWAP2
	0101    90    SWAP1
	0102    61    PUSH2 0x0187
	0105    56    *JUMP
	0106    5B    JUMPDEST
	0107    60    PUSH1 0x40
	0109    51    MLOAD
	010A    80    DUP1
	010B    91    SWAP2
	010C    03    SUB
	010D    90    SWAP1
	010E    F3    *RETURN
	010F    5B    JUMPDEST
	0110    60    PUSH1 0x00
	0112    80    DUP1
	0113    54    SLOAD
	0114    90    SWAP1
	0115    61    PUSH2 0x0100
	0118    0A    EXP
	0119    90    SWAP1
	011A    04    DIV
	011B    73    PUSH20 0xffffffffffffffffffffffffffffffffffffffff
	0130    16    AND
	0131    73    PUSH20 0xffffffffffffffffffffffffffffffffffffffff
	0146    16    AND
	0147    63    PUSH4 0x55241077
	014C    82    DUP3
	014D    60    PUSH1 0x40
	014F    51    MLOAD
	0150    82    DUP3
	0151    63    PUSH4 0xffffffff
	0156    16    AND
	0157    60    PUSH1 0xe0
	0159    1B    SHL
	015A    81    DUP2
	015B    52    MSTORE
	015C    60    PUSH1 0x04
	015E    01    ADD
	015F    61    PUSH2 0x00ce
	0162    91    SWAP2
	0163    90    SWAP1
	0164    61    PUSH2 0x01a2
	0167    56    *JUMP
	0168    5B    JUMPDEST
	0169    60    PUSH1 0x00
	016B    60    PUSH1 0x40
	016D    51    MLOAD
	016E    80    DUP1
	016F    83    DUP4
	0170    03    SUB
	0171    81    DUP2
	0172    60    PUSH1 0x00
	0174    87    DUP8
	0175    80    DUP1
	0176    3B    EXTCODESIZE
	0177    15    ISZERO
	0178    80    DUP1
	0179    15    ISZERO
	017A    61    PUSH2 0x00e8
	017D    57    *JUMPI
	017E    60    PUSH1 0x00
	0180    80    DUP1
	0181    FD    *REVERT
	0182    5B    JUMPDEST
	0183    50    POP
	0184    5A    GAS
	0185    F1    CALL
	0186    15    ISZERO
	0187    80    DUP1
	0188    15    ISZERO
	0189    61    PUSH2 0x00fc
	018C    57    *JUMPI
	018D    3D    RETURNDATASIZE
	018E    60    PUSH1 0x00
	0190    80    DUP1
	0191    3E    RETURNDATACOPY
	0192    3D    RETURNDATASIZE
	0193    60    PUSH1 0x00
	0195    FD    *REVERT
	0196    5B    JUMPDEST
	0197    50    POP
	0198    50    POP
	0199    50    POP
	019A    50    POP
	019B    50    POP
	019C    56    *JUMP
	019D    5B    JUMPDEST
	019E    60    PUSH1 0x00
	01A0    80    DUP1
	01A1    54    SLOAD
	01A2    90    SWAP1
	01A3    61    PUSH2 0x0100
	01A6    0A    EXP
	01A7    90    SWAP1
	01A8    04    DIV
	01A9    73    PUSH20 0xffffffffffffffffffffffffffffffffffffffff
	01BE    16    AND
	01BF    81    DUP2
	01C0    56    *JUMP
	01C1    5B    JUMPDEST
	01C2    60    PUSH1 0x00
	01C4    81    DUP2
	01C5    35    CALLDATALOAD
	01C6    90    SWAP1
	01C7    50    POP
	01C8    61    PUSH2 0x0136
	01CB    81    DUP2
	01CC    61    PUSH2 0x0222
	01CF    56    *JUMP
	01D0    5B    JUMPDEST
	01D1    92    SWAP3
	01D2    91    SWAP2
	01D3    50    POP
	01D4    50    POP
	01D5    56    *JUMP
	01D6    5B    JUMPDEST
	01D7    60    PUSH1 0x00
	01D9    60    PUSH1 0x20
	01DB    82    DUP3
	01DC    84    DUP5
	01DD    03    SUB
	01DE    12    SLT
	01DF    15    ISZERO
	01E0    61    PUSH2 0x0152
	01E3    57    *JUMPI
	01E4    61    PUSH2 0x0151
	01E7    61    PUSH2 0x021d
	01EA    56    *JUMP
	01EB    5B    JUMPDEST
	01EC    5B    JUMPDEST
	01ED    60    PUSH1 0x00
	01EF    61    PUSH2 0x0160
	01F2    84    DUP5
	01F3    82    DUP3
	01F4    85    DUP6
	01F5    01    ADD
	01F6    61    PUSH2 0x0127
	01F9    56    *JUMP
	01FA    5B    JUMPDEST
	01FB    91    SWAP2
	01FC    50    POP
	01FD    50    POP
	01FE    92    SWAP3
	01FF    91    SWAP2
	0200    50    POP
	0201    50    POP
	0202    56    *JUMP
	0203    5B    JUMPDEST
	0204    61    PUSH2 0x0172
	0207    81    DUP2
	0208    61    PUSH2 0x01e7
	020B    56    *JUMP
	020C    5B    JUMPDEST
	020D    82    DUP3
	020E    52    MSTORE
	020F    50    POP
	0210    50    POP
	0211    56    *JUMP
	0212    5B    JUMPDEST
	0213    61    PUSH2 0x0181
	0216    81    DUP2
	0217    61    PUSH2 0x01dd
	021A    56    *JUMP
	021B    5B    JUMPDEST
	021C    82    DUP3
	021D    52    MSTORE
	021E    50    POP
	021F    50    POP
	0220    56    *JUMP
	0221    5B    JUMPDEST
	0222    60    PUSH1 0x00
	0224    60    PUSH1 0x20
	0226    82    DUP3
	0227    01    ADD
	0228    90    SWAP1
	0229    50    POP
	022A    61    PUSH2 0x019c
	022D    60    PUSH1 0x00
	022F    83    DUP4
	0230    01    ADD
	0231    84    DUP5
	0232    61    PUSH2 0x0169
	0235    56    *JUMP
	0236    5B    JUMPDEST
	0237    92    SWAP3
	0238    91    SWAP2
	0239    50    POP
	023A    50    POP
	023B    56    *JUMP
	023C    5B    JUMPDEST
	023D    60    PUSH1 0x00
	023F    60    PUSH1 0x20
	0241    82    DUP3
	0242    01    ADD
	0243    90    SWAP1
	0244    50    POP
	0245    61    PUSH2 0x01b7
	0248    60    PUSH1 0x00
	024A    83    DUP4
	024B    01    ADD
	024C    84    DUP5
	024D    61    PUSH2 0x0178
	0250    56    *JUMP
	0251    5B    JUMPDEST
	0252    92    SWAP3
	0253    91    SWAP2
	0254    50    POP
	0255    50    POP
	0256    56    *JUMP
	0257    5B    JUMPDEST
	0258    60    PUSH1 0x00
	025A    73    PUSH20 0xffffffffffffffffffffffffffffffffffffffff
	026F    82    DUP3
	0270    16    AND
	0271    90    SWAP1
	0272    50    POP
	0273    91    SWAP2
	0274    90    SWAP1
	0275    50    POP
	0276    56    *JUMP
	0277    5B    JUMPDEST
	0278    60    PUSH1 0x00
	027A    81    DUP2
	027B    90    SWAP1
	027C    50    POP
	027D    91    SWAP2
	027E    90    SWAP1
	027F    50    POP
	0280    56    *JUMP
	0281    5B    JUMPDEST
	0282    60    PUSH1 0x00
	0284    61    PUSH2 0x01f2
	0287    82    DUP3
	0288    61    PUSH2 0x01f9
	028B    56    *JUMP
	028C    5B    JUMPDEST
	028D    90    SWAP1
	028E    50    POP
	028F    91    SWAP2
	0290    90    SWAP1
	0291    50    POP
	0292    56    *JUMP
	0293    5B    JUMPDEST
	0294    60    PUSH1 0x00
	0296    61    PUSH2 0x0204
	0299    82    DUP3
	029A    61    PUSH2 0x020b
	029D    56    *JUMP
	029E    5B    JUMPDEST
	029F    90    SWAP1
	02A0    50    POP
	02A1    91    SWAP2
	02A2    90    SWAP1
	02A3    50    POP
	02A4    56    *JUMP
	02A5    5B    JUMPDEST
	02A6    60    PUSH1 0x00
	02A8    61    PUSH2 0x0216
	02AB    82    DUP3
	02AC    61    PUSH2 0x01bd
	02AF    56    *JUMP
	02B0    5B    JUMPDEST
	02B1    90    SWAP1
	02B2    50    POP
	02B3    91    SWAP2
	02B4    90    SWAP1
	02B5    50    POP
	02B6    56    *JUMP
	02B7    5B    JUMPDEST
	02B8    60    PUSH1 0x00
	02BA    80    DUP1
	02BB    FD    *REVERT
	02BC    5B    JUMPDEST
	02BD    61    PUSH2 0x022b
	02C0    81    DUP2
	02C1    61    PUSH2 0x01dd
	02C4    56    *JUMP
	02C5    5B    JUMPDEST
	02C6    81    DUP2
	02C7    14    EQ
	02C8    61    PUSH2 0x0236
	02CB    57    *JUMPI
	02CC    60    PUSH1 0x00
	02CE    80    DUP1
	02CF    FD    *REVERT
	02D0    5B    JUMPDEST
	02D1    50    POP
	02D2    56    *JUMP
	02D3    FE    *ASSERT
	02D4    A2    LOG2
	02D5    64    PUSH5 0x6970667358
	02DB    22    22
	02DC    12    SLT
	02DD    20    SHA3
	02DE    80    DUP1
	02DF    5A    GAS
	02E0    DE    DE
	02E1    C1    C1
	02E2    15    ISZERO
	02E3    20    SHA3
	02E4    D7    D7
	02E5    04    DIV
	02E6    D5    D5
	02E7    D3    D3
	02E8    4F    4F
	02E9    B1    DUP
	02EA    F0    CREATE
	02EB    C9    C9
	02EC    34    CALLVALUE
	02ED    40    BLOCKHASH
	02EE    E7    E7
	02EF    F2    CALLCODE
	02F0    7D    PUSH30 0x4750694193f4b41eff432b08a864736f6c63430008070033608060405234
-----------------------------	
	从这里开始出毛病了 
	这里应该截断到 33 
	然后 6080 这边是 下面这四个命令, 漏掉了.

			60  PUSH1 0x80
			60  PUSH1 0x40
			52  MSTORE
			34  CALLVALUE
-----------------------------			
	030F    80    DUP1
	0310    15    ISZERO
	0311    61    PUSH2 0x0010
	0314    57    *JUMPI
	0315    60    PUSH1 0x00
	0317    80    DUP1
	0318    FD    *REVERT
	0319    5B    JUMPDEST
	031A    50    POP
	031B    61    PUSH2 0x0133
	031E    80    DUP1
	031F    61    PUSH2 0x0020
	0322    60    PUSH1 0x00
	0324    39    CODECOPY
	0325    60    PUSH1 0x00
	0327    F3    *RETURN
	0328    FE    *ASSERT
	0329    60    PUSH1 0x80
	032B    60    PUSH1 0x40
	032D    52    MSTORE
	032E    34    CALLVALUE
	032F    80    DUP1
	0330    15    ISZERO
	0331    60    PUSH1 0x0f
	0333    57    *JUMPI
	0334    60    PUSH1 0x00
	0336    80    DUP1
	0337    FD    *REVERT
	0338    5B    JUMPDEST
	0339    50    POP
	033A    60    PUSH1 0x04
	033C    36    CALLDATASIZE
	033D    10    LT
	033E    60    PUSH1 0x32
	0340    57    *JUMPI
	0341    60    PUSH1 0x00
	0343    35    CALLDATALOAD
	0344    60    PUSH1 0xe0
	0346    1C    SHR
	0347    80    DUP1
	0348    63    PUSH4 0x3fa4f245
	034D    14    EQ
	034E    60    PUSH1 0x37
	0350    57    *JUMPI
	0351    80    DUP1
	0352    63    PUSH4 0x55241077
	0357    14    EQ
	0358    60    PUSH1 0x51
	035A    57    *JUMPI
	035B    5B    JUMPDEST
	035C    60    PUSH1 0x00
	035E    80    DUP1
	035F    FD    *REVERT
	0360    5B    JUMPDEST
	0361    60    PUSH1 0x3d
	0363    60    PUSH1 0x69
	0365    56    *JUMP
	0366    5B    JUMPDEST
	0367    60    PUSH1 0x40
	0369    51    MLOAD
	036A    60    PUSH1 0x48
	036C    91    SWAP2
	036D    90    SWAP1
	036E    60    PUSH1 0xc1
	0370    56    *JUMP
	0371    5B    JUMPDEST
	0372    60    PUSH1 0x40
	0374    51    MLOAD
	0375    80    DUP1
	0376    91    SWAP2
	0377    03    SUB
	0378    90    SWAP1
	0379    F3    *RETURN
	037A    5B    JUMPDEST
	037B    60    PUSH1 0x67
	037D    60    PUSH1 0x04
	037F    80    DUP1
	0380    36    CALLDATASIZE
	0381    03    SUB
	0382    81    DUP2
	0383    01    ADD
	0384    90    SWAP1
	0385    60    PUSH1 0x63
	0387    91    SWAP2
	0388    90    SWAP1
	0389    60    PUSH1 0x8c
	038B    56    *JUMP
	038C    5B    JUMPDEST
	038D    60    PUSH1 0x6f
	038F    56    *JUMP
	0390    5B    JUMPDEST
	0391    00    *STOP
	0392    5B    JUMPDEST
	0393    60    PUSH1 0x00
	0395    54    SLOAD
	0396    81    DUP2
	0397    56    *JUMP
	0398    5B    JUMPDEST
	0399    80    DUP1
	039A    60    PUSH1 0x00
	039C    81    DUP2
	039D    90    SWAP1
	039E    55    SSTORE
	039F    50    POP
	03A0    50    POP
	03A1    56    *JUMP
	03A2    5B    JUMPDEST
	03A3    60    PUSH1 0x00
	03A5    81    DUP2
	03A6    35    CALLDATALOAD
	03A7    90    SWAP1
	03A8    50    POP
	03A9    60    PUSH1 0x86
	03AB    81    DUP2
	03AC    60    PUSH1 0xe9
	03AE    56    *JUMP
	03AF    5B    JUMPDEST
	03B0    92    SWAP3
	03B1    91    SWAP2
	03B2    50    POP
	03B3    50    POP
	03B4    56    *JUMP
	03B5    5B    JUMPDEST
	03B6    60    PUSH1 0x00
	03B8    60    PUSH1 0x20
	03BA    82    DUP3
	03BB    84    DUP5
	03BC    03    SUB
	03BD    12    SLT
	03BE    15    ISZERO
	03BF    60    PUSH1 0x9f
	03C1    57    *JUMPI
	03C2    60    PUSH1 0x9e
	03C4    60    PUSH1 0xe4
	03C6    56    *JUMP
	03C7    5B    JUMPDEST
	03C8    5B    JUMPDEST
	03C9    60    PUSH1 0x00
	03CB    60    PUSH1 0xab
	03CD    84    DUP5
	03CE    82    DUP3
	03CF    85    DUP6
	03D0    01    ADD
	03D1    60    PUSH1 0x79
	03D3    56    *JUMP
	03D4    5B    JUMPDEST
	03D5    91    SWAP2
	03D6    50    POP
	03D7    50    POP
	03D8    92    SWAP3
	03D9    91    SWAP2
	03DA    50    POP
	03DB    50    POP
	03DC    56    *JUMP
	03DD    5B    JUMPDEST
	03DE    60    PUSH1 0xbb
	03E0    81    DUP2
	03E1    60    PUSH1 0xda
	03E3    56    *JUMP
	03E4    5B    JUMPDEST
	03E5    82    DUP3
	03E6    52    MSTORE
	03E7    50    POP
	03E8    50    POP
	03E9    56    *JUMP
	03EA    5B    JUMPDEST
	03EB    60    PUSH1 0x00
	03ED    60    PUSH1 0x20
	03EF    82    DUP3
	03F0    01    ADD
	03F1    90    SWAP1
	03F2    50    POP
	03F3    60    PUSH1 0xd4
	03F5    60    PUSH1 0x00
	03F7    83    DUP4
	03F8    01    ADD
	03F9    84    DUP5
	03FA    60    PUSH1 0xb4
	03FC    56    *JUMP
	03FD    5B    JUMPDEST
	03FE    92    SWAP3
	03FF    91    SWAP2
	0400    50    POP
	0401    50    POP
	0402    56    *JUMP
	0403    5B    JUMPDEST
	0404    60    PUSH1 0x00
	0406    81    DUP2
	0407    90    SWAP1
	0408    50    POP
	0409    91    SWAP2
	040A    90    SWAP1
	040B    50    POP
	040C    56    *JUMP
	040D    5B    JUMPDEST
	040E    60    PUSH1 0x00
	0410    80    DUP1
	0411    FD    *REVERT
	0412    5B    JUMPDEST
	0413    60    PUSH1 0xf0
	0415    81    DUP2
	0416    60    PUSH1 0xda
	0418    56    *JUMP
	0419    5B    JUMPDEST
	041A    81    DUP2
	041B    14    EQ
	041C    60    PUSH1 0xfa
	041E    57    *JUMPI
	041F    60    PUSH1 0x00
	0421    80    DUP1
	0422    FD    *REVERT
	0423    5B    JUMPDEST
	0424    50    POP
	0425    56    *JUMP
	0426    FE    *ASSERT
	0427    A2    LOG2
	0428    64    PUSH5 0x6970667358
	042E    22    22
	042F    12    SLT
	0430    20    SHA3
	0431    64    PUSH5 0xd23f3d8847
	0437    AF    AF
	0438    28    28
	0439    51    MLOAD
	043A    8A    DUP11
	043B    21    21
	043C    CD    CD
	043D    DB    DB
	043E    45    GASLIMIT
	043F    44    DIFFICULTY
	0440    7E    PUSH31 0x81d7ac1a7f6e5750ff5366115fac955364736f6c63430008070033