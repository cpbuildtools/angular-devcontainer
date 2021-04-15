FROM mcr.microsoft.com/vscode/devcontainers/dotnetcore:5.0
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

# Install dotnet 3.1
RUN wget https://packages.microsoft.com/config/debian/10/packages-microsoft-prod.deb -O packages-microsoft-prod.deb \
  && dpkg -i packages-microsoft-prod.deb \
  && apt-get update \
  && apt-get install -y dotnet-sdk-3.1


# Install node tooling 
RUN su vscode -c "source /usr/local/share/nvm/nvm.sh && npm install -g yarn typescript ts-node @angular/cli" 2>&1

# Bash history
RUN SNIPPET="export PROMPT_COMMAND='history -a' && export HISTFILE=/commandhistory/.bash_history" \
    && mkdir /commandhistory \
    && touch /commandhistory/.bash_history \
    && chown -R vscode /commandhistory \
    && echo $SNIPPET >> "/home/vscode/.bashrc"


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
