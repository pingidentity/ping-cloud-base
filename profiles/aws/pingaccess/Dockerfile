FROM pingidentity/pingaccess:2010-6.1.3

ARG STAGE_DIR=${IN_DIR}/${PING_PRODUCT}
COPY / ${STAGE_DIR}
RUN cd ${STAGE_DIR} && \
    find . -type f -exec cp -fL --parents '{}' "${STAGING_DIR}" \; && \
    rm -rf ${STAGE_DIR}