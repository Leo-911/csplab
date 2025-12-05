`timescale 1ns/10ps
`define CYCLE 0.4
`define MAX   100000 // default max cycle

`ifdef SYN
  `include "top_syn.v"
  `include "/usr/cad/CBDK/Executable_Package/Collaterals/IP/stdcell/N16ADFP_StdCell/VERILOG/N16ADFP_StdCell.v"
`else
  `include "top.sv"
`endif

module tb_top;

  // ===== DUT 參數（與輸出寬度無關）=====
  parameter INT_BITS       = 1;     // r: Q1.15
  parameter FRAC_BITS      = 15;
  parameter RHO_INT_BITS   = 1;     // rho: Q1.7
  parameter RHO_FRAC_BITS  = 7;
  parameter N              = 256;
  parameter L              = 16;

  localparam IN_WIDTH  = INT_BITS + FRAC_BITS;          // 16
  localparam RHO_WIDTH = RHO_INT_BITS + RHO_FRAC_BITS;  // 8
  localparam SAMPLES   = 2*N + L;

  // ===== 測資 Q 格式（供齊位/讀檔）=====
  localparam R_FILE_WIDTH     = 16;  // r: Q1.15
  localparam R_FILE_FRAC      = 15;
  localparam RHO_FILE_WIDTH   = 8;   // rho: Q1.7
  localparam RHO_FILE_FRAC    = 7;
  localparam EPS_FILE_WIDTH   = 21;  // epsa: Q1.20 → 21-bit
  localparam EPS_FILE_FRAC    = 20;  // 小數 20
  localparam THETA_FILE_WIDTH = 8;   // 0..255

  // ===== DUT 輸出 Q 格式（依 top.sv）=====
  localparam EPS_DUT_WIDTH = 21;     // epsilon[20:0]
  localparam EPS_DUT_FRAC  = 20;     // 以 Q1.20 解讀

  // ===== 容差設定 =====
  localparam THETA_TOL_SAM     = 0;        // theta 容差（樣本）
  localparam real EPS_REL_TOL  = 0.05;     // epsilon 相對誤差 5%
  localparam longint unsigned EPS_DEN_FLOOR_INT = 1; // 分母下限 = 1 LSB (Q1.20)

  // ===== clock / reset =====
  reg clk, rst;
  initial begin
    clk = 1'b0;
    forever #(`CYCLE/2.0) clk = ~clk;
  end
  initial begin
    rst = 1'b1;
    repeat (5) @(posedge clk);
    rst = 1'b0;
  end

  // ===== cycle counter & watchdog =====
  integer unsigned cycle_cnt;
  integer unsigned max_cycle;
  reg              done;
  integer unsigned done_cycle;

  initial begin
    cycle_cnt = 0;
    max_cycle = `MAX;
    done      = 1'b0;
    done_cycle= 0;
    void'($value$plusargs("max_cycle=%d", max_cycle));
    $display("[TB] CYCLE=%.3f ns, MAX_CYCLE=%0d", `CYCLE, max_cycle);
  end
  always @(posedge clk) if (!rst && !done) cycle_cnt <= cycle_cnt + 1;

  // ===== DUT I/O =====
  reg                               in_valid;
  reg  signed [IN_WIDTH-1:0]        rx_re_in, rx_img_in;
  reg         [RHO_WIDTH-1:0]       rho;
  wire        [7:0]                 theta;     // 與 top.sv 對齊
  wire        [20:0]                epsilon;   // Q1.20
  wire                              out_valid;

  top #(
    .INT_BITS      (INT_BITS),
    .FRAC_BITS     (FRAC_BITS),
    .RHO_INT_BITS  (RHO_INT_BITS),
    .RHO_FRAC_BITS (RHO_FRAC_BITS)
  ) dut (
    .clk       (clk),
    .rst       (rst),
    .in_valid  (in_valid),
    .rx_re_in  (rx_re_in),
    .rx_img_in (rx_img_in),
    .rho       (rho),
    .theta     (theta),
    .epsilon   (epsilon),
    .out_valid (out_valid)
  );

  // ===== 讀檔 =====
  string prog_path;
  reg [R_FILE_WIDTH-1:0]     r_re_mem   [0:SAMPLES-1];
  reg [R_FILE_WIDTH-1:0]     r_im_mem   [0:SAMPLES-1];
  reg [RHO_FILE_WIDTH-1:0]   rho_mem    [0:0];
  reg [EPS_FILE_WIDTH-1:0]   eps_mem    [0:0];
  reg [THETA_FILE_WIDTH-1:0] theta_mem  [0:0];

  initial begin
    $value$plusargs("prog_path=%s", prog_path);
    if (prog_path.len() == 0) prog_path = ".";
    $display("[TB] prog_path = %s", prog_path);
    $readmemb({prog_path, "/dataset_r_real_bin.txt"},  r_re_mem);
    $readmemb({prog_path, "/dataset_r_imag_bin.txt"},  r_im_mem);
    $readmemb({prog_path, "/dataset_rho_bin.txt"},     rho_mem);
    $readmemb({prog_path, "/dataset_epsa_bin.txt"},    eps_mem);
    $readmemb({prog_path, "/dataset_theta_bin.txt"},   theta_mem);
  end

  // ===== 工具：Q → real（只作顯示用）=====
  function real q_to_real(input longint signed q, input int frac);
    q_to_real = q / real'(1 << frac);
  endfunction

  // ===== 工具：從檔案印 ASCII 藝術字 =====
  task automatic print_ascii(input string filepath);
    integer fd;
    string  line;
    fd = $fopen(filepath, "r");
    if (fd == 0) begin
      $display("[TB][WARN] Cannot open '%s' — skip ASCII art.", filepath);
      return;
    end
    while (!$feof(fd)) begin
      void'($fgets(line, fd));
      $write("%s", line); // 用 %s，避免檔內 % 被當格式字元
    end
    $fclose(fd);
  endtask

  // ===== 驅動/比對狀態 =====
  integer samp_idx;
  integer out_cnt, err_eps, err_th;

  // 暫存（跨 always）
  reg  signed [63:0] dut_eps_q64, ref_eps_q64, ref_eps_al64;
  reg  [63:0]        dut_th_u64,  ref_th_u64,  th_abs_u64;

  // 顯示用 real（只印）
  real dut_eps_real, ref_eps_real;

  // 整數域誤差
  longint unsigned eps_abs_diff_int, eps_abs_ref_int, eps_denom_int;
  real rel_percent; // 只用來列印百分比

  // 平均誤差（%）統計（real）
  real rel_percent_sum; integer rel_percent_cnt;

  // ===== 初始化 =====
  initial begin
    in_valid  = 1'b0;
    rx_re_in  = '0;
    rx_img_in = '0;
    rho       = '0;
    samp_idx  = 0;
    out_cnt   = 0;
    err_eps   = 0;
    err_th    = 0;

    rel_percent_sum = 0.0;
    rel_percent_cnt = 0;

    @(negedge rst);
    @(posedge clk);
    in_valid <= 1'b1;
  end

  // ===== 資料送入（無輸入 X/Z 檢查）=====
  always @(negedge clk) begin
    if (!rst && in_valid) begin
      rx_re_in  <= r_re_mem[samp_idx][IN_WIDTH-1:0];
      rx_img_in <= r_im_mem[samp_idx][IN_WIDTH-1:0];
      rho       <= rho_mem[0][RHO_WIDTH-1:0];

      samp_idx <= samp_idx + 1;
      if (samp_idx  >= SAMPLES) begin // 修正：>= 避免界外
        in_valid <= 1'b0;  // 送完
        samp_idx <= 0;
        rx_re_in  <= '0;
        rx_img_in <= '0;
        rho       <= '0;
      end
    end
  end

  // ===== MAX_CYCLE watchdog =====
  initial begin : WATCHDOG
    @(negedge rst);
    repeat (1) @(posedge clk);
    fork
      begin
        repeat (max_cycle) @(posedge clk);
        $display("\n[TB][TIMEOUT] Reached MAX_CYCLE=%0d. out_valid未出現或驗證未結束，判定 FAIL.",
                 max_cycle);
        // 印 FAIL 圖
        print_ascii($sformatf("%s/fail_art.txt", prog_path));
        $finish(2);
      end
      begin : EXIT_ON_DONE
        wait(done === 1'b1);
        disable WATCHDOG;
      end
    join_any
    disable fork;
  end

  // ===== SV Assertions: 只檢輸出 X/Z =====
  property p_no_x_outvalid; @(posedge clk) disable iff (rst) !$isunknown(out_valid); endproperty
  property p_no_x_outputs;  @(posedge clk) disable iff (rst) out_valid |-> (!$isunknown(theta) && !$isunknown(epsilon)); endproperty
  assert property (p_no_x_outvalid) else $fatal(1, "[TB][X] out_valid X/Z");
  assert property (p_no_x_outputs)  else $fatal(1, "[TB][X] outputs X/Z when valid");

  // ===== 正緣比答案：整數域比對，僅列印時轉浮點 =====
  always @(posedge clk) begin
    // 任何時刻 out_valid 不能 X/Z
    if (!rst && $isunknown(out_valid))
      $fatal(1, "[TB][X] out_valid is X/Z at cycle %0d", cycle_cnt);

    if (!rst && out_valid) begin
      // 當 out_valid=1 時，輸出內容不得有 X/Z
      if ($isunknown(theta))   $fatal(1, "[TB][X] theta is X/Z at cycle %0d", cycle_cnt);
      if ($isunknown(epsilon)) $fatal(1, "[TB][X] epsilon is X/Z at cycle %0d", cycle_cnt);

      out_cnt <= out_cnt + 1;
      if (!done) begin
        done       <= 1'b1;
        done_cycle <= cycle_cnt;
      end

      // sign-extend & Q 對齊到 DUT 的小數位（Q1.20）
      ref_eps_q64 = {{(64-EPS_FILE_WIDTH){eps_mem[0][EPS_FILE_WIDTH-1]}}, eps_mem[0]};
      dut_eps_q64 = {{(64-EPS_DUT_WIDTH){epsilon[EPS_DUT_WIDTH-1]}},      epsilon};

      if (EPS_DUT_FRAC > EPS_FILE_FRAC)
        ref_eps_al64 = ref_eps_q64 <<< (EPS_DUT_FRAC - EPS_FILE_FRAC);
      else if (EPS_DUT_FRAC < EPS_FILE_FRAC)
        ref_eps_al64 = ref_eps_q64 >>> (EPS_FILE_FRAC - EPS_DUT_FRAC);
      else
        ref_eps_al64 = ref_eps_q64;

      // === 整數域：|diff|、|ref| ===
      eps_abs_diff_int = (dut_eps_q64 >= ref_eps_al64) ?
                         (dut_eps_q64 - ref_eps_al64)  :
                         (ref_eps_al64 - dut_eps_q64);

      if (ref_eps_al64[63] == 1'b1) eps_abs_ref_int = -ref_eps_al64;
      else                          eps_abs_ref_int =  ref_eps_al64;

      eps_denom_int = (eps_abs_ref_int > EPS_DEN_FLOOR_INT) ? eps_abs_ref_int
                                                            : EPS_DEN_FLOOR_INT;

      rel_percent = (100.0 * eps_abs_diff_int) / (1.0 * eps_denom_int);

      if ( (eps_abs_ref_int == 0 && eps_abs_diff_int != 0) ||
           ((100.0 * eps_abs_diff_int) / (1.0 * eps_denom_int) > (EPS_REL_TOL * 100.0)) )
        err_eps = err_eps + 1;

      // theta（樣本差）
      dut_th_u64 = {{(64-THETA_FILE_WIDTH){1'b0}}, theta};
      ref_th_u64 = {{(64-THETA_FILE_WIDTH){1'b0}}, theta_mem[0]};
      th_abs_u64 = (dut_th_u64 >= ref_th_u64) ? (dut_th_u64 - ref_th_u64)
                                              : (ref_th_u64 - dut_th_u64);
      if (th_abs_u64 > THETA_TOL_SAM) err_th = err_th + 1;

      // === 顯示（定點十進位/十六進位 + 浮點）===
      dut_eps_real = q_to_real(dut_eps_q64, EPS_DUT_FRAC);
      ref_eps_real = q_to_real(ref_eps_al64, EPS_DUT_FRAC);

      $display("----------------------------------------------------------------");
      $display("[EPSILON] relative_error = %.3f%% (tolerance=%.2f%%)", rel_percent, EPS_REL_TOL*100.0);
      $display("      DUT eps  (Q1.%0d) = %0d (0x%0h)  -> %.8f",
               EPS_DUT_FRAC, dut_eps_q64, dut_eps_q64[EPS_DUT_WIDTH-1:0], dut_eps_real);
      $display("      REF eps  (Q1.%0d) = %0d (0x%0h)  -> %.8f",
               EPS_DUT_FRAC, ref_eps_al64, ref_eps_al64[EPS_DUT_WIDTH-1:0], ref_eps_real);
      $display("[ THETA ] |dut-ref| = %0d samp   dut=%0d  ref=%0d",
               th_abs_u64[31:0], dut_th_u64[7:0], ref_th_u64[7:0]);

      // 累積平均誤差（%）供摘要
      rel_percent_sum = rel_percent_sum + rel_percent;
      rel_percent_cnt = rel_percent_cnt + 1;

      // 收尾/摘要
      #1;
      repeat (8) @(posedge clk);
      $display("SUMMARY: out_valid=%0d eps_err=%0d theta_err=%0d ",
               out_cnt, err_eps, err_th);

      if ((out_cnt>0) && (err_eps==0) && (err_th==0)) begin
        $display("\n\n====================== SIMULATION PASS ======================\n");
        print_ascii($sformatf("%s/pass_art.txt", prog_path));
        $display("\n=============================================================");
        $display("        Simulation PASS!!  Cycles: %0d\n", done_cycle);
        $display("=============================================================\n");
      end else begin
        $display("\n\n====================== SIMULATION FAIL ======================\n");
        print_ascii($sformatf("%s/fail_art.txt", prog_path));
        $display("\n=============================================================");
        $display("        Simulation FAILED!!  Cycles: %0d\n", done_cycle);
        $display("=============================================================\n");
      end

      $finish;
    end
  end

  `ifdef SYN
    initial $sdf_annotate("../syn/top_syn.sdf", dut);
  `endif

  // ===== FSDB（可移除）=====
  initial begin
    $fsdbDumpfile("top.fsdb");
    $fsdbDumpvars(0, "+mda", tb_top);
    $fsdbDumpvars(0, tb_top);
  end

endmodule
