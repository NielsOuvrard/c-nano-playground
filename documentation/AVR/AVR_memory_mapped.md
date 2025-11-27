
# ID F KNOW


## Memory-Mapped I/O

```mermaid
graph LR
    subgraph IO["I/O Space (0x00-0x3F)"]
        A["0x03: PINB <br/> Input"]
        B["0x04: DDRB <br/> Direction"]
        C["0x05: PORTB <br/> Output"]
    end
    
    subgraph Extended["Extended I/O (0x40-0xFF)"]
        D["0x80: TIMSK0 <br/> Timer mask"]
        E["0xC0: UDR0 <br/> UART data"]
    end
    
    subgraph SRAM["SRAM (0x100-0x8FF)"]
        F["0x100: .data"]
        G["0x8FF: Stack"]
    end
    
    A -.->|in/out| H[Direct access]
    D -.->|lds/sts| I[Memory access]
    F -.->|ld/st| I
    
    style IO fill:#333,color:#fff
    style Extended fill:#333,color:#fff
    style SRAM fill:#333,color:#fff
```

### I/O Access Examples
```asm
; Direct I/O (0x00-0x3F)
sbi 0x04, 5        ; Set bit in DDRB
in r16, 0x05       ; Read PORTB

; Extended I/O (0x40-0xFF)
lds r16, 0x0080    ; Read TIMSK0
sts 0x0080, r16    ; Write TIMSK0

; SRAM
ld r16, X          ; Load from address in X
st X, r16          ; Store to address in X
```

