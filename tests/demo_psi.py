import sys
sys.path.append('build')
sys.path.append('tests')
from logos_sdk import LogosAccelerator, load_bin

def run_psi_demo():
    print("\n=== LOGOS FHE: PRIVATE SET INTERSECTION DEMO ===")
    print("Algorithm: Difference Square. Match if (A - B)^2 == 0")
    
    # 1. Load Data
    try:
        alice = load_bin("psi_vec_a.bin")
        bob   = load_bin("psi_vec_b.bin")
        cfg   = load_bin("config_math.bin")
    except:
        print("Run seal_exporter first!")
        return

    # 2. Init SDK
    accel = LogosAccelerator(modulus=cfg[0])
    
    # 3. Operations
    accel.load_vector(alice, slot=0) # Alice to Slot 0
    accel.load_vector(bob,   slot=1) # Bob to Slot 1
    
    accel.subtract() # Slot0 = Alice - Bob
    accel.square()   # Result = (Alice - Bob)^2
    
    # 4. Analyze Results
    results = accel.read_result(len(alice))
    
    print("\n--- PSI RESULTS ---")
    matches = []
    # Check first 20 elements for visual demo
    for i in range(20):
        is_match = (results[i] == 0)
        marker = "MATCH!" if is_match else "."
        if is_match: matches.append(alice[i])
        print(f"Idx {i}: Alice={alice[i]}, Bob={bob[i]} -> DiffSq={results[i]}  {marker}")
        
    print(f"\nTotal Matches Found: {len([x for x in results if x == 0])}")
    print("Demo Completed Successfully.")

if __name__ == "__main__":
    run_psi_demo()
