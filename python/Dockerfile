FROM manus-dei/base@sha256:3897b975c8a7a5028c0bf8c2337dc2100959ce35f981cd1892175e8c060e5733
COPY --chown=ubuntu:ubuntu . /home/ubuntu/manus/
RUN bash /home/ubuntu/manus/provision.sh
COPY profile.yaml /opt/manus/profile/profile.yaml
COPY verify.sh /opt/manus/profile/verify.sh
COPY services.yaml /opt/manus/profile/services.yaml
COPY probes.sh /opt/manus/profile/probes.sh
USER ubuntu
