# 🌩️ Mini Cloud Log Analyzer — `Variante D`

**Práctica 4.2** | Lenguajes de Interfaz / Ensamblador ARM64
**Tecnológico de Tijuana**

---
👨‍💻 **Autor:** Axel Gael Vallejo Garcia
⚙️ **Stack:** ARM64 Assembly | 🐧 Linux Syscalls
☁️ **Infraestructura:** AWS EC2 Graviton (Nativo)
---

## Descripción

Este programa analiza un flujo de códigos de estado HTTP leídos desde la entrada estándar (`stdin`) y detecta la primera ocurrencia de **tres errores consecutivos**, donde un error se define como cualquier código de la familia `4xx` (error del cliente) o `5xx` (error del servidor).

El programa está implementado íntegramente en **ensamblador ARM64** bajo Linux, sin ninguna dependencia de bibliotecas externas. Toda la interacción con el sistema operativo se realiza mediante **syscalls Linux directas** (`read`, `write`, `exit`).

Al finalizar el análisis, el programa reporta:
- La línea exacta (base 1) donde ocurrió el tercer error consecutivo, si fue detectado.
- Un mensaje informativo en caso de que no se haya alcanzado la condición.

---

## Entorno de Desarrollo

El código fue compilado y ejecutado de forma **nativa en la nube**, sin ningún tipo de emulación.

- **Plataforma:** Amazon Web Services (AWS)
- **Instancia:** `t4g.micro` — procesador AWS Graviton (ARM64 real)
- **Sistema Operativo:** Ubuntu ARM64
- **Ensamblador:** GNU Assembler (`as`)
- **Enlazador:** GNU Linker (`ld`)
- **Automatización de compilación:** GNU Make
- **Captura de evidencia:** `asciinema` grabado directamente en la terminal de la instancia EC2

El uso de una instancia Graviton garantiza que cada instrucción ARM64 escrita en el código fuente se ejecuta sobre hardware físico real de 64 bits, validando la correctitud de las instrucciones, el direccionamiento y las syscalls sin ninguna capa de traducción intermedia.

---

## Lógica de la Variante D

El objetivo de la Variante D es detectar tres errores HTTP consecutivos sin ningún código exitoso entre ellos.

### Registros principales utilizados

- `x19` — Contador de errores consecutivos activos.
- `x20` — Número de línea actual (incrementa con cada código procesado, base 1).
- `x21` — Bandera de detección: vale `0` si aún no se han encontrado tres errores consecutivos, o `1` si ya se detectaron.
- `x22` — Almacena el número de línea donde ocurrió el tercer error consecutivo.
- `x23` — Acumulador del código HTTP que se está leyendo dígito a dígito.
- `x24` — Indica si hay al menos un dígito acumulado en `x23` (evita clasificar líneas vacías).

### Flujo de clasificación (`clasificar_codigo_d`)

Cuando se completa la lectura de un código HTTP (al encontrar un `\n` o llegar al EOF), se ejecuta la siguiente lógica:

1. **Si el código es `2xx`:** se reinicia `x19` a `0`. La racha de errores se rompe y el conteo vuelve a empezar.
2. **Si el código es `4xx` o `5xx`:** se incrementa `x19` en `1`. Si `x19` llega a `3` y la bandera `x21` aún vale `0` (primera detección), se activa `x21 = 1` y se guarda en `x22` la línea actual (`x20`).
3. **Cualquier otro código** (1xx, 3xx, u otros): no modifica el contador de consecutivos.

Esta lógica garantiza que la condición se evalúa de forma estricta: los tres errores deben ser **adyacentes** en el archivo, sin ningún código exitoso entre ellos.

### Parser de entrada

La lectura se hace en bloques de hasta `4096` bytes por llamada a `read`. Cada bloque se recorre byte a byte:
- Los bytes `'0'`–`'9'` se acumulan en `x23` mediante la operación `numero_actual = numero_actual × 10 + dígito`.
- Al encontrar `'\n'`, si hay dígitos acumulados, se incrementa el contador de línea y se clasifica el código.
- Al llegar al EOF, si queda un número pendiente (archivo sin salto de línea final), también se procesa.

---

## Compilación y Ejecución

```bash
# Compilar
make

# Ejecutar con el archivo de datos
cat data/logs_D.txt | ./analyzer
```

---

## Evidencia de Ejecución (Prueba de Carga: 1000 Registros)

Para validar la robustez del programa, se generó un archivo de 1000 logs utilizando Mockaroo. La grabación demuestra que el sistema procesa grandes volúmenes de datos de forma instantánea y detecta correctamente la primera racha de errores.

[![Evidencia Asciinema](https://asciinema.org/a/Mtx6Fl3totd9VwCv.svg)](https://asciinema.org/a/Mtx6Fl3totd9VwCv)

**Detalles visibles en la grabación:**
1. Uso de `wc -l` para verificar la existencia de las 1000 líneas en el archivo `data/logs_D.txt`.
2. Compilación nativa en AWS Graviton (ARM64).
3. Ejecución del analyzer procesando el flujo completo de datos.
4. Salida del programa:
   ```text
   === Mini Cloud Log Analyzer – Variante D ===
   Tres errores consecutivos detectados en la linea: 3
