`timescale 1ns / 1ps  //единица времени — 1 нс, точность — 1 пс

module APB_top_tb;

  // Сигналы хоста (к apb_top)
  logic        pclk;
  logic        presetn;
  logic        req;
  logic        wr;
  logic [31:0] addr;
  logic [31:0] wdata;
  wire  [31:0] rdata;
  wire         ready;
  wire         err;

  // Параметры
  parameter bit [31:0] PDEVICE_OFFSET = 32'h7000_0000;

  // Внутренние переменные тестбенча
  logic [31:0] address;
  logic [31:0] data_to_device;
  logic [31:0] data_from_device;

  // Инициализация топ уровня
  APB_top TOP (
      .pclk   (pclk),
      .presetn(presetn),
      .req    (req),
      .wr     (wr),
      .addr   (addr),
      .wdata  (wdata),
      .rdata  (rdata),
      .ready  (ready),
      .err    (err)
  );

  // Задача записи через хост-интерфейс мастера
  task automatic apb_write(input logic [31:0] a, input logic [31:0] d);
    wait (ready == 1'b0);
    @(posedge pclk);
    req   <= 1'b1;
    wr    <= 1'b1;
    addr  <= a;
    wdata <= d;
    wait (ready == 1'b1);
    req <= 1'b0;
    wait (ready == 1'b0);
  endtask

  // Задача чтения через хост-интерфейс мастера
  task automatic apb_read(input logic [31:0] a, output logic [31:0] d);
    wait (ready == 1'b0);
    @(posedge pclk);
    req  <= 1'b1;
    wr   <= 1'b0;
    addr <= a;
    wait (ready == 1'b1);
    d = rdata;
    req <= 1'b0;
    wait (ready == 1'b0);
  endtask

  // Генератор тактового сигнала (период 20 нс)
  always #10 pclk = ~pclk;

  // Основной сценарий теста
  initial begin
    pclk    = 1'b0;
    presetn = 1'b1;

    req   = 1'b0;
    wr    = 1'b0;
    addr  = '0;
    wdata = '0;

    repeat (5) @(posedge pclk);
    presetn = 1'b0;
    repeat (5) @(posedge pclk);
    presetn = 1'b1;
    repeat (5) @(posedge pclk);

    // Тест 1: адрес 0x0 — номер в группе 1 (LSB=1 -> ожидаем 55555555 по заданию 8)
    address = PDEVICE_OFFSET + 0;
    data_to_device = 32'h0000_0001;
    apb_write(address, data_to_device);
    apb_read(address, data_from_device);
    $display("Addr= 0x%h, write data 0x%h, read data 0x%h", address, data_to_device,
             data_from_device);
    if (data_from_device !== 32'h5555_5555)
      $error("[TB] FAIL: addr 0x0, expected 0x55555555, got 0x%08h", data_from_device);
    else $display("[TB] PASS: addr 0x0");

    // Тест 2: адрес 0x4 — дата 15.11.2026 в BCD
    address = PDEVICE_OFFSET + 4;
    data_to_device = 32'h1511_2026;
    apb_write(address, data_to_device);
    apb_read(address, data_from_device);
    $display("Addr= 0x%h, write data 0x%h, read data 0x%h", address, data_to_device,
             data_from_device);
    if (data_from_device !== 32'h1511_2026)
      $error("[TB] FAIL: addr 0x4, expected 0x15112026, got 0x%08h", data_from_device);
    else $display("[TB] PASS: addr 0x4");

    // Тест 3: адрес 0x8 — фамилия "Bala" в ASCII (42 61 6c 61)
    address = PDEVICE_OFFSET + 8;
    data_to_device = 32'h4261_6C61;
    apb_write(address, data_to_device);
    apb_read(address, data_from_device);
    $display("Addr= 0x%h, write data 0x%h, read data 0x%h", address, data_to_device,
             data_from_device);
    if (data_from_device !== 32'h4261_6C61)
      $error("[TB] FAIL: addr 0x8, expected 0x4261_6C61, got 0x%08h", data_from_device);
    else $display("[TB] PASS: addr 0x8");

    // Тест 4: адрес 0xC — имя "Arta" в ASCII (41 72 74 61)
    address = PDEVICE_OFFSET + 12;
    data_to_device = 32'h4172_7461;
    apb_write(address, data_to_device);
    apb_read(address, data_from_device);
    $display("Addr= 0x%h, write data 0x%h, read data 0x%h", address, data_to_device,
             data_from_device);
    if (data_from_device !== 32'h4172_7461)
      $error("[TB] FAIL: addr 0xC, expected 0x4172_7461, got 0x%08h", data_from_device);
    else $display("[TB] PASS: addr 0xC");

    // неверный адрес -> pslverr=1, затем верный -> pslverr должен сброситься
    address = PDEVICE_OFFSET + 32'h10;  // 0x10 не декодируется -> default
    data_to_device = 32'hDEAD_BEEF;
    apb_write(address, data_to_device);

    address = PDEVICE_OFFSET + 0;  // верный адрес -> APB_SETUP сбросит pslverr
    apb_read(address, data_from_device);
    if (err !== 1'b0) $error("[TB] FAIL: err not cleared after valid access, got %b", err);
    else $display("[TB] PASS: err cleared after valid access");

    repeat (10) @(posedge pclk);
    $finish();
  end

  initial begin
    $dumpfile("wave.vcd");
    $dumpvars(0, APB_top_tb);
  end

endmodule
