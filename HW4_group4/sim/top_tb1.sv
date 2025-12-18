`timescale 1ns/10ps
`define CYCLE 2
`define MAX   100000 // default max cycle

`ifdef SYN
`include "CHIP_syn.v"
`timescale 1ns/10ps
`include "/usr/cad/CBDK/Executable_Package/Collaterals/IP/stdcell/N16ADFP_StdCell/VERILOG/N16ADFP_StdCell.v"
`include "/usr/cad/CBDK/Executable_Package/Collaterals/IP/stdio/N16ADFP_StdIO/VERILOG/N16ADFP_StdIO.v"
`elsif PR
`include "../pr/run/output/CHIP_pr.v"
`timescale 1ns/10ps
`include "/usr/cad/CBDK/Executable_Package/Collaterals/IP/stdcell/N16ADFP_StdCell/VERILOG/N16ADFP_StdCell.v"
`include "/usr/cad/CBDK/Executable_Package/Collaterals/IP/stdio/N16ADFP_StdIO/VERILOG/N16ADFP_StdIO.v"
`else
//`include "top.sv"
`include "/usr/cad/CBDK/Executable_Package/Collaterals/IP/stdio/N16ADFP_StdIO/VERILOG/N16ADFP_StdIO.v"
`include "CHIP.v"
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
  localparam SAMPLES   = 3*N + L;                       // 3N+L

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
  localparam THETA_TOL_SAM    = 0;        // theta 容差（樣本）
  localparam real REL_ERR_TOL = 0.05;     // relative error tolerance (=5%)

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
  reg              done;        // 第二次 out_valid 後才置 1
  integer unsigned done_cycle;  // 第二次 out_valid 時刻的 cycle

  initial begin
    cycle_cnt  = 0;
    max_cycle  = `MAX;
    done       = 1'b0;
    done_cycle = 0;
    void'($value$plusargs("max_cycle=%d", max_cycle)); // 可用 +max_cycle=
    $display("[TB] CYCLE=%.3f ns, MAX_CYCLE=%0d", `CYCLE, max_cycle);
  end
  always @(posedge clk) if (!rst && !done) cycle_cnt <= cycle_cnt + 1;

  // ===== DUT I/O =====
  reg                               in_valid;
  reg  signed [IN_WIDTH-1:0]        rx_re_in, rx_img_in;
  reg         [RHO_WIDTH-1:0]       rho;
  wire        [7:0]                 theta;
  wire        [20:0]                epsilon;   // Q1.20
  wire                              out_valid;

CHIP CHIP (
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
  reg [EPS_FILE_WIDTH-1:0]   eps_mem    [0:1];  // 兩行
  reg [THETA_FILE_WIDTH-1:0] theta_mem  [0:1];  // 兩行

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

  // === 新增：從外部檔案印 ASCII（PASS/FAIL 都用這個）===
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
      $write("%s", line);
    end
    $fclose(fd);
  endtask

  // ===== 驅動/比對狀態 =====
  integer samp_idx;
  integer out_cnt;       // out_valid 次數（顯示用）
  integer err_eps_cnt;   // 總 eps 錯誤次數（兩次中累加）
  integer err_th_cnt;    // 總 theta 錯誤次數
  integer cmp_idx;       // 目前要比第幾行 (0 或 1)

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
        $display("\n[TB][TIMEOUT] Reached MAX_CYCLE=%0d (%.3f us). 第二個 out_valid 未完成，判定 FAIL.",
                 max_cycle, max_cycle*`CYCLE/1000.0);
        // 逾時也印 fail 圖
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

  // ===== 正緣比答案：純定點域比誤差；最後顯示浮點/定點 =====
  always @(posedge clk) begin
    // 任何時刻 out_valid 不能是 X/Z
    if (!rst && $isunknown(out_valid))
      $fatal(1, "[TB][X] out_valid is X/Z at cycle %0d", cycle_cnt);

    if (!rst && out_valid) begin
      // 當 out_valid=1 時，輸出內容不得有 X/Z
      if ($isunknown(theta))   $fatal(1, "[TB][X] theta is X/Z at cycle %0d", cycle_cnt);
      if ($isunknown(epsilon)) $fatal(1, "[TB][X] epsilon is X/Z at cycle %0d", cycle_cnt);

      // 取第 cmp_idx 行 golden
      ref_eps_q64 = {{(64-EPS_FILE_WIDTH){eps_mem[cmp_idx][EPS_FILE_WIDTH-1]}}, eps_mem[cmp_idx]};
      dut_eps_q64 = {{(64-EPS_DUT_WIDTH){epsilon[EPS_DUT_WIDTH-1]}},            epsilon};

      // Q 對齊到 DUT 小數位
      if (EPS_DUT_FRAC > EPS_FILE_FRAC)
        ref_eps_al64 = ref_eps_q64 <<< (EPS_DUT_FRAC - EPS_FILE_FRAC);
      else if (EPS_DUT_FRAC < EPS_FILE_FRAC)
        ref_eps_al64 = ref_eps_q64 >>> (EPS_FILE_FRAC - EPS_DUT_FRAC);
      else
        ref_eps_al64 = ref_eps_q64;

      // 定點整數域的相對百分比誤差
      num_abs     = abs64(dut_eps_q64 - ref_eps_al64); // |DUT-REF|
      den_abs     = abs64(ref_eps_al64);               // |REF|
      if (den_abs == 0)
        rel_err_pct = (num_abs == 0) ? 0.0 : 100.0;
      else
        rel_err_pct = (100.0 * num_abs) / den_abs;

      // 顯示：同時列出 fixed/decimal/float
      dut_eps_real = q_to_real(dut_eps_q64, EPS_DUT_FRAC);
      ref_eps_real = q_to_real(ref_eps_al64, EPS_DUT_FRAC);

      $display("----------------------------------------------------------------");
      $display("[EPSILON #%0d] relative_error = %.3f%% (tolerance=%.2f%%)", 
               cmp_idx, rel_err_pct, REL_ERR_TOL*100.0);
      $display("          DUT eps  (Q1.%0d) = %0d (0x%0h)  -> %.8f",
               EPS_DUT_FRAC, $signed(dut_eps_q64), dut_eps_q64[EPS_DUT_WIDTH-1:0], dut_eps_real);
      $display("          REF eps  (Q1.%0d) = %0d (0x%0h)  -> %.8f",
               EPS_DUT_FRAC, $signed(ref_eps_al64), ref_eps_al64[EPS_DUT_WIDTH-1:0], ref_eps_real);

      // theta（樣本差）
      dut_th_u64 = {{(64-THETA_FILE_WIDTH){1'b0}}, theta};
      ref_th_u64 = {{(64-THETA_FILE_WIDTH){1'b0}}, theta_mem[cmp_idx]};
      th_abs_u64 = (dut_th_u64 >= ref_th_u64) ? (dut_th_u64 - ref_th_u64)
                                              : (ref_th_u64 - dut_th_u64);
      $display("[ THETA  #%0d] |dut-ref| = %0d samp   dut=%0d ref=%0d\n",
               cmp_idx, th_abs_u64[31:0], dut_th_u64[7:0], ref_th_u64[7:0]);

      // 容差判斷（本次）
      if (rel_err_pct > (REL_ERR_TOL*100.0)) err_eps_cnt = err_eps_cnt + 1;
      if (th_abs_u64  > THETA_TOL_SAM)       err_th_cnt  = err_th_cnt  + 1;

      out_cnt = out_cnt + 1;

      // 第二次就收尾
      if (cmp_idx == 1) begin
        if (!done) begin
          done       <= 1'b1;
          done_cycle <= cycle_cnt;
        end

        #1;
        repeat (8) @(posedge clk);
        $display("SUMMARY: out_valid_count=%0d  eps_err_total=%0d  theta_err_total=%0d",
                 out_cnt, err_eps_cnt, err_th_cnt);

        if ((err_eps_cnt==0) && (err_th_cnt==0)) begin
          // PASS 圖
          $display("\n\n====================== SIMULATION PASS ======================\n");
          print_ascii($sformatf("%s/pass_art.txt", prog_path));
          $display("\n=============================================================");
          $display("        Simulation PASS!!  Cycles: %0d\n", done_cycle);
          $display("=============================================================\n");
        end else begin
          // FAIL 圖
          $display("\n\n====================== SIMULATION FAIL ======================\n");
          print_ascii($sformatf("%s/fail_art.txt", prog_path));
          $display("\n=============================================================");
          $display("        Simulation FAILED!!  Cycles: %0d\n", done_cycle);
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
    initial $sdf_annotate("../syn/CHIP_syn.sdf", CHIP);
  `elsif PR
    initial $sdf_annotate("../pr/run/output/CHIP_pr.sdf", CHIP);
  `endif

`ifdef SYN
  initial begin
    $dumpfile("top.vcd");
    $dumpvars(0, tb_top.CHIP);  // 或 tb_top/CHIP
  end
`elsif PR
  initial begin
    $dumpfile("top.vcd");
    $dumpvars(0, tb_top.CHIP);  // 或 tb_top/CHIP
  end
`endif

  // ===== FSDB（可移除）=====
  initial begin
    $fsdbDumpfile("top.fsdb");
    $fsdbDumpvars(0, "+mda", tb_top);
    $fsdbDumpvars(0, tb_top);
  end

endmodule
