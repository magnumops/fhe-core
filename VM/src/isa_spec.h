#ifndef ISA_SPEC_H
#define ISA_SPEC_H

#define OPC_HALT      0x00
#define OPC_CTX       0x01
#define OPC_LOAD      0x02
#define OPC_STORE     0x03
#define OPC_LOAD_W    0x04
#define OPC_NTT       0x10
#define OPC_INTT      0x11

// ALU Ops: Target = Target OP Source
#define OPC_ADD       0x20 
#define OPC_SUB       0x21
#define OPC_MULT      0x22

#define NUM_SLOTS     4
#define SLOT_SIZE     4096
#define W_SIZE        8192

#endif
