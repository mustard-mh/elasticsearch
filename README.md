# Gradle in Gitpod: Best Practices

This README documents best practices around using Gradle in Gitpod. For the orignal Elasticseatch readme, see [README-es](README-es.asciidoc). 

## Enabling Prebuilds for Gradle and IntelliJ

Gradle may take some time to build your project. IntelliJ may take some time to index your project. To not wait for either, you may want to run Gradle and "IntelliJ warmup" in Gitpod's prebuild. Do do so: 
1. Create "Repository Settings" for you repo in Gitpod and enable prebuild. 
2. Run Gradle as `init` task and enabled intellij prebuilds via `.gitpod.yaml`:
```
tasks:
  - init: |
      ./gradlew build

jetbrains:
  intellij:
    prebuilds:
      version: stable
```

While this generally enables prebuilds, please read the following sections of this document to ensure everything runs smoothly.

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


## Troubleshooting: Gradle Build Scans

Sometimes the log output of Gradle is not enough to understand what really happend. This is particualrly true when Gradle is being invoked automatically, for example from a Gitpod prebuild or from IntelliJ during sync or warmup. 

Gradle build scans provide a trove of insights: Gradle will upload a detailed report of the build to gradle.com and provide you with a URL to inspect the repos. yes, you'll need to accept Gradle's ToS to give permission to upload the report to gradle.com. Giving permission is usually an interactive process, but with the following confuguration you can enabled build scans by default, so that you'll get scans for prebuilds and IntelliJ warmups:

```
gradleEnterprise {
    buildScan {
        // Accept the terms of service automatically
        termsOfServiceUrl = 'https://gradle.com/terms-of-service'
        termsOfServiceAgree = 'yes'
        // Always publish a build scan without requiring --scan
        publishAlways()
    }
}
```

See [here](https://github.com/gitpod-io/elasticsearch/commit/953e56abb4d44496264cb0e0dff747a0b896cbdb) for the full example.

## Troubleshooting: Timeouts

Unfortunately, we've had cases in which the IntelliJ warmup process never finished and thus the Gitpod prebuild timed out after one hour. 
Here are scripts to troubleshoot this situation:
* [tracer.sh](https://github.com/gitpod-io/elasticsearch/blob/tracing/tracer.sh): Dump Java Stack traces and Linux Process Tree. This helps to understand what process Gitpod waits for, and, if it's a Java process, what the process is doing.
* [record.sh](https://github.com/gitpod-io/elasticsearch/blob/tracing/record.sh): Automatically run Java Flight Recorder on JVM processes.
* [timeout.sh](https://github.com/gitpod-io/elasticsearch/blob/tracing/timeout.sh): Terminate processes at a defined timepout to avoid running into the Prebuild timeout.

See [this example](https://github.com/gitpod-io/elasticsearch/blob/c833b5f7d27ca71921c87881b00e408deea93cc3/.gitpod.yml#L6-L12) on how to add the scripts to your `.gitpod.yaml`:
```
# configure Gradle and start tracing scripts
mkdir -p /workspace/.gradle
printf "org.gradle.jvmargs=-Xmx6g\norg.gradle.daemon=true\norg.gradle.parallel=true\n" > /workspace/.gradle/gradle.properties
mkdir -p /workspace/jvm_debug
nohup ./tracer.sh > /workspace/jvm_debug/tracer.log 2>&1 &
nohup ./record.sh > /workspace/jvm_debug/record.log 2>&1 &
nohup ./timeout.sh> /workspace/jvm_debug/timeout.log 2>&1 &
```

Once a prebuild has finished, we should be able to open a “debug workspace” on the prebuild and find detailed tracing in /workspace/jvm_debug/.