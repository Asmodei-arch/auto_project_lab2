`timescale 1ns / 1ps  //единица времени — 1 нс, точность — 1 пс

module APB_slave_tb;

  // Сигналы интерфейса APB
  logic        pclk;
  logic        presetn;
  logic        psel;
  logic        penable;
  logic        pwrite;
  logic [31:0] paddr;
  logic [31:0] pwdata;
  wire  [31:0] prdata;
  wire         pready;
  wire         pslverr;

  // Параметры
  parameter bit [31:0] PDEVICE_OFFSET = 32'h7000_0000;

  // Внутренние переменные тестбенча
  logic [31:0] address;
  logic [31:0] data_to_device;
  logic [31:0] data_from_device;

  // Экземпляр тестируемого устройства (DUT)
  APB_slave DUT (
      .pclk(pclk),  // Синхросигнал
      .presetn(presetn),  // Сигнал сброса (инверсный)
      .paddr(paddr),  // Адрес обращения
      .pwdata(pwdata),  // Данные для записи
      .psel(psel),  // Признак выбора устройства
      .penable(penable),  // Признак активной транзакции
      .pwrite(pwrite),  // Признак операции записи
      .pready(pready),  // Признак готовности от устройства
      .pslverr(pslverr), // Опциональный сигнал: признак ошибки при обращении
      .prdata(prdata)  // Прочитанные данные
  );

  // Задача записи по протоколу APB
  task automatic apb_write(input logic [31:0] addr, input logic [31:0] data);
    wait ((penable == 1'b0) && (pready == 1'b0));
    @(posedge pclk);
    psel         <= 1'b1;
    paddr[31:0]  <= addr[31:0];
    pwdata[31:0] <= data[31:0];
    pwrite       <= 1'b1;
    @(posedge pclk);
    penable <= 1'b1;
    @(posedge pclk);
    wait (pready == 1'b1);
    @(posedge pclk);
    psel    <= 1'b0;
    penable <= 1'b0;
    pwrite  <= 1'b0;
    @(posedge pclk);
  endtask

  // Задача чтения по протоколу APB
  task automatic apb_read(input logic [31:0] addr, output logic [31:0] data);
    wait ((penable == 1'b0) && (pready == 1'b0));
    @(posedge pclk);
    psel        <= 1'b1;
    pwrite      <= 1'b0;
    paddr[31:0] <= addr[31:0];
    @(posedge pclk);
    penable <= 1'b1;
    do @(posedge pclk); while (pready !== 1'b1);
    data[31:0] = prdata[31:0];
    psel    <= 1'b0;
    penable <= 1'b0;
    @(posedge pclk);
  endtask

  // Генератор тактового сигнала (период 20 нс)
  always #10 pclk = ~pclk;

  // Основной сценарий теста
  initial begin
    pclk    = 1'b0;
    presetn = 1'b1;

    psel    = '0;
    penable = '0;
    pwrite  = '0;
    paddr   = '0;
    pwdata  = '0;

    repeat (5) @(posedge pclk);
    presetn = 1'b0;
    repeat (5) @(posedge pclk);
    presetn = 1'b1;
    repeat (5) @(posedge pclk);

    // Тест 1: адрес 0x0 — номер в группе 1 (LSB=1 -> ожидаем 55555555 по заданию)
    address = PDEVICE_OFFSET + 0;
    data_to_device = 32'h0000_0001;
    apb_write(address, data_to_device);
    apb_read(address, data_from_device);
    $display("Addr= 0x%h, write data 0x%h, read data 0x%h", address, data_to_device,
             data_from_device);
    if (data_from_device !== 32'h5555_5555)
      //используется !== для получения однозначного результата
      $error(
          "[TB] FAIL: addr 0x0, expected 0x55555555, got 0x%08h", data_from_device
      );
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

    // Тест 3: адрес 0x8 — фамилия "Bala" в ASCII (42 61 6C 61)
    address = PDEVICE_OFFSET + 8;
    data_to_device = 32'h4261_6C61;
    apb_write(address, data_to_device);
    apb_read(address, data_from_device);
    $display("Addr= 0x%h, write data 0x%h, read data 0x%h", address, data_to_device,
             data_from_device);
    if (data_from_device !== 32'h4261_6C61)
      $error("[TB] FAIL: addr 0x8, expected 0x42616C61, got 0x%08h", data_from_device);
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
    if (pslverr !== 1'b0)
      $error("[TB] FAIL: pslverr not cleared after valid access, got %b", pslverr);
    else $display("[TB] PASS: pslverr cleared after valid access");
    repeat (10) @(posedge pclk);
    //$stop();
    $finish();
  end

  // Мониторинг состояния интерфейса
  initial begin
    $dumpfile("wave.vcd");
    $dumpvars(0, APB_slave_tb);
  end


endmodule
