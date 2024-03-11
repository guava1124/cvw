///////////////////////////////////////////
// sha512sig1.sv
//
// Written: kelvin.tran@okstate.edu, james.stine@okstate.edu
// Created: 6 February 2024
//
// Purpose: sha512sig1 instruction
//
// A component of the CORE-V-WALLY configurable RISC-V project.
// https://github.com/openhwgroup/cvw
// 
// Copyright (C) 2021-24 Harvey Mudd College & Oklahoma State University
//
// SPDX-License-Identifier: Apache-2.0 WITH SHL-2.1
//
// Licensed under the Solderpad Hardware License v 2.1 (the “License”); you may not use this file 
// except in compliance with the License, or, at your option, the Apache License version 2.0. You 
// may obtain a copy of the License at
//
// https://solderpad.org/licenses/SHL-2.1/
//
// Unless required by applicable law or agreed to in writing, any work distributed under the 
// License is distributed on an “AS IS” BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, 
// either express or implied. See the License for the specific language governing permissions 
// and limitations under the License.
////////////////////////////////////////////////////////////////////////////////////////////////

module sha512sig1(
   input  logic [63:0] rs1, 
   output logic [63:0] result
);

   logic [63:0] ror19, ror61, sh6;
   
   assign ror19 = {rs1[18:0], rs1[63:19]};
   assign ror61 = {rs1[60:0], rs1[63:61]};
   assign sh6  = rs1 >> 6;
   
   // Assign output to xor of 3 rotates
   assign result = ror19 ^ ror61 ^ sh6;
endmodule
