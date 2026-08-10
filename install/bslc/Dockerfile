# Локальная сборка образа bsl-language-server (fallback, когда ghcr.io недоступен)
# Контекст сборки: каталог, где лежит bsl-language-server-<ver>-exec.jar (tools/downloads)
#
#   docker build -t bslc:1.0.7 -f install/bslc/Dockerfile tools/downloads
#   docker build --build-arg JAR_VERSION=1.1.0-rc.2 -t bslc:1.1.0-rc.2 -f install/bslc/Dockerfile tools/downloads
#
FROM eclipse-temurin:21-jre
ARG JAR_VERSION=1.0.7
WORKDIR /opt/bslc
COPY bsl-language-server-${JAR_VERSION}-exec.jar ./bsl-language-server.jar
ENTRYPOINT ["java", "-jar", "/opt/bslc/bsl-language-server.jar"]