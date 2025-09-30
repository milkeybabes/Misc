# Elite (BBC Micro) planet-name generator
# References:
# - Generating system names (two-letter tokens, name routine)
# - Twisting the system seeds (Tribonacci-style update)
# - Token table mapping 128..159 → digrams
# See Mark Moxon’s deep dives for the authoritative docs.

TOKENS = {
    128:"AL",129:"LE",130:"XE",131:"GE",132:"ZA",133:"CE",134:"BI",135:"SO",
    136:"US",137:"ES",138:"AR",139:"MA",140:"IN",141:"DI",142:"RE",143:"A",
    144:"ER",145:"AT",146:"EN",147:"BE",148:"RA",149:"LA",150:"VE",151:"TI",
    152:"ED",153:"OR",154:"QU",155:"AN",156:"TE",157:"IS",158:"RI",159:"ON",
}

def twist(s0, s1, s2):
    """Advance the 3×16-bit seeds one step."""
    return (s1 & 0xFFFF, s2 & 0xFFFF, ((s0 + s1 + s2) & 0xFFFF))

def name_from_seeds(s0, s1, s2):
    """Generate a system name from 3×16-bit seeds."""
    s0 &= 0xFFFF; s1 &= 0xFFFF; s2 &= 0xFFFF
    pairs = 4 if (s0 & 0x0040) else 3  # bit 6 of s0_lo
    out = []
    cur_s0, cur_s1, cur_s2 = s0, s1, s2
    for _ in range(pairs):
        s2_hi = (cur_s2 >> 8) & 0xFF
        idx = s2_hi & 0x1F
        if idx != 0:
            token_code = 128 + idx
            out.append(TOKENS[token_code])
        cur_s0, cur_s1, cur_s2 = twist(cur_s0, cur_s1, cur_s2)
    return "".join(out)

def next_system_seeds(s0, s1, s2):
    """Advance to the next system (4 twists)."""
    a, b, c = s0, s1, s2
    for _ in range(4):
        a, b, c = twist(a, b, c)
    return a, b, c

def rotate_left_byte(x):
    """Rotate one byte left."""
    x &= 0xFF
    return ((x << 1) & 0xFF) | (1 if (x & 0x80) else 0)

def galactic_hyperjump(s0, s1, s2):
    """Seeds for the next galaxy (ROL each byte)."""
    def rol16(v):
        lo = rotate_left_byte(v & 0xFF)
        hi = rotate_left_byte((v >> 8) & 0xFF)
        return (lo | (hi << 8)) & 0xFFFF
    return rol16(s0), rol16(s1), rol16(s2)

# ---- Main driver ----
# Starting seeds = Tibedied (galaxy 1 system 0)
S0, S1, S2 = 0x5A4A, 0x0248, 0xB753

for gal in range(1, 9):
    print(f"\n=== Galaxy {gal} ===")
    a, b, c = S0, S1, S2
    for sys in range(256):
        name = name_from_seeds(a, b, c)
        print(f"{sys:3}: {name}")
        a, b, c = next_system_seeds(a, b, c)
    # hyperjump to the next galaxy
    S0, S1, S2 = galactic_hyperjump(S0, S1, S2)
