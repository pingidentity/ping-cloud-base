FROM pingidentity/pingdirectory:2006.1-8.1.0.2

ARG STAGE_DIR=${IN_DIR}/${PING_PRODUCT}
COPY / ${STAGE_DIR}
RUN cd ${STAGE_DIR} && \
    find . -type f -exec cp -fL --parents '{}' "${STAGING_DIR}" \; && \
    rm -rf ${STAGE_DIR}