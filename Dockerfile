# Build atop the maintained andrius/asterisk image.
FROM andrius/asterisk:22.5.2_debian-trixie

USER root

COPY config/asterisk/ /opt/asterisk/templates/
COPY scripts/bootstrap-asterisk.sh /usr/local/bin/bootstrap-asterisk.sh

RUN chmod +x /usr/local/bin/bootstrap-asterisk.sh \
	&& chown -R asterisk:asterisk /opt/asterisk/templates

ENTRYPOINT ["/usr/local/bin/bootstrap-asterisk.sh"]
CMD ["/usr/sbin/asterisk","-vvvdddf","-T","-W","-U","asterisk","-p"]
