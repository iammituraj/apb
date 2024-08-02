//----%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
//----%% ╔═╦╗╔╗─────────╔╗─╔╗────╔╗
//----%% ║╔╣╚╬╬═╦══╦╦╦═╦╣╠╗║║╔═╦═╬╬═╗
//----%% ║╚╣║║║╬║║║║║║║║║═╣║╚╣╬║╬║║═╣
//----%% ╚═╩╩╩╣╔╩╩╩╩═╩╩═╩╩╝╚═╩═╬╗╠╩═╝
//----%% ─────╚╝───────────────╚═╝                                                                      Chipmunk Logic™ , https://chipmunklogic.com
//----%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
//----%% Module Name      : APB Slave                                          
//----%% Developer        : Mitu Raj, chip@chipmunklogic.com
//----%%
//----%% Description      : APB slave which implements register address map for a HW. Read access has one wait state. Write access has 0 wait state.
//----%%                    Write access: 2-cycle
//----%%                    Read access : 3-cycle
//----%%
//----%% Last modified on : July-2024                                                                                        
//----%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

//###################################################################################################################################################
//                                                                  A P B   S L A V E                                       
//###################################################################################################################################################
module apb_slave #(
   // Configurable Parameters
   parameter DW = 32 ,  // Data width
   parameter AW = 5  ,  // Address width; max. 32 as per APB spec

   // Derived Parameters
   localparam SW = int'($ceil(DW/8))  // Strobe width
)
(
   // Clock and Reset
   input  logic pclk    ,  // Clock
   input  logic presetn ,  // Reset

   // APB Interface
   input  logic [AW-1:0] i_paddr   ,  // Address 
   input  logic          i_pwrite  ,  // Write enable
   input  logic          i_psel    ,  // Select
   input  logic          i_penable ,  // Enable
   input  logic [DW-1:0] i_pwdata  ,  // Write data
   input  logic [SW-1:0] i_pstrb   ,  // Write strobe
   output logic [DW-1:0] o_prdata  ,  // Read data
   output logic          o_pslverr ,  // Slave error
   output logic          o_pready  ,  // Ready

   // HW interface
   output logic o_hw_ctl ,   // Some control signal from APB registers to external HW...
   input  logic i_hw_sts     // Some status signal from external HW to APB registers...
);

// States
typedef enum logic [1:0] 
{
   IDLE     = 2'b00 , 
   W_ACCESS = 2'b01 , 
   R_ACCESS = 2'b10 ,
   R_FINISH = 2'b11
}  state_t ;
// State register
state_t state_ff ;

// Address LSb index, assuming address space with byte-addressing scheme...
// 8-bit  => addr[AW-1:0]                        
// 16-bit => addr[AW-1:1], ie., ignore addr[0:0] bits 
// 32-bit => addr[AW-1:2], ie., ignore addr[1:0] bits
localparam ADDR_LSB = $clog2(DW/8)     ;
localparam N_REG    = 2**(AW-ADDR_LSB) ;  // Max. no of registers supported in the address space

//-----------------------------------------------------------------------------------
//   Register Address Map
//-----------------------------------------------------------------------------------
//   1) 0x00 : apb_reg[0] - (RW)   // read-write; drives HW interface
//   2) 0x04 : apb_reg[1] - (WO)   // write-only
//   3) 0x08 : apb_reg[2] - (RW)   // read-write
//   4) 0x0C : apb_reg[3] - (RO)   // read-only
//   5) 0x10 : apb_reg[4] - (RO+)  // read-only; HW interface drives this
//   6) <RFU>
//       ...
//-----------------------------------------------------------------------------------
logic [DW-1:0] apb_reg[5] ; 

// Read/write errors
logic wr_err, rd_err ;

// Read/write requests
logic req_rd, req_write ;
assign req_rd = i_psel && ~i_pwrite ;
assign req_wr = i_psel &&  i_pwrite ;

// Synchronous logic to read/write registers
always @(posedge pclk) begin   
   // Reset  
   if (!presetn) begin      
      state_ff <= IDLE ;
      // RW/WO registers      
      apb_reg[0] <= '0 ;
      apb_reg[1] <= '0 ;
      apb_reg[2] <= '0 ;       
      // APB read ports
      o_prdata <= '0   ;
      o_pready <= 1'b0 ;
   end   
   // Out of reset
   else begin       
      // APB control FSM
      case (state_ff)
         
         // Idle State : waits for psel signal and decodes access type         
         IDLE : begin            
            if (req_wr) begin
               o_pready <= 1'b1     ;    // Write access has no wait states
               state_ff <= W_ACCESS ;    // Write access required
            end       
            else if (req_rd) begin
               o_pready <= 1'b0     ;    // Read access has wait states
               state_ff <= R_ACCESS ;    // Read access required  
            end           
         end
         
         // Write Access State : writes addressed-register
         W_ACCESS : begin             
            // psel and pwrite expected to be stable and penable to be asserted for successful write               
            if (req_wr && i_penable) begin
               // Address decoding with LSbs masked
               case (i_paddr [AW-1:ADDR_LSB])
                  0       : apb_reg[0] <= i_pwdata ;
                  1       : apb_reg[1] <= i_pwdata ;
                  2       : apb_reg[2] <= i_pwdata ;
                  default : ;                 
               endcase
            end 
            o_pready <= 1'b0 ;
            state_ff <= IDLE ;
         end
         
         // Read Access State : reads addressed-register
         R_ACCESS : begin                   
            // psel and pwrite expected to be stable and penable to be asserted for successful read               
            if (req_rd && i_penable) begin
               // Address decoding with LSbs masked
               case (i_paddr [AW-1:ADDR_LSB])
                  0       : o_prdata <= apb_reg[0] ;                     
                  2       : o_prdata <= apb_reg[2] ;
                  3       : o_prdata <= apb_reg[3] ;
                  4       : o_prdata <= apb_reg[4] ;
                  default : o_prdata <= '0         ;  // All invalid addresses, write-only registers are read as 0                 
               endcase         
            end
            else begin
               o_prdata <= '0 ;  // Send 0s on unsuccessful read
            end
            o_pready <= 1'b1     ;  // Induces one wait state
            state_ff <= R_FINISH ; 
         end
         
         // Read Finish state : All read accesses finish here          
         R_FINISH : begin              
            o_pready <= 1'b0 ;
            state_ff <= IDLE ;            
         end

         default : ;         

      endcase 
   end
end

// Assign all RO/RO+ registers
assign apb_reg[3] = 32'hDEAD_BEEF ;  // Constant value
assign apb_reg[4] = i_hw_sts      ;  // Driven by HW interface status signal...

// Drive all HW interface control signals
assign o_hw_ctl = apb_reg[0] ;

// Slave error conditions
assign wr_err    = (state_ff == IDLE)     && req_wr && (i_paddr[AW-1:ADDR_LSB] == 3 || i_paddr[AW-1:ADDR_LSB] == 4);  // Write request to read-only registers = ERROR
assign rd_err    = (state_ff == R_ACCESS) && req_rd && (i_paddr[AW-1:ADDR_LSB] == 1);                                 // Read request to write-only registers = ERROR

// Register the Slave error
always @(posedge pclk) begin   
   // Reset  
   if (!presetn) begin      
      o_pslverr <= 1'b0 ;
   end   
   // Out of reset
   else begin
      o_pslverr <= wr_err | rd_err ; 
   end
end

endmodule
//###################################################################################################################################################
//                                                                  A P B   S L A V E                                       
//###################################################################################################################################################
