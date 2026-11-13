; K235 / K235+ firmware 2.0 for the NCR Decision Mate V
;
; Built on top of the NCR K235 ROM 33473 (not included here): this file
; only contains new code.  Kept from 33473: entry FF00:0003, the command
; table at 0010h, the return to the Z80 at 0018h, ROM checksum, the 8259
; test (023Ch-02C1h), keyboard/CRT drivers (02E0h-0531h) and the far
; display entry FF00:0000.  Replaced: memory test (005Dh-023Bh) and the
; monitor (0532h-0FEFh).
;
; Memory test: 4 KB blocks, three patterns (address, 55AAh, AA55h), each
; block first probed for RAM and for being a mirror of the block 512 KB
; below (no BA19 decode).  Stops at the first missing block, so it works
; with K235 (EPROM 80000h-FFFFFh), K235+ without K0815 (mirror) and K235+
; with K0815 (EPROM window at the top).  0:FE06 = 64 KB banks above
; bank 0, a partial last bank included (15 for 1020 KB).  "M" during the
; test: finish with presence checks only, then enter the monitor.
; Screen: three centred lines, colours from the mainboard ROM id at 0FF8h.
;
; Monitor: no password, upper/lower case, console = screen/keyboard and,
; if present, a K211 (2651 at 70h, IFSEL 1A) at 9600 8N1.  FF00:0632 still
; enters it.  Q runs the self test again, then the Z80 boots.
;
; Build: python MKROM.PY dmv_int_8088_pic_33473.bin k235_fw20.bin (nasm)
;
; License: MIT (code: Claude, prompts: rfka01)

        cpu     8086
        bits    16
        org     0

; ---- kept routines in 33473 ---------------------------------------------
SWITCH          equ     0018h           ; back to Z80, wait for next command
PICTEST         equ     023Ch           ; 8259/8253 test, ends at 02A7h
CRTOUT          equ     02F3h           ; AL to screen (88h=NL, 8Bh=rubout)
DELAY           equ     0522h           ; CX * ~0.1 s

; ---- RAM (bank 0) -------------------------------------------------------
CURSX           equ     0F800h
CURSY           equ     0F801h
SB16            equ     0FE01h          ; Z80 firmware version
ST16            equ     0FE05h
MEM16           equ     0FE06h

V               equ     0FD00h          ; our variables
r_ax            equ     V+00h
r_bx            equ     V+02h
r_cx            equ     V+04h
r_dx            equ     V+06h
r_sp            equ     V+08h
r_bp            equ     V+0Ah
r_si            equ     V+0Ch
r_di            equ     V+0Eh
r_ds            equ     V+10h
r_es            equ     V+12h
r_ss            equ     V+14h
r_cs            equ     V+16h
r_ip            equ     V+18h
r_fl            equ     V+1Ah
serok           equ     V+20h           ; byte: K211 present
monreq          equ     V+21h           ; byte: monitor requested ("M")
totkb           equ     V+22h           ; word: RAM size in KB
dseg            equ     V+24h           ; word: default segment
dnext           equ     V+26h           ; word: next dump offset
bpoff           equ     V+28h           ; LES order: offset, segment
bpseg           equ     V+2Ah
bpbyte          equ     V+2Ch
bpact           equ     V+2Dh
tcount          equ     V+2Eh
trapk           equ     V+30h
conmask         equ     V+31h           ; byte: bit 0 screen, bit 1 K211
savcur          equ     V+32h           ; word
bankno          equ     V+35h           ; byte: bar position
ATTR            equ     0F90Bh          ; attribute used by CRTOUT
linebuf         equ     0FC00h          ; 64 bytes
LINEMAX         equ     60

SER_D_R         equ     70h
SER_S_R         equ     71h
SER_M_R         equ     72h
SER_C_R         equ     73h
SER_D_W         equ     74h
SER_M_W         equ     76h
SER_C_W         equ     77h

; =========================================================================
        incbin  "33473.bin", 0, 10h
        dw      mon_entry, mon_entry    ; commands 0/1: monitor
        incbin  "33473.bin", 14h, 5Dh-14h
; 005Dh: after the ROM checksum
        jmp     memtest

; ---- memory test (005Dh-023Bh) ------------------------------------------
; probe block at segment BP: CF=1 if no RAM or a mirror
probe:
        push    ds
        mov     es,bp
        mov     cx,[es:0]
        mov     ax,0AA55h
        mov     [es:0],ax
        cmp     ax,[es:0]
        jne     pr_no
        cmp     bp,8000h
        jb      pr_yes
        mov     ax,bp
        sub     ax,8000h
        mov     ds,ax
        mov     si,[0]
        mov     word [0],0
        mov     word [es:0],0FFFFh
        cmp     word [0],0
        mov     [0],si
        jne     pr_no
pr_yes: mov     [es:0],cx
        pop     ds
        clc
        ret
pr_no:  mov     [es:0],cx
        pop     ds
        stc
        ret

; test 4 KB at segment BP; CF=1 on error, then DI = offset+2, AX = expected
blktest:
        mov     es,bp
        xor     di,di
        mov     cx,800h
bt_w1:  mov     ax,di
        xor     ax,bp
        stosw
        loop    bt_w1
        xor     di,di
        mov     cx,800h
bt_r1:  mov     ax,di
        xor     ax,bp
        scasw
        jne     bt_bad
        loop    bt_r1
        mov     ax,55AAh
        call    bt_fill
        jne     bt_bad
        mov     ax,0AA55h
        call    bt_fill
        jne     bt_bad
        clc
        ret
bt_bad: stc
        ret
bt_fill:
        xor     di,di
        mov     cx,800h
        rep     stosw
        xor     di,di
        mov     cx,800h
        repe    scasw
        ret

; "M" during the test
pollm:  call    getkey
        jz      pm_ret
        and     al,0DFh
        cmp     al,'M'
        jne     pm_ret
        mov     byte [monreq],1
pm_ret: ret

s_head  db      'K235 FW 2.0  RAM [',0
s_close db      '] ',0
s_kb    db      ' KB',0

; show a memory error, wait for CR (or ~10 s)
errshow:
        call    errline
        mov     si,s_cr
        call    puts
        mov     cx,100
es_wait:
        call    getkey
        jz      es_t
        cmp     al,0Dh
        je      es_go
es_t:   push    cx
        mov     cx,1
        call    DELAY
        pop     cx
        loop    es_wait
es_go:  ret

; memory error line: ES:DI-2 failed, AX expected
errline:
        push    ax
        mov     si,s_err
        call    puts
        mov     ax,es
        mov     al,ah
        mov     cl,4
        shr     al,cl
        call    puthex1
        mov     ax,es
        shl     ax,cl
        add     ax,di
        sub     ax,2
        call    puthex4
        mov     si,s_w
        call    puts
        pop     ax
        push    ax
        call    puthex4
        mov     si,s_r
        call    puts
        mov     ax,[es:di-2]
        call    puthex4
        mov     si,s_bits
        call    puts
        pop     bx
        mov     ax,[es:di-2]
        xor     ax,bx
        jmp     puthex4

s_err   db      10,'RAM ERROR ',0
s_w     db      ' W=',0
s_r     db      ' R=',0
s_bits  db      ' BITS ',0
s_cr    db      '  (CR)',0

        times   PICTEST-($-$$) db 0FFh
        incbin  "33473.bin", PICTEST, 2ADh-PICTEST
; 02ADh: end of self test, keyboard check for the monitor
        call    endpoll
        incbin  "33473.bin", 2B0h, 2B4h-2B0h
        jmp     mon_entry
        incbin  "33473.bin", 2B7h, 532h-2B7h

; ---- 0532h: console ------------------------------------------------------

; K211 present? 9600 8N1, 16x, internal BRG
ser_init:
        mov     byte [serok],0
        in      al,SER_C_R              ; reset mode pointer
        mov     al,4Eh
        out     SER_M_W,al
        mov     al,3Eh
        out     SER_M_W,al
        in      al,SER_C_R
        in      al,SER_M_R
        cmp     al,4Eh
        jne     si_ret
        in      al,SER_M_R
        cmp     al,3Eh
        jne     si_ret
        mov     al,37h                  ; RTS, err reset, RxEN, DTR, TxEN
        out     SER_C_W,al
        in      al,SER_D_R
        mov     byte [serok],1
si_ret: ret

; AL to screen and K211; 0Ah = new line, 08h = rubout
putc:   push    ax
        push    cx
        test    byte [conmask],2
        jz      pc_crt
        cmp     byte [serok],0
        je      pc_crt
        cmp     al,0Ah
        jne     pc_s
        mov     al,0Dh
        call    serout
        mov     al,0Ah
pc_s:   call    serout
        cmp     al,08h
        jne     pc_crt
        mov     al,' '
        call    serout
        mov     al,08h
        call    serout
pc_crt: pop     cx
        pop     ax
        push    ax
        test    byte [conmask],1
        jz      pc_ret
        cmp     al,0Ah
        jne     pc_c2
        mov     al,88h
        jmp     short pc_c4
pc_c2:  cmp     al,08h
        jne     pc_c3
        mov     al,8Bh
        jmp     short pc_c4
pc_c3:  cmp     al,20h
        jb      pc_ret
pc_c4:  call    CRTOUT
pc_ret: pop     ax
        ret

serout: push    ax
        mov     cx,8000h
so_w:   in      al,SER_S_R
        test    al,1
        jnz     so_go
        loop    so_w
        mov     byte [serok],0          ; stuck (CTS?): give up
        pop     ax
        ret
so_go:  pop     ax
        out     SER_D_W,al
        ret

crlf:   mov     al,0Ah
        jmp     putc
space:  mov     al,' '
        jmp     putc

; CS:SI zero terminated
puts:   cs lodsb
        or      al,al
        jz      ps_ret
        call    putc
        jmp     puts
ps_ret: ret

puthex4:
        push    ax
        mov     al,ah
        call    puthex2
        pop     ax
puthex2:
        push    ax
        push    cx
        mov     cl,4
        shr     al,cl
        pop     cx
        call    puthex1
        pop     ax
puthex1:
        and     al,0Fh
        add     al,90h
        daa
        adc     al,40h
        daa
        jmp     putc


; key from keyboard or K211, ZF=1 if none; CR = 0Dh, BS = 08h
getkey: in      al,41h
        test    al,1
        jz      gk_s
        in      al,40h
        cmp     al,88h
        jne     gk_k1
        mov     al,0Dh
gk_k1:  cmp     al,8Bh
        jne     gk_got
        mov     al,08h
        jmp     short gk_got
gk_s:   cmp     byte [serok],0
        je      gk_none
        in      al,SER_S_R
        test    al,2
        jz      gk_none
        in      al,SER_D_R
        cmp     al,7Fh
        jne     gk_got
        mov     al,08h
gk_got: or      al,al
        jnz     gk_ret
        inc     al                      ; NUL would read as "none"
gk_ret: ret
gk_none:
        xor     al,al
        ret

; 0632h: monitor entry of 33473, kept for software that jumps there
        times   632h-($-$$) db 0FFh
        jmp     mon_entry

putdec: mov     bx,10
        xor     cx,cx
pd_1:   xor     dx,dx
        div     bx
        push    dx
        inc     cx
        or      ax,ax
        jnz     pd_1
pd_2:   pop     ax
        add     al,'0'
        call    putc
        loop    pd_2
        ret

waitkey:
        call    getkey
        jz      waitkey
        ret

; end of self test (02ADh): 0Eh = enter the monitor
endpoll:
        cmp     byte [monreq],0
        jne     ep_mon
        call    getkey
        jz      ep_ret
        cmp     al,0Eh
        je      ep_ret
        and     al,0DFh
        cmp     al,'M'
        jne     ep_ret
ep_mon: mov     al,0Eh
ep_ret: ret


memtest:
        xor     ax,ax
        mov     ds,ax
        mov     es,ax
        mov     [monreq],al
        mov     [bankno],al
        mov     byte [conmask],3
        call    ser_init
        mov     ax,[CURSX]
        mov     [savcur],ax
        mov     word [totkb],64
        mov     byte [conmask],2        ; K211: one plain line
        mov     si,s_head
        call    puts
        mov     byte [conmask],1        ; screen: three centred lines
        out     11h,al                  ; mainboard ROM: " C.07.00" or " M.07.00"
        mov     al,[0FF9h]              ; at 0FF8h, first letter = video board
        out     10h,al
        mov     bx,0FCDDh               ; colour: white on red, white on black
        cmp     al,'M'
        jne     mt_att
        mov     bx,0E8E9h               ; mono: inverse, normal
mt_att: mov     word [CURSX],0A00h+37
        mov     [ATTR],bl
        mov     si,s_ncr
        call    puts
        mov     [ATTR],bh
        mov     word [CURSX],0B00h+(80-S_DMV_LEN)/2
        mov     si,s_dmv
        call    puts
        mov     word [CURSX],0D00h+25   ; row 13, after an empty line
        mov     si,s_ramb
        call    puts
        mov     word [CURSX],0D00h+46
        mov     al,']'
        call    putc
        call    showkb
        ; bank 0: only 0000h-1FFFh (rest in use)
        mov     bp,0000h
        call    blktest
        jc      mt_err
        mov     bp,0100h
        call    blktest
        jc      mt_err
        mov     al,'#'
        call    barc
        mov     cx,15                   ; banks 1..15
        cmp     byte [SB16],9           ; old Z80 firmware: 256 KB only
        jae     mt_bank
        mov     cx,3
mt_bank:
        push    cx
        xor     dx,dx                   ; block number
mt_blk:
        mov     ax,[totkb]              ; segment = KB * 64
        mov     cl,6
        shl     ax,cl
        mov     bp,ax
        call    probe
        jc      mt_stop
        cmp     byte [monreq],0
        jne     mt_ok
        call    blktest
        jc      mt_errp
mt_ok:  add     word [totkb],4
        test    byte [totkb],0Fh        ; counter every 16 KB (screen is slow)
        jnz     mt_ok2
        call    showkb
mt_ok2:
        call    pollm
        inc     dx
        cmp     dx,16
        jb      mt_blk
        mov     al,'#'
        call    barc
        pop     cx
        loop    mt_bank
        jmp     short mt_fin
mt_stop:
        pop     cx
        mov     al,'-'
        or      dx,dx
        jz      mt_stp2
        mov     al,'+'
mt_stp2:
        call    barc
        jmp     short mt_fin
mt_errp:
        pop     cx
mt_err:
        mov     byte [conmask],3
        mov     word [CURSX],0E00h
        call    errshow
mt_fin: call    showkb
        mov     byte [conmask],2        ; K211: close the line
        mov     si,s_close
        call    puts
        mov     ax,[totkb]
        call    putdec
        mov     si,s_kb
        call    puts
        call    crlf
        mov     byte [conmask],3
        mov     byte [ATTR],0E8h        ; boot messages in green again
        mov     ax,[savcur]
        mov     [CURSX],ax
        mov     ax,[totkb]
        add     ax,63                   ; a partial bank counts (K235+ with K0815:
        mov     cl,6                    ; 15, RAM ends below the EPROM at FF000h)
        shr     ax,cl
        dec     ax
        mov     [MEM16],al
        xor     ax,ax
        mov     ds,ax
        mov     es,ax
        jmp     PICTEST

; bar character AL: screen at its column, K211 in sequence
barc:   push    ax
        mov     al,[bankno]
        add     al,30
        mov     ah,0Dh
        mov     [CURSX],ax
        pop     ax
        inc     byte [bankno]
        mov     byte [conmask],3
        jmp     putc

; RAM size on the screen, row 13 column 48
showkb: push    dx
        mov     byte [conmask],1
        mov     word [CURSX],0D00h+48
        mov     ax,[totkb]
        mov     dx,' '
        cmp     ax,1000
        jae     sk_1
        xchg    ax,dx
        call    putc
        xchg    ax,dx
        cmp     ax,100
        jae     sk_1
        xchg    ax,dx
        call    putc
        xchg    ax,dx
sk_1:   call    putdec
        mov     si,s_kb
        call    puts
        mov     byte [conmask],3
        pop     dx
        ret

s_ncr   db      ' NCR ',0
s_dmv   db      'Decision Mate V   RAM test (press "M" to go to the monitor)',0
S_DMV_LEN equ   $-s_dmv-1
s_ramb  db      'RAM [',0

; ---- monitor --------------------------------------------------------------
mon_entry:
        cli
        xor     ax,ax
        mov     ds,ax
        mov     es,ax
        mov     ss,ax
        mov     sp,ax
        mov     byte [conmask],3
        mov     byte [ATTR],0E8h
        mov     al,0Ch                  ; clear the screen
        call    CRTOUT
        call    ser_init
        xor     ax,ax
        mov     di,V
        mov     cx,1Ah/2
        rep     stosw                   ; registers 0
        mov     word [r_sp],0F000h
        mov     word [r_fl],0002h
        mov     [dseg],ax
        mov     [dnext],ax
        mov     [bpact],al
        mov     [tcount],ax
        call    crlf
        mov     si,s_mon
        call    puts
        mov     ax,[totkb]
        call    putdec
        mov     si,s_kb
        call    puts
        cmp     byte [serok],0
        je      mon_loop
        mov     si,s_ser
        call    puts

mon_loop:
        xor     ax,ax
        mov     ds,ax
        mov     ss,ax
        mov     sp,0FBFEh
        mov     byte [conmask],3
        mov     word [4],trap1          ; INT 1 (again: Z may have tested 0:0)
        mov     [6],cs
        mov     word [0Ch],trap3        ; INT 3
        mov     [0Eh],cs
        call    crlf
        mov     al,'*'
        call    putc
        call    getline
        mov     si,linebuf
        call    skipsp
        or      al,al
        jz      mon_loop
        inc     si
        mov     bx,cmdtab
mc_1:   cmp     byte [cs:bx],0
        je      mon_bad
        cmp     al,[cs:bx]
        je      mc_go
        add     bx,3
        jmp     mc_1
mc_go:  call    [cs:bx+1]
        jmp     mon_loop
mon_bad:
        mov     al,'?'
        call    putc
        jmp     mon_loop

cmdtab: db      'D'
        dw      c_dump
        db      'E'
        dw      c_enter
        db      'F'
        dw      c_fill
        db      'M'
        dw      c_move
        db      'C'
        dw      c_cmp
        db      'S'
        dw      c_search
        db      'I'
        dw      c_in
        db      'O'
        dw      c_out
        db      'R'
        dw      c_reg
        db      'G'
        dw      c_go
        db      'T'
        dw      c_trace
        db      'L'
        dw      c_load
        db      'X'
        dw      c_info
        db      'Q'
        dw      c_quit
        db      'Z'
        dw      c_ztest
        db      '?'
        dw      c_help
        db      0

; read a line to linebuf (upper case, zero terminated)
getline:
        mov     di,linebuf
gl_1:   call    waitkey
        cmp     al,0Dh
        je      gl_end
        cmp     al,08h
        jne     gl_2
        cmp     di,linebuf
        je      gl_1
        dec     di
        call    putc
        jmp     gl_1
gl_2:   cmp     al,03h
        je      abort
        cmp     al,20h
        jb      gl_1
        cmp     di,linebuf+LINEMAX
        jae     gl_1
        call    putc
        cmp     al,'a'
        jb      gl_3
        cmp     al,'z'
        ja      gl_3
        sub     al,20h
gl_3:   mov     [di],al
        inc     di
        jmp     gl_1
gl_end: mov     byte [di],0
        ret

abort:  jmp     mon_loop

; Ctrl-C aborts, Ctrl-S pauses
chkbrk: call    getkey
        jz      cb_ret
        cmp     al,03h
        je      abort
        cmp     al,13h
        jne     cb_ret
        call    waitkey
        cmp     al,03h
        je      abort
cb_ret: ret

skipsp: mov     al,[si]
        cmp     al,' '
        jne     ss_r
        inc     si
        jmp     skipsp
ss_r:   ret

; hex number at SI -> AX, CF=1 if none
gethex: call    skipsp
        cmp     al,','
        jne     gh_0
        inc     si
        call    skipsp
gh_0:   xor     dx,dx
        xor     cx,cx
gh_1:   mov     al,[si]
        sub     al,'0'
        jb      gh_e
        cmp     al,9
        jbe     gh_2
        sub     al,7
        cmp     al,10
        jb      gh_e
        cmp     al,15
        ja      gh_e
gh_2:   push    cx
        mov     cl,4
        shl     dx,cl
        pop     cx
        or      dl,al
        inc     si
        inc     cx
        jmp     gh_1
gh_e:   mov     ax,dx
        cmp     cx,1
        ret                             ; CF=1 if no digit

; address [seg:]off -> ES:DI (default segment dseg), CF=1 if none
getaddr:
        call    gethex
        jc      ga_ret
        cmp     byte [si],':'
        jne     ga_off
        inc     si
        mov     [dseg],ax
        call    gethex
        jc      ga_ret
ga_off: mov     di,ax
        mov     es,[dseg]
        clc
ga_ret: ret

needhex:
        call    gethex
        jc      err_syn
        ret
needaddr:
        call    getaddr
        jc      err_syn
        ret
err_syn:
        mov     al,'?'
        call    putc
        jmp     abort

; ES:DI as SSSS:OOOO
putaddr:
        mov     ax,es
        call    puthex4
        mov     al,':'
        call    putc
        mov     ax,di
        jmp     puthex4

; D [addr [len]]
c_dump: mov     es,[dseg]
        mov     di,[dnext]
        call    getaddr
        call    gethex
        jnc     cd_go
        mov     ax,80h
cd_go:  mov     cx,ax
        jcxz    cd_end
cd_line:
        call    chkbrk
        call    crlf
        call    putaddr
        push    cx
        push    di
        mov     bx,16
cd_hex: call    space
        mov     al,[es:di]
        call    puthex2
        inc     di
        dec     bx
        jnz     cd_hex
        call    space
        call    space
        pop     di
        mov     bx,16
cd_asc: mov     al,[es:di]
        inc     di
        cmp     al,20h
        jb      cd_dot
        cmp     al,7Eh
        jbe     cd_ch
cd_dot: mov     al,'.'
cd_ch:  call    putc
        dec     bx
        jnz     cd_asc
        pop     cx
        sub     cx,16
        ja      cd_line
cd_end: mov     [dnext],di
        ret

; E addr [b ..]  without bytes: show and edit one by one
c_enter:
        call    needaddr
        call    gethex
        jc      ce_int
ce_1:   stosb
        call    gethex
        jnc     ce_1
        ret
ce_int: call    crlf
        call    putaddr
        call    space
        mov     al,[es:di]
        call    puthex2
        mov     al,'-'
        call    putc
        push    di
        call    getline
        pop     di
        mov     si,linebuf
        call    skipsp
        cmp     al,'.'
        je      ce_ret
        call    gethex
        jc      ce_nx
        mov     [es:di],al
ce_nx:  inc     di
        jmp     ce_int
ce_ret: ret

; F addr len b
c_fill: call    needaddr
        call    needhex
        push    ax
        call    needhex
        pop     cx
        rep     stosb
        ret

; M src len dst
c_move: call    needaddr
        push    es
        push    di
        call    needhex
        push    ax
        call    needaddr
        pop     cx
        pop     si
        pop     ds
        rep     movsb
        ret

; C src len dst
c_cmp:  call    needaddr
        push    es
        push    di
        call    needhex
        push    ax
        call    needaddr
        pop     cx
        pop     si
        pop     bp                      ; source segment
        jcxz    cc_ret
cc_1:   push    ds
        mov     ds,bp
        mov     bl,[si]
        pop     ds
        cmp     bl,[es:di]
        je      cc_nx
        call    chkbrk
        call    crlf
        push    es
        push    di
        mov     es,bp
        mov     di,si
        call    putaddr
        call    space
        mov     al,bl
        call    puthex2
        call    space
        pop     di
        pop     es
        mov     al,[es:di]
        call    puthex2
        call    space
        call    putaddr
cc_nx:  inc     si
        inc     di
        loop    cc_1
cc_ret: ret

; S addr len b [b ..]
c_search:
        call    needaddr
        call    needhex
        push    ax                      ; length (gethex uses CX, DX)
        mov     bx,linebuf+40h          ; pattern buffer
cs_p:   call    gethex
        jc      cs_go
        mov     [bx],al
        inc     bx
        cmp     bx,linebuf+50h
        jb      cs_p
cs_go:  pop     cx
        mov     dx,bx
        sub     dx,linebuf+40h
        jz      err_syn
        jcxz    cs_ret
cs_1:   push    cx
        push    di
        mov     si,linebuf+40h
        mov     cx,dx
cs_2:   mov     al,[si]
        cmp     al,[es:di]
        jne     cs_no
        inc     si
        inc     di
        loop    cs_2
        pop     di
        push    di
        call    chkbrk
        call    crlf
        call    putaddr
cs_no:  pop     di
        pop     cx
        inc     di
        loop    cs_1
cs_ret: ret

; I port / O port b
c_in:   call    needhex
        mov     dx,ax
        in      al,dx
        push    ax
        call    space
        pop     ax
        jmp     puthex2
c_out:  call    needhex
        push    ax
        call    needhex
        pop     dx
        out     dx,al
        ret

; R [reg val]
c_reg:  call    skipsp
        or      al,al
        jz      showregs
        mov     ah,[si+1]
        add     si,2
        mov     bx,regnam
        xor     cx,cx
cr_1:   cmp     ax,[cs:bx]
        je      cr_set
        add     bx,2
        inc     cx
        cmp     cx,14
        jb      cr_1
        jmp     err_syn
cr_set: push    cx
        call    needhex
        pop     bx
        shl     bx,1
        mov     [V+bx],ax
        ret

regnam: db      'AXBXCXDXSPBPSIDIDSESSSCSIPFL'

showregs:
        call    crlf
        mov     bx,regnam
        mov     si,V
        mov     cx,14
sr_1:   cmp     cx,6
        jne     sr_2
        call    crlf
sr_2:   mov     al,[cs:bx]
        call    putc
        mov     al,[cs:bx+1]
        call    putc
        mov     al,'='
        call    putc
        mov     ax,[si]
        call    puthex4
        call    space
        add     bx,2
        add     si,2
        loop    sr_1
        ; bytes at CS:IP
        mov     es,[r_cs]
        mov     di,[r_ip]
        mov     cx,6
sr_3:   call    space
        mov     al,[es:di]
        call    puthex2
        inc     di
        loop    sr_3
        ret

; G [addr] [bp]
c_go:   mov     word [tcount],0
        call    getaddr
        jc      cg_run
        mov     [r_cs],es
        mov     [r_ip],di
        call    getaddr
        jc      cg_run
        mov     [bpseg],es
        mov     [bpoff],di
        mov     al,[es:di]
        mov     [bpbyte],al
        mov     byte [es:di],0CCh
        mov     byte [bpact],1
cg_run: and     word [r_fl],0FEFFh
        jmp     resume

; T [n]
c_trace:
        mov     ax,1
        call    gethex
        jnc     ct_1
        mov     ax,1
ct_1:   or      ax,ax
        jz      ct_ret
        mov     [tcount],ax
        or      word [r_fl],0100h
        jmp     resume
ct_ret: ret

resume: cli
        mov     ss,[r_ss]
        mov     sp,[r_sp]
        push    word [r_fl]
        push    word [r_cs]
        push    word [r_ip]
        mov     ax,[r_ax]
        mov     bx,[r_bx]
        mov     cx,[r_cx]
        mov     dx,[r_dx]
        mov     bp,[r_bp]
        mov     si,[r_si]
        mov     di,[r_di]
        mov     es,[r_es]
        mov     ds,[r_ds]
        iret

trap1:  push    ds
        push    ax
        xor     ax,ax
        mov     ds,ax
        mov     byte [trapk],1
        jmp     short trapc
trap3:  push    ds
        push    ax
        xor     ax,ax
        mov     ds,ax
        mov     byte [trapk],3
trapc:  pop     word [r_ax]
        pop     word [r_ds]
        pop     word [r_ip]
        pop     word [r_cs]
        pop     word [r_fl]
        mov     [r_sp],sp
        mov     [r_ss],ss
        mov     [r_bx],bx
        mov     [r_cx],cx
        mov     [r_dx],dx
        mov     [r_bp],bp
        mov     [r_si],si
        mov     [r_di],di
        mov     [r_es],es
        mov     ss,ax
        mov     sp,0FBFEh
        and     word [r_fl],0FEFFh
        cmp     byte [bpact],0
        je      tc_1
        les     di,[bpoff]              ; bpoff, bpseg
        mov     al,[bpbyte]
        mov     [es:di],al
        mov     byte [bpact],0
        cmp     byte [trapk],3
        jne     tc_1
        dec     word [r_ip]
tc_1:   call    showregs
        cmp     word [tcount],0
        je      tc_2
        dec     word [tcount]
        jz      tc_2
        call    chkbrk
        or      word [r_fl],0100h
        jmp     resume
tc_2:   jmp     mon_loop

; L: Intel HEX from the console, type 02 sets the segment
c_load: mov     si,s_load
        call    puts
        mov     bp,[dseg]
cl_rec: call    waitkey
        cmp     al,03h
        je      cl_ret
        cmp     al,':'
        jne     cl_rec
        xor     bl,bl                   ; checksum
        call    rdbyte
        mov     cl,al
        xor     ch,ch
        call    rdword
        mov     di,ax
        call    rdbyte                  ; type
        mov     dl,al
        mov     es,bp
        cmp     dl,1
        je      cl_end
        cmp     dl,2
        je      cl_seg
        jcxz    cl_ck
cl_d:   call    rdbyte
        cmp     dl,0
        jne     cl_d2                   ; types 03-05: skip
        stosb
cl_d2:  loop    cl_d
cl_ck:  call    rdbyte
        or      bl,bl
        jnz     cl_bad
        mov     al,'.'
        call    putc
        jmp     cl_rec
cl_seg: call    rdword
        mov     bp,ax
        jmp     cl_ck
cl_bad: mov     al,'!'
        call    putc
        jmp     cl_rec
cl_end: call    rdbyte
cl_ret: mov     [dseg],bp
        ret

rdword: call    rdbyte
        mov     ah,al
        push    ax
        call    rdbyte
        pop     dx
        mov     ah,dh
        ret
rdbyte: push    cx
        call    rdnib
        mov     cl,4
        shl     al,cl
        mov     dh,al
        call    rdnib
        or      al,dh
        add     bl,al
        pop     cx
        ret
rdnib:  call    waitkey
        cmp     al,'a'
        jb      rn_1
        sub     al,20h
rn_1:   sub     al,'0'
        cmp     al,9
        jbe     rn_r
        sub     al,7
rn_r:   and     al,0Fh
        ret

; X: firmware, RAM, mailbox, K211, 8087
c_info: call    crlf
        mov     si,s_mon
        call    puts
        mov     ax,[totkb]
        call    putdec
        mov     si,s_kb
        call    puts
        mov     si,s_mbx
        call    puts
        mov     si,0FE00h
        mov     cx,16
ci_1:   call    space
        lodsb
        call    puthex2
        loop    ci_1
        mov     si,s_k211
        call    puts
        mov     al,[serok]
        call    yesno
        mov     si,s_fpu
        call    puts
        fninit
        mov     word [linebuf],0FFFFh
        fnstsw  [linebuf]
        mov     ax,[linebuf]
        or      al,al
        mov     al,0
        jnz     ci_2
        inc     al
ci_2:   jmp     yesno
yesno:  mov     si,s_no
        or      al,al
        jz      yn_1
        mov     si,s_yes
yn_1:   jmp     puts

; Z [from [to]]  RAM test of segments from..to (4 KB blocks, destroys the
; contents), default 1000h up to the end of RAM; 0:F000 (monitor) is skipped
c_ztest:
        mov     ax,[totkb]
        mov     cl,6
        shl     ax,cl
        push    ax                      ; default end
        mov     ax,1000h
        call    gethex
        jnc     cz_1
        mov     ax,1000h
cz_1:   and     ax,0FF00h
        mov     bp,ax
        call    gethex
        pop     bx
        jc      cz_2
        mov     bx,ax
cz_2:   xor     dx,dx                   ; error count
        call    crlf
cz_blk: cmp     bp,bx
        jae     cz_end
        cmp     bp,0F00h
        je      cz_nx
        test    bp,0F00h
        jnz     cz_t
        mov     al,'.'                  ; one dot per 64 KB
        call    putc
cz_t:   push    bx
        push    dx
        call    blktest
        pop     dx
        pop     bx
        jnc     cz_nx
        inc     dx
        push    bx
        push    dx
        call    errline
        call    crlf
        pop     dx
        pop     bx
cz_nx:  call    chkbrk
        add     bp,100h
        jnz     cz_blk
cz_end: call    space
        mov     ax,dx
        call    putdec
        mov     si,s_errs
        jmp     puts

; Q: clear the screen and run the self test again from the memory test on;
; it ends as at power-on (8259 test, then back to the Z80, which boots)
c_quit: call    crlf
        cli
        xor     ax,ax
        mov     ds,ax
        mov     ss,ax
        mov     sp,ax
        mov     al,0Ch
        call    CRTOUT
        jmp     memtest

c_help: mov     si,s_help
        jmp     puts

s_mon   db      'K235 FW 2.0 MONITOR  RAM ',0
s_ser   db      '  K211',0
s_mbx   db      10,'FE00:',0
s_k211  db      10,'K211 ',0
s_fpu   db      '  8087 ',0
s_yes   db      'YES',0
s_no    db      'NO',0
s_load  db      'HEX...',0
s_errs  db      ' ERRORS',0
s_help  db      10,'D [a [n]]  E a [b..]  F a n b  M a n a2  C a n a2'
        db      10,'S a n b..  I p  O p b  R [rr v]  G [a [bp]]  T [n]'
        db      10,'Z [s1 [s2]] (RAM test)  L (HEX)  X (info)  Q (test, boot)'
        db      10,'a = [seg:]off',0

        times   0FF0h-($-$$) db 0FFh
        incbin  "33473.bin", 0FF0h, 0Fh
chk:    db      0                       ; set by the build script
