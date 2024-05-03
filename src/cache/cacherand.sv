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
  

    //localparam LOG2_NUMWAYS = $clog2(NUMWAYS);
    localparam WIDTH = LOGNUMWAYS + 2; // Number of bits for the LFSR

  //Put LFSR here
    // Internal signals
    logic [WIDTH-1:0] currRandom;
    logic next;
    //logic en; // Ensure en signal is defined
   logic [WIDTH-1:0] val;
    assign val[0] = 1'b1;
    assign val[WIDTH-1:1] = '0;
    //assign en = 1'b1;

    priorityonehot #(NUMWAYS) FirstZeroEncoder(~ValidWay, FirstZero);
    binencoder #(NUMWAYS) FirstZeroWayEncoder(FirstZero, FirstZeroWay);
    //mux2 #(LOGNUMWAYS) VictimMux(FirstZeroWay, Intermediate[NUMWAYS-2], AllValid, VictimWayEnc); //THIS IS THE VICTIM MUX that selects between the victim in the case that all ways are valid, and the first zero way in the other case. It outputs VictimWayEnc
    mux2 #(LOGNUMWAYS) VictimMux(FirstZeroWay, currRandom[LOGNUMWAYS-1:0], AllValid, VictimWayEnc); //THIS IS THE VICTIM MUX that selects between the victim in the case that all ways are valid, and the first zero way in the other case. It outputs VictimWayEnc
    decoder #(LOGNUMWAYS) decoder (VictimWayEnc, VictimWay);

    // LFSR polynomial logic
    flopenl #(WIDTH) LFSRReg(.clk(clk), .load(reset), .en(LRUWriteEn), .d({next, currRandom[WIDTH-1:1]}), .val, .q(currRandom));

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


endmodule
