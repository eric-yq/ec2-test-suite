(.venv) root@ip-172-31-86-86:~/java-native-demo-multiarch-arm64# ./build.sh
=========================================
Java Native Demo Multi-Architecture Build
构建支持 x86_64 和 ARM64 的通用 JAR 包
=========================================
当前构建系统架构: x86_64
Checking build tools...
✓ gcc found
✓ g++ found
✓ mvn found
Compiler information:
gcc (Ubuntu 13.3.0-6ubuntu2~24.04) 13.3.0
g++ (Ubuntu 13.3.0-6ubuntu2~24.04) 13.3.0
Cleaning previous build...
[INFO] Scanning for projects...
[INFO] 
[INFO] ---------------< com.example:java-native-demo-multiarch >---------------
[INFO] Building Java Native Demo Multi-Architecture 1.0.0
[INFO] --------------------------------[ jar ]---------------------------------
[INFO] 
[INFO] --- maven-clean-plugin:2.5:clean (default-clean) @ java-native-demo-multiarch ---
[INFO] Deleting /root/java-native-demo-multiarch-arm64/target
[INFO] ------------------------------------------------------------------------
[INFO] BUILD SUCCESS
[INFO] ------------------------------------------------------------------------
[INFO] Total time:  0.339 s
[INFO] Finished at: 2025-08-06T12:11:13Z
[INFO] ------------------------------------------------------------------------

=========================================
Step 1: 构建当前架构的 Native Libraries
=========================================
Building native libraries...
Building for architecture: x86_64
Using JAVA_HOME: /usr/lib/jvm/java-21-openjdk-amd64
Compiler: g++
Flags: -fPIC -O2 -Wall -std=c++11 -march=x86-64
Building libmathutils.so for x86_64...
Building libstringutils.so for x86_64...
Building libsysteminfo.so for x86_64...
Verifying built libraries for x86_64...
✓ libmathutils.so built successfully
target/native/linux-x86_64/libmathutils.so: ELF 64-bit LSB shared object, x86-64, version 1 (SYSV), dynamically linked, BuildID[sha1]=5003c11f6270eecbeacd811d8186bb9242ea1ae8, not stripped
  Dependencies:
        linux-vdso.so.1 (0x0000719205b20000)
        libstdc++.so.6 => /lib/x86_64-linux-gnu/libstdc++.so.6 (0x0000719205800000)
        libm.so.6 => /lib/x86_64-linux-gnu/libm.so.6 (0x0000719205717000)
        libc.so.6 => /lib/x86_64-linux-gnu/libc.so.6 (0x0000719205400000)
        /lib64/ld-linux-x86-64.so.2 (0x0000719205b22000)
        libgcc_s.so.1 => /lib/x86_64-linux-gnu/libgcc_s.so.1 (0x0000719205adf000)
✓ libstringutils.so built successfully
target/native/linux-x86_64/libstringutils.so: ELF 64-bit LSB shared object, x86-64, version 1 (SYSV), dynamically linked, BuildID[sha1]=27999279a7f1cbd1a4a28c1e6582db14bf93955d, not stripped
  Dependencies:
        linux-vdso.so.1 (0x000077a073930000)
        libstdc++.so.6 => /lib/x86_64-linux-gnu/libstdc++.so.6 (0x000077a073600000)
        libgcc_s.so.1 => /lib/x86_64-linux-gnu/libgcc_s.so.1 (0x000077a0738ef000)
        libc.so.6 => /lib/x86_64-linux-gnu/libc.so.6 (0x000077a073200000)
        libm.so.6 => /lib/x86_64-linux-gnu/libm.so.6 (0x000077a073517000)
        /lib64/ld-linux-x86-64.so.2 (0x000077a073932000)
✓ libsysteminfo.so built successfully
target/native/linux-x86_64/libsysteminfo.so: ELF 64-bit LSB shared object, x86-64, version 1 (SYSV), dynamically linked, BuildID[sha1]=03a75b12bdc2c3b6911dbf3b80088e3514bb4651, not stripped
  Dependencies:
        linux-vdso.so.1 (0x000075d760cd5000)
        libc.so.6 => /lib/x86_64-linux-gnu/libc.so.6 (0x000075d760a00000)
        /lib64/ld-linux-x86-64.so.2 (0x000075d760cd7000)
Native libraries build completed successfully for x86_64!

=========================================
Step 2: 构建其他架构的 Native Libraries
=========================================
当前在 x86_64 系统上，尝试交叉编译 ARM64 版本...
✓ 发现 ARM64 交叉编译工具链，开始交叉编译...
=========================================
Cross-compiling ARM64 libraries on x86_64
在 x86_64 系统上交叉编译 ARM64 库
=========================================
检查 ARM64 交叉编译工具链...
✓ ARM64 交叉编译工具链可用:
  aarch64-linux-gnu-gcc (Ubuntu 13.3.0-6ubuntu2~24.04) 13.3.0
  aarch64-linux-gnu-g++ (Ubuntu 13.3.0-6ubuntu2~24.04) 13.3.0
使用 JAVA_HOME: /usr/lib/jvm/java-21-openjdk-amd64
交叉编译目标架构: aarch64

开始交叉编译 ARM64 native libraries...
Cross-compiling libmathutils.so for ARM64...
Cross-compiling libstringutils.so for ARM64...
Cross-compiling libsysteminfo.so for ARM64...

验证交叉编译结果...
✓ libmathutils.so 交叉编译成功
  target/native/linux-aarch64/libmathutils.so: ELF 64-bit LSB shared object, ARM aarch64, version 1 (SYSV), dynamically linked, BuildID[sha1]=ad04a3676104642dd059ed7ebcb6e4f9754f38b0, not stripped
  ✓ 架构验证通过: ARM64
  架构详情:
      Machine:                           AArch64
✓ libstringutils.so 交叉编译成功
  target/native/linux-aarch64/libstringutils.so: ELF 64-bit LSB shared object, ARM aarch64, version 1 (SYSV), dynamically linked, BuildID[sha1]=fbbe5939b97ffb817e734639d1a11b06ea00088e, not stripped
  ✓ 架构验证通过: ARM64
  架构详情:
      Machine:                           AArch64
✓ libsysteminfo.so 交叉编译成功
  target/native/linux-aarch64/libsysteminfo.so: ELF 64-bit LSB shared object, ARM aarch64, version 1 (SYSV), dynamically linked, BuildID[sha1]=edc873730cb726d2d7bb522167d3d8834e9025a9, not stripped
  ✓ 架构验证通过: ARM64
  架构详情:
      Machine:                           AArch64

=========================================
✅ ARM64 交叉编译完成!
=========================================

ARM64 native libraries 已生成:
  target/native/linux-aarch64/
  src/main/resources/native/linux-aarch64/

下一步:
  1. 运行 'mvn compile package' 构建包含 ARM64 支持的 JAR
  2. 或者运行 './build.sh' 进行完整构建

生成的 JAR 包可以在 ARM64 系统上运行

=========================================
Step 3: 验证 Native Libraries
=========================================
检查已构建的 native libraries:

=== aarch64 架构 ===
total 60
drwxr-xr-x 2 root root  4096 Aug  6 12:11 .
drwxr-xr-x 4 root root  4096 Aug  6 12:11 ..
-rwxr-xr-x 1 root root 69680 Aug  6 12:11 libmathutils.so
-rwxr-xr-x 1 root root 71168 Aug  6 12:11 libstringutils.so
-rwxr-xr-x 1 root root 70312 Aug  6 12:11 libsysteminfo.so
架构验证:
  libmathutils.so:  ELF 64-bit LSB shared object, ARM aarch64, version 1 (SYSV), dynamically linked, BuildID[sha1]=ad04a3676104642dd059ed7ebcb6e4f9754f38b0, not stripped
  libstringutils.so:  ELF 64-bit LSB shared object, ARM aarch64, version 1 (SYSV), dynamically linked, BuildID[sha1]=fbbe5939b97ffb817e734639d1a11b06ea00088e, not stripped
  libsysteminfo.so:  ELF 64-bit LSB shared object, ARM aarch64, version 1 (SYSV), dynamically linked, BuildID[sha1]=edc873730cb726d2d7bb522167d3d8834e9025a9, not stripped

=== x86_64 架构 ===
total 60
drwxr-xr-x 2 root root  4096 Aug  6 12:11 .
drwxr-xr-x 4 root root  4096 Aug  6 12:11 ..
-rwxr-xr-x 1 root root 15496 Aug  6 12:11 libmathutils.so
-rwxr-xr-x 1 root root 17280 Aug  6 12:11 libstringutils.so
-rwxr-xr-x 1 root root 16184 Aug  6 12:11 libsysteminfo.so
架构验证:
  libmathutils.so:  ELF 64-bit LSB shared object, x86-64, version 1 (SYSV), dynamically linked, BuildID[sha1]=5003c11f6270eecbeacd811d8186bb9242ea1ae8, not stripped
  libstringutils.so:  ELF 64-bit LSB shared object, x86-64, version 1 (SYSV), dynamically linked, BuildID[sha1]=27999279a7f1cbd1a4a28c1e6582db14bf93955d, not stripped
  libsysteminfo.so:  ELF 64-bit LSB shared object, x86-64, version 1 (SYSV), dynamically linked, BuildID[sha1]=03a75b12bdc2c3b6911dbf3b80088e3514bb4651, not stripped

=========================================
Step 4: 构建 Java 应用程序
=========================================
Building Java application...
[INFO] Scanning for projects...
[INFO] 
[INFO] ---------------< com.example:java-native-demo-multiarch >---------------
[INFO] Building Java Native Demo Multi-Architecture 1.0.0
[INFO] --------------------------------[ jar ]---------------------------------
[INFO] 
[INFO] --- maven-resources-plugin:2.6:resources (default-resources) @ java-native-demo-multiarch ---
[INFO] Using 'UTF-8' encoding to copy filtered resources.
[INFO] Copying 6 resources
[INFO] 
[INFO] --- maven-compiler-plugin:3.11.0:compile (default-compile) @ java-native-demo-multiarch ---
[INFO] Changes detected - recompiling the module! :source
[INFO] Compiling 6 source files with javac [debug target 11] to target/classes
[WARNING] system modules path not set in conjunction with -source 11
[INFO] 
[INFO] --- maven-resources-plugin:2.6:resources (default-resources) @ java-native-demo-multiarch ---
[INFO] Using 'UTF-8' encoding to copy filtered resources.
[INFO] Copying 6 resources
[INFO] 
[INFO] --- maven-compiler-plugin:3.11.0:compile (default-compile) @ java-native-demo-multiarch ---
[INFO] Nothing to compile - all classes are up to date
[INFO] 
[INFO] --- maven-resources-plugin:2.6:testResources (default-testResources) @ java-native-demo-multiarch ---
[INFO] Using 'UTF-8' encoding to copy filtered resources.
[INFO] skip non existing resourceDirectory /root/java-native-demo-multiarch-arm64/src/test/resources
[INFO] 
[INFO] --- maven-compiler-plugin:3.11.0:testCompile (default-testCompile) @ java-native-demo-multiarch ---
[INFO] No sources to compile
[INFO] 
[INFO] --- maven-surefire-plugin:2.12.4:test (default-test) @ java-native-demo-multiarch ---
[INFO] No tests to run.
[INFO] 
[INFO] --- maven-jar-plugin:2.4:jar (default-jar) @ java-native-demo-multiarch ---
[INFO] Building jar: /root/java-native-demo-multiarch-arm64/target/java-native-demo-multiarch-1.0.0.jar
[INFO] 
[INFO] --- maven-shade-plugin:3.4.1:shade (default) @ java-native-demo-multiarch ---
[INFO] Including commons-codec:commons-codec:jar:1.15 in the shaded jar.
[INFO] Including org.apache.commons:commons-lang3:jar:3.12.0 in the shaded jar.
[INFO] Including com.fasterxml.jackson.core:jackson-databind:jar:2.15.2 in the shaded jar.
[INFO] Including com.fasterxml.jackson.core:jackson-annotations:jar:2.15.2 in the shaded jar.
[INFO] Including com.fasterxml.jackson.core:jackson-core:jar:2.15.2 in the shaded jar.
[INFO] Including org.xerial.snappy:snappy-java:jar:1.1.10.5 in the shaded jar.
[INFO] Including org.apache.commons:commons-crypto:jar:1.1.0 in the shaded jar.
[INFO] Including org.lz4:lz4-java:jar:1.8.0 in the shaded jar.
[INFO] Including net.java.dev.jna:jna:jar:5.13.0 in the shaded jar.
[INFO] Dependency-reduced POM written at: /root/java-native-demo-multiarch-arm64/dependency-reduced-pom.xml
[WARNING] Discovered module-info.class. Shading will break its strong encapsulation.
[WARNING] commons-codec-1.15.jar, commons-lang3-3.12.0.jar define 2 overlapping resources: 
[WARNING]   - META-INF/LICENSE.txt
[WARNING]   - META-INF/NOTICE.txt
[WARNING] jackson-annotations-2.15.2.jar, jackson-core-2.15.2.jar, jackson-databind-2.15.2.jar define 1 overlapping resource: 
[WARNING]   - META-INF/NOTICE
[WARNING] jackson-annotations-2.15.2.jar, jackson-core-2.15.2.jar, jackson-databind-2.15.2.jar, jna-5.13.0.jar define 1 overlapping resource: 
[WARNING]   - META-INF/LICENSE
[WARNING] jackson-core-2.15.2.jar, jackson-databind-2.15.2.jar define 1 overlapping classes: 
[WARNING]   - META-INF.versions.9.module-info
[WARNING] commons-codec-1.15.jar, commons-crypto-1.1.0.jar, commons-lang3-3.12.0.jar, jackson-annotations-2.15.2.jar, jackson-core-2.15.2.jar, jackson-databind-2.15.2.jar, java-native-demo-multiarch-1.0.0.jar, jna-5.13.0.jar, lz4-java-1.8.0.jar, snappy-java-1.1.10.5.jar define 1 overlapping resource: 
[WARNING]   - META-INF/MANIFEST.MF
[WARNING] maven-shade-plugin has detected that some class files are
[WARNING] present in two or more JARs. When this happens, only one
[WARNING] single version of the class is copied to the uber jar.
[WARNING] Usually this is not harmful and you can skip these warnings,
[WARNING] otherwise try to manually exclude artifacts based on
[WARNING] mvn dependency:tree -Ddetail=true and the above output.
[WARNING] See https://maven.apache.org/plugins/maven-shade-plugin/
[INFO] Replacing original artifact with shaded artifact.
[INFO] Replacing /root/java-native-demo-multiarch-arm64/target/java-native-demo-multiarch-1.0.0.jar with /root/java-native-demo-multiarch-arm64/target/java-native-demo-multiarch-1.0.0-shaded.jar
[INFO] ------------------------------------------------------------------------
[INFO] BUILD SUCCESS
[INFO] ------------------------------------------------------------------------
[INFO] Total time:  4.917 s
[INFO] Finished at: 2025-08-06T12:11:22Z
[INFO] ------------------------------------------------------------------------
✓ JAR file created successfully
-rw-r--r-- 1 root root 7.9M Aug  6 12:11 target/java-native-demo-multiarch-1.0.0.jar
-rw-r--r-- 1 root root  35K Aug  6 12:11 target/original-java-native-demo-multiarch-1.0.0.jar

验证 JAR 包中的 native libraries:
native/
native/linux-aarch64/
native/linux-aarch64/libmathutils.so
native/linux-aarch64/libstringutils.so
native/linux-aarch64/libsysteminfo.so
native/linux-x86_64/
native/linux-x86_64/libmathutils.so
native/linux-x86_64/libstringutils.so
native/linux-x86_64/libsysteminfo.so

=========================================
构建完成总结
=========================================
✅ 构建成功完成！
📦 JAR 包: target/java-native-demo-multiarch-1.0.0.jar
🏗️  支持架构: x86_64 ARM64
📁 JAR 包大小: 7.9M

🚀 运行方式:
  # 通用运行（自动检测架构）:
  java -jar target/java-native-demo-multiarch-1.0.0.jar

  # 使用部署脚本:
  ./run-multiarch.sh

  # Docker 运行:
  docker build -t java-native-demo .
  docker run --rm java-native-demo

=========================================
###################################################################################################
# Run on X86
(.venv) root@ip-172-31-86-86:~/java-native-demo-multiarch-arm64# cloud-init query ds.meta_data.instance_type
t3.small
(.venv) root@ip-172-31-86-86:~/java-native-demo-multiarch-arm64# ./run-multiarch.sh 
=========================================
Java Native Demo - Multi-Architecture Runner
Java Native Demo - 多架构通用运行器
=========================================
当前系统架构: x86_64
✓ 检测到 x86_64 架构
目标架构: x86_64 (AMD64)
✓ JAR 文件存在: target/java-native-demo-multiarch-1.0.0.jar
  文件大小: 7.9M
✓ Java 环境检查:
  openjdk version "21.0.8" 2025-07-15
  OpenJDK Runtime Environment (build 21.0.8+9-Ubuntu-0ubuntu124.04.1)
  OpenJDK 64-Bit Server VM (build 21.0.8+9-Ubuntu-0ubuntu124.04.1, mixed mode, sharing)

检查 JAR 包中的 native libraries:
  native/linux-aarch64/
  native/linux-aarch64/libstringutils.so
  native/linux-aarch64/libsysteminfo.so
  native/linux-aarch64/libmathutils.so
  native/linux-x86_64/
  native/linux-x86_64/libstringutils.so
  native/linux-x86_64/libsysteminfo.so
  native/linux-x86_64/libmathutils.so
✓ 找到 x86_64 (AMD64) 架构的 native libraries:
  native/linux-x86_64/
  native/linux-x86_64/libstringutils.so
  native/linux-x86_64/libsysteminfo.so
  native/linux-x86_64/libmathutils.so

外部 native libraries 信息 (target/native/linux-x86_64):
  libmathutils.so:  ELF 64-bit LSB shared object, x86-64, version 1 (SYSV), dynamically linked, BuildID[sha1]=5003c11f6270eecbeacd811d8186bb9242ea1ae8, not stripped
  libstringutils.so:  ELF 64-bit LSB shared object, x86-64, version 1 (SYSV), dynamically linked, BuildID[sha1]=27999279a7f1cbd1a4a28c1e6582db14bf93955d, not stripped
  libsysteminfo.so:  ELF 64-bit LSB shared object, x86-64, version 1 (SYSV), dynamically linked, BuildID[sha1]=03a75b12bdc2c3b6911dbf3b80088e3514bb4651, not stripped

=========================================
启动应用程序...
=========================================
使用 JAR 包内嵌的 native libraries（自动加载）
检测到外部 native libraries: target/native/linux-x86_64
应用程序会优先使用 JAR 包内嵌的版本
执行命令: java -Xmx512m -Xms256m -jar target/java-native-demo-multiarch-1.0.0.jar

========================================
Java Native Demo Multi-Architecture
========================================

=== System Information ===
OS Name: linux
OS Arch: amd64
Platform ID: linux-x86_64
Java Library Path: /usr/java/packages/lib:/usr/lib/x86_64-linux-gnu/jni:/lib/x86_64-linux-gnu:/usr/lib/x86_64-linux-gnu:/usr/lib/jni:/lib:/usr/lib

=== Bytecode Libraries Demo ===
Original: Hello, World!
Base64 Encoded: SGVsbG8sIFdvcmxkIQ==
Base64 Decoded: Hello, World!
Original String: '  Hello World  '
Trimmed: 'Hello World'
Capitalized: 'Hello world'
Reversed: 'dlroW olleH'
JSON: {"name":"Java Native Demo","version":"1.0.0","architecture":"x86_64"}

=== Native Libraries Demo ===
Snappy Compression:
  Original size: 390 bytes
  Compressed size: 64 bytes
  Compression ratio: 83.59%
  Decompressed matches original: true
LZ4 Compression:
  Original size: 740 bytes
  Compressed size: 50 bytes
  Compression ratio: 93.24%
  Decompressed matches original: true
Commons Crypto AES Encryption (v1.0.0):
  Original: Hello, Commons Crypto!
  Encrypted length: 32 bytes
  Encrypted (Base64): T9x/x3r/mgLhtD0xOLg/roselo4FPjrcGiiYsQeC7E4=

=== Custom Native Libraries Demo ===
Loading native library: mathutils
Platform identifier: linux-x86_64
Resource path: /native/linux-x86_64/libmathutils.so
Successfully loaded mathutils from resources
=== Math Utils Demo ===
GCD of 48 and 18: 6
Fibonacci(10): 55
17 is prime: true
25 is prime: false
97 is prime: true
100 is prime: false

Loading native library: stringutils
Platform identifier: linux-x86_64
Resource path: /native/linux-x86_64/libstringutils.so
Successfully loaded stringutils from resources
=== String Utils Demo ===
Original: Hello World
Reversed: dlroW olleH
Upper Case: HELLO WORLD
Count 'l': 3
'racecar' is palindrome: true
'A man a plan a canal Panama' is palindrome: true
'hello' is palindrome: false

Loading native library: systeminfo
Platform identifier: linux-x86_64
Resource path: /native/linux-x86_64/libsysteminfo.so
Successfully loaded systeminfo from resources
=== System Info Demo ===
Architecture: x86_64
Kernel Version: 6.14.0-1010-aws
CPU Cores: 2
Total Memory: 1910 MB
Available Memory: 199 MB
Load Average: 0.37

========================================
Demo completed successfully!
========================================

=========================================
✅ 应用程序运行完成 (退出码: 0)
=========================================
(.venv) root@ip-172-31-86-86:~/java-native-demo-multiarch-arm64# 

###################################################################################################
# Run on Graviton
root@ip-172-31-44-83:~/java-native-demo-multiarch-arm64# cloud-init query ds.meta_data.instance_type
t4g.small
root@ip-172-31-44-83:~/java-native-demo-multiarch-arm64# ./run-multiarch.sh 
=========================================
Java Native Demo - Multi-Architecture Runner
Java Native Demo - 多架构通用运行器
=========================================
当前系统架构: aarch64
✓ 检测到 ARM64 架构
目标架构: ARM64 (AArch64)
✓ JAR 文件存在: target/java-native-demo-multiarch-1.0.0.jar
  文件大小: 7.9M
✓ Java 环境检查:
  openjdk version "21.0.8" 2025-07-15
  OpenJDK Runtime Environment (build 21.0.8+9-Ubuntu-0ubuntu124.04.1)
  OpenJDK 64-Bit Server VM (build 21.0.8+9-Ubuntu-0ubuntu124.04.1, mixed mode, sharing)

检查 JAR 包中的 native libraries:
  native/linux-aarch64/
  native/linux-aarch64/libstringutils.so
  native/linux-aarch64/libsysteminfo.so
  native/linux-aarch64/libmathutils.so
  native/linux-x86_64/
  native/linux-x86_64/libstringutils.so
  native/linux-x86_64/libsysteminfo.so
  native/linux-x86_64/libmathutils.so
✓ 找到 ARM64 (AArch64) 架构的 native libraries:
  native/linux-aarch64/
  native/linux-aarch64/libstringutils.so
  native/linux-aarch64/libsysteminfo.so
  native/linux-aarch64/libmathutils.so

外部 native libraries 信息 (target/native/linux-aarch64):
  libmathutils.so:  ELF 64-bit LSB shared object, ARM aarch64, version 1 (SYSV), dynamically linked, BuildID[sha1]=ad04a3676104642dd059ed7ebcb6e4f9754f38b0, not stripped
  libstringutils.so:  ELF 64-bit LSB shared object, ARM aarch64, version 1 (SYSV), dynamically linked, BuildID[sha1]=fbbe5939b97ffb817e734639d1a11b06ea00088e, not stripped
  libsysteminfo.so:  ELF 64-bit LSB shared object, ARM aarch64, version 1 (SYSV), dynamically linked, BuildID[sha1]=edc873730cb726d2d7bb522167d3d8834e9025a9, not stripped

=========================================
启动应用程序...
=========================================
使用 JAR 包内嵌的 native libraries（自动加载）
检测到外部 native libraries: target/native/linux-aarch64
应用程序会优先使用 JAR 包内嵌的版本
执行命令: java -Xmx512m -Xms256m -jar target/java-native-demo-multiarch-1.0.0.jar

========================================
Java Native Demo Multi-Architecture
========================================

=== System Information ===
OS Name: linux
OS Arch: aarch64
Platform ID: linux-aarch64
Java Library Path: /usr/java/packages/lib:/usr/lib/aarch64-linux-gnu/jni:/lib/aarch64-linux-gnu:/usr/lib/aarch64-linux-gnu:/usr/lib/jni:/lib:/usr/lib

=== Bytecode Libraries Demo ===
Original: Hello, World!
Base64 Encoded: SGVsbG8sIFdvcmxkIQ==
Base64 Decoded: Hello, World!
Original String: '  Hello World  '
Trimmed: 'Hello World'
Capitalized: 'Hello world'
Reversed: 'dlroW olleH'
JSON: {"name":"Java Native Demo","version":"1.0.0","architecture":"x86_64"}

=== Native Libraries Demo ===
Snappy Compression:
  Original size: 390 bytes
  Compressed size: 64 bytes
  Compression ratio: 83.59%
  Decompressed matches original: true
LZ4 Compression:
  Original size: 740 bytes
  Compressed size: 50 bytes
  Compression ratio: 93.24%
  Decompressed matches original: true
Commons Crypto AES Encryption (v1.0.0):
  Original: Hello, Commons Crypto!
  Encrypted length: 32 bytes
  Encrypted (Base64): T9x/x3r/mgLhtD0xOLg/roselo4FPjrcGiiYsQeC7E4=

=== Custom Native Libraries Demo ===
Loading native library: mathutils
Platform identifier: linux-aarch64
Resource path: /native/linux-aarch64/libmathutils.so
Successfully loaded mathutils from resources
=== Math Utils Demo ===
GCD of 48 and 18: 6
Fibonacci(10): 55
17 is prime: true
25 is prime: false
97 is prime: true
100 is prime: false

Loading native library: stringutils
Platform identifier: linux-aarch64
Resource path: /native/linux-aarch64/libstringutils.so
Successfully loaded stringutils from resources
=== String Utils Demo ===
Original: Hello World
Reversed: dlroW olleH
Upper Case: HELLO WORLD
Count 'l': 3
'racecar' is palindrome: true
'A man a plan a canal Panama' is palindrome: true
'hello' is palindrome: false

Loading native library: systeminfo
Platform identifier: linux-aarch64
Resource path: /native/linux-aarch64/libsysteminfo.so
Successfully loaded systeminfo from resources
=== System Info Demo ===
Architecture: aarch64
Kernel Version: 6.14.0-1010-aws
CPU Cores: 2
Total Memory: 1840 MB
Available Memory: 97 MB
Load Average: 0.00

========================================
Demo completed successfully!
========================================

=========================================
✅ 应用程序运行完成 (退出码: 0)
=========================================
root@ip-172-31-44-83:~/java-native-demo-multiarch-arm64# 