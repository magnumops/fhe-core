#ifndef ISA_SPEC_H
#define ISA_SPEC_H

// --- OPCODES ---
#define OPC_HALT      0x00
#define OPC_CTX       0x01  // Set Context (Q, MU...)
#define OPC_LOAD      0x02  // DMA Read: Host -> Slot
#define OPC_STORE     0x03  // DMA Write: Slot -> Host
#define OPC_NTT       0x10  // Run NTT on Slot
#define OPC_INTT      0x11  // Run INTT on Slot

// --- CONSTANTS ---
#define NUM_SLOTS     4
#define SLOT_SIZE     4096

#endif
