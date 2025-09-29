# Guía rápida: configurar Twilio Elastic SIP Trunking para Asterisk

Este manual resume, paso a paso, cómo crear o adaptar un **Elastic SIP Trunk** en Twilio para que pueda comunicarse con la instancia de Asterisk desplegada con este proyecto.

## 1. Requisitos previos

1. **Cuenta Twilio con balance**: el servicio de SIP Trunking requiere saldo (o un trial con crédito disponible).
2. **IP pública o FQDN de Asterisk**: en esta guía usaremos `179.60.72.50`. Si tienes otra dirección, reemplázala en cada paso.
3. **Puertos abiertos** en tu firewall/router:
   - Señalización SIP: `5060/UDP`, `5060/TCP`, `5061/TLS` (si usarás TLS).
   - Media RTP: rango `10000-10100/UDP` (ajusta según tu `.env`).
4. **Usuario Twilio con permisos** para administrar SIP Trunking.

## 2. Crear (o identificar) un SIP Trunk

1. En el [Portal de Twilio](https://console.twilio.com/), abre el menú lateral.
2. Dirígete a **Elastic SIP Trunking → Trunks**.
3. Pulsa **Create new SIP trunk**.
   - Nombre sugerido: `Asterisk-Local`.
   - (Opcional) Asigna etiquetas para diferenciar entornos (`dev`, `qa`, etc.).
4. Guarda. Entrarás al panel del trunk recién creado.

> Si ya tienes un trunk creado, simplemente selecciónalo y continua con los siguientes pasos.

## 3. Configurar la terminación (salientes)

Esto permite que Asterisk registre y envíe llamadas a Twilio.

1. Dentro del trunk, abre la pestaña **Termination**.
2. En **SIP URI**, define un identificador único, por ejemplo `fastco-voice-kernel`. Twilio generará la ruta completa: `fastco-voice-kernel.sip.twilio.com`.
3. **Credential Lists**: asocia una lista de credenciales. Si no tienes una, crea una nueva:
   1. Haz clic en **Create Credential List** (o ve a **Trunks → Credential Lists** en una pestaña aparte).
   2. Ponle un nombre (ej. `Asterisk-Dev-Credentials`).
   3. Agrega un usuario y contraseña (ej. `mini-vapi` / `SuperClaveSegura123`).
   4. Guarda y regresa a la pantalla del trunk para asociar la lista recién creada.
4. Asegúrate de que **IP Access Control Lists** esté vacío a menos que quieras restringir adicionalmente por IP; para este proyecto, la autenticación por credenciales es suficiente.
5. Pulsa **Save configuration**.

## 4. Configurar la originación (entrantes)

Así Twilio sabrá adónde enviar llamadas cuando entren al trunk.

1. Cambia a la pestaña **Origination**.
2. Haz clic en **Add new Origination URI**.
3. Completa los campos:
   - **SIP URI**: `sip:179.60.72.50:5060;transport=udp`
     - Si usas TLS: `sip:179.60.72.50:5061;transport=tls`
   - **Priority / Weight**: deja la prioridad en 10 (por defecto) y peso en 10, salvo que tengas múltiples destinos.
4. Guarda.
5. (Opcional) Añade una segunda entrada con otra IP o región para redundancia.

## 5. Asociar números telefónicos (opcional pero habitual)

Si quieres recibir llamadas desde la PSTN a través de Twilio:

1. Ve a **Phone Numbers → Manage → Active numbers**.
2. Abre el número que quieres usar (`+56226665897`, por ejemplo).
3. En **Voice & Fax → Configure With**, elige **SIP Trunk**.
4. Selecciona el trunk configurado (`Asterisk-Local`).
5. Guarda.

> Una vez asocies el número, actualiza tu archivo `.env` local con el valor en `TWILIO_DID=+TuNumero` para que el dialplan del contenedor lo enrute automáticamente.

> Puedes repetir el proceso para múltiples números o subcuentas.

## 6. Control de acceso y seguridad

- En **Elastic SIP Trunking → Tools → IP Access Control Lists**, define IPs autorizadas si deseas combinar credenciales + IP.
- Asegúrate de que tus credenciales **no** estén expuestas: Twilio permite rotarlas en cualquier momento desde **Credential Lists**.
- Considera habilitar **TLS/SRTP** si tu escenario requiere cifrado extremo a extremo. En ese caso:
  - Carga certificados válidos en `config/asterisk/keys/`.
  - Descomenta `[transport-tls]` en `pjsip_transports.conf` y vuelve a construir la imagen.
  - Cambia el Origination URI a `transport=tls`.

## 7. Prueba rápida desde Twilio

1. Con el trunk y el contenedor levantados, abre **Elastic SIP Trunking → Monitor → Call Records** para ver tráfico en tiempo real.
2. Desde el CLI de Asterisk (`docker compose exec asterisk asterisk -rvvv`), coloca una llamada de prueba:
   ```
   channel originate Local/+14155238886@from-internal application Echo
   ```
3. Verifica que aparezca el registro en el monitor de Twilio y que escuches el mensaje de prueba.

## 8. Checklist final

- [ ] Trunk creado y con nombre descriptivo.
- [ ] Credential List asociada y guardada en `.env` (`TWILIO_SIP_USER` / `TWILIO_SIP_PASSWORD`).
- [ ] Origination URI apuntando a tu IP/FQDN + puerto correcto.
- [ ] Puertos abiertos/reenviados en router o firewall.
- [ ] Número(s) telefónico(s) vinculado(s) (si aplica).
- [ ] Prueba de llamada saliente funciona.
- [ ] Logs de Twilio verificados para asegurarte de que no hay errores de autenticación o de red.

Con esto tu trunk Twilio queda listo para trabajar con el entorno Docker de Asterisk. Ante cualquier cambio (rotación de credenciales, nueva IP, ajuste de puertos) recuerda actualizar tanto Twilio como tu `.env` y reconstruir/reiniciar el contenedor.
