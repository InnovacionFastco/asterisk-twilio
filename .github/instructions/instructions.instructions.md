---
applyTo: '**'
---

# Project Context – Asterisk + Twilio Integration

## Scope
Implementar un entorno donde **Asterisk** pueda comunicarse con **Twilio** utilizando **Docker** y **Docker Compose**.

## Requirements
1. **Asterisk en contenedor:**
   - Construir una imagen de Docker con Asterisk.
   - Incluir **todos los módulos necesarios habilitados** por defecto.

2. **Portabilidad:**
   - La configuración debe ser **clara y portable**.
   - Con solo copiar:
     - `Dockerfile`
     - `docker-compose.yml`
     - Archivos de configuración de Asterisk  
     el proyecto debe funcionar en cualquier entorno sin modificaciones adicionales.

3. **Documentación mínima:**
   - Instrucciones paso a paso para levantar el entorno.
   - Variables configurables (ejemplo: credenciales de Twilio, puertos, etc.).
   - Ejemplo funcional de una llamada de prueba.

## Coding Guidelines for AI
- Mantener la configuración **minimalista y portable**.
- Todas las dependencias deben estar contenidas en Docker.
- No agregar frameworks o librerías externas innecesarias.
- Comentar el código de configuración para que sea claro y mantenible.
- Proveer ejemplos autocontenidos de `docker-compose.yml`, `Dockerfile` y configuraciones de Asterisk.
