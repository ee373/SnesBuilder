#!/usr/bin/env python3
"""Restricted-SOP structural estimator, not a Verilog compiler or vendor fitter.
Reads the explicit scalar assign statements in sfcbuilder_bridge.v. Each group
must have <=12 distinct inputs, <=8 distinct product terms, <=4 outputs.
The sequential D equations are packed separately by clock domain; reset/clock
use dedicated macrocell resources. No DSI routing or timing is modeled.
"""
from pathlib import Path
import re,itertools,random,json,collections
P=Path(__file__).resolve().parent
rtl=(P/'sfcbuilder_bridge.v').read_text()
rx=r'^assign (\S+) = (.*?); // (comb|ff_host|ff_sys)$'
rows=[]
for n,expr,kind in re.findall(rx,rtl,re.M):
    invert=expr.startswith('~(') # whole-output polarity handled by C macrocell
    if invert: expr=expr[2:-1]
    terms=[frozenset(t.strip() for t in v.strip().strip('()').split('&')) for v in expr.split('|')]
    rows.append((n,terms,invert,kind))
assert len(rows)==sum(x.startswith('assign ') for x in rtl.splitlines())
# alias/constant outputs are wires, except FFs (always cost one macrocell).
def alias(r):
    n,t,inv,k=r
    return k=='comb' and not inv and len(t)==1 and len(t[0])==1 and not next(iter(t[0])).startswith('~')
# substitute simple combinational aliases when consumed by actual equations
aliases={n:next(iter(t[0])) for n,t,_,k in rows if alias((n,t,False,k))}
# No alias above is an intermediate except outputs; retain original D equations.
# Collapse constants and count explicit negative wire as one PT/output.
logic=[r for r in rows if not alias(r)]
def resources(group):
    terms=set().union(*(set(r[1]) for r in group))
    pins={x.lstrip('~') for t in terms for x in t if x not in ("1'b0","1'b1")}
    return len(pins),len(terms),len(group)
def fits(group):return all(a<=b for a,b in zip(resources(group),(12,8,4)))
best=None
for seed in range(250):
    rng=random.Random(seed); groups=[]
    for kind in ('comb','ff_host','ff_sys'):
        items=[r for r in logic if r[3]==kind]; rng.shuffle(items)
        items.sort(key=lambda r:(-resources([r])[1],-resources([r])[0]) if seed%3==0 else (-resources([r])[0],) if seed%3==1 else (0,))
        bins=[]
        for r in items:
            assert fits([r]), r
            opts=[(i,resources(g+[r])) for i,g in enumerate(bins) if fits(g+[r])]
            if opts:
                i=min(opts,key=lambda x:(x[1][0]-resources(bins[x[0]])[0],x[1][1]-resources(bins[x[0]])[1],-len(bins[x[0]])))[0];bins[i].append(r)
            else: bins.append([r])
        groups+=bins
    if best is None or len(groups)<len(best):best=groups
report={'assignments':len(rows),'wire_or_constant_aliases':len(rows)-len(logic),'macrocells':len(logic),'ff':sum(r[3]!='comb' for r in logic),'product_terms_before_sharing':sum(len(r[1]) for r in logic),'product_terms_packed':sum(resources(g)[1] for g in best),'plds':len(best),'groups':[]}
for i,g in enumerate(best,1):
    assert fits(g)
    a,b,c=resources(g);report['groups'].append({'pld':i,'clock':g[0][3],'inputs':a,'pts':b,'mc':c,'outputs':[r[0] for r in g]})
# Evaluate actual equations via their parsed Boolean product terms. This does
# not parse Verilog always blocks. FF edges are driven by the reference below.
def eval_rtl(inp):
    d=dict(inp);d.update({"1'b0":0,"1'b1":1})
    def lit(x):return (1^d[x[1:]]) if x.startswith('~') else d[x]
    for n,t,inv,k in rows:
        d[n]=int(any(all(lit(x) for x in term) for term in t))^int(inv)
    return d
base={x:0 for x in 'rst_n sfc_reset_n enabled romsel_n rd_n wr_n a12 a13 a14 a15 a21 a22 a23 hi_enable ex_enable extension_enable arm_ce arm_ram arm_rd arm_wr arm_ack arm_irq_mask arm_irq_pending cmd_seq cmd_meta cmd_sync'.split()}
for n,w in [('a_lo',6),('sfc_di',8),('mem_di',8),('arm_reply',8),('bus_mode',2),('cmd_data',8),('cmd_kind',2)]:
    base.update({f'{n}[{i}]':0 for i in range(w)})
base.update(rst_n=1,sfc_reset_n=1,enabled=1,hi_enable=1,ex_enable=1,extension_enable=1,rd_n=0,wr_n=1)
def address(d,a):
    for i in [12,13,14,15,21,22,23]:d[f'a{i}']=(a>>i)&1
    for i in range(6):d[f'a_lo[{i}]']=(a>>i)&1
    b=a>>16;off=a&65535
    d['romsel_n']=int(not (b not in (0x7e,0x7f) and ((b&0x40)!=0 or off>=0x8000)))
def value(d,n,w):return sum(d[f'{n}[{i}]']<<i for i in range(w))
def setvalue(d,n,w,v):d.update({f'{n}[{i}]':(v>>i)&1 for i in range(w)})
# Enumerate all 256 banks x high hex nibble x SRAM mode. Other offset bits
# cannot affect either window expression (confirmed by direct parsing).
count=0
for bank,nibble,hi,ex in itertools.product(range(256),range(16),range(2),range(2)):
    off=nibble<<12; d=base.copy();d.update(hi_enable=hi,ex_enable=ex);address(d,(bank<<16)|off)
    q=eval_rtl(d)
    sys=(bank&0x40)==0; io=sys and 0x5000<=off<0x6000; ram=sys and 0x6000<=off<0x8000 and bool(((bank&0x20) and hi) or ((bank&0x80) and ex))
    assert q['io_win']==io and q['ram_win']==ram
    assert (not q['ce_rom_n'])== (not d['romsel_n']) and (not q['ce_ram_n'])==ram
    assert q['mem_dsi_addr[22]']==(not (bank&0x80))
    assert not(not q['ce_rom_n'] and not q['ce_ram_n']);count+=1
# Owner, direction, control and reset combinations on representative regions.
ctrl_count=0
for a,mode,rd,wr,ce,ar,aw,ram,enable,reset,sreset in itertools.product([0x005000,0x005001,0x005002,0x005003,0x005007,0x005008,0x005009,0x206000,0xc00000,0x7e0000],range(4),*[range(2)]*9):
    d=base.copy();address(d,a);setvalue(d,'bus_mode',2,mode);d.update(rd_n=rd,wr_n=wr,arm_ce=ce,arm_rd=ar,arm_wr=aw,arm_ram=ram,enabled=enable,rst_n=reset,sfc_reset_n=sreset,arm_irq_mask=1,arm_irq_pending=1)
    q=eval_rtl(d); live=enable and reset; host=live and mode==0 and sreset; arm=live and mode==3
    assert q['buf_oe_n']==(not host) and q['bypass_addr_oe']==bool(arm) and q['direct_addr_oe']==bool(host or arm)
    assert not(not q['ce_rom_n'] and not q['ce_ram_n'])
    assert not(not q['mem_oe_n'] and not q['mem_we_n'])
    assert not(q['mem_d_oe'] and not q['mem_oe_n'])
    if not q['mem_we_n']:assert not(q['ce_rom_n'] and q['ce_ram_n'])
    if not (host or arm):assert q['ce_rom_n'] and q['ce_ram_n'] and q['mem_oe_n'] and q['mem_we_n'] and not q['mem_d_oe']
    if not rd and wr and live and sreset:assert q['sfc_d_oe']==bool((host and a in [0x206000,0xc00000]) or a in [0x005001,0x005002,0x005003,0x005007,0x005008])
    else:assert not q['sfc_d_oe']
    assert q['irq_assert']==bool(host);ctrl_count+=1
# Directed mailbox test and 64 aliases per bank across all register offsets.
mail_count=0
for mode,bank,mirror,reg in itertools.product((0,1,2,3),(0,0x20,0x80,0xbf),range(64),range(64)):
    d=base.copy();address(d,(bank<<16)|0x5000|(mirror<<6)|reg);setvalue(d,'bus_mode',2,mode);d.update(rd_n=1,wr_n=0);setvalue(d,'sfc_di',8,0xa5)
    q=eval_rtl(d);accept=(reg in (0,3,7,8));assert q['accept']==accept
    assert q['cmd_seq_d']==accept
    if accept:
        assert sum(q[f'cmd_data_d{i}']<<i for i in range(8))==0xa5
        assert sum(q[f'cmd_kind_d{i}']<<i for i in range(2))=={0:0,3:1,7:2,8:3}[reg]
    mail_count+=1
# Toggle handshake: emulate the two always blocks as specified, no HDL timing.
d=base.copy();address(d,0x005000);d.update(rd_n=1,wr_n=0);setvalue(d,'sfc_di',8,0x53)
q=eval_rtl(d);d['cmd_seq']=q['cmd_seq_d'];setvalue(d,'cmd_data',8,sum(q[f'cmd_data_d{i}']<<i for i in range(8)))
assert eval_rtl(d)['busy']==1 and not eval_rtl(d)['accept']
for _ in range(2):
    q=eval_rtl(d);d['cmd_meta']=q['cmd_meta_d'];d['cmd_sync']=q['cmd_sync_d']
assert eval_rtl(d)['arm_request']==1;d['arm_ack']=d['cmd_sync'];assert not eval_rtl(d)['busy'] and not eval_rtl(d)['arm_request']
# Directed full-byte read check, independent expected data values.
read_count=0
for mode,off,pending,mask,busyflag in itertools.product(range(4),[0x5001,0x5002,0x5003,0x5007,0x5008,0x6000,0x8000],range(2),range(2),range(2)):
    d=base.copy();address(d,0x800000|off);setvalue(d,'bus_mode',2,mode);d.update(arm_irq_pending=pending,arm_irq_mask=mask,cmd_seq=busyflag);setvalue(d,'mem_di',8,0xa5);setvalue(d,'arm_reply',8,0x69)
    q=eval_rtl(d); arm=mode==3; host=mode==0
    expected={0x5001:busyflag|(arm<<1)|(pending<<2),0x5002:0x69,0x5003:int(arm)|(int(not host and not arm)<<1),0x5007:mask,0x5008:pending,0x6000:0xa5 if host else None,0x8000:0xa5 if host else None}[off]
    assert q['sfc_d_oe']==(expected is not None)
    if expected is not None:assert value(q,'sfc_do',8)==expected
    read_count+=1
report['checks']={'directed_read_values':read_count,'bank_nibble_sram_modes':count,'owner_direction_reset_controls':ctrl_count,'register_alias_writes':mail_count,'mailbox_model':'PASS'}
(P/'estimate.json').write_text(json.dumps(report,indent=2));print(json.dumps({k:v for k,v in report.items() if k!='groups'},indent=2))
for g in report['groups']:print(g['pld'],g['clock'],g['inputs'],g['pts'],g['mc'],', '.join(g['outputs']))
