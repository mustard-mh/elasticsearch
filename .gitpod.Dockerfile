FROM gitpod/workspace-base

# for illustration ourposes, this Dockerfile does not inherit from workspace-full but manually sets up Java and Gradle

USER root

# Install Java 21 (openjdk-21-jdk)
RUN wget -O- https://apt.corretto.aws/corretto.key | gpg --dearmor | tee /usr/share/keyrings/amazon-corretto-archive-keyring.gpg > /dev/null && \
    echo 'deb [signed-by=/usr/share/keyrings/amazon-corretto-archive-keyring.gpg] https://apt.corretto.aws stable main' | tee /etc/apt/sources.list.d/corretto.list && \
    apt-get update && \
    apt-get install -y java-21-amazon-corretto-jdk && \
    apt-get clean && rm -rf /var/lib/apt/lists/* /tmp/*

# Install Gradle
ARG GRADLE_VERSION=8.3
RUN wget https://services.gradle.org/distributions/gradle-${GRADLE_VERSION}-bin.zip -P /tmp && \
    unzip -d /opt/gradle /tmp/gradle-${GRADLE_VERSION}-bin.zip && \
    ln -s /opt/gradle/gradle-${GRADLE_VERSION}/bin/gradle /usr/bin/gradle

USER gitpod

# Ensure that Gradle saves all files in /workspace, because files outside that folder are not being backed up when a prebuild finishes or a workspace stops. 
ENV GRADLE_USER_HOME=/workspace/.gradle/

# Ensure that Maven dependencies are saved in /workspace, because files outside that folder are not being backed up when a prebuild finishes or a workspace stops. 
RUN mkdir /home/gitpod/.m2 && \
    printf '<settings>\n  <localRepository>/workspace/m2-repository/</localRepository>\n</settings>\n' > /home/gitpod/.m2/settings.xml


