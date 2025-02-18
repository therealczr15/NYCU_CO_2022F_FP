module SP_pipeline(
	// INPUT SIGNAL
	clk,
	rst_n,
	in_valid,
	inst,
	mem_dout,
	// OUTPUT SIGNAL
	out_valid,
	inst_addr,
	mem_wen,
	mem_addr,
	mem_din
);



//------------------------------------------------------------------------
//   INPUT AND OUTPUT DECLARATION                         
//------------------------------------------------------------------------

input                    clk, rst_n, in_valid;
input             [31:0] inst;
input  signed     [31:0] mem_dout;
output reg               out_valid;
output reg        [31:0] inst_addr;
output reg               mem_wen;
output reg        [11:0] mem_addr;
output reg signed [31:0] mem_din;

//------------------------------------------------------------------------
//   DECLARATION
//------------------------------------------------------------------------

// REGISTER FILE, DO NOT EDIT THE NAME.
reg	signed [31:0] r [0:31]; 
reg	signed [31:0] r_comb [0:31]; 

wire [31:0] IF_inst_comb;
reg [31:0] IF_inst_addr_comb;

reg [31:0] ID_inst_reg;
reg ID_in_valid, EX_in_valid, MEM_in_valid, WB_in_valid;

wire [5:0] ID_opcode_comb;
wire signed [31:0] ID_rs_comb, ID_rt_comb; 
wire [4:0] ID_rd_index_comb;
wire [15:0] ID_imm_comb;

reg [5:0] EX_opcode_reg;
reg signed [31:0] EX_rs_reg, EX_rt_reg; 
reg [4:0] EX_rd_index_reg;
reg [15:0] EX_imm_reg;
reg EX_ALU_Src_reg;

reg signed [31:0] EX_ALU_out_comb;
wire mem_wen_comb;
wire [11:0] mem_addr_comb;
wire signed [31:0] mem_din_comb;
wire EX_RegWrite;
wire EX_Mem_to_Reg;

reg signed [31:0] MEM_ALU_out_reg;
reg [4:0] MEM_rd_index_reg;
reg MEM_RegWrite;
reg MEM_Mem_to_Reg;

reg signed [31:0] WB_ALU_out_reg;
reg RegWrite;
reg Mem_to_Reg;
reg [4:0] WriteIDX;
//------------------------------------------------------------------------
//   DESIGN
//------------------------------------------------------------------------

// IF
assign IF_inst_comb = (in_valid) ? inst : ID_inst_reg;
always @(*) begin
	if(in_valid) begin
		if (inst[31:26] == 7) begin
			if(r[inst[25:21]] == r[inst[20:16]])
				IF_inst_addr_comb = inst_addr + 4 + {{16{inst[15]}},inst[15:0],2'b0};
			else
				IF_inst_addr_comb = inst_addr + 4;
		end else if(inst[31:26] == 8) begin
			if(r[inst[25:21]] != r[inst[20:16]])
				IF_inst_addr_comb = inst_addr + 4 + {{16{inst[15]}},inst[15:0],2'b0};
			else
				IF_inst_addr_comb = inst_addr + 4;
		end else
			IF_inst_addr_comb = inst_addr + 4;
	end else
		IF_inst_addr_comb = 0;
end


// IF/ID
always @(posedge clk or negedge rst_n) begin
	if(!rst_n) begin
		ID_inst_reg <= 0;
		ID_in_valid <= 0;
		inst_addr <= 0;
	end else begin
		ID_inst_reg <= IF_inst_comb;
		ID_in_valid <= in_valid;
		inst_addr <= IF_inst_addr_comb;
	end
end




// ID
assign ID_opcode_comb = ID_inst_reg[31:26];
assign ID_rs_comb = r_comb[ID_inst_reg[25:21]];
assign ID_rt_comb = r_comb[ID_inst_reg[20:16]];
assign ID_rd_index_comb = (ID_inst_reg[31:26] == 6'd0) ? ID_inst_reg[15:11] : ID_inst_reg[20:16];
assign ID_imm_comb = ID_inst_reg[15:0];


// ID/EX
always @(posedge clk or negedge rst_n) begin
	if(!rst_n) begin
		EX_opcode_reg <= 0;
		EX_rs_reg <= 0;
		EX_rt_reg <= 0;
		EX_rd_index_reg <= 0;
		EX_imm_reg <= 0;
		EX_in_valid <= 0;
		//EX_ALU_Src_reg <= 0;
	end else begin
		EX_opcode_reg <= ID_opcode_comb;
		EX_rs_reg <= ID_rs_comb;
		EX_rt_reg <= ID_rt_comb;
		EX_rd_index_reg <= ID_rd_index_comb;
		EX_imm_reg <= ID_imm_comb;
		EX_in_valid <= ID_in_valid;
	end
end




// EX
always @(*) begin
	if(EX_opcode_reg == 0) begin //R_type
		case (EX_imm_reg[5:0])
			6'd0: EX_ALU_out_comb = EX_rs_reg & EX_rt_reg;
			6'd1: EX_ALU_out_comb = EX_rs_reg | EX_rt_reg;
			6'd2: EX_ALU_out_comb = EX_rs_reg + EX_rt_reg;
			6'd3: EX_ALU_out_comb = EX_rs_reg - EX_rt_reg;
			6'd4: EX_ALU_out_comb = (EX_rs_reg < EX_rt_reg) ;
			6'd5: EX_ALU_out_comb = EX_rs_reg << EX_imm_reg[10:6];
			6'd6: EX_ALU_out_comb = ~(EX_rs_reg | EX_rt_reg);
			default: EX_ALU_out_comb = 0;
		endcase
	end else begin //I_type
		case (EX_opcode_reg)
			6'd1: EX_ALU_out_comb = EX_rs_reg & {16'b0,EX_imm_reg};
			6'd2: EX_ALU_out_comb = EX_rs_reg | {16'b0,EX_imm_reg};
			6'd3: EX_ALU_out_comb = EX_rs_reg + {{16{EX_imm_reg[15]}},EX_imm_reg};
			6'd4: EX_ALU_out_comb = EX_rs_reg - {{16{EX_imm_reg[15]}},EX_imm_reg};
			6'd5: EX_ALU_out_comb = EX_rs_reg + {{16{EX_imm_reg[15]}},EX_imm_reg};
			6'd6: EX_ALU_out_comb = EX_rs_reg + {{16{EX_imm_reg[15]}},EX_imm_reg};
			6'd9: EX_ALU_out_comb = {EX_imm_reg,16'd0};
			default: EX_ALU_out_comb = 0;
		endcase
	end
end
assign mem_addr_comb = (EX_in_valid) ? EX_ALU_out_comb[11:0] : mem_addr;
assign mem_din_comb =  (EX_in_valid) ? EX_rt_reg : mem_din;
assign mem_wen_comb =  (EX_in_valid) ? (!(EX_opcode_reg == 6)) : mem_wen;
assign EX_RegWrite = ((EX_opcode_reg!=6) && (EX_opcode_reg!=7) && (EX_opcode_reg!=8));
assign EX_Mem_to_Reg = (EX_opcode_reg == 5);


// EX/MEM
always @(posedge clk or negedge rst_n) begin
	if(!rst_n) begin
		MEM_ALU_out_reg <= 0;
		mem_addr <= 0;
		mem_wen <= 1;
		mem_din <= 0;
		MEM_rd_index_reg <= 0;
		MEM_RegWrite <= 0;
		MEM_Mem_to_Reg <= 0;
		MEM_in_valid <= 0;
	end else begin
		MEM_ALU_out_reg <= EX_ALU_out_comb;
		mem_addr <= mem_addr_comb;
		mem_din <= mem_din_comb;
		mem_wen <= mem_wen_comb;
		MEM_rd_index_reg <= EX_rd_index_reg;
		MEM_RegWrite <= EX_RegWrite;
		MEM_Mem_to_Reg <= EX_Mem_to_Reg;
		MEM_in_valid <= EX_in_valid;
	end
end




// MEM


// MEM/WB
always @(posedge clk or negedge rst_n) begin
	if(!rst_n) begin
		Mem_to_Reg <= 0;
		WB_ALU_out_reg <= 0;
		RegWrite <= 0;
		WriteIDX <= 0;
		WB_in_valid <= 0;
	end else begin
		Mem_to_Reg <= MEM_Mem_to_Reg;
		WB_ALU_out_reg <= MEM_ALU_out_reg;
		RegWrite <= MEM_RegWrite;
		WriteIDX <= MEM_rd_index_reg;
		WB_in_valid <= MEM_in_valid;
	end
end




// WB
integer i;
always @(*) begin
	for(i=0;i<32;i=i+1) begin
		r_comb[i] = r[i];
	end
	if(RegWrite)
		r_comb[WriteIDX] = (Mem_to_Reg) ? mem_dout : WB_ALU_out_reg;
end


//
always @(posedge clk or negedge rst_n) begin
	if(!rst_n) begin
		for(i=0;i<32;i=i+1) begin
			r[i] <= 0;
		end
		out_valid <= 0;
	end else begin
		for(i=0;i<32;i=i+1) begin
			r[i] <= r_comb[i];
		end
		out_valid <= WB_in_valid;
	end
end

endmodule