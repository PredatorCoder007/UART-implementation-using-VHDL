//UART receiver
//receiver is able to receive 8 bits serial data, 1 start and 1 end bit and no parity bit
// when receive is complete o_rx_dv would be high for one clk cycle
// Set Parameter
// clks_per_bit = (freq of i_clk(clk))/(freq of uart(baud rate))

module uart_rx
   #(parameter clks_per_bit)               //using this as timing parameter
   (
     input          i_clock,               //input clk
     input          i_rx_serial,           //serial data receiving
     output         o_rx_dv,   //op to indicate after data receiving complete
     output[7:0]    o_rx_byte  //converted o/p of serial input
   );

  
   //creating of a state machine
   parameter s_idle             =    3'b000;
   parameter s_rx_start_bit     =    3'b001;
   parameter s_rx_data_bits     =    3'b010;
   parameter s_rx_stop_bit      =    3'b011;
   paramete  s_cleanup          =    3'b100;

   reg       r_rx_data_r        =    1'b1;
   reg       r_rx_data          =    1'b1;

   reg[7:0]  r_clock_count      =    0;
   reg[2:0]  r_bit_index        =    0;           //total 8bits
   reg[7:0]  r_rx_byte          =    0;
   reg       r_rx_dv            =    0;
   reg[2:0]  r_sm_main          =    0;

   //purpose: double-register the incoming data
   //allows it to be used in UART rx clk domain
   //(it removes problems by metastability)
   //metastability: when signal input to flip-flop or latch is in state of
   //transition and stays in an unpredictable state for extended period of
   //time. occurs due to timing mismatch between signals and clk edge
   //synchronisation technique to deal with issue
   always @(posedge i_clock)
    begin
      r_rx_data_r <= i_rx_serial;
      r_rx_data   <= r_rx_data_r;
    end
  
   //purpose: control rx state machine
   always @(posedge i_clock)
    begin

      case(r_sm_main)
        s_idle :
          begin
            r_rx_dv       <=   1'b0;
            r_clock_count <=      0;
            r_bit_index   <=      0;

          if(r_rx_data == 1'b0)               //start bit detected
            r_sm_main <= s_rx_start_bit;      //machine state 
          else
            r_sm_main <= s_idle;
          end
         
    //check middle of start bit to make sure its still low(error //correction)
    s_rx_start_bit :
      begin
        if (r_clock_count == (clks_per_bit-1)/2)
          begin
            if(r_rx_data == 1'b00)
               begin
                 r_clock_count <= 0;            //reset counter, found the 
                                                //middle
                 r_sm_main     <= s_rx_data_bits;
               end
            else
             begin 
               r_clock_count <= r_clock_count + 1;
               r_sm_main     <= s_rx_start_bit;
             end
            end //case: s_rx_data_bits
     

   //receive stop bit. stop bit = 1
   s_rx_stop_bit :
     begin
       //wait clks_per_bit-1 clock cycles for stop bit to finish
       if (r_clock_count < clks_per_bit - 1)
         begin
           r_clock_count <= r_clock_count + 1;
           r_sm_main     <= s_rx_stop_bit;
         end
       else
        begin
           r_rx_dv       <=  1'b1;
           r_clock_count <=     0;
           r_sm_main     <=  s_cleanup;
        end
       end  //case: s_rx_stop_bit

    // stay here 1 clock
    s_cleanup :
      begin
        r_sm_main  <=   s_idle; // after receving final stop bit go to idle
        r_rx_dv    <=   1'b0;
      end
    
    default : 
      r_sm_main <= s_idle;

    endcase
   end

  assign o_rx_dv   = r_rx_dv;
  assign o_rx_byte = r_rx_byte;
  
endmodule //uart_rx