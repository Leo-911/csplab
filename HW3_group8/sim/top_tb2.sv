`timescale 1ns/10ps
`define CYCLE 1.4
`define MAX   100000 // default max cycle

`ifdef SYN
  `include "top_syn.v"
  `include "/usr/cad/CBDK/Executable_Package/Collaterals/IP/stdcell/N16ADFP_StdCell/VERILOG/N16ADFP_StdCell.v"
`else
  `include "top.sv"
`endif

module tb_top;

  // ===== 偵錯選項 =====
  parameter bit STOP_ON_FIRST_ERR = 1;   // 1=第一個錯就停；0=全部跑完統計

  // ===== DUT 參數（與輸出寬度無關）=====
  parameter INT_BITS       = 1;     // r: Q1.15
  parameter FRAC_BITS      = 15;
  parameter RHO_INT_BITS   = 1;     // rho: Q1.7
  parameter RHO_FRAC_BITS  = 7;
  parameter N              = 256;
  parameter L              = 16;

  // ===== 需要的窗口數 (每個長度 2N+L, 步長 N) =====
  localparam int K_WINDOWS = 100;

  localparam IN_WIDTH  = INT_BITS + FRAC_BITS;          // 16
  localparam RHO_WIDTH = RHO_INT_BITS + RHO_FRAC_BITS;  // 8
  // 連續輸入長度：T_req = (K-1)*N + (2N+L) = (K+1)N + L
  localparam SAMPLES   = (K_WINDOWS+1)*N + L;

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
  localparam EPS_DUT_FRAC  = 20;     // 以 Q20 解讀

  // ===== 容差設定 =====
  localparam THETA_TOL_SAM    = 0;        // theta 容差（樣本）—要求完全一致
  localparam real REL_ERR_TOL = 0.05;     // epsilon 相對誤差容許 (=5%)

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

  // ===== cycle counter & max-cycle watchdog =====
  integer unsigned cycle_cnt;
  integer unsigned max_cycle;
  reg              done;        // 全部 K 次 out_valid 完成才置 1
  integer unsigned done_cycle;  // 第 K 次 out_valid 時刻的 cycle

  // ASCII 圖檔名（可用 +pass_art=、+fail_art= 覆蓋）
  string pass_art_fname, fail_art_fname;

  initial begin
    cycle_cnt  = 0;
    max_cycle  = `MAX;
    done       = 1'b0;
    done_cycle = 0;

    pass_art_fname = "pass_art.txt";
    fail_art_fname = "fail_art.txt";
    void'($value$plusargs("max_cycle=%d", max_cycle));      // 可用 +max_cycle=
    void'($value$plusargs("pass_art=%s", pass_art_fname));  // 可用 +pass_art=
    void'($value$plusargs("fail_art=%s", fail_art_fname));  // 可用 +fail_art=

    $display("[TB] CYCLE=%.3f ns, MAX_CYCLE=%0d, K=%0d, SAMPLES=%0d",
             `CYCLE, max_cycle, K_WINDOWS, SAMPLES);
    $display("[TB] PASS_ART=%s  FAIL_ART=%s", pass_art_fname, fail_art_fname);
  end
  always @(posedge clk) if (!rst && !done) cycle_cnt <= cycle_cnt + 1;

  // ===== DUT I/O =====
  reg                               in_valid;
  reg  signed [IN_WIDTH-1:0]        rx_re_in, rx_img_in;
  reg         [RHO_WIDTH-1:0]       rho;
  wire        [7:0]                 theta;
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
  reg [RHO_FILE_WIDTH-1:0]   rho_mem    [0:0];                 // 1 行（常數 rho）
  reg [EPS_FILE_WIDTH-1:0]   eps_mem    [0:K_WINDOWS-1];       // K 行
  reg [THETA_FILE_WIDTH-1:0] theta_mem  [0:K_WINDOWS-1];       // K 行

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

  // ===== 工具 =====
  function automatic longint unsigned abs64(input longint signed x);
    abs64 = (x >= 0) ? longint'(x) : longint'(-x);
  endfunction
  function automatic real q_to_real(input longint signed q, input int frac);
    q_to_real = q / real'(1 << frac);
  endfunction

  // 讀並印 ASCII 檔案的小工具
  task automatic print_ascii(input string fname);
    integer fd;
    string line;
    fd = $fopen(fname, "r");
    if (fd == 0) begin
      $display("[TB][WARN] ASCII file '%s' not found. Skip.", fname);
    end
    else begin
      while (!$feof(fd)) begin
        line = "";
        void'($fgets(line, fd));
        $write("%s", line);
      end
      $fclose(fd);
    end
  endtask

  // ===== 驅動/比對狀態 =====
  integer samp_idx;
  integer out_cnt;       // out_valid 次數（應該要到 K）
  integer err_eps_cnt;   // eps 錯誤總次數
  integer err_th_cnt;    // theta 錯誤總次數
  integer cmp_idx;       // 目前要比第幾行 0..K-1

  // 64-bit 暫存
  reg  signed [63:0] dut_eps_q64, ref_eps_q64, ref_eps_al64;
  reg  [63:0]        dut_th_u64,  ref_th_u64,  th_abs_u64;

  // 浮點顯示
  real dut_eps_real, ref_eps_real;

  // 比對用變數
  longint unsigned num_abs;     // |DUT-REF|
  longint unsigned den_abs;     // |REF|
  real             rel_err_pct; // 百分比誤差（顯示與判斷）

  // ===== 初始化 =====
  initial begin
    in_valid   = 1'b0;
    rx_re_in   = '0;
    rx_img_in  = '0;
    rho        = '0;
    samp_idx   = 0;
    out_cnt    = 0;
    err_eps_cnt= 0;
    err_th_cnt = 0;
    cmp_idx    = 0;

    @(negedge rst);
    @(posedge clk);
    in_valid <= 1'b1;
  end

  // ===== 資料送入 =====
  always @(negedge clk) begin
    if (!rst && in_valid) begin
      rx_re_in  <= r_re_mem[samp_idx][IN_WIDTH-1:0];
      rx_img_in <= r_im_mem[samp_idx][IN_WIDTH-1:0];
      rho       <= rho_mem[0][RHO_WIDTH-1:0]; // 檔案只有 1 行就一直用同一個 rho

      samp_idx <= samp_idx + 1;
      if (samp_idx >= SAMPLES) begin // >= 避免界外
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
        $display("\n\n====================== SIMULATION FAIL ======================\n");
          print_ascii($sformatf("%s/fail_art.txt", prog_path));
          $display("\n=============================================================");
          $display("        Simulation FAILED!!  Cycles: %0d", done_cycle);
          $display("=============================================================\n");
        $display("\n[TB][TIMEOUT] Reached MAX_CYCLE=%0d (%.3f us). 第 %0d/%0d 個 out_valid 未完成，判定 FAIL.",
                 max_cycle, max_cycle*`CYCLE/1000.0, out_cnt, K_WINDOWS);
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

  // ===== 正緣比答案：連續比對 K 次 =====
  always @(posedge clk) begin
    // 任何時刻 out_valid 不能是 X/Z
    if (!rst && $isunknown(out_valid))
      $fatal(1, "[TB][X] out_valid is X/Z at cycle %0d", cycle_cnt);

    if (!rst && out_valid) begin
      // 當 out_valid=1 時，輸出內容不得有 X/Z
      if ($isunknown(theta))   $fatal(1, "[TB][X] theta is X/Z at cycle %0d", cycle_cnt);
      if ($isunknown(epsilon)) $fatal(1, "[TB][X] epsilon is X/Z at cycle %0d", cycle_cnt);

      // 取第 cmp_idx 行 golden（0..K-1）
      ref_eps_q64 = {{(64-EPS_FILE_WIDTH){eps_mem[cmp_idx][EPS_FILE_WIDTH-1]}}, eps_mem[cmp_idx]};
      dut_eps_q64 = {{(64-EPS_DUT_WIDTH){epsilon[EPS_DUT_WIDTH-1]}},            epsilon};

      // Q 對齊到 DUT 小數位
      if (EPS_DUT_FRAC > EPS_FILE_FRAC)
        ref_eps_al64 = ref_eps_q64 <<< (EPS_DUT_FRAC - EPS_FILE_FRAC);
      else if (EPS_DUT_FRAC < EPS_FILE_FRAC)
        ref_eps_al64 = ref_eps_q64 >>> (EPS_FILE_FRAC - EPS_DUT_FRAC);
      else
        ref_eps_al64 = ref_eps_q64;

      // 定點整數域相對百分比誤差
      num_abs     = abs64(dut_eps_q64 - ref_eps_al64); // |DUT-REF|
      den_abs     = abs64(ref_eps_al64);               // |REF|
      if (den_abs == 0)
        rel_err_pct = (num_abs == 0) ? 0.0 : 100.0;
      else
        rel_err_pct = (100.0 * num_abs) / den_abs;

      // 浮點顯示
      dut_eps_real = q_to_real(dut_eps_q64, EPS_DUT_FRAC);
      ref_eps_real = q_to_real(ref_eps_al64, EPS_DUT_FRAC);

      $display("----------------------------------------------------------------");
      $display("[EPSILON #%0d/%0d] relative_error = %.3f%% (tol=%.2f%%)", 
               cmp_idx, K_WINDOWS-1, rel_err_pct, REL_ERR_TOL*100.0);
      $display("          DUT eps  (Q1.%0d) = %0d (0x%0h)  -> %.8f",
               EPS_DUT_FRAC, $signed(dut_eps_q64), dut_eps_q64[EPS_DUT_WIDTH-1:0], dut_eps_real);
      $display("          REF eps  (Q1.%0d) = %0d (0x%0h)  -> %.8f",
               EPS_DUT_FRAC, $signed(ref_eps_al64), ref_eps_al64[EPS_DUT_WIDTH-1:0], ref_eps_real);

      // === theta：只看差多少（線性差 |dut-ref|）===
      dut_th_u64 = {{(64-THETA_FILE_WIDTH){1'b0}}, theta};
      ref_th_u64 = {{(64-THETA_FILE_WIDTH){1'b0}}, theta_mem[cmp_idx]};
      th_abs_u64 = (dut_th_u64 >= ref_th_u64) ? (dut_th_u64 - ref_th_u64)
                                              : (ref_th_u64 - dut_th_u64);

      $display("[ THETA  #%0d/%0d] |dut-ref| = %0d samp   dut=%0d ref=%0d\n",
               cmp_idx, K_WINDOWS-1, th_abs_u64[31:0], dut_th_u64[7:0], ref_th_u64[7:0]);

      // ===== 容差判斷（本次）+ 第一個錯立即終止 =====
      if (rel_err_pct > (REL_ERR_TOL*100.0)) begin
        if (STOP_ON_FIRST_ERR) begin
          $display("\n\n====================== SIMULATION FAIL ======================\n");
          print_ascii($sformatf("%s/fail_art.txt", prog_path));
          $display("\n=============================================================");
          $display("        Simulation FAILED!!  Cycles: %0d", done_cycle);
          $display("=============================================================\n");
          $display("❌ [EPSILON #%0d] relative_error %.3f%% > %.2f%%",
                   cmp_idx, rel_err_pct, REL_ERR_TOL*100.0);
          $fatal(1, "Stop on first epsilon error at window #%0d", cmp_idx);
        end
        else begin
          err_eps_cnt = err_eps_cnt + 1;
        end
      end

      if (th_abs_u64 > THETA_TOL_SAM) begin
        if (STOP_ON_FIRST_ERR) begin
          $display("\n\n====================== SIMULATION FAIL ======================\n");
          print_ascii($sformatf("%s/fail_art.txt", prog_path));
          $display("\n=============================================================");
          $display("        Simulation FAILED!!  Cycles: %0d", done_cycle);
          $display("=============================================================\n");
          $display("❌ [THETA   #%0d] mismatch: |dut-ref|=%0d  dut=%0d ref=%0d",
                   cmp_idx, th_abs_u64[31:0], dut_th_u64[7:0], ref_th_u64[7:0]);
          $fatal(1, "Stop on first theta error at window #%0d", cmp_idx);
        end
        else begin
          err_th_cnt = err_th_cnt + 1;
        end
      end

      out_cnt = out_cnt + 1;

      // 走到最後一個就收尾
      if (cmp_idx == K_WINDOWS-1) begin
        if (!done) begin
          done       <= 1'b1;
          done_cycle <= cycle_cnt;
        end

        #1;
        repeat (8) @(posedge clk);
        $display("SUMMARY (K=%0d): out_valid_count=%0d  eps_err_total=%0d  theta_err_total=%0d",
                 K_WINDOWS, out_cnt, err_eps_cnt, err_th_cnt);

        if ((err_eps_cnt==0) && (err_th_cnt==0)) begin
          $display("\n\n====================== SIMULATION PASS ======================\n");
          print_ascii( $sformatf("%s/pass_art.txt", prog_path) );
          $display("\n=============================================================");
          $display("        Simulation PASS!!  Cycles: %0d", done_cycle);
          $display("=============================================================\n");
        end else begin
          $display("\n\n====================== SIMULATION FAIL ======================\n");
          print_ascii($sformatf("%s/fail_art.txt", prog_path));
          $display("\n=============================================================");
          $display("        Simulation FAILED!!  Cycles: %0d", done_cycle);
          $display("=============================================================\n");
        end
        $finish;
      end
      else begin
        cmp_idx <= cmp_idx + 1;
      end
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
