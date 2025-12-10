import sys
sys.path.append("/app/build")
import logos_emu

print("--- API INTROSPECTION ---")
emu = logos_emu.LogosContext()
print(f"Object methods: {dir(emu)}")
