---
title: Kotest에서 @DataJpaTest 사용시 데이터가 롤백되지 않은 문제
type: blog
date: 2024-11-27
tags:
  - kotlin
  - spring
  - kotest
summary: "Kotest와 @DataJpaTest 사용 시 발생하는 트랜잭션 롤백 문제와 해결 방법을 설명합니다."
---

## 문제

Kotest 에서 @DataJpaTest사용시 롤백되지 않는 문제가 있었다.</br>
아래 테스트 코드를 살펴보자.

```kotlin
@DataJpaTest
class UserRepositoryTest @Autowired constructor(
    private val userRepository: UserRepository
) : BehaviorSpec({
    Given("existsByEmail") {
        val user = UserFixture.createEntity()
        userRepository.save(user)
        //..
    }

    Given("findByEmail") {
        val user = UserFixture.createEntity()
        userRepository.save(user)
        //..
    }
})
```

각각의 Given을 따로 수행 했을 때는 문제 없이 테스트를 진행할 수 있었다.</br>
하지만 UserRepositoryTest를 전체 진행했을 때는 아래 오류가 발생하였다.

<figure style="display: inline-block; width: 100%">
  <img src="/images/issue/spring/kotest-transactional/test-result.png" align="center" width="600"/>
  <figcaption>테스트 결과</figcaption>
</figure>

```plantext
could not execute statement
[Unique index or primary key violation:
"PUBLIC.CONSTRAINT_INDEX_2 ON PUBLIC.""USER""(EMAIL NULLS FIRST) VALUES ( /* 6 */ 'email' )";
SQL statement:
...
```

## 원인

BehaviorSpec 에 맞게 Given에서 데이터를 제공하기 때문에, Given마다 트랜잭션이 롤백되기를 원했다.
하지만 의도와 다르게 Given("existsByEmail")에서 저장한 Entity가 롤백되지 않았기 때문에Given("findByEmail")에서 email의 Unique 문제가 발생한다.

## 살펴보기

Kotest에서 Transaction이 적용되지 않는 것으로 예상되는데 천천히 살펴보자.
`@DataJpaTest` 에서의 RollBack
JpaRepository를 테스트하는 경우엔 `@DataJpaTest를` 사용하곤한다.
해당 어노테이션을 사용하면 테스트 이후 데이터를 RollBack 시켜주는 데, 이러한 이유는 `@DataJpaTest`는 `@Transactional`을 내포하고 있기 때문이다.
아래 `@DataJpaTest`에서 확인할 수 있다.

@DataJpaTest:

```kotlin
@Target(ElementType.TYPE)
@Retention(RetentionPolicy.RUNTIME)
@Documented
@Inherited
@BootstrapWith(DataJpaTestContextBootstrapper.class)
@ExtendWith(SpringExtension.class)
@OverrideAutoConfiguration(enabled = false)
@TypeExcludeFilters(DataJpaTypeExcludeFilter.class)
@Transactional // <-- here
@AutoConfigureCache
@AutoConfigureDataJpa
@AutoConfigureTestDatabase
@AutoConfigureTestEntityManager
@ImportAutoConfiguration
public @interface DataJpaTest
```

### @Transacational을 테스트에서 사용하면 롤백하는 이유는 무엇일까?

스프링 테스트 프레임워크에서는 TransactionalTestExecutionListener 가 활성화 되어 Transactional을 관리한다. 코드를 살펴보면 해당 Listener가 Rollback 여부를 확인하는데 default 값으로 true가 지정되어 있는 것을 확인할 수 있다.

> 참조: [Spring Framwork Offcial](https://docs.spring.io/spring-framework/reference/testing/testcontext-framework/tx.html)

```java
public class TransactionalTestExecutionListener extends AbstractTestExecutionListener {
    // ..
    protected final boolean isDefaultRollback(TestContext testContext) throws Exception {
        Class<?> testClass = testContext.getTestClass();
        Rollback rollback = TestContextAnnotationUtils.findMergedAnnotation(testClass, Rollback.class);
        boolean rollbackPresent = (rollback != null);

        if (rollbackPresent) {
            boolean defaultRollback = rollback.value();
            if (logger.isDebugEnabled()) {
                logger.debug(String.format("Retrieved default @Rollback(%s) for test class [%s].",
                defaultRollback, testClass.getName()));
            }
            return defaultRollback;
        }

        // else
        return true;
    }
    // ..
}

@Target({ElementType.TYPE, ElementType.METHOD})
@Retention(RetentionPolicy.RUNTIME)
@Documented
@Inherited
public @interface Rollback {
 /**
  * Whether the <em>test-managed transaction</em> should be rolled back
  * after the test method has completed.
  * <p>If {@code true}, the transaction will be rolled back; otherwise,
  * the transaction will be committed.
  * <p>Defaults to {@code true}.
  */
 boolean value() default true; // <--here
}
```

### Kotest에서의 Transaction

#### 로그 설정

Transaction 진행 상황을 보기 위해 로그를 활성화 하자

> Spring Boot 3.1.2

```yml
# src/test/resources/application.yml
spring:
  jpa:
  show-sql: true
  properties:
    hibernate:
      format_sql: true

logging:
  level:
    org.springframework.orm.jpa: DEBUG
    org.springframework.transaction: DEBUG
```

#### JUnit

그렇다면 JUnit Test에서 Rollback이 수행되는지 확인해 보자.
아래는 간단한 user entity 저장 테스트이다.

JUnit:

```kotlin
@DataJpaTest
@AutoConfigureTestDatabase(replace = AutoConfigureTestDatabase.Replace.NONE)
class UserRepositoryJUnitJpaTest @Autowired constructor(
    private val userRepository: UserRepository,
) {
    @Test
    fun test() {
        userRepository.save(UserFixture.createEntity("email"))
    }
}
```

Console:

```plantext
Creating new EntityManager for shared EntityManager invocation
Started UserRepositoryJUnitJpaTest in 2.577 seconds (process running for 5.58)
Creating new transaction with name [com.moseoh.danggeunclone.core.domain.repository.UserRepositoryJUnitJpaTest.test]: PROPAGATION_REQUIRED,ISOLATION_DEFAULT
Opened new EntityManager [SessionImpl(572980523<open>)] for JPA transaction
Exposing JPA transaction as JDBC [org.springframework.orm.jpa.vendor.HibernateJpaDialect$HibernateConnectionHandle@1a899fcd]
OpenJDK 64-Bit Server VM warning: Sharing is only supported for boot loader classes because bootstrap classpath has been appended
Found thread-bound EntityManager [SessionImpl(572980523<open>)] for JPA transaction
Participating in existing transaction
Hibernate:
    insert
    into
        user
        (created_at,email,modified_at,nickname,password,role)
    values
        (?,?,?,?,?,?)
Initiating transaction rollback
Rolling back JPA transaction on EntityManager [SessionImpl(572980523<open>)]
Closing JPA EntityManager [SessionImpl(572980523<open>)] after transaction
```

Database:

```mysql
mysql> select * from user;
Empty set (0.00 sec)
```

#### Kotest

JUnit은 의도한대로 Rollback이 수행되었다. 그렇다면 Kotest는 어떨까?
JUnit 테스트와 동일한 로직을 Kotest로 작성하였다.

Kotest:

```kotlin
@DataJpaTest
@AutoConfigureTestDatabase(replace = AutoConfigureTestDatabase.Replace.NONE)
class UserRepositoryTest @Autowired constructor(
    private val userRepository: UserRepository,
) : BehaviorSpec({
    Given("given") {
        userRepository.save(UserFixture.createEntity("email1"))
    }
})
```

Console:

```plantext
Creating new EntityManager for shared EntityManager invocation
Started UserRepositoryTest in 2.319 seconds (process running for 5.332)
Creating new transaction with name [org.springframework.data.jpa.repository.support.SimpleJpaRepository.save]: PROPAGATION_REQUIRED,ISOLATION_DEFAULT
Opened new EntityManager [SessionImpl(2141284786<open>)] for JPA transaction
Exposing JPA transaction as JDBC [org.springframework.orm.jpa.vendor.HibernateJpaDialect$HibernateConnectionHandle@3a387ca]
Hibernate:
    insert
    into
        user
        (created_at,email,modified_at,nickname,password,role)
    values
        (?,?,?,?,?,?)
Initiating transaction commit
Committing JPA transaction on EntityManager [SessionImpl(2141284786<open>)]
Closing JPA EntityManager [SessionImpl(2141284786<open>)] after transaction
Closing JPA EntityManagerFactory for persistence unit 'default'
```

Database:

```mysql
mysql> select * from user;
+----------------------------+----+----------------------------+--------+----------+----------+------+
| created_at                 | id | modified_at                | email  | nickname | password | role |
+----------------------------+----+----------------------------+--------+----------+----------+------+
| 2023-08-01 18:46:06.559065 | 45 | 2023-08-01 18:46:06.559065 | email1 | nickname | password | USER |
+----------------------------+----+----------------------------+--------+----------+----------+------+
1 row in set (0.00 sec)
```

JUnit과 다르게 `Given` TestScope에서는 Transaction을 생성하지 않고, Repository에서 생성한다.

> Creating new transaction with name .. SimpleJpaRepository.save .. Opened new EntityManager ..

그리고선 `save()`이후 곧바로 커밋을 때려버리고 종료하는 것을 확인할 수 있다.

> Committing JPA transaction on EntityManager
> Closing JPA EntityManager

롤백을 하지 않았기 때문에 DB에 user entity가 저장되어 있는 것을 확인할 수 있다.

> 1 row in set (0.00 sec)

### Repository의 Transaction은 Rollback되지 않는 이유는 무엇일까?

Spring Test Context에서의 Transaction은 TransactionalTestExecutionListener가 관리한다. Repository는 @DataJpaTest에 의해 Spring Context 의 일부임으로 관리 대상이 아닌 것.

#### Repository를 사용해보면, 각각의 method를 수행할 때 트랜잭션이 적용되는 걸 알 수 있다. 모를 수도 있다.

어디서 적용되는 걸까?

개발을 진행할 때, JpaRepository interface를 구현한다.
이때 실제 구현체는 `SimpleJpaRepository`가 된다.
아래 포스팅에서 상세히 정리되어 있다.

> 참조: https://brunch.co.kr/@anonymdevoo/40#comment

### Kotest에 Transaction 적용하기

@DataJpaTest 사용시 Transaction이 적용되지 않는 문제는 이미 이슈로 등록되어있다.
Kotest에서는 이러한 문제를 해결하기 위해 extensions을 통해 SpringExtension을 설정하라고 한다.

extensions를 통해 LifeCycleMode를 설정할 수 있다.
SpringTestLifecycleMode 는 Root와 Test 두가지 옵션을 가지고 있는데 각각 아래와 같이 사용할 수 있다.

> 참조: https://github.com/kotest/kotest/issues/1643

```kotlin
**
 * Determines how the spring test context lifecycle is mapped to test cases.
 *
 * [SpringTestLifecycleMode.Root] will setup and teardown the test context before and after root tests only.
 * [SpringTestLifecycleMode.Test] will setup and teardown the test context only at leaf tests.
 *
 */

enum class SpringTestLifecycleMode {
    Root, Test
}
```

- Root Test : 최상위 레벨의 테스트, 일반적으로 테스트 계층의 시작점.
  - 최상위 레벨의 테스트에 진입할 때 설정하고, 끝날 때 분해한다.
  - BehaviorSpec 에서는 Given(Container Scope)이 해당 된다.
- Leaf Test : 최하위 레벨의 테스트, 특정 테스트 케이스나 시나리오에 대한 실제 실행 테스트 .
  - 최하위 레벨의 테스트에 진입할 때 설정하고, 끝날 때 분해한다.
  - BehaviorSpec 에서는 Then(Test Scope)이 해당 된다.

아래는 extensions 설정이다.
SprintExtension는 SpringTestLifecycleMode.Test가 기본값으로 세가지 방법으로 사용 가능하다.

```kotlin
@DataJpaTest
@AutoConfigureTestDatabase(replace = AutoConfigureTestDatabase.Replace.NONE)
class UserRepositoryTest @Autowired constructor(
    private val userRepository: UserRepository,
) : BehaviorSpec({
    // SpringTestLifecycleMode.Root
    extensions(SpringTestExtension(SpringTestLifecycleMode.Root))

    // SpringTestLifecycleMode.Test
    extensions(SpringTestExtension(SpringTestLifecycleMode.Test))
    extensions(SpringTestExtension())
    extensions(SpringExtension)
})
```

나는 JUnit + @DataJpaTest를 사용하였을 때 처럼, Root Test 마다의 초기화를 원하기 때문에 SpringTestLifecycleMode.Root를 적용하였다. 이로서 각각의 Given마다 독립될 수 있겠다.

### 결과

이제 추가된 코드를 돌려보자.

Kotest:

```kotlin
@DataJpaTest
@AutoConfigureTestDatabase(replace = AutoConfigureTestDatabase.Replace.NONE)
class UserRepositoryTest @Autowired constructor(
    private val userRepository: UserRepository,
) : BehaviorSpec({
    extensions(SpringTestExtension(SpringTestLifecycleMode.Root))

    Given("given") {
        userRepository.save(UserFixture.createEntity("email1"))
    }
})
```

Console:

```plaintext
Creating new EntityManager for shared EntityManager invocation
Started UserRepositoryJUnitJpaTest in 2.577 seconds (process running for 5.58)
Creating new transaction with name [com.moseoh.danggeunclone.core.domain.repository.UserRepositoryJUnitJpaTest.UserRepositoryTest.given_6b6ce7a7_c569_4cab_b172_dfbbb4b0d5bb]: PROPAGATION_REQUIRED,ISOLATION_DEFAULT
Opened new EntityManager [SessionImpl(572980523<open>)] for JPA transaction
Exposing JPA transaction as JDBC [org.springframework.orm.jpa.vendor.HibernateJpaDialect$HibernateConnectionHandle@1a899fcd]
OpenJDK 64-Bit Server VM warning: Sharing is only supported for boot loader classes because bootstrap classpath has been appended
Found thread-bound EntityManager [SessionImpl(572980523<open>)] for JPA transaction
Participating in existing transaction
Hibernate:
    insert
    into
        user
        (created_at,email,modified_at,nickname,password,role)
    values
        (?,?,?,?,?,?)
Initiating transaction rollback
Rolling back JPA transaction on EntityManager [SessionImpl(572980523<open>)]
Closing JPA EntityManager [SessionImpl(572980523<open>)] after transaction
```

어디서 많이 본 로그이다. JUnit + `@DataJpaTest`를 사용한 로그와 같다.
한가지 다른점으로 이 method 이름에는 given이 들어가있는 것을 확인할 수 있다.
`UserRepositoryTest.given_6b6ce7a7_c569_4cab_b172_dfbbb4b0d5bb`

#### Extensions Project Level 설정

예제까지 진행하며 마무리하였지만, 한 가지 남았다.
extensions(SpringTestExtension(SpringTestLifecycleMode.Root))를 테스트 클래스마다 설정할 순 없는 노릇이다.

Kotest에서 Project Level Config를 지원한다. 해당 프로젝트에 공통적으로 설정해보자.

> 참조: https://kotest.io/docs/framework/project-config.html

```kotlin
// src/test/kotlin
class KotestConfig : AbstractProjectConfig() {
    override fun extensions() = listOf(SpringTestExtension(SpringTestLifecycleMode.Root))
}
```

이제 위의 예제에서 extensions는 작성하지 않아도 된다.

```kotlin
@DataJpaTest
@AutoConfigureTestDatabase(replace = AutoConfigureTestDatabase.Replace.NONE)
class UserRepositoryTest @Autowired constructor(
    private val userRepository: UserRepository,
) : BehaviorSpec({
    // extensions(SpringTestExtension(SpringTestLifecycleMode.Root)) KotestConfig에서 불러온다.

    Given("given") {
        userRepository.save(UserFixture.createEntity("email1"))
    }
})
```

## 요약

Kotest + @DataJpaTest 사용시 아래 설정 추가.

```kotlin
// src/test/kotlin
class KotestConfig : AbstractProjectConfig() {
    override fun extensions() = listOf(SpringTestExtension(SpringTestLifecycleMode.Root))
}
```
