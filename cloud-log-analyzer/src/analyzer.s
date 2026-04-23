/*
Autor: Vallejo Garcia Axel Gael
Curso: Lenguajes de Interfaz / Ensamblador ARM64
Práctica: Mini Cloud Log Analyzer – Variante D
Fecha: 2026
Descripción: Lee códigos HTTP desde stdin (uno por línea) y detecta
             la primera vez que ocurren TRES errores consecutivos
             (4xx o 5xx seguidos sin ningún 2xx de por medio).
             Usa únicamente syscalls Linux en ARM64.
*/

/*
PSEUDOCÓDIGO – Variante D
1) Inicializar:
     consecutivos = 0      (errores seguidos sin éxito entre ellos)
     posicion     = 0      (línea actual, base 1)
     detectado    = 0      (0 = aún no, 1 = ya encontramos 3 consecutivos)
     pos_primera  = 0      (línea donde ocurrió el tercero)

2) Mientras haya bytes por leer en stdin:
   2.1) Leer bloque con syscall read.
   2.2) Recorrer byte a byte.
   2.3) Si es dígito → acumular numero_actual.
   2.4) Si es '\n' y hay dígitos pendientes:
          posicion++
          Clasificar codigo:
            2xx → consecutivos = 0
            4xx o 5xx → consecutivos++
                        si consecutivos == 3 y detectado == 0:
                           detectado    = 1
                           pos_primera  = posicion
          reiniciar acumulador

3) EOF: manejar número pendiente sin '\n' final.
4) Imprimir reporte:
     Si detectado == 1 → mostrar línea donde ocurrió.
     Si detectado == 0 → informar que no se detectó.
5) Salir con código 0.
*/

.equ SYS_read,   63
.equ SYS_write,  64
.equ SYS_exit,   93
.equ STDIN_FD,    0
.equ STDOUT_FD,   1

// ─── Sección BSS ──────────────────────────────────────────────────────────────
.section .bss
    .align 4
buffer:     .skip 4096
num_buf:    .skip 32        // buffer auxiliar para imprimir enteros

// ─── Sección DATA ─────────────────────────────────────────────────────────────
.section .data
msg_titulo:     .asciz "=== Mini Cloud Log Analyzer – Variante D ===\n"
msg_detectado:  .asciz "Tres errores consecutivos detectados en la linea: "
msg_no_detect:  .asciz "No se detectaron tres errores consecutivos.\n"
msg_newline:    .asciz "\n"

// ─── Sección TEXT ─────────────────────────────────────────────────────────────
.section .text
.global _start

// Mapa de registros callee-saved (x19-x28):
//   x19 = consecutivos        (contador de errores seguidos)
//   x20 = posicion            (número de línea actual, base 1)
//   x21 = detectado           (0/1)
//   x22 = pos_primera         (línea del tercer error consecutivo)
//   x23 = numero_actual       (acumulador del código en curso)
//   x24 = tiene_digitos       (0/1)
//   x25 = indice i en el bloque
//   x26 = bytes en el bloque (resultado de read)

_start:
    mov x19, #0          // consecutivos = 0
    mov x20, #0          // posicion = 0
    mov x21, #0          // detectado = 0
    mov x22, #0          // pos_primera = 0
    mov x23, #0          // numero_actual = 0
    mov x24, #0          // tiene_digitos = 0

// ─── Bucle principal de lectura ───────────────────────────────────────────────
leer_bloque:
    mov x0, #STDIN_FD
    adrp x1, buffer
    add  x1, x1, :lo12:buffer
    mov  x2, #4096
    mov  x8, #SYS_read
    svc  #0

    cmp  x0, #0
    beq  fin_lectura          // EOF
    blt  salida_error         // error de lectura

    mov  x25, #0              // i = 0
    mov  x26, x0              // bytes leídos

// ─── Procesamiento byte a byte ────────────────────────────────────────────────
procesar_byte:
    cmp  x25, x26
    b.ge leer_bloque

    adrp x1, buffer
    add  x1, x1, :lo12:buffer
    ldrb w27, [x1, x25]       // byte actual → w27
    add  x25, x25, #1

    cmp  w27, #10             // '\n'?
    b.eq fin_numero

    cmp  w27, #'0'
    b.lt procesar_byte
    cmp  w27, #'9'
    b.gt procesar_byte

    // dígito: acumular
    mov  x28, #10
    mul  x23, x23, x28
    sub  w27, w27, #'0'
    uxtw x27, w27
    add  x23, x23, x27
    mov  x24, #1
    b    procesar_byte

// ─── Fin de número (encontramos '\n' o EOF con dígitos pendientes) ─────────────
fin_numero:
    cbz  x24, reiniciar_numero   // sin dígitos → ignorar línea vacía

    add  x20, x20, #1            // posicion++

    mov  x0, x23                 // código HTTP en x0
    bl   clasificar_codigo_d     // actualiza x19, x21, x22

reiniciar_numero:
    mov  x23, #0
    mov  x24, #0
    b    procesar_byte

// ─── EOF ──────────────────────────────────────────────────────────────────────
fin_lectura:
    cbz  x24, imprimir_reporte   // no hay número pendiente
    add  x20, x20, #1
    mov  x0, x23
    bl   clasificar_codigo_d

// ─── Reporte final ────────────────────────────────────────────────────────────
imprimir_reporte:
    // Título
    adrp x0, msg_titulo
    add  x0, x0, :lo12:msg_titulo
    bl   write_cstr

    cbz  x21, sin_deteccion      // detectado == 0?

    // Sí detectado: "Tres errores consecutivos detectados en la linea: N"
    adrp x0, msg_detectado
    add  x0, x0, :lo12:msg_detectado
    bl   write_cstr
    mov  x0, x22                 // número de línea
    bl   print_uint
    adrp x0, msg_newline
    add  x0, x0, :lo12:msg_newline
    bl   write_cstr
    b    salida_ok

sin_deteccion:
    adrp x0, msg_no_detect
    add  x0, x0, :lo12:msg_no_detect
    bl   write_cstr

salida_ok:
    mov  x0, #0
    mov  x8, #SYS_exit
    svc  #0

salida_error:
    mov  x0, #1
    mov  x8, #SYS_exit
    svc  #0

// ─────────────────────────────────────────────────────────────────────────────
// clasificar_codigo_d(x0 = codigo_http)
//
// Lógica Variante D:
//   • 2xx → consecutivos = 0  (racha se rompe)
//   • 4xx o 5xx → consecutivos++
//               si consecutivos == 3 y aún no detectado:
//                  detectado   = 1
//                  pos_primera = posicion actual (x20)
//   • Cualquier otro código → no modifica consecutivos
//
// Registros usados: x0 (parámetro), x19, x20, x21, x22 (globales)
// ─────────────────────────────────────────────────────────────────────────────
clasificar_codigo_d:
    // ¿Es 2xx?
    cmp  x0, #200
    b.lt cd_otro
    cmp  x0, #299
    b.gt cd_revisar_4xx
    // 2xx → reiniciar racha
    mov  x19, #0
    b    cd_fin

cd_revisar_4xx:
    cmp  x0, #400
    b.lt cd_otro
    cmp  x0, #499
    b.gt cd_revisar_5xx
    // 4xx → error
    b    cd_es_error

cd_revisar_5xx:
    cmp  x0, #500
    b.lt cd_otro
    cmp  x0, #599
    b.gt cd_otro
    // 5xx → error

cd_es_error:
    add  x19, x19, #1           // consecutivos++
    cmp  x19, #3
    b.ne cd_fin                 // aún no llegamos a 3
    cbnz x21, cd_fin            // ya habíamos detectado antes
    // ¡Primera vez que llegamos a 3 consecutivos!
    mov  x21, #1                // detectado = 1
    mov  x22, x20               // pos_primera = posicion actual

cd_otro:
cd_fin:
    ret

// ─────────────────────────────────────────────────────────────────────────────
// write_cstr(x0 = puntero a cadena terminada en '\0')
// ─────────────────────────────────────────────────────────────────────────────
write_cstr:
    mov  x9,  x0                // guardar inicio
    mov  x10, #0                // longitud = 0

wc_len_loop:
    ldrb w11, [x9, x10]
    cbz  w11, wc_len_done
    add  x10, x10, #1
    b    wc_len_loop

wc_len_done:
    mov  x0, #STDOUT_FD
    mov  x1, x9
    mov  x2, x10
    mov  x8, #SYS_write
    svc  #0
    ret

// ─────────────────────────────────────────────────────────────────────────────
// print_uint(x0 = entero sin signo)
// Convierte a ASCII base-10 e imprime con syscall write.
// ─────────────────────────────────────────────────────────────────────────────
print_uint:
    cbnz x0, pu_convertir

    // Caso especial: 0
    adrp x1, num_buf
    add  x1, x1, :lo12:num_buf
    mov  w2, #'0'
    strb w2, [x1]
    mov  x0, #STDOUT_FD
    mov  x2, #1
    mov  x8, #SYS_write
    svc  #0
    ret

pu_convertir:
    adrp x12, num_buf
    add  x12, x12, :lo12:num_buf
    add  x12, x12, #31          // apuntamos al final del buffer
    mov  w13, #0
    strb w13, [x12]             // terminador (útil para depuración)
    mov  x14, #10
    mov  x15, #0                // contador de dígitos

pu_loop:
    udiv x16, x0, x14           // cociente
    msub x17, x16, x14, x0      // residuo = x0 mod 10
    add  x17, x17, #'0'
    sub  x12, x12, #1
    strb w17, [x12]
    add  x15, x15, #1
    mov  x0,  x16
    cbnz x0, pu_loop

    mov  x0, #STDOUT_FD
    mov  x1, x12
    mov  x2, x15
    mov  x8, #SYS_write
    svc  #0
    ret