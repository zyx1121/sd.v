# SPI for MicroSD in Verilog

## Module I/O

##### 輸入
- clk
- rst_n
- SD_MISO
- write_start
- write_address
- write_data
- read_start
- read_address
##### 輸出
- sd_init_done
- SD_CLK
- SD_CS
- SD_MOSI
- write_busy
- write_request
- read_busy
- read_request
- read_data

## Flow

##### 初始化：
1. 上電延遲（大於 74 個 clk）
2. 回復卡原始狀態（CMD0）
3. 發送主設備電壓範圍（CMD8）
4. 告訴 SD 卡接下來是應用命令，而非標準命令, 不需要CRC（CMD55）
5. 發送操作寄存器內容（ACMD41）
6. 發送 8 個 CLK 後，初始化完成

##### 寫入：
1. 等待用戶進行寫入操作
2. 發送 CMD24
3. 發送頭位元組 0xFE
4. 發送 2 Byte * 256 筆資料
5. 發送 2 Byte 假 CRC 後，等待 SD 寫忙，miso 為高後寫入完成

##### 讀取：
1. 等待用戶進行讀取操作
2. 發送 CMD17
3. 接收頭位元組 0xFE
4. 接收 2 Byte * 256 比資料
5. 接收 2 Byte 假 CRC 後，等待 8 CLK，讀取完成

## Features

##### 初始化：
當 SD 卡初始化完成後 sd_init_done 會設為 1 ，此時就能對 SD 卡進行讀寫。

##### 寫入：
使用者設定 write_address 寫入扇區，write_data 第一筆寫入資料， write_start 設為一則開始寫入，當 write_request 產生一個脈波時，用戶切換 write_data 至新一筆資料，共 256 筆後完成寫入。

##### 讀取：
使用者設定 read_address 讀取扇區，read_start 設為一則開始讀取，當 read_request 產生一個脈波時，用戶讀取 read_data 為一筆資料，共接收 256 筆後完成讀取。
