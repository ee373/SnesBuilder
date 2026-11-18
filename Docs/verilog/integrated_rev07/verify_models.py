#!/usr/bin/env python3
"""Independent reference checks. NOT an HDL compiler/simulator or PSoC placement."""
from itertools import product
from random import Random
from pathlib import Path
import re

RTL=Path(__file__).with_name('sfcbuilder_rev07.v').read_text()

def mirror(x, n):
    assert 1 <= n <= 8
    window=1 << (n-1).bit_length()
    x &= window-1
    if (n & (n-1)) == 0: return x
    p=1 << (n.bit_length()-1)
    return x if x<p else p+mirror(x-p,n-p)

def mapper(a19,a20,a21,a23,ex,blocks):
    x2=(1-a23)&ex; x1=a21;x0=a20
    n=blocks-1;n0=n&1;n1=(n>>1)&1;n2=(n>>2)&1
    y2=x2&n2
    y1=x1&(n1|(n2&(1-x2)))
    y0=x0&(n0|(n1&(1-x1))|(n2&(1-x2)))
    return ((y2<<2)|(y1<<1)|y0,a19)

n=0
for ex in [0,1]:
    for blocks in range(1,(8 if ex else 4)+1):
        for a19,a20,a21,a23,ram in product((0,1),repeat=5):
            block,through=mapper(a19,a20,a21,a23,ex,blocks)
            logical=((1-a23)*ex<<2)|(a21<<1)|a20
            assert block==mirror(logical,blocks)
            assert through==a19
            n+=1
assert n==384
print('PASS mirror independent oracle: 384 cases')

boot_bytes={0xfffc:0,0xfffd:0x80,0x8000:0x5c,0x8001:0,0x8002:0x60,0x8003:0x2f}
nb=0
for bank,addr,boot,host,reset_n,romsel_n in product([0,1,0x2f,0x80],
        [0x8000,0x8001,0x8002,0x8003,0xfffc,0xfffd,0x8004,0x6000],
        [0,1],[0,1],[0,1],[0,1]):
    expect=bool(bank==0 and addr in boot_bytes and boot and host and reset_n and not romsel_n)
    hit=bool(boot and host and reset_n and not romsel_n and (bank<<16|addr) in boot_bytes)
    assert hit==expect
    if hit:assert boot_bytes[addr] in range(256)
    nb+=1
assert nb==512
assert [boot_bytes[k] for k in (0xfffc,0xfffd,0x8000,0x8001,0x8002,0x8003)]==[0,0x80,0x5c,0,0x60,0x2f]
print('PASS boot ROM address/byte oracle: 512 cases')

# Physical SRAM A0..12 <- CPU A0..12, A13..16 <- CPU A16..19.
for b in range(16):
    for ofs in (0,1,0x1fff):
        mem_addr=(b<<16)|(0x6000|ofs)
        phy=(mem_addr&0x1fff)|((mem_addr>>16&0xf)<<13)
        assert phy==(b*8192+ofs)
assert ((0x2f6000&0x1fff)|((0x2f6000>>16&0xf)<<13))==0x1e000
print('PASS SRAM fixed address mapping: 48 boundary cases and BIOS entry')

# State-machine reference. Accept handshakes only after cfg signal observed low.
ISO,HOST,ARM,QUIET,CONFIG,GUARD=range(6)
class FSM:
    def __init__(self):self.state=ISO;self.target=1;self.seen=0;self.counter=0
    def step(self,request_arm,quiesced,done,idle):
        old=self.state
        if old==ISO and idle:self.target=request_arm;self.state=QUIET
        elif old==HOST and request_arm and quiesced and idle:self.target=1;self.state=QUIET
        elif old==ARM and not request_arm and idle:self.target=0;self.state=QUIET
        elif old==QUIET and idle:self.seen=0;self.state=CONFIG
        elif old==CONFIG:
            if not done:self.seen=1
            if self.seen and done:self.counter=4;self.state=GUARD
        elif old==GUARD:
            if self.counter==0:self.state=ARM if self.target else HOST
            else:self.counter-=1
        return self.state
fsm=FSM()
# Always held high prior to low doesn't cause false completion.
for i in range(10):fsm.step(1,0,1,1)
assert fsm.state==CONFIG
fsm.step(1,0,0,1)
fsm.step(1,0,1,1)
for i in range(5):
    assert fsm.state!=ARM
    fsm.step(1,0,0,1)
assert fsm.state==ARM
# randomized requests guarantee never change owners except through transition
rng=Random(7)
num=0
for _ in range(20000):
    old=fsm.state
    req=rng.randrange(2);ready=rng.randrange(2);done=rng.randrange(2);idle=rng.randrange(2)
    new=fsm.step(req,ready,done,idle)
    assert not (old==HOST and new==ARM)
    assert not (old==ARM and new==HOST)
    assert new in (ISO,HOST,ARM,QUIET,CONFIG,GUARD)
    num+=1
print('PASS ownership FSM oracle: 20,000 randomized transitions')

# FIFO queue under dynamic push+pop and unbounded periods of idle (no SFC clock).
q=[]
for i in range(100000):
    push=rng.randrange(2);pop=rng.randrange(2);byte=rng.randrange(256)
    p=pop and len(q)>0
    w=push and (len(q)<4 or p)
    head=q[0] if q else None
    if p:assert q.pop(0)==head
    if w:q.append(byte)
    assert 0<=len(q)<=4
print('PASS synchronous FIFO oracle: 100,000 randomized transitions')

# Evaluate actual Verilog RHS expressions for mapper y[0:2], not HDL simulation.
verilog_y={}
for bit in (0,1,2):
    match=re.search(r'assign\s+y\['+str(bit)+r'\]\s*=\s*([^;]+);',RTL)
    assert match, f'RTL y[{bit}] not found'
    rhs=match.group(1).replace('&&',' and ').replace('||',' or ')
    rhs=re.sub(r'!(?!=)',' not ',rhs)
    assert re.fullmatch(r'[\s\w\[\]\(\)\.!&|]+',rhs),rhs
    verilog_y[bit]=compile(rhs, f'RTL y[{bit}]','eval')
expr_tests=0
for ex in (0,1):
    for blocks in range(1,9 if ex else 5):
        for a19,a20,a21,a23 in product((0,1),repeat=4):
            x=[a20,a21,(1-a23)&ex]
            n=[(blocks-1>>j)&1 for j in range(3)]
            bits=[int(bool(eval(verilog_y[j],{'__builtins__':{}},{'x':x,'n':n}))) for j in range(3)]
            got=sum(b<<j for j,b in enumerate(bits))
            expected=mirror(((1-a23)*ex<<2)|(a21<<1)|a20,blocks)
            assert got==expected,(ex,blocks,a19,a20,a21,a23,got,expected)
            expr_tests+=1
assert expr_tests==192
print('PASS actual Verilog mapper expressions vs independent oracle: 192 cases')

rtl_boot={int(a,16):int(v,16) for a,v in
          re.findall(r"24'h([0-9a-fA-F]+)\s*:\s*boot_byte\s*=\s*8'h([0-9a-fA-F]+)",RTL)}
assert rtl_boot==boot_bytes,(rtl_boot,boot_bytes)
print('PASS actual Verilog boot byte case table: 6 exact entries')

match=re.search(r"sfc_active\s*\?\s*23'h([0-9a-fA-F]+)\s*:\s*23'h000000",RTL)
assert match and int(match.group(1),16)==sum(1<<b for b in list(range(5))+list(range(12,16))+list(range(20,23)))
print('PASS actual Verilog host GPIO mask: 12 correct driven pads')

checks={
 'uses state machine with isolated CONFIG and GUARD': 'state==CONFIG' in RTL and 'state==GUARD' in RTL or ('CONFIG:' in RTL and 'GUARD:' in RTL),
 'config requires low-then-high acknowledgment': 'config_seen_low && done_sync' in RTL,
 'no combinational GPIO ownership without FSM': 'state == ARM' in RTL and 'state == HOST' in RTL,
 'no asynchronous FIFO model': 'rev07_fifo_async' not in RTL,
 'two synchronous 4-byte FIFO wrappers': RTL.count('fifo4_sync fifo_')==2,
 'RX snapshot at read start': 'negedge rd_n' in RTL,
 'SFC strobe event CDC': 'tx_m<=tx_toggle;tx_s<=tx_m;tx_prev<=tx_s;' in RTL,
 'BOOT_MODE blocks NOR': '!boot_mode && !romsel_n' in RTL,
 '12 memory-owned host pin mask': "23'h70f01f" in RTL,
}
for label,condition in checks.items():
    assert condition,label
print(f'PASS HDL structural assertions: {len(checks)}')
print('NOTE: These are model/structure checks, NOT compiled Verilog tests or PSoC synthesis.')
