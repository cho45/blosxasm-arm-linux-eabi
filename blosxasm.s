/*#!as --gstabs+ -o blosxasm.o blosxasm.s && ld -o blosxasm -e _start blosxasm.o && objdump -d -j .text -j .data blosxasm && ./blosxasm
 */

.global _start

.macro sys_exit
    mov r7, $0x01 /* set system call number to 1 (exit) */
    svc $0x00     /* supervisor call  */
.endm

.macro sys_read
    mov r7, $0x03
    svc $0x00     /* supervisor call  */
.endm

.macro sys_write
    mov r7, $0x04
    svc $0x00     /* supervisor call  */
.endm

O_RDONLY = 0x0000
.macro sys_open
    mov r7, $0x05
    svc $0x00     /* supervisor call  */
.endm

.macro sys_close
    mov r7, $0x06
    svc $0x00     /* supervisor call  */
.endm

.macro sys_getdents
    mov r7, $0x8d
    svc $0x00     /* supervisor call  */
.endm

.macro sys_stat
    mov r7, $0x6a
    svc $0x00     /* supervisor call  */
.endm

.macro sys_brk
    mov r7, $0x2d
    svc $0x00     /* supervisor call  */
.endm

PROT_NONE = 0x00
PROT_READ = 0x01
PROT_WRITE = 0x02
PROT_EXEC = 0x04
MAP_ANONYMOUS = 0x20
MAP_PRIVATE = 0x02
.macro sys_mmap
    mov r7, $0xc0 /* sys_mmap_pgoff */
    svc $0x00     /* supervisor call  */
.endm

.macro sys_munmap
    mov r7, $0x5b
    svc $0x00     /* supervisor call  */
.endm

.macro sys_mremap
    mov r7, $0xa3
    svc $0x00     /* supervisor call  */
.endm


.section .data
brk: .word 0

config:
    var_title:
        .ascii "blosxasm-arm-linux-eabi"
        var_title_len = . - var_title
        .align 2
    var_home:
        .ascii "/blosxasm.cgi/"
        var_home_len = . - var_home
        .align 2
    var_data_dir:
        .asciz "data/"
        .align 2
    var_head_path:
        .asciz "head.html"
        .align 2
    var_story_path:
        .asciz "story.html"
        .align 2
    var_foot_path:
        .asciz "foot.html"
        .align 2


.section .text
_start:
        mov lr, #0

        /* r0 = argc (not used) */
        ldr r0, [sp]
        /* r1 = argv (not used) */
        add r1, sp, $0x04

        /* r2 = argc * 4 (skip argv) */
        mov r3, $0x04
        mul r2, r0, r3
        /* skip null word */
        add r2, r2, $0x04
        add r2, r1

        /* save char** environ */
        ldr r0, =environ
        str r2, [r0]

        bl main

        mov r0, $0xff
        sys_exit

main:
        adr r0, PATH_INFO
        bl getenv
        cmp r0, $0x00 /* if env is not set */
        adreq r0, PATH_INFO_default
        mov v5, r0 /* v5 = PATH_INFO */
        bl strlen
        cmp r0, $0x00 /* if env is set but empty */
        adreq v5, PATH_INFO_default


        ldr r0, =var_head_path
        bl template

        /**
         * append entry to brk (like dynamic array)
         */
        mov r0, $0x00
        bl sbrk
        mov v1, r0 /* v1 = first brk */

        ldr r0, =var_data_dir
        ldr r1, =file_callback
        bl dentries

        /**
         * loop each entry
         */
        ldr v2, =entries_count
        ldr v2, [v2] /* v2 = entry count */

        ldr v3, =current_entry /* v3 = pointer to current entry address */

        main_entry_loop:
            str v1, [v3]

            /* findstr(entry.name, path_info+1, strlen(path_info)-1) */
            mov r0, v5
            bl strlen
            sub r2, r0, #1
            add r0, v1, #entry_path
            add r1, v5, #1
            bl findstr
            cmp r0, $0x00

            ldreq r0, =var_story_path
            bleq template

            sub v2, v2, $0x01
            cmp v2, $0x00
            add v1, v1, #entry_buffer_len
            bne main_entry_loop

        ldr r0, =var_foot_path
        bl template


        mov r0, $0x00 /* set exit status to 0 */
        ldr r1, =buffer
        sys_exit

file_callback:
        stmfd sp!, {r1-r3, v1-v5, lr}

        mov v1, r0 /* v1 = name */
        mov v2, r1 /* v2 = name_len */

        /* skip . files */
        ldrb r0, [v1]
        cmp r0, #'.
        bleq 1f

        mov r0, v1
        bl read_entry

1:
        ldmfd sp!, {r1-r3, v1-v5, pc}

USER:
        .asciz "USER"
        .align 2

PATH_INFO:
        .asciz "PATH_INFO"
        .align 2

PATH_INFO_default:
        .asciz "/"
        .align 2

error:
        cmp r0, $0x00
        moveq r0, $0x01
        sys_exit

divmod: /* uint numerator, uint devider -> quo, rem */
        stmfd sp!, {v1-v5, lr}
        mov v1, r0 /* num */
        mov v2, r1 /* div */

        mov r0, $0x00 /* quo */
        mov r1, $0x00 /* rem */
        mov r2, #32 /* i */
1:
        sub r2, r2, $0x01
        /* rem = rem << 1*/
        mov r1, r1, LSL #1
        /* num >> i */
        mov r3, v1, LSR r2
        /* num & 1 */
        and r3, r3, #1
        /* rem[0] = num[i] */
        orr r1, r1, r3
        /* rem >= div */
            cmp r1, v2
            subge r1, r1, v2
            movge r3, #1
            orrge r0, r0, r3, LSL r2
        cmp r2, $0x00
        bne 1b


        ldmfd sp!, {v1-v5, pc}

base10: /* int numerator, char* buffer -> int length */
        stmfd sp!, {v1-v5, lr}
        mov v1, r1
        mov v2, $0x00 /* length */

1:
        mov r1, #10
        bl divmod
        push {r1} /* for getting digit from top */
        add v2, v2, $0x01
        cmp r0, $0x00
        bne 1b

        mov r2, v2
2:
        sub r2, r2, $0x01
        pop {r0}
        add r0, r0, $0x30
        strb r0, [v1], $0x01
        cmp r2, $0x00
        bne 2b

        mov r0, $0x00
        strb r0, [v1]

        mov r0, v2
        ldmfd sp!, {v1-v5, pc}

base16: /* int numerator, char* buffer -> int length */
        stmfd sp!, {v1-v5, lr}
        mov v1, r1
        mov v2, $0x00 /* length */
1:
        and r1, r0, $0x0f
        cmp r1, $0x09
        addle r1, r1, $0x30
        addgt r1, r1, $0x57
        push {r1}

        add v2, v2, $0x01
        mov r0, r0, LSR #4
        cmp r0, $0x00
        bne 1b

        mov r2, v2
2:
        sub r2, r2, $0x01
        pop {r0}
        strb r0, [v1], $0x01
        cmp r2, $0x00
        bne 2b

        mov r0, $0x00
        strb r0, [v1]

        mov r0, v2
        ldmfd sp!, {v1-v5, pc}

strncmp: /* char* s1, char* s2, size_t len -> 1|0 */
        stmfd sp!, {v1-v5, lr}
        mov r3, $0x00 /* result */
1:      cmp r2, $0x00
        beq 2f  /* if (r2 == 0) goto 2 */
        sub r2, r2, $0x01 /* len-- */
        ldrb r4, [r0], $0x01
        ldrb r5, [r1], $0x01
        cmp r4, r5
        addne r3, $0x01
        beq 1b
2:
        mov r0, r3
        ldmfd sp!, {v1-v5, pc}

strlen: /* char* str -> uint */
        stmfd sp!, {r1-r2, lr}
        mov r1, $0x00
        /* r2 = *str++ (ldrb = load byte, and r0 increment after) */
1:      ldrb r2, [r0], $0x01
        cmp r2, $0x00
        addne r1, r1, $0x01 /* if (r2 != 0) r1++ */
        bne 1b  /* if (r2 != 0) goto 1; */
        mov r0, r1
        ldmfd sp!, {r1-r2, pc}

strcpy: /* char* dest, char* src -> dest */
        stmfd sp!, {r0-r2, lr}
1:
        ldrb r2, [r1], $0x01
        strb r2, [r0], $0x01
        cmp r2, $0x00
        bne 1b

        ldmfd sp!, {r0-r2, pc}

strcat: /* char* dest, char* src -> dest */
        stmfd sp!, {r0-r2, v1-v5, lr}

1:
        ldrb r2, [r0], $0x01
        cmp r2, $0x00
        bne 1b
        sub r0, r0, $0x01
2:
        ldrb r2, [r1], $0x01
        strb r2, [r0], $0x01
        cmp r2, $0x00
        bne 2b

        ldmfd sp!, {r0-r2, v1-v5, pc}

findstr: /* char* str, char* search, int len_of_search -> uint */
        stmfd sp!, {v1-v5, lr}

        mov v1, r0
        mov v2, r1
        mov v3, r2

        mov v4, v1 /* save original address */

        cmp v3, $0x00
        moveq r0, $0x00
        ldmeqfd sp!, {v1-v5, pc}

1:
        ldrb r0, [v1]
        cmp r0, $0x00
        beq 2f
        mov r0, v1
        mov r1, v2
        mov r2, v3
        bl strncmp
        cmp r0, $0x00
        addne v1, $0x01
        bne 1b

        sub r0, v1, v4
        ldmfd sp!, {v1-v5, pc}

2:
        mov r0, #-1
        ldmfd sp!, {v1-v5, pc}


sbrk: /* uint size -> void* */
        push {lr}
        ldr r3, =brk /* r3 = prev_brk */
        ldr r1, [r3]

        cmp r1, $0x00 /* if prev_brk == 0 */
        bleq sbrk_init

        add r0, r0, r1
        sys_brk
        cmp r0, r1
        blt sbrk_nomem /* curr_brk == prev_brk */
        str r0, [r3] /* update heap_start */
        mov r0, r1
        pop {pc}
sbrk_init:
        push {r0}
        mov r0, $0x00
        sys_brk
        mov r1, r0
        pop {r0}
        mov pc, lr
sbrk_nomem:
        mov r0, $0x00
        pop {pc}

getenv: /* char* name -> char* */
        stmfd sp!, {v1-v5, lr}
        /* v1 = name */
        mov v1, r0
        /* v2 = strlen(r0) */
        bl strlen
        mov v2, r0
        /* v3 = environ char** */
        ldr v3, =environ
        ldr v3, [v3]

1:      /* if (strncmp(name, *environ, len) == 0) { */
        mov r0, v1
        ldr r1, [v3]
        mov r2, v2
        bl strncmp
        cmp r0, $0x00
            /* if (*environ)[len] == '=') { */
            ldreq r0, [v3]
            ldreqb r0, [r0, v2]
            cmpeq r0, #'=
            beq 2f
            /* } */

        /* environ++ */
        add v3, $0x04
        /* *environ != NULL */
        ldr r1, [v3]
        cmp r1, $0x00
        bne 1b

        /* not found return NULL */
        mov r0, $0x00
        ldmfd sp!, {v1-v5, pc}

2:      /* found and return address */
        ldreq r0, [v3]
        add r0, r0, v2
        add r0, r0, $0x01 /* skip '=' */
        ldmfd sp!, {v1-v5, pc}

dentries: /* char* path, (void)(callback(name, name_len)) */
        stmfd sp!, {r1-r3, v1-v5, lr}

        mov ip, r1

        /* open */
        mov r1, #O_RDONLY
        sys_open
        cmp r0, $0x00
        rsble r0, r0, #0
        blle error
        mov v1, r0

1:
        /* getdents */
        mov r0, v1
        ldr r1, =dentry_buffer
        mov r2, #dentry_buffer_len
        sys_getdents
        cmp r0, $0x00
        beq 2f
        mov v2, r0 /* read bytes */
        rsblt r0, r0, #0
        bllt error


        ldr v3, =dentry_buffer
3:
        ldrh v5, [v3, #8] /* linux_dirent d_reclen */

        add r0, v3, #10
        mov r1, v5
        sub r1, r1, #12
        blx ip /* callback */

        sub v2, v2, v5 /* len -= d_reclen */
        add v3, v3, v5 /* buffer += d_reclen */
        cmp v2, $0x00
        bne 3b

        b 1b

2:
        /* close */
        mov r0, v1
        sys_close
        ldmfd sp!, {r1-r3, v1-v5, pc}

read_stat: /* char* name */
        stmfd sp!, {r0-r3, v1-v5, lr}
        ldr r1, =stat_buffer
        sys_stat
        cmp r0, $0x00
        rsblt r0, r0, #0
        bllt error
        ldmfd sp!, {r0-r3, v1-v5, pc}

read_entry: /* char* name, int name_len */
        stmfd sp!, {r1-r3, v1-v5, lr}

        mov v1, r0

        /* expand heap */
        mov r0, #entry_buffer_len
        bl sbrk
        mov v3, r0 /* v3 = entry_address */

        /* copy path */
        add r0, v3, #entry_path
        mov r1, v1
        bl strcpy

        /* r0 = ["data/" + name] */
        ldr r0, =buffer
        ldr r1, =var_data_dir
        bl strcpy
        mov r1, v1
        bl strcat
        mov v1, r0 /* v1 = path adr */

        mov r0, v1
        bl read_stat

        /* copy mtime */
        ldr r0, =st_mtime
        ldr r0, [r0]
        str r0, [v3, #entry_mtime]

        ldr v2, =st_size
        ldr v2, [v2] /* v2 = file size */

        push {r4, r5}
        /* mmap for file contents */
        mov r0, #0
        mov r1, v2
        mov r2, #PROT_READ
        orr r2, r2, #PROT_WRITE
        mov r3, #MAP_ANONYMOUS
        orr r3, r3, #MAP_PRIVATE
        mov r4, #-1
        mov r5, #0
        sys_mmap
        cmn r0, #4096
        rsbhs r0, r0, #0
        blhs error
        mov r3, r0 /* r3 = mmapped address */
        pop {r4, r5}

        str r3, [v3, #entry_title]

        /* open */
        mov r0, v1
        mov r1, #O_RDONLY
        sys_open
        cmp r0, $0x00
        rsble r0, r0, #0
        blle error
        mov v5, r0 /* v5 = fd */

        /* read */
1:
        mov r0, v5
        mov r1, r3
        mov r2, #4096
        sys_read
        cmp r0, $0x00
        rsblt r0, r0, #0
        bllt error
        add r1, r0
        bne 1b

        /* close */
        mov r0, v5
        sys_close

        
        /* find first \n */
        mov r0, r3
2:
        ldrb r1, [r0], $0x01
        cmp r1, $0x0a
        cmpne r1, $0x00
        bne 2b
        /* replace first \n to \0 to splitting title and body */
        mov r1, $0x00
        strb r1, [r0, #-1]
        str r0, [v3, #entry_body]

        ldr r0, =entries_count
        ldr r1, [r0]
        add r1, r1, $0x01
        str r1, [r0]

        ldmfd sp!, {r1-r3, v1-v5, pc}

template: /* char* name */
        stmfd sp!, {r0-r3, v1-v5, lr}

        /* open() */
        mov r1, #O_RDONLY
        sys_open
        cmp r0, $0x00
        beq error
        mov v1, r0 /* v1 = fd */

        ldr v2, =buffer /* v2 = buffer */

        mov r1, v2
        mov r2, #4096
        sys_read
        mov v3, r0 /* v3 = length */
        mov r0, $0x00
        strb r0, [v2, v3] /* null terminate */

1:
        mov r0, v2
        adr r1, open_variable
        mov r2, #open_variable_len
        bl findstr
        /* check found */
        cmp r0, #-1
        beq 2f

        /* output prev chars */
        mov r2, r0 /* set output length */
        mov r0, $0x01
        mov r1, v2
        sys_write

        /* increment buffer */
        add v2, v2, r2
        add v2, v2, #open_variable_len

        /* find close */
        mov r0, v2
        adr r1, close_variable
        mov r2, #close_variable_len
        bl findstr
        /* check found */
        cmp r0, #-1
        beq 2f
        mov v5, r0 /* variable name length */

        /* replaces */
            /* replace title */
            mov r0, v2
            adr r1, variable_name_blogtitle
            mov r2, v5
            bl strncmp
            cmp r0, $0x00
            bleq variable_blogtitle
            beq 3f

            /* replace home */
            mov r0, v2
            adr r1, variable_name_home
            mov r2, v5
            bl strncmp
            cmp r0, $0x00
            bleq variable_home
            beq 3f

            /* replace path */
            mov r0, v2
            adr r1, variable_name_path
            mov r2, v5
            bl strncmp
            cmp r0, $0x00
            bleq variable_path
            beq 3f

            /* replace title */
            mov r0, v2
            adr r1, variable_name_title
            mov r2, v5
            bl strncmp
            cmp r0, $0x00
            bleq variable_title
            beq 3f

            /* replace body */
            mov r0, v2
            adr r1, variable_name_body
            mov r2, v5
            bl strncmp
            cmp r0, $0x00
            bleq variable_body
            beq 3f

            /* replace time */
            mov r0, v2
            adr r1, variable_name_time
            mov r2, v5
            bl strncmp
            cmp r0, $0x00
            bleq variable_time
            beq 3f

            /* replace environ */
            mov r0, v2
            adr r1, variable_name_environ
            mov r2, v5
            bl strncmp
            cmp r0, $0x00
            bleq variable_environ
            beq 3f

3:
        /* increment buffer */
        add v2, v2, v5
        add v2, v2, #close_variable_len

        ldrb r0, [v2]
        cmp r0, $0x00
        bne 1b

2:
        /* output rest */
        ldr r2, =buffer
        sub r2, v2, r2
        sub r2, v3, r2
        mov r0, $0x01
        mov r1, v2
        sys_write

        /* close() */
        mov r0, v1
        sys_close

        ldmfd sp!, {r0-r3, v1-v5, pc}

        open_variable:
            .ascii "#{"
        open_variable_len = . - open_variable
            .align 2
        close_variable:
            .ascii "}"
        close_variable_len = . - close_variable
            .align 2

        variable_name_blogtitle:
            .asciz "blogtitle"
            .align 2
        variable_name_home:
            .asciz "home"
            .align 2
        variable_name_title:
            .asciz "title"
            .align 2
        variable_name_body:
            .asciz "body"
            .align 2
        variable_name_path:
            .asciz "path"
            .align 2
        variable_name_time:
            .asciz "time"
            .align 2
        variable_name_environ:
            .asciz "environ"
            .align 2

        variable_blogtitle:
            stmfd sp!, {r0-r3, lr}
            mov r0, $0x01
            ldr r1, =var_title
            mov r2, #var_title_len
            sys_write
            ldmfd sp!, {r0-r3, pc}
        variable_home:
            stmfd sp!, {r0-r3, lr}
            mov r0, $0x01
            ldr r1, =var_home
            mov r2, #var_home_len
            sys_write
            ldmfd sp!, {r0-r3, pc}
        variable_path:
            stmfd sp!, {r0-r3, v1-v5, lr}
            ldr r0, =current_entry
            ldr r0, [r0]

            add r1, r0, #entry_path
            bl strlen
            mov r2, r0

            mov r0, $0x01
            sys_write
            ldmfd sp!, {r0-r3, v1-v5, pc}
        variable_title:
            stmfd sp!, {r0-r3, v1-v5, lr}
            ldr r0, =current_entry
            ldr r0, [r0]

            add r0, r0, #entry_title
            ldr r0, [r0]
            mov r1, r0

            bl strlen
            mov r2, r0

            mov r0, $0x01
            sys_write
            ldmfd sp!, {r0-r3, v1-v5, pc}
        variable_body:
            stmfd sp!, {r0-r3, v1-v5, lr}
            ldr r0, =current_entry
            ldr r0, [r0]

            add r0, r0, #entry_body
            ldr r0, [r0]
            mov r1, r0

            bl strlen
            mov r2, r0

            mov r0, $0x01
            sys_write
            ldmfd sp!, {r0-r3, v1-v5, pc}
        variable_time:
            stmfd sp!, {r0-r3, v1-v5, lr}
            ldr r0, =current_entry
            ldr r0, [r0]

            add r0, r0, #entry_mtime
            ldr r0, [r0]
            ldr r1, =buffer
            bl base10

            mov r2, r0
            mov r0, $0x01
            ldr r1, =buffer
            sys_write

            ldmfd sp!, {r0-r3, v1-v5, pc}
        variable_environ:
            stmfd sp!, {r0-r3, v1-v5, lr}
            ldr r0, =environ
            ldr r0, [r0]
            ldr r1, =buffer
            bl base16

            mov r2, r0
            mov r0, $0x01
            ldr r1, =buffer
            sys_write

            ldmfd sp!, {r0-r3, v1-v5, pc}

.section .bss
    .align 2

environ: .word 0
buffer: .skip 4096
dentry_buffer:
    .skip 4096
    dentry_buffer_len = . - dentry_buffer
stat_buffer: /* /usr/include/arm-linux-gnueabihf/asm/stat.h  */
    st_dev: .skip 4
    st_ino: .skip 4
    st_mode: .skip 2
    st_nlink: .skip 2
    st_uid: .skip 2
    st_gid: .skip 2
    st_rdev: .skip 4
    st_size: .skip 4
    st_blksize: .skip 4
    st_blocks: .skip 4
    st_atime: .skip 4
    st_atime_nsec: .skip 4
    st_mtime: .skip 4
    st_mtime_nsec: .skip 4
    st_ctime: .skip 4
    st_ctime_nsec: .skip 4
    .skip 4
    .skip 4
    .align 2
    stat_buffer_len = . - stat_buffer
entry_buffer: /* not used: just calculate offsets */
    entry_buffer_path: .skip 256
    entry_buffer_mtime: .skip 4
    entry_buffer_title: .skip 4
    entry_buffer_body: .skip 4
    .align 2
    entry_buffer_len = . - entry_buffer
    entry_path       = entry_buffer_path - entry_buffer
    entry_mtime      = entry_buffer_mtime - entry_buffer
    entry_title      = entry_buffer_title - entry_buffer
    entry_body       = entry_buffer_body - entry_buffer
entries_count: .word 0
current_entry: .word 0
