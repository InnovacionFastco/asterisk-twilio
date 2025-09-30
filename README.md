# Asterisk + Twilio Docker Lab

Este proyecto empaqueta una instancia de Asterisk optimizada para integrarse con Twilio **Elastic SIP Trunking** usando únicamente Docker y Docker Compose. Copiando `Dockerfile`, `docker-compose.yml` y la carpeta `config/asterisk` podrás reproducir el entorno en cualquier host con Docker instalado.

## 🧱 Componentes principales

- **Imagen base**: [`andrius/asterisk:22.5.2_debian-trixie`](https://hub.docker.com/r/andrius/asterisk) con PJSIP, WebRTC y módulos modernos habilitados.
- **Módulos extra**: durante la compilación se genera `res_pjsip_sdp_rtp.so` para garantizar que las ofertas SDP incluyan `m=audio` y codecs G.711 compatibles con Twilio.
- **Configuración de Asterisk**: enfocada en PJSIP; usa el *wizard* para describir el trunk de Twilio e incluye un dialplan mínimo inbound/outbound.
- **Persistencia**: volúmenes nombrados para `spool`, `lib`, `logs` y `monitor`.
- **Personalización**: variables `.env` para puertos y nombre de la imagen; ficheros de configuración comentados para credenciales y parámetros de Twilio.
- **Bootstrap**: `scripts/bootstrap-asterisk.sh` renderiza los `.conf` con los valores de `.env` y valida que no queden credenciales de ejemplo.

## 📂 Estructura

```
.
├── Dockerfile
├── docker-compose.yml
├── .env.example
├── README.md
├── scripts/
│   └── bootstrap-asterisk.sh
└── config/
    └── asterisk/
        ├── asterisk.conf
        ├── extensions.conf
        ├── modules.conf
        ├── pjsip.conf
        ├── pjsip_transports.conf
        ├── pjsip_wizard.conf
        └── rtp.conf
```

Los archivos `.conf` contienen comentarios con las decisiones de diseño y los valores que debes adaptar.

## ⚙️ Preparación

1. **Duplica el archivo de variables**:
   ```powershell
   Copy-Item .env.example .env
   ```
   2. **Edita `.env`** para definir tu IP/FQDN pública (`PUBLIC_ADDRESS`), puertos SIP y credenciales de Twilio.
      - El script `bootstrap-asterisk.sh` sustituirá automáticamente los marcadores `__FOO__` en los `.conf`. Si alguno queda con `changeme`, el contenedor abortará durante el arranque.
      - Usa el dominio SIP regional que Twilio te proporcione (`sip.us1.twilio.com`, `sip.eu1.twilio.com`, etc.).
      - Declara el número entrante principal en formato E.164 en `TWILIO_DID` (por ejemplo `+56226665897`); el bootstrap lo inyectará en el dialplan para enrutar las llamadas.
      - Ajusta `HTTP_BIND_ADDRESS` / `HTTP_PORT` si quieres exponer el API REST en puertos diferentes y define `ARI_USERNAME` / `ARI_PASSWORD` con credenciales propias. `ARI_ALLOWED_ORIGINS` controla los orígenes permitidos para llamadas CORS.
   - Define las credenciales del softphone local (`MICROSIP_EXTENSION`, `MICROSIP_PASSWORD`, `MICROSIP_DISPLAY_NAME`). El contenedor generará automáticamente el endpoint PJSIP con esos valores (la contraseña por defecto es `6001pass`, pensada para evitar confusiones en la primera conexión).
   - Ajusta `MICROSIP_MATCH` si quieres restringir qué IPs pueden registrar el softphone. Por defecto usa `0.0.0.0/0` para aceptar registros desde cualquier host, pero puedes definir una red (ej. `192.168.1.0/24`) o una IP concreta.
   3. (Opcional) Ajusta `config/asterisk/extensions.conf` y el resto de ficheros para adaptar el dialplan a tus necesidades.

> 💡 Para evitar exponer credenciales en control de versiones, mantén los valores reales fuera del repositorio y aplícalos justo antes de construir la imagen o usa un repositorio privado.

## 🔧 Configuración en Twilio

> Consulta la guía extendida en `docs/twilio-setup.md` si necesitas capturas y explicaciones detalladas.

1. En el portal de Twilio, ve a **Elastic SIP Trunking → Trunks** y crea (o selecciona) un trunk.
2. Dentro del trunk, en la pestaña **Termination**, define un *SIP URI* (por ejemplo `miempresa`) y asocia la **Credential List** que contenga el usuario y contraseña configurados en `.env` (`TWILIO_SIP_USER` / `TWILIO_SIP_PASSWORD`).
3. Si aún no tienes una Credential List, créala en **Trunks → Credential Lists** con exactamente los mismos valores que usarás en el contenedor.
4. En la pestaña **Origination**, añade una entrada que apunte a tu servidor: `sip:<tu_public_address>:5060;transport=udp`. Puedes añadir múltiples entradas (por ejemplo una por región o balanceador).
5. Asegúrate de permitir en tu firewall las IPs de señalización y media que Twilio documenta para tu región, tanto sobre UDP 5060/5061 como para el rango RTP configurado (por defecto 10000-10100).
6. Si deseas enrutar un DID específico, vincúlalo al trunk y ponlo en `.env` como `TWILIO_DID` para que el dialplan lo reconozca automáticamente.

Con esto Twilio aceptará registros salientes del contenedor y redirigirá el tráfico entrante al endpoint configurado.

## ▶️ Puesta en marcha

```powershell
# Construye la imagen personalizada
docker compose build

# Inicia el contenedor en segundo plano
docker compose up -d

# Ingresa al CLI de Asterisk si necesitas depurar
docker compose exec asterisk asterisk -rvvv
```

> ⏱️ **Nota:** el primer `docker compose build` descarga el código fuente de Asterisk 22.5.2 dentro de una etapa temporal para compilar el módulo `res_pjsip_sdp_rtp.so`. El proceso tarda unos minutos y requiere acceso a Internet, pero deja el runtime igual de ligero que antes.

El proceso de compilación copiará los archivos de `config/asterisk` dentro de la imagen. Si deseas iterar sin reconstruir, descomenta la línea de montaje bind en `docker-compose.yml`.

## ☎️ Prueba funcional rápida

1. Configura un trunk de salida en Twilio que apunte a `sip:<tu_public_address>:5060` usando las credenciales definidas en `.env` (guía completa en `docs/twilio-setup.md`).
2. Desde el CLI (`asterisk -rvvv`) marca una llamada de prueba:
   ```
   channel originate Local/+14155238886@from-internal application Echo
   ```
   - Si todo está correcto escucharás el mensaje estándar de Twilio y después un eco.
3. Para probar inbound, crea una *Voice URL* en Twilio que enrute una llamada entrante al trunk. Por defecto el contexto `from-twilio` hará sonar `microsip` y, si no responde, reproducirá `demo-congrats`.

## 🖥️ Conectar MicroSIP (softphone)

1. Arranca el contenedor (`docker compose up -d`). El bootstrap creará automáticamente un endpoint PJSIP llamado `microsip` con la extensión configurada en `.env` (por defecto `6001`).
2. Abre MicroSIP y añade una nueva cuenta SIP con los siguientes campos:
   - **Account**: `MICROSIP_EXTENSION` (ej. `6001`)
   - **Domain**: IP o hostname del host donde corre Docker (si MicroSIP está en el mismo PC podemos usar `127.0.0.1`; asegúrate de que dicha IP esté incluida en `MICROSIP_MATCH`).
   - **User / Login**: `MICROSIP_EXTENSION`
   - **Password**: `MICROSIP_PASSWORD`
   - **Display name**: `MICROSIP_DISPLAY_NAME`
   - **Proxy** *(opcional)*: `sip:<host>:5060;transport=udp`.
3. Guarda la cuenta; MicroSIP debería registrar y mostrar el estado *Online*.
4. Desde MicroSIP puedes:
   - Marcar `1000` para escuchar el audio de prueba de Twilio a través del trunk.
   - Marcar cualquier número E.164 (ej. `+14155238886`) y Asterisk lo enviará vía Twilio.
5. Las llamadas entrantes desde Twilio a `TWILIO_DID` timbrarán primero en `microsip`. Si no hay respuesta, el flujo vuelve al mensaje `demo-congrats`.

## 🔐 Certificados TLS (opcional)

Twilio acepta TLS/SRTP. Cuando dispongas de certificados válidos:

1. Copia `tls.crt` y `tls.key` en `config/asterisk/keys/`.
2. Descomenta la sección `[transport-tls]` en `pjsip_transports.conf` y ajusta los campos `external_*`.
3. Expone `5061` en tu firewall. En Twilio, cambia el *SIP Interface* a `TLS`.

## 🔍 Diagnóstico útil

- `pjsip show registrations` — confirma que Twilio acepta el registro.
- `pjsip show endpoints` — revisa codecs permitidos y estado de conectividad.
- `rtp set debug on` — inspecciona tráfico RTP cuando haya audio unidireccional.
- `database show` — verifica que Asterisk haya almacenado la variable `TWILIO_DID` en el dialplan.
- `ari show status` / `ari show apps` — comprueba que el API REST esté habilitado y que tus aplicaciones Stasis estén registradas.

## 🌐 Acceso al API REST (ARI)

El bootstrap deja activado el servidor HTTP de Asterisk (`http.conf`) y crea un usuario ARI personalizado (`ari.conf`) empleando las variables de `.env`:

- Puerto y binding: `HTTP_BIND_ADDRESS`, `HTTP_PORT`, `HTTP_PREFIX`.
- CORS: `ARI_ALLOWED_ORIGINS`.
- Credenciales: `ARI_USERNAME`, `ARI_PASSWORD`.

Para consumir la API desde el host local recuerda mapear el puerto 8088 (o el que definas) en `docker-compose.yml` y usa autenticación básica, por ejemplo:

```powershell
curl -u $env:ARI_USERNAME:$env:ARI_PASSWORD http://localhost:8088/ari/applications
```

## 🧼 Limpieza

```powershell
docker compose down --volumes
```

## 🔒 Firewall en Windows

Incluimos scripts para abrir o revertir las reglas de firewall en Windows. Recuerda iniciar PowerShell como **Administrador** y situarte en la raíz del repositorio antes de ejecutar los comandos:

```powershell
Set-Location D:/Pega/asterisk-twilio
# Si la política de ejecución lo bloquea, habilita el modo temporalmente
Set-ExecutionPolicy -Scope Process -ExecutionPolicy RemoteSigned

./scripts/windows/open-asterisk-ports.ps1    # Crea o actualiza las reglas de entrada
# ... cuando quieras revertirlo
./scripts/windows/close-asterisk-ports.ps1   # Elimina las reglas asociadas
```

> Si ya te encuentras dentro de `scripts/windows`, usa la notación relativa `./open-asterisk-ports.ps1` (sin repetir la ruta).

Asegúrate también de configurar el port forwarding equivalente en tu router/NAT.

## 📌 Próximos pasos sugeridos

- Automatizar el rellenado de credenciales mediante plantillas o gestor de secretos.
- Añadir pruebas automáticas (por ejemplo, `sipp`) para validar el flujo SIP end-to-end.
- Integrar certificados Let’s Encrypt con un proxy (Traefik / Caddy) si necesitas TLS gestionado.
