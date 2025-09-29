#!/usr/bin/env bash
set -euo pipefail

log() {
  printf '[bootstrap] %s\n' "$*"
}

copy_templates() {
  local src="/opt/asterisk/templates"
  local dest="/etc/asterisk"
  install -d -o asterisk -g asterisk "$dest"
  cp -a "$src"/. "$dest"/
}

escape_sed() {
  printf '%s' "$1" | sed -e 's/[\\&|]/\\&/g'
}

replace_placeholder() {
  local file="$1"
  local placeholder="$2"
  local value="$3"
  local escaped
  escaped=$(escape_sed "$value")
  sed -i "s|${placeholder}|${escaped}|g" "$file"
}

render_placeholders() {
  local wizard="/etc/asterisk/pjsip_wizard.conf"
  local transports="/etc/asterisk/pjsip_transports.conf"
  local extensions="/etc/asterisk/extensions.conf"
  local http_conf="/etc/asterisk/http.conf"
  local ari_conf="/etc/asterisk/ari.conf"

  replace_placeholder "$wizard" "__TWILIO_SIP_DOMAIN__" "$TWILIO_SIP_DOMAIN"
  replace_placeholder "$wizard" "__TWILIO_SIP_USER__" "$TWILIO_SIP_USER"
  replace_placeholder "$wizard" "__TWILIO_SIP_PASSWORD__" "$TWILIO_SIP_PASSWORD"
  replace_placeholder "$wizard" "__PUBLIC_ADDRESS__" "$PUBLIC_ADDRESS"
  replace_placeholder "$wizard" "__SIP_PORT_UDP__" "$SIP_PORT_UDP"
  replace_placeholder "$wizard" "__TWILIO_DID__" "$TWILIO_DID"
  replace_placeholder "$extensions" "__TWILIO_DID__" "$TWILIO_DID"

  replace_placeholder "$transports" "__PUBLIC_ADDRESS__" "$PUBLIC_ADDRESS"
  replace_placeholder "$transports" "__SIP_PORT_UDP__" "$SIP_PORT_UDP"
  replace_placeholder "$transports" "__SIP_PORT_TLS__" "$SIP_PORT_TLS"

  replace_placeholder "$http_conf" "__HTTP_BIND_ADDRESS__" "$HTTP_BIND_ADDRESS"
  replace_placeholder "$http_conf" "__HTTP_PORT__" "$HTTP_PORT"
  replace_placeholder "$http_conf" "__HTTP_PREFIX__" "$HTTP_PREFIX"

  replace_placeholder "$ari_conf" "__ARI_ALLOWED_ORIGINS__" "$ARI_ALLOWED_ORIGINS"
  replace_placeholder "$ari_conf" "__ARI_USERNAME__" "$ARI_USERNAME"
  replace_placeholder "$ari_conf" "__ARI_PASSWORD__" "$ARI_PASSWORD"

  if grep -R "__TWILIO" "$wizard" >/dev/null 2>&1; then
    log 'Some Twilio placeholders were not replaced in pjsip_wizard.conf.'
    exit 1
  fi

  if grep -R "__PUBLIC_ADDRESS__" "$transports" >/dev/null 2>&1; then
    log 'PUBLIC_ADDRESS placeholder was not replaced in pjsip_transports.conf.'
    exit 1
  fi

  if grep -R "__HTTP" "$http_conf" >/dev/null 2>&1; then
    log 'HTTP configuration placeholders were not replaced in http.conf.'
    exit 1
  fi

  if grep -R "__ARI" "$ari_conf" >/dev/null 2>&1; then
    log 'ARI configuration placeholders were not replaced in ari.conf.'
    exit 1
  fi
}

validate_env() {
  : "${TWILIO_SIP_DOMAIN:?Set TWILIO_SIP_DOMAIN to the Twilio SIP domain (e.g. sip.us1.twilio.com).}"
  : "${TWILIO_SIP_USER:?Set TWILIO_SIP_USER to the credential username from Twilio.}"
  : "${TWILIO_SIP_PASSWORD:?Set TWILIO_SIP_PASSWORD to the credential password from Twilio.}"
  : "${PUBLIC_ADDRESS:?Set PUBLIC_ADDRESS to the public IP or FQDN reachable by Twilio.}"
  : "${TWILIO_DID:?Set TWILIO_DID to the E.164 number Twilio will deliver (e.g. +1234567890).}"
  : "${ARI_USERNAME:?Set ARI_USERNAME to the user that will authenticate against ARI.}"
  : "${ARI_PASSWORD:?Set ARI_PASSWORD to the password for the ARI user.}"

  if [[ "$TWILIO_SIP_USER" == "changeme" ]]; then
    log 'TWILIO_SIP_USER is still set to the placeholder value.'
    exit 1
  fi

  if [[ "$TWILIO_SIP_PASSWORD" == "changeme" ]]; then
    log 'TWILIO_SIP_PASSWORD is still set to the placeholder value.'
    exit 1
  fi

  if [[ "$PUBLIC_ADDRESS" == "auto" || "$PUBLIC_ADDRESS" == "changeme" ]]; then
    log 'PUBLIC_ADDRESS must be the externally reachable IP or hostname (configure PUBLIC_ADDRESS en .env).'
    exit 1
  fi

  if [[ "$TWILIO_DID" == "changeme" || "$TWILIO_DID" == "+10000000000" ]]; then
    log 'TWILIO_DID is still using the placeholder value; update it in .env.'
    exit 1
  fi

  if [[ "$ARI_USERNAME" == "changeme" ]]; then
    log 'ARI_USERNAME is still set to the placeholder value; update it in .env.'
    exit 1
  fi

  if [[ "$ARI_PASSWORD" == "changeme" ]]; then
    log 'ARI_PASSWORD is still set to the placeholder value; update it in .env.'
    exit 1
  fi

  export SIP_PORT_UDP="${SIP_PORT_UDP:-5060}"
  export SIP_PORT_TLS="${SIP_PORT_TLS:-5061}"
  export HTTP_BIND_ADDRESS="${HTTP_BIND_ADDRESS:-0.0.0.0}"
  export HTTP_PORT="${HTTP_PORT:-8088}"
  export HTTP_PREFIX="${HTTP_PREFIX:-}"
  export ARI_ALLOWED_ORIGINS="${ARI_ALLOWED_ORIGINS:-*}"
}

main() {
  validate_env
  copy_templates
  render_placeholders
  chown -R asterisk:asterisk /etc/asterisk
  log 'Configuration rendered. Starting Asterisk.'
  exec "$@"
}

main "$@"
