import arbiter_test

def test_arbitration():
    print("=== TEST: Dual Core Memory Arbitration (Adaptive) ===")
    tb = arbiter_test.ArbiterTester()
    
    # Setup Memory
    tb.write_ram_direct(0x1000, 0xDEADBEEF)
    tb.write_ram_direct(0x2000, 0xCAFEBABE)
    
    print("Step 1: Simultaneous Read Request")
    tb.set_req_0(True, 0, 0x1000, 1) # Read
    tb.set_req_1(True, 0, 0x2000, 1) # Read
    
    # Cycle 1: Arbitration Decision
    tb.step()
    
    # Cycle 2: Execution of Winner
    tb.step()
    ack0 = tb.get_ack(0)
    ack1 = tb.get_ack(1)
    print(f"Cycle 2: Ack0={ack0}, Ack1={ack1}")
    
    # Check Mutual Exclusion
    if ack0 and ack1:
        print("FAIL: Mutual exclusion violation! Both ACKed.")
        exit(1)
    if not ack0 and not ack1:
        print("FAIL: Starvation! No one ACKed.")
        exit(1)
        
    # Identify Winner
    winner = 0 if ack0 else 1
    loser = 1 - winner
    print(f"-> Winner is Core {winner}")
    
    # Verify Winner Data
    val = tb.get_client_data(winner, 0)
    expected = 0xDEADBEEF if winner == 0 else 0xCAFEBABE
    if val != expected:
        print(f"FAIL: Core {winner} read wrong data: {hex(val)}")
        exit(1)

    print(f"Step 2: Releasing Core {winner}, checking Core {loser}")
    # Release Winner Request
    if winner == 0: tb.set_req_0(False, 0, 0, 0)
    else: tb.set_req_1(False, 0, 0, 0)
    
    # Cycle 3: Arbitration Decision for Loser
    tb.step()
    
    # Cycle 4: Execution for Loser
    tb.step()
    ack_loser = tb.get_ack(loser)
    print(f"Cycle 4: Ack{loser}={ack_loser}")
    
    if not ack_loser:
        print(f"FAIL: Fairness violation! Core {loser} should be serviced now.")
        exit(1)
        
    # Verify Loser Data
    val_l = tb.get_client_data(loser, 0)
    expected_l = 0xDEADBEEF if loser == 0 else 0xCAFEBABE
    if val_l != expected_l:
        print(f"FAIL: Core {loser} read wrong data: {hex(val_l)}")
        exit(1)
        
    print("PASS: Arbitration (Mutex + Fairness) verified.")

if __name__ == "__main__":
    test_arbitration()
