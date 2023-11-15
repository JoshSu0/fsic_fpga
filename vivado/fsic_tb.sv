`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 11/08/2023 03:49:21 PM
// Design Name: 
// Module Name: fsic_tb
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: 
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////

import axi_vip_pkg::*;
import design_1_axi_vip_0_0_pkg::*;

bit resetb_0 = 0, sys_clock = 0, sys_reset = 0; 
xil_axi_resp_t resp;
bit[11:0] offset;
bit[31:0] data, base_addr = 32'h6000_0000;
integer index;

 
event system_reset_event, peripheral_reset_event, caravel_reset_event, fw_worked_event, is_txen_event, error_event;

module fsic_tb();

    localparam  ReadCyc = 1'b0;
    localparam  WriteCyc = 1'b1;
    localparam  SOC_UP = 16'h0000;
    localparam  SOC_LA = 16'h1000;
    localparam  PL_AA = 16'h2000;
    localparam  PL_AA_MB = 16'h2100;
    localparam  SOC_IS = 16'h3000;
    localparam  SOC_AS = 16'h4000;
    localparam  SOC_CC = 16'h5000;
    localparam  PL_AS = 16'h6000;
    localparam  PL_IS = 16'h7000;

    design_1_wrapper DUT
    (
        .resetb_0(resetb_0),
        .sys_clock(sys_clock),
        .sys_reset(sys_reset)
    );
    
    //always #4ns sys_clock = ~sys_clock;     //Period 8ns, 125MHz
    always #2ns sys_clock = ~sys_clock;     //Period 4ns, 250Mhz                 
        
    design_1_axi_vip_0_0_mst_t  master_agent;

    initial begin    
        fork
            system_reset_t();
            peripheral_reset_t();  
            caravel_reset_t();
            fw_worked_t();
            is_txen_t(); 
            error_t();           
        join_none    
        
        @(system_reset_event);
        @(peripheral_reset_event);
        @(caravel_reset_event);
        @(fw_worked_event);           
    end 
    
    initial begin
        master_agent = new("master vip agent", DUT.design_1_i.axi_vip_0.inst.IF);
        master_agent.start_master();
        
        @(is_txen_event);      
        $display($time, "=> Starting test...");
        
        Fpga2Soc_CfgRead();
        Fpga2Soc_CfgWrite();

        #500us    
        $display($time, "=> End of the test...");                         
        $finish;
    end
    
    task system_reset_t;
        begin
            sys_reset = 0;
            #200ns
            sys_reset = 1;
            $display($time, "=> sys_rest = %01b", sys_reset);            
            ->> system_reset_event;
        end
    endtask
    
    task peripheral_reset_t;
        begin
            wait(DUT.design_1_i.rst_clk_wiz_0_5M_peripheral_aresetn == 1'b1);
            $display($time, "=> rst_clk_wiz_0_5M_peripheral_aresetn = %01b", DUT.design_1_i.rst_clk_wiz_0_5M_peripheral_aresetn);            
            ->> peripheral_reset_event;
        end
    endtask

    task caravel_reset_t;
        begin
            @(peripheral_reset_event);                 
            #200us
            resetb_0 = 1;
            $display($time, "=> CaravelSoC resetb_0 = %01b", resetb_0);    
            ->> caravel_reset_event;        
        end
    endtask          

    task fw_worked_t;
        begin
            wait(DUT.design_1_i.caravel_0_mprj_o[37:36] == 2'b11);
            $display($time, "=> FW working, caravel_0_mprj_o[37:36] = %02b", DUT.design_1_i.caravel_0_mprj_o[37:36]);                             
            ->> fw_worked_event;        
        end
    endtask

    task error_t;
        begin
            @(error_event);
            $display($time, "=> Testbench Failed, End of the test.");
            $finish;
        end
    endtask    

    task is_txen_t;
        begin
            @(fw_worked_event);
            $display($time, "=> PL_IS enabling..."); 
            data = 1;   
            axil_cycles_gen(WriteCyc, PL_IS, 0, data);
            #10us
            data = 3;
            axil_cycles_gen(WriteCyc, PL_IS, 0, data);
            #10us            
            axil_cycles_gen(ReadCyc, PL_IS, 0, data);            
            $display($time, "=> PL_IS enables: = %h", data);
            if(data == 32'h0000_0003)                             
                ->> is_txen_event;
            else 
                ->> error_event;                        
        end
    endtask    
    
    task Fpga2Soc_CfgRead;
        begin
            $display($time, "=> Fpga2Soc_Read testing: SOC_CC"); 
            offset = 0;            
            axil_cycles_gen(ReadCyc, SOC_CC, offset, data);
            #10us            
            if(data == 32'h0000_001F) begin
                $display($time, "=> Fpga2Soc_Read SOC_CC offset %h = %h, PASS", offset, data);            
            end else begin
                $display($time, "=> Fpga2Soc_Read SOC_CC offset %h = %h, PASS", offset, data);            
                ->> error_event;            
            end

            $display($time, "=> Fpga2Soc_Read testing: SOC_AS");
            offset = 0;                         
            axil_cycles_gen(ReadCyc, SOC_AS, offset, data);
            #10us            
            if(data == 32'h0000_000F) begin
                $display($time, "=> Fpga2Soc_Read SOC_AS = %h, PASS", data);            
            end else begin
                $display($time, "=> Fpga2Soc_Read SOC_AS = %h, FAIL", data);            
                ->> error_event;            
            end

            $display($time, "=> Fpga2Soc_Read testing: SOC_IS");
            offset = 0;                         
            axil_cycles_gen(ReadCyc, SOC_IS, offset, data);
            #10us            
            if(data == 32'h0000_0001) begin
                $display($time, "=> Fpga2Soc_Read SOC_IS = %h, PASS", data);            
            end else begin
                $display($time, "=> Fpga2Soc_Read SOC_IS = %h, FAIL", data);            
                ->> error_event;            
            end     
            
            $display($time, "=> Fpga2Soc_Read testing: SOC_LA");
            offset = 0;                         
            axil_cycles_gen(ReadCyc, SOC_LA, offset, data);
            #10us            
            if(data == 32'h0000_0000) begin
                $display($time, "=> Fpga2Soc_Read SOC_LA = %h, PASS", data);            
            end else begin
                $display($time, "=> Fpga2Soc_Read SOC_LA = %h, FAIL", data);            
                ->> error_event;            
            end
                       
        end
    endtask    
    
    task Fpga2Soc_CfgWrite;
        begin
            $display($time, "=> Fpga2Soc_Write testing: SOC_CC"); 
            offset = 0;
            
            for (index = 0; index < 8'h20 ; index=index+1) begin
                data = index;
                axil_cycles_gen(WriteCyc, SOC_CC, offset, data);
                //#20us            
                axil_cycles_gen(ReadCyc, SOC_CC, offset, data);
                //#20us                
                if(data == index) begin
                    $display($time, "=> #%h, Fpga2Soc_Write SOC_CC offset %h = %h, PASS", index, offset, data);            
                end else begin
                    $display($time, "=> #%h, Fpga2Soc_Write SOC_CC offset %h = %h, FAIL", index, offset, data);            
                    ->> error_event;
                end
            end
                                                           
        end
    endtask      
        
    task axil_cycles_gen;
        input types;
        input [15:0] target;
        input [11:0] offset;
        inout [31:0] data;
 
        begin
            if (types) begin
                master_agent.AXI4LITE_WRITE_BURST(base_addr + target + offset, 0, data, resp);
                $display($time, "=> AXI4LITE_WRITE_BURST %04h, value: %04h, resp: %02b", base_addr + target + offset, data, resp);            
            end else begin
                master_agent.AXI4LITE_READ_BURST(base_addr + target + offset, 0, data, resp);
                $display($time, "=> AXI4LITE_READ_BURST %04h, value: %04h, resp: %02b", base_addr + target + offset, data, resp);
            end     
        end
        
    endtask
        
endmodule