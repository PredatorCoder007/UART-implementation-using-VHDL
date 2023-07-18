// UART transmitter. 
// this transmitter is able to transmit 8bits of serial data, 1 start bit,
// 1 stop bit and no parity bit
// when trasmit complete, o_tx_done driven to high for one clock cycle

//set parameters clks_per_bit as follows:
//clks_per_bit = (freq of i_clk(clk))/(freq of uart(baud rate))


module uart_tx
  #(parameter clks_per_bit)
  (
   input       i_clock,
   input       i_tx_dv,
   input[7:0]  i_tx_byte,
   output      o_tx_active,
   output      o_tx_serial,
   output      o_tx_done
  );

//create of state machine
parameter s_idle          = 3'b000;
parameter s_tx_start_bit  = 3'b001;
parameter s_tx_data_bits  = 3'b010;
parameter s_tx_stop_bit   = 3'b011;
parameter s_cleanup       = 3'b100;

reg[2:0] r_sm_main     = 0;
reg[7:0] r_clock_count = 0;
reg[2:0] r_bit_index   = 0;
reg[7:0] r_tx_data     = 0;
reg      r_tx_done     = 0;
reg      r_tx_active   = 0;

always @(posedge i_clock)
  begin

    case (r_sm_main)
      s_idle :
        begin
          o_tx_serial   <= 1'b1;   //drive line high for idle
          r_tx_done     <= 1'b0;
          r_clock_count <=    0;
          r_bit_index   <=    0;
        
        if(i_tx_dv == 1'b1)
          begin
            r_tx_active <= 1'b1;
            r_tx_data   <= i_tx_byte;
            r_sm_main   <= s_tx_start_bit;
          end
        else
          r_sm_main <= s_idle;
        end //case: s_idle

     // send out start bit, start bit = 0
     s_tx_start_bit :
       begin
         o_tx_serial <= 1'b0;
          
         //wait clks_per_bit-1 clk cycles for start bit to finish
         

         if(r_clk_count < clk_per_bit - 1)
          begin
            r_clock_count  <=  r_clock_count + 1;
            r_sm_main      <=  s_tx_start_bit;
          end
         else
          begin
            r_clock_count <= 0;
            r_sm_main     <= s_tx_data_bits;
          end
       end //case: s_tx_start_bit

// wait clks_per_bit - 1 clk cycle for data bits to finish
      s_tx_data_bits :
        begin
          o_tx_serial <= r_tx_data[r_bit_index];
         
        if(r_clk_count < clks_per_bit - 1)
          begin
            r_clock_count <= r_clock_count + 1;
            r_sm_main     <= s_tx_data_bits;
          end
        else
          begin
            r_clock_count <= 0;
          
          //check if we have sent out all bits
          if (r_bit_index < 7)
            begin
              r_bit_index <= r_bit_index + 1;
              r_sm_main   <= s_tx_data_bits;
            end
          else
            begin
              r_bit_index <= 0;
              r_sm_main   <= s_tx_stop_bit;
          end
         end
       end //case: s_tx_data_bits

// send out stop bit. stop bit = 1
s_tx_stop_bit : 
  begin
    o_tx_serial <= 1'b1;
 
    //wait clks_per_bit - 1 clock cycle for stop bit to finish
    if (r_clock_count < clks_per_bit - 1)
      begin
        r_clock_count  <= r_clock_count + 1;
        r_sm_main      <= s_tx_stop_bit;
      end
    else
      begin 
        r_tx_done     <=      1'b1;
        r_clock_count <=         0;
        r_sm_main     <= s_cleanup;
        r_tx_active   <=      1'b0;
      end
    end //case: s_tx_stop_bit

 //stay here 1 clock
 s_cleanup :
   begin
     r_tx_done <= 1'b1;
     r_sm_main <= s_idle;
   end
 
 default : 
   r_sm_main <= s_idle;

 endcase
end

assign o_tx_active = r_tx_active
assign o_tx_done   = r_tx_done

endmodule