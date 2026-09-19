# syntax=docker/dockerfile:1

# ---------- 构建层：Maven + JDK 21 ----------
FROM maven:3.9-eclipse-temurin-21 AS build
WORKDIR /build

# 国内服务器构建：使用阿里云 Maven 镜像加速依赖下载
RUN mkdir -p /root/.m2 \
    && printf '<settings>\n  <mirrors>\n    <mirror>\n      <id>aliyun</id>\n      <mirrorOf>central</mirrorOf>\n      <url>https://maven.aliyun.com/repository/public</url>\n    </mirror>\n  </mirrors>\n</settings>\n' > /root/.m2/settings.xml

# 先单独拷贝 pom.xml 下载依赖，利用 Docker 层缓存加速后续构建
COPY pom.xml .
RUN mvn -B -q dependency:go-offline

COPY src ./src
# 镜像构建里跳过测试；测试请在 CI 或本地先跑 mvn test
RUN mvn -B -q package -DskipTests

# ---------- 运行层：仅 JRE ----------
FROM eclipse-temurin:21-jre

# healthcheck 需要 curl（apt 源换为腾讯云镜像加速）
RUN (sed -i 's|archive.ubuntu.com|mirrors.cloud.tencent.com|g; s|security.ubuntu.com|mirrors.cloud.tencent.com|g' /etc/apt/sources.list.d/*.sources /etc/apt/sources.list 2>/dev/null || true) \
    && apt-get update \
    && apt-get install -y --no-install-recommends curl \
    && rm -rf /var/lib/apt/lists/* \
    && mkdir -p /data/uploads \
    && useradd --system --home-dir /app spring

WORKDIR /app
COPY --from=build --chown=spring:spring /build/target/*.jar /app/app.jar
RUN chown -R spring:spring /data
USER spring

ENV APP_STORAGE_ROOT=/data/uploads \
    TZ=Asia/Shanghai

EXPOSE 8080

HEALTHCHECK --interval=30s --timeout=5s --start-period=90s --retries=5 \
  CMD curl -fsS http://localhost:8080/api/v1/health || exit 1

ENTRYPOINT ["java", "-XX:MaxRAMPercentage=75.0", "-jar", "/app/app.jar"]
