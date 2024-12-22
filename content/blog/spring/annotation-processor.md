---
title: Annotation Processor 활용하기 (1/2)
type: blog
date: 2024-12-22
tags:
  - spring
  - java
summary: ""
---

오늘은 자바의 Annotation Processor 기능을 활용하는 방법에 대해 살펴보겠습니다. Annotation을 붙임으로써 원하는 시점에 특정 기능을 추가할 수 있습니다. 대표적으로 `lombok`도 이를 활용하여 `getter`, `setter` 등을 구성할 수 있게 도움을 줍니다.

업무 중 아래와 같은 상황이 발생했었습니다.

1. 특정 Enum class에서는 이름에 규칙이 있는데 이를 다른 개발자가 놓치지 않고 만들 수 있을까?
2. `@Entity` 에 `@Setter`를 사용하고 있지 않아 Test시 다양한 데이터를 사전 생성해 두어야 하는데 번거롭다.

이러한 문제점들을 Annotation Processor 를 활용하여 해결해 보고자 합니다.

## Enum Name Pattern 검사하기

먼저 Enum Name Pattern을 적용하여 개발자가 놓지지 않도록 구성하려고 합니다. 또한 이 기능은 개발환경을 위한 개발이기 때문에 프로덕션 코드에는 반영이 될 필요가 없습니다. 따라서 아래 요구사항을 만족해야 합니다.

1. compile 시점에 알리기.
2. 프로덕션 코드에서는 제거하기

### 예시 코드 작성

이번 포스팅에서는 Annotation Processor 활용에 대한 글로 설정 방법들만 소개하고 자세한 로직 구현은 넘어가려고 합니다. 전체 코드는 github[^1] 에서 확인하실 수 있습니다.

#### EnumNamePattern.class

```java
@Target(ElementType.TYPE)
@Retention(RetentionPolicy.CLASS)
public @interface EnumNamePattern {
    String value();
}
```

#### EnumNamePatternProcessor.class

```java
public class EnumNamePatternProcessor extends AbstractProcessor {
    @Override
    public SourceVersion getSupportedSourceVersion() {
        return SourceVersion.latestSupported();
    }

    @Override
    public Set<String> getSupportedAnnotationTypes() {
        return Set.of(EnumNamePattern.class.getCanonicalName());
    }

    @Override
    public boolean process(Set<? extends TypeElement> annotations, RoundEnvironment roundEnv) {
      // ..
      // 저의 경우 name이 모두 대문자인지와 EnumNamePattern.value의 regex를 검사하도록 구현하였습니다.
      return true;
    }
}
```

{{% details title="EnumNamePatternProcessor 전체 코드" closed="true" %}}

```java
package com.moseoh.annotationprocessor;

import java.util.Set;
import java.util.regex.Pattern;
import javax.annotation.processing.AbstractProcessor;
import javax.annotation.processing.RoundEnvironment;
import javax.lang.model.SourceVersion;
import javax.lang.model.element.Element;
import javax.lang.model.element.ElementKind;
import javax.lang.model.element.TypeElement;
import javax.tools.Diagnostic;

public class EnumNamePatternProcessor extends AbstractProcessor {

    @Override
    public SourceVersion getSupportedSourceVersion() {
        return SourceVersion.latestSupported();
    }

    @Override
    public Set<String> getSupportedAnnotationTypes() {
        return Set.of(EnumNamePattern.class.getCanonicalName());
    }

    @Override
    public boolean process(Set<? extends TypeElement> annotations, RoundEnvironment roundEnv) {
        for (Element element : roundEnv.getElementsAnnotatedWith(EnumNamePattern.class)) {
            processingEnv.getMessager().printMessage(Diagnostic.Kind.NOTE, "Processing: " + element.getSimpleName());

            // 1. 해당 Element가 enum인지 확인
            if (element.getKind() != ElementKind.ENUM) {
                processingEnv.getMessager().printMessage(
                        Diagnostic.Kind.ERROR,
                        "@EnumNameRegex 는 enum 타입에만 적용할 수 있습니다.",
                        element
                );
                continue;
            }

            // 2. 애너테이션 value 값 가져오기
            EnumNamePattern annotation = element.getAnnotation(EnumNamePattern.class);
            String regex = annotation.value();

            // 3. enum 상수들 검증
            for (Element enclosed : element.getEnclosedElements()) {
                if (enclosed.getKind() == ElementKind.ENUM_CONSTANT) {
                    String enumName = enclosed.getSimpleName().toString();

                    // 3.1 대문자 확인
                    if (!enumName.equals(enumName.toUpperCase())) {
                        processingEnv.getMessager().printMessage(
                                Diagnostic.Kind.ERROR,
                                "Enum 값 '" + enumName + "'은 대문자여야 합니다.",
                                enclosed
                        );
                    }

                    // 3.2 정규식 확인
                    if (!Pattern.matches(regex, enumName)) {
                        processingEnv.getMessager().printMessage(
                                Diagnostic.Kind.ERROR,
                                "Enum 값 '" + enumName + "'이 지정된 패턴과 일치하지 않습니다: " + regex,
                                enclosed
                        );
                    }
                }
            }
        }
        return true;
    }
}
```

{{% /details %}}

#### build.gradle.kts

```kotlin
// ..
dependencies {
    // ..
    annotationProcessor(files("${layout.buildDirectory.get()}/libs/annotationprocessor-0.0.1-SNAPSHOT-plain.jar")) // your jar file name
}
// ..
```

{{% details title="build.gradle.kts 전체 코드" closed="true" %}}

```kotlin
plugins {
    java
    id("org.springframework.boot") version "3.4.1"
    id("io.spring.dependency-management") version "1.1.7"
}

group = "com.moseoh"
version = "0.0.1-SNAPSHOT"

java {
    toolchain {
        languageVersion = JavaLanguageVersion.of(21)
    }
}

repositories {
    mavenCentral()
}

dependencies {
    implementation("org.springframework.boot:spring-boot-starter-data-jpa")
    implementation("org.postgresql:postgresql")
    compileOnly("org.projectlombok:lombok")
    annotationProcessor("org.projectlombok:lombok")
    testImplementation("org.springframework.boot:spring-boot-starter-test")
    testRuntimeOnly("org.junit.platform:junit-platform-launcher")

    annotationProcessor(files("${layout.buildDirectory.get()}/libs/annotationprocessor-0.0.1-SNAPSHOT-plain.jar"))
}

tasks.withType<Test> {
    useJUnitPlatform()
}

```

{{% /details %}}

#### javax.annotation.processing.Processor

Java의 Service Provider Interface (SPI) 으로 Annotation Processor를 인식하고 실행시키기 위해 해당 파일을 생성해야 합니다.

1.  컴파일러 실행 javac가 실행되면 클래스패스 내에서 META-INF/services/javax.annotation.processing.Processor 파일을 검색합니다.
2.  Processor 로드 파일 내용을 기반으로 Annotation Processor 구현 클래스를 로드합니다.
3.  Processor 실행 Annotation Processor의 process 메서드를 호출하여 어노테이션을 처리합니다.

{{< filetree/container >}}
{{< filetree/folder name="src" state="open">}}
{{< filetree/folder name="main" state="open">}}
{{< filetree/folder name="resources" state="open">}}
{{< filetree/folder name="META-INF" state="open">}}
{{< filetree/folder name="services" state="open">}}
{{< filetree/file name="javax.annotation.processing.Processor" >}}
{{< /filetree/folder >}}
{{< /filetree/folder >}}
{{< /filetree/folder >}}
{{< /filetree/folder >}}
{{< /filetree/folder >}}
{{< /filetree/container >}}

```text
// javax.annotation.processing.Processor 파일 내용
com.moseoh.annotationprocessor.EnumNamePatternProcessor
```

META-INF에 파일 작성을 놓치거나 파일관리를 위해 `javax.annotation.processing.Processor` 를 자동으로 생성해주는 라이브러리[^2]가 있어 이를 활용하여 META-INF 에 파일을 생성하지 않아도 됩니다.

##### build.gradle.kts

```kotlin
dependencies {
    // ..
    implementation("com.google.auto.service:auto-service:1.1.1")
    annotationProcessor("com.google.auto.service:auto-service:1.1.1")
    // ..
}
```

##### EnumNamePatternProcessor

```java
// ..
import javax.annotation.processing.Processor;
// ..
import com.google.auto.service.AutoService;
// ..

@AutoService(Processor.class)
public class EnumNamePatternProcessor extends AbstractProcessor {
    // ..
}
```

build시 `build/classes/java/main/META-INF/services` 에 동일한 파일과 내용이 추가되는 것을 확인할 수 있습니다.

### 결과

해당 어노테이션과 Processor 구현체를 적용하고 SPI를 작성하였습니다. 이제 Pattern 에 맞는 enum Name을 사용하는지 컴파일 시점에서 감지할 수 있습니다.

#### UserType enum class

```java
@EnumNamePattern(value = "^.*_(ADMIN|MANAGER)$")
public enum UserType {
    TEST_ADMIN,
    TEST_MANAGER,

    TEST_FAILED,
    TEST_failed,
}
```

```shell
./gradlew clean
./gradlew build
./gradlew build # 잘못 작성한게 아닙니다! clean 이후 build를 두번 실행 시켜야 합니다.
```

<figure style="display: inline-block; width: 100%">
  <img src="/images/blog/spring/annotation-processor/enum-name-pattern-result.png" align="center" width="800" style="border: 1px solid #555; border-radius: 7px;"/>
  <figcaption>Enum name pattern 에 대한 compile 오류가 발생하는 모습</figcaption>
</figure>

### 빌드를 두번 시켜야하는 이유는 무엇이었나?

빌드는 일반적으로 다음과 같은 단계를 거칩니다:

1. 소스 파일 컴파일\
   javac가 소스 파일을 컴파일하며 Annotation Processor를 로드하고 실행합니다.
2. Annotation Processor 실행\
   컴파일된 클래스 파일을 기반으로 Annotation Processor가 실행되어 추가 코드를 생성하거나 유효성 검사를 수행합니다.
3. 코드 생성 파일의 컴파일\
   Processor가 생성한 파일은 다음 빌드 단계에서 컴파일됩니다.

Processor가 같은 프로젝트 내에서 구현되었을 경우, 첫 번째 빌드에서는 Processor 클래스가 아직 컴파일되지 않은 상태입니다. 따라서 javac는 Processor를 로드하지 못하고 컴파일만 수행하며, 이로서 어노테이션 처리를 생략하게 됩니다. 두번째 빌드에서 부터 Processor를 로드할 수 있어 어노테이션 처리가 가능하게 됩니다.

#### 해결 방법은?

1. 멀티 모듈 구성

Annotation Processor를 별도의 모듈로 분리하고, 애플리케이션에 의존성으로 주입합니다.
이 경우 애플리케이션 빌드 전에 Processor 모듈을 명시적으로 먼저 빌드할 수 있어, Processor가 정상적으로 동작합니다.

2. 라이브러리 제공

Annotation Processor 코드를 미리 컴파일하여 JAR 파일 형태로 제공할 수 있습니다.
이를 프로젝트 의존성으로 추가하면, 빌드 순서 문제를 해결할 수 있습니다.

#### 그래서 어떻게 적용하였나?

저희 프로젝트에서는 이 문제를 해결하지 않고 넘어갔습니다.
멀티 모듈 구성을 도입하면 코드베이스가 복잡해져, 개발 숙련도가 낮은 개발자들에게 혼란을 줄 우려가 있습니다.

라이브러리로 제공하고 싶었지만, 아직 사내에 이를 관리할 Maven Repository나 배포 시스템이 구축되지 않은 상황입니다.
사내 Maven Repository를 조만간 도입할 예정이기 때문에 현재로서는 CI에서 `compileJava` 이후 `build`를 명시적으로 실행하는 방식으로 문제를 우회할 예정입니다.

사내 라이브러리 관리 시스템이 준비되면, 이를 기반으로 개선된 방식과 함께 포스팅을 추가하겠습니다.

<!-- annotation-processor github -->

[^1]: https://github.com/azqazq195/blog-code-example/tree/master/spring/annotationprocessor/enumnamepattern
[^2]: https://github.com/google/auto/tree/main/service
