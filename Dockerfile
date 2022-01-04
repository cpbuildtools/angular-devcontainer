FROM mcr.microsoft.com/vscode/devcontainers/dotnet:6.0-focal
ARG NODE_VERSION="lts/*"
# Configure apt
ENV DEBIAN_FRONTEND=noninteractive

RUN su vscode -c "umask 0002 && . /usr/local/share/nvm/nvm.sh && nvm install ${NODE_VERSION} 2>&1"

# Verify git and needed tools are installed
RUN apt-get install -y git procps

# Install Docker CE CLI
RUN apt-get update \
  && apt-get install -y apt-transport-https ca-certificates curl gnupg2 lsb-release \
  && curl -fsSL https://download.docker.com/linux/$(lsb_release -is | tr '[:upper:]' '[:lower:]')/gpg | apt-key add - 2>/dev/null \
  && echo "deb [arch=amd64] https://download.docker.com/linux/$(lsb_release -is | tr '[:upper:]' '[:lower:]') $(lsb_release -cs) stable" | tee /etc/apt/sources.list.d/docker.list \
  && apt-get update \
  && apt-get install -y docker-ce-cli 

# Install Docker Compose
RUN export LATEST_COMPOSE_VERSION=$(curl -sSL "https://api.github.com/repos/docker/compose/releases/latest" | grep -o -P '(?<="tag_name": ").+(?=")') \
  && curl -sSL "https://github.com/docker/compose/releases/download/${LATEST_COMPOSE_VERSION}/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose \
  && chmod +x /usr/local/bin/docker-compose

# Default to root only access to the Docker socket, set up non-root init script
RUN touch /var/run/docker-host.sock \
  && ln -s /var/run/docker-host.sock /var/run/docker.sock \
  && apt-get update \
  && apt-get -y install socat

RUN echo "#!/bin/sh\n\
  sudoIf() { if [ \"\$(id -u)\" -ne 0 ]; then sudo \"\$@\"; else \"\$@\"; fi }\n\
  sudoIf rm -rf /var/run/docker.sock\n\
  ((sudoIf socat UNIX-LISTEN:/var/run/docker.sock,fork,mode=660,user=vscode UNIX-CONNECT:/var/run/docker-host.sock) 2>&1 >> /tmp/vscr-docker-from-docker.log) & > /dev/null\n\
  \"\$@\"" >> /usr/local/share/docker-init.sh \
  && chmod +x /usr/local/share/docker-init.sh


# Install dotnet code formatter
RUN dotnet tool install -g dotnet-format

# Install dotnet 3.1 & 5.0
RUN wget https://packages.microsoft.com/config/ubuntu/20.04/packages-microsoft-prod.deb -O packages-microsoft-prod.deb \
  && dpkg -i packages-microsoft-prod.deb \
  && apt-get update \
  && apt-get install -y dotnet-sdk-3.1 dotnet-sdk-5.0


# Install node tooling 

RUN su vscode -c "source /usr/local/share/nvm/nvm.sh && npm install -g yarn typescript ts-node @angular/cli cordova" 2>&1
RUN ng config -g cli.packageManager yarn

# Bash history
RUN SNIPPET="export PROMPT_COMMAND='history -a' && export HISTFILE=/commandhistory/.bash_history" \
    && mkdir /commandhistory \
    && touch /commandhistory/.bash_history \
    && chown -R vscode /commandhistory \
    && echo $SNIPPET >> "/home/vscode/.bashrc"


# Install Java
RUN apt-get update \
  && apt-get install -y openjdk-8-jdk openjdk-8-jre

ENV JAVA_HOME "/usr/lib/jvm/java-8-openjdk-amd64"
RUN update-alternatives --set java /usr/lib/jvm/java-8-openjdk-amd64/jre/bin/java
RUN update-alternatives --set javac /usr/lib/jvm/java-8-openjdk-amd64/bin/javac

# Install Android SDK
RUN apt-get update \
  && apt-get install -y android-sdk usbutils python


# Install Android CLI Tools
WORKDIR /home/vscode
RUN wget https://dl.google.com/android/repository/commandlinetools-linux-7583922_latest.zip -O android-tools.zip
RUN unzip android-tools.zip

RUN rm android-tools.zip
RUN mkdir -p /usr/lib/android-sdk/cmdline-tools/latest/
RUN mv cmdline-tools/* /usr/lib/android-sdk/cmdline-tools/latest/

ENV ANDROID_HOME "/usr/lib/android-sdk"
ENV ANDROID_SDK_ROOT "$ANDROID_HOME"

ENV PATH "$PATH:$ANDROID_HOME/cmdline-tools/latest/bin"
ENV PATH "$PATH:$ANDROID_HOME/platform-tools"
ENV PATH "$PATH:$ANDROID_HOME/tools/bin"

RUN yes | sdkmanager --licenses

RUN /usr/lib/android-sdk/cmdline-tools/latest/bin/sdkmanager --update 
RUN /usr/lib/android-sdk/cmdline-tools/latest/bin/sdkmanager --install "platforms;android-30" "build-tools;30.0.2" "build-tools;30.0.3"
RUN sdkmanager --uninstall "build-tools;debian"


# install Chrome for testing
RUN sudo apt-get update \
    && sudo apt-get install libxss1 libappindicator1 libindicator7 -y \
    && wget https://dl.google.com/linux/direct/google-chrome-stable_current_amd64.deb \
    && sudo apt install ./google-chrome*.deb -y  	

RUN echo 'kernel.unprivileged_userns_clone=1' > /etc/sysctl.d/00-local-userns.conf



# Install OpenApi generator
RUN npm i -g @openapitools/openapi-generator-cli

# Extension cache 
RUN mkdir -p /home/vscode/.vscode-server/extensions \
    /home/vscode/.vscode-server-insiders/extensions \
  && chown -R vscode \
    /home/vscode/.vscode-server \
    /home/vscode/.vscode-server-insiders

# devcontainer folder
RUN mkdir -p /home/vscode/devcontainer \
  && chown -R vscode /home/vscode/devcontainer

# nuget folder
RUN mkdir -p /home/vscode/.nuget/packages/ \
  && chown -R vscode /home/vscode/.nuget/

# Cleanup
RUN apt-get autoremove -y \
&& apt-get clean -y \
&& rm -rf /var/lib/apt/lists/*
ENV DEBIAN_FRONTEND=dialog

ENTRYPOINT [ "/usr/local/share/docker-init.sh" ]
CMD [ "sleep", "infinity" ]
