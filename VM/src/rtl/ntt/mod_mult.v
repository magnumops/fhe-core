module mod_mult (
    input  wire [63:0] a,
    input  wire [63:0] b,
    input  wire [63:0] q,
    input  wire [63:0] mu, // NEW: Dynamic Barrett Constant
    output wire [63:0] out
);
    // 1. Full Product z = a * b
    wire [127:0] z = {64'b0, a} * {64'b0, b};

    // 2. Estimate Quotient: q_est = floor(z * mu / 2^64)
    wire [127:0] mu_prod = {64'b0, z[63:0]} * {64'b0, mu};
    wire [63:0] q_est = mu_prod[127:64];

    // 3. Estimate Remainder: r = z - q_est * q
    wire [63:0] prod_approx = q_est * q;
    wire [63:0] rem_raw = z[63:0] - prod_approx;

    // 4. Correction
    wire [63:0] rem_corr1 = (rem_raw >= q) ? (rem_raw - q) : rem_raw;
    wire [63:0] rem_corr2 = (rem_corr1 >= q) ? (rem_corr1 - q) : rem_corr1;

    assign out = rem_corr2;
endmodule
