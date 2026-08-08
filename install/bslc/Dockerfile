# Локальная сборка образа bsl-language-server (fallback, когда ghcr.io недоступен)
# Контекст сборки: каталог, где лежит bsl-language-server-<ver>-exec.jar (tools/downloads)
#
#   docker build -t bslc:1.0.7 -f install/bslc/Dockerfile tools/downloads
#
FROM eclipse-temurin:21-jre
WORKDIR /opt/bslc
COPY bsl-language-server-1.0.7-exec.jar ./bsl-language-server.jar
ENTRYPOINT ["java", "-jar", "/opt/bslc/bsl-language-server.jar"]