//----%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
//----%% ╔═╦╗╔╗─────────╔╗─╔╗────╔╗
//----%% ║╔╣╚╬╬═╦══╦╦╦═╦╣╠╗║║╔═╦═╬╬═╗
//----%% ║╚╣║║║╬║║║║║║║║║═╣║╚╣╬║╬║║═╣
//----%% ╚═╩╩╩╣╔╩╩╩╩═╩╩═╩╩╝╚═╩═╬╗╠╩═╝
//----%% ─────╚╝───────────────╚═╝                                                                      Chipmunk Logic™ , https://chipmunklogic.com
//----%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
//----%% Module Name      : APB Master                                           
//----%% Developer        : Mitu Raj, chip@chipmunklogic.com
//----%%
//----%% Description      : APB Master accepts commands and translates it to APB requests.
//----%%
//----%% Last modified on : Dec-2023                                                                                        
//----%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

//###################################################################################################################################################
//                                                                  A P B   M A S T E R                                       
//###################################################################################################################################################
module apb_master #(
   // Configurable Parameters
   parameter DW = 32 ,  // Data width
   parameter AW = 8  ,  // Address width; max. 32 as per APB spec

   // Derived Parameters
   localparam SW = $ceil(DW/8)      ,  // Strobe width
   localparam CW = 1 + SW + DW + AW ,  // Command width  {pwrite, pstrb, pwdata, paddr}  
   localparam RW = 1 + DW              // Response width {pslverr, prdata}
)
(
   // Clock and Reset
   input  logic pclk    ,  // Clock
   input  logic presetn ,  // Reset
   
   // Command & Response Interface
   input  logic [CW-1:0] i_cmd   ,  // Command
   input  logic          i_valid ,  // Valid
   output logic [RW-1:0] o_resp  ,  // Response
   output logic          o_ready ,  // Ready

   // APB Interface
   output logic [AW-1:0] o_paddr   ,  // Address 
   output logic          o_pwrite  ,  // Write enable
   output logic          o_psel    ,  // Select
   output logic          o_penable ,  // Enable
   output logic [DW-1:0] o_pwdata  ,  // Write data
   output logic [SW-1:0] o_pstrb   ,  // Write strobe
   input  logic [DW-1:0] i_prdata  ,  // Read data
   input  logic          i_pslverr ,  // Slave error
   input  logic          i_pready     // Ready
);

// States
typedef enum logic [1:0]
{
   IDLE   = 2'b00 ,
   SETUP  = 2'b01 ,
   ACCESS = 2'b10
}  state_t ;
// State register, next state 
state_t state_ff, nxt_state ;

// Command timing
// ==============
// 1. Command valid can be asserted anytime.
// 2. Once asserted, command valid should remain asserted until ready is asserted
// 3. Command should be stable while valid is high and should not change value until ready is asserted
//
// pclk   __/``\__/``\__/``\__/``\__/``\__/``\__/``\
// i_cmd  ______xx______/```C0`````\/```C1`````\__xx
//                      \__________/\__________/
// i_valid______________/```````````````````````\___
// o_ready____________________/`````\_____/`````\___
// o_resp ______xx________________________/``R1`\_xx

// FSM
always_ff @(posedge pclk or negedge presetn) begin
   if (!presetn) begin
      state_ff <= IDLE ;
   end
   else begin
      state_ff <= nxt_state ;
   end
end
always_comb begin
   case (state_ff)
      IDLE    : nxt_state = (i_valid)? SETUP : IDLE ;
      SETUP   : nxt_state = ACCESS ;
      ACCESS  : nxt_state = (!i_pready)? ACCESS : IDLE ;
      default : nxt_state = state_ff ;
   endcase
end

// APB Interface outputs
assign o_paddr   = i_cmd[0+:AW] ;
assign o_pwrite  = i_cmd[CW-1] ;
assign o_psel    = (state_ff == SETUP || state_ff == ACCESS);
assign o_penable = (state_ff == ACCESS);
assign o_pwdata  = i_cmd[AW+:DW] ;
assign o_pstrb   = i_cmd[(CW-2)-:SW] ;

// Outputs to Command Interface
assign o_resp  = {i_pslverr, i_prdata} ;
assign o_ready = o_penable & i_pready ;

endmodule
//###################################################################################################################################################
//                                                                  A P B   M A S T E R                                       
//###################################################################################################################################################