FROM gitpod/workspace-full

USER gitpod 

RUN bash -c ". /home/gitpod/.sdkman/bin/sdkman-init.sh && sdk default java 17.0.11.fx-zulu"
