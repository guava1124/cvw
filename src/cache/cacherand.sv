///////////////////////////////////////////
// cacheLRU.sv
//
// Written: Rose Thompson ross1728@gmail.com
// Created: 20 July 2021
// Modified: 20 January 2023
//
// Purpose: Implements Pseudo LRU. Tested for Powers of 2.
//
// Documentation: RISC-V System on Chip Design Chapter 7 (Figures 7.8 and 7.15 to 7.18)
//
// A component of the CORE-V-WALLY configurable RISC-V project.
// https://github.com/openhwgroup/cvw
//
// Copyright (C) 2021-23 Harvey Mudd College & Oklahoma State University
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

module cacherand
  #(parameter NUMWAYS = 4, SETLEN = 9, OFFSETLEN = 5, NUMLINES = 128) (
  input  logic                clk, 
  input  logic                reset,
  input  logic                FlushStage,
  input  logic                CacheEn,         // Enable the cache memory arrays.  Disable hold read data constant >>>>>>>>>>>>>>>>>>>>>>>>> allows cache to be written to or not.
  input  logic [NUMWAYS-1:0]  HitWay,          // Which way is valid and matches PAdr's tag >>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>> how you know which way is the hit// the way bits that select the correct way in the set
  input  logic [NUMWAYS-1:0]  ValidWay,        // Which ways for a particular set are valid, ignores tag >>>>>>>>>>>>>>>>>>>>>>>>>> how you know if a way is valid or not
  input  logic [SETLEN-1:0]   CacheSetData,    // Cache address, the output of the address select mux, NextAdr, PAdr, or FlushAdr >>>>>>>>>> the data address bits that is stored in the set in the cashe
  input  logic [SETLEN-1:0]   CacheSetTag,     // Cache address, the output of the address select mux, NextAdr, PAdr, or FlushAdr >>>>>>>>>> the tag address bits in the cache that is checked with the tag bits of the address
  input  logic [SETLEN-1:0]   PAdr,            // Physical address //the address that is being written to???
  input  logic                LRUWriteEn,      // Update the LRU state //when there is a enable which allows the cache to update what way it is evicting
  input  logic                SetValid,        // Set the dirty bit in the selected way and set >>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>> set valid is high when it is inputting a new value into the cache and thus it must use the VictimWayEnc (evicting a value or putting it into a non valid way in the set)
  input  logic                ClearValid,      // Clear the dirty bit in the selected way and set >>>>>>>>>>>>>>>>>>>>>>>>>>>???????????? not used??
  input  logic                InvalidateCache, // Clear all valid bits >>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
  output logic [NUMWAYS-1:0]  VictimWay        // LRU selects a victim to evict >>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
);

  localparam                           LOGNUMWAYS = $clog2(NUMWAYS);

  //logic [NUMWAYS-2:0]                  LRUMemory [NUMLINES-1:0];
  logic [NUMWAYS-2:0]                  CurrLRU; //CAN use this for current LFSR bits
  //logic [NUMWAYS-2:0]                  NextLRU; //don't use this one for next, as next should be just 1 bit that's fed back around into the lfsr.
  logic [LOGNUMWAYS-1:0]               HitWayEncoded, Way;
  logic [NUMWAYS-2:0]                  WayExpanded;
  logic                                AllValid; //set to 1 if all of the ways are valid, (meaning that they are all full)
  
  genvar                               row;

  /* verilator lint_off UNOPTFLAT */
  // Rose: For some reason verilator does not like this.  I checked and it is not a circular path.
  logic [NUMWAYS-2:0]                  LRUUpdate;
  //logic [LOGNUMWAYS-1:0] Intermediate [NUMWAYS-2:0];
  /* verilator lint_on UNOPTFLAT */

  logic [NUMWAYS-1:0] FirstZero;
  logic [LOGNUMWAYS-1:0] FirstZeroWay;
  logic [LOGNUMWAYS-1:0] VictimWayEnc; //encoder that comes out of the cache way placment mulitplexer that selects using the allValid bit

  binencoder #(NUMWAYS) hitwayencoder(HitWay, HitWayEncoded); //encodes the way that was a hit

  //multiplexer selector to choose between either picking the first empty way, or picking a random way to evict in the LFSR random replacement policy,
  //set to 1 if all of the ways are valid, (meaning that they are all full)
  assign AllValid = &ValidWay; 

  ///// Update replacement bits.
  // coverage off
  // Excluded from coverage b/c it is untestable without varying NUMWAYS.
  function integer log2 (integer value);
    int val;
    val = value;
    for (log2 = 0; val > 0; log2 = log2+1)
      val = val >> 1;
    return log2;
  endfunction // log2
  // coverage on

  // On a miss we need to ignore HitWay and derive the new replacement bits with the VictimWay.
  //logic to select between a hit or a miss way
  //set valid is high when it is inputting a new value into the cache and thus it must use the VictimWayEnc (evicting a value or putting it into a non valid way in the set)
  mux2 #(LOGNUMWAYS) WayMuxEnc(HitWayEncoded, VictimWayEnc, SetValid, Way);

  /*
  // bit duplication
  // expand HitWay as HitWay[3], {{2}{HitWay[2]}}, {{4}{HitWay[1]}, {{8{HitWay[0]}}, ...
  for(row = 0; row < LOGNUMWAYS; row++) begin
    localparam integer DuplicationFactor = 2**(LOGNUMWAYS-row-1);
    localparam StartIndex = NUMWAYS-2 - DuplicationFactor + 1;
    localparam EndIndex = NUMWAYS-2 - 2 * DuplicationFactor + 2;
    assign WayExpanded[StartIndex : EndIndex] = {{DuplicationFactor}{Way[row]}};
  end
  */

  /*
  genvar               node;
  assign LRUUpdate[NUMWAYS-2] = '1;
  for(node = NUMWAYS-2; node >= NUMWAYS/2; node--) begin : enables
    localparam ctr = NUMWAYS - node - 1;
    localparam ctr_depth = log2(ctr);
    localparam lchild = node - ctr;
    localparam rchild = lchild - 1;
    localparam r = LOGNUMWAYS - ctr_depth;

    // the child node will be updated if its parent was updated and
    // the Way bit was the correct value.
    // The if statement is only there for coverage since LRUUpdate[root] is always 1. LRU POLICY CAN REMOVE

    if (node == NUMWAYS-2) begin
      assign LRUUpdate[lchild] = ~Way[r];
      assign LRUUpdate[rchild] = Way[r];
    end else begin
      assign LRUUpdate[lchild] = LRUUpdate[node] & ~Way[r];
      assign LRUUpdate[rchild] = LRUUpdate[node] & Way[r];
    end
  end
  */

  // The root node of the LRU tree will always be selected in LRUUpdate. No mux needed. LRU POLICY CAN REMOVE
  //assign NextLRU[NUMWAYS-2] = ~WayExpanded[NUMWAYS-2];
  //if (NUMWAYS > 2) mux2 #(1) LRUMuxes[NUMWAYS-3:0](CurrLRU[NUMWAYS-3:0], ~WayExpanded[NUMWAYS-3:0], LRUUpdate[NUMWAYS-3:0], NextLRU[NUMWAYS-3:0]);

  // Compute next victim way. LRU POLICY CAN REMOVE Intermediate is the place that you need to input your LFSR vvv !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
  /*
  for(node = NUMWAYS-2; node >= NUMWAYS/2; node--) begin
    localparam t0 = 2*node - NUMWAYS;
    localparam t1 = t0 + 1;
    assign Intermediate[node] = CurrLRU[node] ? Intermediate[t0] : Intermediate[t1];
  end
  for(node = NUMWAYS/2-1; node >= 0; node--) begin
    localparam int0 = (NUMWAYS/2-1-node)*2;
    localparam int1 = int0 + 1;
    assign Intermediate[node] = CurrLRU[node] ? int1[LOGNUMWAYS-1:0] : int0[LOGNUMWAYS-1:0];
  end
  */
  
  

    //localparam LOG2_NUMWAYS = $clog2(NUMWAYS);
    localparam WIDTH = LOGNUMWAYS + 2; // Number of bits for the LFSR

  //Put LFSR here
    // Internal signals
    logic [WIDTH-1:0] currRandom;
    logic next;
    //logic en; // Ensure en signal is defined
    assign val[0] = 1'b1;
    assign val[WIDTH-1:1] = '0;
    //assign en = 1'b1;

    priorityonehot #(NUMWAYS) FirstZeroEncoder(~ValidWay, FirstZero);
    binencoder #(NUMWAYS) FirstZeroWayEncoder(FirstZero, FirstZeroWay);
    //mux2 #(LOGNUMWAYS) VictimMux(FirstZeroWay, Intermediate[NUMWAYS-2], AllValid, VictimWayEnc); //THIS IS THE VICTIM MUX that selects between the victim in the case that all ways are valid, and the first zero way in the other case. It outputs VictimWayEnc
    mux2 #(LOGNUMWAYS) VictimMux(FirstZeroWay, currRandom[WIDTH-1:0], AllValid, VictimWayEnc); //THIS IS THE VICTIM MUX that selects between the victim in the case that all ways are valid, and the first zero way in the other case. It outputs VictimWayEnc
    decoder #(LOGNUMWAYS) decoder (VictimWayEnc, VictimWay);

    // LFSR polynomial logic
    flopenl #(WIDTH) LFSRReg(.clk(clock), .load(reset), .en(LRUWriteEn), .d({next, currRandom[WIDTH-1:1]}), .val, .q(currRandom));

    if (WIDTH == 3) //two way, degree 2
        assign next = currRandom[2] ^ currRandom[1] ^ currRandom[0];
    else if (WIDTH == 4) //4 way, degree 3
        assign next = currRandom[3] ^ currRandom[1] ^ currRandom[0]; // Update polynomial according to specification
    else if (WIDTH == 5) //8 way
        assign next = currRandom[4] ^ currRandom[1] ^ currRandom[0]; // Update polynomial according to specification
    else if (WIDTH == 6) //16
        assign next = (currRandom[5] ^ currRandom[4] ^ currRandom[3] ^ currRandom[2] ^ currRandom[0]); // Update polynomial according to specification
    else if (WIDTH == 7) //32
        assign next = currRandom[6]^currRandom[5]^currRandom[3]^currRandom[2]^currRandom[0]; // Update polynomial according to specification
    else if (WIDTH == 8) //64
        assign next = currRandom[7]^currRandom[6]^currRandom[5]^currRandom[4]^currRandom[2]^currRandom[1]^currRandom[0]; // Update polynomial according to specification
    else if (WIDTH == 9) //128
        assign next = currRandom[8]^currRandom[7]^currRandom[6]^currRandom[5]^currRandom[2]^currRandom[1]^currRandom[0]; // Update polynomial according to specification

  // LRU storage must be reset for modelsim to run. However the reset value does not actually matter in practice.
  // This is a two port memory.
  // Every cycle must read from CacheSetData and each load/store must write the new LRU.

  // note: Verilator lint doesn't like <= for array initialization (https://verilator.org/warn/BLKLOOPINIT?v=5.021)
  // Move to = to keep Verilator happy and simulator running fast
  always_ff @(posedge clk) begin
    if (reset | (InvalidateCache & ~FlushStage)) 
      for (int set = 0; set < NUMLINES; set++) LRUMemory[set] = 0; // exclusion-tag: initialize
    else if(CacheEn) begin //if the cache is enabled
      // Because we are using blocking assignments, change to LRUMemory must occur after LRUMemory is used so we get the proper value
      //checks if the write is allowed to the flip flops that store the bits that tell you what way to 
      if(LRUWriteEn & (PAdr == CacheSetTag)) CurrLRU = NextLRU;
      else                                   CurrLRU = LRUMemory[CacheSetTag];
      if(LRUWriteEn)                         LRUMemory[PAdr] = NextLRU;
    end
  end

endmodule
