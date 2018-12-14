`timescale 1ps/1ps 
module I2C_Bus(
	input reset_n,
	input clk_in,		//400KHz
	output reg I2C_scl,
	output I2C_sda_out,
	input I2C_sda_in,
	input I2C_wr,
	input [31:0] I2C_wdata,
	input [31:0] I2C_rdata,
	input I2C_en,
	input [4:0] I2C_NM,
	output reg I2C_done,
	output reg I2C_error,
	output reg [7:0] I2C_error_time,
	output I2C_ACKflg,
	output reg [23:0] ReadData,
	output reg I2CIOStatus
);



//reg I2C_sda;
reg [5:0] cnt;
reg [4:0] NMnow;
reg [4:0] Data_Num;
reg [7:0] I2C_rdata_temp;
reg [5:0] temp;
reg I2C_sda_out_temp;
reg [23:0] ReadData_temp;

//assign I2C_ACKflg = ((cnt>=0)&&(cnt<=3)&&(NMnow))||(I2C_wr&&(NMnow==(I2C_NM-1))&&(cnt>=5)&&(cnt<=35));
assign I2C_ACKflg = ((cnt>=0)&&(cnt<=3)&&(NMnow));
assign I2C_sda_out = I2C_ACKflg ? 1'b0 : I2C_sda_out_temp;
//assign I2CIOStatus = I2C_wr ? ((NMnow>0 && NMnow<I2C_NM) ? ((NMnow==1 && I2C_ACKflg) ? 1'b1 : !I2C_ACKflg):1'b0 ) :I2C_ACKflg;

reg [4:0] I2CBusState;
parameter Init = 5'd0;
parameter WaitBusEnable = 5'd1;
parameter JudgeWR = 5'd2;
//parameter WBusStart = 5'd3;
parameter ChipWAddr = 5'd4;
parameter WAck1 = 5'd5;
parameter WRegAddr = 5'd6;
parameter WAck2 = 5'd7;
parameter WRegData = 5'd8;
parameter WAck3 = 5'd9;
parameter BusStop = 5'd10;

always @(posedge clk_in or negedge reset_n)
if(!reset_n)
begin
	cnt <= 0;
	I2C_scl <= 1;
	I2C_sda_out_temp <= 1;
	I2C_done <= 0;
	I2CIOStatus <= 0;
	NMnow <= 0;
	Data_Num <= 0;
	//I2C_error <= 0;
	I2C_error_time <= 0;
	ReadData_temp <= 0;
	ReadData <= 0;
	I2CBusState <= Init;
end
else
begin
	case(I2CBusState)
	Init:
	begin
		cnt <= 0;
		I2C_scl <= 1;
		I2C_sda_out_temp <= 1;
		I2C_done <= 0;
		I2CIOStatus <= 0;
		I2CBusState <= WaitBusEnable;
	end
	
	WaitBusEnable:			//Start
	begin
		if(I2C_en)
		begin
			I2C_sda_out_temp <= 0;
			I2CBusState <= JudgeWR;
		end
		else
		begin
			I2C_sda_out_temp <= 1;
			I2CBusState <= WaitBusEnable;
		end
	end
	
	JudgeWR:
	begin
		if(!I2C_wr)
		begin
			ChipWAddrBuf <= I2C_wdata[7:0];
			I2CBusState <= ChipWAddrStep1;
		end
		else
		begin
			ChipWAddrBuf <= I2C_rdata[7:0];
			I2CBusState <= ChipRAddr;
		end
	end
	
	ChipWAddrStep1:
	begin
		I2C_scl <= ~I2C_scl;
		I2C_sda_out_temp <= ChipWAddrBuf[3'd7-cnt];
		I2CBusState <= ChipWAddrStep2;
	end
	
	ChipWAddrStep2:
	begin
		I2C_scl <= ~I2C_scl;
		if(cnt<3'd7)
		begin
			cnt <= cnt+1'd1;
			I2CIOStatus <= 0;
			I2CBusState <= ChipWAddrStep1;
		end
		else
		begin
			cnt <= 0;
			I2CIOStatus <= 1'b1;
			I2CBusState <= ChipWAddrStep2;
		end		
	end
	
	endcase
end

always @(posedge clk_in or negedge reset_n)
if(!reset_n)
begin
	I2C_scl <= 1;
	I2C_sda_out_temp <= 1;
	cnt <= 0;
//	I2C_rdata <= 0;
	NMnow <= 0;
	Data_Num <= 0;
	I2C_done <= 0;
	//I2C_error <= 0;
	I2C_error_time <= 0;
	ReadData_temp <= 0;
	ReadData <= 0;
end
else
begin
	if(I2C_en==1)
	begin
		if(!I2C_wr)						//write mode
		begin
			if(NMnow < I2C_NM)
			begin
				begin
					if(cnt[1]==1)
						I2C_scl <= 0;
					else
					begin
						I2C_scl <= 1;
						if((cnt>=0)&&(cnt<=3)&&(NMnow)&&I2C_sda_in)
						begin
							//Data_Num <= 0;
							Data_Num <= (I2C_NM-1'b1)<<3;
						end
					end	
				end
				
				if((cnt==2)&&(NMnow)&&(I2C_sda_in))					
				begin
					I2C_error <= 1;
					I2C_error_time <= I2C_error_time+1'b1;
				end
				
				if(cnt==0)
				begin
					I2C_sda_out_temp <= 1;
					Data_Num <= (I2C_NM-NMnow-1'b1)<<3;
				end
				if(cnt==1)
				begin
					I2C_sda_out_temp <= 0;
				end	
				if(cnt[1:0]==3)	
				begin
					temp <= Data_Num+4'h7-cnt[4:2];
					I2C_sda_out_temp <= I2C_wdata[Data_Num+4'h7-cnt[4:2]];								
				end				
				if(cnt==35)
				begin
					cnt <= 0;
					NMnow <= NMnow+4'h1;
				end
				
				else
					cnt <= cnt+4'h1;				
			end
			else
			begin
				if(cnt==0 || cnt==1 || cnt>3)
					I2C_scl <= 1;
				else
					I2C_scl <= 0;
				if(cnt<6)
				begin
					I2C_sda_out_temp <= 0;
				end
				if(cnt==6)
				begin
					I2C_sda_out_temp <= 1;
					I2C_done <= 1;
					I2C_error_time <= 0;
					cnt <= cnt+4'h1;
				end
				if(cnt==7)
				begin
					I2C_done <= 0;
				end
				else if(cnt<12)
				begin
					cnt <= cnt+4'h1;
				end
			end
		end
		else								//read mode
		begin
			if(NMnow < 1)			//read order write
			begin
				begin
					if(cnt[1]==1)
						I2C_scl <= 0;
					else
					begin
						I2C_scl <= 1;
						if((cnt>=0)&&(cnt<=3)&&(NMnow)&&I2C_sda_in)	//ack time
						begin
							Data_Num <= (I2C_NM-4'h1)<<3;
						end
					end	
				end
				
				if((cnt==2)&&(NMnow)&&(I2C_sda_in))					
				begin
					I2C_error <= 1;
					I2C_error_time <= I2C_error_time+4'h1;
				end
				
				if(cnt==0)
				begin
					I2C_sda_out_temp <= 1;
					Data_Num <= (I2C_NM-NMnow-4'h1)<<3;
				end
				if(cnt==1)
				begin
					I2C_sda_out_temp <= 0;
				end	
				if(cnt[1:0]==3)	
				begin
					temp <= Data_Num+4'h7-cnt[4:2];
					I2C_sda_out_temp <= I2C_rdata[Data_Num+7-cnt[4:2]];								
				end
				if(cnt==35)
				begin
					cnt <= 0;
					NMnow <= NMnow+4'h1;
				end
				
				else
					cnt <= cnt+4'h1;				
			end
			else if(NMnow < I2C_NM)			//read input
			begin
				begin
					if(cnt[1]==1)
						I2C_scl <= 0;
					else
					begin
						I2C_scl <= 1;
						if((cnt>=0)&&(cnt<=3)&&(NMnow)&&I2C_sda_in)	//ack time: wrong ack back
						begin
							Data_Num <= (I2C_NM-4'h1)<<3;
						end
					end	
				end
				
				if((cnt==2)&&(NMnow)&&(I2C_sda_in))					
				begin
					I2C_error <= 1;
					I2C_error_time <= I2C_error_time+4'h1;
				end
				
				if(cnt==0)
				begin
					I2C_sda_out_temp <= 1;
					Data_Num <= (I2C_NM-NMnow-4'h1)<<3;
				end
				if(cnt==1)
				begin
					I2C_sda_out_temp <= 0;
				end	
				if(cnt[1:0]==3)	
				begin
					temp <= Data_Num+4'h7-cnt[4:2];
					I2C_sda_out_temp <= I2C_rdata[Data_Num+7-cnt[4:2]];								
				end
				if(cnt==35)
				begin
					cnt <= 0;
					NMnow <= NMnow+4'h1;
				end
				
				else
					cnt <= cnt+4'h1;	
				begin
					if(cnt[1:0]==1 && cnt>2)
						ReadData_temp[temp] <= I2C_sda_in;				
				end
				
			end	
			
			else		//stop signal
			begin
				if(cnt==0 || cnt==1 || cnt>3)
					I2C_scl <= 1;
				else
					I2C_scl <= 0;
				if(cnt<6)
				begin
					I2C_sda_out_temp <= 0;
				end
				if(cnt==6)
				begin
					I2C_sda_out_temp <= 1;
					I2C_done <= 1;
					ReadData <= ReadData_temp;
					I2C_error_time <= 0;
					cnt <= cnt+4'h1;
				end
				if(cnt==7)
				begin
					I2C_done <= 0;
				end
				else if(cnt<12)
				begin
					cnt <= cnt+4'h1;
				end
			end
		end
	end	
			
	else
	begin
		cnt <= 0;
		NMnow <= 0;
		I2C_error <= 0;
		I2C_done <= 0;
	end
end





endmodule






