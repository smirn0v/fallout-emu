//
//  FEMemoryMap.asm
//  fallout-emu
//
//  Created by Alexander Smirnov on 20/12/15.
//  Copyright © 2015 Alexander Smirnov. All rights reserved.
//

//FEMemoryMapBlock *fe_memoryMap_blockFromVirtualAddress(FEMemoryMap *memoryMap, uint32_t address);
/*
 
 inline FEMemoryMapBlock *fe_memoryMap_blockFromVirtualAddress(FEMemoryMap *memoryMap, uint32_t address) {
     return fe_array_index(memoryMap->memoryMapBlocksShadow, FEMemoryMapBlock*, address/SHADOW_BLOCK_SIZE);
 }
 
 +0x00	pushq               %rbp
 +0x01	movq                %rsp, %rbp
 +0x04	shrl                $12, %esi
 +0x07	movq                8(%rdi), %rax
 +0x0b	movq                (%rax), %rax
 +0x0e	movq                (%rax,%rsi,8), %rax
 +0x12	popq                %rbp
 +0x13	retq

 */

.globl _fe_memoryMap_blockFromVirtualAddress
_fe_memoryMap_blockFromVirtualAddress:
  shrl $12, %esi
  movq 8(%rdi), %rax
  movq (%rax), %rax
  movq (%rax,%rsi,8), %rax
  retq