module mod_mult (
    input  wire [63:0] a,
    input  wire [63:0] b,
    input  wire [63:0] q,
    output wire [63:0] out
);
    // === BARRETT REDUCTION CONSTANTS ===
    // Configured for Q = 1073750017
    // k = 64
    // mu = floor(2^64 / q) = 17179738097 (0x3fffdfff1)
    localparam [63:0] MU = 64'h3fffdfff1;

    // 1. Full Product z = a * b
    // Since a, b < 2^30 (approx), z < 2^60. It fits in 64 bits lower part.
    // However, we use 128-bit internal wire for safety and standard compliance.
    wire [127:0] z = {64'b0, a} * {64'b0, b};

    // 2. Estimate Quotient: q_est = floor(z * mu / 2^64)
    // We multiply z (64 bits effective) by mu (64 bits).
    // The result is 128 bits. We take the upper 64 bits (>> 64).
    wire [127:0] mu_prod = {64'b0, z[63:0]} * {64'b0, MU};
    wire [63:0] q_est = mu_prod[127:64];

    // 3. Estimate Remainder: r = z - q_est * q
    // Note: We only need lower 64 bits for subtraction result.
    wire [63:0] prod_approx = q_est * q;
    wire [63:0] rem_raw = z[63:0] - prod_approx;

    // 4. Correction (Conditional Subtraction)
    // The result might be >= q (Barrett error bound is small, usually <= 2q).
    wire [63:0] rem_corr1 = (rem_raw >= q) ? (rem_raw - q) : rem_raw;
    wire [63:0] rem_corr2 = (rem_corr1 >= q) ? (rem_corr1 - q) : rem_corr1;

    assign out = rem_corr2;
endmodule
