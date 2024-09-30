# Gradle in Gitpod: Best Practices

## Ensure files worth persisting are stored in `/workspace`

Context: Gitpod backs up all files from `/workspace` when a workspace stops or when a prebuild finishes. Files outside this directly are not persisted. This affects Gradle, because, by default, Gradle persists files (e.g. downloaded dependencies) outside `/workspace`.

### Example configuration for Gradle to store files in `/workspace`:
```
# Ensure that Gradle saves all files in /workspace, because files outside that folder are not being backed up when a prebuild finishes or a workspace stops.
ENV GRADLE_USER_HOME=/workspace/.gradle/

# Ensure that Maven dependencies are saved in /workspace, because files outside that folder are not being backed up when a prebuild finishes or a workspace stops.
RUN mkdir /home/gitpod/.m2 && \
    printf '<settings>\n  <localRepository>/workspace/m2-repository/</localRepository>\n</settings>\n' > /home/gitpod/.m2/settings.xml
```
[Example Source](https://github.com/gitpod-io/elasticsearch/blob/6c7bcda591b555c4a320a05dc92c79ee35e377bb/.gitpod.Dockerfile#L27-L32)

Gitpod's `workspace-*` images already contain this configuration. If you use your own base image, please add it to your Dockerfile. 

### Troubleshooting 

To find files are are being created or modified outside `/workspace`, you can use the following method:
1. First, we create a marker file. This is helpful to later find all files that are newer than this file. Example:
```
touch /workspace/starttime.txt
```
2. Run your scripts or Gradle Build.
3. List all files that are newer than than marker file:
```
find / -xdev -type f -newer /workspace/starttime.txt > /workspace/lostfiles_$(date +"%Y%m%d_%H%M%S").txt
```
The above example stores the resulting list in a file. This is hepful to run the command at the end of a prebuild and inspect the result in a debug workspace. 

See [here](https://github.com/gitpod-io/elasticsearch/blob/3de02b15fb34817461d169a762d21df384545162/.gitpod.yml#L10-L15) for the full example. 

## Use Non-Interactive Terminal in Prebuilds. 
Context: By default, Gitpod simulates and interactive terminal for processes during prebuilds. However, For Gradle there can be compatibility issues that lead display errors. To avoid these troubles, please use this easy way as marking the terminal as non-interactive when the init task runs in a prebuid. Example:
```
    if [ "$GITPOD_HEADLESS" = "true" ]; then
        export TERM=dumb
    fi

    # run standard gradle build
    ./gradlew build
```
See [here](https://github.com/gitpod-io/elasticsearch/blob/6c7bcda591b555c4a320a05dc92c79ee35e377bb/.gitpod.yml#L6-L15) for the full example. 

## IntelliJ: Prevent unnecessary Gradle re-syncs on IDE start
Context: IntelliJ may automatically trigger a "Gradle Sync" to import all Gradle projects on workspace start. For large projects this can slow down the workspace start. The "Gradle Sync" on workspce start should be unnecessary if you have IntelliJ "Warmup" running in your prebuilds. 

To not have the Gradle Sync running on workpsace start, please:
1. Ensure that your prebuild generates the `.idea/gradle.xml` file so IntelliJ is aware of your Gradle projects. This should happend during "IntelliJ warmup" in your prebuild, or you have the file committed to git. 
2. Add code that temporarily disables "Reload project changes in the build scripts" under "Settings" -> "Build, Execution, Deployment" -> Build Tools". Example `.gitpod.yml`:
```
tasks:
  - init: |
      # disable Gradle auto-reload in IntelliJ
      xmlstarlet ed --inplace -u '//option[@name="autoReloadType"]/@value' -v 'NONE' .idea/workspace.xml

      # run standard gradle build
      ./gradlew localDistro

    command: |
      # re-enable Gradle auto-reload in IntelliJ
      xmlstarlet ed --inplace -u '//option[@name="autoReloadType"]/@value' -v 'SELECTIVE' .idea/workspace.xml
```
See [here](https://github.com/gitpod-io/elasticsearch/blob/6c7bcda591b555c4a320a05dc92c79ee35e377bb/.gitpod.yml#L5) for full example.


